import Foundation
import simd

/// Defines which physical surface of the 3D spinner volume was intersected by a ray.
enum SpinnerSurfaceType: String, Sendable, Equatable, CaseIterable {
    /// Top planar disc surface of the hub and wings (normal aligns with rotation axis +Y).
    case topFace
    /// Bottom planar disc surface of the hub and wings (normal opposes rotation axis -Y).
    case bottomFace
    /// Outer cylindrical rim / side edge of the wings and lobes (normal points radially outward in XZ plane).
    case sideEdge
    /// Near-boundary tolerance margin surrounding the spinner body.
    case margin
}

/// Projects screen rays onto the 3D volume and planar surfaces of the fidget spinner.
enum TouchProjector {
    
    // MARK: - Legacy / Planar Types
    
    /// Result of projecting a ray onto the spinner interaction plane.
    struct ProjectionResult: Sendable, Equatable {
        /// Intersection point in world coordinates.
        let worldPoint: simd_float3
        /// Vector from spinner center to the intersection point in world coordinates.
        let radiusVector: simd_float3
        /// Distance from the spinner center in meters.
        let distanceFromCenter: Float
        /// Whether the hit point is within the interactive physical radius (including a small margin).
        let isWithinInteractionRadius: Bool
    }
    
    // MARK: - 3D Volume Intersection Types
    
    /// Rich 3D intersection result with the spinner interaction volume.
    struct RayVolumeIntersection: Sendable, Equatable {
        /// Exact 3D intersection point in world coordinates.
        let worldPoint: simd_float3
        /// 3D intersection point in spinner's local coordinate frame.
        let localPoint: simd_float3
        /// Surface normal vector at contact point in world coordinates.
        let worldNormal: simd_float3
        /// Surface normal vector in local coordinates.
        let localNormal: simd_float3
        /// In-plane lever arm vector from rotation axis to contact point in world coordinates.
        let inPlaneRadiusVector: simd_float3
        /// Perpendicular distance from rotation axis to contact point in meters.
        let leverArmDistance: Float
        /// Which surface of the 3D spinner volume was struck.
        let surfaceType: SpinnerSurfaceType
        /// Distance from camera ray origin to intersection point along the ray.
        let rayDistance: Float
        /// Whether contact is within the physical body boundary (not just margin).
        let isDirectHit: Bool
    }
    
    // MARK: - 3D Ray-Volume Intersection
    
