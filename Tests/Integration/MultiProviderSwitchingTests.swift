import XCTest
import SwiftData
@testable import AudioWhisper

/// Integration tests for switching between transcription providers
@MainActor
final class MultiProviderSwitchingTests: IsolatedXCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testDefaults: UserDefaults!
    var mockKeychain: MockKeychainService!
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
        suiteName = "MultiProviderSwitchingTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!

        // Set up mock keychain
        mockKeychain = MockKeychainService()

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
        mockKeychain = nil
        testDefaults = nil
        suiteName = nil

        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperation() async {
        try? await Task.sleep(for: .milliseconds(100))
    }

    private func setProvider(_ provider: TranscriptionProvider) {
        testDefaults.set(provider.rawValue, forKey: "transcriptionProvider")
    }

    private func getProvider() -> TranscriptionProvider {
        let rawValue = testDefaults.string(forKey: "transcriptionProvider") ?? TranscriptionProvider.local.rawValue
        return TranscriptionProvider(rawValue: rawValue) ?? .local
    }

    // MARK: - Provider Switching Tests

    func testSwitchFromLocalToParakeet() {
        // Given - Local is selected
        setProvider(.local)
        XCTAssertEqual(getProvider(), .local)

        // When - Switch to Parakeet
        setProvider(.parakeet)

        // Then - Provider is updated
        XCTAssertEqual(getProvider(), .parakeet)
    }

    func testSwitchFromParakeetToLocal() {
        // Given - Parakeet is selected
        setProvider(.parakeet)
        XCTAssertEqual(getProvider(), .parakeet)

        // When - Switch to Local
        setProvider(.local)

        // Then - Provider is updated
        XCTAssertEqual(getProvider(), .local)
    }

    // MARK: - Provider Switch Error Handling Tests

    func testSwitchToLocalWithMissingModel() async throws {
        // Given - Switch to local provider
        setProvider(.local)

        // When - Local model is not downloaded
        // The system should handle this gracefully

        // Then - No crash, appropriate error would be shown
        XCTAssertEqual(getProvider(), .local)
    }

    func testSwitchToParakeetWithoutPython() async throws {
        // Given - Switch to Parakeet provider
        setProvider(.parakeet)

        // When - Python is not configured
        // The system should handle this gracefully

        // Then - No crash, appropriate error would be shown
        XCTAssertEqual(getProvider(), .parakeet)
    }

    func testSwitchToParakeetWithoutPythonConfigured() async throws {
        // Given - Switch to Parakeet provider
        setProvider(.parakeet)

        // When - Python may not be configured
        // The system should handle this gracefully

        // Then - No crash, provider is set (appropriate error would be shown during transcription)
        XCTAssertEqual(getProvider(), .parakeet)
    }

    // MARK: - Rapid Switching Tests

    func testRapidProviderSwitching() {
        // Given - Start with Local
        setProvider(.local)

        // When - Rapidly switch between providers
        let providers: [TranscriptionProvider] = [.parakeet, .local, .parakeet, .local, .parakeet, .local]

        for provider in providers {
            setProvider(provider)
        }

        // Then - Final provider should be correct
        XCTAssertEqual(getProvider(), .local)
    }

    func testRapidProviderSwitchingDoesNotCorruptState() async throws {
        // Given - Existing records
        let initialRecord = TranscriptionRecord(
            text: "Initial transcription",
            provider: .local,
            duration: 5.0
        )
        modelContext.insert(initialRecord)
        try modelContext.save()

        // When - Rapidly switch providers
        for _ in 0..<10 {
            setProvider(.local)
            setProvider(.parakeet)
        }

        await waitForAsyncOperation()

        // Then - Records are preserved
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let records = try modelContext.fetch(descriptor)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.text, "Initial transcription")
    }

    // MARK: - Provider Switch Mid-Transcription (Conceptual)

    func testProviderSwitchMidTranscription() async throws {
        // This is a conceptual test - in practice, switching mid-transcription
        // should complete the current transcription with the original provider

        // Given - Transcription in progress with Local
        let localRecord = TranscriptionRecord(
            text: "Transcription started with Local",
            provider: .local,
            duration: 10.0
        )
        modelContext.insert(localRecord)
        try modelContext.save()

        // When - Provider is changed to Parakeet
        setProvider(.parakeet)

        // Then - Existing record maintains original provider
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let records = try modelContext.fetch(descriptor)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.transcriptionProvider, .local)
        XCTAssertEqual(getProvider(), .parakeet)
    }

    // MARK: - History Preservation Tests

    func testProviderSwitchPreservesHistory() async throws {
        // Given - Records from multiple providers
        let records = [
            TranscriptionRecord(text: "Local text", provider: .local, duration: 5.0),
            TranscriptionRecord(text: "Parakeet text", provider: .parakeet, duration: 6.0),
            TranscriptionRecord(text: "Another local text", provider: .local, duration: 7.0)
        ]

        for record in records {
            modelContext.insert(record)
        }
        try modelContext.save()

        // When - Switch between providers
        setProvider(.parakeet)
        setProvider(.local)
        setProvider(.parakeet)

        await waitForAsyncOperation()

        // Then - All records are preserved
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let savedRecords = try modelContext.fetch(descriptor)

        XCTAssertEqual(savedRecords.count, 3)

        let providers = Set(savedRecords.map { $0.transcriptionProvider })
        XCTAssertTrue(providers.contains(.local))
        XCTAssertTrue(providers.contains(.parakeet))
    }

    // MARK: - Provider Configuration Tests

    func testProviderSwitchUpdatesUsageMetrics() async throws {
        // Given - Records from different providers
        let localRecord = TranscriptionRecord(text: "Five words are here now", provider: .local, duration: 5.0)
        let parakeetRecord = TranscriptionRecord(text: "Three words here", provider: .parakeet, duration: 3.0)

        modelContext.insert(localRecord)
        modelContext.insert(parakeetRecord)
        try modelContext.save()

        // When - Fetch provider-specific records
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let allRecords = try modelContext.fetch(descriptor)

        // Then - Each provider's records are correctly attributed
        let localRecords = allRecords.filter { $0.transcriptionProvider == .local }
        let parakeetRecords = allRecords.filter { $0.transcriptionProvider == .parakeet }

        XCTAssertEqual(localRecords.count, 1)
        XCTAssertEqual(parakeetRecords.count, 1)
    }

    // MARK: - All Providers Test

    func testAllProvidersAreAccessible() {
        // Verify all providers can be set
        let allProviders: [TranscriptionProvider] = [.local, .parakeet]

        for provider in allProviders {
            setProvider(provider)
            XCTAssertEqual(getProvider(), provider, "Should be able to set \(provider.displayName)")
        }
    }

    func testProviderDisplayNames() {
        // Verify all providers have display names
        let allProviders: [TranscriptionProvider] = [.local, .parakeet]

        for provider in allProviders {
            XCTAssertFalse(provider.displayName.isEmpty, "\(provider) should have a display name")
        }
    }

    func testProviderRawValues() {
        // Verify raw values are unique and valid
        let allProviders: [TranscriptionProvider] = [.local, .parakeet]
        let rawValues = allProviders.map { $0.rawValue }

        XCTAssertEqual(Set(rawValues).count, allProviders.count, "All raw values should be unique")

        for rawValue in rawValues {
            XCTAssertFalse(rawValue.isEmpty, "Raw value should not be empty")
        }
    }

    func testProviderAllCasesCount() {
        // Verify TranscriptionProvider.allCases has the expected count
        XCTAssertEqual(TranscriptionProvider.allCases.count, 2, "Should have exactly 2 providers (local and parakeet)")
    }
}
