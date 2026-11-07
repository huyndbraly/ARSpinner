import Foundation
import simd

/// Helper for quaternion operations used in 3D rotation simulations.
enum QuaternionHelper {
    
    /// Creates a unit quaternion representing a rotation of `angle` (in radians) around `axis`.
    @inlinable
    static func fromAxisAngle(axis: simd_float3, angle: Float) -> simd_quatf {
        guard VectorMath.isFinite(axis), angle.isFinite else {
            return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }
        let len = simd_length(axis)
        guard len > VectorMath.floatEpsilon else {
            return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }
        let normalizedAxis = axis / len
        let q = simd_quatf(angle: angle, axis: normalizedAxis)
        return VectorMath.isFinite(q) ? q : simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    }
    
    /// Rotates a 3D vector by a quaternion.
    @inlinable
    static func rotate(vector: simd_float3, by rotation: simd_quatf) -> simd_float3 {
        return rotation.act(vector)
    }
    
    /// Spherical linear interpolation between two quaternions.
    @inlinable
    static func slerp(from q0: simd_quatf, to q1: simd_quatf, t: Float) -> simd_quatf {
        return simd_slerp(q0, q1, t)
    }
    
    /// Returns the local Y-axis rotated by the given orientation quaternion.
    @inlinable
    static func rotatedYAxis(from orientation: simd_quatf) -> simd_float3 {
        return orientation.act(simd_float3(0, 1, 0))
    }
    
    /// Returns the local X-axis rotated by the given orientation quaternion.
    @inlinable
    static func rotatedXAxis(from orientation: simd_quatf) -> simd_float3 {
        return orientation.act(simd_float3(1, 0, 0))
    }
    
    /// Returns the local Z-axis rotated by the given orientation quaternion.
    @inlinable
    static func rotatedZAxis(from orientation: simd_quatf) -> simd_float3 {
        return orientation.act(simd_float3(0, 0, 1))
    }
}

