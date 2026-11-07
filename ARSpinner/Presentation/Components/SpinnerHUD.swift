import SwiftUI

/// Minimalist HUD displaying real-time rotational telemetry and dual spin mode selection when spinner is placed.
struct SpinnerHUD: View {
    let state: SpinnerState
    let onStop: () -> Void
    var onSpinModeChanged: ((SpinMode) -> Void)? = nil
    
    @ObservedObject private var localization = LocalizationService.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // Spin Mode Selector (Natural vs Continuous Acceleration)
            HStack(spacing: 4) {
                ForEach(SpinMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            onSpinModeChanged?(mode)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode == .natural ? "leaf.fill" : "bolt.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text(spinModeTitle(for: mode))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(state.spinMode == mode ? .black : .white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            state.spinMode == mode ? Color.white : Color.clear
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(3)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            
            // Primary Rotational Gauge Card
            VStack(spacing: 6) {
                HStack(spacing: 16) {
                    // Rotational Speed / RPM Readout
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: state.direction.iconName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(state.isSpinning ? .cyan : .secondary)
                            
                            Text(directionText)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        if state.spinMode == .continuous {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(Int(abs(state.rpm).rounded()))")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.primary)
                                Text(" / \(Int(SpinMode.continuousMaxRPM)) \(localization.tr(.rpm))")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(Int(abs(state.rpm).rounded()))")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.primary)
                                Text(" \(localization.tr(.rpm))")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                        .frame(height: 38)
                        .background(Color.white.opacity(0.2))
                    
                    // Peak RPM & Total Revolutions
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text(localization.tr(.peak))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            Text("\(Int(state.maxRpmAchieved.rounded()))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.primary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                                .foregroundColor(.teal)
                            Text(localization.tr(.revs))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", state.totalRevolutions))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if state.isSpinning {
                        Button(action: onStop) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.red.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Progress Bar and Guidance footer for Continuous Spin
                if state.spinMode == .continuous {
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 4)
                                
                                let ratio = min(1.0, max(0.0, CGFloat(abs(state.rpm) / SpinMode.continuousMaxRPM)))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.cyan, .blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(4, geo.size.width * ratio), height: 4)
                                    .animation(.linear(duration: 0.1), value: ratio)
                            }
                        }
                        .frame(height: 4)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.with.needle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan)
                            Text(localization.tr(.continuousSpinInstruction))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.cyan.opacity(0.9))
                        }
                    }
                    .padding(.top, 2)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
        }
    }
    
    private func spinModeTitle(for mode: SpinMode) -> String {
        switch mode {
        case .natural:
            return localization.tr(.spinModeNatural)
        case .continuous:
            return localization.tr(.spinModeContinuous)
        }
    }
    
    private var directionText: String {
        switch state.direction {
        case .clockwise:
            return localization.tr(.clockwise)
        case .counterClockwise:
            return localization.tr(.counterClockwise)
        case .idle:
            return localization.tr(.idle)
        }
    }
}
