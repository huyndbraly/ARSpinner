import Foundation

/// Calculates the moment of inertia (I) for symmetrical fidget spinners around their central axis.
enum InertiaCalculator {
    
    /// Computes the mass moment of inertia (kg·m²) around the rotation axis (local Y).
    /// Uses physical decomposition into central hub, connecting arms, and weighted outer lobes.
    static func calculate(for config: SpinnerConfiguration) -> Float {
        if let customI = config.customMomentOfInertia, customI > 0 {
            return customI
        }
        
        let totalMass = config.totalMass
        let n = Float(config.wingCount)
        
        // Typical mass distribution:
        // Central hub: ~25%
        // Outer counterweight lobes: ~60% (distributed across n lobes)
        // Connecting arms/structure: ~15% (distributed across n arms)
        let hubMass = totalMass * 0.25
        let lobeMassTotal = totalMass * 0.60
        let armMassTotal = totalMass * 0.15
        
        let massPerLobe = lobeMassTotal / n
        let massPerArm = armMassTotal / n
        
        // 1. Central Hub (solid cylinder rotating around central axis)
        // I_hub = 1/2 * m * r^2
        let hubInertia = 0.5 * hubMass * pow(config.centerBearingRadius, 2)
        
        // 2. Outer Lobes (cylindrical weights at distance d from center)
        // By Parallel Axis Theorem: I_lobe = (1/2 * m_lobe * r_lobe^2) + (m_lobe * d^2)
        let lobeSelfInertia = 0.5 * massPerLobe * pow(config.lobeRadius, 2)
        let lobeOffsetInertia = massPerLobe * pow(config.lobeOffsetDistance, 2)
        let singleLobeInertia = lobeSelfInertia + lobeOffsetInertia
        let totalLobesInertia = n * singleLobeInertia
        
        // 3. Connecting Arms (slender rods between hub and lobe)
        // Length = d - r_hub
        let armLength = max(0.005, config.lobeOffsetDistance - config.centerBearingRadius)
        let armCenterDistance = config.centerBearingRadius + (armLength * 0.5)
        // I_rod_center = 1/12 * m * L^2; I_arm = I_rod_center + m * d_mid^2
        let armSelfInertia = (1.0 / 12.0) * massPerArm * pow(armLength, 2)
        let armOffsetInertia = massPerArm * pow(armCenterDistance, 2)
        let totalArmsInertia = n * (armSelfInertia + armOffsetInertia)
        
        let calculatedInertia = hubInertia + totalLobesInertia + totalArmsInertia
        
        // Sanity fallback bound: ensure strictly positive and within realistic physics range
        return max(1e-6, calculatedInertia)
    }
}

