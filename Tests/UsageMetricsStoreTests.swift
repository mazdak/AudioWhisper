import XCTest
import SwiftData
@testable import AudioWhisper

@MainActor
final class UsageMetricsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: UsageMetricsStore!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "UsageMetricsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = UsageMetricsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        suiteName = nil
        super.tearDown()
    }

    func testRecordSessionAccumulatesTotals() {
        XCTAssertEqual(store.snapshot.totalSessions, 0)

        store.recordSession(duration: 30, wordCount: 120, characterCount: 600)

        XCTAssertEqual(store.snapshot.totalSessions, 1)
        XCTAssertEqual(store.snapshot.totalWords, 120)
        XCTAssertEqual(store.snapshot.totalCharacters, 600)
        XCTAssertEqual(store.snapshot.totalDuration, 30, accuracy: 0.1)
        XCTAssertGreaterThan(store.snapshot.wordsPerMinute, 0)
        XCTAssertGreaterThan(store.snapshot.keystrokesSaved, 0)
    }

    func testResetClearsSnapshot() {
        store.recordSession(duration: 10, wordCount: 50, characterCount: 250)
        store.reset()

        XCTAssertEqual(store.snapshot.totalSessions, 0)
        XCTAssertEqual(store.snapshot.totalWords, 0)
        XCTAssertEqual(store.snapshot.totalDuration, 0)
        XCTAssertEqual(store.snapshot.keystrokesSaved, 0)
    }

    func testEstimatedWordCount() {
        let text = "Don't stop 42 times -- seriously!"
        let count = UsageMetricsStore.estimatedWordCount(for: text)
        XCTAssertEqual(count, 5)

        XCTAssertEqual(UsageMetricsStore.estimatedWordCount(for: ""), 0)
    }

    func testBootstrapLoadsHistoryWhenEmpty() async {
        let mockDataManager = TestDataManager()
        mockDataManager.isHistoryEnabled = true

        let record = TranscriptionRecord(
            text: "Hello world",
            provider: .openai,
            duration: 12,
            modelUsed: nil,
            wordCount: 2
        )
        mockDataManager.records = [record]

        await store.bootstrapIfNeeded(dataManager: mockDataManager)

        XCTAssertEqual(store.snapshot.totalSessions, 1)
        XCTAssertEqual(store.snapshot.totalWords, 2)
        XCTAssertEqual(store.snapshot.totalDuration, 12, accuracy: 0.1)
    }

    func testBootstrapSkipsWhenCountersPresent() async {
        store.recordSession(duration: 5, wordCount: 10, characterCount: 50)

        let mockDataManager = TestDataManager()
        mockDataManager.isHistoryEnabled = true
        mockDataManager.records = [
            TranscriptionRecord(text: "ignored", provider: .openai, duration: 30, modelUsed: nil, wordCount: 5)
        ]

        await store.bootstrapIfNeeded(dataManager: mockDataManager)

        // Should remain unchanged because snapshot already had data.
        XCTAssertEqual(store.snapshot.totalSessions, 1)
        XCTAssertEqual(store.snapshot.totalWords, 10)
    }

}

@MainActor
private final class TestDataManager: DataManagerProtocol {
    var isHistoryEnabled: Bool = true
    var retentionPeriod: RetentionPeriod = .oneMonth
    var sharedModelContainer: ModelContainer? { nil }

    var records: [TranscriptionRecord] = []

    func initialize() throws {}

    func saveTranscription(_ record: TranscriptionRecord) async throws {
        records.append(record)
    }

    func fetchAllRecords() async throws -> [TranscriptionRecord] {
        records
    }

    func fetchRecords(matching searchQuery: String) async throws -> [TranscriptionRecord] {
        records
    }

    func fetchRecords(matching searchQuery: String, limit: Int?, offset: Int?) async throws -> [TranscriptionRecord] {
        records
    }

    func deleteRecord(_ record: TranscriptionRecord) async throws {
        records.removeAll { $0.id == record.id }
    }

    func deleteAllRecords() async throws {
        records.removeAll()
    }

    func cleanupExpiredRecords() async throws {}

    func saveTranscriptionQuietly(_ record: TranscriptionRecord) async {
        records.append(record)
    }

    func fetchAllRecordsQuietly() async -> [TranscriptionRecord] {
        records
    }

    func cleanupExpiredRecordsQuietly() async {}
}
