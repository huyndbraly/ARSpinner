import Foundation
import RealityKit
import ARKit

/// Manages AnchorEntity creation, attachment, and lifecycle within the RealityKit scene.
@MainActor
final class SpinnerAnchorManager {
    
    // MARK: - Properties
    
    private(set) var activeAnchor: AnchorEntity?
    private(set) var rootEntity: Entity?
    private(set) var rotatingBody: Entity?
    private(set) var collisionEntity: Entity?
    private(set) var currentFactory: SpinnerEntityProviding?
    private weak var activeScene: RealityKit.Scene?
    
    // MARK: - Lifecycle
    
    /// Attaches the spinner entity hierarchy to a world-space transform.
    /// Ensures spinner stays strictly fixed in world coordinates and does NOT move with camera.
    func placeSpinner(
        at worldTransform: simd_float4x4,
        targetDiameter: Float,
        in scene: RealityKit.Scene,
        factory: SpinnerEntityProviding
    ) -> (root: Entity, rotatingBody: Entity, collisionEntity: Entity) {
        // Clean up any existing anchor to prevent duplicate entities
        removeSpinner()
        
        self.activeScene = scene
        self.currentFactory = factory
        
        // 1. Create a World Anchor locked to world origin (identity matrix).
        // This ensures anchor.transform defines the exact, unpolluted world-space transform,
        // avoiding nested coordinate transforms that invert or rotate forward movement sideways.
        let anchor = AnchorEntity(world: matrix_identity_float4x4)
        anchor.name = "SpinnerWorldAnchor"
        anchor.transform = Transform(matrix: worldTransform)
        
        // 2. Instantiate spinner hierarchy from factory
        let (root, rotating, collision) = factory.createSpinnerEntity(targetDiameter: targetDiameter)
        anchor.addChild(root)
        
        // 3. Add to RealityKit scene
        scene.addAnchor(anchor)
        
        self.activeAnchor = anchor
        self.rootEntity = root
        self.rotatingBody = rotating
        self.collisionEntity = collision
        
        AppLogger.scene.info("Spinner placed at world transform successfully (diameter: \(targetDiameter * 100.0, format: .fixed(precision: 1)) cm).")
        return (root: root, rotatingBody: rotating, collisionEntity: collision)
    }
    
    /// Replaces the active spinner entity hierarchy on the existing world anchor in-place.
    /// Strictly preserves world anchor transform, orientation, and AR tracking state.
    func swapSpinnerModel(
        newHierarchy: (root: Entity, rotatingBody: Entity, collisionEntity: Entity),
        factory: SpinnerEntityProviding
    ) {
        self.currentFactory = factory
        
        guard let anchor = activeAnchor else { return }
        
        // 1. Unlink and remove old root entity
        if let oldRoot = rootEntity {
            anchor.removeChild(oldRoot)
        }
        
        // 2. Attach new normalized root entity to the existing world anchor
        anchor.addChild(newHierarchy.root)
        
        // 3. Update active references
        self.rootEntity = newHierarchy.root
        self.rotatingBody = newHierarchy.rotatingBody
        self.collisionEntity = newHierarchy.collisionEntity
        
        AppLogger.scene.info("Swapped spinner model in-place on existing world anchor.")
    }
    
    /// Updates the physical and visual diameter in-place without replacing anchors or resetting physics state.
    func updateDiameter(_ newDiameter: Float) {
        guard let root = rootEntity,
              let rotating = rotatingBody,
              let collision = collisionEntity,
              let factory = currentFactory else {
            return
        }
        factory.updateDiameter(newDiameter, on: root, rotatingBody: rotating, collisionEntity: collision)
    }
    
    /// Completely removes the active spinner anchor and cleans up scene resources.
    func removeSpinner() {
        if let anchor = activeAnchor {
            activeScene?.removeAnchor(anchor)
            anchor.removeFromParent()
            activeAnchor = nil
            rootEntity = nil
            rotatingBody = nil
            collisionEntity = nil
            currentFactory = nil
            activeScene = nil
            AppLogger.scene.info("Spinner anchor removed from scene.")
        }
    }
    
    /// Returns the world position of the spinner if placed.
    var worldPosition: simd_float3? {
        guard let anchor = activeAnchor else { return nil }
        return anchor.position(relativeTo: nil)
    }
    
    /// Returns the world rotation axis (Y-axis) of the spinner.
    var worldRotationAxis: simd_float3? {
        guard let anchor = activeAnchor else { return nil }
        let orientation = anchor.orientation(relativeTo: nil)
        return QuaternionHelper.rotatedYAxis(from: orientation)
    }
    
    /// Returns the complete world orientation quaternion of the spinner anchor.
    var worldOrientation: simd_quatf? {
        guard let anchor = activeAnchor else { return nil }
        return anchor.orientation(relativeTo: nil)
    }
}
