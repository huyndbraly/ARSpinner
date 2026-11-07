import Foundation
import AVFoundation

/// Manages the rear camera flashlight (torch) to illuminate physical environments for AR tracking in low-light conditions.
@MainActor
final class TorchService: ObservableObject {
    static let shared = TorchService()
    
    @Published private(set) var isTorchOn: Bool = false
    
    private init() {}
    
    /// Whether the device has a physical torch available.
    var isTorchAvailable: Bool {
        guard let device = AVCaptureDevice.default(for: .video) else { return false }
        return device.hasTorch && device.isTorchAvailable
    }
    
    /// Toggles the rear camera flashlight on or off.
    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            // Simulator or device without torch: toggle state for UI feedback
            isTorchOn.toggle()
            AppLogger.general.info("Torch toggled in simulated environment: \(self.isTorchOn)")
            return
        }
        
        do {
            try device.lockForConfiguration()
            if isTorchOn {
                device.torchMode = .off
                isTorchOn = false
                AppLogger.general.info("Flashlight turned OFF.")
            } else {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                isTorchOn = true
                AppLogger.general.info("Flashlight turned ON.")
            }
            device.unlockForConfiguration()
        } catch {
            AppLogger.general.warning("Failed to configure torch mode: \(error.localizedDescription)")
        }
    }
    
    /// Turns off the flashlight (e.g. when view disappears or app is backgrounded).
    func turnOff() {
        guard isTorchOn else { return }
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            isTorchOn = false
            return
        }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = .off
            isTorchOn = false
            device.unlockForConfiguration()
            AppLogger.general.info("Flashlight turned OFF.")
        } catch {
            AppLogger.general.warning("Failed to turn off torch: \(error.localizedDescription)")
        }
    }
}

