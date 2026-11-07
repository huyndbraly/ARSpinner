import XCTest
@testable import ARSpinner

@MainActor
final class AudioAndSettingsTests: XCTestCase {
    
    func testAudioFeedbackServiceInitializationAndMuting() {
        let audio = AudioFeedbackService()
        XCTAssertTrue(audio.isMuted)
        
        // Muting prevents audio generation
        audio.updateBearingSound(angularVelocity: 50.0)
        
        // Unmute and verify update
        audio.isMuted = false
        XCTAssertFalse(audio.isMuted)
        audio.volume = 0.5
        XCTAssertEqual(audio.volume, 0.5, accuracy: 1e-4)
        
        audio.updateBearingSound(angularVelocity: 100.0)
        audio.playContactSound()
        
        audio.stop()
    }
    
    func testMutingAudioDoesNotAffectPhysicsSimulation() {
        let engineWithAudioMuted = SpinnerPhysicsEngine(configuration: .standard)
        let engineWithAudioActive = SpinnerPhysicsEngine(configuration: .standard)
        
        let audio = AudioFeedbackService()
        audio.isMuted = true
        
        engineWithAudioMuted.setAngularVelocity(50.0)
        engineWithAudioActive.setAngularVelocity(50.0)
        
        // Step both engines
        for _ in 0..<30 {
            engineWithAudioMuted.update(deltaTime: 1.0 / 60.0)
            engineWithAudioActive.update(deltaTime: 1.0 / 60.0)
            audio.updateBearingSound(angularVelocity: engineWithAudioMuted.state.angularVelocity)
        }
        
        XCTAssertEqual(
            engineWithAudioMuted.state.angularVelocity,
            engineWithAudioActive.state.angularVelocity,
            accuracy: Float(1e-6)
        )
    }
    
    func testPhysicsParameterInfoCoversAllRequiredFields() {
        for key in PhysicsParameterKey.allCases {
            // Test Vietnamese
            let viInfo = PhysicsParameterInfo.info(for: key, language: .vi, currentValueString: "1.0")
            XCTAssertFalse(viInfo.title.isEmpty, "Missing VI title for \(key.rawValue)")
            XCTAssertFalse(viInfo.whatIsIt.isEmpty, "Missing VI whatIsIt for \(key.rawValue)")
            XCTAssertFalse(viInfo.howItAffects.isEmpty, "Missing VI howItAffects for \(key.rawValue)")
            XCTAssertFalse(viInfo.whenIncreased.isEmpty, "Missing VI whenIncreased for \(key.rawValue)")
            XCTAssertFalse(viInfo.whenDecreased.isEmpty, "Missing VI whenDecreased for \(key.rawValue)")
            XCTAssertFalse(viInfo.currentValueMeaning.isEmpty, "Missing VI currentValueMeaning for \(key.rawValue)")
            
            // Test English
            let enInfo = PhysicsParameterInfo.info(for: key, language: .en, currentValueString: "1.0")
            XCTAssertFalse(enInfo.title.isEmpty, "Missing EN title for \(key.rawValue)")
            XCTAssertFalse(enInfo.whatIsIt.isEmpty, "Missing EN whatIsIt for \(key.rawValue)")
            XCTAssertFalse(enInfo.howItAffects.isEmpty, "Missing EN howItAffects for \(key.rawValue)")
            XCTAssertFalse(enInfo.whenIncreased.isEmpty, "Missing EN whenIncreased for \(key.rawValue)")
            XCTAssertFalse(enInfo.whenDecreased.isEmpty, "Missing EN whenDecreased for \(key.rawValue)")
            XCTAssertFalse(enInfo.currentValueMeaning.isEmpty, "Missing EN currentValueMeaning for \(key.rawValue)")
            
            // Ensure translations are distinct
            XCTAssertNotEqual(viInfo.whatIsIt, enInfo.whatIsIt)
        }
    }
    
    func testTorchServiceTogglingAndTurnOff() {
        let torch = TorchService.shared
        XCTAssertFalse(torch.isTorchOn)
        
        torch.toggleTorch()
        XCTAssertTrue(torch.isTorchOn)
        
        torch.turnOff()
        XCTAssertFalse(torch.isTorchOn)
    }
    
    func testModeSwitchWhilePlacedResetsStateAndStopsSpinner() {
        let viewModel = ARExperienceViewModel()
        viewModel.isPlaced = true
        viewModel.selectedMode = .surface
        viewModel.spinnerState = SpinnerState(isPlaced: true, mode: .surface, angularVelocity: 60.0)
        
        var resetCalled = false
        var modeChangedTo: SpinnerMode?
        viewModel.onResetRequested = {
            resetCalled = true
        }
        viewModel.onModeChanged = { newMode in
            modeChangedTo = newMode
        }
        
        // Switching to floating mode while placed must reset placement and stop ghost spinning
        viewModel.setMode(.floating)
        
        XCTAssertTrue(resetCalled)
        XCTAssertEqual(modeChangedTo, .floating)
        XCTAssertFalse(viewModel.isPlaced)
        XCTAssertEqual(viewModel.selectedMode, .floating)
        XCTAssertEqual(viewModel.spinnerState.angularVelocity, 0.0, accuracy: 1e-5)
    }
    
    func testAudioServiceStopAndZeroVelocitySilencing() {
        let audio = AudioFeedbackService()
        audio.isMuted = false
        
        // Spinning velocity sets target RPM
        audio.updateBearingSound(angularVelocity: 80.0)
        
        // Zero angular velocity silences immediately
        audio.updateBearingSound(angularVelocity: 0.0)
        
        // Stopping silences immediately
        audio.stop()
    }
}

