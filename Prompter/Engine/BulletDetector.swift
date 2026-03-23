import Foundation

struct BulletItem: Identifiable {
    let id: Int
    let text: String          // the bullet text (without the marker)
    let original: String      // original line including marker
    let keywords: [String]    // significant words for keyword matching
}

enum BulletDetector {
    /// Characters/patterns that indicate a bullet point at the start of a line
    private static let bulletPatterns: [String] = ["- ", "* ", "• ", "→ ", "# "]

    /// Check if text is formatted as bullet points.
    /// Returns true if every non-empty line starts with a bullet marker.
    static func isBulletFormat(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return false }

        return lines.allSatisfy { line in
            isBulletLine(line)
        }
    }

    /// Check if a single line starts with a bullet marker
    static func isBulletLine(_ line: String) -> Bool {
        // Check standard markers
        for pattern in bulletPatterns {
            if line.hasPrefix(pattern) { return true }
        }
        // Check numbered: "1. ", "2. ", "12. " etc.
        if let dotIndex = line.firstIndex(of: ".") {
            let prefix = line[line.startIndex..<dotIndex]
            if !prefix.isEmpty && prefix.allSatisfy({ $0.isNumber }) {
                let afterDot = line.index(after: dotIndex)
                if afterDot < line.endIndex && line[afterDot] == " " {
                    return true
                }
            }
        }
        return false
    }

    /// Parse bullet-formatted text into an array of BulletItems
    static func parseBullets(_ text: String) -> [BulletItem] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var items: [BulletItem] = []

        for (index, line) in lines.enumerated() {
            let cleaned = stripBulletMarker(line)
            guard !cleaned.isEmpty else { continue }

            items.append(BulletItem(
                id: index,
                text: cleaned,
                original: line,
                keywords: extractKeywords(from: cleaned)
            ))
        }

        return items
    }

    /// Parse plain text (script) into bullet items from extracted bullet strings
    static func parseBulletsFromExtracted(_ bulletTexts: [String]) -> [BulletItem] {
        bulletTexts.enumerated().map { index, text in
            BulletItem(
                id: index,
                text: text,
                original: "• \(text)",
                keywords: extractKeywords(from: text)
            )
        }
    }

    /// Remove the bullet marker from the start of a line
    static func stripBulletMarker(_ line: String) -> String {
        // Standard markers
        for pattern in bulletPatterns {
            if line.hasPrefix(pattern) {
                return String(line.dropFirst(pattern.count))
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        // Numbered
        if let dotIndex = line.firstIndex(of: ".") {
            let prefix = line[line.startIndex..<dotIndex]
            if !prefix.isEmpty && prefix.allSatisfy({ $0.isNumber }) {
                let afterDot = line.index(after: dotIndex)
                if afterDot < line.endIndex && line[afterDot] == " " {
                    return String(line[line.index(after: afterDot)...])
                        .trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return line
    }

    /// Extract significant keywords from text (skip stop words, prefer longer words)
    static func extractKeywords(from text: String) -> [String] {
        let stopWords: Set<String> = [
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to",
            "for", "of", "with", "by", "from", "is", "are", "was", "were",
            "be", "been", "being", "have", "has", "had", "do", "does", "did",
            "will", "would", "could", "should", "may", "might", "can", "shall",
            "it", "its", "this", "that", "these", "those", "i", "you", "he",
            "she", "we", "they", "my", "your", "his", "her", "our", "their",
            "me", "him", "us", "them", "what", "which", "who", "whom",
            "not", "no", "so", "if", "then", "than", "too", "very",
            "just", "about", "up", "out", "how", "all", "each", "every",
            "both", "few", "more", "most", "other", "some", "such", "only"
        ]

        let words = text.normalized.components(separatedBy: " ")
            .filter { !$0.isEmpty && !stopWords.contains($0) && $0.count > 2 }

        // Return up to 5 keywords, preferring longer/rarer words
        return Array(words.sorted { $0.count > $1.count }.prefix(5))
    }
}
