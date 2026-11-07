import XCTest
import simd
@testable import ARSpinner

final class VectorMathTests: XCTestCase {
    
    func testRPMConversions() {
        // 60 RPM = 1 rev/sec = 2π rad/sec
        let twoPiRad = Float.pi * 2.0
        let rpm = VectorMath.radPerSecToRPM(twoPiRad)
        XCTAssertEqual(rpm, 60.0, accuracy: 1e-4)
        
        let backToRad = VectorMath.rpmToRadPerSec(60.0)
        XCTAssertEqual(backToRad, twoPiRad, accuracy: 1e-4)
    }
    
    func testDegreesRadiansConversion() {
        XCTAssertEqual(VectorMath.degreesToRadians(180.0), Float.pi, accuracy: 1e-5)
        XCTAssertEqual(VectorMath.radiansToDegrees(Float.pi), 180.0, accuracy: 1e-5)
    }
    
    func testAngleNormalization() {
        let angle3Pi = Float.pi * 3.0
        let norm2Pi = VectorMath.normalizeAngle2Pi(angle3Pi)
        XCTAssertEqual(norm2Pi, Float.pi, accuracy: 1e-5)
        
        let negAngle = -Float.pi * 0.5
        let normSigned = VectorMath.normalizeAngleSignedPi(negAngle)
        XCTAssertEqual(normSigned, -Float.pi * 0.5, accuracy: 1e-5)
    }
    
    func testCrossAndDotProducts() {
        let x = simd_float3(1, 0, 0)
        let z = simd_float3(0, 0, 1)
        // x × z = -y = (0, -1, 0)
        let crossXZ = VectorMath.cross(x, z)
        XCTAssertEqual(crossXZ.x, 0, accuracy: 1e-5)
        XCTAssertEqual(crossXZ.y, -1, accuracy: 1e-5)
        XCTAssertEqual(crossXZ.z, 0, accuracy: 1e-5)
        
        // z × x = +y = (0, 1, 0)
        let crossZX = VectorMath.cross(z, x)
        XCTAssertEqual(crossZX.x, 0, accuracy: 1e-5)
        XCTAssertEqual(crossZX.y, 1, accuracy: 1e-5)
        XCTAssertEqual(crossZX.z, 0, accuracy: 1e-5)
        
        let dotVal = VectorMath.dot(x, z)
        XCTAssertEqual(dotVal, 0.0, accuracy: 1e-5)
    }
    
    func testPlaneProjection() {
        let v = simd_float3(2, 5, 3)
        let normal = simd_float3(0, 1, 0)
        let projected = VectorMath.projectOntoPlane(vector: v, planeNormal: normal)
        XCTAssertEqual(projected.x, 2, accuracy: 1e-5)
        XCTAssertEqual(projected.y, 0, accuracy: 1e-5)
        XCTAssertEqual(projected.z, 3, accuracy: 1e-5)
    }
    
    func testRayPlaneIntersection() {
        let rayOrigin = simd_float3(0, 5, 0)
        let rayDirection = simd_float3(0, -1, 0)
        let planePoint = simd_float3(0, 0, 0)
        let planeNormal = simd_float3(0, 1, 0)
        
        let hit = VectorMath.rayPlaneIntersection(
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            planePoint: planePoint,
            planeNormal: planeNormal
        )
        
        XCTAssertNotNil(hit)
        if let hit = hit {
            XCTAssertEqual(hit.x, 0, accuracy: 1e-5)
            XCTAssertEqual(hit.y, 0, accuracy: 1e-5)
            XCTAssertEqual(hit.z, 0, accuracy: 1e-5)
        }
        
        // Parallel ray should return nil
        let parallelRayDir = simd_float3(1, 0, 0)
        let parallelHit = VectorMath.rayPlaneIntersection(
            rayOrigin: rayOrigin,
            rayDirection: parallelRayDir,
            planePoint: planePoint,
            planeNormal: planeNormal
        )
        XCTAssertNil(parallelHit)
    }
}

