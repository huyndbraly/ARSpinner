import XCTest
import simd
import RealityKit
@testable import ARSpinner

final class SafeTransformAndNumericalSafetyTests: XCTestCase {
    
    func testSafeTransformWithValidMatrix() {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = simd_float4(1.0, 2.0, 3.0, 1.0)
        
        let transformOpt = SafeTransform.create(from: matrix)
        XCTAssertNotNil(transformOpt)
        guard let transform = transformOpt else { return }
        
        XCTAssertEqual(transform.translation.x, 1.0, accuracy: Float(1e-5))
        XCTAssertEqual(transform.translation.y, 2.0, accuracy: Float(1e-5))
        XCTAssertEqual(transform.translation.z, 3.0, accuracy: Float(1e-5))
        XCTAssertFalse(transform.rotation.real.isNaN)
        XCTAssertFalse(transform.rotation.imag.x.isNaN)
        XCTAssertFalse(transform.rotation.imag.y.isNaN)
        XCTAssertFalse(transform.rotation.imag.z.isNaN)
    }
    
    func testSafeTransformWithShearedOrSlightlyNonOrthonormalMatrix() {
        // ARKit raycast matrices often have minute numerical inaccuracies (e.g. shear of 1e-6)
        // which causes raw Transform(matrix:) to produce NaNs.
        var matrix = matrix_identity_float4x4
        matrix.columns.0 = simd_float4(1.000002, 0.000005, 0.000001, 0.0)
        matrix.columns.1 = simd_float4(0.000003, 0.999998, 0.000004, 0.0)
        matrix.columns.2 = simd_float4(0.000001, 0.000002, 1.000003, 0.0)
        matrix.columns.3 = simd_float4(0.5, 0.1, -0.8, 1.0)
        
        let transformOpt = SafeTransform.create(from: matrix)
        XCTAssertNotNil(transformOpt)
        guard let transform = transformOpt else { return }
        
        XCTAssertFalse(transform.rotation.real.isNaN)
        XCTAssertFalse(transform.rotation.imag.x.isNaN)
        XCTAssertFalse(transform.rotation.imag.y.isNaN)
        XCTAssertFalse(transform.rotation.imag.z.isNaN)
        XCTAssertFalse(transform.translation.x.isNaN)
        XCTAssertFalse(transform.scale.x.isNaN)
        XCTAssertEqual(transform.translation.x, 0.5, accuracy: Float(1e-5))
    }
    
    func testSafeTransformHandlesNaNAndInfiniteMatricesGracefully() {
        var nanMatrix = matrix_identity_float4x4
        nanMatrix.columns.3 = simd_float4(Float.nan, 0.0, 0.0, 1.0)
        
        // Non-finite matrices should be safely rejected by returning nil
        let transformFromNaN = SafeTransform.create(from: nanMatrix)
        XCTAssertNil(transformFromNaN)
        
        var infMatrix = matrix_identity_float4x4
        infMatrix.columns.0.x = Float.infinity
        
        let transformFromInf = SafeTransform.create(from: infMatrix)
        XCTAssertNil(transformFromInf)
    }
    
    func testQuaternionFromZeroAxisAngle() {
        // Zero length axis should return identity quaternion without producing NaNs
        let zeroAxis = simd_float3(0, 0, 0)
        let quat = QuaternionHelper.fromAxisAngle(axis: zeroAxis, angle: Float.pi * 0.5)
        
        XCTAssertFalse(quat.real.isNaN)
        XCTAssertFalse(quat.imag.x.isNaN)
        XCTAssertEqual(quat.real, 1.0, accuracy: Float(1e-6))
        XCTAssertEqual(quat.imag, simd_float3(0, 0, 0))
    }
    
    func testVectorMathFiniteChecks() {
        let finite3 = simd_float3(1, 2, 3)
        XCTAssertTrue(VectorMath.isFinite(finite3))
        
        let nan3 = simd_float3(Float.nan, 2, 3)
        XCTAssertFalse(VectorMath.isFinite(nan3))
        
        let inf3 = simd_float3(1, Float.infinity, 3)
        XCTAssertFalse(VectorMath.isFinite(inf3))
        
        let identity4x4 = matrix_identity_float4x4
        XCTAssertTrue(VectorMath.isFinite(identity4x4))
        
        var nan4x4 = matrix_identity_float4x4
        nan4x4.columns.1.y = Float.nan
        XCTAssertFalse(VectorMath.isFinite(nan4x4))
    }
    
    func testRayPlaneIntersectionProtections() {
        // Parallel ray
        let origin = simd_float3(0, 1, 0)
        let direction = simd_float3(1, 0, 0)
        let planePoint = simd_float3(0, 0, 0)
        let planeNormal = simd_float3(0, 1, 0)
        
        XCTAssertNil(VectorMath.rayPlaneIntersection(
            rayOrigin: origin,
            rayDirection: direction,
            planePoint: planePoint,
            planeNormal: planeNormal
        ))
        
        // Ray pointing away from plane
        let awayDir = simd_float3(0, 1, 0)
        XCTAssertNil(VectorMath.rayPlaneIntersection(
            rayOrigin: origin,
            rayDirection: awayDir,
            planePoint: planePoint,
            planeNormal: planeNormal
        ))
        
        // Non-finite input
        let nanDir = simd_float3(0, Float.nan, 0)
        XCTAssertNil(VectorMath.rayPlaneIntersection(
            rayOrigin: origin,
            rayDirection: nanDir,
            planePoint: planePoint,
            planeNormal: planeNormal
        ))
    }
}
