import Foundation
import UIKit
import RealityKit
import ARKit
import QuartzCore

/// Handles touch gestures on the ARView, projects touch rays onto the 3D spinner volume,
/// and applies continuous physical torque during user contact without latency.
@MainActor
final class SpinnerGestureController: NSObject, UIGestureRecognizerDelegate {
    
    // MARK: - Dependencies
    
    private weak var arView: ARView?
    private let sceneController: SpinnerSceneController
    private let hapticService: HapticFeedbackService
    private let audioService: AudioFeedbackProviding?
    private let stateMachine = InteractionStateMachine()
    
    // MARK: - Callbacks
    
    /// Invoked when user taps the screen to place the spinner prior to placement.
    var onTapToPlace: ((CGPoint) -> Void)?
    
    // MARK: - Gesture Recognizers
    
    private var panRecognizer: UIPanGestureRecognizer?
    private var tapRecognizer: UITapGestureRecognizer?
    
    // MARK: - Gesture State
    
    private var isInteractingWithSpinner: Bool = false
    
    /// Throttled diagnostic logging helper for touch interaction
    private var lastDiagnosticLogTime: TimeInterval = 0.0
    private let diagnosticLogInterval: TimeInterval = 0.15 // ~6.6 Hz logging to prevent console spam
    
    // MARK: - Initialization
    
    init(
        arView: ARView,
        sceneController: SpinnerSceneController,
        hapticService: HapticFeedbackService,
        audioService: AudioFeedbackProviding? = nil
    ) {
        self.arView = arView
        self.sceneController = sceneController
        self.hapticService = hapticService
        self.audioService = audioService
        super.init()
        setupGestureRecognizers(on: arView)
    }
    
    // MARK: - Setup & Teardown
    
    private func setupGestureRecognizers(on arView: ARView) {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = true
        pan.delegate = self
        arView.addGestureRecognizer(pan)
        self.panRecognizer = pan
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.cancelsTouchesInView = true
        tap.delegate = self
        arView.addGestureRecognizer(tap)
        self.tapRecognizer = tap
    }
    
