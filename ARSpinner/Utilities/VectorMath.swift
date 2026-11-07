import Foundation
import simd

/// High-performance 3D vector math and physics utilities using SIMD.
enum VectorMath {
    
    // MARK: - Constants
    
    static let floatEpsilon: Float = 1e-6
    static let doubleEpsilon: Double = 1e-9
    static let radiansPerRevolution: Float = 2.0 * .pi
    static let rpmConversionFactor: Float = 60.0 / (2.0 * .pi) // ~9.54929658
    
    // MARK: - Unit Conversions
    
    /// Converts angular velocity in radians per second to Revolutions Per Minute (RPM).
    @inlinable
    static func radPerSecToRPM(_ radPerSec: Float) -> Float {
        return radPerSec * rpmConversionFactor
    }
    
    /// Converts Revolutions Per Minute (RPM) to angular velocity in radians per second.
    @inlinable
    static func rpmToRadPerSec(_ rpm: Float) -> Float {
        return rpm / rpmConversionFactor
    }
    
    /// Converts degrees to radians.
    @inlinable
    static func degreesToRadians(_ degrees: Float) -> Float {
        return degrees * (.pi / 180.0)
    }
    
    /// Converts radians to degrees.
    @inlinable
    static func radiansToDegrees(_ radians: Float) -> Float {
        return radians * (180.0 / .pi)
    }
    
    /// Normalizes an angle in radians to the range [0, 2π).
    @inlinable
    static func normalizeAngle2Pi(_ angle: Float) -> Float {
        var a = angle.truncatingRemainder(dividingBy: radiansPerRevolution)
        if a < 0 {
            a += radiansPerRevolution
        }
        return a
    }
    
    /// Normalizes an angle in radians to the range [-π, π].
    @inlinable
    static func normalizeAngleSignedPi(_ angle: Float) -> Float {
        var a = angle.truncatingRemainder(dividingBy: radiansPerRevolution)
        if a > .pi {
            a -= radiansPerRevolution
        } else if a < -.pi {
            a += radiansPerRevolution
        }
        return a
    }
    
    // MARK: - Vector Operations
    
    /// Computes the cross product of two 3D vectors.
    @inlinable
    static func cross(_ a: simd_float3, _ b: simd_float3) -> simd_float3 {
        return simd_cross(a, b)
    }
    
    /// Computes the dot product of two 3D vectors.
    @inlinable
    static func dot(_ a: simd_float3, _ b: simd_float3) -> Float {
        return simd_dot(a, b)
    }
    
    /// Computes the Euclidean length of a 3D vector.
    @inlinable
    static func length(_ v: simd_float3) -> Float {
        return simd_length(v)
    }
    
    /// Returns the normalized vector or zero if the length is too close to zero.
    @inlinable
    static func safeNormalize(_ v: simd_float3) -> simd_float3 {
        let len = simd_length(v)
        guard len > floatEpsilon else { return simd_float3(0, 0, 0) }
        return v / len
    }
    
    /// Projects a 3D vector onto a plane defined by its unit normal vector.
    /// v_proj = v - (v · n) * n
    @inlinable
    static func projectOntoPlane(vector: simd_float3, planeNormal: simd_float3) -> simd_float3 {
        let n = safeNormalize(planeNormal)
        let projectionOnNormal = simd_dot(vector, n) * n
        return vector - projectionOnNormal
    }
    
    // MARK: - Ray-Plane Intersection
    
    /// Computes the intersection of a 3D ray with a 3D plane.
    /// - Parameters:
    ///   - rayOrigin: The starting point of the ray in world coordinates.
    ///   - rayDirection: The direction vector of the ray.
    ///   - planePoint: A point that lies on the plane.
    ///   - planeNormal: The normal vector of the plane (should be normalized).
    /// - Returns: The intersection point in world coordinates, or nil if ray is parallel or pointing away.
    static func rayPlaneIntersection(
        rayOrigin: simd_float3,
        rayDirection: simd_float3,
        planePoint: simd_float3,
        planeNormal: simd_float3
    ) -> simd_float3? {
        guard isFinite(rayOrigin), isFinite(rayDirection), isFinite(planePoint), isFinite(planeNormal) else {
            return nil
        }
        let normal = safeNormalize(planeNormal)
        let direction = safeNormalize(rayDirection)
        guard simd_length(normal) > floatEpsilon, simd_length(direction) > floatEpsilon else {
            return nil
        }
        
        let denominator = simd_dot(direction, normal)
        
        // Ray is parallel or almost parallel to the plane
        guard abs(denominator) > floatEpsilon else {
            return nil
        }
        
        // Parameter t along the ray: t = ((planePoint - rayOrigin) · normal) / (direction · normal)
        let t = simd_dot(planePoint - rayOrigin, normal) / denominator
        
        // Only consider forward intersections (t >= 0)
        guard t >= 0, t.isFinite else {
            return nil
        }
        
        let hit = rayOrigin + (direction * t)
        return isFinite(hit) ? hit : nil
    }
    
    /// Clamps a float value between a minimum and maximum bound.
    @inlinable
    static func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
        return min(max(value, minValue), maxValue)
    }
    
    // MARK: - Finite Value Validation
    
    /// Returns true if all components of the 3D vector are finite (neither NaN nor infinite).
    @inlinable
    static func isFinite(_ v: simd_float3) -> Bool {
        return v.x.isFinite && v.y.isFinite && v.z.isFinite
    }
    
    /// Returns true if all components of the 4D vector are finite.
    @inlinable
    static func isFinite(_ v: simd_float4) -> Bool {
        return v.x.isFinite && v.y.isFinite && v.z.isFinite && v.w.isFinite
    }
    
    /// Returns true if all components of the quaternion are finite.
    @inlinable
    static func isFinite(_ q: simd_quatf) -> Bool {
        return q.vector.x.isFinite && q.vector.y.isFinite && q.vector.z.isFinite && q.vector.w.isFinite
    }
    
    /// Returns true if all elements of the 4x4 matrix are finite.
    @inlinable
    static func isFinite(_ m: simd_float4x4) -> Bool {
        return isFinite(m.columns.0) && isFinite(m.columns.1) && isFinite(m.columns.2) && isFinite(m.columns.3)
    }
}

