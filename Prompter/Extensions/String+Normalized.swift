import Foundation

extension String {
    /// Lowercased with punctuation stripped and whitespace collapsed
    var normalized: String {
        let stripped = self.unicodeScalars.filter { scalar in
            CharacterSet.letters.contains(scalar) ||
            CharacterSet.decimalDigits.contains(scalar) ||
            CharacterSet.whitespaces.contains(scalar) ||
            scalar == "'"
        }
        return String(stripped)
            .lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Split into normalized word array
    var normalizedWords: [String] {
        normalized.components(separatedBy: " ").filter { !$0.isEmpty }
    }
}
