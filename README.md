# ARSpinner 🌀
### Augmented Reality Fidget Spinner Simulator for iOS

ARSpinner is a high-performance native iOS application built with **Swift, SwiftUI, ARKit, and RealityKit**. It features an independent **Custom Physics Engine** simulating real-world angular momentum, moment of inertia, viscous and Coulomb bearing friction, dynamic model normalization, interactive physical sizing (4–15 cm), **in-app 3D Spinner Model Selection from USDZ Resource Library** with real-time 3D turntable previews and in-place AR model swapping, **dual spin modes** (Natural vs Cumulative Continuous Spin up to **2,000 RPM** with inter-stroke burst grace period), **procedural bearing audio synthesis** via `AVAudioEngine`, interactive **educational physics parameter cards (`ⓘ`)**, and full **Vietnamese & English bilingual localization**.

---

## 📱 Core Highlights

- **Augmented Reality Spatial Simulation**:
  - **Surface Mode**: Automatically detects real horizontal planes (tables, desks, floors) and anchors the spinner in world space.
  - **Floating Mode**: Suspends the spinner in mid-air in front of the camera, locked to world coordinates and facing the user.
- **Dynamic USDZ Resource Library & In-App Model Selection**:
  - **Dynamic Bundle Scanner (`SpinnerCatalog.swift`)**: Automatically scans the main application bundle at runtime for all `.usdz` assets (never hardcoded in UI). Automatically extracts file metadata, estimates mass and inertia, and formats friendly display names (handling `snake_case`, `camelCase`, `kebab-case`, numbers) with curated Vietnamese and English overrides.
  - **Inspected Models**:
    - **Classic Tri-Blade Spinner (`Spinner.usdz`)**: $D_{\text{raw}} = 1.959\text{ m}$, mass $0.068\text{ kg}$, 3 wings.
    - **Stealth Dual-Blade Spinner (`Spinner2.usdz`)**: $D_{\text{raw}} = 1.002\text{ m}$, mass $0.078\text{ kg}$, 2 wings.
    - **Cyber Shuriken Spinner (`Spinner3.usdz`)**: $D_{\text{raw}} = 1.002\text{ m}$, mass $0.072\text{ kg}$, 3 wings.
    - **Biohazard Dual-Blade Spinner (`Spinner4.usdz`)**: $D_{\text{raw}} = 1.002\text{ m}$, mass $0.082\text{ kg}$, 2 wings (auto-oriented flat in $XZ$).
    - **Chrome Heavy Tri-Spinner (`Spinner5.usdz`)**: $D_{\text{raw}} = 1.001\text{ m}$, mass $0.085\text{ kg}$, 3 wings.
    - **Phantom Torq Spinner (`Spinner6.usdz`)**: $D_{\text{raw}} = 1.002\text{ m}$, mass $0.075\text{ kg}$, 3 wings.
    - **Dragonfire Aero Spinner (`Spinner7.usdz`)**: $D_{\text{raw}} = 0.986\text{ m}$, mass $0.079\text{ kg}$, 3 wings.
    - **Dynamic Custom Models**: Automatically detects and formats any additional `.usdz` dropped into `ARSpinner/Resources`.
  - **In-App 3D Selection Sheet (`SpinnerSelectionSheet.swift`)**:
    - 2-column dark-mode card grid featuring isolated, low-overhead SceneKit 3D turntable previews (`Spinner3DPreviewView.swift`) with realistic studio rim lighting.
    - Checkmark badges, active spinner loading states, bilingual descriptions, and shortcut button (`fanblades.fill`) located directly beside the size adjustment button in the bottom AR control panel.
  - **In-Place AR Model Swapping Without Tracking Disruption**:
    - **Guarantees zero ARKit tracking interruption and zero AR session restart**.
    - Retains exact world anchor, Surface/Floating mode, world coordinates, orientation, user-chosen diameter scale, audio settings, and physics configuration.
    - Swaps the 3D entity hierarchy directly on the existing world anchor (`SpinnerAnchorManager.swapSpinnerModel`), resets angular velocity $\omega = 0$, resets input torque, and dynamically regenerates a matching collision box.
    - Updates model mass and recalculates moment of inertia $I$ in `SpinnerPhysicsEngine`.
    - **Race condition protection**: Uses unique UUID request tokens (`activeRequestToken`) to discard stale loads when tapping models rapidly in succession.
  - **Persistence**: Selected model ID is saved to `UserDefaults` and seamlessly restored on subsequent app launches.
