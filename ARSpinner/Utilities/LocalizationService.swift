import Foundation
import SwiftUI
import Combine

/// Supported application languages.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en = "en"
    case vi = "vi"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .en: return "English"
        case .vi: return "Tiếng Việt"
        }
    }
    
    var shortCode: String {
        switch self {
        case .en: return "EN"
        case .vi: return "VI"
        }
    }
}

/// Central localization keys ensuring compile-time safety and zero missing string errors.
enum LocKey: String, CaseIterable, Sendable {
    // Brand & Home
    case appTitle
    case appSubtitle
    case startAR
    case physicsEngineTitle
    case physicsEngineSubtitle
    case surfaceMidAirTitle
    case surfaceMidAirSubtitle
    case swipeInteractionTitle
    case swipeInteractionSubtitle
    case swipeToSpinPrompt
    case tapToSwitchModel
    
    // Modes
    case modeSurface
    case modeFloating
    case modeSurfaceDesc
    case modeFloatingDesc
    
    // Placement & Actions
    case placeOnSurface
    case placeInAir
    case resetPosition
    case scanningEnvironment
    case pointAtSurface
    case surfaceDetectedReady
    case readyPlaceMidAir
    case trackingUnavailable
    case trackingInterrupted
    case excessiveMotion
    case insufficientFeatures
    case swipeWingsHint
    
    // HUD & Telemetry
    case rpm
    case peak
    case revs
    case speed
    case clockwise
    case counterClockwise
    case idle
    case stop
    
    // Size & Distance Control
    case spinnerSize
    case diameter
    case resetSize
    case cmUnit
    case giantSpinner
    case giantSpinnerSubtitle
    case meterUnit
    case resetSizeGiant
    case placementDistance
    case autoDistance
    case pushAwayHint
    
    // Flashlight
    case flashlight
    case flashlightOn
    case flashlightOff
    
    // Physics Settings
    case physicsTitle
    case presets
    case presetStandard
    case presetHighSpeed
    case presetHeavyBrass
    case frictionModel
    case frictionType
    case viscousDamping
    case coulombFriction
    case massAndDimensions
    case totalMass
    case momentOfInertia
    case maxSafeSpeed
    case cancel
    case apply
    case frictionCombined
    case frictionCoulomb
    case frictionViscous
    case frictionNone
    
    // Permission
    case cameraAccessRequired
    case cameraPermissionDesc
    case openSettings
    case checkAgain
    
    // Language
    case language
    
    // Spin Modes & Continuous Spin
    case spinModeNatural
    case spinModeContinuous
    case continuousSpinInstruction
    
    // Audio & Sounds
    case soundEffects
    case soundVolume
    case audioSectionHeader
    
    // Spinner State Strings
    case stateSpinning
    case stateAccelerating
    case stateDecelerating
    case stateStopped
    
    // Model Selection & Library
    case chooseSpinner
    case modelSelectionSubtitle
    case selected
    case loadingModel
    case unableToLoadModel
    case noAvailableModels
    case modelChangedSuccess
}

/// Dynamic localization service supporting instant in-app switching and UserDefaults persistence.
@MainActor
final class LocalizationService: ObservableObject {
    
    static let shared = LocalizationService()
    
