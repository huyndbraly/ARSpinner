import Foundation
import UIKit
import simd

/// State machine and trajectory tracker for touch interactions on the fidget spinner.
/// Accurately discriminates between taps, long presses, micro-movements, and genuine physical swipes.
final class InteractionStateMachine: @unchecked Sendable {
    
    // MARK: - Types
    
    struct TouchSample: Sendable {
        let screenPoint: CGPoint
        let worldPoint: simd_float3
        let surfaceType: SpinnerSurfaceType
        let timestamp: TimeInterval
        
        init(
            screenPoint: CGPoint,
            worldPoint: simd_float3,
            surfaceType: SpinnerSurfaceType = .topFace,
            timestamp: TimeInterval
        ) {
            self.screenPoint = screenPoint
            self.worldPoint = worldPoint
            self.surfaceType = surfaceType
            self.timestamp = timestamp
        }
    }
    
    enum State: Sendable, Equatable {
        case idle
        case touching(startScreenPoint: CGPoint, startWorldPoint: simd_float3)
        case swiping
    }
    
    struct ValidatedSwipe: Sendable {
        let startWorldPoint: simd_float3
        let endWorldPoint: simd_float3
        let duration: TimeInterval
        let contactWorldPoint: simd_float3
        let screenDistance: CGFloat
        let screenVelocity: CGFloat
    }
    
    // MARK: - Constants & Thresholds
    
    /// Minimum screen travel distance required to qualify as a swipe (points).
    static let minSwipeDistance: CGFloat = 12.0
    
    /// Minimum finger velocity required at release to impart rotational momentum (points/second).
    static let minSwipeVelocity: CGFloat = 60.0
    
    /// Time window evaluated prior to finger lift-off to calculate terminal flick velocity (seconds).
    static let trailingWindowDuration: TimeInterval = 0.120
    
    /// Maximum time finger can be stationary before release to still be considered a flick (seconds).
    /// If held longer than this, it is considered a held touch and imparts 0 impulse.
    static let maxRestDurationBeforeRelease: TimeInterval = 0.080
    
    /// Upper bound on physical world-space swipe velocity to eliminate tracking glitch spikes (m/s).
    static let maxWorldSwipeSpeed: Float = 3.5
    
    // MARK: - State
    
    private(set) var currentState: State = .idle
    private var samples: [TouchSample] = []
    private var initialScreenPoint: CGPoint = .zero
    private var initialWorldPoint: simd_float3 = .zero
    
    /// Most recent touch sample recorded.
    var lastSample: TouchSample? {
        return samples.last
    }
    
    /// Second most recent touch sample recorded, useful for computing delta displacement and velocity.
    var previousSample: TouchSample? {
        guard samples.count >= 2 else { return nil }
        return samples[samples.count - 2]
    }
    
    // MARK: - Lifecycle
    
    func onTouchBegan(
        screenPoint: CGPoint,
        worldPoint: simd_float3,
        surfaceType: SpinnerSurfaceType = .topFace,
        timestamp: TimeInterval
    ) {
        samples.removeAll(keepingCapacity: true)
        initialScreenPoint = screenPoint
        initialWorldPoint = worldPoint
        
        let sample = TouchSample(
            screenPoint: screenPoint,
            worldPoint: worldPoint,
            surfaceType: surfaceType,
            timestamp: timestamp
        )
        samples.append(sample)
        currentState = .touching(startScreenPoint: screenPoint, startWorldPoint: worldPoint)
    }
    
    func onTouchMoved(
        screenPoint: CGPoint,
        worldPoint: simd_float3,
        surfaceType: SpinnerSurfaceType = .topFace,
        timestamp: TimeInterval
    ) {
        guard VectorMath.isFinite(worldPoint), timestamp > 0 else { return }
        
        let sample = TouchSample(
            screenPoint: screenPoint,
            worldPoint: worldPoint,
            surfaceType: surfaceType,
            timestamp: timestamp
        )
        samples.append(sample)
        
        // Prune samples older than 0.5s to maintain an agile rolling window
        let cutoff = timestamp - 0.50
        while let first = samples.first, first.timestamp < cutoff && samples.count > 4 {
            samples.removeFirst()
        }
        
        currentState = .swiping
    }
    