- **Dynamic 3D Model Normalization & USDZ Support**:
  - Automatically loads and analyzes the raw visual bounding box of `Spinner.usdz`.
  - Normalizes oversized models (e.g. raw 1.96 m asset) down to an accurate physical fidget spinner diameter (default **7.6 cm**).
  - Precisely centers the model pivot at `(0, 0, 0)` so rotation occurs exactly about the central bearing core.
  - Generates an accurate, matching collision volume and procedural fallback if asset loading fails.
- **Interactive In-AR Size Adjustment**:
  - Live size control panel directly accessible from the AR screen.
  - Continuous slider from **4.0 cm** to **15.0 cm** with fine **0.1 cm** stepper buttons (`[-]` and `[+]`) and a reset-to-default button (`7.6 cm`).
  - Resizes visual geometry, collision box, and touch gesture hit boundaries **in-place** without duplicating entities, altering world anchor position, or interrupting active rotation.
- **Custom Rotational Physics Engine**:
  - Decoupled from rendering logic (zero RealityKit dependencies in physics layer).
  - Fixed-axis angular momentum equations:
    $$\Delta L = r \times J$$
    $$\Delta \omega = \frac{(r \times J) \cdot \text{axis}}{I}$$
  - Dual friction modeling:
    - **Viscous Damping**: $\tau_v = -c_v \cdot \omega$ (air drag and bearing lubricant resistance).
    - **Coulomb Dry Friction**: $\tau_c = -\mu_c \cdot \operatorname{sgn}(\omega)$ (ball contact drag).
  - Numerical integration with sub-stepping ($240\text{ Hz}$) for complete frame-rate independence (30 FPS vs 60 FPS vs 120 FPS ProMotion).
- **Direct Finger-to-Spinner Continuous Torque Physics**:
  - **Instantaneous Real-Time Response**: Eliminates gesture latency; as soon as a finger touches a wing and moves, continuous tangential torque is injected into the physics engine during `touchesMoved`.
  - **Contact Traction & Dynamic Braking**:
    $$\tau_{\text{contact}} = r \times F_{\text{contact}}$$
    $$F_{\text{contact}} = k_{\text{grip}} \cdot (v_{\text{finger, tan}} - \omega r)$$
    Swiping in the spin direction drives immediate acceleration; swiping counter-direction applies strong opposing torque that brakes and reverses rotation.
  - **Stationary Rest Zeroing**: When the finger rests stationary on screen ($v \approx 0$), active torque is zeroed ($\tau = 0$), allowing the spinner to coast with bearing friction.
  - **Seamless Velocity Preservation on Release**: When the finger lifts (`touchesEnded`), the spinner preserves its active angular velocity $\omega$ and continues spinning with natural inertia (zero duplicate impulse).
- **3D Ray-Volume Edge Hit Testing**:
  - Replaces flat 2D plane projection with an analytical **3D Ray-Cylinder Volume Intersection**:
    - **Top Face**: Intersects planar cap ($y = +h$, normal $[0, 1, 0]$).
    - **Bottom Face**: Intersects lower cap ($y = -h$, normal $[0, -1, 0]$) when viewing from beneath.
    - **Side Edges & Outer Rim**: Intersects cylindrical side walls ($x^2 + z^2 = R^2, y \in [-h, h]$), enabling intuitive swiping directly on the wing rims and edges.
    - **Extreme Angle Robustness**: Functions flawlessly at oblique, steep, and near-horizontal camera perspectives without parallel plane raycast failures.
- **Dual Spin Modes (Natural vs Cumulative Continuous Spin)**:
  - **Natural Mode (Quán tính)**: Authentic physical skin traction model ($F = k_{\text{grip}} \cdot (v_{\text{finger}} - v_{\text{surface}})$); each swipe imparts realistic force, and touching a wing spinning faster than the finger naturally slows it down. Once released, it spins down smoothly under viscous and Coulomb bearing friction.
  - **Continuous Mode (Tăng tốc liên tục)**: Redesigned into a non-braking cumulative acceleration engine. Co-directional swipes add positive driving torque regardless of how fast the spinner is already rotating (no relative velocity braking at high RPM!), allowing the user to pump the spinner up to **2,000 RPM** ($\omega_{\max} \approx 209.4395\text{ rad/s}$).
  - **Inter-Stroke Grace Period (0.5s)**: During rapid flick bursts, friction is damped during the $0.5\text{ s}$ pause between strokes so the spinner does not shed momentum before the next flick lands. Once the user stops swiping, full bearing friction engages and spins the spinner down to rest.
  - **Counter-Directional Braking**: Swiping against rotation applies strong opposing torque, instantly braking and reversing rotation.
  - Mode switching is mathematically seamless: preserves current rotation angle and velocity without discontinuity.
  - HUD displays a mode selector, real-time `RPM / 2,000 RPM` readout with progress gauge, and coaching tips.
