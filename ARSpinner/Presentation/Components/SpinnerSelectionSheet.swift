import SwiftUI

/// Premium dark-mode sheet presenting the library of available 3D USDZ spinner models in a 2-column grid.
struct SpinnerSelectionSheet: View {
    @ObservedObject var selectionManager: SpinnerSelectionManager
    let onSelectModel: (SpinnerModelDescriptor) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject private var localization = LocalizationService.shared
    
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background dark blur
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Subtitle Guidance
                        Text(localization.tr(.modelSelectionSubtitle))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        // Error Banner (if any)
                        if let error = selectionManager.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Empty State (if zero models found)
                        if selectionManager.catalog.availableModels.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text(localization.tr(.noAvailableModels))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            // 2-Column Model Grid
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(selectionManager.catalog.availableModels) { model in
                                    SpinnerCardView(
                                        model: model,
                                        isSelected: selectionManager.selectedModel.id == model.id,
                                        isLoading: selectionManager.loadingModelId == model.id,
                                        onSelect: {
                                            onSelectModel(model)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(localization.tr(.chooseSpinner))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                if selectionManager.catalog.availableModels.isEmpty {
                    selectionManager.catalog.refreshCatalog()
                }
            }
        }
    }
}

