import SwiftData
import Foundation

@Model
final class Prompt {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var targetSeconds: Int = 0  // 0 = no target
    var extractedBulletsJSON: String = ""  // JSON array of strings, derived from script via LLM
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(title: String = "", body: String = "", targetSeconds: Int = 0) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.targetSeconds = targetSeconds
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var hasTarget: Bool { targetSeconds > 0 }

    var isBulletFormat: Bool { BulletDetector.isBulletFormat(body) }

    var hasExtractedBullets: Bool { !extractedBulletsJSON.isEmpty }

    var extractedBullets: [String] {
        get {
            guard !extractedBulletsJSON.isEmpty,
                  let data = extractedBulletsJSON.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return arr
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                extractedBulletsJSON = str
            }
        }
    }

    var displayTitle: String {
        if !title.isEmpty { return title }
        let firstLine = body.components(separatedBy: .newlines).first ?? ""
        let trimmed = String(firstLine.prefix(50))
        return trimmed.isEmpty ? "Untitled Prompt" : trimmed
    }

    var wordCount: Int {
        body.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
