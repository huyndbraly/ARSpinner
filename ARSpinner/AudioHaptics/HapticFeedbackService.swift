import Foundation
import UIKit

/// Manages tactile haptic feedback for user interactions and rotational events.
@MainActor
final class HapticFeedbackService {
    
    // MARK: - Generators
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    private var isEnabled: Bool = true
    
    // MARK: - Lifecycle
    
    init() {
        prepare()
    }
    
    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
    }
    
    // MARK: - Interactions
    
    /// Triggered when the user's finger first contacts the spinner.
    func onTouchContact() {
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.7)
    }
    
    /// Triggered when a swipe impulse is applied to spin the spinner.
    func onSwipeFlick(speed: Float) {
        guard isEnabled else { return }
        let intensity = min(1.0, max(0.3, CGFloat(speed / 80.0)))
        if speed > 60.0 {
            heavyImpact.impactOccurred(intensity: intensity)
        } else {
            mediumImpact.impactOccurred(intensity: intensity)
        }
    }
    
    /// Triggered periodically as the spinner wings rotate.
    func onRotationalTick(speed: Float) {
        guard isEnabled else { return }
        // Subtle tick whose intensity scales with speed
        let intensity = min(0.6, max(0.15, CGFloat(speed / 120.0)))
        lightImpact.impactOccurred(intensity: intensity)
    }
    
    /// Triggered on placement or UI actions.
    func onSelection() {
        guard isEnabled else { return }
        selectionFeedback.selectionChanged()
    }
    
    func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
    }
}

