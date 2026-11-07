import SwiftUI

/// Fullscreen Augmented Reality fidget spinner simulator screen.
struct ARExperienceView: View {
    @StateObject private var viewModel = ARExperienceViewModel()
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @ObservedObject private var localization = LocalizationService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            if viewModel.cameraPermissionGranted {
                // 1. RealityKit AR Camera Layer (Fullscreen)
                ARViewContainer(
                    viewModel: viewModel,
                    configuration: appEnvironment.configuration
                )
                .ignoresSafeArea()
                
                // 2. Overlay Controls & HUD
                VStack(spacing: 0) {
                    // Top Navigation & Actions Bar
                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                        
                        Spacer()
                        
                        // Mode Selector (Disabled once spinner is placed)
                        ModeSelector(
                            selectedMode: $viewModel.selectedMode,
                            isLocked: viewModel.isPlaced
                        )
                        .onChange(of: viewModel.selectedMode) { _, newMode in
                            viewModel.setMode(newMode)
                        }
                        
                        Spacer()
                        
                        // In-App Language Toggle Pill
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                localization.toggleLanguage()
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "globe")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(localization.currentLanguage.shortCode)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(height: 40)
                            .padding(.horizontal, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                        
                        // Sound/Mute Toggle
                        Button {
                            viewModel.toggleMute()
                        } label: {
                            Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Contextual Guidance / Status Pill
                    PlacementIndicatorView(
                        mode: viewModel.selectedMode,
                        isPlaced: viewModel.isPlaced,
                        canPlace: viewModel.canPlace,
                        trackingStatus: viewModel.trackingStatus,
                        isSpinning: viewModel.spinnerState.isSpinning
                    )
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Interactive Size Control Overlay
                    if viewModel.showSizeControl {
                        SpinnerSizeControlView(
                            diameter: $viewModel.spinnerDiameter,
                            onChange: { newDiameter in
                                viewModel.setDiameter(newDiameter)
                            },
                            onReset: {
                                viewModel.resetDiameter()
                            },
                            onClose: {
                                viewModel.toggleSizeControl()
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                    
                    // Rotational HUD (Visible once placed)
                    if viewModel.isPlaced {
                        SpinnerHUD(
                            state: viewModel.spinnerState,
                            onStop: {
                                viewModel.stopSpinner()
                            },
                            onSpinModeChanged: { newMode in
                                viewModel.setSpinMode(newMode)
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Bottom Controls (Place / Reset / Flashlight / Size Toggle / Model Picker)
                    ARControlPanel(
                        isPlaced: viewModel.isPlaced,
                        canPlace: viewModel.canPlace,
                        mode: viewModel.selectedMode,
                        diameter: viewModel.spinnerDiameter,
                        isSizePanelOpen: viewModel.showSizeControl,
                        isFlashlightOn: viewModel.isFlashlightOn,
                        onPlace: {
                            viewModel.place()
                        },
                        onReset: {
                            viewModel.reset()
                        },
                        onToggleFlashlight: {
                            viewModel.toggleFlashlight()
                        },
                        onToggleSizePanel: {
                            viewModel.toggleSizeControl()
                        },
                        onOpenModelSelection: {
                            viewModel.openModelSelection()
                        }
                    )
                }
            } else {
                // Camera Permission Fallback
                PermissionView {
                    viewModel.checkCameraPermission()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(true)
        .onDisappear {
            viewModel.turnOffFlashlight()
        }
        .sheet(isPresented: $viewModel.showModelSelectionSheet) {
            SpinnerSelectionSheet(
                selectionManager: viewModel.selectionManager,
                onSelectModel: { model in
                    viewModel.selectModel(model)
                }
            )
            .presentationDetents([.fraction(0.65), .large])
            .presentationDragIndicator(.visible)
        }
    }
}
