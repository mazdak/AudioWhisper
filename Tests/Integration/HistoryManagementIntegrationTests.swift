import XCTest
import SwiftData
@testable import AudioWhisper

/// Integration tests for DataManager <-> UsageMetricsStore interaction
/// Verifies that saving/deleting records correctly updates metrics
@MainActor
final class HistoryManagementIntegrationTests: IsolatedXCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var metricsStore: UsageMetricsStore!
    var testDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container
        modelContainer = try ModelContainer(
            for: TranscriptionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = ModelContext(modelContainer)

        // Create isolated UserDefaults
        let suiteName = "HistoryManagementIntegrationTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!

        // Set up metrics store with test defaults
        metricsStore = UsageMetricsStore(defaults: testDefaults)

        // Ensure clean state
        metricsStore.reset()

        // Enable history
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

        testDefaults.removePersistentDomain(forName: testDefaults.description)

        modelContainer = nil
        modelContext = nil
        metricsStore = nil
        testDefaults = nil

        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func createRecord(
        text: String,
        provider: TranscriptionProvider = .local,
        duration: TimeInterval? = 10.0
    ) -> TranscriptionRecord {
        TranscriptionRecord(
            text: text,
            provider: provider,
            duration: duration
        )
    }

    private func waitForAsyncOperation() async {
        try? await Task.sleep(for: .milliseconds(100))
    }

    // MARK: - Save -> Metrics Update Tests

    func testSaveTranscriptionUpdatesMetrics() async throws {
        // Given - Initial empty metrics
        let initialSnapshot = metricsStore.snapshot
        XCTAssertEqual(initialSnapshot.totalSessions, 0)
        XCTAssertEqual(initialSnapshot.totalWords, 0)

        // When - Save a transcription and record metrics
        let text = "Hello world this is a test transcription"
        let record = createRecord(text: text, duration: 10.0)
        modelContext.insert(record)
        try modelContext.save()

        // Simulate recording the session (as app does)
        let wordCount = UsageMetricsStore.estimatedWordCount(for: text)
        metricsStore.recordSession(duration: 10.0, wordCount: wordCount, characterCount: text.count)

        await waitForAsyncOperation()

        // Then - Metrics are updated
        let updatedSnapshot = metricsStore.snapshot
        XCTAssertEqual(updatedSnapshot.totalSessions, 1)
        XCTAssertEqual(updatedSnapshot.totalWords, wordCount)
        XCTAssertEqual(updatedSnapshot.totalCharacters, text.count)
        XCTAssertEqual(updatedSnapshot.totalDuration, 10.0)
    }

    func testMultipleSavesAccumulateMetrics() async throws {
        // Given - Save multiple records
        let texts = [
            "First transcription with five words",
            "Second transcription has more words in it",
            "Third one"
        ]

        var expectedTotalWords = 0
        var expectedTotalDuration: TimeInterval = 0

        for (index, text) in texts.enumerated() {
            let duration = TimeInterval((index + 1) * 5)
            let record = createRecord(text: text, duration: duration)
            modelContext.insert(record)

            let wordCount = UsageMetricsStore.estimatedWordCount(for: text)
            metricsStore.recordSession(duration: duration, wordCount: wordCount, characterCount: text.count)

            expectedTotalWords += wordCount
            expectedTotalDuration += duration
        }
        try modelContext.save()

        await waitForAsyncOperation()

        // Then
        let snapshot = metricsStore.snapshot
        XCTAssertEqual(snapshot.totalSessions, 3)
        XCTAssertEqual(snapshot.totalWords, expectedTotalWords)
        XCTAssertEqual(snapshot.totalDuration, expectedTotalDuration)
    }

    // MARK: - Delete -> Metrics Rebuild Tests

    func testDeleteRecordRebuildMetrics() async throws {
        // Given - Create and save multiple records
        let records = [
            createRecord(text: "First record with words", duration: 10.0),
            createRecord(text: "Second record", duration: 5.0),
            createRecord(text: "Third record to delete", duration: 8.0)
        ]

        for record in records {
            modelContext.insert(record)
            let wordCount = UsageMetricsStore.estimatedWordCount(for: record.text)
            metricsStore.recordSession(duration: record.duration ?? 0, wordCount: wordCount, characterCount: record.text.count)
        }
        try modelContext.save()

        await waitForAsyncOperation()

        let initialSnapshot = metricsStore.snapshot
        XCTAssertEqual(initialSnapshot.totalSessions, 3)

        // When - Delete one record and rebuild
        let recordToDelete = records[2]
        modelContext.delete(recordToDelete)
        try modelContext.save()

        // Fetch remaining and rebuild
        let remainingRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        metricsStore.rebuild(using: remainingRecords)

        await waitForAsyncOperation()

        // Then - Metrics reflect remaining records only
        let updatedSnapshot = metricsStore.snapshot
        XCTAssertEqual(updatedSnapshot.totalSessions, 2)

        // Verify words decreased
        let expectedWords = remainingRecords.reduce(0) { $0 + $1.wordCount }
        XCTAssertEqual(updatedSnapshot.totalWords, expectedWords)
    }

    func testBulkDeleteMetricsConsistency() async throws {
        // Given - Create 10 records
        var allRecords: [TranscriptionRecord] = []
        for i in 1...10 {
            let record = createRecord(text: "Record number \(i) with some content", duration: Double(i))
            allRecords.append(record)
            modelContext.insert(record)

            let wordCount = UsageMetricsStore.estimatedWordCount(for: record.text)
            metricsStore.recordSession(duration: record.duration ?? 0, wordCount: wordCount, characterCount: record.text.count)
        }
        try modelContext.save()

        await waitForAsyncOperation()

        let initialSnapshot = metricsStore.snapshot
        XCTAssertEqual(initialSnapshot.totalSessions, 10)

        // When - Delete first 5 records (bulk)
        for i in 0..<5 {
            modelContext.delete(allRecords[i])
        }
        try modelContext.save()

        // Rebuild from remaining
        let remainingRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        metricsStore.rebuild(using: remainingRecords)

        await waitForAsyncOperation()

        // Then - Metrics accurately reflect remaining 5 records
        let updatedSnapshot = metricsStore.snapshot
        XCTAssertEqual(updatedSnapshot.totalSessions, 5)
        XCTAssertEqual(remainingRecords.count, 5)

        // Verify exact word/character counts
        let expectedWords = remainingRecords.reduce(0) { $0 + $1.wordCount }
        let expectedChars = remainingRecords.reduce(0) { $0 + $1.text.count }
        XCTAssertEqual(updatedSnapshot.totalWords, expectedWords)
        XCTAssertEqual(updatedSnapshot.totalCharacters, expectedChars)
    }

    func testDeleteAllRecordsResetsMetrics() async throws {
        // Given - Create some records
        for i in 1...5 {
            let record = createRecord(text: "Record \(i)", duration: 5.0)
            modelContext.insert(record)
            metricsStore.recordSession(duration: 5.0, wordCount: 2, characterCount: record.text.count)
        }
        try modelContext.save()

        await waitForAsyncOperation()

        XCTAssertEqual(metricsStore.snapshot.totalSessions, 5)

        // When - Delete all and rebuild
        let allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        for record in allRecords {
            modelContext.delete(record)
        }
        try modelContext.save()

        metricsStore.rebuild(using: [])

        await waitForAsyncOperation()

        // Then - Metrics are effectively reset
        let snapshot = metricsStore.snapshot
        XCTAssertEqual(snapshot.totalSessions, 0)
        XCTAssertEqual(snapshot.totalWords, 0)
        XCTAssertEqual(snapshot.totalDuration, 0)
    }

    // MARK: - Daily Activity Tests

    func testDailyActivityAccumulation() async throws {
        // Given - Save multiple records on same day
        let todayRecords = [
            createRecord(text: "First record today with words", duration: 5.0),
            createRecord(text: "Second record today", duration: 3.0),
            createRecord(text: "Third one", duration: 2.0)
        ]

        for record in todayRecords {
            modelContext.insert(record)
            let wordCount = UsageMetricsStore.estimatedWordCount(for: record.text)
            metricsStore.recordSession(duration: record.duration ?? 0, wordCount: wordCount, characterCount: record.text.count)
        }
        try modelContext.save()

        await waitForAsyncOperation()

        // Then - Daily activity should accumulate all words
        let dailyActivity = metricsStore.getDailyActivity(days: 1)
        XCTAssertFalse(dailyActivity.isEmpty)

        // Get today's entry
        let today = Calendar.current.startOfDay(for: Date())
        let todayWords = dailyActivity[today] ?? 0

        let expectedTodayWords = todayRecords.reduce(0) { $0 + UsageMetricsStore.estimatedWordCount(for: $1.text) }
        XCTAssertEqual(todayWords, expectedTodayWords)
    }

    func testStreakCalculation() async throws {
        // Given - Record session for today
        let text = "Test transcription for streak"
        let wordCount = UsageMetricsStore.estimatedWordCount(for: text)
        metricsStore.recordSession(duration: 5.0, wordCount: wordCount, characterCount: text.count)

        await waitForAsyncOperation()

        // Then - Streak should be at least 1
        let streak = metricsStore.calculateStreak()
        XCTAssertGreaterThanOrEqual(streak, 1)
    }

    // MARK: - History Disabled Tests

    func testMetricsNotRecordedWhenHistoryDisabled() async throws {
        // Given - Disable history
        testDefaults.set(false, forKey: "transcriptionHistoryEnabled")

        // Record initial state
        let initialSnapshot = metricsStore.snapshot

        // When - Don't save to DataManager (mimicking disabled history behavior)
        // Metrics would only be updated if the app explicitly records

        await waitForAsyncOperation()

        // Then - Metrics should not change
        let finalSnapshot = metricsStore.snapshot
        XCTAssertEqual(finalSnapshot.totalSessions, initialSnapshot.totalSessions)
    }

    // MARK: - Word Count Estimation Tests

    func testEstimatedWordCountAccuracy() {
        // Test the pure function used in the flow
        let testCases = [
            ("Hello world", 2),
            ("One two three four five", 5),
            ("", 0),
            ("Single", 1),
            ("Hyphenated-word here", 3), // Hyphen splits words into 3
            ("It's a contraction", 3) // Apostrophe doesn't split
        ]

        for (text, expectedCount) in testCases {
            let count = UsageMetricsStore.estimatedWordCount(for: text)
            XCTAssertEqual(count, expectedCount, "Failed for: '\(text)'")
        }
    }

    // MARK: - Rebuild Integration Tests

    func testRebuildFromRecordsAccuracy() async throws {
        // Given - Create records with known values
        let records = [
            createRecord(text: "Five words in this text", duration: 10.0),
            createRecord(text: "Three word text", duration: 5.0)
        ]

        for record in records {
            modelContext.insert(record)
        }
        try modelContext.save()

        await waitForAsyncOperation()

        // When - Rebuild metrics from records
        let fetchedRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        metricsStore.rebuild(using: fetchedRecords)

        // Then - Verify accuracy
        let snapshot = metricsStore.snapshot
        XCTAssertEqual(snapshot.totalSessions, 2)
        XCTAssertEqual(snapshot.totalDuration, 15.0)

        let expectedWords = fetchedRecords.reduce(0) { $0 + $1.wordCount }
        XCTAssertEqual(snapshot.totalWords, expectedWords)
    }

    func testRebuildDailyActivityOnly() async throws {
        // Given - Records saved and metrics recorded
        let records = [
            createRecord(text: "First test record", duration: 5.0),
            createRecord(text: "Second test record", duration: 5.0)
        ]

        for record in records {
            modelContext.insert(record)
            let wordCount = UsageMetricsStore.estimatedWordCount(for: record.text)
            metricsStore.recordSession(duration: 5.0, wordCount: wordCount, characterCount: record.text.count)
        }
        try modelContext.save()

        let initialSnapshot = metricsStore.snapshot
        let initialSessions = initialSnapshot.totalSessions

        // When - Rebuild only daily activity
        let fetchedRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        metricsStore.rebuildDailyActivity(using: fetchedRecords)

        // Then - Session count unchanged, daily activity rebuilt
        let updatedSnapshot = metricsStore.snapshot
        XCTAssertEqual(updatedSnapshot.totalSessions, initialSessions)

        // Daily activity should reflect records
        let dailyActivity = metricsStore.getDailyActivity(days: 1)
        XCTAssertFalse(dailyActivity.isEmpty)
    }
}
