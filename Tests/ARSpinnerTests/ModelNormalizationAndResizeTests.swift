import XCTest
import simd
import RealityKit
@testable import ARSpinner

final class ModelNormalizationAndResizeTests: XCTestCase {
    
    func testModelNormalizationFromLargeRawBounds() {
        // Raw USDZ model dimensions: ~1.96m X, 0.33m Y, 1.96m Z, center at (0.05, 0.02, -0.03)
        let rawExtents = simd_float3(1.96, 0.33, 1.96)
        let rawCenter = simd_float3(0.05, 0.02, -0.03)
        let targetDiameter: Float = 0.076 // 7.6 cm
        
        let result = USDZSpinnerEntityFactory.calculateNormalization(
            extents: rawExtents,
            center: rawCenter,
            targetDiameter: targetDiameter
        )
        
        XCTAssertNotNil(result)
        guard let norm = result else { return }
        
        // 1. Uniform scale factor must equal target / horizontalSpan
        let expectedScale: Float = 0.076 / 1.96
        XCTAssertEqual(norm.scale, expectedScale, accuracy: Float(1e-6))
        
        // 2. Scaled horizontal dimension must equal target diameter
        let scaledX: Float = rawExtents.x * norm.scale
        XCTAssertEqual(scaledX, targetDiameter, accuracy: Float(1e-5))
        
        // 3. Center offset must be exactly -center * scale to place pivot at (0, 0, 0)
        XCTAssertEqual(norm.centerOffset.x, -rawCenter.x * norm.scale, accuracy: Float(1e-6))
        XCTAssertEqual(norm.centerOffset.y, -rawCenter.y * norm.scale, accuracy: Float(1e-6))
        XCTAssertEqual(norm.centerOffset.z, -rawCenter.z * norm.scale, accuracy: Float(1e-6))
        
        // 4. Collision box must safely envelope the model
        XCTAssertGreaterThanOrEqual(norm.collisionBoxSize.x, targetDiameter)
        XCTAssertGreaterThanOrEqual(norm.collisionBoxSize.z, targetDiameter)
        XCTAssertGreaterThan(norm.collisionBoxSize.y, 0.005)
    }
    
    func testNormalizationRejectsDegenerateOrNonFiniteBounds() {
        let zeroExtents = simd_float3(0, 0, 0)
        let center = simd_float3(0, 0, 0)
        
        XCTAssertNil(USDZSpinnerEntityFactory.calculateNormalization(
            extents: zeroExtents,
            center: center,
            targetDiameter: 0.076
        ))
        
        let nanExtents = simd_float3(Float.nan, 1.0, 1.0)
        XCTAssertNil(USDZSpinnerEntityFactory.calculateNormalization(
            extents: nanExtents,
            center: center,
            targetDiameter: 0.076
        ))
        
        let zeroTarget = USDZSpinnerEntityFactory.calculateNormalization(
            extents: simd_float3(1, 1, 1),
            center: center,
            targetDiameter: 0.0
        )
        XCTAssertNil(zeroTarget)
    }
    
    func testConfigurationDiameterConstraints() {
        XCTAssertEqual(SpinnerConfiguration.defaultDiameter, 0.076, accuracy: Float(1e-4))
        XCTAssertEqual(SpinnerConfiguration.minDiameter, 0.040, accuracy: Float(1e-4))
        XCTAssertEqual(SpinnerConfiguration.maxDiameter, 0.150, accuracy: Float(1e-4))
        XCTAssertEqual(SpinnerConfiguration.diameterStep, 0.001, accuracy: Float(1e-5))
        
        var config = SpinnerConfiguration.standard
        XCTAssertEqual(config.diameter, 0.076, accuracy: Float(1e-4))
        XCTAssertEqual(config.outerRadius, 0.038, accuracy: Float(1e-4))
        
        // Modifying diameter updates outerRadius proportionally
        config.diameter = 0.100 // 10 cm
        XCTAssertEqual(config.outerRadius, 0.050, accuracy: Float(1e-4))
        
        // Modifying outerRadius updates diameter
        config.outerRadius = 0.045
        XCTAssertEqual(config.diameter, 0.090, accuracy: Float(1e-4))
    }
    
