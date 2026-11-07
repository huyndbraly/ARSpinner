import XCTest
import simd
@testable import ARSpinner

final class SwipeImpulseCalculatorTests: XCTestCase {
    
    let center = simd_float3(0, 0, 0)
    let yAxis = simd_float3(0, 1, 0)
    let radius: Float = 0.040 // 4 cm
    let inertia: Float = 4.0e-5
    let mass: Float = 0.035
    
    func testOuterTipProducesGreaterTorqueThanCenter() {
        let duration: TimeInterval = 0.02
        
        // 1. Swipe near outer tip (radius ~ 3.5 cm along X)
        // Contact point at X = 0.035, swiped in +Z direction
        let outerStart = simd_float3(0.035, 0, -0.01)
        let outerEnd = simd_float3(0.035, 0, 0.01)
        
        let outerResult = SwipeImpulseCalculator.calculateImpulse(
            startWorldPoint: outerStart,
            endWorldPoint: outerEnd,
            duration: duration,
            spinnerCenter: center,
            rotationAxis: yAxis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            effectiveMass: mass
        )
        
        // 2. Swipe near center hub (radius ~ 0.5 cm along X)
        let innerStart = simd_float3(0.005, 0, -0.01)
        let innerEnd = simd_float3(0.005, 0, 0.01)
        
        let innerResult = SwipeImpulseCalculator.calculateImpulse(
            startWorldPoint: innerStart,
            endWorldPoint: innerEnd,
            duration: duration,
            spinnerCenter: center,
            rotationAxis: yAxis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            effectiveMass: mass
        )
        
        // Outer tip torque should be substantially larger than inner hub torque
        XCTAssertGreaterThan(abs(outerResult.angularImpulse), abs(innerResult.angularImpulse))
        XCTAssertGreaterThan(abs(outerResult.deltaAngularVelocity), abs(innerResult.deltaAngularVelocity))
        
        // Ratio should be approximately 0.035 / 0.005 = 7.0
        let ratio = abs(outerResult.angularImpulse) / abs(innerResult.angularImpulse)
        XCTAssertEqual(ratio, 7.0, accuracy: 0.1)
    }
    
    func testFasterSwipeProducesGreaterImpulse() {
        let start = simd_float3(0.030, 0, -0.01)
        let end = simd_float3(0.030, 0, 0.01)
        
        // Fast swipe: 10 ms
        let fastResult = SwipeImpulseCalculator.calculateImpulse(
            startWorldPoint: start,
            endWorldPoint: end,
            duration: 0.010,
            spinnerCenter: center,
            rotationAxis: yAxis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            effectiveMass: mass
        )
        
        // Slow swipe: 50 ms
        let slowResult = SwipeImpulseCalculator.calculateImpulse(
            startWorldPoint: start,
            endWorldPoint: end,
            duration: 0.050,
            spinnerCenter: center,
            rotationAxis: yAxis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            effectiveMass: mass
        )
        
        XCTAssertGreaterThan(abs(fastResult.deltaAngularVelocity), abs(slowResult.deltaAngularVelocity))
    }
    
    func testCounterSwipeProducesOppositeSign() {
        let startForward = simd_float3(0.030, 0, -0.01)
        let endForward = simd_float3(0.030, 0, 0.01)
        
        let forwardResult = SwipeImpulseCalculator.calculateImpulse(
            startWorldPoint: startForward,
            endWorldPoint: endForward,
            duration: 0.02,
            spinnerCenter: center,
            rotationAxis: yAxis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            effectiveMass: mass
        )
        
        let startReverse = simd_float3(0.030, 0, 0.01)
        let endReverse = simd_float3(0.030, 0, -0.01)
        
        let reverseResult = SwipeImpulseCalculator.calculateImpulse(
            startWorldPoint: startReverse,
            endWorldPoint: endReverse,
            duration: 0.02,
            spinnerCenter: center,
            rotationAxis: yAxis,
            spinnerRadius: radius,
            momentOfInertia: inertia,
            effectiveMass: mass
        )
        
        // Signs should be exact opposites
        XCTAssertEqual(forwardResult.deltaAngularVelocity, -reverseResult.deltaAngularVelocity, accuracy: 1e-4)
    }
}

