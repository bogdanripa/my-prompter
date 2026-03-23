import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum KeyPointExtractor {
    /// Extract key points from a script. Uses on-device LLM on iOS 26+, falls back to heuristic.
    static func extract(from text: String) async -> [String] {
        let raw: [String]
        if #available(iOS 26, *) {
            raw = await extractWithLLM(from: text) ?? extractHeuristic(from: text)
        } else {
            raw = extractHeuristic(from: text)
        }
        // Strip any bullet markers from all results
        return raw
            .map { BulletDetector.stripBulletMarker($0) }
            .filter { !$0.isEmpty }
    }

    /// Heuristic: split by paragraphs, take the first sentence or key phrase from each
    private static func extractHeuristic(from text: String) -> [String] {
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // If only one paragraph, split by sentences
        if paragraphs.count <= 1 {
            return extractBySentences(from: text)
        }

        return paragraphs.compactMap { paragraph in
            // Take the first sentence of each paragraph
            let firstSentence = paragraph
                .components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let sentence = firstSentence, !sentence.isEmpty else { return nil }

            // Truncate long sentences
            if sentence.count > 80 {
                let words = sentence.components(separatedBy: " ")
                return words.prefix(10).joined(separator: " ") + "..."
            }
            return sentence
        }
    }

    /// Split by sentences and group into key points
    private static func extractBySentences(from text: String) -> [String] {
        let sentences = text
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 10 }

        // Take every 2-3 sentences as a key point, cap at ~8 points
        let stride = max(1, sentences.count / 8)
        var points: [String] = []
        for i in Swift.stride(from: 0, to: sentences.count, by: stride) {
            let sentence = sentences[i]
            if sentence.count > 80 {
                let words = sentence.components(separatedBy: " ")
                points.append(words.prefix(10).joined(separator: " ") + "...")
            } else {
                points.append(sentence)
            }
        }
        return Array(points.prefix(10))
    }

    /// Extract using on-device LLM (iOS 26+)
    @available(iOS 26, *)
    private static func extractWithLLM(from text: String) async -> [String]? {
        #if canImport(FoundationModels)
        do {
            let session = LanguageModelSession()
            let prompt = """
                Extract 5-8 key talking points from this speech or script. \
                Return only the bullet points, one per line, starting each with "- ". \
                Keep each point short (under 10 words). \
                Do not add any other text.

                Script:
                \(text)
                """
            let response = try await session.respond(to: prompt)
            let lines = response.content
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("- ") || $0.hasPrefix("* ") || $0.hasPrefix("• ") }
                .map { BulletDetector.stripBulletMarker($0) }
                .filter { !$0.isEmpty }

            return lines.isEmpty ? nil : lines
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
