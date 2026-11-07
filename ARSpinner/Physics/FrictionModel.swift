import Foundation

/// Protocol defining a friction model that opposes rotational motion.
protocol FrictionModeling: Sendable {
    /// Computes the opposing frictional torque (in N·m) for the given angular velocity.
    /// Note: Opposing torque must have the opposite sign of `angularVelocity`.
    func computeFrictionTorque(angularVelocity: Float, momentOfInertia: Float) -> Float
}

/// Viscous friction model where drag is proportional to angular velocity:
/// τ = -c_v * ω
/// Represents fluid shear, aerodynamic drag, and high-speed bearing oil film resistance.
struct ViscousFrictionModel: FrictionModeling {
    let coefficient: Float
    
    init(coefficient: Float) {
        self.coefficient = max(0, coefficient)
    }
    
    func computeFrictionTorque(angularVelocity: Float, momentOfInertia: Float) -> Float {
        guard abs(angularVelocity) > 1e-7 else { return 0 }
        return -coefficient * angularVelocity
    }
}

/// Coulomb friction model where resistance is a constant dry friction opposing motion:
/// τ = -μ_c * sgn(ω)
/// Represents solid contact drag in ball bearings.
struct CoulombFrictionModel: FrictionModeling {
    let coefficient: Float
    
    init(coefficient: Float) {
        self.coefficient = max(0, coefficient)
    }
    
    func computeFrictionTorque(angularVelocity: Float, momentOfInertia: Float) -> Float {
        guard abs(angularVelocity) > 1e-7 else { return 0 }
        let sign: Float = angularVelocity > 0 ? 1.0 : -1.0
        return -coefficient * sign
    }
}

/// Combined friction model pairing viscous damping with dry Coulomb friction:
/// τ = -(c_v * ω + μ_c * sgn(ω))
/// Produces realistic natural spin down: smooth high-speed decay followed by a definitive resting stop.
struct CombinedFrictionModel: FrictionModeling {
    let viscousCoefficient: Float
    let coulombCoefficient: Float
    
    init(viscousCoefficient: Float, coulombCoefficient: Float) {
        self.viscousCoefficient = max(0, viscousCoefficient)
        self.coulombCoefficient = max(0, coulombCoefficient)
    }
    
    func computeFrictionTorque(angularVelocity: Float, momentOfInertia: Float) -> Float {
        guard abs(angularVelocity) > 1e-7 else { return 0 }
        let sign: Float = angularVelocity > 0 ? 1.0 : -1.0
        let viscousTorque = -viscousCoefficient * angularVelocity
        let coulombTorque = -coulombCoefficient * sign
        return viscousTorque + coulombTorque
    }
}

/// Factory for creating friction models from `SpinnerConfiguration`.
enum FrictionModelFactory {
    static func make(for config: SpinnerConfiguration) -> any FrictionModeling {
        switch config.frictionType {
        case .viscous:
            return ViscousFrictionModel(coefficient: config.viscousFrictionCoefficient)
        case .coulomb:
            return CoulombFrictionModel(coefficient: config.coulombFrictionCoefficient)
        case .combined:
            return CombinedFrictionModel(
                viscousCoefficient: config.viscousFrictionCoefficient,
                coulombCoefficient: config.coulombFrictionCoefficient
            )
        }
    }
}

