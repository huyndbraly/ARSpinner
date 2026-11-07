import SwiftUI

/// Card view representing an individual 3D spinner model within the selection gallery.
struct SpinnerCardView: View {
    let model: SpinnerModelDescriptor
    let isSelected: Bool
    let isLoading: Bool
    let onSelect: () -> Void
    
    @ObservedObject private var localization = LocalizationService.shared
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // 1. 3D Interactive Turntable Preview Container
                ZStack(alignment: .topTrailing) {
                    Spinner3DPreviewView(
                        fileURL: model.fileURL,
                        assetName: model.assetName
                    )
                    .frame(height: 125)
                    
                    // Selected Checkmark Badge
                    if isSelected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Text(localization.tr(.selected))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                        .shadow(color: .cyan.opacity(0.4), radius: 4)
                        .padding(8)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Loading Overlay
                    if isLoading {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                            
                            VStack(spacing: 6) {
                                ProgressView()
                                    .tint(.cyan)
                                    .scaleEffect(0.9)
                                Text(localization.tr(.loadingModel))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                
                // 2. Metadata & Title
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.localizedName(for: localization.currentLanguage))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 5) {
                        // Mass Badge
                        Text("\(Int((model.estimatedMass * 1000.0).rounded()))g")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        // Material Badge
                        Text(model.localizedMaterial(for: localization.currentLanguage))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.cyan.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(white: 0.12).opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSelected ? Color.cyan : Color.white.opacity(0.12),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? Color.cyan.opacity(0.28) : Color.black.opacity(0.2),
                radius: isSelected ? 10 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(ScaleBounceButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - Scale Button Style

private struct ScaleBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

