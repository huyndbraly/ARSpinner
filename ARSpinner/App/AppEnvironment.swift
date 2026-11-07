import Foundation
import SwiftUI

/// Environment configuration and dependency container for ARSpinner.
@MainActor
final class AppEnvironment: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var activeMode: SpinnerMode = .surface
    @Published var configuration: SpinnerConfiguration = .standard
    @Published var hasCompletedOnboarding: Bool = false
    
    // MARK: - Singleton
    
    static let shared = AppEnvironment()
    
    private init() {}
    
    // MARK: - Methods
    
    func updateConfiguration(_ newConfig: SpinnerConfiguration) {
        self.configuration = newConfig
    }
    
    func setPlacementMode(_ mode: SpinnerMode) {
        self.activeMode = mode
    }
}

