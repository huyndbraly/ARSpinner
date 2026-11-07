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
    
    /// Callback for haptic tick generation when passing angular thresholds.
    var onAngularTick: ((Float) -> Void)?
    private var lastHapticAngle: Float = 0.0
    private let hapticAngleInterval: Float = (2.0 * .pi) / 3.0 // 1 tick per wing passage (120 deg)
    
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
        
        // 3. Check for angular passage for tactile haptics
        let angleDelta = abs(currentAngle - lastHapticAngle)
        if angleDelta >= hapticAngleInterval {
            let speed = abs(physicsEngine.state.angularVelocity)
            if speed > 1.0 {
                onAngularTick?(speed)
            }
            lastHapticAngle = currentAngle
        }
        
        // 4. Throttled UI state publication (does NOT redraw SwiftUI every 120 FPS frame)
        let now = CACurrentMediaTime()
        if now - lastUIUpdateTime >= uiUpdateInterval {
            lastUIUpdateTime = now
            let snapshot = physicsEngine.makeStateSnapshot(isPlaced: true, mode: .surface)
            onUIStateUpdate?(snapshot)
        }
    }
}
