import Foundation
import RealityKit
import simd
import Combine

/// In-memory cache holding loaded RealityKit template entities to eliminate repeated USDZ file loads and disk I/O.
final class RealityKitEntityCache: @unchecked Sendable {
    static let shared = RealityKitEntityCache()
    private let cache = NSCache<NSString, Entity>()
    
    private init() {
        cache.countLimit = 15
    }
    
    func getEntity(for key: String) -> Entity? {
        return cache.object(forKey: key as NSString)?.clone(recursive: true)
    }
    
    func setEntity(_ entity: Entity, for key: String) {
        cache.setObject(entity.clone(recursive: true), forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

/// Normalizes and manages external USDZ spinner models with precise pivot centering and interactive scaling.
@MainActor
final class USDZSpinnerEntityFactory: SpinnerEntityProviding {
    
    // MARK: - Properties
    
    private(set) var currentDiameter: Float
    private(set) var thickness: Float
    
    let modelDescriptor: SpinnerModelDescriptor
    private let proceduralFallback: SpinnerEntityFactory
    
    /// Cached raw geometry metadata from original unscaled USDZ asset
    private(set) var rawDiameter: Float = 1.0
    private(set) var rawCenter: simd_float3 = .zero
    private(set) var rawThickness: Float = 0.015
    private(set) var rawOrientation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])
    private(set) var initialUniformScale: Float = 1.0
    
    // MARK: - Initialization
    
    init(
        modelDescriptor: SpinnerModelDescriptor,
        defaultDiameter: Float = 0.076, // 7.6 cm default
        configuration: SpinnerConfiguration = .standard
    ) {
        self.modelDescriptor = modelDescriptor
        self.currentDiameter = defaultDiameter
        self.thickness = configuration.thickness
        self.proceduralFallback = SpinnerEntityFactory(configuration: configuration)
    }
    
    convenience init(
        assetName: String = "Spinner",
        defaultDiameter: Float = 0.076,
        configuration: SpinnerConfiguration = .standard
    ) {
        let descriptor = SpinnerModelDescriptor(
            id: assetName,
            fileName: "\(assetName).usdz",
            assetName: assetName,
            displayNameEn: SpinnerModelDescriptor.formatFriendlyName(from: assetName),
            displayNameVi: SpinnerModelDescriptor.formatFriendlyName(from: assetName)
        )
        self.init(modelDescriptor: descriptor, defaultDiameter: defaultDiameter, configuration: configuration)
    }
    
    // MARK: - Asynchronous Loading
    
    /// Asynchronously loads and normalizes the USDZ model entity without blocking the main actor.
    func loadSpinnerEntityAsync(targetDiameter: Float) async throws -> (root: Entity, rotatingBody: Entity, collisionEntity: Entity) {
        let diameter = (targetDiameter.isFinite && targetDiameter > 0.01) ? targetDiameter : currentDiameter
        self.currentDiameter = diameter
        
        let cacheKey = modelDescriptor.fileURL?.path ?? modelDescriptor.assetName
        if let cachedEntity = RealityKitEntityCache.shared.getEntity(for: cacheKey) {
            return buildNormalizedHierarchy(from: cachedEntity, targetDiameter: diameter)
        }
        
        let modelEntity: Entity
        if let url = modelDescriptor.fileURL, FileManager.default.fileExists(atPath: url.path) {
            modelEntity = try await Self.loadEntityAsync(from: url)
        } else {
            modelEntity = try await Self.loadEntityNamedAsync(modelDescriptor.assetName)
        }
        
        RealityKitEntityCache.shared.setEntity(modelEntity, for: cacheKey)
        return buildNormalizedHierarchy(from: modelEntity, targetDiameter: diameter)
    }
    
    private static func loadEntityAsync(from url: URL) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var hasResumed = false
            cancellable = Entity.loadAsync(contentsOf: url)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion, !hasResumed {
                            hasResumed = true
                            continuation.resume(throwing: error)
                        }
                        _ = cancellable
                    },
                    receiveValue: { entity in
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(returning: entity)
                        }
                    }
                )
        }
    }
    
    private static func loadEntityNamedAsync(_ name: String) async throws -> Entity {
        do {
            return try await loadEntityNamedRawAsync(name)
        } catch {
            if !name.hasSuffix(".usdz") {
                return try await loadEntityNamedRawAsync("\(name).usdz")
            }
            throw error
        }
    }
    
    private static func loadEntityNamedRawAsync(_ name: String) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var hasResumed = false
            cancellable = Entity.loadAsync(named: name)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion, !hasResumed {
                            hasResumed = true
                            continuation.resume(throwing: error)
                        }
                        _ = cancellable
                    },
                    receiveValue: { entity in
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(returning: entity)
                        }
                    }
                )
        }
    }
    
    // MARK: - SpinnerEntityProviding
    
    func createSpinnerEntity(targetDiameter: Float) -> (root: Entity, rotatingBody: Entity, collisionEntity: Entity) {
        let diameter = (targetDiameter.isFinite && targetDiameter > 0.01) ? targetDiameter : currentDiameter
        self.currentDiameter = diameter
        
        let cacheKey = modelDescriptor.fileURL?.path ?? modelDescriptor.assetName
        if let cachedEntity = RealityKitEntityCache.shared.getEntity(for: cacheKey) {
            return buildNormalizedHierarchy(from: cachedEntity, targetDiameter: diameter)
        }
        
        // 1. Attempt to load from fileURL if available on disk
        if let url = modelDescriptor.fileURL, FileManager.default.fileExists(atPath: url.path),
           let modelEntity = try? Entity.load(contentsOf: url) {
            RealityKitEntityCache.shared.setEntity(modelEntity, for: cacheKey)
            return buildNormalizedHierarchy(from: modelEntity, targetDiameter: diameter)
        }
        
        // 2. Attempt to load by named asset from application bundle
        if let modelEntity = (try? Entity.load(named: modelDescriptor.assetName)) ?? (try? Entity.load(named: "\(modelDescriptor.assetName).usdz")) {
            RealityKitEntityCache.shared.setEntity(modelEntity, for: cacheKey)
            return buildNormalizedHierarchy(from: modelEntity, targetDiameter: diameter)
        }
        
        AppLogger.scene.warning("USDZ asset '\(self.modelDescriptor.assetName)' not found in bundle. Using procedural model.")
        return proceduralFallback.createSpinnerEntity(targetDiameter: diameter)
    }
    
    func updateDiameter(
        _ newDiameter: Float,
        on root: Entity,
        rotatingBody: Entity,
        collisionEntity: Entity
    ) {
        guard newDiameter.isFinite, newDiameter > 0.01, rawDiameter > 0.001 else {
            AppLogger.scene.warning("Invalid diameter update: \(newDiameter)")
            return
        }
        
        self.currentDiameter = newDiameter
        let scale = newDiameter / rawDiameter
        
        // 1. Update visual model scale and centered position
        if let visualModel = rotatingBody.children.first(where: { $0.name == "NormalizedVisualModel" }) {
            visualModel.scale = simd_float3(scale, scale, scale)
            visualModel.orientation = rawOrientation
            visualModel.position = -rawOrientation.act(rawCenter * scale)
        } else {
            // In case visualModel was directly rotatingBody or procedural fallback
            proceduralFallback.updateDiameter(newDiameter, on: root, rotatingBody: rotatingBody, collisionEntity: collisionEntity)
            return
        }
        
        // 2. Update collision shape to tightly envelope the resized spinner
        let currentThickness = rawThickness * scale
        self.thickness = currentThickness
        
        let collisionBoxSize = simd_float3(
            newDiameter * 1.05,
            max(0.016, currentThickness * 1.6),
            newDiameter * 1.05
        )
        let newShape = ShapeResource.generateBox(size: collisionBoxSize)
        collisionEntity.components.set(CollisionComponent(shapes: [newShape]))
        
        AppLogger.scene.info("Updated USDZ spinner diameter to \(newDiameter * 100.0, format: .fixed(precision: 1)) cm (scale: \(scale))")
    }
    
    // MARK: - Normalization Engine
    
    /// Pure calculation helper for model normalization, exposed for direct mathematical unit testing.
    nonisolated static func calculateNormalization(
        extents: simd_float3,
        center: simd_float3,
        targetDiameter: Float
    ) -> (scale: Float, centerOffset: simd_float3, scaledThickness: Float, collisionBoxSize: simd_float3)? {
        let horizontalSpan = max(extents.x, extents.z)
        guard horizontalSpan.isFinite, horizontalSpan > 0.001, targetDiameter.isFinite, targetDiameter > 0.001 else {
            return nil
        }
        let scale = targetDiameter / horizontalSpan
        let rawThickness = (extents.y.isFinite && extents.y > 0.001) ? extents.y : 0.012
        let scaledThickness = rawThickness * scale
        let safeCenter = VectorMath.isFinite(center) ? center : .zero
        let centerOffset = -safeCenter * scale
        let collisionBox = simd_float3(
            targetDiameter * 1.05,
            max(0.016, scaledThickness * 1.6),
            targetDiameter * 1.05
        )
        return (scale: scale, centerOffset: centerOffset, scaledThickness: scaledThickness, collisionBoxSize: collisionBox)
    }
    
    /// Normalizes raw model bounds so origin (0, 0, 0) is precisely at the central bearing core,
    /// XZ is the horizontal spin plane, and the horizontal span exactly matches `targetDiameter`.
    func buildNormalizedHierarchy(
        from modelEntity: Entity,
        targetDiameter: Float
    ) -> (root: Entity, rotatingBody: Entity, collisionEntity: Entity) {
        // 1. Calculate actual visual bounding box across all children
        let bounds = modelEntity.visualBounds(relativeTo: modelEntity)
        let extents = bounds.extents
        let center = bounds.center
        
        // Detect if model was authored with a different up-axis / thin-axis (e.g. thin along Z or X)
        var orientation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])
        var effectiveExtents = extents
        if extents.z < extents.y && extents.z < extents.x {
            // Thin axis is Z (modeled upright in XY plane). Rotate +90° around X to lie flat in XZ.
            orientation = simd_quatf(angle: .pi / 2.0, axis: simd_float3(1, 0, 0))
            effectiveExtents = simd_float3(extents.x, extents.z, extents.y)
        } else if extents.x < extents.y && extents.x < extents.z {
            // Thin axis is X (modeled upright in YZ plane). Rotate +90° around Z to lie flat in XZ.
            orientation = simd_quatf(angle: .pi / 2.0, axis: simd_float3(0, 0, 1))
            effectiveExtents = simd_float3(extents.y, extents.x, extents.z)
        }
        self.rawOrientation = orientation
        
        guard let norm = Self.calculateNormalization(extents: effectiveExtents, center: center, targetDiameter: targetDiameter) else {
            AppLogger.scene.error("USDZ bounds are invalid or degenerate: extents=\(extents)")
            return proceduralFallback.createSpinnerEntity(targetDiameter: targetDiameter)
        }
        
        let horizontalSpan = max(effectiveExtents.x, effectiveExtents.z)
        self.rawDiameter = horizontalSpan
        self.rawCenter = VectorMath.isFinite(center) ? center : .zero
        self.rawThickness = (effectiveExtents.y.isFinite && effectiveExtents.y > 0.001) ? effectiveExtents.y : 0.012
        self.initialUniformScale = norm.scale
        self.thickness = norm.scaledThickness
        
        // 2. Configure Root Entity (Stationary container in world space)
        let root = Entity()
        root.name = "SpinnerRoot"
        
        // 3. Configure Collision Entity (Fixed child of root, covers physical interactive zone)
        let collisionEntity = Entity()
        collisionEntity.name = "SpinnerCollision"
        let collisionShape = ShapeResource.generateBox(size: norm.collisionBoxSize)
        collisionEntity.components.set(CollisionComponent(shapes: [collisionShape]))
        root.addChild(collisionEntity)
        
        // 4. Configure Rotating Rigid Body (Rotates around local Y-axis [0, 1, 0])
        let rotatingBody = Entity()
        rotatingBody.name = "SpinnerBody"
        root.addChild(rotatingBody)
        
        // 5. Position, rotate and scale the visual model inside rotatingBody so central bearing is at (0,0,0)
        modelEntity.name = "NormalizedVisualModel"
        modelEntity.scale = simd_float3(norm.scale, norm.scale, norm.scale)
        modelEntity.orientation = orientation
        modelEntity.position = -orientation.act(self.rawCenter * norm.scale)
        rotatingBody.addChild(modelEntity)
        
        AppLogger.scene.info("Normalized USDZ model '\(self.modelDescriptor.id)': rawDiameter=\(horizontalSpan, format: .fixed(precision: 3))m -> target=\(targetDiameter, format: .fixed(precision: 3))m, scale=\(norm.scale, format: .fixed(precision: 6)), center=\(self.rawCenter)")
        return (root: root, rotatingBody: rotatingBody, collisionEntity: collisionEntity)
    }
}
