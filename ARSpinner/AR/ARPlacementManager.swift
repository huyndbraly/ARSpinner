import Foundation
import RealityKit
import ARKit

/// Coordinates Surface and Floating placement logic, placement indicator rendering, and transform computation.
@MainActor
final class ARPlacementManager {
    
    // MARK: - Dependencies
    
    private weak var arView: ARView?
    private let raycastManager: ARRaycastManager
    private let sceneController: SpinnerSceneController
    
    // MARK: - Placement Indicator Entity
    
    private var indicatorAnchor: AnchorEntity?
    private var indicatorModel: ModelEntity?
    private var centerPipEntity: ModelEntity?
    
    // MARK: - State
    
    private(set) var currentMode: SpinnerMode = .surface
    private(set) var latestSurfaceTransform: simd_float4x4?
    private(set) var currentIndicatorDiameter: Float
    
    // Base radius of the procedural cylinder mesh (0.5m = 1.0m base diameter)
    private static let baseUnitRadius: Float = 0.5
    
    // MARK: - Initialization
    
    init(
        arView: ARView,
        sceneController: SpinnerSceneController,
        initialDiameter: Float = SpinnerConfiguration.defaultDiameter
    ) {
        self.arView = arView
        self.sceneController = sceneController
        self.currentIndicatorDiameter = initialDiameter
        self.raycastManager = ARRaycastManager(arView: arView)
        setupIndicator(diameter: initialDiameter)
    }
    
    // MARK: - Placement Indicator Setup
    
    private func setupIndicator(diameter: Float) {
        guard let arView = arView else { return }
        
        let anchor = AnchorEntity(world: matrix_identity_float4x4)
        anchor.name = "PlacementIndicatorAnchor"
        anchor.isEnabled = false
        
        // Unit circular disc indicator mesh (base radius = 0.5m -> base diameter = 1.0m)
        let ringMesh = ProceduralMeshHelper.generateCylinder(height: 0.0015, radius: Self.baseUnitRadius)
        let ringMaterial = SimpleMaterial(
            color: UIColor.systemCyan.withAlphaComponent(0.60),
            roughness: 0.5,
            isMetallic: false
        )
        let ringEntity = ModelEntity(mesh: ringMesh, materials: [ringMaterial])
        ringEntity.name = "PlacementIndicatorModel"
        // Scale to exactly match spinner diameter from the start
        ringEntity.scale = simd_float3(diameter, 1.0, diameter)
        anchor.addChild(ringEntity)
        
        // Inner pip dot (remains crisp at origin without expanding with ring scaling)
        let dotMesh = MeshResource.generateSphere(radius: 0.004)
        let dotMaterial = SimpleMaterial(color: UIColor.white.withAlphaComponent(0.95), isMetallic: false)
        let dotEntity = ModelEntity(mesh: dotMesh, materials: [dotMaterial])
        dotEntity.name = "PlacementIndicatorDot"
        anchor.addChild(dotEntity)
        
        arView.scene.addAnchor(anchor)
        
        self.indicatorAnchor = anchor
        self.indicatorModel = ringEntity
        self.centerPipEntity = dotEntity
    }
    
    /// Synchronizes the placement indicator size with the current spinner diameter in real-time.
    func updateIndicatorDiameter(_ diameter: Float) {
        guard diameter.isFinite, diameter > 0.01 else { return }
        self.currentIndicatorDiameter = diameter
        indicatorModel?.scale = simd_float3(diameter, 1.0, diameter)
    }
    
    // MARK: - Frame Update
    
    /// Updates the placement indicator based on camera view and selected mode.
    func updatePlacementState() {
        guard !sceneController.isPlaced, let arView = arView else {
            indicatorAnchor?.isEnabled = false
            return
        }
        
        if currentMode == .surface {
            // Raycast from screen center
            let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            if let result = raycastManager.raycast(from: screenCenter) {
                let surfaceTransform = result.worldTransform
                latestSurfaceTransform = surfaceTransform
                if let safeT = SafeTransform.create(from: surfaceTransform) {
                    indicatorAnchor?.transform = safeT
                    indicatorAnchor?.isEnabled = true
                } else {
                    indicatorAnchor?.isEnabled = false
                }
            } else {
                latestSurfaceTransform = nil
                indicatorAnchor?.isEnabled = false
            }
        } else {
            // In Floating mode, show preview reticle suspended 45cm in front of camera
            if let floatingMatrix = computeFloatingTransform(),
               let safeT = SafeTransform.create(from: floatingMatrix) {
                indicatorAnchor?.transform = safeT
                indicatorAnchor?.isEnabled = true
            } else {
                indicatorAnchor?.isEnabled = false
            }
        }
    }
    
