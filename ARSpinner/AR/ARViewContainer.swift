import Foundation
import SwiftUI
import RealityKit
import ARKit
import Combine

/// SwiftUI wrapper for RealityKit's ARView, wiring ARKit session, physics simulation,
/// gestures, and haptics into the presentation layer.
struct ARViewContainer: UIViewRepresentable {
    
    @ObservedObject var viewModel: ARExperienceViewModel
    let configuration: SpinnerConfiguration
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, configuration: configuration)
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        
        let coordinator = context.coordinator
        coordinator.setup(with: arView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Updates handled through Coordinator and Combine subscriptions
    }
    
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.tearDown(uiView: uiView)
    }
    
    // MARK: - Coordinator
    
    @MainActor
    final class Coordinator: NSObject {
        private let viewModel: ARExperienceViewModel
        private let configuration: SpinnerConfiguration
        
        private var sessionCoordinator: ARSessionCoordinator?
        private var sceneController: SpinnerSceneController?
        private var placementManager: ARPlacementManager?
        private var gestureController: SpinnerGestureController?
        private var hapticService: HapticFeedbackService?
        private var audioService: AudioFeedbackProviding?
        private weak var arView: ARView?
        
        private var cancellables = Set<AnyCancellable>()
        private var frameSubscription: Cancellable?
        
        init(viewModel: ARExperienceViewModel, configuration: SpinnerConfiguration) {
            self.viewModel = viewModel
            self.configuration = configuration
            super.init()
        }
        
        func setup(with arView: ARView) {
            self.arView = arView
            
            // 1. Initialize Haptic & Audio Services
            let haptics = HapticFeedbackService()
            self.hapticService = haptics
            
            let audio = AudioFeedbackService()
            audio.isMuted = viewModel.isMuted
            audio.volume = viewModel.audioVolume
            self.audioService = audio
            
            // 2. Initialize Scene Controller & Physics Engine using restored model from selectionManager
            let selectedModel = viewModel.selectionManager.selectedModel
            let sceneCtrl = SpinnerSceneController(
                configuration: configuration,
                modelDescriptor: selectedModel
            )
            sceneCtrl.setSpinMode(viewModel.selectedSpinMode)
            self.sceneController = sceneCtrl
            
            // Wire model swap completion callback
            sceneCtrl.onModelSwapped = { [weak self, weak audio, weak haptics] in
                guard let self = self else { return }
                audio?.stop()
                haptics?.onSelection()
                let snapshot = sceneCtrl.physicsEngine.makeStateSnapshot(
                    isPlaced: self.viewModel.isPlaced,
                    mode: self.viewModel.selectedMode
                )
                self.viewModel.updateStateSnapshot(snapshot)
            }
            
            // 3. Connect Scene Update Telemetry to UI, Audio, and Haptics
            sceneCtrl.updateController.onUIStateUpdate = { [weak self, weak audio] snapshot in
                self?.viewModel.updateStateSnapshot(snapshot)
                audio?.updateBearingSound(angularVelocity: snapshot.angularVelocity)
            }
            
            sceneCtrl.updateController.onAngularTick = { [weak haptics] speed in
                haptics?.onRotationalTick(speed: speed)
            }
            
            // 4. Initialize Placement Manager with synchronized initial spinner diameter
            let placement = ARPlacementManager(
                arView: arView,
                sceneController: sceneCtrl,
                initialDiameter: viewModel.spinnerDiameter
            )
            placement.setMode(viewModel.selectedMode)
            self.placementManager = placement
            
            // 5. Initialize Gesture Controller
            let gestures = SpinnerGestureController(
                arView: arView,
                sceneController: sceneCtrl,
                hapticService: haptics,
                audioService: audio
            )
            
            // Wire tap-to-place on AR camera screen
            gestures.onTapToPlace = { [weak self] point in
                guard let self = self, !self.viewModel.isPlaced else { return }
                let success = self.placementManager?.placeSpinner(
                    atScreenPoint: point,
                    targetDiameter: self.viewModel.spinnerDiameter
                ) ?? false
                if success {
                    self.hapticService?.onSelection()
                    self.viewModel.isPlaced = true
                    self.viewModel.canPlace = false
                }
            }
            self.gestureController = gestures
            
            // 6. Configure ARKit Session
            let sessionCoord = ARSessionCoordinator()
            arView.session.delegate = sessionCoord
            self.sessionCoordinator = sessionCoord
            
            // Observe tracking status
            sessionCoord.$trackingStatus
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    guard let self = self else { return }
                    if self.viewModel.trackingStatus != status {
                        self.viewModel.trackingStatus = status
                    }
                    let hasSurface = self.placementManager?.latestSurfaceTransform != nil
                    self.viewModel.updatePlacementReadiness(hasSurface: hasSurface)
                }
                .store(in: &cancellables)
            
            // Start AR World Tracking Session
            startARSession(on: arView)
            
            // 7. Subscribe to scene update to refresh placement indicator
            frameSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
                guard let self = self else { return }
                self.placementManager?.updatePlacementState()
                let hasSurface = self.placementManager?.latestSurfaceTransform != nil
                self.viewModel.updatePlacementReadiness(hasSurface: hasSurface)
            }
            
            // 8. Wire ViewModel Action Callbacks
            bindViewModelActions()
        }
        
        private func startARSession(on arView: ARView) {
            guard ARWorldTrackingConfiguration.isSupported else {
                AppLogger.ar.error("ARWorldTrackingConfiguration is not supported on this device.")
                return
            }
            
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal]
            config.environmentTexturing = .automatic
            
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            AppLogger.ar.info("ARSession started with horizontal plane detection.")
        }
        
        private func bindViewModelActions() {
            viewModel.onPlaceRequested = { [weak self] in
                guard let self = self else { return }
                let success = self.placementManager?.placeSpinner(
                    targetDiameter: self.viewModel.spinnerDiameter
                ) ?? false
                if success {
                    self.hapticService?.onSelection()
                    self.viewModel.isPlaced = true
                    self.viewModel.canPlace = false
                }
            }
            
            viewModel.onResetRequested = { [weak self] in
                self?.placementManager?.resetPlacement()
                self?.sceneController?.physicsEngine.stopImmediately()
                self?.audioService?.stop()
                self?.hapticService?.onSelection()
            }
            
            viewModel.onModeChanged = { [weak self] mode in
                self?.placementManager?.setMode(mode)
                self?.sceneController?.physicsEngine.stopImmediately()
                self?.audioService?.stop()
                self?.hapticService?.onSelection()
            }
            
            viewModel.onSpinModeChanged = { [weak self] spinMode in
                self?.sceneController?.setSpinMode(spinMode)
                self?.hapticService?.onSelection()
            }
            
            viewModel.onConfigurationChanged = { [weak self] newConfig in
                self?.sceneController?.updateConfiguration(newConfig)
            }
            
            viewModel.onDiameterChanged = { [weak self] newDiameter in
                self?.sceneController?.updateDiameter(newDiameter)
                self?.placementManager?.updateIndicatorDiameter(newDiameter)
            }
            
            viewModel.onAudioMuteToggled = { [weak self] muted in
                self?.audioService?.isMuted = muted
            }
            
            viewModel.onAudioVolumeChanged = { [weak self] vol in
                self?.audioService?.volume = vol
            }
            
            viewModel.onStopRequested = { [weak self] in
                self?.sceneController?.physicsEngine.stopImmediately()
                self?.audioService?.stop()
                self?.hapticService?.onTouchContact()
            }
            
            viewModel.onModelSelected = { [weak self] model in
                guard let self = self, let sceneCtrl = self.sceneController else { return }
                self.viewModel.selectionManager.selectModel(
                    model,
                    sceneController: sceneCtrl,
                    targetDiameter: self.viewModel.spinnerDiameter
                ) { [weak self] success in
                    if success {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            self?.viewModel.showModelSelectionSheet = false
                        }
                    }
                }
            }
        }
        
        func tearDown(uiView: ARView) {
            frameSubscription?.cancel()
            frameSubscription = nil
            cancellables.removeAll()
            
            audioService?.stop()
            audioService = nil
            
            gestureController?.teardown()
            gestureController = nil
            
            sceneController?.removeSpinner()
            uiView.session.pause()
            
            viewModel.onPlaceRequested = nil
            viewModel.onResetRequested = nil
            viewModel.onModeChanged = nil
            viewModel.onSpinModeChanged = nil
            viewModel.onConfigurationChanged = nil
            viewModel.onDiameterChanged = nil
            viewModel.onAudioMuteToggled = nil
            viewModel.onAudioVolumeChanged = nil
            viewModel.onStopRequested = nil
            viewModel.onModelSelected = nil
            
            AppLogger.ar.info("ARView dismantled cleanly.")
        }
    }
}
