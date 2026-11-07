import SwiftUI

/// Settings sheet allowing users to tune physical parameters and friction models in real time,
/// equipped with interactive (i) natural-language educational cards for each parameter.
struct PhysicsConfigSheet: View {
    @Binding var configuration: SpinnerConfiguration
    var isMuted: Binding<Bool>? = nil
    var audioVolume: Binding<Float>? = nil
    let onSave: (SpinnerConfiguration) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject private var localization = LocalizationService.shared
    
    @State private var selectedPreset: Int = 0
    @State private var frictionType: FrictionType = .combined
    @State private var massGrams: Double = 68.0
    @State private var viscousFactor: Double = 4.5
    @State private var coulombFactor: Double = 3.2
    @State private var internalVolume: Double = 0.8
    @State private var internalMuted: Bool = false
    
    @State private var presentedInfo: PhysicsParameterInfo? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Presets
                Section {
                    Picker(localization.tr(.presets), selection: $selectedPreset) {
                        Text(localization.tr(.presetStandard)).tag(0)
                        Text(localization.tr(.presetHighSpeed)).tag(1)
                        Text(localization.tr(.presetHeavyBrass)).tag(2)
                    }
                    .pickerStyle(.inline)
                    .onChange(of: selectedPreset) { _, newIndex in
                        applyPreset(index: newIndex)
                    }
                } header: {
                    HStack {
                        Text(localization.tr(.presets))
                        Spacer()
                        infoButton(for: .presets, currentValue: currentPresetName)
                    }
                }
                
