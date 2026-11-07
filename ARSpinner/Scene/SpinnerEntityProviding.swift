import Foundation
import RealityKit

/// Protocol defining the contract for generating, loading, normalizing, and dynamically scaling 3D Spinner entities.
@MainActor
protocol SpinnerEntityProviding: AnyObject {
    
    /// Current physical outer diameter of the spinner in meters.
    var currentDiameter: Float { get }
    
    /// Current physical outer radius of the spinner in meters (diameter / 2).
    var currentRadius: Float { get }
    
    /// Current physical thickness of the spinner in meters.
    var thickness: Float { get }
    
    /// Instantiates the complete 3D Spinner Entity hierarchy normalized to `targetDiameter`.
    /// - Parameter targetDiameter: Target physical diameter in meters (e.g. 0.076m = 7.6cm).
    /// - Returns: A tuple containing root, rotating body, and collision entity.
    func createSpinnerEntity(targetDiameter: Float) -> (root: Entity, rotatingBody: Entity, collisionEntity: Entity)
    
    /// Dynamically resizes the existing spinner in place without replacing anchors or resetting physics.
    /// - Parameters:
    ///   - newDiameter: New target diameter in meters.
    ///   - root: The stationary root entity.
    ///   - rotatingBody: The rotating rigid body entity.
    ///   - collisionEntity: The collision container entity.
    func updateDiameter(_ newDiameter: Float, on root: Entity, rotatingBody: Entity, collisionEntity: Entity)
}

extension SpinnerEntityProviding {
    var currentRadius: Float {
        return currentDiameter * 0.5
    }
}
