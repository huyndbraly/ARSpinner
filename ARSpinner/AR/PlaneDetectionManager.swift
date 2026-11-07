import Foundation
import ARKit

/// Inspects and classifies horizontal planes discovered by ARKit.
@MainActor
final class PlaneDetectionManager {
    
    private(set) var detectedPlanes: [UUID: ARPlaneAnchor] = [:]
    
    var hasUsablePlanes: Bool {
        return !detectedPlanes.isEmpty
    }
    
    func addPlane(_ anchor: ARPlaneAnchor) {
        detectedPlanes[anchor.identifier] = anchor
    }
    
    func updatePlane(_ anchor: ARPlaneAnchor) {
        detectedPlanes[anchor.identifier] = anchor
    }
    
    func removePlane(_ anchor: ARPlaneAnchor) {
        detectedPlanes.removeValue(forKey: anchor.identifier)
    }
    
    func reset() {
        detectedPlanes.removeAll()
    }
}

