import XCTest
import CoreGraphics
import simd
@testable import ARSpinner

final class ContinuousSpinPhysicsTests: XCTestCase {
    
    var engine: SpinnerPhysicsEngine!
    
    let center = simd_float3(0, 0, 0)
    let axis = simd_float3(0, 1, 0)
    let radius: Float = 0.038
    let inertia: Float = 2.5e-5
    
    override func setUp() {
        super.setUp()
        engine = SpinnerPhysicsEngine(configuration: .standard, spinMode: .natural)
    }
    
    // MARK: - Velocity Stacking Tests
    
    func testContinuousSpinStacksVelocityAcrossMultipleSwipes() {
        engine.setSpinMode(.continuous)
        XCTAssertEqual(engine.spinMode, .continuous)
        
        let singleImpulse: Float = 0.0008 // N·m·s
        
        // 1st swipe
        engine.applyAngularImpulse(singleImpulse)
        let speed1 = engine.state.angularVelocity
        XCTAssertGreaterThan(speed1, 0.0)
        
        // 2nd swipe in same direction
        engine.applyAngularImpulse(singleImpulse)
        let speed2 = engine.state.angularVelocity
        XCTAssertGreaterThan(speed2, speed1, "Continuous spin must stack velocity on successive co-directional swipes.")
        
        // 3rd swipe
        engine.applyAngularImpulse(singleImpulse)
        let speed3 = engine.state.angularVelocity
        XCTAssertGreaterThan(speed3, speed2)
    }
    
    // MARK: - 2,000 RPM Cap Verification
    
    func testContinuousSpinCapsAt2000RPM() {
        engine.setSpinMode(.continuous)
        let capOmega = SpinMode.continuousMaxAngularVelocity // ~209.4395 rad/s = 2,000 RPM
        
        // Apply huge positive impulse
        engine.applyAngularImpulse(10.0)
        XCTAssertEqual(engine.state.angularVelocity, capOmega, accuracy: Float(1e-4))
        XCTAssertEqual(engine.state.rpm, 2000.0, accuracy: Float(1.0), "RPM must cap at 2,000 RPM.")
        
        // Even with another impulse, speed cannot exceed 2,000 RPM
        engine.applyAngularImpulse(1.0)
        XCTAssertEqual(engine.state.angularVelocity, capOmega, accuracy: Float(1e-4))
        
        // Test negative (clockwise) direction clamping
        engine.stopImmediately()
        engine.applyAngularImpulse(-10.0)
        XCTAssertEqual(engine.state.angularVelocity, -capOmega, accuracy: Float(1e-4))
        XCTAssertEqual(abs(engine.state.rpm), 2000.0, accuracy: Float(1.0))
    }
    
    // MARK: - High RPM Non-Braking Verification
    
    func testCodirectionalSwipeNeverBrakesAtHighRPM() {
        // At 600 RPM (~62.83 rad/s), surface speed at r = 0.035m is ~2.2 m/s.
        // Finger swipe at 1.25 m/s is SLOWER than the surface speed.
        let highOmega: Float = 62.83
        
        let p0 = simd_float3(0.035, 0, 0.0)
        let p1 = simd_float3(0.035, 0, -0.020) // Forward swipe along -Z
        let screen0 = CGPoint(x: 200, y: 300)
        let screen1 = CGPoint(x: 200, y: 250)
        
        // 1. Natural Spin: relative velocity is negative -> produces braking torque
        let naturalResult = SwipeImpulseCalculator.calculateContinuousTorque(
            previousWorldPoint: p0,
            currentWorldPoint: p1,
            previousScreenPoint: screen0,
            currentScreenPoint: screen1,
            deltaTime: 0.016,
            spinnerCenter: center,
            rotationAxis: axis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            currentAngularVelocity: highOmega,
            effectiveMass: 0.035,
            spinMode: .natural
        )
        XCTAssertLessThan(naturalResult.appliedTorque, 0.0, "Natural spin must produce braking drag when finger is slower than surface.")
        
        // 2. Continuous Spin: co-directional swipe MUST produce POSITIVE drive torque!
        let continuousResult = SwipeImpulseCalculator.calculateContinuousTorque(
            previousWorldPoint: p0,
            currentWorldPoint: p1,
            previousScreenPoint: screen0,
            currentScreenPoint: screen1,
            deltaTime: 0.016,
            spinnerCenter: center,
            rotationAxis: axis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            currentAngularVelocity: highOmega,
            effectiveMass: 0.035,
            spinMode: .continuous
        )
        XCTAssertGreaterThan(continuousResult.appliedTorque, 0.003, "Continuous spin MUST produce forward driving torque during co-directional swipe, even at 600 RPM!")
    }
    
