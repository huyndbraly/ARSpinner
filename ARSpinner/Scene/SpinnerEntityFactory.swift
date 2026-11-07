import Foundation
import UIKit
import RealityKit
import simd

/// Procedural factory that constructs a high-detail 3D Fidget Spinner model
/// using procedural primitives and physically based metallic materials.
@MainActor
final class SpinnerEntityFactory: SpinnerEntityProviding {
    
    // MARK: - Properties
    
    private(set) var currentDiameter: Float
    private(set) var thickness: Float
    private let config: SpinnerConfiguration
    private var baseDiameter: Float
    
    // MARK: - Initialization
    
    init(configuration: SpinnerConfiguration = .standard) {
        self.config = configuration
        self.currentDiameter = configuration.diameter
        self.baseDiameter = configuration.diameter
        self.thickness = configuration.thickness
    }
    
    // MARK: - Factory Methods
    
    func createSpinnerEntity(targetDiameter: Float = 0.076) -> (root: Entity, rotatingBody: Entity, collisionEntity: Entity) {
        let diameter = (targetDiameter.isFinite && targetDiameter > 0.01) ? targetDiameter : currentDiameter
        self.currentDiameter = diameter
        self.baseDiameter = config.diameter > 0.01 ? config.diameter : 0.076
        
        // 1. Root Entity: Stationary container in world space
        let rootEntity = Entity()
        rootEntity.name = "SpinnerRoot"
        
        // 2. Collision Entity
        let collisionEntity = Entity()
        collisionEntity.name = "SpinnerCollision"
        let collisionBoxSize = simd_float3(
            diameter * 1.05,
            max(0.016, thickness * 1.6),
            diameter * 1.05
        )
        let collisionShape = ShapeResource.generateBox(size: collisionBoxSize)
        collisionEntity.components.set(CollisionComponent(shapes: [collisionShape]))
        rootEntity.addChild(collisionEntity)
        
        // 3. Rotating Body Entity: Rigid body containing central hub, arms, and 3 wings
        let rotatingBody = Entity()
        rotatingBody.name = "SpinnerBody"
        rootEntity.addChild(rotatingBody)
        
        // Apply initial scale relative to base dimensions
        let scaleFactor = diameter / baseDiameter
        rotatingBody.scale = simd_float3(scaleFactor, scaleFactor, scaleFactor)
        
        // 4. Materials
        let darkTitaniumMat = SimpleMaterial(
            color: UIColor(red: 0.14, green: 0.15, blue: 0.18, alpha: 1.0),
            roughness: 0.22,
            isMetallic: true
        )
        
        let chromeSteelMat = SimpleMaterial(
            color: UIColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1.0),
            roughness: 0.12,
            isMetallic: true
        )
        
        let brassGoldMat = SimpleMaterial(
            color: UIColor(red: 0.88, green: 0.72, blue: 0.32, alpha: 1.0),
            roughness: 0.25,
            isMetallic: true
        )
        
