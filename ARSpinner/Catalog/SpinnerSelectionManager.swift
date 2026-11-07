import Foundation
import Combine
import RealityKit

/// Manages the active spinner model selection, asynchronous loading, race-condition protection,
/// and UserDefaults persistence.
@MainActor
final class SpinnerSelectionManager: ObservableObject {
    
    // MARK: - Storage Keys
    
    private let storageKey = "com.arspinner.selected_spinner_model_id"
    
    // MARK: - Dependencies
    
    let catalog: SpinnerCatalog
    
    // MARK: - Published State
    
    /// Currently active and selected spinner model.
    @Published private(set) var selectedModel: SpinnerModelDescriptor
    
    /// Whether an asynchronous model load operation is actively in progress.
    @Published private(set) var isLoading: Bool = false
    
    /// The ID of the model currently being loaded.
    @Published private(set) var loadingModelId: String? = nil
    
    /// Transient user-facing error message if a model load failed.
    @Published var errorMessage: String? = nil
    
    // MARK: - Race Condition Protection
    
    /// Token representing the latest user selection request; stale tasks are automatically dropped.
    private var activeRequestToken: UUID?
    
    // MARK: - Initialization
    
    init(catalog: SpinnerCatalog? = nil) {
        let resolvedCatalog = catalog ?? SpinnerCatalog.shared
        self.catalog = resolvedCatalog
        
        // Restore saved model selection or fall back to default
        if let savedId = UserDefaults.standard.string(forKey: "com.arspinner.selected_spinner_model_id"),
           let restored = resolvedCatalog.model(withId: savedId) {
            self.selectedModel = restored
        } else {
            self.selectedModel = resolvedCatalog.defaultModel
        }
    }
    
    // MARK: - Model Selection
    
    /// Asynchronously loads and applies a new spinner model into the scene.
    ///
    /// Guarantees:
    /// - Zero ARKit session interruption.
    /// - World anchor position and orientation are strictly preserved.
    /// - If model A is clicked and then model B is quickly clicked, model A is discarded (race condition protection).
    /// - If loading fails, the previous model is retained and an error message is set.
    func selectModel(
        _ model: SpinnerModelDescriptor,
        sceneController: SpinnerSceneController,
        targetDiameter: Float,
        onComplete: ((Bool) -> Void)? = nil
    ) {
        // If already selected and not currently loading, nothing to do
        if selectedModel.id == model.id && !isLoading && sceneController.isPlaced {
            onComplete?(true)
            return
        }
        
        let requestToken = UUID()
        self.activeRequestToken = requestToken
        self.isLoading = true
        self.loadingModelId = model.id
        self.errorMessage = nil
        
        let config = sceneController.physicsEngine.configuration
        let factory = USDZSpinnerEntityFactory(
            modelDescriptor: model,
            defaultDiameter: targetDiameter,
            configuration: config
        )
        
        Task { @MainActor in
            do {
                // 1. Asynchronously load and normalize the 3D entity hierarchy
                let loadedHierarchy = try await factory.loadSpinnerEntityAsync(targetDiameter: targetDiameter)
                
                // 2. Race condition check: ensure user has not selected another model in the meantime
                guard self.activeRequestToken == requestToken else {
                    AppLogger.scene.info("Discarded stale model load for '\(model.id)' because another model was requested.")
                    return
                }
                
                // 3. Swap entity in scene without altering world anchor or ARKit session
                sceneController.swapSpinnerModel(
                    with: factory,
                    hierarchy: loadedHierarchy,
                    descriptor: model,
                    targetDiameter: targetDiameter
                )
                
                // 4. Update state and persist
                self.selectedModel = model
                UserDefaults.standard.set(model.id, forKey: self.storageKey)
                self.isLoading = false
                self.loadingModelId = nil
                self.errorMessage = nil
                
                AppLogger.scene.info("Successfully switched spinner model to: '\(model.id)' (\(model.displayNameEn)).")
                onComplete?(true)
                
            } catch {
                guard self.activeRequestToken == requestToken else { return }
                
                self.isLoading = false
                self.loadingModelId = nil
                self.errorMessage = error.localizedDescription
                
                AppLogger.scene.error("Failed to load spinner model '\(model.id)': \(error.localizedDescription). Keeping current model.")
                onComplete?(false)
            }
        }
    }
    
    /// Directly sets the selected model without loading (useful for testing or initializing state).
    func setSelectedModelDirectly(_ model: SpinnerModelDescriptor) {
        self.selectedModel = model
        UserDefaults.standard.set(model.id, forKey: self.storageKey)
    }
}

