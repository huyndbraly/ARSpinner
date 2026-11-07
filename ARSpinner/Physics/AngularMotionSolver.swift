import Foundation

/// Numerically integrates rotational equations of motion with sub-stepping for FPS independence.
final class AngularMotionSolver: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let fixedTimestep: Float
    private let maxSubSteps: Int
    private var accumulator: Float = 0.0
    
    // MARK: - Initialization
    
    /// - Parameters:
    ///   - fixedTimestep: Internal simulation timestep (default 1/240 sec for high fidelity).
    ///   - maxSubSteps: Maximum sub-steps per frame to prevent spiral of death during lag spikes.
    init(fixedTimestep: Float = 1.0 / 240.0, maxSubSteps: Int = 8) {
        self.fixedTimestep = fixedTimestep
        self.maxSubSteps = maxSubSteps
    }
    
    // MARK: - Integration
    
    /// Integrates the physics state over variable `deltaTime` using fixed sub-steps.
    /// - Parameters:
    ///   - state: Inout reference to the physics state.
    ///   - appliedTorque: External torque applied during this step.
    ///   - frictionModel: The friction model providing resistive torque.
    ///   - config: Configuration containing max speed, stop threshold, etc.
    ///   - spinMode: Active spin mode (.natural or .continuous).
    ///   - isInContinuousGracePeriod: Whether continuous spin is within the inter-stroke grace period (reducing friction).
    ///   - deltaTime: Elapsed real time since last frame in seconds.
    func step(
        state: inout SpinnerPhysicsState,
        appliedTorque: Float,
        frictionModel: any FrictionModeling,
        config: SpinnerConfiguration,
        spinMode: SpinMode = .natural,
        isInContinuousGracePeriod: Bool = false,
        deltaTime: TimeInterval
    ) {
        // Clamp deltaTime to avoid extreme jumps (e.g. returning from background)
        let dt = Float(min(max(deltaTime, 0.0), 0.1))
        accumulator += dt
        
        var steps = 0
        while accumulator >= fixedTimestep && steps < maxSubSteps {
            subStep(
                state: &state,
                appliedTorque: appliedTorque,
                frictionModel: frictionModel,
                config: config,
                spinMode: spinMode,
                isInContinuousGracePeriod: isInContinuousGracePeriod,
                h: fixedTimestep
            )
            accumulator -= fixedTimestep
            steps += 1
        }
        
        // If remaining accumulator is too large, drop excess to prevent lag accumulation
        if accumulator > fixedTimestep * Float(maxSubSteps) {
            accumulator = 0.0
        }
    }
    
    /// Single fixed-time numerical integration sub-step using Semi-Implicit Euler with friction clamping.
    private func subStep(
        state: inout SpinnerPhysicsState,
        appliedTorque: Float,
        frictionModel: any FrictionModeling,
        config: SpinnerConfiguration,
        spinMode: SpinMode,
        isInContinuousGracePeriod: Bool,
        h: Float
    ) {
        let I = state.momentOfInertia
        guard I > 1e-7 else { return }
        
        let omega = state.angularVelocity
        
        // 1. Compute friction torque based on current velocity
        var frictionTorque = frictionModel.computeFrictionTorque(
            angularVelocity: omega,
            momentOfInertia: I
        )
        
        // In Continuous Spin mode during the inter-stroke grace period (~0.5s),
        // reduce friction drag significantly (damped to 10%) so user flicks can chain momentum
        // without shedding RPM between quick successive strokes.
        if isInContinuousGracePeriod {
            frictionTorque *= 0.10
        }
        
        state.frictionTorque = frictionTorque
        state.appliedTorque = appliedTorque
        
        // Total torque
        let totalTorque = appliedTorque + frictionTorque
        let alpha = totalTorque / I
        state.angularAcceleration = alpha
        
        // 2. Predict next angular velocity
        var nextOmega = omega + (alpha * h)
        
        // 3. Physical stop condition for friction:
        // Friction alone can NEVER accelerate an object in the reverse direction.
        // If no external torque is applied and nextOmega crossed zero, or is below threshold, stop it.
        if abs(appliedTorque) < 1e-6 {
            if (omega > 0 && nextOmega <= 0) || (omega < 0 && nextOmega >= 0) {
                nextOmega = 0.0
            } else if abs(nextOmega) < config.stopThreshold {
                nextOmega = 0.0
            }
        }
        
        // 4. Clamp to max angular velocity (enforce continuous spin cap of 2,000 RPM if active)
        let maxOmega: Float
        if spinMode == .continuous {
            maxOmega = SpinMode.continuousMaxAngularVelocity
        } else {
            maxOmega = config.maxAngularVelocity
        }
        nextOmega = VectorMath.clamp(nextOmega, min: -maxOmega, max: maxOmega)
        
        state.angularVelocity = nextOmega
        
        // Track peak velocity
        if abs(nextOmega) > abs(state.peakAngularVelocity) {
            state.peakAngularVelocity = nextOmega
        }
        
        // 5. Update angular position
        let deltaTheta = nextOmega * h
        state.angle += deltaTheta
        
        // 6. Accumulate revolutions
        let deltaRevs = Double(abs(deltaTheta)) / Double(VectorMath.radiansPerRevolution)
        state.totalRevolutions += deltaRevs
    }
    
    /// Resets the internal time accumulator.
    func reset() {
        accumulator = 0.0
    }
}

