import Foundation
import simd

/// Status of USDZ model loading and readiness.
enum SpinnerLoadStatus: String, Sendable, Equatable {
    case ready
    case loading
    case failed
}

/// Metadata and descriptor for a 3D fidget spinner model loaded from USDZ resources.
struct SpinnerModelDescriptor: Identifiable, Sendable, Equatable {
    
    // MARK: - Core Identifiers
    
    /// Unique identifier for the spinner model (e.g. "Spinner", "Spinner2").
    let id: String
    
    /// Raw filename including extension (e.g. "Spinner.usdz", "Spinner2.usdz").
    let fileName: String
    
    /// Asset name without extension for bundle lookup (e.g. "Spinner", "Spinner2").
    let assetName: String
    
    /// Direct file URL in the application bundle if located on disk.
    let fileURL: URL?
    
    // MARK: - Bilingual Display Names
    
    /// Friendly English display name.
    let displayNameEn: String
    
    /// Friendly Vietnamese display name.
    let displayNameVi: String
    
    // MARK: - Physical & Simulation Properties
    
    /// Estimated physical mass of the spinner in kilograms (default ~0.068 kg = 68 grams).
    let estimatedMass: Float
    
    /// Number of symmetric lobes or wings (e.g. 3 for tri-spinner).
    let wingCount: Int
    
    /// Material description for UI badges (e.g. "Ceramic Hybrid", "Steel").
    let materialDescriptionEn: String
    let materialDescriptionVi: String
    
    /// Rotation axis in local model coordinates (default is local +Y axis [0, 1, 0]).
    let localRotationAxis: simd_float3
    
    /// Whether this model was bundled natively with the app.
    let isBundled: Bool
    
    // MARK: - Initializer
    
    init(
        id: String,
        fileName: String,
        assetName: String,
        fileURL: URL? = nil,
        displayNameEn: String,
        displayNameVi: String,
        estimatedMass: Float = 0.068,
        wingCount: Int = 3,
        materialDescriptionEn: String = "Ceramic Hybrid",
        materialDescriptionVi: String = "Gốm lai Ceramic",
        localRotationAxis: simd_float3 = simd_float3(0, 1, 0),
        isBundled: Bool = true
    ) {
        self.id = id
        self.fileName = fileName
        self.assetName = assetName
        self.fileURL = fileURL
        self.displayNameEn = displayNameEn
        self.displayNameVi = displayNameVi
        self.estimatedMass = estimatedMass
        self.wingCount = wingCount
        self.materialDescriptionEn = materialDescriptionEn
        self.materialDescriptionVi = materialDescriptionVi
        self.localRotationAxis = localRotationAxis
        self.isBundled = isBundled
    }
    
    // MARK: - Localized Helpers
    
    /// Returns the appropriate display name based on active app language.
    func localizedName(for language: AppLanguage) -> String {
        switch language {
        case .vi:
            return displayNameVi
        case .en:
            return displayNameEn
        }
    }
    
    /// Returns the localized material description based on active app language.
    func localizedMaterial(for language: AppLanguage) -> String {
        switch language {
        case .vi:
            return materialDescriptionVi
        case .en:
            return materialDescriptionEn
        }
    }
    
    // MARK: - Auto-formatting Helper
    
    /// Converts raw filenames (e.g. "Custom_Gold_Spinner_02.usdz") into clean human-readable titles.
    static func formatFriendlyName(from rawFileName: String) -> String {
        var baseName = (rawFileName as NSString).deletingPathExtension
        
        // Replace underscores and hyphens with spaces
        baseName = baseName.replacingOccurrences(of: "_", with: " ")
        baseName = baseName.replacingOccurrences(of: "-", with: " ")
        
        // Insert space before capital letters in camelCase (e.g. "NeonSpinner" -> "Neon Spinner")
        let formatted = baseName.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        
        // Insert space before digits if adjacent to letters (e.g. "Spinner2" -> "Spinner 2")
        let withDigitSpacing = formatted.replacingOccurrences(
            of: "([a-zA-Z])([0-9])",
            with: "$1 $2",
            options: .regularExpression
        )
        
        // Capitalize words
        let words = withDigitSpacing.split(separator: " ").map { word -> String in
            guard let first = word.first else { return "" }
            return first.uppercased() + word.dropFirst()
        }
        
        let result = words.joined(separator: " ")
        return result.isEmpty ? "Custom Spinner" : result
    }
}

