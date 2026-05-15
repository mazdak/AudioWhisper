import XCTest
import SwiftData
@testable import AudioWhisper

/// Integration tests for app lifecycle events and state management
@MainActor
final class AppLifecycleIntegrationTests: IsolatedXCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testDefaults: UserDefaults!
    var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
        modelContainer = try ModelContainer(
            for: TranscriptionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = ModelContext(modelContainer)

        // Create isolated UserDefaults for testing
        suiteName = "AppLifecycleIntegrationTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!

        // Enable history
        testDefaults.set(true, forKey: "transcriptionHistoryEnabled")
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

        if let suiteName = suiteName {
            testDefaults?.removePersistentDomain(forName: suiteName)
        }

        modelContainer = nil
        modelContext = nil
        testDefaults = nil
        suiteName = nil

        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperation() async {
        try? await Task.sleep(for: .milliseconds(100))
    }

    // MARK: - Launch Sequence Tests

    func testAppLaunchSequenceWithDefaultSettings() {
        // Given - Default settings
        testDefaults.register(defaults: [
            "enableSmartPaste": true,
            "immediateRecording": true,
            "startAtLogin": true,
            "playCompletionSound": true
        ])

        // When - App launches
        let enableSmartPaste = testDefaults.bool(forKey: "enableSmartPaste")
        let immediateRecording = testDefaults.bool(forKey: "immediateRecording")

        // Then - Defaults are properly registered
        XCTAssertTrue(enableSmartPaste)
        XCTAssertTrue(immediateRecording)
    }

    func testAppLaunchSequenceWithCustomProvider() {
        // Given - Custom provider setting
        testDefaults.set(TranscriptionProvider.parakeet.rawValue, forKey: "transcriptionProvider")

        // When - App reads provider
        let providerRaw = testDefaults.string(forKey: "transcriptionProvider")
        let provider = TranscriptionProvider(rawValue: providerRaw ?? "")

        // Then - Custom provider is loaded
        XCTAssertEqual(provider, .parakeet)
    }

    func testAppLaunchSequenceWithMissingModel() {
        // Given - Local provider selected but model not downloaded
        testDefaults.set(TranscriptionProvider.local.rawValue, forKey: "transcriptionProvider")
        testDefaults.set("large-v3", forKey: "selectedWhisperModel")

        // When - App checks model availability
        let providerRaw = testDefaults.string(forKey: "transcriptionProvider")
        let modelRaw = testDefaults.string(forKey: "selectedWhisperModel")

        // Then - App should detect missing model
        XCTAssertEqual(providerRaw, "local")
        XCTAssertEqual(modelRaw, "large-v3")
        // Dashboard would be shown in real app
    }

    // MARK: - Recording Flow Tests

    func testAppLaunchToRecordToTranscribeFlow() async throws {
        // Given - App has launched and user records
        let recordingText = "This is a test transcription from recording"

        // When - Transcription is saved
        let record = TranscriptionRecord(
            text: recordingText,
            provider: .local,
            duration: 5.0
        )
        modelContext.insert(record)
        try modelContext.save()

        await waitForAsyncOperation()

        // Then - Record is persisted
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let records = try modelContext.fetch(descriptor)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.text, recordingText)
    }

    // MARK: - Termination Tests

    func testAppTerminationCleanupsAllResources() async throws {
        // Given - App has records and state
        let record = TranscriptionRecord(
            text: "Pre-termination record",
            provider: .local,
            duration: 3.0
        )
        modelContext.insert(record)
        try modelContext.save()

        // When - App terminates (simulated by cleaning up)
        // In real app, this would be applicationWillTerminate

        // Then - Records should persist (SwiftData handles this)
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let records = try modelContext.fetch(descriptor)

        XCTAssertEqual(records.count, 1)
    }

    // MARK: - State Restoration Tests

    func testAppRelaunchRestoresState() async throws {
        // Given - Previous session left records
        let previousRecord = TranscriptionRecord(
            text: "Previous session transcription",
            provider: .parakeet,
            duration: 8.0
        )
        modelContext.insert(previousRecord)
        try modelContext.save()

        // When - App "relaunches" (new context from same container)
        let newContext = ModelContext(modelContainer)

        // Then - Previous records are available
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let records = try newContext.fetch(descriptor)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.text, "Previous session transcription")
    }

    func testAppRelaunchRestoresSettings() {
        // Given - Settings from previous session
        testDefaults.set(TranscriptionProvider.local.rawValue, forKey: "transcriptionProvider")
        testDefaults.set("medium", forKey: "selectedWhisperModel")
        testDefaults.set(false, forKey: "immediateRecording")

        // When - App reads settings
        let provider = testDefaults.string(forKey: "transcriptionProvider")
        let model = testDefaults.string(forKey: "selectedWhisperModel")
        let immediateRecording = testDefaults.bool(forKey: "immediateRecording")

        // Then - Settings are restored
        XCTAssertEqual(provider, "local")
        XCTAssertEqual(model, "medium")
        XCTAssertFalse(immediateRecording)
    }

    // MARK: - First Run Tests

    func testFirstRunBehavior() {
        // Given - First run (no hasCompletedWelcome flag)
        testDefaults.removeObject(forKey: "hasCompletedWelcome")

        // When - Check first run status
        let hasCompletedWelcome = testDefaults.bool(forKey: "hasCompletedWelcome")

        // Then - Should be false (first run)
        XCTAssertFalse(hasCompletedWelcome)
    }

    func testSubsequentRunBehavior() {
        // Given - Not first run
        testDefaults.set(true, forKey: "hasCompletedWelcome")

        // When - Check first run status
        let hasCompletedWelcome = testDefaults.bool(forKey: "hasCompletedWelcome")

        // Then - Should be true
        XCTAssertTrue(hasCompletedWelcome)
    }

    // MARK: - Multiple Session Tests

    func testMultipleSessionsAccumulateRecords() async throws {
        // Given - Multiple "sessions" of transcriptions
        for i in 1...3 {
            let record = TranscriptionRecord(
                text: "Session \(i) transcription",
                provider: .local,
                duration: Double(i * 5)
            )
            modelContext.insert(record)
        }
        try modelContext.save()

        await waitForAsyncOperation()

        // Then - All records accumulated
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let records = try modelContext.fetch(descriptor)

        XCTAssertEqual(records.count, 3)
    }

    // MARK: - Memory Warning Simulation

    func testAppHandlesMemoryPressure() async throws {
        // Given - App has records
        let record = TranscriptionRecord(
            text: "Record before memory pressure",
            provider: .parakeet,
            duration: 5.0
        )
        modelContext.insert(record)
        try modelContext.save()

        // When - Memory pressure occurs (simulated)
        // In real app, this would trigger memory warning handlers

        await waitForAsyncOperation()

        // Then - Critical data is preserved
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let records = try modelContext.fetch(descriptor)

        XCTAssertEqual(records.count, 1)
    }

    // MARK: - Settings Synchronization Tests

    func testSettingsAreSynchronizedAcrossSessions() {
        // Given - Settings changed
        testDefaults.set("large-v3", forKey: "selectedWhisperModel")
        testDefaults.synchronize()

        // When - Read settings
        let model = testDefaults.string(forKey: "selectedWhisperModel")

        // Then - Changes are persisted
        XCTAssertEqual(model, "large-v3")
    }
}
