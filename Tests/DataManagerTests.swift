import XCTest
import SwiftData
@testable import AudioWhisper

@MainActor
final class DataManagerTests: XCTestCase {
    var dataManager: MockDataManager!
    
    override func setUp() async throws {
        try await super.setUp()
        dataManager = MockDataManager()
        try? dataManager.initialize()
    }
    
    override func tearDown() async throws {
        dataManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testDataManagerInitialization() throws {
        let manager = MockDataManager()
        XCTAssertNoThrow(try manager.initialize())
    }
    
    // MARK: - Save Transcription Tests
    
    func testSaveTranscriptionWhenHistoryEnabled() async throws {
        dataManager.isHistoryEnabled = true
        
        let record = TranscriptionRecord(
            text: "Test transcription",
            provider: .openai,
            duration: 5.0,
            modelUsed: "whisper-1"
        )
        
        try await dataManager.saveTranscription(record)
        
        let records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.text, "Test transcription")
        XCTAssertEqual(records.first?.provider, "openai")
    }
    
    func testSaveTranscriptionWhenHistoryDisabled() async throws {
        dataManager.isHistoryEnabled = false
        
        let record = TranscriptionRecord(
            text: "Test transcription",
            provider: .openai
        )
        
        try await dataManager.saveTranscription(record)
        
        let records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 0)
    }
    
    func testSaveTranscriptionQuietly() async {
        dataManager.isHistoryEnabled = true
        
        let record = TranscriptionRecord(
            text: "Test transcription",
            provider: .openai
        )
        
        await dataManager.saveTranscriptionQuietly(record)
        
        let records = await dataManager.fetchAllRecordsQuietly()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.text, "Test transcription")
    }
    
    // MARK: - Fetch Records Tests
    
    func testFetchAllRecordsEmpty() async throws {
        let records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 0)
    }
    
    func testFetchAllRecordsWithData() async throws {
        dataManager.isHistoryEnabled = true
        
        // Add multiple records
        let record1 = TranscriptionRecord(text: "First", provider: .openai)
        let record2 = TranscriptionRecord(text: "Second", provider: .gemini)
        
        try await dataManager.saveTranscription(record1)
        try await dataManager.saveTranscription(record2)
        
        let records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 2)
        
        // Should be sorted by date (newest first)
        XCTAssertEqual(records.first?.text, "Second")
        XCTAssertEqual(records.last?.text, "First")
    }
    
    func testFetchAllRecordsQuietly() async {
        dataManager.isHistoryEnabled = true
        
        let record = TranscriptionRecord(text: "Test", provider: .openai)
        await dataManager.saveTranscriptionQuietly(record)
        
        let records = await dataManager.fetchAllRecordsQuietly()
        XCTAssertEqual(records.count, 1)
    }
    
    // MARK: - Search Tests
    
    func testFetchRecordsWithSearchQuery() async throws {
        dataManager.isHistoryEnabled = true
        
        let record1 = TranscriptionRecord(text: "Meeting notes about Swift programming", provider: .openai)
        let record2 = TranscriptionRecord(text: "Python tutorial transcript", provider: .gemini)
        let record3 = TranscriptionRecord(text: "Swift development discussion", provider: .local)
        
        try await dataManager.saveTranscription(record1)
        try await dataManager.saveTranscription(record2)
        try await dataManager.saveTranscription(record3)
        
        // Search for Swift-related records
        let swiftRecords = try await dataManager.fetchRecords(matching: "Swift")
        XCTAssertEqual(swiftRecords.count, 2)
        
        // Search for Python-related records
        let pythonRecords = try await dataManager.fetchRecords(matching: "Python")
        XCTAssertEqual(pythonRecords.count, 1)
        
        // Search for non-existent term
        let noResults = try await dataManager.fetchRecords(matching: "JavaScript")
        XCTAssertEqual(noResults.count, 0)
        
        // Empty query should return all records
        let allRecords = try await dataManager.fetchRecords(matching: "")
        XCTAssertEqual(allRecords.count, 3)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteSingleRecord() async throws {
        dataManager.isHistoryEnabled = true
        
        let record1 = TranscriptionRecord(text: "First", provider: .openai)
        let record2 = TranscriptionRecord(text: "Second", provider: .gemini)
        
        try await dataManager.saveTranscription(record1)
        try await dataManager.saveTranscription(record2)
        
        var records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 2)
        
        // Delete one record
        try await dataManager.deleteRecord(record1)
        
        records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.text, "Second")
    }
    
    func testDeleteAllRecords() async throws {
        dataManager.isHistoryEnabled = true
        
        let record1 = TranscriptionRecord(text: "First", provider: .openai)
        let record2 = TranscriptionRecord(text: "Second", provider: .gemini)
        
        try await dataManager.saveTranscription(record1)
        try await dataManager.saveTranscription(record2)
        
        var records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 2)
        
        // Delete all records
        try await dataManager.deleteAllRecords()
        
        records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 0)
    }
    
    // MARK: - Retention Policy Tests
    
    func testRetentionPeriodEnum() {
        XCTAssertEqual(RetentionPeriod.oneWeek.displayName, "1 Week")
        XCTAssertEqual(RetentionPeriod.oneMonth.displayName, "1 Month")
        XCTAssertEqual(RetentionPeriod.threeMonths.displayName, "3 Months")
        XCTAssertEqual(RetentionPeriod.forever.displayName, "Forever")
        
        XCTAssertNotNil(RetentionPeriod.oneWeek.timeInterval)
        XCTAssertNotNil(RetentionPeriod.oneMonth.timeInterval)
        XCTAssertNotNil(RetentionPeriod.threeMonths.timeInterval)
        XCTAssertNil(RetentionPeriod.forever.timeInterval)
        
        // Test time intervals are reasonable
        XCTAssertEqual(RetentionPeriod.oneWeek.timeInterval, 7 * 24 * 60 * 60)
        XCTAssertEqual(RetentionPeriod.oneMonth.timeInterval, 30 * 24 * 60 * 60)
        XCTAssertEqual(RetentionPeriod.threeMonths.timeInterval, 90 * 24 * 60 * 60)
    }
    
    func testCleanupExpiredRecordsWithForeverRetention() async throws {
        dataManager.retentionPeriod = .forever
        dataManager.isHistoryEnabled = true
        
        // Create an old record
        let oldRecord = TranscriptionRecord(text: "Old record", provider: .openai)
        try await dataManager.saveTranscription(oldRecord)
        
        // Cleanup should not remove anything
        try await dataManager.cleanupExpiredRecords()
        
        let records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 1)
    }
    
    func testCleanupExpiredRecordsWithTimeBasedRetention() async throws {
        dataManager.retentionPeriod = .oneWeek
        dataManager.isHistoryEnabled = true
        
        // Create records with different dates
        let recentRecord = TranscriptionRecord(text: "Recent", provider: .openai)
        let oldRecord = TranscriptionRecord(text: "Old", provider: .gemini)
        
        // Manually set an old date for testing
        let oneMonthAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        oldRecord.date = oneMonthAgo
        
        try await dataManager.saveTranscription(recentRecord)
        try await dataManager.saveTranscription(oldRecord)
        
        var records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 2)
        
        // Cleanup should remove the old record
        try await dataManager.cleanupExpiredRecords()
        
        records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.text, "Recent")
    }
    
    func testCleanupExpiredRecordsQuietly() async {
        dataManager.retentionPeriod = .oneWeek
        dataManager.isHistoryEnabled = true
        
        let record = TranscriptionRecord(text: "Test", provider: .openai)
        await dataManager.saveTranscriptionQuietly(record)
        
        // Should not throw
        await dataManager.cleanupExpiredRecordsQuietly()
        
        let records = await dataManager.fetchAllRecordsQuietly()
        XCTAssertEqual(records.count, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testDataManagerErrorDescriptions() {
        let initError = DataManagerError.initializationFailed(NSError(domain: "test", code: 1))
        XCTAssertTrue(initError.errorDescription?.contains("Failed to initialize") == true)
        
        let saveError = DataManagerError.saveFailed(NSError(domain: "test", code: 2))
        XCTAssertTrue(saveError.errorDescription?.contains("Failed to save") == true)
        
        let fetchError = DataManagerError.fetchFailed(NSError(domain: "test", code: 3))
        XCTAssertTrue(fetchError.errorDescription?.contains("Failed to fetch") == true)
        
        let deleteError = DataManagerError.deleteFailed(NSError(domain: "test", code: 4))
        XCTAssertTrue(deleteError.errorDescription?.contains("Failed to delete") == true)
        
        let cleanupError = DataManagerError.cleanupFailed(NSError(domain: "test", code: 5))
        XCTAssertTrue(cleanupError.errorDescription?.contains("Failed to clean up") == true)
        
        let containerError = DataManagerError.modelContainerUnavailable
        XCTAssertEqual(containerError.errorDescription, "Data storage is not available")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentOperations() async throws {
        dataManager.isHistoryEnabled = true
        
        // Perform multiple concurrent saves
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let record = TranscriptionRecord(
                        text: "Concurrent record \(i)",
                        provider: .openai
                    )
                    await self.dataManager.saveTranscriptionQuietly(record)
                }
            }
        }
        
        let records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 10)
    }
    
    // MARK: - Integration Tests
    
    func testPaginatedFetchRecords() async throws {
        dataManager.isHistoryEnabled = true
        
        // Create 10 test records with searchable content
        for i in 0..<10 {
            let record = TranscriptionRecord(
                text: "Test record \(i) with searchable content",
                provider: .local,
                duration: Double(i),
                modelUsed: "tiny"
            )
            try await dataManager.saveTranscription(record)
        }
        
        // Test pagination with limit
        let firstBatch = try await dataManager.fetchRecords(matching: "searchable", limit: 3, offset: 0)
        XCTAssertEqual(firstBatch.count, 3, "Should return exactly 3 records")
        
        // Test pagination with offset
        let secondBatch = try await dataManager.fetchRecords(matching: "searchable", limit: 3, offset: 3)
        XCTAssertEqual(secondBatch.count, 3, "Should return next 3 records")
        
        // Verify different records in batches
        let firstIds = Set(firstBatch.map { $0.id })
        let secondIds = Set(secondBatch.map { $0.id })
        XCTAssertTrue(firstIds.isDisjoint(with: secondIds), "Batches should contain different records")
        
        // Test with offset beyond available records - the mock returns the last remaining records
        let lastBatch = try await dataManager.fetchRecords(matching: "searchable", limit: 5, offset: 8)
        XCTAssertEqual(lastBatch.count, 2, "Should return remaining records when offset + limit exceeds total")
        
        // Test without pagination (backward compatibility)
        let allRecords = try await dataManager.fetchRecords(matching: "searchable")
        XCTAssertEqual(allRecords.count, 10, "Should return all matching records without pagination")
    }
    
    func testFullWorkflow() async throws {
        dataManager.isHistoryEnabled = true
        dataManager.retentionPeriod = .oneMonth
        
        // Save multiple transcriptions
        let record1 = TranscriptionRecord(text: "Meeting notes", provider: .openai, duration: 120.0)
        let record2 = TranscriptionRecord(text: "Voice memo", provider: .gemini, duration: 30.0)
        let record3 = TranscriptionRecord(text: "Interview transcript", provider: .local, modelUsed: "small")
        
        try await dataManager.saveTranscription(record1)
        try await dataManager.saveTranscription(record2)
        try await dataManager.saveTranscription(record3)
        
        // Verify all saved
        var allRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(allRecords.count, 3)
        
        // Search for specific content
        let meetingRecords = try await dataManager.fetchRecords(matching: "meeting")
        XCTAssertEqual(meetingRecords.count, 1)
        XCTAssertEqual(meetingRecords.first?.text, "Meeting notes")
        
        // Delete one record
        try await dataManager.deleteRecord(record2)
        allRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(allRecords.count, 2)
        
        // Cleanup (should not remove recent records)
        try await dataManager.cleanupExpiredRecords()
        allRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(allRecords.count, 2)
        
        // Clear all
        try await dataManager.deleteAllRecords()
        allRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(allRecords.count, 0)
    }
}