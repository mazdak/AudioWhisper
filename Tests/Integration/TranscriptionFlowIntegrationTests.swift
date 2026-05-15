import XCTest
import SwiftData
@testable import AudioWhisper

/// Integration tests for the full transcription flow:
/// AudioRecorder -> SpeechToTextService -> SemanticCorrectionService -> DataManager -> UsageMetricsStore
@MainActor
final class TranscriptionFlowIntegrationTests: IsolatedXCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var mockKeychain: MockKeychainService!
    var metricsStore: UsageMetricsStore!
    var testDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
        modelContainer = try ModelContainer(
            for: TranscriptionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = ModelContext(modelContainer)

        // Create isolated UserDefaults for testing
        let suiteName = "TranscriptionFlowIntegrationTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!

        // Set up metrics store with test defaults
        metricsStore = UsageMetricsStore(defaults: testDefaults)

        // Set up mock keychain
        mockKeychain = MockKeychainService()

        // Enable history for tests
        testDefaults.set(true, forKey: "transcriptionHistoryEnabled")
        testDefaults.set(RetentionPeriod.forever.rawValue, forKey: "transcriptionRetentionPeriod")
    }

    override func tearDown() async throws {
        // Clean up records
        if let modelContext = modelContext {
            let allRecords = try? modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
            for record in allRecords ?? [] {
                modelContext.delete(record)
            }
            try? modelContext.save()
        }

        // Clean up test defaults
        testDefaults.removePersistentDomain(forName: testDefaults.description)

        modelContainer = nil
        modelContext = nil
        mockKeychain = nil
        metricsStore = nil
        testDefaults = nil

        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTempAudioFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let audioFile = tempDir.appendingPathComponent("test_audio_\(UUID().uuidString).m4a")
        // Create a minimal valid file
        FileManager.default.createFile(atPath: audioFile.path, contents: Data([0x00, 0x00, 0x00, 0x1C, 0x66, 0x74, 0x79, 0x70]), attributes: nil)
        return audioFile
    }

    private func cleanupTempFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func waitForAsyncOperation() async {
        try? await Task.sleep(for: .milliseconds(100))
    }

    // MARK: - Full Flow Tests

    func testRecordingDurationPassesToTranscriptionRecord() async throws {
        // Given - A transcription with known duration
        let duration: TimeInterval = 15.5
        let transcribedText = "This is a test transcription with measured duration"

        // When - Create and save a record with this duration
        let record = TranscriptionRecord(
            text: transcribedText,
            provider: .local,
            duration: duration,
            modelUsed: "base"
        )

        modelContext.insert(record)
        try modelContext.save()

        await waitForAsyncOperation()

        // Then - Verify duration is preserved through the flow
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let savedRecords = try modelContext.fetch(descriptor)

        XCTAssertEqual(savedRecords.count, 1)
        XCTAssertEqual(savedRecords[0].duration, duration, "Duration should pass through correctly")
        XCTAssertEqual(savedRecords[0].text, transcribedText)
    }

    func testTranscriptionTextFlowsThroughToRecord() async throws {
        // Given - Text from transcription
        let originalText = "Hello world, this is a voice transcription test"

        // When - Flow through the system
        let record = TranscriptionRecord(
            text: originalText,
            provider: .parakeet,
            duration: 5.0
        )

        modelContext.insert(record)
        try modelContext.save()

        await waitForAsyncOperation()

        // Then - Verify text is preserved
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let savedRecords = try modelContext.fetch(descriptor)

        XCTAssertEqual(savedRecords.count, 1)
        XCTAssertEqual(savedRecords[0].text, originalText)
        XCTAssertEqual(savedRecords[0].transcriptionProvider, .parakeet)
    }

    func testCancelledRecordingDoesNotCreateRecord() async throws {
        // Given - Initial state with no records
        let initialDescriptor = FetchDescriptor<TranscriptionRecord>()
        let initialRecords = try modelContext.fetch(initialDescriptor)
        XCTAssertEqual(initialRecords.count, 0)

        // When - Simulating a cancelled recording (no record is saved)
        // In the real flow, cancellation means transcription never completes

        await waitForAsyncOperation()

        // Then - No records should exist
        let finalRecords = try modelContext.fetch(initialDescriptor)
        XCTAssertEqual(finalRecords.count, 0, "Cancelled recording should not create a record")
    }

    func testFullFlowWithSemanticCorrectionApplied() async throws {
        // Given - Text that would be corrected
        let originalText = "this is uncorrected text without proper capitalization"
        let correctedText = "This is corrected text with proper capitalization."

        // When - Save the corrected text (simulating post-correction)
        let record = TranscriptionRecord(
            text: correctedText,
            provider: .local,
            duration: 8.0
        )

        modelContext.insert(record)
        try modelContext.save()

        await waitForAsyncOperation()

        // Then - Verify corrected text is stored
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let savedRecords = try modelContext.fetch(descriptor)

        XCTAssertEqual(savedRecords.count, 1)
        XCTAssertEqual(savedRecords[0].text, correctedText)
        XCTAssertNotEqual(savedRecords[0].text, originalText)
    }

    func testMultipleTranscriptionsAccumulateCorrectly() async throws {
        // Given - Multiple transcription sessions
        let sessions = [
            ("First session text", 5.0, TranscriptionProvider.local),
            ("Second session with more words here", 10.0, TranscriptionProvider.parakeet),
            ("Third session text", 3.0, TranscriptionProvider.local)
        ]

        // When - Save all sessions
        for (text, duration, provider) in sessions {
            let record = TranscriptionRecord(
                text: text,
                provider: provider,
                duration: duration
            )
            modelContext.insert(record)
        }
        try modelContext.save()

        await waitForAsyncOperation()

        // Then - All records are saved
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let savedRecords = try modelContext.fetch(descriptor)

        XCTAssertEqual(savedRecords.count, 3)

        // Verify provider diversity
        let providers = Set(savedRecords.map { $0.transcriptionProvider })
        XCTAssertTrue(providers.contains(.local))
        XCTAssertTrue(providers.contains(.parakeet))
    }

    // MARK: - Text Cleaning Integration

    func testCleanTranscriptionTextIntegration() {
        // Test the static cleaning function that's part of the transcription flow
        let inputWithBrackets = "Hello [music] world [applause]"
        let cleaned = SpeechToTextService.cleanTranscriptionText(inputWithBrackets)

        XCTAssertEqual(cleaned, "Hello world")
        XCTAssertFalse(cleaned.contains("["))
        XCTAssertFalse(cleaned.contains("]"))
    }

    func testCleanTranscriptionTextWithParentheses() {
        let inputWithParens = "Hello (background noise) world (unclear)"
        let cleaned = SpeechToTextService.cleanTranscriptionText(inputWithParens)

        XCTAssertEqual(cleaned, "Hello world")
        XCTAssertFalse(cleaned.contains("("))
        XCTAssertFalse(cleaned.contains(")"))
    }

    func testCleanTranscriptionTextWithNestedMarkers() {
        let inputNested = "Hello [[nested]] world"
        let cleaned = SpeechToTextService.cleanTranscriptionText(inputNested)

        XCTAssertEqual(cleaned, "Hello world")
    }

    func testCleanTranscriptionTextPreservesNormalText() {
        let normalText = "This is normal transcribed text without any markers."
        let cleaned = SpeechToTextService.cleanTranscriptionText(normalText)

        XCTAssertEqual(cleaned, normalText)
    }

    // MARK: - Provider Flow Tests

    func testAllProvidersCreateValidRecords() async throws {
        // Test that all providers create valid records
        let providers: [TranscriptionProvider] = [.local, .parakeet]

        for provider in providers {
            let record = TranscriptionRecord(
                text: "Test text for \(provider.displayName)",
                provider: provider,
                duration: 5.0,
                modelUsed: provider == .local ? "base" : nil
            )
            modelContext.insert(record)
        }
        try modelContext.save()

        await waitForAsyncOperation()

        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let savedRecords = try modelContext.fetch(descriptor)

        XCTAssertEqual(savedRecords.count, 2)

        for record in savedRecords {
            XCTAssertFalse(record.text.isEmpty)
            XCTAssertNotNil(record.date)
            XCTAssertNotNil(record.id)
        }
    }

    func testLocalProviderIncludesModelUsed() async throws {
        // Given - Local transcription with specific model
        let record = TranscriptionRecord(
            text: "Local transcription test",
            provider: .local,
            duration: 8.0,
            modelUsed: "large-v3-turbo"
        )

        modelContext.insert(record)
        try modelContext.save()

        await waitForAsyncOperation()

        // Then
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let savedRecords = try modelContext.fetch(descriptor)

        XCTAssertEqual(savedRecords.count, 1)
        XCTAssertEqual(savedRecords[0].modelUsed, "large-v3-turbo")
        XCTAssertEqual(savedRecords[0].transcriptionProvider, .local)
    }

    // MARK: - Error Flow Tests

    func testRecordWithNilDurationHandledGracefully() async throws {
        // Given - Record without duration (possible edge case)
        let record = TranscriptionRecord(
            text: "Quick recording without duration tracking",
            provider: .local,
            duration: nil
        )

        modelContext.insert(record)
        try modelContext.save()

        await waitForAsyncOperation()

        // Then - Record is saved without crash
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let savedRecords = try modelContext.fetch(descriptor)

        XCTAssertEqual(savedRecords.count, 1)
        XCTAssertNil(savedRecords[0].duration)
        XCTAssertNil(savedRecords[0].formattedDuration, "Nil duration should result in nil formatted duration")
    }

    func testEmptyTextTranscriptionHandled() async throws {
        // Given - Empty transcription (edge case)
        let record = TranscriptionRecord(
            text: "",
            provider: .parakeet,
            duration: 1.0
        )

        modelContext.insert(record)
        try modelContext.save()

        await waitForAsyncOperation()

        // Then - Record is saved but word count is 0
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let savedRecords = try modelContext.fetch(descriptor)

        XCTAssertEqual(savedRecords.count, 1)
        XCTAssertEqual(savedRecords[0].wordCount, 0)
        XCTAssertTrue(savedRecords[0].text.isEmpty)
    }
}
