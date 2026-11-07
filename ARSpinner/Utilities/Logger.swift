import Foundation
import os.log

/// Unified logging subsystem for ARSpinner
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.arspinner.ARSpinner"
    
    static let general = Logger(subsystem: subsystem, category: "General")
    static let ar = Logger(subsystem: subsystem, category: "AR")
    static let physics = Logger(subsystem: subsystem, category: "Physics")
    static let interaction = Logger(subsystem: subsystem, category: "Interaction")
    static let scene = Logger(subsystem: subsystem, category: "Scene")
}