    /// Evaluates the recorded touch trajectory upon finger release (`touchesEnded`).
    /// Returns `ValidatedSwipe` if and only if the gesture meets all distance, velocity, and timing criteria.
    func onTouchEnded(
        finalScreenPoint: CGPoint,
        finalWorldPoint: simd_float3?,
        timestamp: TimeInterval,
        spinnerCenter: simd_float3,
        rotationAxis: simd_float3,
        spinnerRadius: Float
    ) -> ValidatedSwipe? {
        defer {
            samples.removeAll()
            currentState = .idle
        }
        
        if let finalWorld = finalWorldPoint, VectorMath.isFinite(finalWorld) {
            samples.append(TouchSample(screenPoint: finalScreenPoint, worldPoint: finalWorld, timestamp: timestamp))
        }
        
        guard samples.count >= 2, samples.first != nil, let last = samples.last else {
            return nil
        }
        
        // 1. Minimum Total Screen Distance Check
        // Rejects stationary taps and micro-movements
        let dxTotal = last.screenPoint.x - initialScreenPoint.x
        let dyTotal = last.screenPoint.y - initialScreenPoint.y
        let totalScreenDistance = hypot(dxTotal, dyTotal)
        guard totalScreenDistance >= Self.minSwipeDistance else {
            AppLogger.interaction.debug("Gesture rejected: total screen distance (\(totalScreenDistance, format: .fixed(precision: 1)) pt) below threshold (\(Self.minSwipeDistance) pt).")
            return nil
        }
        
        // 2. Trailing Movement & Rest Duration Check
        // If the user moved their finger, held it stationary, and then lifted, it is NOT a flick!
        let trailingWindowStart = last.timestamp - Self.trailingWindowDuration
        let trailingSamples = samples.filter { $0.timestamp >= trailingWindowStart }
        
        guard trailingSamples.count >= 2,
              let trailingFirst = trailingSamples.first,
              let trailingLast = trailingSamples.last else {
            return nil
        }
        
        let trailingDuration = max(0.008, trailingLast.timestamp - trailingFirst.timestamp)
        let dxTrailing = trailingLast.screenPoint.x - trailingFirst.screenPoint.x
        let dyTrailing = trailingLast.screenPoint.y - trailingFirst.screenPoint.y
        let trailingDistance = hypot(dxTrailing, dyTrailing)
        let screenVelocity = trailingDistance / CGFloat(trailingDuration)
        
        guard screenVelocity >= Self.minSwipeVelocity else {
            AppLogger.interaction.debug("Gesture rejected: terminal velocity (\(screenVelocity, format: .fixed(precision: 1)) pt/s) below threshold (\(Self.minSwipeVelocity) pt/s).")
            return nil
        }
        
        // 3. Contact Point & Lever Arm Validation
        // Confirm that the swipe occurred across or immediately on the spinner disc
        let contactPoint = (trailingFirst.worldPoint + trailingLast.worldPoint) * 0.5
        let normal = VectorMath.safeNormalize(rotationAxis)
        let radiusVec = VectorMath.projectOntoPlane(vector: contactPoint - spinnerCenter, planeNormal: normal)
        let contactDistance = simd_length(radiusVec)
        
        // Catchment boundary: contact point must be within 1.35x spinner radius
        guard contactDistance <= (spinnerRadius * 1.35) else {
            AppLogger.interaction.debug("Gesture rejected: contact distance (\(contactDistance * 100, format: .fixed(precision: 1)) cm) outside catchment radius (\(spinnerRadius * 1.35 * 100, format: .fixed(precision: 1)) cm).")
            return nil
        }
        
        return ValidatedSwipe(
            startWorldPoint: trailingFirst.worldPoint,
            endWorldPoint: trailingLast.worldPoint,
            duration: trailingDuration,
            contactWorldPoint: contactPoint,
            screenDistance: totalScreenDistance,
            screenVelocity: screenVelocity
        )
    }
    
    func onTouchCancelled() {
        samples.removeAll()
        currentState = .idle
    }
}
