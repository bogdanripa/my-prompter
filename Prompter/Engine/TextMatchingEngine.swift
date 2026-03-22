import Foundation
import Combine

@MainActor
final class TextMatchingEngine: ObservableObject {
    let words: [TokenizedWord]

    @Published private(set) var cursorIndex: Int = 0
    @Published private(set) var confidence: Double = 0.0

    // Matching parameters
    private let forwardWindowSize: Int = 80      // large look-ahead covers paragraph skips
    private let backwardWindowSize: Int = 5      // small look-behind
    private let matchThreshold: Double = 0.5
    private let jumpConfidence: Double = 0.65    // confidence needed to jump backward
    private let recognizedWindowSize: Int = 5    // use more words for better matching
    private let maxStepForward: Int = 80         // allow jumping a full paragraph in one step
    private let maxStepExpanded: Int = 200       // max step in expanded mode

    // Consecutive confirmation: require the same position N times before moving.
    // Small steps (1-3 words forward) need fewer confirmations.
    // Bigger jumps need more, to avoid false matches.
    private var candidateIndex: Int = 0
    private var candidateHits: Int = 0

    // Progressive search: expand on consecutive misses (for jumping backward or very far)
    private var consecutiveMisses: Int = 0
    private let fullSearchThreshold: Int = 8

    // Initial seek: search entire text until we find where the speaker starts
    private var hasFoundInitialPosition: Bool = false

    // Deduplication
    private var lastRecognizedSuffix: String = ""

    init(words: [TokenizedWord]) {
        self.words = words
    }

    /// Process partial recognition results and update cursor position
    func processPartialResult(_ recognizedWords: [String]) {
        guard !recognizedWords.isEmpty, !words.isEmpty else { return }

        // Better deduplication: compare actual content, not just count
        let recentWords = Array(recognizedWords.suffix(recognizedWindowSize))
            .map { $0.normalized }
        let suffix = recentWords.joined(separator: " ")
        guard suffix != lastRecognizedSuffix else { return }
        lastRecognizedSuffix = suffix

        // --- Progressive search strategy ---
        let searchResult: (absoluteIndex: Int, confidence: Double)?
        let currentMaxStep: Int

        if !hasFoundInitialPosition {
            // First match: search the entire text to find where the speaker starts
            searchResult = searchWindow(recentWords: recentWords, from: 0, to: words.count, useBias: false)
            currentMaxStep = words.count
        } else if consecutiveMisses >= fullSearchThreshold {
            // Lost: search entire text (handles jumping backward to earlier sections)
            searchResult = searchWindow(recentWords: recentWords, from: 0, to: words.count, useBias: false)
            currentMaxStep = words.count
        } else {
            let start = max(0, cursorIndex - backwardWindowSize)
            let end = min(words.count, cursorIndex + forwardWindowSize)
            searchResult = searchWindow(recentWords: recentWords, from: start, to: end, useBias: true)
            currentMaxStep = maxStepForward
        }

        guard let result = searchResult else {
            consecutiveMisses += 1
            return
        }

        let proposedCursor = result.absoluteIndex
        let conf = result.confidence

        // Clamp forward movement to maxStep (prevents wild jumps)
        let newCursor: Int
        if proposedCursor > cursorIndex {
            newCursor = min(proposedCursor, cursorIndex + currentMaxStep)
        } else {
            newCursor = proposedCursor
        }

        if !hasFoundInitialPosition && conf >= matchThreshold {
            // Initial seek: jump directly to wherever we matched
            if isNear(newCursor, candidateIndex) {
                candidateHits += 1
                candidateIndex = newCursor
            } else {
                candidateIndex = newCursor
                candidateHits = 1
            }

            // Require 3 confirmations before committing initial position
            if candidateHits >= 3 {
                cursorIndex = candidateIndex
                confidence = conf
                consecutiveMisses = 0
                candidateHits = 0
                hasFoundInitialPosition = true
            }
        } else if newCursor > cursorIndex && conf >= matchThreshold {
            // Forward movement: use confirmation to avoid jitter
            if isNear(newCursor, candidateIndex) {
                candidateHits += 1
                candidateIndex = newCursor
            } else {
                candidateIndex = newCursor
                candidateHits = 1
            }

            let needed = confirmationsNeeded(for: candidateIndex)
            if candidateHits >= needed {
                cursorIndex = candidateIndex
                confidence = conf
                consecutiveMisses = 0
                candidateHits = 0
            } else {
                // Not enough confirmations yet, but don't count as a miss
                consecutiveMisses = 0
            }
        } else if newCursor < cursorIndex && conf >= jumpConfidence {
            // Backward: require higher confidence, but also confirm
            if isNear(newCursor, candidateIndex) {
                candidateHits += 1
                candidateIndex = newCursor
            } else {
                candidateIndex = newCursor
                candidateHits = 1
            }

            let needed = confirmationsNeeded(for: candidateIndex)
            if candidateHits >= needed {
                cursorIndex = candidateIndex
                confidence = conf
                consecutiveMisses = 0
                candidateHits = 0
            }
        } else if newCursor == cursorIndex {
            // Staying at current position
            consecutiveMisses = 0
        } else {
            consecutiveMisses += 1
        }
    }

    /// Reset to beginning
    func reset() {
        cursorIndex = 0
        confidence = 0
        consecutiveMisses = 0
        lastRecognizedSuffix = ""
        candidateIndex = 0
        candidateHits = 0
        hasFoundInitialPosition = false
    }

    /// Jump to a specific position (for manual override)
    func jumpTo(index: Int) {
        cursorIndex = max(0, min(index, words.count - 1))
        consecutiveMisses = 0
        candidateHits = 0
    }

    // MARK: - Private

    /// Check if two positions are "near" each other (within 3 words)
    private func isNear(_ a: Int, _ b: Int) -> Bool {
        abs(a - b) <= 3
    }

    /// How many consecutive confirmations needed before jumping, based on distance from cursor
    private func confirmationsNeeded(for target: Int) -> Int {
        let distance = abs(target - cursorIndex)
        if distance <= 3 {
            return 1  // next few words: move immediately
        } else if distance <= 8 {
            return 2  // moderate skip: confirm once
        } else {
            return 3  // big jump: need solid evidence
        }
    }

    /// Search a window of words and return the best match position
    private func searchWindow(
        recentWords: [String],
        from start: Int,
        to end: Int,
        useBias: Bool
    ) -> (absoluteIndex: Int, confidence: Double)? {
        guard start < end else { return nil }

        let expectedWindow = (start..<end).map { words[$0].text }
        let cursorOffsetInWindow = useBias ? cursorIndex - start : nil

        let result = FuzzyMatcher.findBestAlignment(
            recognized: recentWords,
            expected: expectedWindow,
            cursorOffset: cursorOffsetInWindow
        )

        guard result.rawConfidence >= matchThreshold else { return nil }

        let matchedAbsoluteIndex = start + result.offset + recentWords.count - 1
        let clampedIndex = min(matchedAbsoluteIndex, words.count - 1)

        return (clampedIndex, result.confidence)
    }
}