- **Procedural Bearing Audio Synthesis (`AVAudioEngine`)**:
  - 100% procedurally synthesized in-memory audio buffer (zero external audio files or copyright concerns).
  - Accurately models steel/ceramic ball bearing acoustics: metallic raceway rolling noise + resonant harmonic hum + cyclic ball pass flutter.
  - Real-time modulation: Pitch (-800 to +1400 cents), playback rate ($0.65\times$ to $2.2\times$), and exponential volume mapped dynamically to current RPM.
  - Automatically silences below $15\text{ RPM}$; includes tactile contact flick ticks and full mute/volume controls.
- **Redesigned Physics Settings with Educational Info Sheets (`ⓘ`)**:
  - Modal popover sheet (`PhysicsParameterInfoSheet`) beside each parameter explaining:
    1. What is this parameter?
    2. How it affects spinner rotation.
    3. What happens when increased.
    4. What happens when decreased.
    5. What the current value means in real-world physical units.
  - Clear physical distinction between total mass ($m$) and moment of inertia ($I$).
- **Vietnamese & English Bilingual Localization**:
  - Seamless in-app language toggle (`EN` / `VI`) in the top navigation bar with instant UI update without app restart.
  - Complete translations for all screens, guidance pills, telemetry, HUD, and educational parameter descriptions.
  - Language preference persisted via `UserDefaults`.
- **Numerical Robustness & Safe Transforms**:
  - Employs Gram-Schmidt orthonormalization in `SafeTransform.swift` to eliminate `Call to RETransformComponentSetLocalSRT contains NaN` errors.
  - Safe quaternion conversion protecting against zero-length axis vectors and non-finite inputs.

---

## 🏛 Architecture & Code Structure

The project strictly follows Modular Architecture with unidirectional data flow and clean separation of concerns:

