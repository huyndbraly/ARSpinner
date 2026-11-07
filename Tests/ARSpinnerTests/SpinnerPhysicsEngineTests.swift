import XCTest
import simd
@testable import ARSpinner

final class SpinnerPhysicsEngineTests: XCTestCase {
    
    var engine: SpinnerPhysicsEngine!
    
    override func setUp() {
        super.setUp()
        engine = SpinnerPhysicsEngine(configuration: .standard)
    }
    
    func testInitialAngularVelocityIsZero() {
        XCTAssertEqual(engine.state.angularVelocity, 0.0, accuracy: 1e-6)
        XCTAssertEqual(engine.state.angle, 0.0, accuracy: 1e-6)
        XCTAssertEqual(engine.state.totalRevolutions, 0.0, accuracy: 1e-6)
        XCTAssertFalse(engine.state.isSpinning)
    }
    
    func testAngularImpulseInitiatesRotation() {
        let impulse: Float = 0.001 // N·m·s
        engine.applyAngularImpulse(impulse)
        
        XCTAssertGreaterThan(engine.state.angularVelocity, 0.0)
        XCTAssertTrue(engine.state.isSpinning)
        
        let expectedOmega = impulse / engine.state.momentOfInertia
        XCTAssertEqual(engine.state.angularVelocity, expectedOmega, accuracy: 1e-2)
    }
    
    func testCoDirectionalImpulseIncreasesSpeed() {
        engine.setAngularVelocity(20.0)
        let initialSpeed = engine.state.angularVelocity
        
        engine.applyAngularImpulse(0.0005)
        XCTAssertGreaterThan(engine.state.angularVelocity, initialSpeed)
    }
    
    func testCounterDirectionalImpulseDecreasesSpeed() {
        engine.setAngularVelocity(30.0)
        let initialSpeed = engine.state.angularVelocity
        
        // Counter impulse (negative)
        engine.applyAngularImpulse(-0.0003)
        XCTAssertLessThan(engine.state.angularVelocity, initialSpeed)
    }
    
    func testCounterDirectionalImpulseCanReverseDirection() {
        engine.setAngularVelocity(5.0)
        // Strong negative impulse
        let strongOpposingImpulse: Float = -0.002
        engine.applyAngularImpulse(strongOpposingImpulse)
        
        XCTAssertLessThan(engine.state.angularVelocity, 0.0)
    }
    
    func testFrictionReducesAngularVelocityOverTime() {
        engine.setAngularVelocity(50.0)
        let initialSpeed = engine.state.angularVelocity
        
        // Simulate 0.5 seconds
        for _ in 0..<30 {
            engine.update(deltaTime: 1.0 / 60.0)
        }
        
        XCTAssertLessThan(engine.state.angularVelocity, initialSpeed)
        XCTAssertGreaterThan(engine.state.angularVelocity, 0.0)
    }
    
    func testSpinnerStopsCleanlyBelowThreshold() {
        // Set speed very close to stop threshold
        let config = engine.configuration
        engine.setAngularVelocity(config.stopThreshold * 0.9)
        
        // Update a few steps with no applied torque
        for _ in 0..<10 {
            engine.update(deltaTime: 1.0 / 60.0)
        }
        
        XCTAssertEqual(engine.state.angularVelocity, 0.0, accuracy: 1e-6)
        XCTAssertFalse(engine.state.isSpinning)
    }
    
    func testMaxAngularVelocityIsClamped() {
        let maxOmega = engine.configuration.maxAngularVelocity
        // Apply massive impulse
        engine.applyAngularImpulse(10.0)
        
        XCTAssertEqual(engine.state.angularVelocity, maxOmega, accuracy: 1e-5)
    }
    
    func testResetClearsAllState() {
        engine.setAngularVelocity(60.0)
        for _ in 0..<20 {
            engine.update(deltaTime: 1.0 / 60.0)
        }
        
        XCTAssertGreaterThan(engine.state.totalRevolutions, 0.0)
        
        engine.reset()
        
        XCTAssertEqual(engine.state.angularVelocity, 0.0, accuracy: 1e-6)
        XCTAssertEqual(engine.state.angle, 0.0, accuracy: 1e-6)
        XCTAssertEqual(engine.state.totalRevolutions, 0.0, accuracy: 1e-6)
        XCTAssertFalse(engine.state.isSpinning)
    }
    
    func testFPSIndependence() {
        // Compare decay over 1.0 simulated second between 30 FPS, 60 FPS, and 120 FPS
        let initialOmega: Float = 60.0
        
        // 1. Run at 30 FPS
        let engine30 = SpinnerPhysicsEngine(configuration: .standard)
        engine30.setAngularVelocity(initialOmega)
        let dt30 = 1.0 / 30.0
        for _ in 0..<30 {
            engine30.update(deltaTime: dt30)
        }
        let omega30 = engine30.state.angularVelocity
        
        // 2. Run at 60 FPS
        let engine60 = SpinnerPhysicsEngine(configuration: .standard)
        engine60.setAngularVelocity(initialOmega)
        let dt60 = 1.0 / 60.0
        for _ in 0..<60 {
            engine60.update(deltaTime: dt60)
        }
        let omega60 = engine60.state.angularVelocity
        
        // 3. Run at 120 FPS
        let engine120 = SpinnerPhysicsEngine(configuration: .standard)
        engine120.setAngularVelocity(initialOmega)
        let dt120 = 1.0 / 120.0
        for _ in 0..<120 {
            engine120.update(deltaTime: dt120)
        }
        let omega120 = engine120.state.angularVelocity
        
        // All should be within 1.5% of each other due to sub-stepping
        let diff30to60 = abs(omega30 - omega60) / omega60
        let diff60to120 = abs(omega60 - omega120) / omega60
        
        XCTAssertLessThan(diff30to60, 0.015, "30 FPS vs 60 FPS relative difference is \(diff30to60)")
        XCTAssertLessThan(diff60to120, 0.015, "60 FPS vs 120 FPS relative difference is \(diff60to120)")
    }
}

