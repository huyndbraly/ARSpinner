import Foundation
import ARKit
import Combine

/// State of AR tracking for user-facing feedback.
enum TrackingStatus: Equatable, Sendable {
    case initializing
    case normal
    case limited(reason: String)
    case notAvailable
    case interrupted
    
    var userInstruction: String {
        switch self {
        case .initializing:
            return "Initializing AR tracking..."
        case .normal:
            return "Tracking normal. Ready to place."
        case .limited(let reason):
            return "Tracking limited: \(reason)"
        case .notAvailable:
            return "AR tracking is currently not available."
        case .interrupted:
            return "AR session interrupted. Please wait..."
        }
    }
}

/// Coordinates ARSession lifecycle, camera tracking state, and session interruptions.
@MainActor
final class ARSessionCoordinator: NSObject, ARSessionDelegate {
    
    // MARK: - Published State
    
    @Published private(set) var trackingStatus: TrackingStatus = .initializing
    @Published private(set) var hasDetectedPlanes: Bool = false
    
    private var detectedPlaneCount: Int = 0
    
    // MARK: - ARSessionDelegate (nonisolated protocol requirements)
    
    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state = camera.trackingState
        Task { @MainActor [weak self] in
            self?.handleTrackingStateChange(state)
        }
    }
    
    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let count = anchors.compactMap { $0 as? ARPlaneAnchor }.count
        if count > 0 {
            Task { @MainActor [weak self] in
                self?.handlePlanesAdded(count: count)
            }
        }
    }
    
    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let count = anchors.compactMap { $0 as? ARPlaneAnchor }.count
        if count > 0 {
            Task { @MainActor [weak self] in
                self?.handlePlanesRemoved(count: count)
            }
        }
    }
    
    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor [weak self] in
            self?.trackingStatus = .interrupted
            AppLogger.ar.warning("AR session was interrupted.")
        }
    }
    
    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor [weak self] in
            self?.trackingStatus = .initializing
            AppLogger.ar.info("AR session interruption ended.")
        }
    }
    
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.trackingStatus = .notAvailable
            AppLogger.ar.error("ARSession failed with error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - State Handlers
    
    private func handleTrackingStateChange(_ state: ARCamera.TrackingState) {
        switch state {
        case .notAvailable:
            trackingStatus = .notAvailable
            AppLogger.ar.warning("AR tracking not available.")
            
        case .limited(let reason):
            let description: String
            switch reason {
            case .excessiveMotion:
                description = "Slow down device movement."
            case .insufficientFeatures:
                description = "Point camera at a textured surface."
            case .initializing:
                description = "Move iPhone slowly to map area."
            case .relocalizing:
                description = "Relocalizing session..."
            @unknown default:
                description = "Move device slowly."
            }
            trackingStatus = .limited(reason: description)
            AppLogger.ar.info("AR tracking limited: \(description)")
            
        case .normal:
            trackingStatus = .normal
            AppLogger.ar.info("AR tracking normal.")
        }
    }
    
    private func handlePlanesAdded(count: Int) {
        detectedPlaneCount += count
        hasDetectedPlanes = true
        AppLogger.ar.info("Detected new horizontal plane(s). Total: \(self.detectedPlaneCount)")
    }
    
    private func handlePlanesRemoved(count: Int) {
        detectedPlaneCount = max(0, detectedPlaneCount - count)
        hasDetectedPlanes = detectedPlaneCount > 0
    }
}
