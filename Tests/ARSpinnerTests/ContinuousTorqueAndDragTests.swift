import XCTest
import CoreGraphics
import simd
@testable import ARSpinner

final class ContinuousTorqueAndDragTests: XCTestCase {
    
    let center = simd_float3(0, 0, 0)
    let axis = simd_float3(0, 1, 0)
    let radius: Float = 0.038
    let inertia: Float = 2.5e-5
    
    var engine: SpinnerPhysicsEngine!
    
    override func setUp() {
        super.setUp()
        engine = SpinnerPhysicsEngine(configuration: .standard, spinMode: .natural)
    }
    
    // MARK: - Continuous Torque Calculator Tests
    
    func testStationaryFingerProducesZeroTorque() {
        // Finger placed on wing (r = 0.030m) but remaining completely stationary (screenDist = 0)
        let p0 = simd_float3(0.030, 0, 0)
        let screen0 = CGPoint(x: 200, y: 300)
        
        let result = SwipeImpulseCalculator.calculateContinuousTorque(
            previousWorldPoint: p0,
            currentWorldPoint: p0,
            previousScreenPoint: screen0,
            currentScreenPoint: screen0,
            deltaTime: 0.016,
            spinnerCenter: center,
            rotationAxis: axis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            currentAngularVelocity: 0.0
        )
        
        XCTAssertTrue(result.isStationary, "Zero movement must be classified as stationary.")
        XCTAssertEqual(result.appliedTorque, 0.0, accuracy: Float(1e-7), "Stationary touch must produce exactly 0 torque.")
        XCTAssertEqual(result.fingerVelocity, .zero)
    }
    
    func testMicroMovementBelowThresholdProducesZeroTorque() {
        // Micro-movement (< 0.8 pt screen distance) representing finger tremble / jitter
        let p0 = simd_float3(0.030, 0, 0)
        let p1 = simd_float3(0.0301, 0, 0.0001)
        let screen0 = CGPoint(x: 200, y: 300)
        let screen1 = CGPoint(x: 200.4, y: 300.2) // ~0.45 pt
        
        let result = SwipeImpulseCalculator.calculateContinuousTorque(
            previousWorldPoint: p0,
            currentWorldPoint: p1,
            previousScreenPoint: screen0,
            currentScreenPoint: screen1,
            deltaTime: 0.016,
            spinnerCenter: center,
            rotationAxis: axis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            currentAngularVelocity: 0.0
        )
        
        XCTAssertTrue(result.isStationary)
        XCTAssertEqual(result.appliedTorque, 0.0, accuracy: Float(1e-7))
    }
    
    func testTangentialSwipeProducesPositiveDriveTorque() {
        // Finger on +X axis moving along -Z (tangential in positive counterclockwise direction around +Y)
        let p0 = simd_float3(0.035, 0, 0.0)
        let p1 = simd_float3(0.035, 0, -0.020) // Moved 2 cm in 16 ms (~1.25 m/s along -Z)
        let screen0 = CGPoint(x: 200, y: 300)
        let screen1 = CGPoint(x: 200, y: 250) // 50 pt movement
        
        let result = SwipeImpulseCalculator.calculateContinuousTorque(
            previousWorldPoint: p0,
            currentWorldPoint: p1,
            previousScreenPoint: screen0,
            currentScreenPoint: screen1,
            deltaTime: 0.016,
            spinnerCenter: center,
            rotationAxis: axis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            currentAngularVelocity: 0.0
        )
        
        XCTAssertFalse(result.isStationary)
        XCTAssertGreaterThan(result.tangentialVelocity, 0.5)
        XCTAssertGreaterThan(result.appliedTorque, 0.001, "Tangential swipe must exert positive drive torque.")
        XCTAssertLessThanOrEqual(result.appliedTorque, 0.025, "Torque must be safety-capped.")
    }
    
    func testCounterSwipeExertsBrakingTorque() {
        // Spinner is spinning forward at 40 rad/s (~382 RPM, surface moving towards -Z at +X axis)
        // User swipes in opposite direction (+Z)
        let p0 = simd_float3(0.035, 0, 0.0)
        let p1 = simd_float3(0.035, 0, 0.020) // Swiping backwards (+Z)
        let screen0 = CGPoint(x: 200, y: 300)
        let screen1 = CGPoint(x: 200, y: 350)
        
        let result = SwipeImpulseCalculator.calculateContinuousTorque(
            previousWorldPoint: p0,
            currentWorldPoint: p1,
            previousScreenPoint: screen0,
            currentScreenPoint: screen1,
            deltaTime: 0.016,
            spinnerCenter: center,
            rotationAxis: axis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            currentAngularVelocity: 40.0
        )
        
        XCTAssertLessThan(result.tangentialVelocity, 0.0)
        XCTAssertLessThan(result.appliedTorque, -0.001, "Counter-swipe must produce opposing negative torque to brake spinner.")
    }
    
