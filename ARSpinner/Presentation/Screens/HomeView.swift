import SwiftUI

/// Premium landing screen showcasing the ARSpinner experience.
struct HomeView: View {
    @State private var previewRotation: Double = 0.0
    @State private var isSpinningPreview: Bool = true
    @State private var navigateToAR: Bool = false
    
    @ObservedObject private var localization = LocalizationService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background: Deep dark slate with subtle radial glow
                Color(red: 0.06, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.cyan.opacity(0.12),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 20,
                    endRadius: 280
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Top Bar: Language Toggle Pill
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                localization.toggleLanguage()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(localization.currentLanguage.shortCode)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    // Brand Header
                    VStack(spacing: 6) {
                        Text(localization.tr(.appTitle))
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .tracking(2.5)
                            .foregroundColor(.white)
                        
                        Text(localization.tr(.appSubtitle))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Animated 3D Preview Widget
                    ZStack {
                        // Ambient glow ring
                        Circle()
                            .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                            .frame(width: 220, height: 220)
                        
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            .frame(width: 170, height: 170)
                        
                        // Procedural 3-Wing Spinner Graphic
                        SpinnerPreviewGraphic()
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(previewRotation))
                            .onAppear {
                                withAnimation(
                                    .linear(duration: 3.5)
                                    .repeatForever(autoreverses: false)
                                ) {
                                    previewRotation = 360.0
                                }
                            }
                    }
                    .frame(height: 210)
                    
                    Spacer()
                    
                    // Feature Highlights
                    VStack(spacing: 12) {
                        FeatureRow(
                            icon: "waveform.path.ecg",
                            title: localization.tr(.physicsEngineTitle),
                            subtitle: localization.tr(.physicsEngineSubtitle)
                        )
                        
                        FeatureRow(
                            icon: "table.furniture",
                            title: localization.tr(.surfaceMidAirTitle),
                            subtitle: localization.tr(.surfaceMidAirSubtitle)
                        )
                        
                        FeatureRow(
                            icon: "hand.tap",
                            title: localization.tr(.swipeInteractionTitle),
                            subtitle: localization.tr(.swipeInteractionSubtitle)
                        )
                    }
                    .padding(.horizontal, 28)
                    
                    Spacer(minLength: 12)
                    
                    // Start Button
                    NavigationLink(destination: ARExperienceView()) {
                        HStack(spacing: 10) {
                            Image(systemName: "arkit")
                                .font(.system(size: 18, weight: .semibold))
                            Text(localization.tr(.startAR))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .white.opacity(0.2), radius: 16, x: 0, y: 4)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

/// Minimalist graphic rendering the 3-wing spinner silhouette for the home screen preview.
private struct SpinnerPreviewGraphic: View {
    var body: some View {
        ZStack {
            // 3 Wings
            ForEach(0..<3) { i in
                let angle = Double(i) * 120.0
                WingGraphic()
                    .rotationEffect(.degrees(angle))
            }
            
            // Central Hub
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.28), Color(white: 0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
            
            // Central Bearing
            Circle()
                .fill(Color(white: 0.85))
                .frame(width: 26, height: 26)
            
            Circle()
                .fill(Color(white: 0.2))
                .frame(width: 14, height: 14)
        }
    }
}

/// Single stylized fidget spinner wing with an embedded circular counterweight hole.
private struct WingGraphic: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Outer lobe
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.35), Color(white: 0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                
                // Outer bearing weight insert
                Circle()
                    .fill(Color(white: 0.82))
                    .frame(width: 28, height: 28)
                
                Circle()
                    .fill(Color(red: 0.08, green: 0.09, blue: 0.12))
                    .frame(width: 18, height: 18)
            }
            .offset(y: -46)
        }
    }
}

/// Minimal information row displaying an icon, title, and descriptive subtitle.
private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.cyan)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}
