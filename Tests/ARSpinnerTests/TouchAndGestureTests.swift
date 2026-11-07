import XCTest
import UIKit
import simd
@testable import ARSpinner

final class TouchAndGestureTests: XCTestCase {
    
    let center = simd_float3(0, 0, 0)
    let normal = simd_float3(0, 1, 0)
    let radius: Float = 0.038 // 3.8 cm (7.6 cm diameter)
    
    // MARK: - Hit Testing & Projection Tests
    
    func testTouchProjectorWithDynamicRadius() {
        let rayOrigin = simd_float3(0.05, 1.0, 0.0) // 5 cm from center along X
        let rayDirection = simd_float3(0, -1, 0)
        
        // 1. With standard 7.6 cm diameter (radius = 3.8 cm)
        // 5 cm distance is outside 3.8 * 1.25 = 4.75 cm
        let resultStandard = TouchProjector.projectRayOntoSpinnerPlane(
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            spinnerCenter: center,
            spinnerNormal: normal,
            maxRadius: 0.038,
            marginMultiplier: 1.25
        )
        XCTAssertNotNil(resultStandard)
        XCTAssertFalse(resultStandard?.isWithinInteractionRadius ?? true)
        
        // 2. Resized to 12.0 cm diameter (radius = 6.0 cm)
        // 5 cm distance is now well within 6.0 cm radius!
        let resultResized = TouchProjector.projectRayOntoSpinnerPlane(
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            spinnerCenter: center,
            spinnerNormal: normal,
            maxRadius: 0.060,
            marginMultiplier: 1.25
        )
        XCTAssertNotNil(resultResized)
        XCTAssertTrue(resultResized?.isWithinInteractionRadius ?? false)
        XCTAssertEqual(resultResized?.distanceFromCenter ?? 0, 0.05, accuracy: 1e-4)
    }
    
