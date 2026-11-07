import SwiftUI
import SceneKit

/// Thread-safe in-memory cache for loaded SceneKit preview nodes to eliminate repeated disk I/O.
final class SpinnerPreviewCache: @unchecked Sendable {
    static let shared = SpinnerPreviewCache()
    private let cache = NSCache<NSString, SCNNode>()
    
    private init() {
        cache.countLimit = 20
    }
    
    func getNode(for key: String) -> SCNNode? {
        return cache.object(forKey: key as NSString)?.clone()
    }
    
    func setNode(_ node: SCNNode, for key: String) {
        cache.setObject(node, forKey: key as NSString)
    }
}

/// Lightweight, isolated 3D preview component rendering USDZ spinner models in SwiftUI
/// with custom studio lighting, asynchronous background loading, and smooth turntable rotation.
struct Spinner3DPreviewView: View {
    let fileURL: URL?
    let assetName: String
    
    var body: some View {
        SceneKitPreviewRepresentable(fileURL: fileURL, assetName: assetName)
            .background(
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.06), Color.black.opacity(0.35)]),
                    center: .center,
                    startRadius: 10,
                    endRadius: 90
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - SceneKit Representable

private struct SceneKitPreviewRepresentable: UIViewRepresentable {
    let fileURL: URL?
    let assetName: String
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)
        scnView.backgroundColor = .clear
        // Disable heavy multisampling on high-DPI retina display to save significant Metal memory bandwidth
        scnView.antialiasingMode = .none
        // Cap preview FPS at 30 to prevent GPU contention with running ARKit/RealityKit session
        scnView.preferredFramesPerSecond = 30
        scnView.isUserInteractionEnabled = false // Gesture interactions handled at card level
        
        setupScene(on: scnView)
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Scene is static turntable; no continuous property mutation needed
    }
    
    static func dismantleUIView(_ uiView: SCNView, coordinator: ()) {
        uiView.scene?.rootNode.removeAllActions()
        uiView.scene = nil
        uiView.pointOfView = nil
    }
    
    private func setupScene(on scnView: SCNView) {
        let scene = SCNScene()
        
        // 1. Studio Lighting Rig
        let keyLightNode = SCNNode()
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 1100
        keyLight.color = UIColor.white
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(1.0, 2.0, 2.0)
        keyLightNode.eulerAngles = SCNVector3(-Float.pi / 4.0, Float.pi / 6.0, 0)
        scene.rootNode.addChildNode(keyLightNode)
        
        let rimLightNode = SCNNode()
        let rimLight = SCNLight()
        rimLight.type = .directional
        rimLight.intensity = 700
        rimLight.color = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        rimLightNode.light = rimLight
        rimLightNode.position = SCNVector3(-1.5, 1.5, -2.0)
        rimLightNode.eulerAngles = SCNVector3(Float.pi / 4.0, -Float.pi / 3.0, 0)
        scene.rootNode.addChildNode(rimLightNode)
        
        let ambientLightNode = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 400
        ambientLight.color = UIColor(white: 0.8, alpha: 1.0)
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
        
        // 2. Camera setup angled obliquely to clearly reveal wings and central bearing
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = 50.0
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.48, 1.35)
        cameraNode.eulerAngles = SCNVector3(-0.35, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode
        
        let containerNode = SCNNode()
        containerNode.name = "TurntableContainer"
        scene.rootNode.addChildNode(containerNode)
        
        scnView.scene = scene
        
        // 3. Check memory cache first for instant synchronous presentation
        let cacheKey = fileURL?.path ?? assetName
        if let cachedNode = SpinnerPreviewCache.shared.getNode(for: cacheKey) {
            containerNode.addChildNode(cachedNode)
            let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2.0, z: 0, duration: 8.0)
            containerNode.runAction(SCNAction.repeatForever(rotation))
            return
        }
        
        // 4. Asynchronously load USDZ geometry off the main thread to prevent UI freezing
        let url = fileURL
        let name = assetName
        
        DispatchQueue.global(qos: .userInitiated).async { [weak containerNode] in
            var loadedScene: SCNScene?
            if let targetURL = url, FileManager.default.fileExists(atPath: targetURL.path) {
                loadedScene = try? SCNScene(url: targetURL, options: nil)
            }
            if loadedScene == nil {
                loadedScene = SCNScene(named: name)
            }
            if loadedScene == nil {
                loadedScene = SCNScene(named: "\(name).usdz")
            }
            
            let modelWrapper = SCNNode()
            if let modelScene = loadedScene {
                let meshNode = SCNNode()
                for child in modelScene.rootNode.childNodes {
                    meshNode.addChildNode(child.clone())
                }
                
                // Check orientation of bounding box
                let bbox = meshNode.boundingBox
                let spanX = abs(Float(bbox.max.x - bbox.min.x))
                let spanY = abs(Float(bbox.max.y - bbox.min.y))
                let spanZ = abs(Float(bbox.max.z - bbox.min.z))
                
                var horizontalSpan: Float = max(spanX, spanZ)
                var centerX = Float(bbox.min.x + bbox.max.x) * 0.5
                var centerY = Float(bbox.min.y + bbox.max.y) * 0.5
                var centerZ = Float(bbox.min.z + bbox.max.z) * 0.5
                
                if spanZ < spanY && spanZ < spanX {
                    meshNode.eulerAngles.x = Float.pi / 2.0
                    horizontalSpan = max(spanX, spanY)
                    let oldY = centerY
                    let oldZ = centerZ
                    centerY = -oldZ
                    centerZ = oldY
                } else if spanX < spanY && spanX < spanZ {
                    meshNode.eulerAngles.z = Float.pi / 2.0
                    horizontalSpan = max(spanY, spanZ)
                    let oldX = centerX
                    let oldY = centerY
                    centerX = oldY
                    centerY = -oldX
                }
                
                modelWrapper.addChildNode(meshNode)
                
                if horizontalSpan > 0.001 {
                    let targetSpan: Float = 0.95
                    let scale = targetSpan / horizontalSpan
                    modelWrapper.scale = SCNVector3(scale, scale, scale)
                    modelWrapper.position = SCNVector3(-centerX * scale, -centerY * scale, -centerZ * scale)
                }
            } else {
                let fallbackGeom = SCNTorus(ringRadius: 0.35, pipeRadius: 0.08)
                fallbackGeom.firstMaterial?.diffuse.contents = UIColor.systemCyan
                let fallbackNode = SCNNode(geometry: fallbackGeom)
                modelWrapper.addChildNode(fallbackNode)
            }
            
            // Cache the prepared node
            SpinnerPreviewCache.shared.setNode(modelWrapper, for: cacheKey)
            
            // Attach to view on main thread
            DispatchQueue.main.async { [weak containerNode] in
                guard let container = containerNode else { return }
                container.addChildNode(modelWrapper.clone())
                let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2.0, z: 0, duration: 8.0)
                container.runAction(SCNAction.repeatForever(rotation))
            }
        }
    }
}