```
ARSpinner/
├── App/
│   ├── ARSpinnerApp.swift              # App entry point (@main)
│   └── AppEnvironment.swift            # Global settings & dependency container
│
├── Models/
│   ├── SpinnerConfiguration.swift      # Mass, inertia, diameter, friction tuning
│   ├── SpinnerMode.swift               # .surface and .floating enum
│   ├── SpinMode.swift                  # .natural and .continuous (1200 RPM cap) enum
│   └── SpinnerState.swift              # Observable telemetry snapshot for SwiftUI
│
├── Utilities/
│   ├── VectorMath.swift                # SIMD 3D math, finite guards, ray-plane math, RPM conversion
│   ├── QuaternionHelper.swift          # Orientation math, zero-length vector protection
│   ├── SafeTransform.swift             # Matrix orthonormalization eliminating NaN Transform errors
│   ├── LocalizationService.swift       # Bilingual localization engine & dictionary (EN/VI)
│   └── Logger.swift                    # Unified os.Logger subsystem
│
├── Physics/                            # PURE SWIFT & SIMD (Zero RealityKit dependency)
│   ├── SpinnerPhysicsState.swift       # Angle, angular velocity, RPM, acceleration, inertia
│   ├── FrictionModel.swift             # Viscous, Coulomb, and Combined friction models
│   ├── InertiaCalculator.swift         # Mass moment of inertia (I) calculator
│   ├── AngularMotionSolver.swift       # Sub-stepped semi-implicit numerical integrator
│   └── SpinnerPhysicsEngine.swift      # Master physics coordinator with mode handling
│
├── Scene/                              # RealityKit 3D rendering layer
│   ├── ProceduralMeshHelper.swift      # MeshDescriptor cylinder generator for iOS 17+
│   ├── SpinnerEntityProviding.swift    # Abstraction protocol for 3D model providers
│   ├── USDZSpinnerEntityFactory.swift  # Model normalization, pivot centering & dynamic resizing
│   ├── SpinnerEntityFactory.swift      # Procedural 3D metallic fidget spinner
│   ├── SpinnerAnchorManager.swift      # AnchorEntity management in world space
│   ├── SceneUpdateController.swift     # SceneEvents.Update loop & telemetry throttle
│   └── SpinnerSceneController.swift    # Master 3D scene & physics coordinator
│
├── AR/                                 # ARKit tracking & placement
│   ├── ARSessionCoordinator.swift      # ARSessionDelegate & camera tracking observer
│   ├── PlaneDetectionManager.swift     # Horizontal plane classifier
│   ├── ARRaycastManager.swift          # Geometry & estimated plane raycasting
│   ├── ARPlacementManager.swift        # Surface indicator, safe transforms & world anchoring
│   └── ARViewContainer.swift           # UIViewRepresentable bridging RealityKit to SwiftUI
│
├── Interaction/                        # Gestures & touch math
│   ├── TouchProjector.swift            # Ray-plane projection with dynamic boundary check
│   ├── SwipeImpulseCalculator.swift    # Clamped torque, linear impulse, and Δω calculator
│   ├── InteractionStateMachine.swift   # Sample buffering, trailing 120ms window & rest detector
│   └── SpinnerGestureController.swift  # Pan & tap gesture handler on ARView with logging
│
├── AudioHaptics/
│   ├── HapticFeedbackService.swift     # UIImpactFeedbackGenerator tactile response
│   └── AudioFeedbackService.swift      # Procedural AVAudioEngine bearing sound & contact clicks
│
├── Catalog/                            # Dynamic Model Management & Metadata
│   ├── SpinnerModelDescriptor.swift    # Metadata model, bilingual display names, estimated mass & radius
│   ├── SpinnerCatalog.swift            # Dynamic bundle scanner for all .usdz files & curated registry
│   └── SpinnerSelectionManager.swift   # Observable selection state, async loading & race-condition guards
│
├── Presentation/                       # SwiftUI views & controls
│   ├── Screens/
│   │   ├── HomeView.swift              # Minimalist landing view with 3D preview & lang toggle
│   │   └── ARExperienceView.swift      # Fullscreen AR simulator interface
│   ├── Components/
│   │   ├── ModeSelector.swift          # Surface vs Floating segmented pill
│   │   ├── SpinnerHUD.swift            # Digital RPM gauge, spin mode selector & coaching
│   │   ├── SpinnerSizeControlView.swift# Interactive diameter slider & steppers (4–15 cm)
│   │   ├── SpinnerSelectionSheet.swift # 2-column model selection sheet with 3D turntable cards
│   │   ├── SpinnerCardView.swift       # Card view displaying 3D preview, selection checkmark & metadata
│   │   ├── Spinner3DPreviewView.swift  # Lightweight isolated SceneKit 3D turntable viewer
│   │   ├── ARControlPanel.swift        # Primary Place/Reset/Settings/Size/Model toolbar
│   │   ├── PlacementIndicatorView.swift# AR scanning guidance overlay
│   │   ├── PhysicsConfigSheet.swift    # Live physics parameters tuning sheet with ⓘ buttons
│   │   ├── PhysicsParameterInfo.swift  # Structured educational parameter explanations
│   │   ├── PhysicsParameterInfoSheet.swift # Educational popover sheet for parameters
│   │   └── PermissionView.swift        # Camera access request screen
│   └── ViewModels/
│       └── ARExperienceViewModel.swift # Presentation state machine
│
├── Resources/
│   ├── Spinner.usdz                    # Classic Tri-Blade Fidget Spinner model
│   └── Spinner2.usdz                   # Stealth Dual-Blade Fidget Spinner model
│
└── Tests/ARSpinnerTests/               # XCTest Unit Test Suite (75 tests)
    ├── SpinnerCatalogAndSelectionTests.swift   # Catalog discovery, name format, in-place swap, race condition, inertia update
    ├── ContinuousTorqueAndDragTests.swift      # Real-time torque, stationary finger, Natural & Continuous drag, 2,000 RPM cap
    ├── RayVolumeHitTestingTests.swift          # 3D cylinder/disc hit testing (top, bottom, side rim, margin)
    ├── ContinuousSpinPhysicsTests.swift        # Cumulative acceleration, 2,000 RPM ceiling, 10-stroke burst, high-RPM non-braking, grace period
    ├── AudioAndSettingsTests.swift             # Audio engine lifecycle, mute, educational content
    ├── TouchAndGestureTests.swift              # Tap/long-press rejection, trailing flick, bounds
    ├── ModelNormalizationAndResizeTests.swift  # Normalization math, bounds, scaling, pivot
    ├── SafeTransformAndNumericalSafetyTests.swift # NaN matrix rejection, orthonormalization
    ├── LocalizationServiceTests.swift          # Translation coverage, model selection keys & language switching
    ├── SpinnerPhysicsEngineTests.swift         # Angular motion, friction, FPS independence
    ├── SwipeImpulseCalculatorTests.swift       # Lever arm ratio, speed scaling, reversal
    └── VectorMathTests.swift                   # SIMD math, finite guards, ray-plane checks
```

