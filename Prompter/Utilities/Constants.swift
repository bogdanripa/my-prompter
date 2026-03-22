import Foundation

enum AppConstants {
    // Matching engine
    static let defaultWindowSize = 20
    static let defaultLookBackSize = 3
    static let defaultMatchThreshold = 0.5
    static let defaultHighConfidenceThreshold = 0.8
    static let defaultRecognizedWindowSize = 4
    static let lostModeConsecutiveMisses = 8

    // Audio
    static let recognitionRestartInterval: TimeInterval = 50

    // UI defaults
    static let defaultFontSize: Double = 36
    static let minFontSize: Double = 20
    static let maxFontSize: Double = 60
    static let defaultSpeakingWPM = 150
}