                // Section 2: Friction Simulation Model
                Section {
                    HStack {
                        Text(localization.tr(.frictionType))
                        Spacer()
                        Picker("", selection: $frictionType) {
                            ForEach(FrictionType.allCases) { type in
                                Text(localizedFrictionName(type)).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        infoButton(for: .frictionType, currentValue: localizedFrictionName(frictionType))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(localization.tr(.viscousDamping))
                            Spacer()
                            Text(String(format: "%.1f × 10⁻⁶", viscousFactor))
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                            infoButton(for: .viscousDamping, currentValue: String(format: "%.1f × 10⁻⁶ N·m·s/rad", viscousFactor))
                        }
                        Slider(value: $viscousFactor, in: 0.5...15.0, step: 0.1)
                            .tint(.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(localization.tr(.coulombFriction))
                            Spacer()
                            Text(String(format: "%.1f × 10⁻⁶", coulombFactor))
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                            infoButton(for: .coulombFriction, currentValue: String(format: "%.1f × 10⁻⁶ N·m", coulombFactor))
                        }
                        Slider(value: $coulombFactor, in: 0.5...15.0, step: 0.1)
                            .tint(.cyan)
                    }
                } header: {
                    Text(localization.tr(.frictionModel))
                }
                
                // Section 3: Mass & Inertia
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(localization.tr(.totalMass))
                            Spacer()
                            Text("\(Int(massGrams)) g")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                            infoButton(for: .totalMass, currentValue: "\(Int(massGrams)) g")
                        }
                        Slider(value: $massGrams, in: 30.0...180.0, step: 1.0)
                            .tint(.cyan)
                    }
                    
                    let inertia = InertiaCalculator.calculate(for: currentConfig)
                    HStack {
                        Text(localization.tr(.momentOfInertia))
                        Spacer()
                        Text(String(format: "%.2e kg·m²", inertia))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                        infoButton(for: .momentOfInertia, currentValue: String(format: "%.2e kg·m²", inertia))
                    }
                    
                    HStack {
                        Text(localization.tr(.maxSafeSpeed))
                        Spacer()
                        Text("\(Int(currentConfig.maxAngularVelocity)) rad/s (\(Int(VectorMath.radPerSecToRPM(currentConfig.maxAngularVelocity))) RPM)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        infoButton(for: .maxSafeSpeed, currentValue: "\(Int(VectorMath.radPerSecToRPM(currentConfig.maxAngularVelocity))) RPM")
                    }
                } header: {
                    Text(localization.tr(.massAndDimensions))
                }
                
                // Section 4: Bearing Acoustics & Audio
                Section {
                    Toggle(isOn: Binding(
                        get: { isMuted?.wrappedValue ?? internalMuted },
                        set: { val in
                            isMuted?.wrappedValue = val
                            internalMuted = val
                        }
                    )) {
                        HStack {
                            Text(localization.tr(.soundEffects))
                            infoButton(for: .audioEffects, currentValue: (isMuted?.wrappedValue ?? internalMuted) ? (localization.currentLanguage == .vi ? "Tắt" : "Muted") : (localization.currentLanguage == .vi ? "Bật" : "Active"))
                        }
                    }
                    
                    if !(isMuted?.wrappedValue ?? internalMuted) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(localization.tr(.soundVolume))
                                Spacer()
                                Text("\(Int((audioVolume?.wrappedValue ?? Float(internalVolume)) * 100))%")
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(audioVolume?.wrappedValue ?? Float(internalVolume)) },
                                set: { val in
                                    audioVolume?.wrappedValue = Float(val)
                                    internalVolume = val
                                }
                            ), in: 0.0...1.0, step: 0.05)
                            .tint(.cyan)
                        }
                    }
                } header: {
                    Text(localization.tr(.audioSectionHeader))
                }
            }
            .navigationTitle(localization.tr(.physicsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.tr(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.tr(.apply)) {
                        let finalConfig = currentConfig
                        configuration = finalConfig
                        onSave(finalConfig)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.cyan)
                }
            }
            .onAppear {
                loadFromConfig()
            }
            .sheet(item: $presentedInfo) { info in
                PhysicsParameterInfoSheet(info: info)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func infoButton(for key: PhysicsParameterKey, currentValue: String) -> some View {
        Button {
            presentedInfo = PhysicsParameterInfo.info(
                for: key,
                language: localization.currentLanguage,
                currentValueString: currentValue
            )
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.cyan)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Info about \(key.rawValue)")
    }
    
    private var currentPresetName: String {
        switch selectedPreset {
        case 1: return localization.tr(.presetHighSpeed)
        case 2: return localization.tr(.presetHeavyBrass)
        default: return localization.tr(.presetStandard)
        }
    }
    
    private func localizedFrictionName(_ type: FrictionType) -> String {
        switch type {
        case .combined: return localization.tr(.frictionCombined)
        case .coulomb: return localization.tr(.frictionCoulomb)
        case .viscous: return localization.tr(.frictionViscous)
        }
    }
    
    private var currentConfig: SpinnerConfiguration {
        var cfg = configuration
        cfg.frictionType = frictionType
        cfg.totalMass = Float(massGrams) / 1000.0
        cfg.viscousFrictionCoefficient = Float(viscousFactor) * 1e-6
        cfg.coulombFrictionCoefficient = Float(coulombFactor) * 1e-6
        return cfg
    }
    
    private func loadFromConfig() {
        frictionType = configuration.frictionType
        massGrams = Double(configuration.totalMass * 1000.0)
        viscousFactor = Double(configuration.viscousFrictionCoefficient * 1e6)
        coulombFactor = Double(configuration.coulombFrictionCoefficient * 1e6)
        internalVolume = Double(audioVolume?.wrappedValue ?? 0.8)
        internalMuted = isMuted?.wrappedValue ?? true
    }
    
    private func applyPreset(index: Int) {
        let preset: SpinnerConfiguration
        switch index {
        case 1: preset = .ceramicHighSpeed
        case 2: preset = .heavyBrass
        default: preset = .standard
        }
        frictionType = preset.frictionType
        massGrams = Double(preset.totalMass * 1000.0)
        viscousFactor = Double(preset.viscousFrictionCoefficient * 1e6)
        coulombFactor = Double(preset.coulombFrictionCoefficient * 1e6)
    }
}
