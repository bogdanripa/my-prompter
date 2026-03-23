import Foundation
import Combine

@MainActor
final class BulletMatchingEngine: ObservableObject {
    let bullets: [BulletItem]

    @Published private(set) var currentBulletIndex: Int = 0
    @Published private(set) var completedBullets: Set<Int> = []

    private let keywordThreshold: Int = 2  // keywords needed to consider a bullet "covered"
    private var recognizedKeywordsForCurrent: Set<String> = []
    private var lastRecognizedSuffix: String = ""

    // Confirmation to avoid premature advances
    private var advanceConfirmations: Int = 0
    private let confirmationsNeeded: Int = 2

    init(bullets: [BulletItem]) {
        self.bullets = bullets
    }

    /// Process partial recognition results and check if current bullet is covered
    func processPartialResult(_ recognizedWords: [String]) {
        guard !recognizedWords.isEmpty, currentBulletIndex < bullets.count else { return }

        // Deduplication
        let recent = Array(recognizedWords.suffix(8)).map { $0.normalized }
        let suffix = recent.joined(separator: " ")
        guard suffix != lastRecognizedSuffix else { return }
        lastRecognizedSuffix = suffix

        let currentBullet = bullets[currentBulletIndex]

        // Check how many keywords from the current bullet appear in recent speech
        let matchedKeywords = currentBullet.keywords.filter { keyword in
            recent.contains { word in
                FuzzyMatcher.normalizedSimilarity(word, keyword) > 0.7
            }
        }

        // Track matched keywords across multiple partial results
        for kw in matchedKeywords {
            recognizedKeywordsForCurrent.insert(kw)
        }

        let threshold = min(keywordThreshold, max(1, currentBullet.keywords.count - 1))

        if recognizedKeywordsForCurrent.count >= threshold {
            advanceConfirmations += 1
            if advanceConfirmations >= confirmationsNeeded {
                advanceToNext()
            }
        }

        // Also check if speech matches the NEXT bullet (speaker already moved on)
        if currentBulletIndex + 1 < bullets.count {
            let nextBullet = bullets[currentBulletIndex + 1]
            let nextMatched = nextBullet.keywords.filter { keyword in
                recent.contains { word in
                    FuzzyMatcher.normalizedSimilarity(word, keyword) > 0.7
                }
            }
            let nextThreshold = min(keywordThreshold, max(1, nextBullet.keywords.count - 1))
            if nextMatched.count >= nextThreshold {
                // Speaker skipped ahead — advance current and move to next
                advanceToNext()
            }
        }
    }

    /// Advance to the next bullet
    private func advanceToNext() {
        completedBullets.insert(currentBulletIndex)
        if currentBulletIndex < bullets.count - 1 {
            currentBulletIndex += 1
        }
        recognizedKeywordsForCurrent = []
        advanceConfirmations = 0
    }

    /// Mark the last bullet as complete (called when finishing)
    func finishAll() {
        completedBullets.insert(currentBulletIndex)
    }

    /// Reset to beginning
    func reset() {
        currentBulletIndex = 0
        completedBullets = []
        recognizedKeywordsForCurrent = []
        advanceConfirmations = 0
        lastRecognizedSuffix = ""
    }

    /// Jump to a specific bullet
    func jumpTo(index: Int) {
        currentBulletIndex = max(0, min(index, bullets.count - 1))
        recognizedKeywordsForCurrent = []
        advanceConfirmations = 0
    }

    var progress: Double {
        guard bullets.count > 0 else { return 0 }
        return Double(currentBulletIndex) / Double(bullets.count)
    }

    var isAtEnd: Bool {
        currentBulletIndex >= bullets.count - 1 && completedBullets.contains(currentBulletIndex)
    }
}
