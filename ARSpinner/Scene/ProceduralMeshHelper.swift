import Foundation
import RealityKit
import simd

/// Helper for generating procedural 3D meshes compatible with iOS 17 and iOS 18+.
enum ProceduralMeshHelper {
    
    /// Generates a cylindrical mesh resource with top and bottom caps and smooth normals.
    /// Compatible with iOS 17+.
    static func generateCylinder(height: Float, radius: Float, segments: Int = 24) -> MeshResource {
        var descriptor = MeshDescriptor(name: "ProceduralCylinder")
        
        var positions: [simd_float3] = []
        var normals: [simd_float3] = []
        var uvs: [simd_float2] = []
        var indices: [UInt32] = []
        
        let halfHeight = height * 0.5
        let segmentAngle = (2.0 * Float.pi) / Float(segments)
        
        // 1. Side wall vertices
        for i in 0...segments {
            let theta = Float(i) * segmentAngle
            let cosTheta = cos(theta)
            let sinTheta = sin(theta)
            
            let x = radius * cosTheta
            let z = radius * sinTheta
            let normal = simd_float3(cosTheta, 0, sinTheta)
            let u = Float(i) / Float(segments)
            
            // Top rim vertex
            positions.append(simd_float3(x, halfHeight, z))
            normals.append(normal)
            uvs.append(simd_float2(u, 1.0))
            
            // Bottom rim vertex
            positions.append(simd_float3(x, -halfHeight, z))
            normals.append(normal)
            uvs.append(simd_float2(u, 0.0))
        }
        
        // Side triangles
        for i in 0..<segments {
            let topLeft = UInt32(i * 2)
            let bottomLeft = UInt32(i * 2 + 1)
            let topRight = UInt32((i + 1) * 2)
            let bottomRight = UInt32((i + 1) * 2 + 1)
            
            indices.append(topLeft)
            indices.append(bottomLeft)
            indices.append(topRight)
            
            indices.append(topRight)
            indices.append(bottomLeft)
            indices.append(bottomRight)
        }
        
        // 2. Top cap
        let topCenterIndex = UInt32(positions.count)
        positions.append(simd_float3(0, halfHeight, 0))
        normals.append(simd_float3(0, 1, 0))
        uvs.append(simd_float2(0.5, 0.5))
        
        let topRimStartIndex = UInt32(positions.count)
        for i in 0...segments {
            let theta = Float(i) * segmentAngle
            let x = radius * cos(theta)
            let z = radius * sin(theta)
            positions.append(simd_float3(x, halfHeight, z))
            normals.append(simd_float3(0, 1, 0))
            uvs.append(simd_float2((cos(theta) + 1.0) * 0.5, (sin(theta) + 1.0) * 0.5))
        }
        for i in 0..<segments {
            indices.append(topCenterIndex)
            indices.append(topRimStartIndex + UInt32(i))
            indices.append(topRimStartIndex + UInt32(i + 1))
        }
        
        // 3. Bottom cap
        let bottomCenterIndex = UInt32(positions.count)
        positions.append(simd_float3(0, -halfHeight, 0))
        normals.append(simd_float3(0, -1, 0))
        uvs.append(simd_float2(0.5, 0.5))
        
        let bottomRimStartIndex = UInt32(positions.count)
        for i in 0...segments {
            let theta = Float(i) * segmentAngle
            let x = radius * cos(theta)
            let z = radius * sin(theta)
            positions.append(simd_float3(x, -halfHeight, z))
            normals.append(simd_float3(0, -1, 0))
            uvs.append(simd_float2((cos(theta) + 1.0) * 0.5, (sin(theta) + 1.0) * 0.5))
        }
        for i in 0..<segments {
            indices.append(bottomCenterIndex)
            indices.append(bottomRimStartIndex + UInt32(i + 1))
            indices.append(bottomRimStartIndex + UInt32(i))
        }
        
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)
        
        do {
            return try MeshResource.generate(from: [descriptor])
        } catch {
            // Fallback to basic box if descriptor fails
            return MeshResource.generateBox(width: radius * 2.0, height: height, depth: radius * 2.0)
        }
    }
}