    func testTouchProjectionRejectsFarOutsideTouches() {
        let farRayOrigin = simd_float3(0.50, 1.0, 0.0) // 50 cm away from center
        let rayDirection = simd_float3(0, -1, 0)
        
        let result = TouchProjector.projectRayOntoSpinnerPlane(
            rayOrigin: farRayOrigin,
            rayDirection: rayDirection,
            spinnerCenter: center,
            spinnerNormal: normal,
            maxRadius: 0.038,
            marginMultiplier: 1.4
        )
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.isWithinInteractionRadius ?? true)
    }
    
    func testSwipeImpulseClampsTorqueAtOuterRadius() {
        let farStart = simd_float3(0.10, 0, -0.01)
        let farEnd = simd_float3(0.10, 0, 0.01)
        
        let result = SwipeImpulseCalculator.calculateImpulse(
            startWorldPoint: farStart,
            endWorldPoint: farEnd,
            duration: 0.02,
            spinnerCenter: center,
            rotationAxis: normal,
            spinnerRadius: 0.038,
            momentOfInertia: 4.0e-5,
            effectiveMass: 0.035
        )
        
        // Lever arm must be clamped to outer radius to prevent unrealistic torque
        XCTAssertEqual(result.leverArmDistance, 0.038, accuracy: 1e-4)
        XCTAssertFalse(result.angularImpulse.isNaN)
        XCTAssertFalse(result.deltaAngularVelocity.isNaN)
    }
    
    // MARK: - Gesture Discrimination Tests
    
    func testTapDoesNotProduceSwipe() {
        let stateMachine = InteractionStateMachine()
        let t0: TimeInterval = 100.0
        
        // Tap: small movement (< 12 pt)
        let p0 = CGPoint(x: 200, y: 300)
        let w0 = simd_float3(0.02, 0, 0.01)
        stateMachine.onTouchBegan(screenPoint: p0, worldPoint: w0, timestamp: t0)
        
        let p1 = CGPoint(x: 202, y: 301)
        let w1 = simd_float3(0.021, 0, 0.011)
        stateMachine.onTouchMoved(screenPoint: p1, worldPoint: w1, timestamp: t0 + 0.03)
        
        let swipe = stateMachine.onTouchEnded(
            finalScreenPoint: p1,
            finalWorldPoint: w1,
            timestamp: t0 + 0.05,
            spinnerCenter: center,
            rotationAxis: normal,
            spinnerRadius: radius
        )
        
        XCTAssertNil(swipe, "Tap movement under 12 pt must be rejected and produce 0 impulse.")
    }
    
    func testLongPressDoesNotProduceSwipe() {
        let stateMachine = InteractionStateMachine()
        let t0: TimeInterval = 100.0
        
        // Long press: finger stays nearly stationary for 1.0 second
        let p0 = CGPoint(x: 200, y: 300)
        let w0 = simd_float3(0.02, 0, 0.01)
        stateMachine.onTouchBegan(screenPoint: p0, worldPoint: w0, timestamp: t0)
        
        stateMachine.onTouchMoved(screenPoint: p0, worldPoint: w0, timestamp: t0 + 0.5)
        stateMachine.onTouchMoved(screenPoint: p0, worldPoint: w0, timestamp: t0 + 1.0)
        
        let swipe = stateMachine.onTouchEnded(
            finalScreenPoint: p0,
            finalWorldPoint: w0,
            timestamp: t0 + 1.05,
            spinnerCenter: center,
            rotationAxis: normal,
            spinnerRadius: radius
        )
        
        XCTAssertNil(swipe, "Stationary long press must produce 0 impulse.")
    }
    
    func testSwipeAndHoldDoesNotProduceSwipe() {
        let stateMachine = InteractionStateMachine()
        let t0: TimeInterval = 100.0
        
        // Swipe initially from (150, 300) to (220, 300), but then HELD stationary for 200ms before lifting
        let p0 = CGPoint(x: 150, y: 300)
        let w0 = simd_float3(-0.02, 0, 0.01)
        stateMachine.onTouchBegan(screenPoint: p0, worldPoint: w0, timestamp: t0)
        
        let pEnd = CGPoint(x: 220, y: 300)
        let wEnd = simd_float3(0.02, 0, 0.01)
        stateMachine.onTouchMoved(screenPoint: pEnd, worldPoint: wEnd, timestamp: t0 + 0.10)
        
        // Hold stationary for 200ms
        stateMachine.onTouchMoved(screenPoint: pEnd, worldPoint: wEnd, timestamp: t0 + 0.25)
        stateMachine.onTouchMoved(screenPoint: pEnd, worldPoint: wEnd, timestamp: t0 + 0.30)
        
        let swipe = stateMachine.onTouchEnded(
            finalScreenPoint: pEnd,
            finalWorldPoint: wEnd,
            timestamp: t0 + 0.32,
            spinnerCenter: center,
            rotationAxis: normal,
            spinnerRadius: radius
        )
        
        XCTAssertNil(swipe, "Finger held stationary before lift-off must produce 0 impulse.")
    }
    
    func testValidBriskSwipeProducesSingleValidatedSwipe() {
        let stateMachine = InteractionStateMachine()
        let t0: TimeInterval = 100.0
        
        // Brisk flick across spinner wing: 60 pt displacement over 60 ms (~1000 pt/s)
        let p0 = CGPoint(x: 170, y: 300)
        let w0 = simd_float3(0.015, 0, -0.020)
        stateMachine.onTouchBegan(screenPoint: p0, worldPoint: w0, timestamp: t0)
        
        let p1 = CGPoint(x: 195, y: 300)
        let w1 = simd_float3(0.025, 0, -0.005)
        stateMachine.onTouchMoved(screenPoint: p1, worldPoint: w1, timestamp: t0 + 0.03)
        
        let p2 = CGPoint(x: 230, y: 300)
        let w2 = simd_float3(0.035, 0, 0.015)
        stateMachine.onTouchMoved(screenPoint: p2, worldPoint: w2, timestamp: t0 + 0.06)
        
        let swipe = stateMachine.onTouchEnded(
            finalScreenPoint: p2,
            finalWorldPoint: w2,
            timestamp: t0 + 0.065,
            spinnerCenter: center,
            rotationAxis: normal,
            spinnerRadius: radius
        )
        
        XCTAssertNotNil(swipe)
        guard let valid = swipe else { return }
        XCTAssertGreaterThanOrEqual(valid.screenDistance, 12.0)
        XCTAssertGreaterThanOrEqual(valid.screenVelocity, 60.0)
        XCTAssertLessThanOrEqual(valid.duration, 0.15)
    }
    
    func testSubthresholdVelocitySwipeIsRejected() {
        let stateMachine = InteractionStateMachine()
        let t0: TimeInterval = 100.0
        
        // Very slow drag: moves 15 pt over 0.5 seconds (velocity = 30 pt/s < 60 pt/s)
        let p0 = CGPoint(x: 200, y: 300)
        let w0 = simd_float3(0.02, 0, 0.01)
        stateMachine.onTouchBegan(screenPoint: p0, worldPoint: w0, timestamp: t0)
        
        let p1 = CGPoint(x: 215, y: 300)
        let w1 = simd_float3(0.025, 0, 0.01)
        stateMachine.onTouchMoved(screenPoint: p1, worldPoint: w1, timestamp: t0 + 0.50)
        
        let swipe = stateMachine.onTouchEnded(
            finalScreenPoint: p1,
            finalWorldPoint: w1,
            timestamp: t0 + 0.51,
            spinnerCenter: center,
            rotationAxis: normal,
            spinnerRadius: radius
        )
        
        XCTAssertNil(swipe, "Slow drag under 60 pt/s must not produce an impulsive flick.")
    }
}
