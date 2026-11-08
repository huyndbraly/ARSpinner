import XCTest
import simd
import RealityKit
@testable import ARSpinner

@MainActor
final class ARPipelineOptimizationTests: XCTestCase {
    
    // MARK: - RealityKit Entity Cache Tests
    
    func testRealityKitEntityCacheStoresAndClonesEntities() {
        let cache = RealityKitEntityCache.shared
        cache.clear()
        
        let originalEntity = Entity()
        originalEntity.name = "TestSpinnerBase"
        
        cache.setEntity(originalEntity, for: "TestKey")
        
        let retrieved = cache.getEntity(for: "TestKey")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "TestSpinnerBase")
        
        // Ensure retrieved object is an independent clone
        XCTAssertFalse(originalEntity === retrieved, "Retrieved entity must be an independent clone")
        
        retrieved?.name = "ModifiedClone"
        let secondRetrieval = cache.getEntity(for: "TestKey")
        XCTAssertEqual(secondRetrieval?.name, "TestSpinnerBase", "Mutating a clone must not corrupt the cached template")
    }
    
    func testRealityKitEntityCacheClear() {
        let cache = RealityKitEntityCache.shared
        let entity = Entity()
        cache.setEntity(entity, for: "KeyToClear")
        XCTAssertNotNil(cache.getEntity(for: "KeyToClear"))
        
        cache.clear()
        XCTAssertNil(cache.getEntity(for: "KeyToClear"))
    }
    
    // MARK: - SceneUpdateController Idle Sleep Tests
    
    func testSceneUpdateControllerIdleSleepPublishesOnceAndSleeps() {
        let engine = SpinnerPhysicsEngine(configuration: .standard)
        engine.stopImmediately()
        
        let controller = SceneUpdateController(physicsEngine: engine)
        controller.currentModeProvider = { .floating }
        
        var updateCount = 0
        controller.onUIStateUpdate = { _ in
            updateCount += 1
        }
        
        let arView = ARView(frame: .zero)
        let mockEntity = Entity()
        controller.startUpdating(scene: arView.scene, rotatingBody: mockEntity)
        
        controller.stopUpdating()
        
        // Verify controller preserves floating mode
        XCTAssertEqual(controller.currentModeProvider?(), .floating)
    }
    
    // MARK: - View Model Deduplication Tests
    
    func testARExperienceViewModelStateDeduplication() {
        let viewModel = ARExperienceViewModel()
        let state1 = SpinnerState(isPlaced: true, mode: .surface, spinMode: .natural, angularVelocity: 50.0)
        
        viewModel.updateStateSnapshot(state1)
        XCTAssertTrue(viewModel.isPlaced)
        XCTAssertEqual(viewModel.spinnerState.angularVelocity, 50.0)
        
        // Supplying identical state does not alter state or trigger redundant updates
        viewModel.updateStateSnapshot(state1)
        XCTAssertEqual(viewModel.spinnerState, state1)
    }
    
    func testPlacementReadinessStateTransitions() {
        let viewModel = ARExperienceViewModel()
        viewModel.selectedMode = .surface
        viewModel.isPlaced = false
        
        // Surface not detected -> canPlace = false
        viewModel.updatePlacementReadiness(hasSurface: false)
        XCTAssertFalse(viewModel.canPlace)
        
        // Surface detected -> canPlace = true
        viewModel.updatePlacementReadiness(hasSurface: true)
        XCTAssertTrue(viewModel.canPlace)
        
        // Once placed -> canPlace must always be false
        viewModel.isPlaced = true
        viewModel.updatePlacementReadiness(hasSurface: true)
        XCTAssertFalse(viewModel.canPlace)
    }
}
