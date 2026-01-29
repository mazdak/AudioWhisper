import Foundation
import SwiftData
@testable import AudioWhisper

/// Mock implementation for DataManager to avoid SwiftData operations in tests
@MainActor
final class MockDataManager: DataManagerProtocol {
    // MARK: - State

    var isHistoryEnabled: Bool = true
    var retentionPeriod: RetentionPeriod = .oneMonth
    var sharedModelContainer: ModelContainer?

    // MARK: - Configurable Data

    var recordsToReturn: [TranscriptionRecord] = []
    var shouldThrowOnSave = false
    var shouldThrowOnFetch = false
    var shouldThrowOnDelete = false
    var errorToThrow: Error = NSError(domain: "MockDataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])

    // MARK: - Call Tracking

    var initializeCallCount = 0
    var saveTranscriptionCallCount = 0
    var saveTranscriptionLastRecord: TranscriptionRecord?
    var fetchAllRecordsCallCount = 0
    var fetchRecordsCallCount = 0
    var fetchRecordsLastQuery: String?
    var deleteRecordCallCount = 0
    var deleteRecordLastRecord: TranscriptionRecord?
    var deleteAllRecordsCallCount = 0
    var cleanupExpiredRecordsCallCount = 0
    var saveTranscriptionQuietlyCallCount = 0
    var fetchAllRecordsQuietlyCallCount = 0
    var cleanupExpiredRecordsQuietlyCallCount = 0

    // MARK: - Protocol Methods

    func initialize() throws {
        initializeCallCount += 1
    }

    func saveTranscription(_ record: TranscriptionRecord) async throws {
        saveTranscriptionCallCount += 1
        saveTranscriptionLastRecord = record

        // Skip saving if history is disabled
        guard isHistoryEnabled else { return }

        if shouldThrowOnSave {
            throw errorToThrow
        }

        recordsToReturn.append(record)
    }

    func fetchAllRecords() async throws -> [TranscriptionRecord] {
        fetchAllRecordsCallCount += 1

        if shouldThrowOnFetch {
            throw errorToThrow
        }

        // Sort by date descending (newest first) to match real DataManager behavior
        return recordsToReturn.sorted { $0.date > $1.date }
    }

    func fetchRecords(matching searchQuery: String) async throws -> [TranscriptionRecord] {
        fetchRecordsCallCount += 1
        fetchRecordsLastQuery = searchQuery

        if shouldThrowOnFetch {
            throw errorToThrow
        }

        // Sort by date descending (newest first)
        let sorted = recordsToReturn.sorted { $0.date > $1.date }

        if searchQuery.isEmpty {
            return sorted
        }

        return sorted.filter { record in
            record.text.localizedCaseInsensitiveContains(searchQuery) ||
            record.provider.localizedCaseInsensitiveContains(searchQuery) ||
            (record.modelUsed?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }

    func fetchRecords(matching searchQuery: String, limit: Int?, offset: Int?) async throws -> [TranscriptionRecord] {
        fetchRecordsCallCount += 1
        fetchRecordsLastQuery = searchQuery

        if shouldThrowOnFetch {
            throw errorToThrow
        }

        // Sort by date descending (newest first)
        var results = recordsToReturn.sorted { $0.date > $1.date }

        if !searchQuery.isEmpty {
            results = results.filter { record in
                record.text.localizedCaseInsensitiveContains(searchQuery) ||
                record.provider.localizedCaseInsensitiveContains(searchQuery) ||
                (record.modelUsed?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }

        if let offset = offset {
            results = Array(results.dropFirst(offset))
        }

        if let limit = limit {
            results = Array(results.prefix(limit))
        }

        return results
    }

    func deleteRecord(_ record: TranscriptionRecord) async throws {
        deleteRecordCallCount += 1
        deleteRecordLastRecord = record

        if shouldThrowOnDelete {
            throw errorToThrow
        }

        recordsToReturn.removeAll { $0.id == record.id }
    }

    func deleteAllRecords() async throws {
        deleteAllRecordsCallCount += 1

        if shouldThrowOnDelete {
            throw errorToThrow
        }

        recordsToReturn.removeAll()
    }

    func cleanupExpiredRecords() async throws {
        cleanupExpiredRecordsCallCount += 1

        // Skip if retention is forever
        guard let timeInterval = retentionPeriod.timeInterval else { return }

        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        recordsToReturn.removeAll { $0.date < cutoffDate }
    }

    // MARK: - Quiet Methods (no throwing)

    func saveTranscriptionQuietly(_ record: TranscriptionRecord) async {
        saveTranscriptionQuietlyCallCount += 1
        saveTranscriptionLastRecord = record

        // Skip saving if history is disabled
        guard isHistoryEnabled else { return }

        if !shouldThrowOnSave {
            recordsToReturn.append(record)
        }
    }

    func fetchAllRecordsQuietly() async -> [TranscriptionRecord] {
        fetchAllRecordsQuietlyCallCount += 1
        if shouldThrowOnFetch {
            return []
        }
        // Sort by date descending (newest first) to match real DataManager behavior
        return recordsToReturn.sorted { $0.date > $1.date }
    }

    func cleanupExpiredRecordsQuietly() async {
        cleanupExpiredRecordsQuietlyCallCount += 1

        // Skip if retention is forever
        guard let timeInterval = retentionPeriod.timeInterval else { return }

        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        recordsToReturn.removeAll { $0.date < cutoffDate }
    }

    // MARK: - Test Helpers

    func reset() {
        isHistoryEnabled = true
        retentionPeriod = .oneMonth
        sharedModelContainer = nil
        recordsToReturn = []
        shouldThrowOnSave = false
        shouldThrowOnFetch = false
        shouldThrowOnDelete = false

        initializeCallCount = 0
        saveTranscriptionCallCount = 0
        saveTranscriptionLastRecord = nil
        fetchAllRecordsCallCount = 0
        fetchRecordsCallCount = 0
        fetchRecordsLastQuery = nil
        deleteRecordCallCount = 0
        deleteRecordLastRecord = nil
        deleteAllRecordsCallCount = 0
        cleanupExpiredRecordsCallCount = 0
        saveTranscriptionQuietlyCallCount = 0
        fetchAllRecordsQuietlyCallCount = 0
        cleanupExpiredRecordsQuietlyCallCount = 0
    }

    func addRecord(_ record: TranscriptionRecord) {
        recordsToReturn.append(record)
    }

    func addRecords(_ records: [TranscriptionRecord]) {
        recordsToReturn.append(contentsOf: records)
    }

    func setHistoryEnabled(_ enabled: Bool) {
        isHistoryEnabled = enabled
    }

    /// Create a test record with default values
    static func makeTestRecord(
        text: String = "Test transcription",
        duration: TimeInterval? = 5.0,
        provider: TranscriptionProvider = .local,
        sourceAppBundleId: String? = "com.apple.Notes",
        sourceAppName: String? = "Notes"
    ) -> TranscriptionRecord {
        TranscriptionRecord(
            text: text,
            provider: provider,
            duration: duration,
            sourceAppBundleId: sourceAppBundleId,
            sourceAppName: sourceAppName,
            sourceAppIconData: nil
        )
    }
}
