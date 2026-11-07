import SwiftUI

/// Overlay displaying contextual guidance during scanning and initial interaction.
struct PlacementIndicatorView: View {
    let mode: SpinnerMode
    let isPlaced: Bool
    let canPlace: Bool
    let trackingStatus: TrackingStatus
    let isSpinning: Bool
    
    @State private var hasInteractedOnce: Bool = false
    @ObservedObject private var localization = LocalizationService.shared
    
    var body: some View {
        VStack {
            if !isPlaced {
                // Pre-placement Coaching Prompt
                HStack(spacing: 8) {
                    Image(systemName: iconForState)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(canPlace ? .green : .secondary)
                    
                    Text(messageForState)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if !hasInteractedOnce && !isSpinning {
                // Post-placement interaction hint
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                    Text(localization.tr(.swipeWingsHint))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                .transition(.opacity)
            }
        }
        .onChange(of: isSpinning) { _, newValue in
            if newValue {
                hasInteractedOnce = true
            }
        }
    }
    
    private var iconForState: String {
        if canPlace {
            return "checkmark.circle.fill"
        }
        switch trackingStatus {
        case .initializing: return "arrow.triangle.2.circlepath"
        case .normal: return mode == .surface ? "viewfinder" : "cube.transparent"
        case .limited: return "exclamationmark.triangle"
        case .notAvailable, .interrupted: return "xmark.circle"
        }
    }
    
    private var messageForState: String {
        if canPlace {
            return mode == .surface ? localization.tr(.surfaceDetectedReady) : localization.tr(.readyPlaceMidAir)
        }
        switch trackingStatus {
        case .initializing:
            return localization.tr(.scanningEnvironment)
        case .limited(let reason):
            if reason.lowercased().contains("motion") {
                return localization.tr(.excessiveMotion)
            } else if reason.lowercased().contains("features") {
                return localization.tr(.insufficientFeatures)
            }
            return reason
        case .notAvailable:
            return localization.tr(.trackingUnavailable)
        case .interrupted:
            return localization.tr(.trackingInterrupted)
        case .normal:
            return mode == .surface ? localization.tr(.pointAtSurface) : localization.tr(.readyPlaceMidAir)
        }
    }
}
