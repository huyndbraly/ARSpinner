import Foundation

/// Direction of rotation relative to the spinner's normal (Y) axis.
enum RotationDirection: String, Sendable {
    case idle = "Idle"
    case clockwise = "Clockwise"
    case counterClockwise = "Counter-Clockwise"
    
    var iconName: String {
        switch self {
        case .idle: return "pause.circle"
        case .clockwise: return "arrow.clockwise.circle"
        case .counterClockwise: return "arrow.counterclockwise.circle"
        }
    }
}

/// Snapshot of the spinner's real-time state for UI presentation.
struct SpinnerState: Sendable, Equatable {
    
    /// Whether the spinner has been anchored in the AR scene.
    var isPlaced: Bool = false
    
    /// Current placement mode.
    var mode: SpinnerMode = .surface
    
    /// Current rotational physics interaction mode.
    var spinMode: SpinMode = .natural
    
    /// Current angular orientation (angle in radians around local Y-axis).
    var angle: Float = 0.0
    
    /// Current angular velocity in radians per second.
    var angularVelocity: Float = 0.0
    
    /// Current angular acceleration in radians per second squared.
    var angularAcceleration: Float = 0.0
    
    /// Revolutions per minute (RPM).
    var rpm: Float {
        return abs(VectorMath.radPerSecToRPM(angularVelocity))
    }
    
    /// Direction of rotation.
    var direction: RotationDirection {
        if abs(angularVelocity) < 0.1 {
            return .idle
        } else if angularVelocity > 0 {
            return .counterClockwise
        } else {
            return .clockwise
        }
    }
    
    /// Cumulative revolutions since placement.
    var totalRevolutions: Double = 0.0
    
    /// Peak RPM reached in current session.
    var maxRpmAchieved: Float = 0.0
    
    /// Whether the spinner is currently in motion.
    var isSpinning: Bool {
        return abs(angularVelocity) > 0.1
    }
    
    /// Formatted RPM string for HUD (e.g. "845 RPM").
    var formattedRpm: String {
        return "\(Int(rpm.rounded())) RPM"
    }
    
    /// Formatted revolutions string for HUD.
    var formattedRevolutions: String {
        return String(format: "%.1f revs", totalRevolutions)
    }
}

