import Foundation
import RealityKit
import ARKit

/// Master controller managing the 3D scene, spinner entity, physics bridge, and rendering loop.
@MainActor
final class SpinnerSceneController {
    
    // MARK: - Subcomponents
    
    let anchorManager: SpinnerAnchorManager
    let physicsEngine: SpinnerPhysicsEngine
    let updateController: SceneUpdateController
    private(set) var entityFactory: SpinnerEntityProviding
    
    // MARK: - State
    
    private(set) var isPlaced: Bool = false
    private(set) var currentMode: SpinnerMode = .surface
    
    /// Callback invoked when a 3D model swap completes.
    var onModelSwapped: (() -> Void)?
    
    var currentDiameter: Float {
        return entityFactory.currentDiameter
    }
    
    var currentRadius: Float {
        return entityFactory.currentRadius
    }
    
    var currentThickness: Float {
        return entityFactory.thickness
    }
    
    // MARK: - Initialization
    
    init(
        configuration: SpinnerConfiguration = .standard,
        modelDescriptor: SpinnerModelDescriptor? = nil,
        entityFactory: SpinnerEntityProviding? = nil
    ) {
        self.physicsEngine = SpinnerPhysicsEngine(configuration: configuration)
        self.updateController = SceneUpdateController(physicsEngine: physicsEngine)
        self.anchorManager = SpinnerAnchorManager()
        if let factory = entityFactory {
            self.entityFactory = factory
        } else if let descriptor = modelDescriptor {
            self.entityFactory = USDZSpinnerEntityFactory(
                modelDescriptor: descriptor,
                defaultDiameter: configuration.diameter,
                configuration: configuration
            )
        } else {
            self.entityFactory = USDZSpinnerEntityFactory(
                assetName: "Spinner",
                defaultDiameter: configuration.diameter,
                configuration: configuration
            )
        }
    }
    
    // MARK: - Scene Actions
    
    /// Spawns and anchors the spinner at the specified world transform.
    func placeSpinner(
        at transform: simd_float4x4,
        mode: SpinnerMode,
        targetDiameter: Float? = nil,
        in arView: ARView
    ) {
        self.currentMode = mode
        let diameter = targetDiameter ?? physicsEngine.configuration.diameter
        
        let (_, rotatingBody, _) = anchorManager.placeSpinner(
            at: transform,
            targetDiameter: diameter,
            in: arView.scene,
            factory: entityFactory
        )
        
        // Start physics update loop
        updateController.startUpdating(scene: arView.scene, rotatingBody: rotatingBody)
        isPlaced = true
        
        AppLogger.scene.info("SpinnerSceneController placed spinner in mode: \(mode.rawValue), diameter: \(diameter * 100.0, format: .fixed(precision: 1)) cm")
    }
    
    /// Dynamically resizes the spinner in-place without replacing anchors or resetting physics state.
    func updateDiameter(_ newDiameter: Float) {
        guard newDiameter.isFinite, newDiameter >= SpinnerConfiguration.minDiameter, newDiameter <= SpinnerConfiguration.maxDiameter else {
            return
        }
        
        // 1. Update visual model scale and collision shape in-place
        anchorManager.updateDiameter(newDiameter)
        
        // 2. Update configuration diameter without touching angular velocity or angle
        var updatedConfig = physicsEngine.configuration
        updatedConfig.diameter = newDiameter
        physicsEngine.updateConfiguration(updatedConfig)
        
        AppLogger.scene.info("Resized spinner diameter to \(newDiameter * 100.0, format: .fixed(precision: 1)) cm in-place.")
    }
    
    /// Removes the spinner from the scene and stops physics updates.
    func removeSpinner() {
        updateController.stopUpdating()
        anchorManager.removeSpinner()
        physicsEngine.stopImmediately()
        isPlaced = false
        AppLogger.scene.info("SpinnerSceneController removed spinner.")
    }
    
    /// Resets the spinner rotation to idle without removing it from the scene.
    func resetRotation() {
        physicsEngine.reset()
    }
    
    /// Updates the interaction spin mode (Natural vs Continuous) without resetting angle or position.
    func setSpinMode(_ mode: SpinMode) {
        physicsEngine.setSpinMode(mode)
        AppLogger.scene.info("SpinnerSceneController updated spin mode to: \(mode.rawValue)")
    }
    
    /// Swaps the entity provider (e.g. for USDZ assets or updated configuration).
    func setEntityFactory(_ factory: SpinnerEntityProviding) {
        self.entityFactory = factory
    }
    
    /// Swaps the active spinner model in-place (or prepares it for placement) without interrupting AR tracking.
    func swapSpinnerModel(
        with newFactory: SpinnerEntityProviding,
        hierarchy: (root: Entity, rotatingBody: Entity, collisionEntity: Entity),
        descriptor: SpinnerModelDescriptor,
        targetDiameter: Float
    ) {
        self.entityFactory = newFactory
        
        // 1. Update physics engine mass, diameter, thickness, and inertia
        var updatedConfig = physicsEngine.configuration
        updatedConfig.diameter = targetDiameter
        updatedConfig.totalMass = descriptor.estimatedMass
        updatedConfig.thickness = newFactory.thickness
        physicsEngine.updateConfiguration(updatedConfig)
        
        // 2. If already placed in scene, swap the entity on the existing world anchor
        if isPlaced, let activeScene = anchorManager.activeAnchor?.scene {
            // Swap on the existing world anchor
            anchorManager.swapSpinnerModel(newHierarchy: hierarchy, factory: newFactory)
            
            // Re-subscribe updateController with new rotating body
            updateController.startUpdating(scene: activeScene, rotatingBody: hierarchy.rotatingBody)
            
            // Reset angular velocity to 0 to prevent erratic rotation
            physicsEngine.stopImmediately()
            physicsEngine.reset()
            
            AppLogger.scene.info("Swapped model '\(descriptor.id)' on placed spinner at world position: \(String(describing: self.anchorManager.worldPosition))")
        } else {
            AppLogger.scene.info("Prepared model '\(descriptor.id)' for upcoming placement.")
        }
        
        onModelSwapped?()
    }
    
    /// Updates configuration and propagates to physics engine.
    func updateConfiguration(_ config: SpinnerConfiguration) {
        physicsEngine.updateConfiguration(config)
        self.entityFactory = USDZSpinnerEntityFactory(
            assetName: "Spinner",
            defaultDiameter: config.diameter,
            configuration: config
        )
    }
}
