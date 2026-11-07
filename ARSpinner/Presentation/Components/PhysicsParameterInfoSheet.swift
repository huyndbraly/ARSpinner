import SwiftUI

/// Accessible modal bottom sheet presenting comprehensive physical parameter explanations in natural language.
struct PhysicsParameterInfoSheet: View {
    let info: PhysicsParameterInfo
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localization = LocalizationService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Card with Current Value Badge
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(info.title)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 6) {
                                Text(localization.currentLanguage == .vi ? "Giá trị hiện tại:" : "Current Value:")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                Text(info.currentValue)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.cyan)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.cyan.opacity(0.85))
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                    )
                    
                    // 1. What is this?
                    InfoSectionCard(
                        icon: "questionmark.circle",
                        iconColor: .cyan,
                        headline: localization.currentLanguage == .vi ? "1. Đây là gì?" : "1. What is this?",
                        bodyText: info.whatIsIt
                    )
                    
                    // 2. How it affects spinner
                    InfoSectionCard(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .teal,
                        headline: localization.currentLanguage == .vi ? "2. Ảnh hưởng đến con quay" : "2. How it affects the spinner",
                        bodyText: info.howItAffects
                    )
                    
                    // 3. When increased
                    InfoSectionCard(
                        icon: "arrow.up.circle",
                        iconColor: .orange,
                        headline: localization.currentLanguage == .vi ? "3. Khi tăng giá trị" : "3. What happens when increased?",
                        bodyText: info.whenIncreased
                    )
                    
                    // 4. When decreased
                    InfoSectionCard(
                        icon: "arrow.down.circle",
                        iconColor: .blue,
                        headline: localization.currentLanguage == .vi ? "4. Khi giảm giá trị" : "4. What happens when decreased?",
                        bodyText: info.whenDecreased
                    )
                    
                    // 5. Current value meaning
                    InfoSectionCard(
                        icon: "checkmark.seal",
                        iconColor: .green,
                        headline: localization.currentLanguage == .vi ? "5. Ý nghĩa giá trị hiện tại" : "5. Meaning of current value",
                        bodyText: info.currentValueMeaning
                    )
                }
                .padding(20)
            }
            .background(Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.currentLanguage == .vi ? "Đóng" : "Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.cyan)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

/// Individual explanation section card with unified Apple HIG styling.
private struct InfoSectionCard: View {
    let icon: String
    let iconColor: Color
    let headline: String
    let bodyText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(headline)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Text(bodyText)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

