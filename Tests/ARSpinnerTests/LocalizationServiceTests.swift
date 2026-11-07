import XCTest
@testable import ARSpinner

@MainActor
final class LocalizationServiceTests: XCTestCase {
    
    func testAllKeysHaveTranslationsInEnglishAndVietnamese() {
        let service = LocalizationService.shared
        
        for key in LocKey.allCases {
            service.setLanguage(.en)
            let enString = service.tr(key)
            XCTAssertFalse(enString.isEmpty, "Missing English translation for \(key.rawValue)")
            
            service.setLanguage(.vi)
            let viString = service.tr(key)
            XCTAssertFalse(viString.isEmpty, "Missing Vietnamese translation for \(key.rawValue)")
        }
    }
    
    func testLanguageToggle() {
        let service = LocalizationService.shared
        service.setLanguage(.en)
        XCTAssertEqual(service.currentLanguage, .en)
        
        service.toggleLanguage()
        XCTAssertEqual(service.currentLanguage, .vi)
        
        service.toggleLanguage()
        XCTAssertEqual(service.currentLanguage, .en)
    }
    
    func testVietnameseTranslationAccuracy() {
        let service = LocalizationService.shared
        service.setLanguage(.vi)
        
        XCTAssertEqual(service.tr(.modeSurface), "Mặt phẳng")
        XCTAssertEqual(service.tr(.modeFloating), "Lơ lửng")
        XCTAssertEqual(service.tr(.placeOnSurface), "Đặt lên mặt bàn")
        XCTAssertEqual(service.tr(.placeInAir), "Đặt lơ lửng")
        XCTAssertEqual(service.tr(.resetPosition), "Đặt lại vị trí")
        XCTAssertEqual(service.tr(.spinnerSize), "Kích thước Spinner")
        XCTAssertEqual(service.tr(.spinModeNatural), "Quán tính")
        XCTAssertEqual(service.tr(.spinModeContinuous), "Tăng tốc liên tục")
        XCTAssertTrue(service.tr(.continuousSpinInstruction).contains("2.000 RPM"))
        XCTAssertEqual(service.tr(.chooseSpinner), "Chọn Con Quay")
        XCTAssertEqual(service.tr(.selected), "Đang chọn")
        XCTAssertEqual(service.tr(.giantSpinner), "Con quay khổng lồ")
        
        service.setLanguage(.en)
        XCTAssertTrue(service.tr(.continuousSpinInstruction).contains("2,000 RPM"))
        XCTAssertEqual(service.tr(.chooseSpinner), "Choose Spinner")
        XCTAssertEqual(service.tr(.selected), "Selected")
        XCTAssertEqual(service.tr(.giantSpinner), "Giant Spinner")
        
        XCTAssertEqual(service.tr(.soundEffects), "Bearing Sound Effects")
    }
}

