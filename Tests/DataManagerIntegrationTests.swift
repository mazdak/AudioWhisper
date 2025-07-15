import XCTest
import SwiftData
@testable import AudioWhisper

@MainActor
final class DataManagerIntegrationTests: XCTestCase {
    var dataManager: MockDataManager!
    var realDataManager: DataManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Set up mock data manager for controlled testing
        dataManager = MockDataManager()
        try dataManager.initialize()
        
        // Also test with real DataManager in some cases
        realDataManager = DataManager.shared as? DataManager
        
        // Ensure history is enabled for tests
        UserDefaults.standard.set(true, forKey: "transcriptionHistoryEnabled")
        UserDefaults.standard.set(RetentionPeriod.forever.rawValue, forKey: "transcriptionRetentionPeriod")
    }
    
    override func tearDown() async throws {
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "transcriptionHistoryEnabled")
        UserDefaults.standard.removeObject(forKey: "transcriptionRetentionPeriod")
        
        dataManager = nil
        realDataManager = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createSampleRecord(
        text: String = "Sample transcription",
        provider: TranscriptionProvider = .openai,
        duration: TimeInterval? = 10.5,
        modelUsed: String? = nil
    ) -> TranscriptionRecord {
        return TranscriptionRecord(
            text: text,
            provider: provider,
            duration: duration,
            modelUsed: modelUsed
        )
    }
    
    private func waitForAsyncOperation() async {
        // Small delay to ensure async operations complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    // MARK: - DataManager Protocol Integration Tests
    
    func testDataManagerProtocolConformance() async throws {
        // Test that DataManager conforms to protocol correctly
        XCTAssertTrue(dataManager.isHistoryEnabled, "History should be enabled by default in tests")
        XCTAssertEqual(dataManager.retentionPeriod, .oneMonth, "Default retention should be one month")
        
        // Test that we can change settings
        dataManager.retentionPeriod = .threeMonths
        XCTAssertEqual(dataManager.retentionPeriod, .threeMonths, "Retention period should be changeable")
        
        dataManager.isHistoryEnabled = false
        XCTAssertFalse(dataManager.isHistoryEnabled, "History enabled should be changeable")
    }
    
    func testSaveTranscriptionIntegration() async throws {
        // Test full save workflow with DataManager
        let record = createSampleRecord(
            text: "DataManager integration test",
            provider: .gemini,
            duration: 25.5,
            modelUsed: "advanced"
        )
        
        // When - Save using DataManager
        try await dataManager.saveTranscription(record)
        
        await waitForAsyncOperation()
        
        // Then - Verify record was saved
        let savedRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(savedRecords.count, 1, "Should have saved one record")
        
        let savedRecord = savedRecords[0]
        XCTAssertEqual(savedRecord.text, "DataManager integration test")
        XCTAssertEqual(savedRecord.provider, "gemini")
        XCTAssertEqual(savedRecord.duration, 25.5)
        XCTAssertEqual(savedRecord.modelUsed, "advanced")
    }
    
    func testSaveTranscriptionWhenHistoryDisabled() async throws {
        // Given - Disable history
        dataManager.isHistoryEnabled = false
        
        let record = createSampleRecord(text: "Should not be saved")
        
        // When - Attempt to save
        try await dataManager.saveTranscription(record)
        
        await waitForAsyncOperation()
        
        // Then - Verify record was not saved
        let savedRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(savedRecords.count, 0, "No records should be saved when history is disabled")
    }
    
    func testFetchRecordsIntegration() async throws {
        // Given - Multiple records
        let records = [
            createSampleRecord(text: "First record for fetch test", provider: .openai),
            createSampleRecord(text: "Second record for fetch test", provider: .local),
            createSampleRecord(text: "Third record for fetch test", provider: .parakeet)
        ]
        
        for record in records {
            try await dataManager.saveTranscription(record)
        }
        
        await waitForAsyncOperation()
        
        // When - Fetch all records
        let fetchedRecords = try await dataManager.fetchAllRecords()
        
        // Then - Verify correct order and content
        XCTAssertEqual(fetchedRecords.count, 3, "Should fetch all saved records")
        
        // Records should be sorted by date (newest first)
        XCTAssertEqual(fetchedRecords[0].text, "Third record for fetch test")
        XCTAssertEqual(fetchedRecords[1].text, "Second record for fetch test")
        XCTAssertEqual(fetchedRecords[2].text, "First record for fetch test")
    }
    
    func testSearchIntegration() async throws {
        // Given - Records with searchable content
        let records = [
            createSampleRecord(text: "Meeting about Swift development", provider: .openai),
            createSampleRecord(text: "Python tutorial for beginners", provider: .gemini),
            createSampleRecord(text: "Swift programming best practices", provider: .local),
            createSampleRecord(text: "Database design principles", provider: .parakeet)
        ]
        
        for record in records {
            try await dataManager.saveTranscription(record)
        }
        
        await waitForAsyncOperation()
        
        // Test various search scenarios
        let swiftResults = try await dataManager.fetchRecords(matching: "Swift")
        XCTAssertEqual(swiftResults.count, 2, "Should find 2 Swift-related records")
        
        let pythonResults = try await dataManager.fetchRecords(matching: "Python")
        XCTAssertEqual(pythonResults.count, 1, "Should find 1 Python-related record")
        
        let openaiResults = try await dataManager.fetchRecords(matching: "openai")
        XCTAssertEqual(openaiResults.count, 1, "Should find 1 OpenAI record")
        
        let noResults = try await dataManager.fetchRecords(matching: "JavaScript")
        XCTAssertEqual(noResults.count, 0, "Should find no JavaScript records")
        
        let allResults = try await dataManager.fetchRecords(matching: "")
        XCTAssertEqual(allResults.count, 4, "Empty search should return all records")
    }
    
    func testDeleteRecordIntegration() async throws {
        // Given - Multiple records
        let records = [
            createSampleRecord(text: "Keep this record", provider: .openai),
            createSampleRecord(text: "Delete this record", provider: .gemini),
            createSampleRecord(text: "Keep this one too", provider: .local)
        ]
        
        for record in records {
            try await dataManager.saveTranscription(record)
        }
        
        await waitForAsyncOperation()
        
        var allRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(allRecords.count, 3, "Should start with 3 records")
        
        // When - Delete specific record
        let recordToDelete = allRecords.first { $0.text == "Delete this record" }!
        try await dataManager.deleteRecord(recordToDelete)
        
        await waitForAsyncOperation()
        
        // Then - Verify deletion
        allRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(allRecords.count, 2, "Should have 2 records after deletion")
        
        let remainingTexts = allRecords.map { $0.text }
        XCTAssertTrue(remainingTexts.contains("Keep this record"))
        XCTAssertTrue(remainingTexts.contains("Keep this one too"))
        XCTAssertFalse(remainingTexts.contains("Delete this record"))
    }
    
    func testDeleteAllRecordsIntegration() async throws {
        // Given - Multiple records
        let records = [
            createSampleRecord(text: "Record 1", provider: .openai),
            createSampleRecord(text: "Record 2", provider: .gemini),
            createSampleRecord(text: "Record 3", provider: .local)
        ]
        
        for record in records {
            try await dataManager.saveTranscription(record)
        }
        
        await waitForAsyncOperation()
        
        var allRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(allRecords.count, 3, "Should start with 3 records")
        
        // When - Delete all records
        try await dataManager.deleteAllRecords()
        
        await waitForAsyncOperation()
        
        // Then - Verify all deleted
        allRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(allRecords.count, 0, "Should have no records after delete all")
    }
    
    // MARK: - Retention Policy Integration Tests
    
    func testRetentionPolicyCleanup() async throws {
        // Create records with different dates
        let oldDate = Date().addingTimeInterval(-40 * 24 * 60 * 60) // 40 days ago
        let recentDate = Date().addingTimeInterval(-5 * 24 * 60 * 60) // 5 days ago
        
        let oldRecord = createSampleRecord(text: "Old record", provider: .openai)
        oldRecord.date = oldDate
        
        let recentRecord = createSampleRecord(text: "Recent record", provider: .gemini)
        recentRecord.date = recentDate
        
        try await dataManager.saveTranscription(oldRecord)
        try await dataManager.saveTranscription(recentRecord)
        
        await waitForAsyncOperation()
        
        // Set retention period to one month
        dataManager.retentionPeriod = .oneMonth
        
        // When - Perform cleanup
        try await dataManager.cleanupExpiredRecords()
        
        await waitForAsyncOperation()
        
        // Then - Verify old record was removed
        let remainingRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(remainingRecords.count, 1, "Should have 1 record after cleanup")
        XCTAssertEqual(remainingRecords[0].text, "Recent record", "Recent record should remain")
    }
    
    func testForeverRetentionPolicy() async throws {
        // Create old records
        let veryOldDate = Date().addingTimeInterval(-365 * 24 * 60 * 60) // 1 year ago
        
        let veryOldRecord = createSampleRecord(text: "Very old record", provider: .openai)
        veryOldRecord.date = veryOldDate
        
        try await dataManager.saveTranscription(veryOldRecord)
        
        await waitForAsyncOperation()
        
        // Set retention period to forever
        dataManager.retentionPeriod = .forever
        
        // When - Perform cleanup
        try await dataManager.cleanupExpiredRecords()
        
        await waitForAsyncOperation()
        
        // Then - Verify record was NOT removed
        let remainingRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(remainingRecords.count, 1, "Record should be preserved with forever retention")
        XCTAssertEqual(remainingRecords[0].text, "Very old record")
    }
    
    // MARK: - Quiet Operations Integration Tests
    
    func testQuietOperationsIntegration() async {
        // Test that quiet operations don't throw but still work
        let record = createSampleRecord(text: "Quiet operation test", provider: .local)
        
        // Test quiet save
        await dataManager.saveTranscriptionQuietly(record)
        
        await waitForAsyncOperation()
        
        // Test quiet fetch
        let savedRecords = await dataManager.fetchAllRecordsQuietly()
        XCTAssertEqual(savedRecords.count, 1, "Quiet save should work")
        XCTAssertEqual(savedRecords[0].text, "Quiet operation test")
        
        // Test quiet cleanup
        await dataManager.cleanupExpiredRecordsQuietly()
        
        // Should still have the record (no cleanup needed)
        let afterCleanup = await dataManager.fetchAllRecordsQuietly()
        XCTAssertEqual(afterCleanup.count, 1, "Quiet cleanup should work")
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testDataManagerErrorHandling() async {
        // Test error scenarios with real error types
        let errors: [DataManagerError] = [
            .initializationFailed(NSError(domain: "test", code: 1)),
            .saveFailed(NSError(domain: "test", code: 2)),
            .fetchFailed(NSError(domain: "test", code: 3)),
            .deleteFailed(NSError(domain: "test", code: 4)),
            .cleanupFailed(NSError(domain: "test", code: 5)),
            .modelContainerUnavailable
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
        
        // Test specific error descriptions
        let initError = DataManagerError.initializationFailed(NSError(domain: "test", code: 1))
        XCTAssertTrue(initError.errorDescription!.contains("Failed to initialize"), "Init error should mention initialization")
        
        let containerError = DataManagerError.modelContainerUnavailable
        XCTAssertEqual(containerError.errorDescription, "Data storage is not available")
    }
    
    // MARK: - Concurrency Integration Tests
    
    func testConcurrentDataManagerOperations() async throws {
        let operationCount = 50
        
        // Perform concurrent saves
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<operationCount {
                group.addTask {
                    let record = await self.createSampleRecord(
                        text: "Concurrent record \(i)",
                        provider: TranscriptionProvider.allCases[i % TranscriptionProvider.allCases.count]
                    )
                    await self.dataManager.saveTranscriptionQuietly(record)
                }
            }
        }
        
        await waitForAsyncOperation()
        
        // Verify all records were saved
        let allRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(allRecords.count, operationCount, "All concurrent saves should succeed")
        
        // Test concurrent searches
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let results = try! await self.dataManager.fetchRecords(matching: "Concurrent")
                    return results.count
                }
            }
            
            var searchResults: [Int] = []
            for await result in group {
                searchResults.append(result)
            }
            
            // All searches should return the same count
            XCTAssertTrue(searchResults.allSatisfy { $0 == operationCount }, "Concurrent searches should be consistent")
        }
    }
    
    func testMixedConcurrentOperations() async throws {
        // Perform mixed read/write/delete operations concurrently
        
        // First, add some initial data
        for i in 0..<20 {
            let record = createSampleRecord(text: "Initial record \(i)", provider: .openai)
            try await dataManager.saveTranscription(record)
        }
        
        await waitForAsyncOperation()
        
        // Now perform mixed operations
        await withTaskGroup(of: Void.self) { group in
            // Add new records
            for i in 0..<10 {
                group.addTask {
                    let record = await self.createSampleRecord(text: "New record \(i)", provider: .gemini)
                    await self.dataManager.saveTranscriptionQuietly(record)
                }
            }
            
            // Perform searches
            for _ in 0..<5 {
                group.addTask {
                    let _ = try? await self.dataManager.fetchRecords(matching: "record")
                }
            }
            
            // Delete some records
            group.addTask {
                let records = try? await self.dataManager.fetchAllRecords()
                if let recordsToDelete = records?.prefix(5) {
                    for record in recordsToDelete {
                        try? await self.dataManager.deleteRecord(record)
                    }
                }
            }
        }
        
        await waitForAsyncOperation()
        
        // Verify final state is consistent
        let finalRecords = try await dataManager.fetchAllRecords()
        XCTAssertGreaterThan(finalRecords.count, 0, "Should have some records remaining")
        XCTAssertLessThan(finalRecords.count, 30, "Should have fewer than initial + new records due to deletions")
        
        // Verify data integrity
        for record in finalRecords {
            XCTAssertFalse(record.text.isEmpty, "Records should have valid text")
            XCTAssertNotNil(record.id, "Records should have valid IDs")
            XCTAssertNotNil(record.date, "Records should have valid dates")
        }
    }
    
    // MARK: - Performance Integration Tests
    
    func testDataManagerPerformanceWithLargeDataset() async throws {
        let recordCount = 1000
        var records: [TranscriptionRecord] = []
        
        // Generate test data
        for i in 0..<recordCount {
            let provider = TranscriptionProvider.allCases[i % TranscriptionProvider.allCases.count]
            let text = "Performance test record \(i) with realistic transcription content that might be longer"
            let duration = Double.random(in: 1.0...300.0)
            let record = createSampleRecord(text: text, provider: provider, duration: duration)
            records.append(record)
        }
        
        // Test batch save performance
        let saveStartTime = CFAbsoluteTimeGetCurrent()
        
        for record in records {
            await dataManager.saveTranscriptionQuietly(record)
        }
        
        let saveEndTime = CFAbsoluteTimeGetCurrent()
        let saveTime = saveEndTime - saveStartTime
        
        print("Saved \(recordCount) records in \(saveTime) seconds")
        XCTAssertLessThan(saveTime, 30.0, "Saving should complete within reasonable time")
        
        await waitForAsyncOperation()
        
        // Test fetch performance
        let fetchStartTime = CFAbsoluteTimeGetCurrent()
        let fetchedRecords = await dataManager.fetchAllRecordsQuietly()
        let fetchEndTime = CFAbsoluteTimeGetCurrent()
        let fetchTime = fetchEndTime - fetchStartTime
        
        print("Fetched \(fetchedRecords.count) records in \(fetchTime) seconds")
        XCTAssertEqual(fetchedRecords.count, recordCount, "Should fetch all records")
        XCTAssertLessThan(fetchTime, 5.0, "Fetching should be fast")
        
        // Test search performance
        let searchStartTime = CFAbsoluteTimeGetCurrent()
        let searchResults = try await dataManager.fetchRecords(matching: "500")
        let searchEndTime = CFAbsoluteTimeGetCurrent()
        let searchTime = searchEndTime - searchStartTime
        
        print("Searched \(fetchedRecords.count) records in \(searchTime) seconds")
        XCTAssertGreaterThan(searchResults.count, 0, "Should find matching records")
        XCTAssertLessThan(searchTime, 2.0, "Search should be fast")
    }
    
    // MARK: - Settings Integration Tests
    
    func testDataManagerSettingsIntegration() async throws {
        // Test history enabled/disabled behavior
        let testRecord = createSampleRecord(text: "Settings test", provider: .openai)
        
        // Enable history and save
        UserDefaults.standard.set(true, forKey: "transcriptionHistoryEnabled")
        dataManager.isHistoryEnabled = true
        
        try await dataManager.saveTranscription(testRecord)
        var records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 1, "Record should be saved when history enabled")
        
        // Disable history and try to save another
        UserDefaults.standard.set(false, forKey: "transcriptionHistoryEnabled")
        dataManager.isHistoryEnabled = false
        
        let anotherRecord = createSampleRecord(text: "Should not save", provider: .gemini)
        try await dataManager.saveTranscription(anotherRecord)
        
        records = try await dataManager.fetchAllRecords()
        XCTAssertEqual(records.count, 1, "No new record should be saved when history disabled")
    }
    
    func testRetentionPeriodSettingsIntegration() async throws {
        // Test retention period changes
        let periods: [RetentionPeriod] = [.oneWeek, .oneMonth, .threeMonths, .forever]
        
        for period in periods {
            UserDefaults.standard.set(period.rawValue, forKey: "transcriptionRetentionPeriod")
            dataManager.retentionPeriod = period
            
            XCTAssertEqual(dataManager.retentionPeriod, period, "Retention period should be set correctly")
            
            // Test that timeInterval property matches expectations
            switch period {
            case .oneWeek:
                XCTAssertEqual(period.timeInterval, 7 * 24 * 60 * 60)
            case .oneMonth:
                XCTAssertEqual(period.timeInterval, 30 * 24 * 60 * 60)
            case .threeMonths:
                XCTAssertEqual(period.timeInterval, 90 * 24 * 60 * 60)
            case .forever:
                XCTAssertNil(period.timeInterval)
            }
        }
    }
    
    // MARK: - Real-world Integration Scenarios
    
    func testCompleteUserJourney() async throws {
        // Simulate a complete user journey from setup to data management
        
        // Step 1: User enables history
        UserDefaults.standard.set(true, forKey: "transcriptionHistoryEnabled")
        UserDefaults.standard.set(RetentionPeriod.oneMonth.rawValue, forKey: "transcriptionRetentionPeriod")
        
        dataManager.isHistoryEnabled = true
        dataManager.retentionPeriod = .oneMonth
        
        // Step 2: User creates multiple transcriptions over time
        let transcriptions = [
            ("Meeting notes from team standup", TranscriptionProvider.openai, 450.0),
            ("Voice memo about vacation plans", TranscriptionProvider.local, 30.0),
            ("Interview with job candidate", TranscriptionProvider.gemini, 1800.0),
            ("Conference call recording", TranscriptionProvider.parakeet, 2700.0),
            ("Quick reminder note", TranscriptionProvider.openai, 15.0)
        ]
        
        for (text, provider, duration) in transcriptions {
            let record = createSampleRecord(text: text, provider: provider, duration: duration)
            try await dataManager.saveTranscription(record)
        }
        
        await waitForAsyncOperation()
        
        // Step 3: User searches for specific content
        let meetingResults = try await dataManager.fetchRecords(matching: "meeting")
        XCTAssertEqual(meetingResults.count, 1, "Should find meeting notes")
        
        let interviewResults = try await dataManager.fetchRecords(matching: "interview")
        XCTAssertEqual(interviewResults.count, 1, "Should find interview")
        
        let openaiResults = try await dataManager.fetchRecords(matching: "openai")
        XCTAssertEqual(openaiResults.count, 2, "Should find OpenAI transcriptions")
        
        // Step 4: User deletes some old records
        let allRecords = try await dataManager.fetchAllRecords()
        let voiceMemo = allRecords.first { $0.text.contains("vacation") }!
        try await dataManager.deleteRecord(voiceMemo)
        
        let afterDelete = try await dataManager.fetchAllRecords()
        XCTAssertEqual(afterDelete.count, 4, "Should have 4 records after deletion")
        
        // Step 5: User changes retention policy and performs cleanup
        dataManager.retentionPeriod = .oneWeek
        
        // Simulate some old records by changing their dates
        let recordsToAge = try await dataManager.fetchAllRecords()
        for (index, record) in recordsToAge.enumerated() {
            if index < 2 {
                record.date = Date().addingTimeInterval(-10 * 24 * 60 * 60) // 10 days ago
            }
        }
        
        try await dataManager.cleanupExpiredRecords()
        
        let afterCleanup = try await dataManager.fetchAllRecords()
        XCTAssertLessThan(afterCleanup.count, 4, "Should have fewer records after cleanup")
        
        // Step 6: User disables history
        dataManager.isHistoryEnabled = false
        
        let newRecord = createSampleRecord(text: "This should not be saved", provider: .local)
        try await dataManager.saveTranscription(newRecord)
        
        let finalRecords = try await dataManager.fetchAllRecords()
        XCTAssertEqual(finalRecords.count, afterCleanup.count, "No new records should be saved when history is disabled")
        
        // Verify data integrity throughout the journey
        for record in finalRecords {
            XCTAssertFalse(record.text.isEmpty, "All records should have valid text")
            XCTAssertNotNil(record.transcriptionProvider, "All records should have valid providers")
            XCTAssertNotNil(record.formattedDate, "All records should have formatted dates")
        }
    }
    
    // MARK: - Database-Level Search Performance Tests
    
    func testDatabaseLevelSearchWithPagination() async throws {
        // Create 100 test records to test performance
        for i in 0..<100 {
            let searchTerms = ["apple", "banana", "cherry", "date", "elderberry"]
            let provider = TranscriptionProvider.allCases[i % TranscriptionProvider.allCases.count]
            let searchTerm = searchTerms[i % searchTerms.count]
            
            let record = createSampleRecord(
                text: "Record \(i): Discussion about \(searchTerm) processing",
                provider: provider,
                duration: Double(i),
                modelUsed: provider == .local ? "tiny" : nil
            )
            try await dataManager.saveTranscription(record)
        }
        
        await waitForAsyncOperation()
        
        // Test paginated search
        let firstPage = try await dataManager.fetchRecords(matching: "apple", limit: 10, offset: 0)
        XCTAssertEqual(firstPage.count, 10, "Should return exactly 10 records for first page")
        
        let secondPage = try await dataManager.fetchRecords(matching: "apple", limit: 10, offset: 10)
        XCTAssertEqual(secondPage.count, 10, "Should return exactly 10 records for second page")
        
        // Verify pages contain different records
        let firstPageIds = Set(firstPage.map { $0.id })
        let secondPageIds = Set(secondPage.map { $0.id })
        XCTAssertTrue(firstPageIds.isDisjoint(with: secondPageIds), "Pages should contain different records")
        
        // Test search with different terms
        let bananaResults = try await dataManager.fetchRecords(matching: "banana", limit: 5, offset: 0)
        XCTAssertEqual(bananaResults.count, 5, "Should return up to 5 banana records")
        
        // Test case-insensitive search
        let uppercaseResults = try await dataManager.fetchRecords(matching: "APPLE", limit: 10, offset: 0)
        XCTAssertEqual(uppercaseResults.count, 10, "Case-insensitive search should work")
        
        // Test search in provider field
        let openaiResults = try await dataManager.fetchRecords(matching: "openai", limit: nil, offset: nil)
        XCTAssertGreaterThan(openaiResults.count, 0, "Should find records by provider name")
        
        // Test search in modelUsed field
        let tinyResults = try await dataManager.fetchRecords(matching: "tiny", limit: nil, offset: nil)
        XCTAssertGreaterThan(tinyResults.count, 0, "Should find records by model name")
        
        // Performance comparison - ensure predicate search is reasonably fast
        let startTime = Date()
        let _ = try await dataManager.fetchRecords(matching: "processing", limit: 50, offset: 0)
        let searchDuration = Date().timeIntervalSince(startTime)
        
        XCTAssertLessThan(searchDuration, 1.0, "Database search should complete within 1 second")
    }
}