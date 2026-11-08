import SwiftUI

/// Premium landing screen showcasing the ARSpinner experience with an interactive
/// real-time 3D spinner hero, 3D orbit inspection, live tachometer RPM telemetry,
/// and high-performance, battery-friendly rendering with zero idle re-renders.
struct HomeView: View {
    @StateObject private var selectionManager = SpinnerSelectionManager()
    @State private var liveRPM: Double = 45.0
    @State private var isSpinningActive: Bool = false
    @State private var hasInteracted: Bool = false
    @State private var showModelSheet: Bool = false
    @State private var isViewActive: Bool = true
    
    @ObservedObject private var localization = LocalizationService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background: Deep dark slate
                Color(red: 0.06, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()
                
                // Static Ambient Backdrop (replaces full-screen continuous gradient recalculations)
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.cyan.opacity(0.08),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 40,
                    endRadius: 360
                )
                .ignoresSafeArea()
                
                GeometryReader { geometry in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // MARK: - Top Navigation Bar
                            HStack {
                                // Tech Status Badge
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                        .shadow(color: .green.opacity(0.6), radius: 3)
                                    Text("SPATIAL 3D")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.75))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4.5)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                                
                                Spacer()
                                
                                // Language Toggle Pill
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        localization.toggleLanguage()
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "globe")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(localization.currentLanguage.shortCode)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 4)
                            
                            // MARK: - Brand Header
                            VStack(spacing: 4) {
                                Text(localization.tr(.appTitle))
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .tracking(2.5)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, Color(red: 0.82, green: 0.95, blue: 1.0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                
                                Text(localization.tr(.appSubtitle))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.top, 8)
                            
                            Spacer(minLength: 8)
                            
                            // MARK: - Interactive 3D Spinner Hero Stage
                            ZStack {
                                // 1. Dynamic Luminous Glow (isolated subview to avoid re-rendering HomeView)
                                LuminousGlowView(isSpinningActive: isSpinningActive, rpm: liveRPM)
                                
                                // 2. Futuristic Tachometer & Gyro HUD Rings (isolated rotation animation)
                                TachometerHUDRingsView()
                                
                                // 3. Prominent 3D Interactive Spinner (Pan on spinner to spin • Pan on background to orbit 3D)
                                HomeSpinner3DHeroView(
                                    model: selectionManager.selectedModel,
                                    rpm: $liveRPM,
                                    isSpinningActive: $isSpinningActive,
                                    isViewActive: isViewActive,
                                    onUserInteraction: {
                                        if !hasInteracted {
                                            withAnimation(.easeOut(duration: 0.3)) {
                                                hasInteracted = true
                                            }
                                        }
                                    }
                                )
                                .frame(width: 330, height: 275)
                                
                                // 4. Floating Live Telemetry Badges
                                VStack {
                                    // Top RPM Telemetry Pill (Rock-solid, jitter-free, isolated re-rendering)
                                    LiveRPMTelemetryBadgeView(
                                        rpm: liveRPM,
                                        isSpinningActive: isSpinningActive
                                    )
                                    
                                    Spacer()
                                    
                                    // Bottom Dual-Interaction Prompt (fades cleanly after user first interacts)
                                    if !hasInteracted && !isSpinningActive {
                                        HStack(spacing: 5) {
                                            Image(systemName: "hand.draw.fill")
                                                .font(.system(size: 10.5, weight: .semibold))
                                            Text(localization.tr(.swipeToSpinPrompt))
                                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                        }
                                        .foregroundColor(.white.opacity(0.85))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4.5)
                                        .background(Color.black.opacity(0.65))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.8))
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    }
                                }
                                .frame(width: 300, height: 260)
                            }
                            .frame(height: 280)
                            
                            // MARK: - Model Quick Switcher Bar
                            HStack(spacing: 10) {
                                // Previous Model Button
                                Button {
                                    cycleModel(forward: false)
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 38, height: 38)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                                }
                                
                                // Active Model Card (Tap opens 2-column 3D model gallery sheet)
                                Button {
                                    showModelSheet = true
                                } label: {
                                    HStack(spacing: 10) {
                                        RotatingFanIcon()
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 5) {
                                                Text(selectionManager.selectedModel.localizedName(for: localization.currentLanguage))
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.white.opacity(0.45))
                                            }
                                            
                                            Text("\(selectionManager.selectedModel.wingCount) \(localization.currentLanguage == .vi ? "cánh" : "wings") • \(Int((selectionManager.selectedModel.estimatedMass * 1000).rounded()))g • \(selectionManager.selectedModel.localizedMaterial(for: localization.currentLanguage))")
                                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.6))
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                                }
                                
                                // Next Model Button
                                Button {
                                    cycleModel(forward: true)
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 38, height: 38)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                            
                            Spacer(minLength: 12)
                            
                            // MARK: - Feature Highlights
                            VStack(spacing: 9) {
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
                            .padding(.horizontal, 24)
                            
                            Spacer(minLength: 14)
                            
                            // MARK: - Start AR Button (PINNED AT BOTTOM)
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
                                .background(
                                    LinearGradient(
                                        colors: [.white, Color(white: 0.92)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: .white.opacity(0.24), radius: 14, x: 0, y: 4)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                        }
                        .frame(minHeight: geometry.size.height)
                    }
                }
            }
            .sheet(isPresented: $showModelSheet) {
                SpinnerSelectionSheet(
                    selectionManager: selectionManager,
                    onSelectModel: { chosen in
                        selectionManager.setSelectedModelDirectly(chosen)
                        showModelSheet = false
                    }
                )
            }
            .onAppear {
                isViewActive = true
            }
            .onDisappear {
                // Completely pause SceneKit and CADisplayLink when navigating away to AR
                isViewActive = false
            }
        }
    }
    
    // MARK: - Model Switching
    
    private func cycleModel(forward: Bool) {
        let models = selectionManager.catalog.availableModels
        guard !models.isEmpty else { return }
        let currentIndex = models.firstIndex(where: { $0.id == selectionManager.selectedModel.id }) ?? 0
        let nextIndex: Int
        if forward {
            nextIndex = (currentIndex + 1) % models.count
        } else {
            nextIndex = (currentIndex - 1 + models.count) % models.count
        }
        let nextModel = models[nextIndex]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) {
            selectionManager.setSelectedModelDirectly(nextModel)
        }
    }
}