    // MARK: - 10-Stroke Consecutive Acceleration Sequence
    
    func testTenStrokeConsecutiveSwipesAccelerateTowards2000RPM() {
        engine.setSpinMode(.continuous)
        XCTAssertEqual(engine.state.angularVelocity, 0.0)
        
        var currentTime: TimeInterval = 100.0
        var recordedRPMs: [Float] = []
        
        // Simulate 10 consecutive swipe strokes with 0.25s pause between strokes
        for _ in 1...10 {
            // Each stroke has 5 contact updates with driving torque (0.015 N·m)
            let drivingTorque: Float = 0.015
            for _ in 0..<5 {
                currentTime += 0.016
                engine.setInputTorque(drivingTorque, timestamp: currentTime)
                engine.update(deltaTime: 0.016, currentTime: currentTime)
            }
            
            // Finger lifts at end of stroke
            engine.clearInputTorque()
            engine.recordContinuousStroke(timestamp: currentTime)
            
            let strokeEndRPM = engine.state.rpm
            recordedRPMs.append(strokeEndRPM)
            
            // User prepares next stroke: 0.25s pause (within 0.5s grace period)
            for _ in 0..<15 {
                currentTime += 0.016
                engine.update(deltaTime: 0.016, currentTime: currentTime)
            }
        }
        
        // Verify steady RPM progression across strokes:
        // Stroke 1 > 0
        XCTAssertGreaterThan(recordedRPMs[0], 100.0)
        // Stroke 3 > Stroke 1
        XCTAssertGreaterThan(recordedRPMs[2], recordedRPMs[0])
        // Stroke 5 > Stroke 3 (must not stall at 200 RPM!)
        XCTAssertGreaterThan(recordedRPMs[4], recordedRPMs[2])
        XCTAssertGreaterThan(recordedRPMs[4], 400.0, "RPM after 5 strokes must comfortably exceed 400 RPM (no 200 RPM stall).")
        // Stroke 10 > Stroke 5
        XCTAssertGreaterThan(recordedRPMs[9], recordedRPMs[4])
        // Sequence approaches 2,000 RPM ceiling
        XCTAssertGreaterThan(recordedRPMs[9], 1000.0, "10 consecutive strokes must drive spinner well over 1,000 RPM towards 2,000 RPM.")
        XCTAssertLessThanOrEqual(recordedRPMs[9], 2000.0)
    }
    
    // MARK: - Counter Swipe Braking & Reversal
    
    func testCounterSwipeBrakesAndReverses() {
        engine.setSpinMode(.continuous)
        engine.setAngularVelocity(80.0) // ~764 RPM forward
        
        let initialSpeed = engine.state.angularVelocity
        XCTAssertGreaterThan(initialSpeed, 50.0)
        
        // Swiping counter-directionally along +Z
        let p0 = simd_float3(0.035, 0, 0.0)
        let p1 = simd_float3(0.035, 0, 0.020)
        let screen0 = CGPoint(x: 200, y: 300)
        let screen1 = CGPoint(x: 200, y: 350)
        
        let counterResult = SwipeImpulseCalculator.calculateContinuousTorque(
            previousWorldPoint: p0,
            currentWorldPoint: p1,
            previousScreenPoint: screen0,
            currentScreenPoint: screen1,
            deltaTime: 0.016,
            spinnerCenter: center,
            rotationAxis: axis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            currentAngularVelocity: initialSpeed,
            effectiveMass: 0.035,
            spinMode: .continuous
        )
        
        XCTAssertLessThan(counterResult.appliedTorque, -0.005, "Counter swipe must produce strong negative braking torque.")
        
        // Apply braking torque across 10 frames
        var t: TimeInterval = 100.0
        for _ in 0..<10 {
            t += 0.016
            engine.setInputTorque(counterResult.appliedTorque, timestamp: t)
            engine.update(deltaTime: 0.016, currentTime: t)
        }
        
        XCTAssertLessThan(engine.state.angularVelocity, initialSpeed, "Counter torque must decelerate the spinner.")
    }
    
    // MARK: - Grace Period & Spindown Tests
    
