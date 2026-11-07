import SwiftUI

/// Elegant mode switch allowing selection between Surface (plane detection) and Floating (mid-air) AR modes.
struct ModeSelector: View {
    @Binding var selectedMode: SpinnerMode
    var isLocked: Bool = false
    
    @ObservedObject private var localization = LocalizationService.shared
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(SpinnerMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                        Text(title(for: mode))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(selectedMode == mode ? .black : .white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        selectedMode == mode ?
                            Color.white : Color.clear
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .padding(3)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func title(for mode: SpinnerMode) -> String {
        switch mode {
        case .surface:
            return localization.tr(.modeSurface)
        case .floating:
            return localization.tr(.modeFloating)
        }
    }
}
