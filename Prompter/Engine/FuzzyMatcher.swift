import Foundation

struct MatchResult {
    let offset: Int        // best match offset within the expected window
    let confidence: Double // 0.0 to 1.0 (after bias applied)
    let rawConfidence: Double // 0.0 to 1.0 (pure text similarity)
}

enum FuzzyMatcher {
    /// Levenshtein edit distance between two strings
    static func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count

        if m == 0 { return n }
        if n == 0 { return m }

        // Two-row DP for space efficiency
        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                if aChars[i - 1] == bChars[j - 1] {
                    curr[j] = prev[j - 1]
                } else {
                    curr[j] = 1 + min(prev[j], curr[j - 1], prev[j - 1])
                }
            }
            swap(&prev, &curr)
        }

        return prev[n]
    }

    /// Normalized similarity between two strings (0.0 = completely different, 1.0 = identical)
    static func normalizedSimilarity(_ a: String, _ b: String) -> Double {
        if a.isEmpty && b.isEmpty { return 1.0 }
        let maxLen = max(a.count, b.count)
        if maxLen == 0 { return 1.0 }
        let distance = levenshteinDistance(a, b)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Slide recognized words over expected words to find the best alignment.
    ///
    /// - Parameters:
    ///   - recognized: Last N words from speech recognition (normalized)
    ///   - expected: Window of expected words from the prompt (normalized)
    ///   - cursorOffset: The offset within `expected` that corresponds to the current cursor.
    ///     Used to apply proximity bias -- positions near the cursor score higher.
    ///     Pass nil to disable bias (e.g. for full-text search in lost mode).
    /// - Returns: Best match offset within the expected window and confidence score
    static func findBestAlignment(
        recognized: [String],
        expected: [String],
        cursorOffset: Int? = nil
    ) -> MatchResult {
        guard !recognized.isEmpty, !expected.isEmpty else {
            return MatchResult(offset: 0, confidence: 0, rawConfidence: 0)
        }

        let recCount = recognized.count
        var bestOffset = 0
        var bestScore = -1.0
        var bestRawScore = 0.0

        // Slide the recognized window across the expected words
        let maxOffset = max(0, expected.count - 1)

        for offset in 0...maxOffset {
            var totalSim = 0.0
            var comparisons = 0

            for i in 0..<recCount {
                let expIdx = offset + i
                guard expIdx < expected.count else { break }

                let sim = normalizedSimilarity(recognized[i], expected[expIdx])
                totalSim += sim
                comparisons += 1
            }

            guard comparisons > 0 else { continue }
            let rawSim = totalSim / Double(comparisons)

            // Apply proximity bias: positions near cursor get a bonus,
            // positions far from cursor get penalized
            let biasedScore: Double
            if let cursorOffset {
                let distance = offset - cursorOffset // negative = backward, positive = forward
                let bias: Double
                if distance >= 0 && distance <= 5 {
                    // Next few words ahead: strong bonus (most likely position)
                    bias = 0.15
                } else if distance > 5 && distance <= 15 {
                    // Moderate skip forward: small bonus
                    bias = 0.05
                } else if distance < 0 && distance >= -3 {
                    // Slight backward (repetition): no penalty
                    bias = 0.0
                } else if distance < -3 {
                    // Going further backward: increasing penalty
                    bias = -0.1 - Double(abs(distance) - 3) * 0.01
                } else {
                    // Large forward skip: slight penalty
                    bias = -0.05
                }
                biasedScore = rawSim + bias
            } else {
                biasedScore = rawSim
            }

            if biasedScore > bestScore {
                bestScore = biasedScore
                bestRawScore = rawSim
                bestOffset = offset
            }
        }

        return MatchResult(
            offset: bestOffset,
            confidence: max(0, bestScore),
            rawConfidence: max(0, bestRawScore)
        )
    }
}
