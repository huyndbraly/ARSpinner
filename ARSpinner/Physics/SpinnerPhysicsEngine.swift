import Foundation
import simd

/// High-level physics simulation engine for the fidget spinner.
/// Strictly decoupled from RealityKit and rendering logic.
final class SpinnerPhysicsEngine: @unchecked Sendable {
    
    // MARK: - Properties
    
    private(set) var state: SpinnerPhysicsState
    private(set) var configuration: SpinnerConfiguration
    private(set) var spinMode: SpinMode = .natural
    private var frictionModel: any FrictionModeling
    private let solver: AngularMotionSolver
    
    /// External torque applied during current simulation step.
    private var pendingTorque: Float = 0.0
    
    /// Continuous user input torque actively exerted by finger contact (N·m).
    private(set) var activeInputTorque: Float = 0.0
    
    /// Timestamp of last input torque update, used to automatically decay torque if touch events pause.
    private var lastInputTorqueTimestamp: TimeInterval = 0.0
    
    /// Timestamp of the most recent stroke or flick in continuous spin mode.
    private(set) var lastContinuousStrokeTimestamp: TimeInterval = 0.0
    
    /// Duration of the grace period between strokes in continuous mode (seconds).
    /// During this window (~0.5s), friction drag is significantly damped so the user can chain successive flicks
    /// without losing accumulated RPM before the next stroke lands.
    static let continuousInterStrokeGracePeriod: TimeInterval = 0.50
    
    // MARK: - Initialization
    
    init(configuration: SpinnerConfiguration = .standard, spinMode: SpinMode = .natural) {
        self.configuration = configuration
        self.spinMode = spinMode
        let inertia = InertiaCalculator.calculate(for: configuration)
        self.state = SpinnerPhysicsState(momentOfInertia: inertia)
        self.frictionModel = FrictionModelFactory.make(for: configuration)
        self.solver = AngularMotionSolver()
    }
    
    // MARK: - Spin Mode
    
    /// Switches the interaction spin mode while strictly preserving current angle and angular velocity.
    func setSpinMode(_ mode: SpinMode) {
        self.spinMode = mode
        if mode == .continuous {
            let cap = SpinMode.continuousMaxAngularVelocity
            state.angularVelocity = VectorMath.clamp(state.angularVelocity, min: -cap, max: cap)
        } else {
            lastContinuousStrokeTimestamp = 0.0
        }
    }
    
    // MARK: - Physics Actions
    
    /// Records a continuous stroke event timestamp to sustain the inter-stroke grace period.
    func recordContinuousStroke(timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.lastContinuousStrokeTimestamp = timestamp
    }
    
    /// Applies an instantaneous angular impulse (ΔL) in N·m·s.
    /// This causes an immediate step change in angular velocity: Δω = ΔL / I
    func applyAngularImpulse(_ impulse: Float, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        let I = state.momentOfInertia
        guard I > 1e-7 else { return }
        
        let deltaOmega = impulse / I
        let newOmega = state.angularVelocity + deltaOmega
        
        let maxOmega: Float
        if spinMode == .continuous {
            maxOmega = SpinMode.continuousMaxAngularVelocity
            self.lastContinuousStrokeTimestamp = timestamp
        } else {
            maxOmega = configuration.maxAngularVelocity
        }
        
        let clampedOmega = VectorMath.clamp(
            newOmega,
            min: -maxOmega,
            max: maxOmega
        )
        
        state.angularVelocity = clampedOmega
        
        if abs(clampedOmega) > abs(state.peakAngularVelocity) {
            state.peakAngularVelocity = clampedOmega
        }
    }
    
    /// Applies continuous external torque (N·m) during the next simulation update.
    func applyTorque(_ torque: Float) {
        pendingTorque += torque
    }
    
    /// Sets the continuous input torque actively exerted by user's finger (N·m).
    func setInputTorque(_ torque: Float, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.activeInputTorque = torque
        self.lastInputTorqueTimestamp = timestamp
        if spinMode == .continuous && abs(torque) > 1e-5 {
            self.lastContinuousStrokeTimestamp = timestamp
        }
    }
    
    /// Immediately clears any active input torque (e.g. when finger lifts or rests).
    func clearInputTorque() {
        self.activeInputTorque = 0.0
        self.lastInputTorqueTimestamp = 0.0
    }
    
    /// Advances physics simulation by `deltaTime`.
    func update(deltaTime: TimeInterval, currentTime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        // If finger has been stationary or no move events received for > 60ms, clear active input torque
        if lastInputTorqueTimestamp > 0.0 && (currentTime - lastInputTorqueTimestamp > 0.060) {
            activeInputTorque = 0.0
        }
        
        let torque = activeInputTorque + pendingTorque
        pendingTorque = 0.0
        
        let isInGracePeriod: Bool
        if spinMode == .continuous && lastContinuousStrokeTimestamp > 0.0 {
            let elapsed = currentTime - lastContinuousStrokeTimestamp
            isInGracePeriod = elapsed <= Self.continuousInterStrokeGracePeriod
        } else {
            isInGracePeriod = false
        }
        
        solver.step(
            state: &state,
            appliedTorque: torque,
            frictionModel: frictionModel,
            config: configuration,
            spinMode: spinMode,
            isInContinuousGracePeriod: isInGracePeriod,
            deltaTime: deltaTime
        )
    }
    
    /// Manually sets angular velocity (useful for testing or direct manual intervention).
    func setAngularVelocity(_ omega: Float) {
        state.angularVelocity = VectorMath.clamp(
            omega,
            min: -configuration.maxAngularVelocity,
            max: configuration.maxAngularVelocity
        )
        if abs(state.angularVelocity) > abs(state.peakAngularVelocity) {
            state.peakAngularVelocity = state.angularVelocity
        }
    }
    
    /// Immediately brings the spinner to rest.
    func stopImmediately() {
        state.angularVelocity = 0.0
        state.angularAcceleration = 0.0
        pendingTorque = 0.0
        clearInputTorque()
        lastContinuousStrokeTimestamp = 0.0
        solver.reset()
    }
    
    /// Completely resets rotation angle, velocity, and accumulators.
    func reset() {
        let inertia = InertiaCalculator.calculate(for: configuration)
        state = SpinnerPhysicsState(momentOfInertia: inertia)
        pendingTorque = 0.0
        clearInputTorque()
        lastContinuousStrokeTimestamp = 0.0
        solver.reset()
    }
    
    /// Updates configuration parameters dynamically (e.g. changing bearing or mass).
    func updateConfiguration(_ newConfig: SpinnerConfiguration) {
        self.configuration = newConfig
        let newInertia = InertiaCalculator.calculate(for: newConfig)
        state.momentOfInertia = newInertia
        self.frictionModel = FrictionModelFactory.make(for: newConfig)
    }
    
    // MARK: - State Snapshot
    
    /// Generates a lightweight snapshot for UI presentation.
    func makeStateSnapshot(isPlaced: Bool, mode: SpinnerMode) -> SpinnerState {
        return SpinnerState(
            isPlaced: isPlaced,
            mode: mode,
            spinMode: spinMode,
            angle: state.angle,
            angularVelocity: state.angularVelocity,
            angularAcceleration: state.angularAcceleration,
            totalRevolutions: state.totalRevolutions,
            maxRpmAchieved: abs(VectorMath.radPerSecToRPM(state.peakAngularVelocity))
        )
    }
}

