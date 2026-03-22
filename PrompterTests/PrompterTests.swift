import XCTest
@testable import Prompter

final class FuzzyMatcherTests: XCTestCase {

    // MARK: - Levenshtein Distance

    func testExactMatch() {
        XCTAssertEqual(FuzzyMatcher.levenshteinDistance("hello", "hello"), 0)
    }

    func testSingleInsertion() {
        XCTAssertEqual(FuzzyMatcher.levenshteinDistance("hello", "helloo"), 1)
    }

    func testSingleDeletion() {
        XCTAssertEqual(FuzzyMatcher.levenshteinDistance("hello", "hell"), 1)
    }

    func testSingleSubstitution() {
        XCTAssertEqual(FuzzyMatcher.levenshteinDistance("hello", "hallo"), 1)
    }

    func testCompletelyDifferent() {
        XCTAssertEqual(FuzzyMatcher.levenshteinDistance("abc", "xyz"), 3)
    }

    func testEmptyStrings() {
        XCTAssertEqual(FuzzyMatcher.levenshteinDistance("", ""), 0)
        XCTAssertEqual(FuzzyMatcher.levenshteinDistance("hello", ""), 5)
        XCTAssertEqual(FuzzyMatcher.levenshteinDistance("", "world"), 5)
    }

    // MARK: - Normalized Similarity

    func testPerfectSimilarity() {
        XCTAssertEqual(FuzzyMatcher.normalizedSimilarity("hello", "hello"), 1.0)
    }

    func testZeroSimilarity() {
        // "abc" vs "xyz" = distance 3, max length 3 -> similarity 0
        XCTAssertEqual(FuzzyMatcher.normalizedSimilarity("abc", "xyz"), 0.0, accuracy: 0.01)
    }

    func testPartialSimilarity() {
        // "hello" vs "hallo" = distance 1, max length 5 -> similarity 0.8
        XCTAssertEqual(FuzzyMatcher.normalizedSimilarity("hello", "hallo"), 0.8, accuracy: 0.01)
    }

    // MARK: - Accent Robustness

    func testAccentedSpeech() {
        // Simulating how "technology" might be recognized with a French accent
        let similarity = FuzzyMatcher.normalizedSimilarity("technology", "teknoloji")
        XCTAssertGreaterThan(similarity, 0.5, "Should still match accented speech")
    }

    // MARK: - Sliding Window Alignment

    func testExactAlignment() {
        let recognized = ["the", "quick", "brown"]
        let expected = ["the", "quick", "brown", "fox", "jumps"]
        let result = FuzzyMatcher.findBestAlignment(recognized: recognized, expected: expected)
        XCTAssertEqual(result.offset, 0)
        XCTAssertGreaterThan(result.confidence, 0.9)
    }

    func testOffsetAlignment() {
        let recognized = ["brown", "fox"]
        let expected = ["the", "quick", "brown", "fox", "jumps"]
        let result = FuzzyMatcher.findBestAlignment(recognized: recognized, expected: expected)
        XCTAssertEqual(result.offset, 2)
        XCTAssertGreaterThan(result.confidence, 0.9)
    }

    func testFuzzyAlignment() {
        // Simulating imperfect recognition
        let recognized = ["tha", "quik", "bown"]  // noisy recognition
        let expected = ["the", "quick", "brown", "fox", "jumps"]
        let result = FuzzyMatcher.findBestAlignment(recognized: recognized, expected: expected)
        XCTAssertEqual(result.offset, 0)
        XCTAssertGreaterThan(result.confidence, 0.5, "Should still find alignment with fuzzy words")
    }

    func testNoMatch() {
        let recognized = ["completely", "different", "words"]
        let expected = ["the", "quick", "brown", "fox", "jumps"]
        let result = FuzzyMatcher.findBestAlignment(recognized: recognized, expected: expected)
        XCTAssertLessThan(result.confidence, 0.4, "Should have low confidence for unrelated words")
    }

    func testEmptyInputs() {
        let result1 = FuzzyMatcher.findBestAlignment(recognized: [], expected: ["hello"])
        XCTAssertEqual(result1.confidence, 0)

        let result2 = FuzzyMatcher.findBestAlignment(recognized: ["hello"], expected: [])
        XCTAssertEqual(result2.confidence, 0)
    }
}

final class WordTokenizerTests: XCTestCase {

    let tokenizer = WordTokenizer()

    func testBasicTokenization() {
        let words = tokenizer.tokenize("Hello world")
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual(words[0].text, "hello")
        XCTAssertEqual(words[1].text, "world")
    }

    func testPunctuationStripping() {
        let words = tokenizer.tokenize("Hello, world! How are you?")
        XCTAssertEqual(words.count, 5)
        XCTAssertEqual(words[0].text, "hello")
        XCTAssertEqual(words[1].text, "world")
        XCTAssertEqual(words[4].text, "you")
    }

    func testContractions() {
        let words = tokenizer.tokenize("don't won't can't")
        XCTAssertEqual(words.count, 3)
        XCTAssertEqual(words[0].text, "don't")
    }

    func testMultipleWhitespace() {
        let words = tokenizer.tokenize("Hello    world\n\nnew   paragraph")
        XCTAssertEqual(words.count, 4)
    }

    func testEmptyText() {
        let words = tokenizer.tokenize("")
        XCTAssertEqual(words.count, 0)
    }

    func testWordIndices() {
        let words = tokenizer.tokenize("one two three")
        XCTAssertEqual(words[0].id, 0)
        XCTAssertEqual(words[1].id, 1)
        XCTAssertEqual(words[2].id, 2)
    }

    func testOriginalTextPreserved() {
        let words = tokenizer.tokenize("Hello, World!")
        XCTAssertEqual(words[0].original, "Hello,")
        XCTAssertEqual(words[1].original, "World!")
    }

    func testUniqueVocabulary() {
        let words = tokenizer.tokenize("the the the extraordinary extraordinary simple")
        let vocab = tokenizer.uniqueVocabulary(from: words)
        // Should prioritize longer words, skip words <= 3 chars
        XCTAssertTrue(vocab.contains("extraordinary"))
        XCTAssertFalse(vocab.contains("the")) // too short
    }
}

final class StringNormalizedTests: XCTestCase {

    func testBasicNormalization() {
        XCTAssertEqual("Hello, World!".normalized, "hello world")
    }

    func testPreservesApostrophes() {
        XCTAssertEqual("don't".normalized, "don't")
    }

    func testCollapsesWhitespace() {
        XCTAssertEqual("hello    world".normalized, "hello world")
    }

    func testNormalizedWords() {
        XCTAssertEqual("Hello, World! How?".normalizedWords, ["hello", "world", "how"])
    }
}
