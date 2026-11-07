import SwiftUI

/// Main application entry point for ARSpinner.
@main
struct ARSpinnerApp: App {
    @StateObject private var appEnvironment = AppEnvironment.shared
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appEnvironment)
                .preferredColorScheme(.dark)
        }
    }
}

