import Foundation

/// Friction model types for physics simulation.
enum FrictionType: String, CaseIterable, Identifiable, Sendable {
    case combined
    case viscous
    case coulomb
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .combined: return "Realistic (Combined)"
        case .viscous: return "Fluid/Air Drag (Viscous)"
        case .coulomb: return "Dry Friction (Coulomb)"
        }
    }
}

/// Physical parameters and constraints of the fidget spinner.
struct SpinnerConfiguration: Sendable, Equatable {
    
    // MARK: - Constants
    
    static let defaultDiameter: Float = 0.076      // 7.6 cm
    static let minDiameter: Float = 0.040          // 4.0 cm
    static let maxDiameter: Float = 0.150          // 15.0 cm
    static let diameterStep: Float = 0.001         // 0.1 cm
    
    // Placement Distance Constants (meters)
    static let defaultPlacementDistance: Float = 0.45 // 45 cm standard viewing distance
    
    // MARK: - Geometry & Dimensions (meters)
    
    /// Total outer physical diameter (default 0.076 m = 7.6 cm).
    var diameter: Float
    
    /// Total outer radius from center to tip of the wings (~3.8 cm).
    var outerRadius: Float {
        get { diameter * 0.5 }
        set { diameter = newValue * 2.0 }
    }
    
    /// Radius of the central bearing hub (~1.2 cm).
    var centerBearingRadius: Float
    
    /// Radius of each outer weighted lobe (~1.1 cm).
    var lobeRadius: Float
    
    /// Distance from center to the center of each outer lobe (~2.6 cm).
    var lobeOffsetDistance: Float
    
    /// Total thickness along local Y axis (~1.1 cm).
    var thickness: Float
    
    /// Number of symmetric lobes/wings (default 3).
    var wingCount: Int
    
    // MARK: - Mass & Inertia
    
    /// Total mass of the spinner in kilograms (default 65 grams = 0.065 kg).
    var totalMass: Float
    
    /// Moment of inertia around local rotation axis (Y-axis) in kg·m².
    /// If 0 or negative, will be automatically computed based on geometry and mass.
    var customMomentOfInertia: Float?
    
    // MARK: - Friction Parameters
    
    /// Friction model type.
    var frictionType: FrictionType
    
    /// Viscous damping coefficient (proportional to angular velocity, air resistance + oil lubricant).
    var viscousFrictionCoefficient: Float
    
    /// Coulomb dry friction coefficient (constant opposing bearing drag).
    var coulombFrictionCoefficient: Float
    
    /// Angular velocity threshold (in rad/s) below which motion cleanly ceases (~0.08 rad/s ~ 0.76 RPM).
    var stopThreshold: Float
    
    // MARK: - Limits & Interactions
    
    /// Maximum allowed angular velocity in radians/sec (~160 rad/s = ~1528 RPM).
    var maxAngularVelocity: Float
    
    /// Effective finger mass (kg) for impulse transfer during swipes (~0.035 kg).
    var effectiveTouchMass: Float
    
    // MARK: - Initializer
    
    init(
        diameter: Float = SpinnerConfiguration.defaultDiameter,
        outerRadius: Float? = nil,
        centerBearingRadius: Float = 0.012,
        lobeRadius: Float = 0.011,
        lobeOffsetDistance: Float = 0.026,
        thickness: Float = 0.011,
        wingCount: Int = 3,
        totalMass: Float = 0.068,
        customMomentOfInertia: Float? = nil,
        frictionType: FrictionType = .combined,
        viscousFrictionCoefficient: Float = 0.0000045,
        coulombFrictionCoefficient: Float = 0.0000032,
        stopThreshold: Float = 0.08,
        maxAngularVelocity: Float = 160.0,
        effectiveTouchMass: Float = 0.035
    ) {
        if let explicitRadius = outerRadius {
            self.diameter = explicitRadius * 2.0
        } else {
            self.diameter = diameter
        }
        self.centerBearingRadius = centerBearingRadius
        self.lobeRadius = lobeRadius
        self.lobeOffsetDistance = lobeOffsetDistance
        self.thickness = thickness
        self.wingCount = wingCount
        self.totalMass = totalMass
        self.customMomentOfInertia = customMomentOfInertia
        self.frictionType = frictionType
        self.viscousFrictionCoefficient = viscousFrictionCoefficient
        self.coulombFrictionCoefficient = coulombFrictionCoefficient
        self.stopThreshold = stopThreshold
        self.maxAngularVelocity = maxAngularVelocity
        self.effectiveTouchMass = effectiveTouchMass
    }
    
    // MARK: - Presets
    
    /// Standard high-precision fidget spinner with ceramic hybrid bearing.
    static let standard = SpinnerConfiguration()
    
    /// High-end ceramic bearing with very low friction (long spin time).
    static let ceramicHighSpeed = SpinnerConfiguration(
        diameter: defaultDiameter,
        centerBearingRadius: 0.012,
        lobeRadius: 0.011,
        lobeOffsetDistance: 0.026,
        thickness: 0.011,
        wingCount: 3,
        totalMass: 0.075,
        customMomentOfInertia: nil,
        frictionType: .combined,
        viscousFrictionCoefficient: 0.0000025,
        coulombFrictionCoefficient: 0.0000015,
        stopThreshold: 0.05,
        maxAngularVelocity: 200.0,
        effectiveTouchMass: 0.035
    )
    
    /// Heavy brass spinner with higher inertia.
    static let heavyBrass = SpinnerConfiguration(
        diameter: 0.080,
        centerBearingRadius: 0.013,
        lobeRadius: 0.012,
        lobeOffsetDistance: 0.027,
        thickness: 0.013,
        wingCount: 3,
        totalMass: 0.115,
        customMomentOfInertia: nil,
        frictionType: .combined,
        viscousFrictionCoefficient: 0.0000060,
        coulombFrictionCoefficient: 0.0000040,
        stopThreshold: 0.06,
        maxAngularVelocity: 140.0,
        effectiveTouchMass: 0.045
    )
}