    func testInterStrokeGracePeriodPreservesSpeedAndIdleDecelerates() {
        engine.setSpinMode(.continuous)
        engine.setAngularVelocity(100.0) // ~955 RPM
        
        let t0: TimeInterval = 100.0
        engine.recordContinuousStroke(timestamp: t0)
        
        let speedAtStroke = engine.state.angularVelocity
        
        // Advance 0.35s during the 0.5s grace period:
        // Speed must remain very stable (damped friction)
        var t = t0
        for _ in 0..<20 {
            t += 0.016 // ~0.32s
            engine.update(deltaTime: 0.016, currentTime: t)
        }
        
        let speedInGrace = engine.state.angularVelocity
        let retention = speedInGrace / speedAtStroke
        XCTAssertGreaterThan(retention, 0.95, "Speed must retain >95% during inter-stroke grace period (0.35s).")
        
        // Now advance past grace period into idle state (t > t0 + 0.5s, say to t0 + 2.0s)
        for _ in 0..<90 { // ~1.44s
            t += 0.016
            engine.update(deltaTime: 0.016, currentTime: t)
        }
        
        let speedAfterIdle = engine.state.angularVelocity
        XCTAssertLessThan(speedAfterIdle, speedInGrace * 0.90, "When idle beyond grace period, full friction must decelerate the spinner.")
    }
    
    // MARK: - Mode Switching & Natural Invariance
    
    func testSwitchingModesPreservesAngleAndVelocity() {
        engine.setAngularVelocity(40.0)
        
        for _ in 0..<10 {
            engine.update(deltaTime: 1.0 / 60.0)
        }
        
        let speedBefore = engine.state.angularVelocity
        let angleBefore = engine.state.angle
        let revsBefore = engine.state.totalRevolutions
        
        // Switch to Continuous
        engine.setSpinMode(.continuous)
        XCTAssertEqual(engine.spinMode, .continuous)
        XCTAssertEqual(engine.state.angularVelocity, speedBefore, accuracy: Float(1e-6))
        XCTAssertEqual(engine.state.angle, angleBefore, accuracy: Float(1e-6))
        XCTAssertEqual(engine.state.totalRevolutions, revsBefore, accuracy: 1e-6)
        
        // Switch back to Natural
        engine.setSpinMode(.natural)
        XCTAssertEqual(engine.spinMode, .natural)
        XCTAssertEqual(engine.state.angularVelocity, speedBefore, accuracy: Float(1e-6))
        XCTAssertEqual(engine.state.angle, angleBefore, accuracy: Float(1e-6))
    }
    
    func testCodirectionalSwipeAcceleratesAndCounterDecelerates() {
        engine.setSpinMode(.natural)
        engine.setAngularVelocity(30.0) // 30 rad/s
        
        let initialSpeed = engine.state.angularVelocity
        
        // Co-directional swipe (+ impulse) accelerates
        engine.applyAngularImpulse(0.0006)
        XCTAssertGreaterThan(engine.state.angularVelocity, initialSpeed)
        
        let boostedSpeed = engine.state.angularVelocity
        
        // Counter-directional swipe (- impulse) decelerates
        engine.applyAngularImpulse(-0.0004)
        XCTAssertLessThan(engine.state.angularVelocity, boostedSpeed)
        
        // Strong counter impulse reverses direction cleanly
        engine.applyAngularImpulse(-0.0025)
        XCTAssertLessThan(engine.state.angularVelocity, 0.0)
    }
    
    func testFPSIndependenceUnderVaryingFrameRates() {
        // Run physics simulation across 30 FPS, 60 FPS, and 120 FPS
        let engine30 = SpinnerPhysicsEngine(configuration: .standard)
        let engine60 = SpinnerPhysicsEngine(configuration: .standard)
        let engine120 = SpinnerPhysicsEngine(configuration: .standard)
        
        let startOmega: Float = 60.0
        engine30.setAngularVelocity(startOmega)
        engine60.setAngularVelocity(startOmega)
        engine120.setAngularVelocity(startOmega)
        
        let totalDuration: TimeInterval = 1.0 // 1 second
        
        // 30 FPS
        let steps30 = 30
        for _ in 0..<steps30 {
            engine30.update(deltaTime: totalDuration / Double(steps30))
        }
        
        // 60 FPS
        let steps60 = 60
        for _ in 0..<steps60 {
            engine60.update(deltaTime: totalDuration / Double(steps60))
        }
        
        // 120 FPS
        let steps120 = 120
        for _ in 0..<steps120 {
            engine120.update(deltaTime: totalDuration / Double(steps120))
        }
        
        // Relative difference should be under 2% across all frame rates
        let diff60to30 = abs(engine60.state.angularVelocity - engine30.state.angularVelocity) / engine60.state.angularVelocity
        let diff120to60 = abs(engine120.state.angularVelocity - engine60.state.angularVelocity) / engine120.state.angularVelocity
        
        XCTAssertLessThan(diff60to30, 0.02, "Physics must be invariant between 30 and 60 FPS.")
        XCTAssertLessThan(diff120to60, 0.02, "Physics must be invariant between 60 and 120 FPS.")
    }
}