    /// Intersects a 3D ray with the finite 3D volume (thick disc / cylinder) of the fidget spinner.
    /// Accurately detects contact with the top face, bottom face, outer rim, and side edges of the wings.
    ///
    /// - Parameters:
    ///   - rayOrigin: World position of the camera ray origin.
    ///   - rayDirection: World direction vector of the camera ray (normalized).
    ///   - spinnerCenter: World center position of the fidget spinner.
    ///   - rotationAxis: Unit vector of spinner rotation axis in world coordinates.
    ///   - spinnerOrientation: Complete world orientation quaternion of the spinner.
    ///   - radius: Outer physical radius of the spinner in meters.
    ///   - thickness: Physical axial thickness of the spinner in meters.
    ///   - marginMultiplier: Tolerance multiplier for boundary hits.
    /// - Returns: `RayVolumeIntersection` if the ray strikes the 3D spinner volume, or `nil` if it misses.
    static func intersectRayWithSpinnerVolume(
        rayOrigin: simd_float3,
        rayDirection: simd_float3,
        spinnerCenter: simd_float3,
        rotationAxis: simd_float3,
        spinnerOrientation: simd_quatf? = nil,
        radius: Float,
        thickness: Float,
        marginMultiplier: Float = 1.0
    ) -> RayVolumeIntersection? {
        let axis = VectorMath.safeNormalize(rotationAxis)
        let rayDir = VectorMath.safeNormalize(rayDirection)
        guard VectorMath.isFinite(rayOrigin), VectorMath.isFinite(rayDir), radius > 0.005 else {
            return nil
        }
        
        let safeThickness = max(0.008, thickness)
        let halfHeight = safeThickness * 0.5
        
        // 1. Construct Orthonormal Frame (Y = rotation axis, X and Z span the spin plane)
        let xAxis: simd_float3
        let zAxis: simd_float3
        let yAxis = axis
        
        if let orient = spinnerOrientation {
            // Derive basis from actual entity orientation
            xAxis = QuaternionHelper.rotatedXAxis(from: orient)
            zAxis = QuaternionHelper.rotatedZAxis(from: orient)
        } else {
            let refVec: simd_float3 = abs(axis.y) < 0.92 ? simd_float3(0, 1, 0) : simd_float3(1, 0, 0)
            xAxis = simd_normalize(simd_cross(refVec, axis))
            zAxis = simd_cross(axis, xAxis)
        }
        
        // 2. Transform Ray into Spinner's Local Coordinates
        let oRel = rayOrigin - spinnerCenter
        let oLocal = simd_float3(
            simd_dot(oRel, xAxis),
            simd_dot(oRel, yAxis),
            simd_dot(oRel, zAxis)
        )
        let dLocal = simd_float3(
            simd_dot(rayDir, xAxis),
            simd_dot(rayDir, yAxis),
            simd_dot(rayDir, zAxis)
        )
        
        let effRadius = radius * marginMultiplier
        let effHalfHeight = halfHeight * max(1.0, marginMultiplier * 0.9)
        let effRadiusSq = effRadius * effRadius
        
        struct HitCandidate {
            let t: Float
            let localPoint: simd_float3
            let localNormal: simd_float3
            let surface: SpinnerSurfaceType
        }
        
        var candidates: [HitCandidate] = []
        candidates.reserveCapacity(4)
        
        // 3. Test Top Planar Cap (y = +effHalfHeight)
        if abs(dLocal.y) > 1e-6 {
            let tTop = (effHalfHeight - oLocal.y) / dLocal.y
            if tTop > 0.001 {
                let x = oLocal.x + tTop * dLocal.x
                let z = oLocal.z + tTop * dLocal.z
                if (x * x + z * z) <= effRadiusSq {
                    candidates.append(HitCandidate(
                        t: tTop,
                        localPoint: simd_float3(x, effHalfHeight, z),
                        localNormal: simd_float3(0, 1, 0),
                        surface: .topFace
                    ))
                }
            }
        }
        
        // 4. Test Bottom Planar Cap (y = -effHalfHeight)
        if abs(dLocal.y) > 1e-6 {
            let tBottom = (-effHalfHeight - oLocal.y) / dLocal.y
            if tBottom > 0.001 {
                let x = oLocal.x + tBottom * dLocal.x
                let z = oLocal.z + tBottom * dLocal.z
                if (x * x + z * z) <= effRadiusSq {
                    candidates.append(HitCandidate(
                        t: tBottom,
                        localPoint: simd_float3(x, -effHalfHeight, z),
                        localNormal: simd_float3(0, -1, 0),
                        surface: .bottomFace
                    ))
                }
            }
        }
        
        // 5. Test Cylindrical Side Wall (x² + z² = effRadius², y ∈ [-effHalfHeight, +effHalfHeight])
        let a = dLocal.x * dLocal.x + dLocal.z * dLocal.z
        if a > 1e-7 {
            let b = 2.0 * (oLocal.x * dLocal.x + oLocal.z * dLocal.z)
            let c = oLocal.x * oLocal.x + oLocal.z * oLocal.z - effRadiusSq
            let discriminant = b * b - 4.0 * a * c
            
            if discriminant >= 0.0 {
                let sqrtD = sqrt(discriminant)
                let t1 = (-b - sqrtD) / (2.0 * a)
                let t2 = (-b + sqrtD) / (2.0 * a)
                
                for tSide in [t1, t2] where tSide > 0.001 {
                    let y = oLocal.y + tSide * dLocal.y
                    if y >= -effHalfHeight && y <= effHalfHeight {
                        let x = oLocal.x + tSide * dLocal.x
                        let z = oLocal.z + tSide * dLocal.z
                        let radDist = sqrt(x * x + z * z)
                        let normSide = radDist > 1e-6 ? simd_float3(x / radDist, 0, z / radDist) : simd_float3(1, 0, 0)
                        
                        candidates.append(HitCandidate(
                            t: tSide,
                            localPoint: simd_float3(x, y, z),
                            localNormal: normSide,
                            surface: .sideEdge
                        ))
                    }
                }
            }
        }
        
        // 6. Select Nearest Visible Positive Hit
        guard let closest = candidates.min(by: { $0.t < $1.t }) else {
            return nil
        }
        
        // 7. Reconstruct World-Space Attributes
        let worldPt = spinnerCenter + (xAxis * closest.localPoint.x) + (yAxis * closest.localPoint.y) + (zAxis * closest.localPoint.z)
        let worldNorm = (xAxis * closest.localNormal.x) + (yAxis * closest.localNormal.y) + (zAxis * closest.localNormal.z)
        
        let inPlaneVec = VectorMath.projectOntoPlane(vector: worldPt - spinnerCenter, planeNormal: axis)
        let leverArm = simd_length(inPlaneVec)
        
        let isDirect = leverArm <= (radius * 1.05) && abs(closest.localPoint.y) <= (halfHeight * 1.15)
        let resolvedSurface: SpinnerSurfaceType = isDirect ? closest.surface : .margin
        
        return RayVolumeIntersection(
            worldPoint: worldPt,
            localPoint: closest.localPoint,
            worldNormal: VectorMath.safeNormalize(worldNorm),
            localNormal: closest.localNormal,
            inPlaneRadiusVector: inPlaneVec,
            leverArmDistance: leverArm,
            surfaceType: resolvedSurface,
            rayDistance: closest.t,
            isDirectHit: isDirect
        )
    }
    
    // MARK: - Legacy Planar Projection
    
    /// Projects a 3D ray from the camera onto the spinner's rotating disc plane.
    /// - Parameters:
    ///   - rayOrigin: World position of the camera ray origin.
    ///   - rayDirection: World direction vector of the camera ray.
    ///   - spinnerCenter: World center position of the fidget spinner.
    ///   - spinnerNormal: World unit normal vector of the spinner disc (its rotation axis).
    ///   - maxRadius: Outer physical radius of the spinner.
    ///   - marginMultiplier: Tolerance multiplier for boundary hits.
    /// - Returns: `ProjectionResult` if the ray intersects the plane, or `nil` if parallel.
    static func projectRayOntoSpinnerPlane(
        rayOrigin: simd_float3,
        rayDirection: simd_float3,
        spinnerCenter: simd_float3,
        spinnerNormal: simd_float3,
        maxRadius: Float,
        marginMultiplier: Float = 1.25
    ) -> ProjectionResult? {
        guard let hitPoint = VectorMath.rayPlaneIntersection(
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            planePoint: spinnerCenter,
            planeNormal: spinnerNormal
        ) else {
            return nil
        }
        
        let radiusVec = hitPoint - spinnerCenter
        let distance = simd_length(radiusVec)
        let effectiveRadius = maxRadius * marginMultiplier
        let isWithinBounds = distance <= effectiveRadius
        
        return ProjectionResult(
            worldPoint: hitPoint,
            radiusVector: radiusVec,
            distanceFromCenter: distance,
            isWithinInteractionRadius: isWithinBounds
        )
    }
}
