import XCTest
@testable import AudioWhisper

final class SemanticCorrectionServiceTests: XCTestCase {

    // MARK: - Normalized Edit Distance Tests

    func testNormalizedEditDistanceIdenticalStrings() {
        let distance = SemanticCorrectionService.normalizedEditDistance(a: "hello", b: "hello")
        XCTAssertEqual(distance, 0.0)
    }

    func testNormalizedEditDistanceCompletelyDifferent() {
        let distance = SemanticCorrectionService.normalizedEditDistance(a: "abc", b: "xyz")
        XCTAssertEqual(distance, 1.0) // 3 substitutions / 3 = 1.0
    }

    func testNormalizedEditDistanceOneCharDifference() {
        let distance = SemanticCorrectionService.normalizedEditDistance(a: "hello", b: "hallo")
        XCTAssertEqual(distance, 0.2) // 1 substitution / 5 = 0.2
    }

    func testNormalizedEditDistanceEmptyOriginal() {
        let distance = SemanticCorrectionService.normalizedEditDistance(a: "", b: "hello")
        XCTAssertEqual(distance, 1.0)
    }

    func testNormalizedEditDistanceEmptyCorrected() {
        let distance = SemanticCorrectionService.normalizedEditDistance(a: "hello", b: "")
        XCTAssertEqual(distance, 1.0)
    }

    func testNormalizedEditDistanceBothEmpty() {
        let distance = SemanticCorrectionService.normalizedEditDistance(a: "", b: "")
        XCTAssertEqual(distance, 0.0)
    }

    func testNormalizedEditDistanceInsertion() {
        let distance = SemanticCorrectionService.normalizedEditDistance(a: "helo", b: "hello")
        XCTAssertEqual(distance, 0.2) // 1 insertion / 5 = 0.2
    }

    func testNormalizedEditDistanceDeletion() {
        let distance = SemanticCorrectionService.normalizedEditDistance(a: "hello", b: "helo")
        XCTAssertEqual(distance, 0.2) // 1 deletion / 5 = 0.2
    }

    func testNormalizedEditDistanceUnicode() {
        let distance = SemanticCorrectionService.normalizedEditDistance(a: "café", b: "cafe")
        XCTAssertEqual(distance, 0.25) // 1 change / 4 = 0.25
    }

    func testNormalizedEditDistanceEmoji() {
        let distance = SemanticCorrectionService.normalizedEditDistance(a: "hello 👋", b: "hello 🙋")
        // "hello 👋" is 7 characters (emoji is 1 character in Swift)
        XCTAssertEqual(distance, 1.0 / 7.0, accuracy: 0.001) // 1 change / 7 chars
    }

    // MARK: - Safe Merge Tests

    func testSafeMergeAcceptsSmallChanges() {
        let result = SemanticCorrectionService.safeMerge(
            original: "hello world",
            corrected: "Hello world",
            maxChangeRatio: 0.25
        )
        XCTAssertEqual(result, "Hello world")
    }

    func testSafeMergeRejectsLargeChanges() {
        let result = SemanticCorrectionService.safeMerge(
            original: "hello world",
            corrected: "completely different text here",
            maxChangeRatio: 0.25
        )
        XCTAssertEqual(result, "hello world") // Kept original
    }

    func testSafeMergeRejectsEmptyCorrected() {
        let result = SemanticCorrectionService.safeMerge(
            original: "hello world",
            corrected: "",
            maxChangeRatio: 0.25
        )
        XCTAssertEqual(result, "hello world")
    }

    func testSafeMergeTrimsWhitespace() {
        // When within threshold, whitespace is trimmed from result
        let result = SemanticCorrectionService.safeMerge(
            original: "hello world",
            corrected: "  hello world  \n",
            maxChangeRatio: 0.25
        )
        XCTAssertEqual(result, "hello world")
    }

    func testSafeMergeIdenticalStrings() {
        let result = SemanticCorrectionService.safeMerge(
            original: "hello world",
            corrected: "hello world",
            maxChangeRatio: 0.25
        )
        XCTAssertEqual(result, "hello world")
    }

    func testSafeMergeAtExactThreshold() {
        // "hello" -> "hallo" is 0.2 edit distance
        // The check is `if ratio > maxChangeRatio` so 0.2 == 0.2 passes (not rejected)
        let result = SemanticCorrectionService.safeMerge(
            original: "hello",
            corrected: "hallo",
            maxChangeRatio: 0.2
        )
        XCTAssertEqual(result, "hallo") // 0.2 is NOT > 0.2, so accepted at boundary
    }

    func testSafeMergeJustUnderThreshold() {
        // "hello" -> "hallo" is 0.2 edit distance
        let result = SemanticCorrectionService.safeMerge(
            original: "hello",
            corrected: "hallo",
            maxChangeRatio: 0.21
        )
        XCTAssertEqual(result, "hallo") // 0.2 < 0.21, accepted
    }

    func testSafeMergeWithFillerWordRemoval() {
        // Simulates removing "um" and "uh" from transcription
        let original = "So um I was like uh thinking about it"
        let corrected = "So I was thinking about it"
        let result = SemanticCorrectionService.safeMerge(
            original: original,
            corrected: corrected,
            maxChangeRatio: 0.4
        )
        XCTAssertEqual(result, corrected)
    }

    func testSafeMergeWithPunctuationFix() {
        let original = "hello how are you doing today"
        let corrected = "Hello, how are you doing today?"
        let result = SemanticCorrectionService.safeMerge(
            original: original,
            corrected: corrected,
            maxChangeRatio: 0.25
        )
        XCTAssertEqual(result, corrected)
    }

    func testSafeMergePreservesOriginalOnHallucination() {
        // LLM might hallucinate extra content
        let original = "The meeting is at 3pm"
        let corrected = "The meeting is at 3pm. Please bring your laptop and prepare the quarterly report for discussion."
        let result = SemanticCorrectionService.safeMerge(
            original: original,
            corrected: corrected,
            maxChangeRatio: 0.25
        )
        XCTAssertEqual(result, original) // Rejected due to too much change
    }

    // MARK: - Edge Cases

    func testSafeMergeWithNewlines() {
        let result = SemanticCorrectionService.safeMerge(
            original: "line one\nline two",
            corrected: "Line one.\nLine two.",
            maxChangeRatio: 0.25
        )
        XCTAssertEqual(result, "Line one.\nLine two.")
    }

    func testNormalizedEditDistanceLongStrings() {
        let original = String(repeating: "a", count: 1000)
        let corrected = String(repeating: "a", count: 990) + String(repeating: "b", count: 10)
        let distance = SemanticCorrectionService.normalizedEditDistance(a: original, b: corrected)
        XCTAssertEqual(distance, 0.01, accuracy: 0.001) // 10 changes / 1000
    }

    func testSafeMergeWithZeroThreshold() {
        let result = SemanticCorrectionService.safeMerge(
            original: "hello",
            corrected: "Hello",
            maxChangeRatio: 0.0
        )
        XCTAssertEqual(result, "hello") // Any change rejected
    }

    func testSafeMergeWithFullThreshold() {
        let result = SemanticCorrectionService.safeMerge(
            original: "hello",
            corrected: "completely different",
            maxChangeRatio: 1.0
        )
        XCTAssertEqual(result, "completely different") // All changes accepted
    }
}
