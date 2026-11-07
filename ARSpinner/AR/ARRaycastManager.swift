import Foundation
import ARKit
import RealityKit

/// Performs raycasting queries against ARKit tracked planes.
@MainActor
final class ARRaycastManager {
    
    private weak var arView: ARView?
    
    init(arView: ARView) {
        self.arView = arView
    }
    
    /// Raycasts from screen point onto horizontal planes.
    /// Prefers existing planes using geometry, then infinite planes, then estimated planes.
    func raycast(from screenPoint: CGPoint) -> ARRaycastResult? {
        guard let arView = arView else { return nil }
        
        // 1. Try existing plane geometry
        let preciseResults = arView.raycast(
            from: screenPoint,
            allowing: .existingPlaneGeometry,
            alignment: .horizontal
        )
        if let first = preciseResults.first {
            return first
        }
        
        // 2. Try existing plane infinite extent
        let extentResults = arView.raycast(
            from: screenPoint,
            allowing: .existingPlaneInfinite,
            alignment: .horizontal
        )
        if let first = extentResults.first {
            return first
        }
        
        // 3. Fallback to estimated plane
        let estimatedResults = arView.raycast(
            from: screenPoint,
            allowing: .estimatedPlane,
            alignment: .horizontal
        )
        return estimatedResults.first
    }
}