        let centerCapMat = SimpleMaterial(
            color: UIColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0),
            roughness: 0.35,
            isMetallic: true
        )
        
        // 5. Central Hub & Bearing
        buildCentralHub(
            parent: rotatingBody,
            bodyMat: darkTitaniumMat,
            steelMat: chromeSteelMat,
            capMat: centerCapMat
        )
        
        // 6. Build 3 Symmetrical Wings and Counterweights
        let wingCount = config.wingCount
        let angleStep = (2.0 * Float.pi) / Float(wingCount)
        
        for i in 0..<wingCount {
            let angle = Float(i) * angleStep
            buildWing(
                parent: rotatingBody,
                angle: angle,
                bodyMat: darkTitaniumMat,
                brassMat: brassGoldMat,
                steelMat: chromeSteelMat
            )
        }
        
        return (root: rootEntity, rotatingBody: rotatingBody, collisionEntity: collisionEntity)
    }
    
    func updateDiameter(
        _ newDiameter: Float,
        on root: Entity,
        rotatingBody: Entity,
        collisionEntity: Entity
    ) {
        guard newDiameter.isFinite, newDiameter > 0.01, baseDiameter > 0.001 else { return }
        self.currentDiameter = newDiameter
        
        let scale = newDiameter / baseDiameter
        rotatingBody.scale = simd_float3(scale, scale, scale)
        
        let currentThickness = config.thickness * scale
        self.thickness = currentThickness
        
        let collisionBoxSize = simd_float3(
            newDiameter * 1.05,
            max(0.016, currentThickness * 1.6),
            newDiameter * 1.05
        )
        collisionEntity.components.set(CollisionComponent(shapes: [ShapeResource.generateBox(size: collisionBoxSize)]))
    }
    
    // MARK: - Private Construction Helpers
    
    private func buildCentralHub(
        parent: Entity,
        bodyMat: SimpleMaterial,
        steelMat: SimpleMaterial,
        capMat: SimpleMaterial
    ) {
        let hubEntity = Entity()
        hubEntity.name = "CenterBearingHub"
        
        let hubMesh = ProceduralMeshHelper.generateCylinder(
            height: thickness,
            radius: config.centerBearingRadius
        )
        let hubModel = ModelEntity(mesh: hubMesh, materials: [bodyMat])
        hubEntity.addChild(hubModel)
        
        let raceMesh = ProceduralMeshHelper.generateCylinder(
            height: thickness * 1.04,
            radius: config.centerBearingRadius * 0.75
        )
        let raceModel = ModelEntity(mesh: raceMesh, materials: [steelMat])
        hubEntity.addChild(raceModel)
        
        let capMesh = ProceduralMeshHelper.generateCylinder(
            height: thickness * 1.15,
            radius: config.centerBearingRadius * 0.55
        )
        let capModel = ModelEntity(mesh: capMesh, materials: [capMat])
        hubEntity.addChild(capModel)
        
        let pipMesh = MeshResource.generateSphere(radius: 0.0022)
        let topPip = ModelEntity(mesh: pipMesh, materials: [steelMat])
        topPip.position = [0, (thickness * 1.15 * 0.5), 0]
        hubEntity.addChild(topPip)
        
        let bottomPip = ModelEntity(mesh: pipMesh, materials: [steelMat])
        bottomPip.position = [0, -(thickness * 1.15 * 0.5), 0]
        hubEntity.addChild(bottomPip)
        
        parent.addChild(hubEntity)
    }
    
    private func buildWing(
        parent: Entity,
        angle: Float,
        bodyMat: SimpleMaterial,
        brassMat: SimpleMaterial,
        steelMat: SimpleMaterial
    ) {
        let wingEntity = Entity()
        wingEntity.name = "Wing_\(Int(VectorMath.radiansToDegrees(angle)))"
        
        let distance = config.lobeOffsetDistance
        let lobeX = distance * cos(angle)
        let lobeZ = distance * sin(angle)
        
        let armLength = distance - (config.centerBearingRadius * 0.4)
        let armWidth = config.centerBearingRadius * 0.85
        let armMesh = MeshResource.generateBox(
            width: armWidth,
            height: thickness * 0.88,
            depth: armLength
        )
        let armModel = ModelEntity(mesh: armMesh, materials: [bodyMat])
        
        let armMidDist = (config.centerBearingRadius * 0.5) + (armLength * 0.5)
        armModel.position = [
            armMidDist * cos(angle),
            0,
            armMidDist * sin(angle)
        ]
        armModel.orientation = simd_quatf(angle: (Float.pi * 0.5) - angle, axis: [0, 1, 0])
        wingEntity.addChild(armModel)
        
        let lobeMesh = ProceduralMeshHelper.generateCylinder(
            height: thickness,
            radius: config.lobeRadius
        )
        let lobeModel = ModelEntity(mesh: lobeMesh, materials: [bodyMat])
        lobeModel.position = [lobeX, 0, lobeZ]
        wingEntity.addChild(lobeModel)
        
        let counterweightMesh = ProceduralMeshHelper.generateCylinder(
            height: thickness * 1.05,
            radius: config.lobeRadius * 0.72
        )
        let counterweightModel = ModelEntity(mesh: counterweightMesh, materials: [brassMat])
        counterweightModel.position = [lobeX, 0, lobeZ]
        wingEntity.addChild(counterweightModel)
        
        let cutoutCoreMesh = ProceduralMeshHelper.generateCylinder(
            height: thickness * 1.08,
            radius: config.lobeRadius * 0.38
        )
        let cutoutCoreModel = ModelEntity(mesh: cutoutCoreMesh, materials: [steelMat])
        cutoutCoreModel.position = [lobeX, 0, lobeZ]
        wingEntity.addChild(cutoutCoreModel)
        
        parent.addChild(wingEntity)
    }
}
