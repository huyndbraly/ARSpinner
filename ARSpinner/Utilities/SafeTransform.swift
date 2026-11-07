import Foundation
import RealityKit
import simd

/// Utility for validating and decomposing 4x4 transformation matrices into strictly finite, orthonormal RealityKit Transforms.
/// Eliminates `Call to RETransformComponentSetLocalSRT contains NaN` errors.
enum SafeTransform {
    
    /// Safely decomposes a 4x4 matrix into an orthonormalized, finite RealityKit `Transform`.
    /// - Parameters:
    ///   - matrix: Input 4x4 matrix (e.g. from ARRaycastResult or camera frame).
    ///   - fallbackTranslation: Translation to use if matrix translation contains non-finite numbers.
    /// - Returns: A valid `Transform` free of NaNs and infinities, or `nil` if matrix is completely degenerate.
    static func create(from matrix: simd_float4x4, fallbackTranslation: simd_float3? = nil) -> Transform? {
        // 1. Validate raw matrix finiteness
        guard VectorMath.isFinite(matrix) else {
            AppLogger.general.warning("SafeTransform: Input matrix contains non-finite values.")
            return nil
        }
        
        // 2. Extract and validate translation
        let translation = simd_float3(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
        guard VectorMath.isFinite(translation) else {
            AppLogger.general.warning("SafeTransform: Translation is non-finite.")
            return nil
        }
        
        // 3. Extract rotation column vectors
        let col0 = simd_float3(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)
        let col1 = simd_float3(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z)
        let col2 = simd_float3(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
        
        let len0 = simd_length(col0)
        let len1 = simd_length(col1)
        let len2 = simd_length(col2)
        
        guard len0 > VectorMath.floatEpsilon,
              len1 > VectorMath.floatEpsilon,
              len2 > VectorMath.floatEpsilon else {
            AppLogger.general.warning("SafeTransform: Matrix basis vectors have zero or near-zero length.")
            return nil
        }
        
        // 4. Gram-Schmidt orthonormalization:
        // Y-axis represents surface normal or gravity up
        let yAxis = col1 / len1
        
        // Project col0 onto plane orthogonal to yAxis
        let projX = col0 - simd_dot(col0, yAxis) * yAxis
        let lenProjX = simd_length(projX)
        guard lenProjX > VectorMath.floatEpsilon else {
            AppLogger.general.warning("SafeTransform: Degenerate collinear basis vectors.")
            return nil
        }
        let xAxis = projX / lenProjX
        
        // Z-axis completes right-handed orthonormal basis
        let zAxis = simd_cross(xAxis, yAxis)
        
        // Construct 3x3 orthonormal rotation matrix
        let rotMatrix = simd_float3x3(columns: (xAxis, yAxis, zAxis))
        
        // 5. Convert to unit quaternion
        let quat = simd_quatf(rotMatrix)
        guard VectorMath.isFinite(quat) else {
            AppLogger.general.warning("SafeTransform: Generated quaternion is non-finite.")
            return nil
        }
        
        let normQuat = simd_normalize(quat)
        guard VectorMath.isFinite(normQuat) else {
            AppLogger.general.warning("SafeTransform: Normalized quaternion is non-finite.")
            return nil
        }
        
        // 6. Return strictly sanitized Transform
        return Transform(scale: simd_float3(1, 1, 1), rotation: normQuat, translation: translation)
    }
    
    /// Verifies whether a RealityKit `Transform` is entirely finite and valid.
    static func isValid(_ transform: Transform) -> Bool {
        return VectorMath.isFinite(transform.translation) &&
               VectorMath.isFinite(transform.rotation) &&
               VectorMath.isFinite(transform.scale) &&
               transform.scale.x > 0 &&
               transform.scale.y > 0 &&
               transform.scale.z > 0
    }
}