    private let storageKey = "com.arspinner.selected_language"
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: storageKey)
        }
    }
    
    init() {
        if let saved = UserDefaults.standard.string(forKey: storageKey),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            let preferred = Locale.preferredLanguages.first ?? "en"
            self.currentLanguage = preferred.hasPrefix("vi") ? .vi : .en
        }
    }
    
    func tr(_ key: LocKey) -> String {
        localizedTable[key]?[currentLanguage] ?? localizedTable[key]?[.en] ?? key.rawValue
    }
    
    func toggleLanguage() {
        currentLanguage = currentLanguage == .en ? .vi : .en
    }
    
    func setLanguage(_ lang: AppLanguage) {
        currentLanguage = lang
    }
    
    // MARK: - Bilingual Dictionary
    
    private let localizedTable: [LocKey: [AppLanguage: String]] = [
        // Brand & Home
        .appTitle: [
            .en: "ARSPINNER",
            .vi: "ARSPINNER"
        ],
        .appSubtitle: [
            .en: "Physical 3D Spatial Simulator",
            .vi: "Trình mô phỏng con quay 3D vật lý"
        ],
        .startAR: [
            .en: "Start AR Experience",
            .vi: "Bắt đầu trải nghiệm AR"
        ],
        .physicsEngineTitle: [
            .en: "Custom Physics Engine",
            .vi: "Engine vật lý chính xác"
        ],
        .physicsEngineSubtitle: [
            .en: "Accurate moment of inertia, angular impulses & bearing friction.",
            .vi: "Mô men quán tính chuẩn xác, xung lực góc & mô hình ma sát vòng bi."
        ],
        .surfaceMidAirTitle: [
            .en: "Surface & Mid-Air Modes",
            .vi: "Mặt phẳng & Lơ lửng không gian"
        ],
        .surfaceMidAirSubtitle: [
            .en: "Anchor on real tables or suspend floating in space.",
            .vi: "Gắn cố định trên bàn thực hoặc thả lơ lửng tự do trong phòng."
        ],
        .swipeInteractionTitle: [
            .en: "Realistic Swipe Interaction",
            .vi: "Tương tác vuốt chân thực"
        ],
        .swipeInteractionSubtitle: [
            .en: "Calculates torque from finger speed and distance from center.",
            .vi: "Mô men quay tính từ vận tốc ngón tay và cánh tay đòn tiếp xúc."
        ],
        .swipeToSpinPrompt: [
            .en: "Swipe spinner to spin • Drag background to orbit 3D",
            .vi: "Vuốt con quay để quay • Kéo nền xoay 3D"
        ],
        .tapToSwitchModel: [
            .en: "Tap to switch 3D model",
            .vi: "Nhấn để đổi con quay 3D"
        ],
        
        // Modes
        .modeSurface: [
            .en: "Surface",
            .vi: "Mặt phẳng"
        ],
        .modeFloating: [
            .en: "Floating",
            .vi: "Lơ lửng"
        ],
        .modeSurfaceDesc: [
            .en: "Place on a detected horizontal surface such as a table or desk.",
            .vi: "Đặt trên mặt phẳng ngang đã nhận diện như bàn làm việc hoặc sàn nhà."
        ],
        .modeFloatingDesc: [
            .en: "Suspend the spinner mid-air in your physical space.",
            .vi: "Thả spinner lơ lửng giữa không gian thực tế phía trước camera."
        ],
        
        // Placement & Actions
        .placeOnSurface: [
            .en: "Place on Surface",
            .vi: "Đặt lên mặt bàn"
        ],
        .placeInAir: [
            .en: "Place in Air",
            .vi: "Đặt lơ lửng"
        ],
        .resetPosition: [
            .en: "Reset Position",
            .vi: "Đặt lại vị trí"
        ],
        .scanningEnvironment: [
            .en: "Scanning environment...",
            .vi: "Đang quét môi trường..."
        ],
        .pointAtSurface: [
            .en: "Point camera at a desk or floor",
            .vi: "Hướng camera vào mặt bàn hoặc sàn nhà"
        ],
        .surfaceDetectedReady: [
            .en: "Surface detected. Ready to place.",
            .vi: "Đã tìm thấy mặt phẳng. Sẵn sàng đặt con quay."
        ],
        .readyPlaceMidAir: [
            .en: "Position ready. Tap Place in Air.",
            .vi: "Đã sẵn sàng. Chạm để thả lơ lửng."
        ],
        .trackingUnavailable: [
            .en: "AR tracking unavailable",
            .vi: "Theo dõi AR không khả dụng"
        ],
        .trackingInterrupted: [
            .en: "Tracking interrupted",
            .vi: "Theo dõi AR bị gián đoạn"
        ],
        .excessiveMotion: [
            .en: "Excessive motion. Slow down.",
            .vi: "Di chuyển quá nhanh. Hãy lia chậm lại."
        ],
        .insufficientFeatures: [
            .en: "Point camera at a textured surface",
            .vi: "Hãy hướng camera vào nơi có vân bề mặt rõ hơn"
        ],
        .swipeWingsHint: [
            .en: "Swipe across spinner wings to spin",
            .vi: "Vuốt ngang cánh con quay để tạo lực xoay"
        ],
        
        // HUD
        .rpm: [
            .en: "RPM",
            .vi: "RPM"
        ],
        .peak: [
            .en: "PEAK",
            .vi: "ĐỈNH"
        ],
        .revs: [
            .en: "REVS",
            .vi: "VÒNG"
        ],
        .speed: [
            .en: "SPEED",
            .vi: "TỐC ĐỘ"
        ],
        .clockwise: [
            .en: "CLOCKWISE",
            .vi: "THUẬN CHIỀU"
        ],
        .counterClockwise: [
            .en: "COUNTER-CLOCKWISE",
            .vi: "NGƯỢC CHIỀU"
        ],
        .idle: [
            .en: "IDLE",
            .vi: "DỪNG"
        ],
        .stop: [
            .en: "STOP",
            .vi: "DỪNG"
        ],
        
        // Size Control
        .spinnerSize: [
            .en: "Spinner Size",
            .vi: "Kích thước Spinner"
        ],
        .diameter: [
            .en: "Diameter",
            .vi: "Đường kính"
        ],
        .resetSize: [
            .en: "Reset (7.6 cm)",
            .vi: "Đặt lại (7.6 cm)"
        ],
        .cmUnit: [
            .en: "cm",
            .vi: "cm"
        ],
        .giantSpinner: [
            .en: "Giant Spinner",
            .vi: "Con quay khổng lồ"
        ],
        .giantSpinnerSubtitle: [
            .en: "Scale up to 15m for monumental AR scale",
            .vi: "Kéo kích thước theo mét, tối đa 15m"
        ],
        .meterUnit: [
            .en: "m",
            .vi: "m"
        ],
        .resetSizeGiant: [
            .en: "Reset (3.0 m)",
            .vi: "Đặt lại (3.0 m)"
        ],
        .placementDistance: [
            .en: "Distance",
            .vi: "Khoảng cách"
        ],
        .autoDistance: [
            .en: "Auto Distance",
            .vi: "Cự ly tối ưu"
        ],
        .pushAwayHint: [
            .en: "Push further away to view giant spinner",
            .vi: "Đẩy ra xa để ngắm trọn con quay khổng lồ"
        ],
        
        // Flashlight
        .flashlight: [
            .en: "Flashlight",
            .vi: "Đèn flash"
        ],
        .flashlightOn: [
            .en: "Turn On Flashlight",
            .vi: "Bật đèn flash"
        ],
        .flashlightOff: [
            .en: "Turn Off Flashlight",
            .vi: "Tắt đèn flash"
        ],
        
        // Physics Settings
        .physicsTitle: [
            .en: "Physics & Bearing Tuning",
            .vi: "Cấu hình Vật lý & Vòng bi"
        ],
        .presets: [
            .en: "Spinner Presets",
            .vi: "Bộ cấu hình sẵn"
        ],
        .presetStandard: [
            .en: "Standard (Ceramic Hybrid)",
            .vi: "Tiêu chuẩn (Gốm lai Ceramic)"
        ],
        .presetHighSpeed: [
            .en: "High Speed (Full Ceramic)",
            .vi: "Tốc độ cao (Full Ceramic)"
        ],
        .presetHeavyBrass: [
            .en: "Heavy Solid Brass",
            .vi: "Đồng khối nặng (Solid Brass)"
        ],
        .frictionModel: [
            .en: "Friction Simulation Model",
            .vi: "Mô hình mô phỏng ma sát"
        ],
        .frictionType: [
            .en: "Bearing Friction Type",
            .vi: "Loại ma sát vòng bi"
        ],
        .viscousDamping: [
            .en: "Air & Lubricant Viscous Damping",
            .vi: "Cản nhớt (Không khí & Dầu mỡ)"
        ],
        .coulombFriction: [
            .en: "Dry Coulomb Bearing Friction",
            .vi: "Ma sát khô Coulomb vòng bi"
        ],
        .massAndDimensions: [
            .en: "Mass & Inertia",
            .vi: "Khối lượng & Quán tính"
        ],
        .totalMass: [
            .en: "Spinner Total Mass",
            .vi: "Tổng khối lượng spinner"
        ],
        .momentOfInertia: [
            .en: "Moment of Inertia (I)",
            .vi: "Mô men quán tính (I)"
        ],
        .maxSafeSpeed: [
            .en: "Max Safe Angular Velocity",
            .vi: "Tốc độ góc an toàn tối đa"
        ],
        .cancel: [
            .en: "Cancel",
            .vi: "Hủy"
        ],
        .apply: [
            .en: "Apply",
            .vi: "Áp dụng"
        ],
        .frictionCombined: [
            .en: "Combined (Coulomb + Viscous)",
            .vi: "Kết hợp (Coulomb + Nhớt)"
        ],
        .frictionCoulomb: [
            .en: "Coulomb Only (Dry Bearing)",
            .vi: "Chỉ Coulomb (Vòng bi khô)"
        ],
        .frictionViscous: [
            .en: "Viscous Only (Fluid Drag)",
            .vi: "Chỉ Nhớt (Lực cản môi trường)"
        ],
        .frictionNone: [
            .en: "None (Zero Friction)",
            .vi: "Không ma sát (Lý tưởng)"
        ],
        
        // Permission
        .cameraAccessRequired: [
            .en: "Camera Access Required",
            .vi: "Yêu cầu quyền Camera"
        ],
        .cameraPermissionDesc: [
            .en: "ARSpinner needs camera permission to detect real-world surfaces and render the 3D fidget spinner in Augmented Reality.",
            .vi: "ARSpinner cần quyền camera để nhận diện mặt phẳng thực tế và hiển thị con quay 3D trong không gian Thực tế tăng cường."
        ],
        .openSettings: [
            .en: "Open Settings",
            .vi: "Mở Cài đặt"
        ],
        .checkAgain: [
            .en: "Check Again",
            .vi: "Kiểm tra lại"
        ],
        
        // Language
        .language: [
            .en: "Language",
            .vi: "Ngôn ngữ"
        ],
        
        // Spin Modes & Continuous Spin
        .spinModeNatural: [
            .en: "Natural Spin",
            .vi: "Quán tính"
        ],
        .spinModeContinuous: [
            .en: "Continuous Spin",
            .vi: "Tăng tốc liên tục"
        ],
        .continuousSpinInstruction: [
            .en: "Max 2,000 RPM • Swipe repeatedly in same direction to accelerate",
            .vi: "Tối đa 2.000 RPM • Vuốt nhiều lần cùng chiều để tăng tốc"
        ],
        
        // Audio & Sounds
        .soundEffects: [
            .en: "Bearing Sound Effects",
            .vi: "Âm thanh vòng bi"
        ],
        .soundVolume: [
            .en: "Sound Volume",
            .vi: "Âm lượng âm thanh"
        ],
        .audioSectionHeader: [
            .en: "Bearing Acoustics",
            .vi: "Âm thanh vòng bi"
        ],
        
        // Spinner State Strings
        .stateSpinning: [
            .en: "Spinning",
            .vi: "Đang quay"
        ],
        .stateAccelerating: [
            .en: "Accelerating",
            .vi: "Đang tăng tốc"
        ],
        .stateDecelerating: [
            .en: "Decelerating",
            .vi: "Đang giảm tốc"
        ],
        .stateStopped: [
            .en: "Stopped",
            .vi: "Đã dừng"
        ],
        
        // Model Selection & Library
        .chooseSpinner: [
            .en: "Choose Spinner",
            .vi: "Chọn Con Quay"
        ],
        .modelSelectionSubtitle: [
            .en: "Select a 3D model from the library",
            .vi: "Chọn mô hình 3D từ thư viện"
        ],
        .selected: [
            .en: "Selected",
            .vi: "Đang chọn"
        ],
        .loadingModel: [
            .en: "Loading model...",
            .vi: "Đang tải mô hình..."
        ],
        .unableToLoadModel: [
            .en: "Unable to load model",
            .vi: "Không thể tải mô hình"
        ],
        .noAvailableModels: [
            .en: "No models found in library",
            .vi: "Không có mô hình trong thư viện"
        ],
        .modelChangedSuccess: [
            .en: "Spinner model updated",
            .vi: "Đã cập nhật mô hình con quay"
        ]
    ]
}

/// SwiftUI View extension for localized string access.
extension View {
    func localizedText(_ key: LocKey) -> String {
        LocalizationService.shared.tr(key)
    }
}

