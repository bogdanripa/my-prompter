import Foundation

struct TokenizedWord: Identifiable {
    let id: Int          // position in word array (0, 1, 2, ...)
    let text: String     // normalized lowercase word for matching
    let original: String // original text as typed
    let range: Range<String.Index> // range in original body text
    let startsNewLine: Bool // true if a newline appeared before this word
}

final class WordTokenizer {
    /// Tokenize a prompt body into an array of words with their positions
    func tokenize(_ text: String) -> [TokenizedWord] {
        var words: [TokenizedWord] = []
        var index = 0

        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil

        var isFirstWord = true

        while !scanner.isAtEnd {
            // Scan whitespace/newlines between words
            let beforeSkip = scanner.currentIndex
            let skipped = scanner.scanCharacters(from: .whitespacesAndNewlines)
            let hasNewline: Bool
            if let skipped {
                hasNewline = skipped.contains(where: { $0.isNewline })
            } else {
                hasNewline = false
            }

            let startIndex = scanner.currentIndex

            // Scan a word (non-whitespace characters)
            if let word = scanner.scanUpToCharacters(from: .whitespacesAndNewlines) {
                let endIndex = scanner.currentIndex
                let range = startIndex..<endIndex

                // Normalize: strip punctuation, lowercase
                let normalized = word.normalized.trimmingCharacters(in: .whitespaces)
                guard !normalized.isEmpty else { continue }

                words.append(TokenizedWord(
                    id: index,
                    text: normalized,
                    original: word,
                    range: range,
                    startsNewLine: hasNewline && !isFirstWord
                ))
                index += 1
                isFirstWord = false
            }
        }

        return words
    }

    /// Extract unique vocabulary words for SFSpeechRecognizer contextualStrings
    func uniqueVocabulary(from words: [TokenizedWord], maxCount: Int = 100) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []

        for word in words {
            if !seen.contains(word.text) && word.text.count > 3 {
                seen.insert(word.text)
                unique.append(word.original)
            }
        }

        // Prioritize longer/uncommon words (they benefit most from contextual hints)
        return Array(unique.sorted { $0.count > $1.count }.prefix(maxCount))
    }
}
