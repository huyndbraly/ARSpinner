import Foundation

/// Internal mutable and immutable physics state tracking angular position, velocity, and inertia.
struct SpinnerPhysicsState: Sendable, Equatable {
    
    /// Current angular position in radians (accumulated).
    var angle: Float
    
    /// Current angular velocity in radians per second (omega).
    var angularVelocity: Float
    
    /// Current angular acceleration in radians per second squared (alpha).
    var angularAcceleration: Float
    
    /// Moment of inertia in kg·m² (I).
    var momentOfInertia: Float
    
    /// Cumulative revolutions completed.
    var totalRevolutions: Double
    
    /// Highest angular velocity attained.
    var peakAngularVelocity: Float
    
    /// External torque currently applied by interaction (N·m).
    var appliedTorque: Float
    
    /// Resistive friction torque currently opposing motion (N·m).
    var frictionTorque: Float
    
    /// Current rotational speed in Revolutions Per Minute (RPM).
    var rpm: Float {
        return VectorMath.radPerSecToRPM(angularVelocity)
    }
    
    /// Highest RPM attained during the simulation session.
    var peakRPM: Float {
        return VectorMath.radPerSecToRPM(peakAngularVelocity)
    }
    
    /// Whether the spinner is currently considered rotating.
    var isSpinning: Bool {
        return abs(angularVelocity) > 0.001
    }
    
    init(
        angle: Float = 0.0,
        angularVelocity: Float = 0.0,
        angularAcceleration: Float = 0.0,
        momentOfInertia: Float = 4.0e-5,
        totalRevolutions: Double = 0.0,
        peakAngularVelocity: Float = 0.0,
        appliedTorque: Float = 0.0,
        frictionTorque: Float = 0.0
    ) {
        self.angle = angle
        self.angularVelocity = angularVelocity
        self.angularAcceleration = angularAcceleration
        self.momentOfInertia = momentOfInertia
        self.totalRevolutions = totalRevolutions
        self.peakAngularVelocity = peakAngularVelocity
        self.appliedTorque = appliedTorque
        self.frictionTorque = frictionTorque
    }
}