---

## 🛠 Build & Run Instructions

### Prerequisites
- macOS 14+ with **Xcode 15 or Xcode 16**.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
- Physical iPhone/iPad running iOS 17.0+ for full AR camera tracking.

### Generate & Build Project
```bash
# 1. Generate Xcode project from project.yml
xcodegen generate

# 2. Run automated unit test suite (75 tests)
xcodebuild test \
  -project ARSpinner.xcodeproj \
  -scheme ARSpinner \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO

# 3. Build for physical device
xcodebuild build \
  -project ARSpinner.xcodeproj \
  -scheme ARSpinner \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

---

## 🔬 Unit Test Coverage

ARSpinner includes a **75-test unit suite** verifying every aspect of 3D volume hit testing, continuous torque, physics, gestures, safe transforms, audio, localization, dynamic catalog discovery, and in-place model swapping:

| Test Suite | Tests | Scope |
| :--- | :---: | :--- |
| **SpinnerCatalogAndSelectionTests** | 14 | Dynamic `.usdz` bundle discovery, duplicate prevention, non-existent fallback, friendly name formatting (snake_case, camelCase, numbers), mass & inertia metadata calculation, in-place entity replacement without anchor recreation, world coordinate & diameter preservation, inertia update, `UserDefaults` persistence, rapid-click race condition prevention, multi-mode operation with swapped model |
| **ContinuousTorqueAndDragTests** | 7 | Zero torque when stationary, micro-movement rejection, positive drive torque, counter-swipe braking, instant Natural Spin response, Continuous Spin 2,000 RPM cap, automatic torque decay timeout |
| **RayVolumeHitTestingTests** | 6 | Top face hits ($+Y$), bottom face hits ($-Y$), horizontal side-edge hits, oblique angle edge hits, outside volume rejection, tolerance margin catchment |
| **ContinuousSpinPhysicsTests** | 9 | Multi-swipe velocity stacking, strict 2,000 RPM cap, high-RPM non-braking verification, 10-stroke consecutive acceleration sequence, counter-swipe braking and reversal, 0.5s inter-stroke grace period retention, mode switching invariance, counter-swipe deceleration, FPS independence |
| **TouchAndGestureTests** | 8 | Tap rejection (0 impulse), long-press rejection, swipe-and-hold rest rejection, valid flick detection, sub-threshold velocity rejection, dynamic radius hit testing, boundary touch rejection, torque clamping |
| **AudioAndSettingsTests** | 3 | Audio engine setup/mute lifecycle, audio independence from physics integration, completeness of educational parameter cards in EN & VI |
| **ModelNormalizationAndResizeTests** | 4 | Normalization from oversized USDZ bounds, pivot centering at `(0,0,0)`, aspect ratio preservation, dynamic resizing continuity |
| **SafeTransformAndNumericalSafetyTests** | 6 | Rejection of NaN/infinite matrices, Gram-Schmidt orthonormalization, zero-axis quaternion safety, ray-plane protection |
| **LocalizationServiceTests** | 4 | Verification of all keys in English and Vietnamese, model selection keys check, language toggling, `UserDefaults` persistence |
| **SpinnerPhysicsEngineTests** | 10 | Impulse response, friction spindown, zero-threshold clamp, velocity limits, reset, FPS independence |
| **SwipeImpulseCalculatorTests** | 3 | Lever arm ratio ($\sim 7\times$ torque at wings), speed-proportional impulse, direction reversal |
| **VectorMathTests** | 6 | SIMD cross/dot products, plane projection, ray-plane intersection, angle normalization, RPM conversions |