    // MARK: - Physics Engine Integration & Response Tests
    
    func testNaturalSpinAcceleratesImmediatelyDuringContact() {
        engine.setSpinMode(.natural)
        XCTAssertEqual(engine.state.angularVelocity, 0.0)
        
        // Finger actively driving spinner with continuous torque (0.008 N·m)
        let torque: Float = 0.008
        let t0: TimeInterval = 100.0
        engine.setInputTorque(torque, timestamp: t0)
        
        // Update physics across 5 frames (each 16.6ms) while finger is moving
        for frame in 1...5 {
            let tFrame = t0 + Double(frame) * (1.0 / 60.0)
            engine.setInputTorque(torque, timestamp: tFrame)
            engine.update(deltaTime: 1.0 / 60.0, currentTime: tFrame)
        }
        
        let speedDuringContact = engine.state.angularVelocity
        XCTAssertGreaterThan(speedDuringContact, 10.0, "Spinner must accelerate immediately in real time during finger contact.")
        XCTAssertEqual(engine.state.appliedTorque, torque, accuracy: Float(1e-5))
        
        // When finger lifts: clear input torque
        engine.clearInputTorque()
        XCTAssertEqual(engine.activeInputTorque, 0.0)
        
        // Current velocity is strictly PRESERVED on release (not reset)
        XCTAssertEqual(engine.state.angularVelocity, speedDuringContact, accuracy: Float(1e-5))
        
        // Coasts naturally with bearing friction after release
        engine.update(deltaTime: 0.1, currentTime: t0 + 0.5)
        XCTAssertLessThan(engine.state.angularVelocity, speedDuringContact, "After release, spinner must coast and decelerate naturally with friction.")
    }
    
    func testContinuousSpinOvercomesFrictionAndStacksTorqueTo2000RPM() {
        engine.setSpinMode(.continuous)
        
        // Continuously apply driving torque (0.015 N·m) over 2.0 seconds
        let drivingTorque: Float = 0.015
        var simTime: TimeInterval = 100.0
        let dt: TimeInterval = 1.0 / 60.0
        
        for _ in 0..<120 { // 2.0 seconds of sustained swiping
            simTime += dt
            engine.setInputTorque(drivingTorque, timestamp: simTime)
            engine.update(deltaTime: dt, currentTime: simTime)
        }
        
        // Must have reached the hard continuous spin ceiling of 2,000 RPM
        let capOmega = SpinMode.continuousMaxAngularVelocity
        XCTAssertEqual(engine.state.angularVelocity, capOmega, accuracy: Float(1e-3))
        XCTAssertEqual(engine.state.rpm, 2000.0, accuracy: Float(1.0), "Continuous spin must strictly cap at 2,000 RPM.")
        
        // When input torque ceases, spinner naturally decelerates
        engine.clearInputTorque()
        // Wait beyond 0.5s grace period so normal friction takes effect
        engine.update(deltaTime: 0.8, currentTime: simTime + 0.8)
        XCTAssertLessThan(engine.state.rpm, 2000.0, "When user ceases swiping, RPM must begin natural friction deceleration.")
    }
    
    func testInputTorqueDecaysAutomaticallyIfTouchEventsStopWithoutLifting() {
        // If the finger stops sending touch move events (e.g. stalled touch or tracking hiccup)
        let t0: TimeInterval = 100.0
        engine.setInputTorque(0.010, timestamp: t0)
        
        // Frame at t = t0 + 10ms: torque is active
        engine.update(deltaTime: 0.010, currentTime: t0 + 0.010)
        XCTAssertEqual(engine.state.appliedTorque, 0.010, accuracy: Float(1e-5))
        
        // Frame at t = t0 + 80ms: > 60ms elapsed with NO new touch move events -> torque drops to 0 automatically!
        engine.update(deltaTime: 0.016, currentTime: t0 + 0.080)
        XCTAssertEqual(engine.state.appliedTorque, 0.0, accuracy: Float(1e-5), "Torque must safely drop to 0 if touch events stall for > 60ms.")
    }
}

