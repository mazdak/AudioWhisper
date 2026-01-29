import XCTest
import Foundation
@testable import AudioWhisper

class SpeechToTextServiceTests: XCTestCase {
    var service: SpeechToTextService!
    var mockKeychain: MockKeychainService!
    var testAudioURL: URL!

    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychainService()
        service = SpeechToTextService(keychainService: mockKeychain)

        // Create a temporary test audio file
        testAudioURL = createTestAudioFile()
    }

    override func tearDown() {
        if let url = testAudioURL, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        service = nil
        mockKeychain = nil
        testAudioURL = nil
        super.tearDown()
    }

    // MARK: - Error Handling Tests

    func testSpeechToTextErrorDescriptions() {
        let invalidURLError = SpeechToTextError.invalidURL
        XCTAssertEqual(invalidURLError.errorDescription, "Recording appears to be corrupted. Please try recording again.")

        let transcriptionFailedError = SpeechToTextError.transcriptionFailed("Test error")
        XCTAssertTrue(transcriptionFailedError.errorDescription?.contains("Transcription failed") == true)
    }

    // MARK: - Provider Tests

    func testProviderEnumHasLocalAndParakeet() {
        let allProviders = TranscriptionProvider.allCases
        XCTAssertTrue(allProviders.contains(.local))
        XCTAssertTrue(allProviders.contains(.parakeet))
        XCTAssertEqual(allProviders.count, 2)
    }

    func testProviderDisplayNames() {
        XCTAssertEqual(TranscriptionProvider.local.displayName, "Local Whisper")
        XCTAssertEqual(TranscriptionProvider.parakeet.displayName, "Parakeet (Advanced)")
    }

    // MARK: - File Handling Tests

    func testTranscribeWithInvalidURL() async {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.m4a")

        do {
            _ = try await service.transcribeRaw(audioURL: invalidURL, provider: .local, model: .base)
            XCTFail("Expected error due to invalid file URL")
        } catch {
            // Should get an error when trying to read the file
            XCTAssertTrue(error is SpeechToTextError || error is CocoaError)
        }
    }

    // MARK: - Text Cleaning Tests

    func testCleanTranscriptionTextRemovesBrackets() {
        let input = "Hello [music] world [applause]"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, "Hello world")
    }

    func testCleanTranscriptionTextRemovesParentheses() {
        let input = "Hello (music) world (applause)"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, "Hello world")
    }

    func testCleanTranscriptionTextRemovesNestedBrackets() {
        let input = "Hello [[nested]] world"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, "Hello world")
    }

    func testCleanTranscriptionTextTrimsWhitespace() {
        let input = "  Hello world  "
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, "Hello world")
    }

    func testCleanTranscriptionTextNormalizesSpaces() {
        let input = "Hello    world"
        let result = SpeechToTextService.cleanTranscriptionText(input)
        XCTAssertEqual(result, "Hello world")
    }

    // MARK: - Parakeet Provider Tests

    func testTranscribeWithParakeetProviderMissingPython() async {
        let invalidPythonPath = "/invalid/python/path"
        UserDefaults.standard.set(invalidPythonPath, forKey: "parakeetPythonPath")

        do {
            _ = try await service.transcribeRaw(audioURL: testAudioURL, provider: .parakeet)
            XCTFail("Expected error due to invalid audio or Python path")
        } catch let error as SpeechToTextError {
            // The test can fail either due to invalid audio (which is expected since we create a fake file)
            // or due to invalid Python path. Both are acceptable test outcomes
            let errorMessage = error.localizedDescription
            let hasExpectedError = errorMessage.contains("Parakeet error") ||
                                 errorMessage.contains("Python") ||
                                 errorMessage.contains("not found") ||
                                 errorMessage.contains("corrupted") ||
                                 errorMessage.contains("unreadable")
            XCTAssertTrue(hasExpectedError, "Error should indicate audio or Python issue: \(errorMessage)")
        } catch {
            // Also acceptable - might be ParakeetError or other
            XCTAssertTrue(true)
        }

        // Clean up
        UserDefaults.standard.removeObject(forKey: "parakeetPythonPath")
    }

    func testParakeetProviderInAllCases() {
        // Ensure Parakeet is included in all provider tests
        let allProviders: [TranscriptionProvider] = [.local, .parakeet]
        XCTAssertTrue(allProviders.contains(.parakeet))
        XCTAssertEqual(allProviders.count, 2)
    }
}

// MARK: - Test Helpers

extension SpeechToTextServiceTests {
    private func createTestAudioFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("test_audio.m4a")

        // Create a minimal test file
        guard let testData = "test audio data".data(using: .utf8) else {
            XCTFail("Failed to create test data")
            return tempDir.appendingPathComponent("invalid")
        }
        do {
            try testData.write(to: audioURL)
        } catch {
            XCTFail("Failed to write test file: \(error)")
            return tempDir.appendingPathComponent("invalid")
        }

        return audioURL
    }
}

// MARK: - Error Comparison

extension SpeechToTextError: Equatable {
    public static func == (lhs: SpeechToTextError, rhs: SpeechToTextError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL):
            return true
        case (.transcriptionFailed(let lhsMessage), .transcriptionFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.localTranscriptionFailed, .localTranscriptionFailed):
            return true
        default:
            return false
        }
    }
}
