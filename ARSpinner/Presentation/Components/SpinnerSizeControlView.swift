import SwiftUI

/// Compact glassmorphic panel providing interactive physical diameter controls (4.0 cm - 15.0 cm)
/// for the tabletop AR fidget spinner.
struct SpinnerSizeControlView: View {
    @Binding var diameter: Float // In meters (e.g. 0.076 = 7.6 cm)
    let onChange: (Float) -> Void
    let onReset: () -> Void
    let onClose: () -> Void
    
    @ObservedObject private var localization = LocalizationService.shared
    
    // Standard Mode bounds (centimeters)
    private let minCm: Float = SpinnerConfiguration.minDiameter * 100.0          // 4.0 cm
    private let maxCm: Float = SpinnerConfiguration.maxDiameter * 100.0          // 15.0 cm
    private let stepCm: Float = SpinnerConfiguration.diameterStep * 100.0        // 0.1 cm
    private let defaultCm: Float = SpinnerConfiguration.defaultDiameter * 100.0  // 7.6 cm
    
    init(
        diameter: Binding<Float>,
        onChange: @escaping (Float) -> Void,
        onReset: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._diameter = diameter
        self.onChange = onChange
        self.onReset = onReset
        self.onClose = onClose
    }
    
    private var diameterCm: Float {
        diameter * 100.0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // MARK: - Header & Live Readout
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cyan)
                    
                    Text(localization.tr(.spinnerSize))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Live Diameter Readout Pill
                HStack(spacing: 2) {
                    Text(String(format: "%.1f", diameterCm))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.cyan)
                    Text(localization.tr(.cmUnit))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
                .background(Color.cyan.opacity(0.18))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                
                // Close Button
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.leading, 4)
            }
            
            // MARK: - Interactive Stepper & Slider
            HStack(spacing: 12) {
                // Stepper Decrement Button [-]
                Button {
                    stepDiameter(by: -stepCm)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(diameterCm <= minCm + 0.01 ? .white.opacity(0.3) : .cyan)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .disabled(diameterCm <= minCm + 0.01)
                
                // Continuous Slider
                Slider(
                    value: Binding<Double>(
                        get: { Double(diameterCm) },
                        set: { updateDiameter(Float($0)) }
                    ),
                    in: Double(minCm)...Double(maxCm),
                    step: Double(stepCm)
                )
                .tint(.cyan)
                
                // Stepper Increment Button [+]
                Button {
                    stepDiameter(by: stepCm)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(diameterCm >= maxCm - 0.01 ? .white.opacity(0.3) : .cyan)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .disabled(diameterCm >= maxCm - 0.01)
            }
            
            // MARK: - Bounds Labels & Quick Default Reset
            HStack {
                Text("\(Int(minCm)) cm")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                
                Spacer()
                
                // One-tap Default Reset Button (7.6 cm)
                Button {
                    updateDiameter(defaultCm)
                    onReset()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9, weight: .bold))
                        Text(localization.tr(.resetSize))
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.3), lineWidth: 0.8))
                }
                
                Spacer()
                
                Text("\(Int(maxCm)) cm")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.07, green: 0.09, blue: 0.14).opacity(0.85))
                .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Actions
    
    private func stepDiameter(by deltaCm: Float) {
        let newCm = max(minCm, min(maxCm, diameterCm + deltaCm))
        updateDiameter(newCm)
    }
    
    private func updateDiameter(_ newCm: Float) {
        let clamped = max(minCm, min(maxCm, newCm))
        let inMeters = clamped / 100.0
        diameter = inMeters
        onChange(inMeters)
    }
}
