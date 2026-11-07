import XCTest
import RealityKit
import simd
@testable import ARSpinner

@MainActor
final class SpinnerCatalogAndSelectionTests: XCTestCase {
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        // Reset test UserDefaults key
        UserDefaults.standard.removeObject(forKey: "com.arspinner.selected_spinner_model_id")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "com.arspinner.selected_spinner_model_id")
        super.tearDown()
    }
    
    // MARK: - 1 & 2. Discovery & Deduplication Tests
    
    func testCatalogDiscoversModelsAndDeduplicates() {
        let catalog = SpinnerCatalog(bundle: .main)
        
        // Must discover at least our built-in models
        XCTAssertGreaterThanOrEqual(catalog.availableModels.count, 2, "Catalog must discover both Spinner and Spinner2.")
        
        // Check for deduplication
        let ids = catalog.availableModels.map { $0.id.lowercased() }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "Catalog must not contain duplicate model IDs.")
        
        // Verify default model is present and primary
        XCTAssertEqual(catalog.defaultModel.id, "Spinner")
        XCTAssertFalse(catalog.defaultModel.displayNameEn.isEmpty)
        XCTAssertFalse(catalog.defaultModel.displayNameVi.isEmpty)
    }
    
    // MARK: - 3. Corrupt & Missing Resource Fallback
    
    func testMissingOrCorruptModelHandlingDoesNotCrash() {
        let invalidDescriptor = SpinnerModelDescriptor(
            id: "NonExistentSpinner",
            fileName: "NonExistentSpinner.usdz",
            assetName: "NonExistentSpinner",
            fileURL: URL(fileURLWithPath: "/invalid/path/NonExistentSpinner.usdz"),
            displayNameEn: "Non Existent",
            displayNameVi: "Không Tồn Tại"
        )
        
        let factory = USDZSpinnerEntityFactory(
            modelDescriptor: invalidDescriptor,
            defaultDiameter: 0.076,
            configuration: .standard
        )
        
        // Must gracefully fall back to procedural geometry without crashing
        let hierarchy = factory.createSpinnerEntity(targetDiameter: 0.076)
        XCTAssertNotNil(hierarchy.root)
        XCTAssertNotNil(hierarchy.rotatingBody)
        XCTAssertNotNil(hierarchy.collisionEntity)
        XCTAssertEqual(hierarchy.root.name, "SpinnerRoot")
    }
    
    // MARK: - 4, 5, 6. Bounds, Normalization, Pivot & Numerical Safety
    
    func testModelNormalizationAndPivotCenteringForBothModels() {
        // Model 1: Raw bounds span ~1.96m, thickness ~0.33m
        let extents1 = simd_float3(1.9594, 0.3284, 1.9562)
        let center1 = simd_float3(-0.0196, -0.0187, -0.0198)
        let targetDiameter: Float = 0.076 // 7.6 cm
        
        guard let norm1 = USDZSpinnerEntityFactory.calculateNormalization(
            extents: extents1,
            center: center1,
            targetDiameter: targetDiameter
        ) else {
            XCTFail("Normalization for Model 1 failed")
            return
        }
        
        XCTAssertTrue(norm1.scale.isFinite && norm1.scale > 0)
        XCTAssertTrue(VectorMath.isFinite(norm1.centerOffset))
        XCTAssertTrue(norm1.scaledThickness.isFinite && norm1.scaledThickness > 0)
        XCTAssertTrue(VectorMath.isFinite(norm1.collisionBoxSize))
        XCTAssertEqual(norm1.scale * max(extents1.x, extents1.z), targetDiameter, accuracy: Float(1e-5))
        
        // Model 2: Raw bounds span ~1.0018m, thickness ~0.1724m, center (0, 0, 0.0076)
        let extents2 = simd_float3(1.0018, 0.1724, 0.9430)
        let center2 = simd_float3(0.0, 0.0002, 0.0076)
        
        guard let norm2 = USDZSpinnerEntityFactory.calculateNormalization(
            extents: extents2,
            center: center2,
            targetDiameter: targetDiameter
        ) else {
            XCTFail("Normalization for Model 2 failed")
            return
        }
        
        XCTAssertTrue(norm2.scale.isFinite && norm2.scale > 0)
        XCTAssertTrue(VectorMath.isFinite(norm2.centerOffset))
        XCTAssertEqual(norm2.scale * max(extents2.x, extents2.z), targetDiameter, accuracy: Float(1e-5))
        XCTAssertNotEqual(norm1.scale, norm2.scale, "Different raw models must have independent scale factors.")
    }
    
    // MARK: - 7 & 8. In-Place Model Swapping Preserves World Anchor
    
    func testInPlaceModelSwappingPreservesWorldAnchorAndUpdatesCollision() {
        let sceneController = SpinnerSceneController(configuration: .standard)
        let arView = ARView(frame: .zero)
        
        // Place spinner initially at fixed world position
        let initialWorldPos = simd_float3(0.5, 0.2, -0.8)
        var worldMatrix = matrix_identity_float4x4
        worldMatrix.columns.3 = simd_float4(initialWorldPos, 1.0)
        
        sceneController.placeSpinner(at: worldMatrix, mode: .surface, targetDiameter: 0.076, in: arView)
        XCTAssertTrue(sceneController.isPlaced)
        
        guard let anchor = sceneController.anchorManager.activeAnchor else {
            XCTFail("Anchor must exist after placement")
            return
        }
        let anchorPosBefore = anchor.position(relativeTo: nil)
        XCTAssertEqual(anchorPosBefore.x, initialWorldPos.x, accuracy: Float(1e-4))
        XCTAssertEqual(anchorPosBefore.y, initialWorldPos.y, accuracy: Float(1e-4))
        XCTAssertEqual(anchorPosBefore.z, initialWorldPos.z, accuracy: Float(1e-4))
        
        let oldRotatingBody = sceneController.anchorManager.rotatingBody
        
        // Swap to Spinner2 model
        let spinner2Descriptor = SpinnerModelDescriptor(
            id: "Spinner2",
            fileName: "Spinner2.usdz",
            assetName: "Spinner2",
            displayNameEn: "Stealth Dual-Tone Spinner",
            displayNameVi: "Con quay Thép phối màu Stealth",
            estimatedMass: 0.078
        )
        
        let factory2 = USDZSpinnerEntityFactory(
            modelDescriptor: spinner2Descriptor,
            defaultDiameter: 0.076,
            configuration: .standard
        )
        let newHierarchy = factory2.createSpinnerEntity(targetDiameter: 0.076)
        
        sceneController.swapSpinnerModel(
            with: factory2,
            hierarchy: newHierarchy,
            descriptor: spinner2Descriptor,
            targetDiameter: 0.076
        )
        
        // 1. World anchor must be the exact same instance
        XCTAssertEqual(sceneController.anchorManager.activeAnchor, anchor, "World anchor must not be re-created or changed.")
        
        // 2. World position must be strictly preserved
        let anchorPosAfter = anchor.position(relativeTo: nil)
        XCTAssertEqual(anchorPosAfter.x, initialWorldPos.x, accuracy: Float(1e-4))
        XCTAssertEqual(anchorPosAfter.y, initialWorldPos.y, accuracy: Float(1e-4))
        XCTAssertEqual(anchorPosAfter.z, initialWorldPos.z, accuracy: Float(1e-4))
        
        // 3. Rotating body must be updated to the new model entity
        XCTAssertNotEqual(sceneController.anchorManager.rotatingBody, oldRotatingBody, "Rotating body must be replaced with the new model.")
        XCTAssertEqual(sceneController.anchorManager.rotatingBody?.name, "SpinnerBody")
        
        // 4. Collision entity must be present and updated
        XCTAssertNotNil(sceneController.anchorManager.collisionEntity)
        XCTAssertEqual(sceneController.anchorManager.collisionEntity?.name, "SpinnerCollision")
        
        // 5. Angular velocity must be safely reset to 0
        XCTAssertEqual(sceneController.physicsEngine.state.angularVelocity, 0.0, "Angular velocity must be reset to 0 on model swap.")
    }
    
    // MARK: - 9 & 10. Per-Model Mass & Moment of Inertia
    
    func testModelSwapUpdatesConfigurationMassAndMomentOfInertia() {
        let sceneController = SpinnerSceneController(configuration: .standard)
        let initialInertia = sceneController.physicsEngine.state.momentOfInertia
        
        let heavyDescriptor = SpinnerModelDescriptor(
            id: "HeavySpinner",
            fileName: "HeavySpinner.usdz",
            assetName: "HeavySpinner",
            displayNameEn: "Heavy Brass Spinner",
            displayNameVi: "Con quay Đồng nặng",
            estimatedMass: 0.120 // 120 grams
        )
        
        let heavyFactory = USDZSpinnerEntityFactory(
            modelDescriptor: heavyDescriptor,
            defaultDiameter: 0.076,
            configuration: sceneController.physicsEngine.configuration
        )
        let hierarchy = heavyFactory.createSpinnerEntity(targetDiameter: 0.076)
        
        sceneController.swapSpinnerModel(
            with: heavyFactory,
            hierarchy: hierarchy,
            descriptor: heavyDescriptor,
            targetDiameter: 0.076
        )
        
        // Configuration mass must be updated
        XCTAssertEqual(sceneController.physicsEngine.configuration.totalMass, 0.120, accuracy: Float(1e-4))
        
        // Moment of inertia must be proportionally higher for heavier model
        let newInertia = sceneController.physicsEngine.state.momentOfInertia
        XCTAssertGreaterThan(newInertia, initialInertia, "Moment of inertia must increase proportionally with model mass.")
    }
    
    // MARK: - 11. Persistence: Save & Restore Selection
    
    func testPersistenceSaveAndRestoreModelSelection() {
        let catalog = SpinnerCatalog(bundle: .main)
        let manager = SpinnerSelectionManager(catalog: catalog)
        
        // Initially default
        XCTAssertEqual(manager.selectedModel.id, catalog.defaultModel.id)
        
        // Select Spinner2
        guard let model2 = catalog.model(withId: "Spinner2") else {
            XCTFail("Spinner2 must exist in catalog")
            return
        }
        manager.setSelectedModelDirectly(model2)
        XCTAssertEqual(manager.selectedModel.id, "Spinner2")
        
        // Re-instantiate a new selection manager (simulating app relaunch)
        let restoredManager = SpinnerSelectionManager(catalog: catalog)
        XCTAssertEqual(restoredManager.selectedModel.id, "Spinner2", "Selection must be persisted across launches via UserDefaults.")
    }
    
    // MARK: - 12. Race Condition Prevention
    
    func testRapidConsecutiveModelSelectionDiscardsStaleRequests() async {
        let catalog = SpinnerCatalog(bundle: .main)
        let manager = SpinnerSelectionManager(catalog: catalog)
        let sceneController = SpinnerSceneController(configuration: .standard)
        
        guard let model1 = catalog.model(withId: "Spinner"),
              let model2 = catalog.model(withId: "Spinner2") else {
            XCTFail("Models must exist in catalog")
            return
        }
        
        let expectation = expectation(description: "Second model loaded")
        
        // Rapidly dispatch selection for model 1, then immediately model 2
        manager.selectModel(model1, sceneController: sceneController, targetDiameter: 0.076)
        manager.selectModel(model2, sceneController: sceneController, targetDiameter: 0.076) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        
        // Wait for latest request to finish loading
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Final selected model must be the latest requested (model 2)
        XCTAssertEqual(manager.selectedModel.id, model2.id, "Latest requested model must prevail in race condition.")
        XCTAssertFalse(manager.isLoading)
        XCTAssertNil(manager.loadingModelId)
    }
    
    // MARK: - 13 & 14. Swapped Model Operates With Natural and Continuous Spin
    
    func testSwappedModelFunctionsInBothNaturalAndContinuousModes() {
        let sceneController = SpinnerSceneController(configuration: .standard)
        
        guard let model2 = SpinnerCatalog(bundle: .main).model(withId: "Spinner2") else {
            XCTFail("Spinner2 must exist")
            return
        }
        
        let factory2 = USDZSpinnerEntityFactory(
            modelDescriptor: model2,
            defaultDiameter: 0.076,
            configuration: .standard
        )
        let hierarchy = factory2.createSpinnerEntity(targetDiameter: 0.076)
        
        sceneController.swapSpinnerModel(
            with: factory2,
            hierarchy: hierarchy,
            descriptor: model2,
            targetDiameter: 0.076
        )
        
        // 1. Natural Spin: test impulse and spindown
        sceneController.setSpinMode(.natural)
        sceneController.physicsEngine.applyAngularImpulse(0.001)
        XCTAssertGreaterThan(sceneController.physicsEngine.state.angularVelocity, 0.0)
        
        let initialSpeed = sceneController.physicsEngine.state.angularVelocity
        for _ in 0..<10 {
            sceneController.physicsEngine.update(deltaTime: 1.0 / 60.0)
        }
        XCTAssertLessThan(sceneController.physicsEngine.state.angularVelocity, initialSpeed, "Natural spin must decelerate with bearing friction on new model.")
        
        // 2. Continuous Spin: stacks velocity up to 2,000 RPM
        sceneController.setSpinMode(.continuous)
        for _ in 0..<20 {
            sceneController.physicsEngine.applyAngularImpulse(0.005)
        }
        let capOmega = SpinMode.continuousMaxAngularVelocity
        XCTAssertEqual(sceneController.physicsEngine.state.angularVelocity, capOmega, accuracy: Float(1e-3), "New model must accelerate up to continuous 2,000 RPM limit.")
        XCTAssertEqual(sceneController.physicsEngine.state.rpm, 2000.0, accuracy: Float(1.0))
    }
    
    // MARK: - Auto-formatting Tests
    
    func testFriendlyNameFormatting() {
        XCTAssertEqual(SpinnerModelDescriptor.formatFriendlyName(from: "Spinner2.usdz"), "Spinner 2")
        XCTAssertEqual(SpinnerModelDescriptor.formatFriendlyName(from: "custom_brass_spinner.usdz"), "Custom Brass Spinner")
        XCTAssertEqual(SpinnerModelDescriptor.formatFriendlyName(from: "dragon-claw-spinner"), "Dragon Claw Spinner")
        XCTAssertEqual(SpinnerModelDescriptor.formatFriendlyName(from: "NeonTriSpinner.usdz"), "Neon Tri Spinner")
    }
}

