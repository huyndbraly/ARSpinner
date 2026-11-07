import SwiftUI

/// Bottom toolbar providing primary placement, reset, settings, live dimension display, and interactive sizing controls in AR.
struct ARControlPanel: View {
    let isPlaced: Bool
    let canPlace: Bool
    let mode: SpinnerMode
    let diameter: Float
    let isSizePanelOpen: Bool
    let isFlashlightOn: Bool
    let onPlace: () -> Void
    let onReset: () -> Void
    let onToggleFlashlight: () -> Void
    let onToggleSizePanel: () -> Void
    let onOpenModelSelection: () -> Void
    
    @ObservedObject private var localization = LocalizationService.shared
    
    private var formattedDimension: String {
        return String(format: "%.1f cm", diameter * 100.0)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Flashlight (Torch) Toggle Button (enables play in low-light environments)
            Button(action: onToggleFlashlight) {
                Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFlashlightOn ? .yellow : .white)
                    .frame(width: 44, height: 44)
                    .background(
                        isFlashlightOn
                            ? Color.yellow.opacity(0.28)
                            : Color.white.opacity(0.12)
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(
                            isFlashlightOn ? Color.yellow.opacity(0.7) : Color.white.opacity(0.2),
                            lineWidth: isFlashlightOn ? 1.5 : 1
                        )
                    )
                    .shadow(color: isFlashlightOn ? Color.yellow.opacity(0.4) : Color.clear, radius: 8)
            }
            
            // Interactive Size Pill Button (Shows current dimension live)
            Button(action: onToggleSizePanel) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSizePanelOpen ? .black : .cyan)
                    
                    Text(formattedDimension)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(isSizePanelOpen ? .black : .white)
                }
                .padding(.horizontal, 10)
                .frame(height: 44)
                .background(
                    isSizePanelOpen
                        ? Color.cyan
                        : Color.white.opacity(0.15)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        Color.white.opacity(0.25),
                        lineWidth: 1
                    )
                )
            }
            
            // Model Selection Gallery Button
            Button(action: onOpenModelSelection) {
                Image(systemName: "fanblades.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            
            // Primary Action: Place or Reset
            if !isPlaced {
                Button(action: onPlace) {
                    HStack(spacing: 6) {
                        Image(systemName: mode == .surface ? "plus.viewfinder" : "cube.transparent")
                            .font(.system(size: 15, weight: .bold))
                        Text(mode == .surface ? localization.tr(.placeOnSurface) : localization.tr(.placeInAir))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundColor(canPlace ? .black : .white.opacity(0.4))
                    .frame(height: 46)
                    .frame(maxWidth: .infinity)
                    .background(canPlace ? Color.white : Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .shadow(color: canPlace ? .white.opacity(0.3) : .clear, radius: 10, x: 0, y: 0)
                }
                .disabled(!canPlace)
            } else {
                Button(action: onReset) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold))
                        Text(localization.tr(.resetPosition))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    .frame(height: 46)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}
