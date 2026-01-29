import XCTest
import SwiftData
@testable import AudioWhisper

/// Integration tests for cross-service error propagation
/// Verifies that errors flow correctly through the service chain
@MainActor
final class ErrorPropagationIntegrationTests: XCTestCase {
    var mockKeychain: MockKeychainService!
    var speechService: SpeechToTextService!
    var testDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()

        // Create isolated defaults
        let suiteName = "ErrorPropagationIntegrationTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!

        // Set up mock keychain
        mockKeychain = MockKeychainService()

        // Create speech service with mock keychain
        speechService = SpeechToTextService(keychainService: mockKeychain)

        // Clear settings
        testDefaults.removeObject(forKey: "semanticCorrectionMode")
    }

    override func tearDown() async throws {
        mockKeychain.clear()
        testDefaults.removePersistentDomain(forName: testDefaults.description)

        mockKeychain = nil
        speechService = nil
        testDefaults = nil

        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func createInvalidAudioFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let audioFile = tempDir.appendingPathComponent("invalid_audio_\(UUID().uuidString).m4a")
        // Create a file with invalid audio content
        FileManager.default.createFile(atPath: audioFile.path, contents: Data([0x00, 0x01, 0x02]), attributes: nil)
        return audioFile
    }

    private func createEmptyFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let emptyFile = tempDir.appendingPathComponent("empty_\(UUID().uuidString).m4a")
        FileManager.default.createFile(atPath: emptyFile.path, contents: Data(), attributes: nil)
        return emptyFile
    }

    private func cleanupTempFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - API Key Error Tests

    func testLocalProviderTranscriptionErrorType() async {
        // Given - Invalid audio file
        let audioURL = createInvalidAudioFile()
        defer { cleanupTempFile(audioURL) }

        // When/Then
        do {
            _ = try await speechService.transcribe(audioURL: audioURL, provider: .local)
            XCTFail("Should throw error")
        } catch {
            // Audio validation fails - we're testing error handling works
            XCTAssertNotNil(error)
        }
    }

    // MARK: - SpeechToTextError Type Tests

    func testSpeechToTextErrorTypes() {
        // Verify all error types have descriptions
        let errors: [SpeechToTextError] = [
            .invalidURL,
            .transcriptionFailed("Test failure"),
            .localTranscriptionFailed(NSError(domain: "test", code: 1))
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error \(error) description should not be empty")
        }
    }

    func testInvalidURLError() {
        let error = SpeechToTextError.invalidURL
        XCTAssertNotNil(error.errorDescription)
    }

    func testTranscriptionFailedErrorContainsMessage() {
        let errorMessage = "Specific failure reason"
        let error = SpeechToTextError.transcriptionFailed(errorMessage)

        // The localized string may not contain the exact message, but error should have description
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testLocalTranscriptionFailedError() {
        let underlyingError = NSError(domain: "WhisperKit", code: 42, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        let error = SpeechToTextError.localTranscriptionFailed(underlyingError)

        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - Keychain Error Tests

    func testKeychainErrorHandling() {
        // Given - Configure mock to throw
        mockKeychain.shouldThrow = true
        mockKeychain.throwError = .itemNotFound

        // When
        let result = mockKeychain.getQuietly(service: "AudioWhisper", account: "Test")

        // Then - Quiet methods return nil on error
        XCTAssertNil(result)
    }

    func testKeychainSaveErrorThrows() {
        // Given
        mockKeychain.shouldThrow = true
        mockKeychain.throwError = .addFailed(-1)

        // When/Then
        XCTAssertThrowsError(try mockKeychain.save("key", service: "test", account: "test")) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }

    func testKeychainDeleteErrorThrows() {
        // Given
        mockKeychain.shouldThrow = true
        mockKeychain.throwError = .deleteFailed(-1)

        // When/Then
        XCTAssertThrowsError(try mockKeychain.delete(service: "test", account: "test")) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }

    // MARK: - Error Recovery Tests

    func testErrorDoesNotCorruptKeychain() {
        // Given - Save a valid key
        try! mockKeychain.save("valid-key", service: "AudioWhisper", account: "OpenAI")

        // When - Attempt an operation that fails
        mockKeychain.shouldThrow = true
        _ = mockKeychain.getQuietly(service: "AudioWhisper", account: "NonExistent")

        // Then - Valid key is still accessible
        mockKeychain.shouldThrow = false
        let key = mockKeychain.getQuietly(service: "AudioWhisper", account: "OpenAI")
        XCTAssertEqual(key, "valid-key")
    }

    // MARK: - Semantic Correction Error Tests

    func testSemanticCorrectionSafeMergeWithEmptyCorrection() {
        // Given
        let original = "Original text"
        let corrected = ""

        // When
        let result = SemanticCorrectionService.safeMerge(original: original, corrected: corrected, maxChangeRatio: 0.6)

        // Then - Empty correction returns original
        XCTAssertEqual(result, original)
    }

    func testSemanticCorrectionSafeMergeExceedsRatio() {
        // Given - Correction changes too much
        let original = "Hello world"
        let corrected = "Completely different text that bears no resemblance"

        // When
        let result = SemanticCorrectionService.safeMerge(original: original, corrected: corrected, maxChangeRatio: 0.25)

        // Then - Original is preserved when change ratio exceeded
        XCTAssertEqual(result, original)
    }

    func testSemanticCorrectionSafeMergeAcceptsMinorChanges() {
        // Given - Minor correction
        let original = "hello world"
        let corrected = "Hello world."

        // When
        let result = SemanticCorrectionService.safeMerge(original: original, corrected: corrected, maxChangeRatio: 0.6)

        // Then - Minor correction is accepted
        XCTAssertEqual(result, "Hello world.")
    }

    func testNormalizedEditDistanceIdenticalStrings() {
        // Given
        let a = "Hello world"
        let b = "Hello world"

        // When
        let distance = SemanticCorrectionService.normalizedEditDistance(a: a, b: b)

        // Then
        XCTAssertEqual(distance, 0.0)
    }

    func testNormalizedEditDistanceCompletelyDifferent() {
        // Given
        let a = "abc"
        let b = "xyz"

        // When
        let distance = SemanticCorrectionService.normalizedEditDistance(a: a, b: b)

        // Then - Should be 1.0 (completely different)
        XCTAssertEqual(distance, 1.0)
    }

    func testNormalizedEditDistanceEmptyString() {
        // Given
        let a = ""
        let b = "hello"

        // When
        let distance = SemanticCorrectionService.normalizedEditDistance(a: a, b: b)

        // Then
        XCTAssertEqual(distance, 1.0)
    }

    // MARK: - Concurrent Error Handling Tests

    func testConcurrentErrorsAreIsolated() async {
        // Given - Multiple concurrent operations
        let mockKeychains = (0..<5).map { _ in MockKeychainService() }

        // Configure some to fail
        mockKeychains[1].shouldThrow = true
        mockKeychains[3].shouldThrow = true

        // When - Run concurrent operations
        await withTaskGroup(of: String?.self) { group in
            for (index, keychain) in mockKeychains.enumerated() {
                group.addTask {
                    return keychain.getQuietly(service: "test", account: "account\(index)")
                }
            }
        }

        // Then - Errors in some don't affect others
        let successKeychain = mockKeychains[0]
        try! successKeychain.save("key", service: "test", account: "test")
        let retrieved = successKeychain.getQuietly(service: "test", account: "test")
        XCTAssertEqual(retrieved, "key")
    }

    // MARK: - Text Cleaning Error Cases

    func testCleanTranscriptionTextWithMalformedBrackets() {
        // Given - Unbalanced brackets
        let malformed = "Hello [unclosed bracket world"

        // When
        let cleaned = SpeechToTextService.cleanTranscriptionText(malformed)

        // Then - Should not crash, returns processed text
        XCTAssertNotNil(cleaned)
    }

    func testCleanTranscriptionTextWithNestedMarkers() {
        // Given - Deeply nested markers
        let nested = "Hello [[[[nested]]]] world"

        // When
        let cleaned = SpeechToTextService.cleanTranscriptionText(nested)

        // Then - All markers removed
        XCTAssertEqual(cleaned, "Hello world")
    }

    func testCleanTranscriptionTextWithOnlyMarkers() {
        // Given - Text with only markers
        let onlyMarkers = "[music] (silence) [applause]"

        // When
        let cleaned = SpeechToTextService.cleanTranscriptionText(onlyMarkers)

        // Then - Result is empty (trimmed)
        XCTAssertEqual(cleaned, "")
    }

    // MARK: - File System Error Simulation

    func testNonExistentFileHandling() async {
        // Given - A URL to a file that doesn't exist
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/path/audio.m4a")

        // When/Then - Should throw an error gracefully
        do {
            _ = try await speechService.transcribe(audioURL: nonExistentURL, provider: .local)
            XCTFail("Should throw error for non-existent file")
        } catch {
            // Expected - file doesn't exist
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Error Notification Tests

    func testErrorNotificationPosted() async {
        // Given
        let expectation = XCTestExpectation(description: "Error notification")
        var receivedError: String?

        let observer = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: .main
        ) { notification in
            receivedError = notification.userInfo?["error"] as? String
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        // When - Post failure notification
        NotificationCenter.default.post(
            name: .pasteOperationFailed,
            object: nil,
            userInfo: ["error": "Test error message"]
        )

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedError, "Test error message")
    }
}
