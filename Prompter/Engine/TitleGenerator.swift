import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum TitleGenerator {
    /// Generate a short title from prompt content. LLM on iOS 26+, heuristic fallback.
    static func generate(from text: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled Prompt" }

        if #available(iOS 26, *) {
            if let llmTitle = await generateWithLLM(from: trimmed) {
                return llmTitle
            }
        }
        return generateHeuristic(from: trimmed)
    }

    /// Heuristic: first sentence or first line, truncated
    private static func generateHeuristic(from text: String) -> String {
        // For bullets, combine first two bullet texts
        if BulletDetector.isBulletFormat(text) {
            let bullets = BulletDetector.parseBullets(text)
            let first = bullets.prefix(2).map { $0.text }
            let combined = first.joined(separator: ", ")
            return String(combined.prefix(40))
        }

        // For scripts, take first sentence
        let firstLine = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? text

        // Split at sentence boundary
        if let dotRange = firstLine.range(of: ".", options: [], range: firstLine.startIndex..<firstLine.index(firstLine.startIndex, offsetBy: min(60, firstLine.count))) {
            return String(firstLine[firstLine.startIndex..<dotRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
        }

        // Just truncate
        let words = firstLine.components(separatedBy: " ")
        return words.prefix(6).joined(separator: " ")
    }

    @available(iOS 26, *)
    private static func generateWithLLM(from text: String) async -> String? {
        #if canImport(FoundationModels)
        do {
            let session = LanguageModelSession()
            let snippet = String(text.prefix(500))
            let prompt = """
                Generate a short title (3-6 words) for this \(BulletDetector.isBulletFormat(text) ? "talk outline" : "speech"). \
                Return only the title, nothing else. No quotes, no punctuation at the end.

                Text:
                \(snippet)
                """
            let response = try await session.respond(to: prompt)
            let title = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title.count < 60 else { return nil }
            return title
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
