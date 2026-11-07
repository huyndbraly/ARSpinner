import XCTest
import simd
@testable import ARSpinner

final class RayVolumeHitTestingTests: XCTestCase {
    
    let center = simd_float3(0.0, 1.0, -0.5)
    let axis = simd_float3(0.0, 1.0, 0.0) // Local +Y rotation axis
    let radius: Float = 0.038 // 3.8 cm radius (7.6 cm diameter)
    let thickness: Float = 0.012 // 1.2 cm thickness (h = 0.006 m)
    
    // MARK: - Top Face Tests
    
    func testRayHitsTopFace() {
        // Camera above the spinner pointing straight down at the top face
        let rayOrigin = simd_float3(0.015, 1.5, -0.5)
        let rayDirection = simd_float3(0.0, -1.0, 0.0)
        
        let hit = TouchProjector.intersectRayWithSpinnerVolume(
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            spinnerCenter: center,
            rotationAxis: axis,
            radius: radius,
            thickness: thickness
        )
        
        XCTAssertNotNil(hit, "Ray pointing down at the spinner must strike the top face.")
        guard let result = hit else { return }
        
        XCTAssertEqual(result.surfaceType, .topFace)
        XCTAssertTrue(result.isDirectHit)
        XCTAssertEqual(result.worldPoint.y, center.y + thickness * 0.5, accuracy: Float(1e-4))
        XCTAssertEqual(result.worldNormal.y, 1.0, accuracy: Float(1e-4))
        XCTAssertLessThanOrEqual(result.leverArmDistance, radius)
    }
    
    // MARK: - Bottom Face Tests
    
    func testRayHitsBottomFaceWhenLookingFromBelow() {
        // Camera below the spinner pointing upwards (e.g. Floating mode looking up)
        let rayOrigin = simd_float3(0.010, 0.5, -0.5)
        let rayDirection = simd_float3(0.0, 1.0, 0.0)
        
        let hit = TouchProjector.intersectRayWithSpinnerVolume(
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            spinnerCenter: center,
            rotationAxis: axis,
            radius: radius,
            thickness: thickness
        )
        
        XCTAssertNotNil(hit, "Ray pointing up from below must strike the bottom face.")
        guard let result = hit else { return }
        
        XCTAssertEqual(result.surfaceType, .bottomFace)
        XCTAssertTrue(result.isDirectHit)
        XCTAssertEqual(result.worldPoint.y, center.y - thickness * 0.5, accuracy: Float(1e-4))
        XCTAssertEqual(result.worldNormal.y, -1.0, accuracy: Float(1e-4))
    }
    
    // MARK: - Side Edge Tests
    
    func testRayHitsSideEdgeHorizontally() {
        // Camera positioned horizontally at the side of the spinner pointing directly at the rim
        // y is exactly aligned with center (y = 1.0)
        let rayOrigin = simd_float3(-0.20, 1.0, -0.5)
        let rayDirection = simd_float3(1.0, 0.0, 0.0)
        
        let hit = TouchProjector.intersectRayWithSpinnerVolume(
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            spinnerCenter: center,
            rotationAxis: axis,
            radius: radius,
            thickness: thickness
        )
        
        XCTAssertNotNil(hit, "Horizontal ray aimed at the rim must strike the side edge.")
        guard let result = hit else { return }
        
        XCTAssertEqual(result.surfaceType, .sideEdge)
        XCTAssertTrue(result.isDirectHit)
        // Hit must occur at outer rim radius: center.x - radius = -0.038
        XCTAssertEqual(result.worldPoint.x, center.x - radius, accuracy: Float(1e-3))
        XCTAssertEqual(result.worldPoint.y, center.y, accuracy: Float(1e-3))
        XCTAssertEqual(result.leverArmDistance, radius, accuracy: Float(1e-3))
        // Normal should point outward (-X direction in this setup)
        XCTAssertEqual(result.worldNormal.x, -1.0, accuracy: Float(1e-3))
    }
    
    func testRayHitsSideEdgeAtObliqueAngle() {
        // Camera at an oblique 30-degree angle from the horizontal plane
        let rayOrigin = simd_float3(-0.15, 1.0 + 0.003, -0.5) // Slightly above center, but within thickness
        let rayDirection = simd_normalize(simd_float3(1.0, -0.01, 0.0))
        
        let hit = TouchProjector.intersectRayWithSpinnerVolume(
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            spinnerCenter: center,
            rotationAxis: axis,
            radius: radius,
            thickness: thickness
        )
        
        XCTAssertNotNil(hit)
        guard let result = hit else { return }
        XCTAssertEqual(result.surfaceType, .sideEdge)
        XCTAssertEqual(result.leverArmDistance, radius, accuracy: Float(1e-3))
    }
    
    // MARK: - Rejection Tests
    
    func testRayCompletelyMissingSpinnerIsRejected() {
        // Ray aimed far away from the spinner (x = 0.50m, whereas radius is 0.038m)
        let rayOrigin = simd_float3(0.50, 1.5, -0.5)
        let rayDirection = simd_float3(0.0, -1.0, 0.0)
        
        let hit = TouchProjector.intersectRayWithSpinnerVolume(
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            spinnerCenter: center,
            rotationAxis: axis,
            radius: radius,
            thickness: thickness
        )
        
        XCTAssertNil(hit, "Ray far outside spinner volume must be rejected.")
    }
    
    func testRayAimingAboveSpinnerIsRejected() {
        // Ray aimed horizontally above the spinner height (y = 1.05m, thickness top is 1.006m)
        let rayOrigin = simd_float3(-0.20, 1.05, -0.5)
        let rayDirection = simd_float3(1.0, 0.0, 0.0)
        
        let hit = TouchProjector.intersectRayWithSpinnerVolume(
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            spinnerCenter: center,
            rotationAxis: axis,
            radius: radius,
            thickness: thickness
        )
        
        XCTAssertNil(hit, "Ray aiming completely above the cylinder height must be rejected.")
    }
    
    // MARK: - Margin Catchment Tests
    
    func testMarginCatchmentCatchesNearMiss() {
        // Ray aiming just outside the outer radius (r = 0.042m, radius = 0.038m)
        // With marginMultiplier = 1.3, effective radius = 0.0494m, so it should catch it as margin!
        let rayOrigin = simd_float3(0.042, 1.5, -0.5)
        let rayDirection = simd_float3(0.0, -1.0, 0.0)
        
        let hit = TouchProjector.intersectRayWithSpinnerVolume(
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            spinnerCenter: center,
            rotationAxis: axis,
            radius: radius,
            thickness: thickness,
            marginMultiplier: 1.3
        )
        
        XCTAssertNotNil(hit, "Near miss within 1.3x margin must be caught.")
        guard let result = hit else { return }
        XCTAssertEqual(result.surfaceType, .margin)
        XCTAssertFalse(result.isDirectHit)
    }
}