// MARK: - Isolated Tachometer HUD View (Eliminates Root View Re-renders)

private struct TachometerHUDRingsView: View {
    @State private var rotation: Double = 0.0
    
    var body: some View {
        ZStack {
            // Outer dashed cardinal tick ring
            Circle()
                .stroke(
                    Color.cyan.opacity(0.22),
                    style: StrokeStyle(lineWidth: 1.2, dash: [3, 14])
                )
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(rotation))
            
            // Secondary fine inner gauge ring
            Circle()
                .stroke(
                    Color.white.opacity(0.08),
                    style: StrokeStyle(lineWidth: 0.8, dash: [4, 7])
                )
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(-rotation * 0.5))
            
            // Cardinal accent dots (0°, 90°, 180°, 270°)
            ForEach([0, 90, 180, 270], id: \.self) { deg in
                Circle()
                    .fill(Color.cyan.opacity(0.75))
                    .frame(width: 3.5, height: 3.5)
                    .offset(y: -130)
                    .rotationEffect(.degrees(Double(deg)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 25.0).repeatForever(autoreverses: false)) {
                rotation = 360.0
            }
        }
    }
}

// MARK: - Isolated Live RPM Telemetry Badge View

private struct LiveRPMTelemetryBadgeView: View {
    let rpm: Double
    let isSpinningActive: Bool
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(badgeColor)
            
            Text(isSpinningActive ? "\(Int(rpm)) RPM" : "IDLE • 45 RPM")
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(badgeColor.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: badgeColor.opacity(0.28), radius: 6)
    }
    
    private var badgeColor: Color {
        if !isSpinningActive || rpm < 250 {
            return Color.cyan
        } else if rpm < 850 {
            return Color(red: 0.25, green: 0.75, blue: 1.0)
        } else if rpm < 1800 {
            return Color(red: 0.55, green: 0.5, blue: 1.0)
        } else if rpm < 2600 {
            return Color(red: 0.95, green: 0.35, blue: 0.9)
        } else {
            return Color(red: 1.0, green: 0.32, blue: 0.25) // Turbo Redline
        }
    }
}

// MARK: - Isolated Luminous Glow View

private struct LuminousGlowView: View {
    let isSpinningActive: Bool
    let rpm: Double
    
    var body: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                glowColor.opacity(glowOpacity),
                Color.cyan.opacity(0.06),
                Color.clear
            ]),
            center: .center,
            startRadius: 20,
            endRadius: 180
        )
        .frame(width: 320, height: 280)
    }
    
    private var glowColor: Color {
        if isSpinningActive && rpm > 1300 {
            return Color.purple
        } else if isSpinningActive && rpm > 600 {
            return Color.blue
        } else {
            return Color.cyan
        }
    }
    
    private var glowOpacity: Double {
        if !isSpinningActive {
            return 0.10
        }
        return min(0.30, 0.10 + (rpm / 2800.0) * 0.20)
    }
}

// MARK: - Isolated Rotating Fan Icon

private struct RotatingFanIcon: View {
    @State private var rotation: Double = 0.0
    
    var body: some View {
        Image(systemName: "fanblades.fill")
            .font(.system(size: 16))
            .foregroundColor(.cyan)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                    rotation = 360.0
                }
            }
    }
}

// MARK: - Feature Highlight Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.cyan)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}
