import Foundation

/// AR placement modes supported by ARSpinner.
enum SpinnerMode: String, CaseIterable, Identifiable, Sendable {
    /// Detects a horizontal surface (table, desk, floor) and locks the spinner to it.
    case surface
    /// Spawns the spinner floating in mid-air in front of the camera, locked in world coordinates.
    case floating
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .surface:
            return "Surface"
        case .floating:
            return "Floating"
        }
    }
    
    var systemImage: String {
        switch self {
        case .surface:
            return "table.furniture"
        case .floating:
            return "cube.transparent"
        }
    }
    
    var description: String {
        switch self {
        case .surface:
            return "Place on a detected horizontal surface such as a table or desk."
        case .floating:
            return "Suspend the spinner mid-air in your physical space."
        }
    }
}