    func teardown() {
        if let arView = arView {
            if let pan = panRecognizer {
                arView.removeGestureRecognizer(pan)
            }
            if let tap = tapRecognizer {
                arView.removeGestureRecognizer(tap)
            }
        }
        panRecognizer = nil
        tapRecognizer = nil
        onTapToPlace = nil
        cleanupInteraction()
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard let arView = arView else { return false }
        
        // Before placement: allow tap to place anywhere on screen
        if !sceneController.isPlaced {
            return gestureRecognizer == tapRecognizer
        }
        
        // After placement: receive touch if intersecting spinner 3D volume or immediate margin
        let point = touch.location(in: arView)
        return isTouchNearSpinner(at: point, marginMultiplier: 1.4)
    }
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return false
    }
    
    // MARK: - 3D Hit Testing & Volume Intersection
    
    /// Determines whether a 2D screen coordinate projects onto or immediately near the spinner.
    private func isTouchNearSpinner(at point: CGPoint, marginMultiplier: Float = 1.4) -> Bool {
        return findSpinnerContactPoint(at: point, marginMultiplier: marginMultiplier) != nil
    }
    
    /// Finds the exact 3D contact point on the spinner using 3D ray-volume intersection with RealityKit entity hitTest fallback.
    private func findSpinnerContactPoint(at point: CGPoint, marginMultiplier: Float = 1.3) -> TouchProjector.RayVolumeIntersection? {
        guard let arView = arView,
              let spinnerCenter = sceneController.anchorManager.worldPosition,
              let spinnerNormal = sceneController.anchorManager.worldRotationAxis,
              let ray = arView.ray(through: point) else {
            return nil
        }
        
        let radius = sceneController.currentRadius
        let thickness = sceneController.currentThickness
        let orientation = sceneController.anchorManager.worldOrientation ?? simd_quatf(angle: 0, axis: [0, 1, 0])
        
        // 1. Precise analytical 3D ray-volume intersection with the 3D spinner cylinder proxy
        if let volumeHit = TouchProjector.intersectRayWithSpinnerVolume(
            rayOrigin: ray.origin,
            rayDirection: ray.direction,
            spinnerCenter: spinnerCenter,
            rotationAxis: spinnerNormal,
            spinnerOrientation: orientation,
            radius: radius,
            thickness: thickness,
            marginMultiplier: marginMultiplier
        ) {
            return volumeHit
        }
        
        // 2. RealityKit direct entity hit-test fallback
        let hitResults = arView.hitTest(point)
        for hit in hitResults {
            var entity: Entity? = hit.entity
            while let current = entity {
                if current.name.contains("Spinner") {
                    let worldPos = hit.position
                    let rVec = worldPos - spinnerCenter
                    let inPlaneR = VectorMath.projectOntoPlane(vector: rVec, planeNormal: spinnerNormal)
                    let dist = simd_length(inPlaneR)
                    if dist <= (radius * marginMultiplier) {
                        return TouchProjector.RayVolumeIntersection(
                            worldPoint: worldPos,
                            localPoint: worldPos - spinnerCenter,
                            worldNormal: spinnerNormal,
                            localNormal: [0, 1, 0],
                            inPlaneRadiusVector: inPlaneR,
                            leverArmDistance: dist,
                            surfaceType: .topFace,
                            rayDistance: simd_length(worldPos - ray.origin),
                            isDirectHit: true
                        )
                    }
                }
                entity = current.parent
            }
        }
        
        // 3. Fallback to planar disc projection if within margin
        if let planeHit = TouchProjector.projectRayOntoSpinnerPlane(
            rayOrigin: ray.origin,
            rayDirection: ray.direction,
            spinnerCenter: spinnerCenter,
            spinnerNormal: spinnerNormal,
            maxRadius: radius,
            marginMultiplier: marginMultiplier
        ), planeHit.isWithinInteractionRadius {
            return TouchProjector.RayVolumeIntersection(
                worldPoint: planeHit.worldPoint,
                localPoint: planeHit.worldPoint - spinnerCenter,
                worldNormal: spinnerNormal,
                localNormal: [0, 1, 0],
                inPlaneRadiusVector: planeHit.radiusVector,
                leverArmDistance: planeHit.distanceFromCenter,
                surfaceType: .margin,
                rayDistance: simd_length(planeHit.worldPoint - ray.origin),
                isDirectHit: false
            )
        }
        
        return nil
    }
    
    /// Projects a 2D screen coordinate into a 3D intersection point on the spinner plane for final trajectory logging.
    private func projectPointToSpinnerPlane(_ point: CGPoint, marginMultiplier: Float = 2.0) -> simd_float3? {
        guard let hit = findSpinnerContactPoint(at: point, marginMultiplier: marginMultiplier) else {
            return nil
        }
        return hit.worldPoint
    }
    
    // MARK: - Pan Gesture Handling
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let arView = arView,
              sceneController.isPlaced,
              let spinnerCenter = sceneController.anchorManager.worldPosition,
              let spinnerNormal = sceneController.anchorManager.worldRotationAxis else {
            return
        }
        
        let screenPoint = gesture.location(in: arView)
        let now = CACurrentMediaTime()
        let currentRadius = sceneController.currentRadius
        
        switch gesture.state {
        case .began:
            guard let hit = findSpinnerContactPoint(at: screenPoint, marginMultiplier: 1.4) else {
                return
            }
            
            isInteractingWithSpinner = true
            stateMachine.onTouchBegan(
                screenPoint: screenPoint,
                worldPoint: hit.worldPoint,
                surfaceType: hit.surfaceType,
                timestamp: now
            )
            
            hapticService.onTouchContact()
            
            // Clear any previous continuous torque
            sceneController.physicsEngine.clearInputTorque()
            
            logInteraction(
                phase: "Began",
                hit: hit,
                screenPoint: screenPoint,
                torque: 0.0,
                rpm: sceneController.physicsEngine.state.rpm
            )
            
        case .changed:
            guard isInteractingWithSpinner else { return }
            
            // Continuous 3D contact point tracking (with generous follow-through margin)
            guard let hit = findSpinnerContactPoint(at: screenPoint, marginMultiplier: 2.2) else {
                // If finger drifted far off the spinner, stop applying torque
                sceneController.physicsEngine.clearInputTorque()
                return
            }
            
            let previousSample = stateMachine.lastSample
            stateMachine.onTouchMoved(
                screenPoint: screenPoint,
                worldPoint: hit.worldPoint,
                surfaceType: hit.surfaceType,
                timestamp: now
            )
            
            if let prev = previousSample {
                let dt = now - prev.timestamp
                let currentMode = sceneController.physicsEngine.spinMode
                let torqueResult = SwipeImpulseCalculator.calculateContinuousTorque(
                    previousWorldPoint: prev.worldPoint,
                    currentWorldPoint: hit.worldPoint,
                    previousScreenPoint: prev.screenPoint,
                    currentScreenPoint: screenPoint,
                    deltaTime: dt,
                    spinnerCenter: spinnerCenter,
                    rotationAxis: spinnerNormal,
                    spinnerRadius: currentRadius,
                    momentOfInertia: sceneController.physicsEngine.state.momentOfInertia,
                    currentAngularVelocity: sceneController.physicsEngine.state.angularVelocity,
                    effectiveMass: sceneController.physicsEngine.configuration.effectiveTouchMass,
                    spinMode: currentMode
                )
                
                if torqueResult.isStationary {
                    // Stationary finger: 0 input torque! Spinner coasts naturally with friction.
                    sceneController.physicsEngine.clearInputTorque()
                } else {
                    // Finger is actively moving: apply continuous torque directly to physics engine!
                    sceneController.physicsEngine.setInputTorque(torqueResult.appliedTorque, timestamp: now)
                }
                
                logInteraction(
                    phase: "Moved",
                    hit: hit,
                    screenPoint: screenPoint,
                    torque: torqueResult.appliedTorque,
                    rpm: sceneController.physicsEngine.state.rpm
                )
            }
            
        case .ended:
            guard isInteractingWithSpinner else {
                cleanupInteraction()
                return
            }
            
            // End of active finger contact: immediately clear continuous input torque
            sceneController.physicsEngine.clearInputTorque()
            if sceneController.physicsEngine.spinMode == .continuous {
                sceneController.physicsEngine.recordContinuousStroke(timestamp: now)
            }
            
            let finalSpeed = abs(sceneController.physicsEngine.state.angularVelocity)
            if finalSpeed > 2.0 {
                hapticService.onSwipeFlick(speed: finalSpeed)
            }
            
            let finalWorldPoint = projectPointToSpinnerPlane(screenPoint, marginMultiplier: 2.2)
            _ = stateMachine.onTouchEnded(
                finalScreenPoint: screenPoint,
                finalWorldPoint: finalWorldPoint,
                timestamp: now,
                spinnerCenter: spinnerCenter,
                rotationAxis: spinnerNormal,
                spinnerRadius: currentRadius
            )
            
            let currentOmega = sceneController.physicsEngine.state.angularVelocity
            let currentRPM = sceneController.physicsEngine.state.rpm
            AppLogger.interaction.info("Swipe contact ended. Angular velocity preserved: \(currentOmega, format: .fixed(precision: 1)) rad/s (\(currentRPM, format: .fixed(precision: 1)) RPM). Zero duplicate impulse applied.")
            
            cleanupInteraction()
            
        case .cancelled, .failed:
            AppLogger.interaction.debug("Pan gesture cancelled or failed.")
            sceneController.physicsEngine.clearInputTorque()
            stateMachine.onTouchCancelled()
            cleanupInteraction()
            
        default:
            break
        }
    }
    
    // MARK: - Tap Gesture Handling
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let arView = arView else { return }
        
        let screenPoint = gesture.location(in: arView)
        
        // Before placement: Tap to place in physical environment
        if !sceneController.isPlaced {
            AppLogger.interaction.info("Tap to place at screen point: (\(screenPoint.x, format: .fixed(precision: 1)), \(screenPoint.y, format: .fixed(precision: 1)))")
            onTapToPlace?(screenPoint)
            return
        }
        
        // After placement: Mere tap DOES NOT create rotational impulse or torque!
        // Subtle haptic touch feedback acknowledges user contact without spinning.
        if isTouchNearSpinner(at: screenPoint, marginMultiplier: 1.2) {
            hapticService.onTouchContact()
            AppLogger.interaction.debug("Tap on placed spinner detected: acknowledged with haptic contact. No rotational torque or impulse generated.")
        }
    }
    
    private func cleanupInteraction() {
        isInteractingWithSpinner = false
        sceneController.physicsEngine.clearInputTorque()
    }
    
    // MARK: - Diagnostic Logging
    
    private func logInteraction(
        phase: String,
        hit: TouchProjector.RayVolumeIntersection,
        screenPoint: CGPoint,
        torque: Float,
        rpm: Float
    ) {
        let now = CACurrentMediaTime()
        guard phase != "Moved" || (now - lastDiagnosticLogTime >= diagnosticLogInterval) else { return }
        lastDiagnosticLogTime = now
        
        let state = sceneController.physicsEngine.state
        let surfaceName = hit.surfaceType.rawValue
        
        AppLogger.interaction.debug(
            "[Interaction \(phase)] surface=\(surfaceName) screen=(\(screenPoint.x, format: .fixed(precision: 1)), \(screenPoint.y, format: .fixed(precision: 1))) world=(\(hit.worldPoint.x, format: .fixed(precision: 3)), \(hit.worldPoint.y, format: .fixed(precision: 3)), \(hit.worldPoint.z, format: .fixed(precision: 3))) leverArm=\(hit.leverArmDistance * 100.0, format: .fixed(precision: 1))cm inTorque=\(torque, format: .fixed(precision: 5))N·m fricTorque=\(state.frictionTorque, format: .fixed(precision: 5))N·m alpha=\(state.angularAcceleration, format: .fixed(precision: 1))rad/s² RPM=\(rpm, format: .fixed(precision: 1))"
        )
    }
}
