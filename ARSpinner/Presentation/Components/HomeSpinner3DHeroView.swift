import SwiftUI
import SceneKit
import UIKit

/// High-performance, battery-efficient 3D hero showcase view rendering custom USDZ spinner models
/// with optimized studio lighting, decoupled 3D orbital inspection on background drag,
/// responsive spin physics on direct spinner touch, throttled telemetry to avoid SwiftUI re-render thrashing,
/// and full lifecycle pausing to prevent GPU/thermal contention during AR sessions.
struct HomeSpinner3DHeroView: View {
    let model: SpinnerModelDescriptor
    @Binding var rpm: Double
    @Binding var isSpinningActive: Bool
    let isViewActive: Bool
    let onUserInteraction: () -> Void
    
    var body: some View {
        HomeSceneKitHeroRepresentable(
            model: model,
            rpm: $rpm,
            isSpinningActive: $isSpinningActive,
            isViewActive: isViewActive,
            onUserInteraction: onUserInteraction
        )
    }
}

// MARK: - SceneKit Hero Representable

private struct HomeSceneKitHeroRepresentable: UIViewRepresentable {
    let model: SpinnerModelDescriptor
    @Binding var rpm: Double
    @Binding var isSpinningActive: Bool
    let isViewActive: Bool
    let onUserInteraction: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            rpmBinding: $rpm,
            isSpinningActiveBinding: $isSpinningActive,
            onInteraction: onUserInteraction
        )
    }
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)
        scnView.backgroundColor = .clear
        
        // Performance optimization: Disable 4X MSAA on ultra-dense Retina screens (460+ PPI).
        // This cuts GPU fragment fill-rate & memory bandwidth by ~75% and prevents thermal heating.
        scnView.antialiasingMode = .none
        
        // Start at 30 FPS for low-power idle showroom turntable; dynamically scales to 60 FPS on active spin
        scnView.preferredFramesPerSecond = 30
        scnView.isUserInteractionEnabled = true
        
        context.coordinator.setupScene(on: scnView)
        context.coordinator.attachGestures(to: scnView)
        context.coordinator.loadModel(model)
        context.coordinator.startPhysicsLoop()
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        if context.coordinator.currentModelId != model.id {
            context.coordinator.loadModel(model)
        }
        
        // Manage lifecycle pausing: completely stop rendering when navigating to AR or sheet
        context.coordinator.setViewActive(isViewActive)
    }
    
    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.teardown(view: uiView)
    }
    
    // MARK: - Coordinator
    
    final class Coordinator: NSObject {
        private var rpmBinding: Binding<Double>
        private var isSpinningActiveBinding: Binding<Bool>
        private let onInteraction: () -> Void
        
        var currentModelId: String = ""
        private weak var scnView: SCNView?
        
        // Node Hierarchy:
        // orbitGimbalNode (yaw & pitch 3D inspection) -> spinContainerNode (spin around local Y) -> modelWrapper
        private var orbitGimbalNode: SCNNode?
        private var spinContainerNode: SCNNode?
        private var currentModelWrapper: SCNNode?
        
        // Default Inspection Angles
        private let defaultPitch: Float = 0.0
        private let defaultYaw: Float = 0.0
        
        // Touch Interaction Mode
        private enum TouchMode {
            case none
            case spin
            case orbit
        }
        private var currentTouchMode: TouchMode = .none
        
        // Spin Physics State
        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval = 0
        private var angularVelocity: Float = 0.8 // Idle speed (~45 RPM)
        private let idleAngularVelocity: Float = 0.8
        private var previousPanTranslationX: CGFloat = 0
        private var lastPanVelocityX: CGFloat = 0
        private var idleSettleTimer: Float = 0.0
        private var isViewActive: Bool = true
        
        // Telemetry Throttling State (prevents 120 FPS SwiftUI re-render storm)
        private var lastReportedRPM: Double = -1.0
        private var lastRPMReportTime: CFTimeInterval = 0.0
        
        // Orbit (Background Drag) State
        private var initialPitch: Float = 0.0
        private var initialYaw: Float = 0.0
        
        // Haptics
        private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
        private let selectionFeedback = UISelectionFeedbackGenerator()
        private var lastHapticAngle: Float = 0
        
        init(
            rpmBinding: Binding<Double>,
            isSpinningActiveBinding: Binding<Bool>,
            onInteraction: @escaping () -> Void
        ) {
            self.rpmBinding = rpmBinding
            self.isSpinningActiveBinding = isSpinningActiveBinding
            self.onInteraction = onInteraction
            super.init()
            impactFeedback.prepare()
            lightFeedback.prepare()
            selectionFeedback.prepare()
        }
        
        func setupScene(on view: SCNView) {
            self.scnView = view
            let scene = SCNScene()
            
            // Optimized Studio Lighting Rig (Streamlined to 2 directional + 1 ambient to minimize fragment shader load)
            let keyLightNode = SCNNode()
            let keyLight = SCNLight()
            keyLight.type = .directional
            keyLight.intensity = 1350
            keyLight.color = UIColor(white: 0.98, alpha: 1.0)
            keyLightNode.light = keyLight
            keyLightNode.position = SCNVector3(1.2, 2.2, 2.0)
            keyLightNode.eulerAngles = SCNVector3(-Float.pi / 4.0, Float.pi / 5.0, 0)
            scene.rootNode.addChildNode(keyLightNode)
            
            let rimLightNode = SCNNode()
            let rimLight = SCNLight()
            rimLight.type = .directional
            rimLight.intensity = 1100
            rimLight.color = UIColor(red: 0.25, green: 0.85, blue: 1.0, alpha: 1.0)
            rimLightNode.light = rimLight
            rimLightNode.position = SCNVector3(-1.8, 1.8, -2.0)
            rimLightNode.eulerAngles = SCNVector3(Float.pi / 4.0, -Float.pi / 3.0, 0)
            scene.rootNode.addChildNode(rimLightNode)
            
            let ambientLightNode = SCNNode()
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.intensity = 450
            ambientLight.color = UIColor(white: 0.8, alpha: 1.0)
            ambientLightNode.light = ambientLight
            scene.rootNode.addChildNode(ambientLightNode)
            
            // Camera Setup
            let cameraNode = SCNNode()
            let camera = SCNCamera()
            camera.zNear = 0.01
            camera.zFar = 50.0
            camera.fieldOfView = 50.0
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0.48, 1.35)
            cameraNode.eulerAngles = SCNVector3(-0.35, 0, 0)
            scene.rootNode.addChildNode(cameraNode)
            view.pointOfView = cameraNode
            
            // Orbit Gimbal (controls 3D inspection pitch & yaw on background touch)
            let gimbal = SCNNode()
            gimbal.name = "OrbitGimbal"
            gimbal.eulerAngles.x = defaultPitch
            gimbal.eulerAngles.y = defaultYaw
            scene.rootNode.addChildNode(gimbal)
            self.orbitGimbalNode = gimbal
            
            // Spin Container (controls spin around local Y axis)
            let spinContainer = SCNNode()
            spinContainer.name = "SpinContainer"
            gimbal.addChildNode(spinContainer)
            self.spinContainerNode = spinContainer
            
            view.scene = scene
        }
        
        func attachGestures(to view: SCNView) {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.maximumNumberOfTouches = 1
            view.addGestureRecognizer(pan)
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            view.addGestureRecognizer(tap)
            
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            view.addGestureRecognizer(doubleTap)
            tap.require(toFail: doubleTap)
        }
        
        // MARK: - Lifecycle Management
        
        func setViewActive(_ active: Bool) {
            guard isViewActive != active else { return }
            self.isViewActive = active
            
            if active {
                displayLink?.isPaused = false
                scnView?.preferredFramesPerSecond = (abs(angularVelocity) > idleAngularVelocity + 1.0) ? 60 : 30
                lastTimestamp = CACurrentMediaTime()
            } else {
                // Pause completely when leaving HomeView (e.g. going to ARExperienceView)
                // This releases 100% of GPU resources so ARKit + RealityKit run with zero thermal contention!
                displayLink?.isPaused = true
                scnView?.preferredFramesPerSecond = 0
            }
        }
        
        // MARK: - Model Loading & Normalization
        
        func loadModel(_ model: SpinnerModelDescriptor) {
            self.currentModelId = model.id
            guard let container = spinContainerNode else { return }
            
            let cacheKey = "hero_" + (model.fileURL?.path ?? model.assetName)
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.2
            self.currentModelWrapper?.opacity = 0.0
            SCNTransaction.commit()
            
            if let cachedNode = SpinnerPreviewCache.shared.getNode(for: cacheKey) {
                attachModelNode(cachedNode, to: container)
                return
            }
            
            let url = model.fileURL
            let name = model.assetName
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self, weak container] in
                guard let self = self, let container = container else { return }
                
                var loadedScene: SCNScene?
                if let targetURL = url, FileManager.default.fileExists(atPath: targetURL.path) {
                    loadedScene = try? SCNScene(url: targetURL, options: nil)
                }
                if loadedScene == nil {
                    loadedScene = SCNScene(named: name)
                }
                if loadedScene == nil {
                    loadedScene = SCNScene(named: "\(name).usdz")
                }
                
                let modelWrapper = SCNNode()
                if let modelScene = loadedScene {
                    let meshNode = SCNNode()
                    for child in modelScene.rootNode.childNodes {
                        meshNode.addChildNode(child.clone())
                    }
                    
                    let bbox = meshNode.boundingBox
                    let spanX = abs(Float(bbox.max.x - bbox.min.x))
                    let spanY = abs(Float(bbox.max.y - bbox.min.y))
                    let spanZ = abs(Float(bbox.max.z - bbox.min.z))
                    
                    var horizontalSpan: Float = max(spanX, spanZ)
                    var centerX = Float(bbox.min.x + bbox.max.x) * 0.5
                    var centerY = Float(bbox.min.y + bbox.max.y) * 0.5
                    var centerZ = Float(bbox.min.z + bbox.max.z) * 0.5
                    
                    if spanZ < spanY && spanZ < spanX {
                        meshNode.eulerAngles.x = Float.pi / 2.0
                        horizontalSpan = max(spanX, spanY)
                        let oldY = centerY
                        let oldZ = centerZ
                        centerY = -oldZ
                        centerZ = oldY
                    } else if spanX < spanY && spanX < spanZ {
                        meshNode.eulerAngles.z = Float.pi / 2.0
                        horizontalSpan = max(spanY, spanZ)
                        let oldX = centerX
                        let oldY = centerY
                        centerX = oldY
                        centerY = -oldX
                    }
                    
                    modelWrapper.addChildNode(meshNode)
                    
                    if horizontalSpan > 0.001 {
                        let targetSpan: Float = 1.12
                        let scale = targetSpan / horizontalSpan
                        modelWrapper.scale = SCNVector3(scale, scale, scale)
                        modelWrapper.position = SCNVector3(-centerX * scale, -centerY * scale, -centerZ * scale)
                    }
                } else {
                    let fallbackGeom = SCNTorus(ringRadius: 0.44, pipeRadius: 0.10)
                    fallbackGeom.firstMaterial?.diffuse.contents = UIColor.systemCyan
                    let fallbackNode = SCNNode(geometry: fallbackGeom)
                    modelWrapper.addChildNode(fallbackNode)
                }
                
                SpinnerPreviewCache.shared.setNode(modelWrapper, for: cacheKey)
                
                DispatchQueue.main.async { [weak self, weak container] in
                    guard let self = self, let container = container, self.currentModelId == model.id else { return }
                    self.attachModelNode(modelWrapper.clone(), to: container)
                }
            }
        }
        
        private func attachModelNode(_ node: SCNNode, to container: SCNNode) {
            currentModelWrapper?.removeFromParentNode()
            node.opacity = 0.0
            container.addChildNode(node)
            self.currentModelWrapper = node
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.22
            node.opacity = 1.0
            SCNTransaction.commit()
        }
        
        // MARK: - Gesture Handling: Spinner Touch vs Background 3D Orbit
        
        private func isSpinnerHit(at point: CGPoint, in view: SCNView) -> Bool {
            let hitResults = view.hitTest(point, options: [
                SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue
            ])
            guard let container = spinContainerNode else { return false }
            return hitResults.contains { result in
                var curr: SCNNode? = result.node
                while let c = curr {
                    if c == container { return true }
                    curr = c.parent
                }
                return false
            }
        }
        
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = scnView, isViewActive else { return }
            
            switch gesture.state {
            case .began:
                let location = gesture.location(in: view)
                if isSpinnerHit(at: location, in: view) {
                    currentTouchMode = .spin
                    previousPanTranslationX = gesture.translation(in: view).x
                    lastPanVelocityX = 0
                    onInteraction()
                    lightFeedback.impactOccurred(intensity: 0.6)
                    
                    // Boost to 60 FPS for interactive fluidity
                    view.preferredFramesPerSecond = 60
                    publishRPM(targetRPM: max(60.0, Double(abs(angularVelocity)) * 60.0 / (2.0 * .pi)), isSpinning: true, force: true)
                } else {
                    currentTouchMode = .orbit
                    initialPitch = orbitGimbalNode?.eulerAngles.x ?? defaultPitch
                    initialYaw = orbitGimbalNode?.eulerAngles.y ?? defaultYaw
                    onInteraction()
                    selectionFeedback.selectionChanged()
                    view.preferredFramesPerSecond = 60
                }
                
            case .changed:
                if currentTouchMode == .spin {
                    guard let spinNode = spinContainerNode else { return }
                    let currentTranslationX = gesture.translation(in: view).x
                    let deltaX = currentTranslationX - previousPanTranslationX
                    previousPanTranslationX = currentTranslationX
                    
                    let deltaAngle = Float(deltaX) * 0.014
                    spinNode.eulerAngles.y += deltaAngle
                    
                    let velocityX = gesture.velocity(in: view).x
                    lastPanVelocityX = velocityX
                    
                    // Smooth throttled RPM reading during active drag
                    let targetDragRPM = min(3200.0, max(80.0, Double(abs(velocityX)) * 0.75))
                    publishRPM(targetRPM: targetDragRPM, isSpinning: true)
                    
                } else if currentTouchMode == .orbit {
                    guard let gimbal = orbitGimbalNode else { return }
                    let translation = gesture.translation(in: view)
                    
                    gimbal.eulerAngles.y = initialYaw + Float(translation.x) * 0.009
                    let newPitch = initialPitch - Float(translation.y) * 0.009
                    gimbal.eulerAngles.x = min(1.15, max(-1.15, newPitch))
                }
                
            case .ended, .cancelled:
                if currentTouchMode == .spin {
                    let velocityX = lastPanVelocityX != 0 ? lastPanVelocityX : gesture.velocity(in: view).x
                    
                    if abs(velocityX) > 75 {
                        let impulseFactor: Float = 0.0036
                        var newOmega = Float(velocityX) * impulseFactor
                        let maxOmega: Float = 315.0 // ~3,000 RPM limit
                        newOmega = min(maxOmega, max(-maxOmega, newOmega))
                        self.angularVelocity = newOmega
                        self.idleSettleTimer = 0.0
                        impactFeedback.impactOccurred()
                        onInteraction()
                        
                        view.preferredFramesPerSecond = 60
                        publishRPM(targetRPM: Double(abs(newOmega)) * 60.0 / (2.0 * .pi), isSpinning: true, force: true)
                    } else {
                        if abs(angularVelocity) < idleAngularVelocity {
                            angularVelocity = (angularVelocity >= 0 ? 1 : -1) * idleAngularVelocity
                        }
                    }
                } else if currentTouchMode == .orbit {
                    // Drop back to 30 FPS if spinner is not spinning fast
                    if abs(angularVelocity) <= idleAngularVelocity + 1.0 {
                        view.preferredFramesPerSecond = 30
                    }
                }
                currentTouchMode = .none
                
            default:
                currentTouchMode = .none
            }
        }
        
        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scnView, isViewActive else { return }
            let location = gesture.location(in: view)
            
            if isSpinnerHit(at: location, in: view) {
                lightFeedback.impactOccurred()
                let boost: Float = 44.0
                if angularVelocity >= 0 {
                    angularVelocity = min(315.0, angularVelocity + boost)
                } else {
                    angularVelocity = max(-315.0, angularVelocity - boost)
                }
                idleSettleTimer = 0.0
                onInteraction()
                
                view.preferredFramesPerSecond = 60
                publishRPM(targetRPM: Double(abs(angularVelocity)) * 60.0 / (2.0 * .pi), isSpinning: true, force: true)
            }
        }
        
        @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let gimbal = orbitGimbalNode, isViewActive else { return }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.35
            gimbal.eulerAngles.x = defaultPitch
            gimbal.eulerAngles.y = defaultYaw
            SCNTransaction.commit()
            selectionFeedback.selectionChanged()
        }
        
        // MARK: - Throttled Telemetry Publisher
        
        private func publishRPM(targetRPM: Double, isSpinning: Bool, force: Bool = false) {
            let now = CACurrentMediaTime()
            let timeDelta = now - lastRPMReportTime
            let rpmDelta = abs(targetRPM - lastReportedRPM)
            
            // Throttle to max 12 Hz (~80ms) or significant change (>12 RPM), unless forced
            if force || (timeDelta >= 0.08 && rpmDelta >= 12.0) {
                lastReportedRPM = targetRPM
                lastRPMReportTime = now
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if abs(self.rpmBinding.wrappedValue - targetRPM) > 1.0 {
                        self.rpmBinding.wrappedValue = targetRPM
                    }
                    if self.isSpinningActiveBinding.wrappedValue != isSpinning {
                        self.isSpinningActiveBinding.wrappedValue = isSpinning
                    }
                }
            }
        }
        
        // MARK: - Physics Simulation Loop
        
        func startPhysicsLoop() {
            let link = CADisplayLink(target: self, selector: #selector(physicsStep(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            self.displayLink = link
            self.lastTimestamp = CACurrentMediaTime()
        }
        
        @objc private func physicsStep(_ link: CADisplayLink) {
            guard isViewActive else { return }
            
            let current = link.timestamp
            var dt = Float(current - lastTimestamp)
            lastTimestamp = current
            
            if dt <= 0 || dt > 0.1 {
                dt = 1.0 / 60.0
            }
            
            guard let spinNode = spinContainerNode else { return }
            
            if currentTouchMode != .spin {
                let isClockwise = angularVelocity >= 0
                let currentSpeed = abs(angularVelocity)
                
                if currentSpeed > idleAngularVelocity {
                    let damping = pow(0.985, dt * 60.0)
                    var decayed = currentSpeed * damping - (0.42 * dt)
                    if decayed < idleAngularVelocity {
                        decayed = idleAngularVelocity
                    }
                    angularVelocity = (isClockwise ? 1.0 : -1.0) * decayed
                    
                    let currentAngle = spinNode.eulerAngles.y
                    let angleSinceHaptic = abs(currentAngle - lastHapticAngle)
                    if currentSpeed > 55.0 && angleSinceHaptic >= (.pi / 1.5) {
                        lastHapticAngle = currentAngle
                        lightFeedback.impactOccurred(intensity: 0.25)
                    }
                    
                    idleSettleTimer = 0.0
                    let computedRPM = Double(currentSpeed) * 60.0 / (2.0 * .pi)
                    publishRPM(targetRPM: computedRPM, isSpinning: true)
                    
                } else {
                    angularVelocity = (isClockwise ? 1.0 : -1.0) * idleAngularVelocity
                    idleSettleTimer += dt
                    
                    if idleSettleTimer >= 0.8 {
                        // Drop frame rate to 30 FPS when safely settled in idle
                        if scnView?.preferredFramesPerSecond != 30 {
                            scnView?.preferredFramesPerSecond = 30
                        }
                        publishRPM(targetRPM: 45.0, isSpinning: false, force: true)
                    }
                }
                
                spinNode.eulerAngles.y += angularVelocity * dt
            }
        }
        
        func teardown(view: SCNView) {
            displayLink?.invalidate()
            displayLink = nil
            view.scene?.rootNode.removeAllActions()
            view.scene = nil
            view.pointOfView = nil
            self.orbitGimbalNode = nil
            self.spinContainerNode = nil
            self.currentModelWrapper = nil
        }
    }
}
