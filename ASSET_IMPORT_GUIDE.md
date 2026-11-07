# ARSpinner - 3D Asset & Audio Import Guide

This guide explains how to replace the procedural RealityKit fidget spinner with custom 3D models (USDZ), high-resolution PBR textures, and bearing acoustic effects.

Thanks to the modular protocol-oriented architecture of ARSpinner (`SpinnerEntityProviding`), you can swap the 3D model asset without touching the **Physics Engine**, **Touch Projector**, or **Gesture Controller**.

---

## 1. 3D Modeling Standards & Coordinate Convention

To ensure physics calculations, lever-arm impulse projections, and visual alignment remain physically accurate, all custom 3D models must adhere strictly to these coordinate conventions:

| Property | Standard Requirement |
| :--- | :--- |
| **Origin $(0, 0, 0)$** | Centered precisely at the core of the central bearing |
| **Rotation Axis** | **Local $+Y$ axis** $(0, 1, 0)$ |
| **Spin Plane** | **Local $XZ$ plane** (horizontal disc) |
| **Outer Diameter** | $7.0\text{ cm} - 8.0\text{ cm}$ (Radius: $0.035\text{ m} - 0.040\text{ m}$) |
| **Thickness** | $0.8\text{ cm} - 1.2\text{ cm}$ ($0.008\text{ m} - 0.012\text{ m}$) |
| **Polygon Budget** | $10,000 - 35,000$ triangles (optimized for mobile 60/120 FPS AR) |
| **Hierarchy** | Root Entity $\rightarrow$ `SpinnerBody` (all rotating lobes & weights attached here) |

> [!IMPORTANT]
> The spinner must be modeled as a single rigid body under `SpinnerBody`. The 3 wings must **not** rotate independently.

---

## 2. Modeling & Exporting in Blender

### Step 1: Geometry Setup in Blender
1. Open Blender and set **Scene Units**:
   - Unit System: `Metric`
   - Unit Scale: `1.0`
   - Length: `Meters` or `Centimeters`
2. Model the fidget spinner lying flat on the ground plane (facing $+Z$ up in Blender; Blender $+Z$ will map to Apple $+Y$ upon USDZ export).
3. Set the 3D Cursor to the exact center of the central bearing.
4. Press `Ctrl + A` $\rightarrow$ **Apply All Transforms** (Location, Rotation, Scale).
5. Name the parent collection or object: `SpinnerBody`.

### Step 2: UV Unwrapping & PBR Materials
Export standard PBR metallic-roughness textures at $2048 \times 2048$ resolution (PNG or HEIC):
- **Base Color / Albedo**: Anodized metal or titanium finish.
- **Roughness Map**: Grayscale (glossy bearing races $\approx 0.1$, satin anodized body $\approx 0.35$).
- **Metallic Map**: White ($1.0$) for metal parts; dark ($0.0$) for plastic/rubber gaskets.
- **Normal Map**: Direct-X / OpenGL tangent-space normal map for engraved logos and bevels.

### Step 3: Exporting to USDZ
Option A: **Direct Blender USD Export**
1. Go to **File** $\rightarrow$ **Export** $\rightarrow$ **Universal Scene Description (.usd, .usdc, .usda)**.
2. Check `Selected Objects Only`.
3. Set Forward Axis to `Y` and Up Axis to `Z` (or Apple USD presets).
4. Run Apple's `usdzconvert` tool:
   ```bash
   usdzconvert Spinner.usdc Spinner.usdz -albedo BaseColor.png -metallic Metallic.png -roughness Roughness.png -normal Normal.png
   ```

Option B: **Apple Reality Converter (macOS)**
1. Export model from Blender as `.gltf` or `.obj`.
2. Drag and drop into **Reality Converter**.
3. Assign textures to the respective material slots.
4. Verify rotation axis and scale in AR Quick Look.
5. Save as `Spinner.usdz`.

---

## 3. Integrating the USDZ Model into ARSpinner

### Step 1: Add Asset to Xcode
1. Drag `Spinner.usdz` into the `ARSpinner/Resources/Models/` group in Xcode.
2. Ensure the **Target Membership** has `ARSpinner` checked.

### Step 2: Create `USDZSpinnerEntityFactory`
Create a new file `ARSpinner/Scene/USDZSpinnerEntityFactory.swift` conforming to `SpinnerEntityProviding`:

```swift
import Foundation
import RealityKit

@MainActor
final class USDZSpinnerEntityFactory: SpinnerEntityProviding {
    
    let outerRadius: Float = 0.038 // 3.8 cm
    let thickness: Float = 0.011   // 1.1 cm
    private let modelName: String
    
    init(modelName: String = "Spinner") {
        self.modelName = modelName
    }
    
    func createSpinnerEntity() -> (root: Entity, rotatingBody: Entity) {
        let root = Entity()
        root.name = "SpinnerRoot"
        
        // Add Collision bounding box for physical touch detection
        let collisionShape = ShapeResource.generateBox(
            size: simd_float3(outerRadius * 2.3, thickness * 1.8, outerRadius * 2.3)
        )
        root.components.set(CollisionComponent(shapes: [collisionShape]))
        
        // Load custom USDZ model
        guard let modelEntity = try? Entity.load(named: modelName) else {
            fatalError("Failed to load \(modelName).usdz from application bundle.")
        }
        
        modelEntity.name = "SpinnerBody"
        root.addChild(modelEntity)
        
        return (root: root, rotatingBody: modelEntity)
    }
}
```

### Step 3: Register in `SpinnerSceneController`
In `SpinnerSceneController.swift`, simply inject the new factory:

```swift
let usdzFactory = USDZSpinnerEntityFactory(modelName: "Spinner")
sceneController.setEntityFactory(usdzFactory)
```

No changes are needed in `SpinnerPhysicsEngine`, `SwipeImpulseCalculator`, or `TouchProjector`! The physical simulation and swipe interactions will automatically control the imported USDZ rigid body.

---

## 4. Audio Effects Integration

To add realistic ball-bearing sound effects:

1. Obtain two audio clips:
   - `bearing_loop.wav`: Seamless mono loop of a ceramic/steel ball bearing spinning at medium speed (~$3000\text{ Hz}$ spectral noise).
   - `finger_flick.wav`: Short metallic contact tap ($< 50\text{ ms}$).
2. Add both files to `ARSpinner/Resources/Audio/`.
3. Update `AudioFeedbackService.swift`:
   - Initialize an `AVAudioPlayer` or `AVAudioEngine` with `AVAudioUnitVarispeed`.
   - Modulate playback rate and volume proportional to angular velocity:
     $$\text{Rate} = \operatorname{clamp}\left(\frac{|\omega|}{50.0}, 0.2, 2.5\right)$$
     $$\text{Volume} = \operatorname{clamp}\left(\frac{|\omega|}{100.0}, 0.05, 0.8\right)$$

