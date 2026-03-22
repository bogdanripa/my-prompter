import SwiftData
import Foundation

@Model
final class Prompt {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var targetSeconds: Int = 0  // 0 = no target
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
