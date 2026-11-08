import Foundation
import Combine
import RealityKit
import QuartzCore

/// Coordinates frame-by-frame RealityKit scene updates and bridges physics with rendering.
/// Decouples 60/120 FPS physics & render ticks from throttled SwiftUI state notifications.
@MainActor
final class SceneUpdateController {
    
    // MARK: - Properties
    
    private let physicsEngine: SpinnerPhysicsEngine
    private var updateSubscription: Cancellable?
    
    /// Throttled telemetry publisher for UI HUD updates (~12 Hz).
    private var lastUIUpdateTime: TimeInterval = 0.0
    private let uiUpdateInterval: TimeInterval = 1.0 / 12.0 // ~12 FPS for UI
    
    /// Callback invoked when a throttled UI update is ready.
    var onUIStateUpdate: ((SpinnerState) -> Void)?
    
    /// Dynamic provider for active placement mode (.surface vs .floating).
    var currentModeProvider: (() -> SpinnerMode)?
    
    /// Callback for haptic tick generation when passing angular thresholds.
    var onAngularTick: ((Float) -> Void)?
    private var lastHapticAngle: Float = 0.0
    private var lastHapticTime: TimeInterval = 0.0
    private let hapticAngleInterval: Float = (2.0 * .pi) / 3.0 // 1 tick per wing passage (120 deg)
    private let minHapticInterval: TimeInterval = 0.035 // Max ~28 Hz haptic ticks to prevent Taptic motor saturation
    
    /// Flag indicating whether the stationary resting state has been reported to UI.
    /// Prevents repeated 12 Hz SwiftUI body re-evaluations when the spinner is completely stopped.
    private var hasPublishedRestingState: Bool = false
    
    // MARK: - Initialization
    
    init(physicsEngine: SpinnerPhysicsEngine) {
        self.physicsEngine = physicsEngine
    }
    
    // MARK: - Subscription Management
    
    /// Subscribes to RealityKit SceneEvents.Update to drive frame updates.
    func startUpdating(scene: RealityKit.Scene, rotatingBody: Entity) {
        stopUpdating()
        
        lastUIUpdateTime = CACurrentMediaTime()
        lastHapticAngle = physicsEngine.state.angle
        lastHapticTime = 0.0
        hasPublishedRestingState = false
        
        updateSubscription = scene.subscribe(to: SceneEvents.Update.self) { [weak self, weak rotatingBody] event in
            guard let self = self, let rotatingBody = rotatingBody else { return }
            self.tick(deltaTime: event.deltaTime, rotatingBody: rotatingBody)
        }
        
        AppLogger.scene.info("SceneUpdateController subscribed to SceneEvents.Update.")
    }
    
    /// Cancels the update subscription.
    func stopUpdating() {
        updateSubscription?.cancel()
        updateSubscription = nil
    }
    
    // MARK: - Frame Tick
    
    private func tick(deltaTime: TimeInterval, rotatingBody: Entity) {
        // 1. Advance physics simulation
        physicsEngine.update(deltaTime: deltaTime)
        
        // 2. Apply updated orientation directly to the RealityKit rotating body
        let currentAngle = physicsEngine.state.angle
        if currentAngle.isFinite {
            rotatingBody.orientation = simd_quatf(angle: currentAngle, axis: [0, 1, 0])
        }
        
        let now = CACurrentMediaTime()
        
        // 3. Check for angular passage for tactile haptics (rate-limited to protect Taptic engine)
        let angleDelta = abs(currentAngle - lastHapticAngle)
        if angleDelta >= hapticAngleInterval {
            let speed = abs(physicsEngine.state.angularVelocity)
            if speed > 1.0 && (now - lastHapticTime >= minHapticInterval) {
                onAngularTick?(speed)
                lastHapticTime = now
            }
            lastHapticAngle = currentAngle
        }
        
        // 4. Throttled UI state publication with idle sleep
        let speed = abs(physicsEngine.state.angularVelocity)
        let isTouching = abs(physicsEngine.activeInputTorque) > 1e-5
        let isMoving = speed > 0.005 || isTouching
        
        if isMoving {
            hasPublishedRestingState = false
            if now - lastUIUpdateTime >= uiUpdateInterval {
                lastUIUpdateTime = now
                let mode = currentModeProvider?() ?? .surface
                let snapshot = physicsEngine.makeStateSnapshot(isPlaced: true, mode: mode)
                onUIStateUpdate?(snapshot)
            }
        } else if !hasPublishedRestingState {
            // Publish one final resting snapshot settling HUD to 0 RPM and idle direction,
            // then sleep UI state updates until user touches or spins again.
            hasPublishedRestingState = true
            lastUIUpdateTime = now
            let mode = currentModeProvider?() ?? .surface
            let snapshot = physicsEngine.makeStateSnapshot(isPlaced: true, mode: mode)
            onUIStateUpdate?(snapshot)
        }
    }
}
