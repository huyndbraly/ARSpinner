import Foundation
import SwiftUI
import Combine
import AVFoundation

/// View model driving the AR experience screen, bridging AR state to SwiftUI.
@MainActor
final class ARExperienceViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var selectedMode: SpinnerMode = .surface
    @Published var selectedSpinMode: SpinMode = .natural
    @Published var trackingStatus: TrackingStatus = .initializing
    @Published var isPlaced: Bool = false
    @Published var canPlace: Bool = false
    @Published var spinnerState: SpinnerState = SpinnerState()
    @Published var cameraPermissionGranted: Bool = true
    @Published var isFlashlightOn: Bool = false
    @Published var showSizeControl: Bool = false
    @Published var showModelSelectionSheet: Bool = false
    @Published var spinnerDiameter: Float = SpinnerConfiguration.defaultDiameter
    @Published var isMuted: Bool = true
    @Published var audioVolume: Float = 0.8
    
    private let torchService = TorchService.shared
    
    /// Manager handling catalog models and selection state.
    let selectionManager = SpinnerSelectionManager()
    
    // MARK: - Callbacks to AR Engine
    
    var onPlaceRequested: (() -> Void)?
    var onResetRequested: (() -> Void)?
    var onModeChanged: ((SpinnerMode) -> Void)?
    var onSpinModeChanged: ((SpinMode) -> Void)?
    var onConfigurationChanged: ((SpinnerConfiguration) -> Void)?
    var onDiameterChanged: ((Float) -> Void)?
    var onAudioMuteToggled: ((Bool) -> Void)?
    var onAudioVolumeChanged: ((Float) -> Void)?
    var onStopRequested: (() -> Void)?
    var onModelSelected: ((SpinnerModelDescriptor) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        checkCameraPermission()
    }
    
    // MARK: - Camera Permission
    
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.cameraPermissionGranted = granted
                }
            }
        case .denied, .restricted:
            cameraPermissionGranted = false
        @unknown default:
            cameraPermissionGranted = false
        }
    }
    
    // MARK: - User Intents
    
    func place() {
        onPlaceRequested?()
    }
    
    func reset() {
        onResetRequested?()
        isPlaced = false
        canPlace = false
        showSizeControl = false
        spinnerState = SpinnerState(isPlaced: false, mode: selectedMode, spinMode: selectedSpinMode)
    }
    
    func setMode(_ mode: SpinnerMode) {
        if isPlaced {
            reset()
        }
        selectedMode = mode
        onModeChanged?(mode)
        updatePlacementReadiness()
    }
    
    // MARK: - Flashlight
    
    func toggleFlashlight() {
        torchService.toggleTorch()
        isFlashlightOn = torchService.isTorchOn
    }
    
    func turnOffFlashlight() {
        torchService.turnOff()
        isFlashlightOn = false
    }
    
    func setSpinMode(_ mode: SpinMode) {
        selectedSpinMode = mode
        onSpinModeChanged?(mode)
    }
    
    func toggleMute() {
        isMuted.toggle()
        onAudioMuteToggled?(isMuted)
    }
    
    func setAudioVolume(_ vol: Float) {
        audioVolume = max(0.0, min(1.0, vol))
        onAudioVolumeChanged?(audioVolume)
    }
    
    func updatePlacementReadiness(hasSurface: Bool = false) {
        let newCanPlace: Bool
        if isPlaced {
            newCanPlace = false
        } else {
            switch selectedMode {
            case .surface:
                newCanPlace = hasSurface
            case .floating:
                newCanPlace = (trackingStatus == .normal || trackingStatus == .initializing)
            }
        }
        if canPlace != newCanPlace {
            canPlace = newCanPlace
        }
    }
    
    func updateStateSnapshot(_ state: SpinnerState) {
        if self.isPlaced != state.isPlaced {
            self.isPlaced = state.isPlaced
        }
        if self.selectedSpinMode != state.spinMode {
            self.selectedSpinMode = state.spinMode
        }
        self.spinnerState = state
    }
    
    func stopSpinner() {
        onStopRequested?()
    }
    
    // MARK: - Size Control
    
    func setDiameter(_ diameter: Float) {
        guard diameter.isFinite else { return }
        let clamped = max(SpinnerConfiguration.minDiameter, min(SpinnerConfiguration.maxDiameter, diameter))
        spinnerDiameter = clamped
        onDiameterChanged?(clamped)
    }
    
    func resetDiameter() {
        let target = SpinnerConfiguration.defaultDiameter
        spinnerDiameter = target
        onDiameterChanged?(target)
    }
    
    func toggleSizeControl() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showSizeControl.toggle()
        }
    }
    
    // MARK: - Model Selection
    
    func openModelSelection() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showModelSelectionSheet = true
        }
    }
    
    func selectModel(_ model: SpinnerModelDescriptor) {
        onModelSelected?(model)
    }
}