    func testGiantSpinnerNormalizationAndCollisionBounds() {
        let center = simd_float3(0, 0, 0)
        let extents = simd_float3(0.1, 0.015, 0.1) // 10 cm raw model
        
        // Scale to 15.0 meters
        let giantNorm = USDZSpinnerEntityFactory.calculateNormalization(
            extents: extents,
            center: center,
            targetDiameter: 15.0
        )
        
        XCTAssertNotNil(giantNorm)
        if let norm = giantNorm {
            XCTAssertEqual(norm.scale, 150.0, accuracy: Float(1e-3))
            XCTAssertEqual(norm.collisionBoxSize.x, 15.0 * 1.05, accuracy: Float(1e-3))
            XCTAssertEqual(norm.collisionBoxSize.z, 15.0 * 1.05, accuracy: Float(1e-3))
            XCTAssertGreaterThan(norm.collisionBoxSize.y, 0.016)
        }
    }
    
    func testResizeDuringActiveSpinPreservesState() {
        let engine = SpinnerPhysicsEngine(configuration: .standard)
        engine.setAngularVelocity(45.0)
        
        // Simulate a few physics frames
        for _ in 0..<15 {
            engine.update(deltaTime: 1.0 / 60.0)
        }
        
        let speedBefore = engine.state.angularVelocity
        let angleBefore = engine.state.angle
        let revsBefore = engine.state.totalRevolutions
        
        // Change diameter via configuration
        var newConfig = engine.configuration
        newConfig.diameter = 0.120 // Resize to 12 cm
        engine.updateConfiguration(newConfig)
        
        // State must remain continuous without jumping or resetting to 0
        XCTAssertEqual(engine.state.angularVelocity, speedBefore, accuracy: Float(1e-6))
        XCTAssertEqual(engine.state.angle, angleBefore, accuracy: Float(1e-6))
        XCTAssertEqual(engine.state.totalRevolutions, revsBefore, accuracy: 1e-6)
        XCTAssertTrue(engine.state.isSpinning)
        XCTAssertEqual(engine.configuration.diameter, 0.120, accuracy: Float(1e-4))
    }
    
    @MainActor
    func testPlacementIndicatorSizeSynchronization() {
        let arView = ARView(frame: .zero)
        let sceneController = SpinnerSceneController(configuration: .standard)
        let placement = ARPlacementManager(
            arView: arView,
            sceneController: sceneController,
            initialDiameter: 0.076
        )
        
        XCTAssertEqual(placement.currentIndicatorDiameter, 0.076, accuracy: 1e-4)
        
        // Update diameter before placement (synchronizes reticle indicator)
        placement.updateIndicatorDiameter(0.120)
        XCTAssertEqual(placement.currentIndicatorDiameter, 0.120, accuracy: 1e-4)
    }
    
    @MainActor
    func testViewModelDiameterUpdatesAndClamping() {
        let viewModel = ARExperienceViewModel()
        
        // Default standard state (7.6 cm)
        XCTAssertEqual(viewModel.spinnerDiameter, SpinnerConfiguration.defaultDiameter, accuracy: 1e-3)
        
        // Update diameter within bounds (12 cm)
        viewModel.setDiameter(0.120)
        XCTAssertEqual(viewModel.spinnerDiameter, 0.120, accuracy: 1e-3)
        
        // Clamps to max 15 cm
        viewModel.setDiameter(0.500)
        XCTAssertEqual(viewModel.spinnerDiameter, SpinnerConfiguration.maxDiameter, accuracy: 1e-3)
        
        // Clamps to min 4 cm
        viewModel.setDiameter(0.010)
        XCTAssertEqual(viewModel.spinnerDiameter, SpinnerConfiguration.minDiameter, accuracy: 1e-3)
        
        // Reset restores 7.6 cm
        viewModel.resetDiameter()
        XCTAssertEqual(viewModel.spinnerDiameter, SpinnerConfiguration.defaultDiameter, accuracy: 1e-3)
    }
}
