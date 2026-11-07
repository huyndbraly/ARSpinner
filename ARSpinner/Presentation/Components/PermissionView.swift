import SwiftUI

/// View presented when camera permission has not been granted.
struct PermissionView: View {
    let onRequestAgain: () -> Void
    
    @ObservedObject private var localization = LocalizationService.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
                    .background(Circle().fill(Color.white.opacity(0.1)))
                
                VStack(spacing: 10) {
                    Text(localization.tr(.cameraAccessRequired))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(localization.tr(.cameraPermissionDesc))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                VStack(spacing: 12) {
                    Button {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    } label: {
                        Text(localization.tr(.openSettings))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 40)
                    
                    Button {
                        onRequestAgain()
                    } label: {
                        Text(localization.tr(.checkAgain))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}