    // MARK: - Placement Execution
    
    /// Places the spinner according to the active mode or an optional screen tap location.
    @discardableResult
    func placeSpinner(atScreenPoint screenPoint: CGPoint? = nil, targetDiameter: Float? = nil) -> Bool {
        guard !sceneController.isPlaced, let arView = arView else {
            return false
        }
        
        let placementTransform: simd_float4x4
        
        switch currentMode {
        case .surface:
            let surfaceTransform: simd_float4x4
            if let tapPoint = screenPoint, let tapResult = raycastManager.raycast(from: tapPoint) {
                surfaceTransform = tapResult.worldTransform
            } else if let cached = latestSurfaceTransform {
                surfaceTransform = cached
            } else {
                AppLogger.ar.warning("Cannot place: No valid surface detected yet.")
                return false
            }
            
            // Elevate along the surface plane's normal vector to rest cleanly on top
            let normal = VectorMath.safeNormalize(simd_float3(
                surfaceTransform.columns.1.x,
                surfaceTransform.columns.1.y,
                surfaceTransform.columns.1.z
            ))
            let halfThickness = sceneController.physicsEngine.configuration.thickness * 0.5
            let offset = normal * halfThickness
            
            var elevatedTransform = surfaceTransform
            elevatedTransform.columns.3.x += offset.x
            elevatedTransform.columns.3.y += offset.y
            elevatedTransform.columns.3.z += offset.z
            placementTransform = elevatedTransform
            
        case .floating:
            guard let floatingMatrix = computeFloatingTransform() else {
                AppLogger.ar.warning("Cannot place: No camera frame available.")
                return false
            }
            placementTransform = floatingMatrix
        }
        
        // Hide placement indicator
        indicatorAnchor?.isEnabled = false
        
        // Anchor spinner in world coordinates
        sceneController.placeSpinner(at: placementTransform, mode: currentMode, targetDiameter: targetDiameter, in: arView)
        return true
    }
    
    /// Computes a stable world-space transform ~45cm in front of camera oriented facing user.
    private func computeFloatingTransform() -> simd_float4x4? {
        guard let arView = arView, let currentFrame = arView.session.currentFrame else {
            return nil
        }
        
        let cameraTransform = currentFrame.camera.transform
        guard VectorMath.isFinite(cameraTransform) else {
            AppLogger.ar.warning("Camera transform contains non-finite values.")
            return nil
        }
        
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let camPos: simd_float3
        let camForward: simd_float3
        
        if let ray = arView.ray(through: screenCenter) {
            camPos = ray.origin
            camForward = VectorMath.safeNormalize(ray.direction)
        } else {
            camForward = -VectorMath.safeNormalize(simd_float3(
                cameraTransform.columns.2.x,
                cameraTransform.columns.2.y,
                cameraTransform.columns.2.z
            ))
            camPos = simd_float3(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            )
        }
        
        // Position at standard tabletop distance (~45cm) directly in front of camera
        let targetPos = camPos + (camForward * SpinnerConfiguration.defaultPlacementDistance)
        
        // Rotation axis stays normal to gravity (local Y = (0, 1, 0))
        let yAxis = simd_float3(0, 1, 0)
        // Horizontal forward vector
        var hForward = simd_float3(camForward.x, 0, camForward.z)
        if simd_length(hForward) < VectorMath.floatEpsilon {
            hForward = simd_float3(0, 0, -1)
        } else {
            hForward = VectorMath.safeNormalize(hForward)
        }
        let xAxis = VectorMath.safeNormalize(VectorMath.cross(yAxis, -hForward))
        let zAxis = VectorMath.safeNormalize(VectorMath.cross(xAxis, yAxis))
        
        var matrix = matrix_identity_float4x4
        matrix.columns.0 = simd_float4(xAxis, 0)
        matrix.columns.1 = simd_float4(yAxis, 0)
        matrix.columns.2 = simd_float4(zAxis, 0)
        matrix.columns.3 = simd_float4(targetPos, 1.0)
        
        return matrix
    }
    
    /// Resets placement and re-enables scanning and indicator.
    func resetPlacement() {
        sceneController.removeSpinner()
        latestSurfaceTransform = nil
        indicatorAnchor?.isEnabled = false
        AppLogger.ar.info("Placement reset requested.")
    }
    
    /// Switches mode and cleans up previous placement if placed.
    func setMode(_ mode: SpinnerMode) {
        if sceneController.isPlaced {
            resetPlacement()
        }
        self.currentMode = mode
    }
}
