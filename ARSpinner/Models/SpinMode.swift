import Foundation

/// Rotational interaction modes for the fidget spinner.
enum SpinMode: String, CaseIterable, Identifiable, Sendable {
    /// Natural physical simulation: each swipe applies a single flick impulse;
    /// motion decays naturally according to bearing friction and air resistance.
    case natural
    
    /// Continuous acceleration mode: successive swipes additively stack rotational velocity,
    /// allowing the user to pump the spinner up to a hard ceiling of 2,000 RPM.
    case continuous
    
    var id: String { rawValue }
    
    /// Hard maximum RPM ceiling for continuous spin mode (3,000 RPM).
    static let continuousMaxRPM: Float = 3000.0
    
    /// Hard maximum angular velocity in rad/s (3000 * 2π / 60 ≈ 314.15926 rad/s).
    static let continuousMaxAngularVelocity: Float = continuousMaxRPM * (Float.pi * 2.0 / 60.0)
}

