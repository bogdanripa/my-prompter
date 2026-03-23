import Foundation

extension Int {
    /// Format seconds as "M:SS"
    var timeFormatted: String {
        let m = self / 60
        let s = self % 60
        return String(format: "%d:%02d", m, s)
    }
}
