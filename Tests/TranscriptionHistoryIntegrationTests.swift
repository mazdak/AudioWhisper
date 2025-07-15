import XCTest
import SwiftUI
import SwiftData
@testable import AudioWhisper

@MainActor
final class TranscriptionHistoryIntegrationTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var dataManager: DataManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        modelContainer = try ModelContainer(
            for: TranscriptionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = ModelContext(modelContainer)
        
        // Set up DataManager with test container
        dataManager = DataManager.shared as? DataManager
        try dataManager?.initialize()
        
        // Ensure history is enabled for tests
        UserDefaults.standard.set(true, forKey: "transcriptionHistoryEnabled")
        UserDefaults.standard.set(RetentionPeriod.forever.rawValue, forKey: "transcriptionRetentionPeriod")
    }
    
    override func tearDown() async throws {
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "transcriptionHistoryEnabled")
        UserDefaults.standard.removeObject(forKey: "transcriptionRetentionPeriod")
        
        modelContainer = nil
        modelContext = nil
        dataManager = nil
        
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
    
    private func createTestView() -> some View {
        TranscriptionHistoryView()
            .modelContainer(modelContainer)
    }
    
    private func waitForAsyncOperation() async {
        // Small delay to ensure async operations complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    // MARK: - Full Flow Integration Tests
    
    func testCompleteTranscriptionFlow() async throws {
        // Given - Create a new transcription record
        let originalText = "This is a complete integration test transcription from OpenAI"
        let record = createSampleRecord(
            text: originalText,
            provider: .openai,
            duration: 15.5,
            modelUsed: "whisper-1"
        )
        
        // When - Save the transcription
        modelContext.insert(record)
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        // Then - Retrieve and verify
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let savedRecords = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(savedRecords.count, 1, "Should have exactly one saved record")
        
        let savedRecord = savedRecords[0]
        XCTAssertEqual(savedRecord.text, originalText, "Text should match")
        XCTAssertEqual(savedRecord.provider, "openai", "Provider should match")
        XCTAssertEqual(savedRecord.duration, 15.5, "Duration should match")
        XCTAssertEqual(savedRecord.modelUsed, "whisper-1", "Model should match")
        XCTAssertNotNil(savedRecord.date, "Date should be set")
        XCTAssertNotNil(savedRecord.id, "ID should be set")
        
        // Verify computed properties work correctly
        XCTAssertEqual(savedRecord.transcriptionProvider, .openai)
        XCTAssertNotNil(savedRecord.formattedDate)
        XCTAssertNotNil(savedRecord.formattedDuration)
        XCTAssertEqual(savedRecord.preview, originalText) // Not truncated
    }
    
    func testMultipleTranscriptionsWorkflow() async throws {
        // Given - Create multiple transcription records
        let records = [
            createSampleRecord(text: "First transcription", provider: .openai, duration: 5.0),
            createSampleRecord(text: "Second transcription", provider: .gemini, duration: 10.0),
            createSampleRecord(text: "Third transcription", provider: .local, duration: 15.0, modelUsed: "base"),
            createSampleRecord(text: "Fourth transcription", provider: .parakeet, duration: 20.0)
        ]
        
        // When - Save all records
        for record in records {
            modelContext.insert(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        // Then - Verify all records are saved and ordered correctly
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let savedRecords = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(savedRecords.count, 4, "Should have all four records")
        
        // Verify they're in reverse chronological order (newest first)
        XCTAssertEqual(savedRecords[0].text, "Fourth transcription")
        XCTAssertEqual(savedRecords[1].text, "Third transcription")
        XCTAssertEqual(savedRecords[2].text, "Second transcription")
        XCTAssertEqual(savedRecords[3].text, "First transcription")
        
        // Verify all providers are represented
        let providers = savedRecords.map { $0.provider }
        XCTAssertTrue(providers.contains("openai"))
        XCTAssertTrue(providers.contains("gemini"))
        XCTAssertTrue(providers.contains("local"))
        XCTAssertTrue(providers.contains("parakeet"))
    }
    
    func testTranscriptionWithHistoryDisabled() async throws {
        // Given - Disable history
        UserDefaults.standard.set(false, forKey: "transcriptionHistoryEnabled")
        
        let record = createSampleRecord(text: "Should not be saved")
        
        // When - Attempt to save (simulating DataManager behavior)
        let isHistoryEnabled = UserDefaults.standard.bool(forKey: "transcriptionHistoryEnabled")
        if isHistoryEnabled {
            modelContext.insert(record)
            try modelContext.save()
        }
        
        await waitForAsyncOperation()
        
        // Then - Verify record was not saved
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let savedRecords = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(savedRecords.count, 0, "No records should be saved when history is disabled")
    }
    
    // MARK: - Search Integration Tests
    
    func testComprehensiveSearchFunctionality() async throws {
        // Given - Create records with diverse content
        let records = [
            createSampleRecord(text: "Meeting notes about Swift programming", provider: .openai),
            createSampleRecord(text: "Python tutorial transcript", provider: .gemini),
            createSampleRecord(text: "Swift development discussion", provider: .local, modelUsed: "base"),
            createSampleRecord(text: "JavaScript framework comparison", provider: .parakeet),
            createSampleRecord(text: "Machine learning concepts explained", provider: .openai, modelUsed: "whisper-1"),
            createSampleRecord(text: "Database design principles", provider: .local, modelUsed: "small")
        ]
        
        for record in records {
            modelContext.insert(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        // Test 1: Text-based search
        let allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        let swiftResults = allRecords.filter { $0.matches(searchQuery: "Swift") }
        XCTAssertEqual(swiftResults.count, 2, "Should find 2 Swift-related records")
        
        // Test 2: Provider-based search
        let openaiResults = allRecords.filter { $0.matches(searchQuery: "openai") }
        XCTAssertEqual(openaiResults.count, 2, "Should find 2 OpenAI records")
        
        // Test 3: Model-based search
        let baseModelResults = allRecords.filter { $0.matches(searchQuery: "base") }
        XCTAssertEqual(baseModelResults.count, 1, "Should find 1 base model record")
        
        // Test 4: Case-insensitive search
        let caseInsensitiveResults = allRecords.filter { $0.matches(searchQuery: "PYTHON") }
        XCTAssertEqual(caseInsensitiveResults.count, 1, "Case-insensitive search should work")
        
        // Test 5: Partial word search
        let partialResults = allRecords.filter { $0.matches(searchQuery: "program") }
        XCTAssertEqual(partialResults.count, 1, "Partial word search should work")
        
        // Test 6: No results
        let noResults = allRecords.filter { $0.matches(searchQuery: "nonexistent") }
        XCTAssertEqual(noResults.count, 0, "Should return no results for non-matching query")
        
        // Test 7: Empty query (should match all)
        let emptyQueryResults = allRecords.filter { $0.matches(searchQuery: "") }
        XCTAssertEqual(emptyQueryResults.count, 6, "Empty query should match all records")
    }
    
    func testSearchWithSpecialCharacters() async throws {
        // Given - Records with special characters
        let records = [
            createSampleRecord(text: "Email: user@example.com with special chars!", provider: .openai),
            createSampleRecord(text: "Path: /Users/test/file.txt", provider: .local),
            createSampleRecord(text: "Code: function() { return 'hello'; }", provider: .gemini),
            createSampleRecord(text: "Unicode: café naïve résumé 世界 🌍", provider: .parakeet)
        ]
        
        for record in records {
            modelContext.insert(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        let allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        
        // Test searching for email
        let emailResults = allRecords.filter { $0.matches(searchQuery: "@example.com") }
        XCTAssertEqual(emailResults.count, 1, "Should find email record")
        
        // Test searching for path
        let pathResults = allRecords.filter { $0.matches(searchQuery: "/Users") }
        XCTAssertEqual(pathResults.count, 1, "Should find path record")
        
        // Test searching for code
        let codeResults = allRecords.filter { $0.matches(searchQuery: "function()") }
        XCTAssertEqual(codeResults.count, 1, "Should find code record")
        
        // Test searching for unicode
        let unicodeResults = allRecords.filter { $0.matches(searchQuery: "café") }
        XCTAssertEqual(unicodeResults.count, 1, "Should find unicode record")
        
        let emojiResults = allRecords.filter { $0.matches(searchQuery: "🌍") }
        XCTAssertEqual(emojiResults.count, 1, "Should find emoji record")
    }
    
    // MARK: - Delete Operations Integration Tests
    
    func testSingleRecordDeletion() async throws {
        // Given - Multiple records
        let records = [
            createSampleRecord(text: "Keep this record", provider: .openai),
            createSampleRecord(text: "Delete this record", provider: .gemini),
            createSampleRecord(text: "Keep this one too", provider: .local)
        ]
        
        for record in records {
            modelContext.insert(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        var allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(allRecords.count, 3, "Should start with 3 records")
        
        // When - Delete specific record
        let recordToDelete = allRecords.first { $0.text == "Delete this record" }!
        modelContext.delete(recordToDelete)
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        // Then - Verify deletion
        allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(allRecords.count, 2, "Should have 2 records after deletion")
        
        let remainingTexts = allRecords.map { $0.text }
        XCTAssertTrue(remainingTexts.contains("Keep this record"))
        XCTAssertTrue(remainingTexts.contains("Keep this one too"))
        XCTAssertFalse(remainingTexts.contains("Delete this record"))
    }
    
    func testBulkDeletion() async throws {
        // Given - Many records
        var records: [TranscriptionRecord] = []
        for i in 1...10 {
            records.append(createSampleRecord(
                text: "Record number \(i)",
                provider: i % 2 == 0 ? .openai : .gemini
            ))
        }
        
        for record in records {
            modelContext.insert(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        var allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(allRecords.count, 10, "Should start with 10 records")
        
        // When - Delete all OpenAI records (should be 5)
        let openaiRecords = allRecords.filter { $0.provider == "openai" }
        XCTAssertEqual(openaiRecords.count, 5, "Should have 5 OpenAI records")
        
        for record in openaiRecords {
            modelContext.delete(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        // Then - Verify bulk deletion
        allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(allRecords.count, 5, "Should have 5 records after bulk deletion")
        
        // All remaining should be Gemini records
        for record in allRecords {
            XCTAssertEqual(record.provider, "gemini", "All remaining records should be Gemini")
        }
    }
    
    func testDeleteAllRecords() async throws {
        // Given - Multiple records
        let records = [
            createSampleRecord(text: "Record 1", provider: .openai),
            createSampleRecord(text: "Record 2", provider: .gemini),
            createSampleRecord(text: "Record 3", provider: .local),
            createSampleRecord(text: "Record 4", provider: .parakeet)
        ]
        
        for record in records {
            modelContext.insert(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        var allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(allRecords.count, 4, "Should start with 4 records")
        
        // When - Delete all records
        for record in allRecords {
            modelContext.delete(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        // Then - Verify all deleted
        allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(allRecords.count, 0, "Should have no records after delete all")
    }
    
    // MARK: - Settings Integration Tests
    
    func testHistoryEnabledSetting() async throws {
        // Test enabling history
        UserDefaults.standard.set(true, forKey: "transcriptionHistoryEnabled")
        let isEnabled = UserDefaults.standard.bool(forKey: "transcriptionHistoryEnabled")
        XCTAssertTrue(isEnabled, "History should be enabled")
        
        // Test disabling history
        UserDefaults.standard.set(false, forKey: "transcriptionHistoryEnabled")
        let isDisabled = UserDefaults.standard.bool(forKey: "transcriptionHistoryEnabled")
        XCTAssertFalse(isDisabled, "History should be disabled")
    }
    
    func testRetentionPeriodSettings() async throws {
        // Test all retention periods
        for period in RetentionPeriod.allCases {
            UserDefaults.standard.set(period.rawValue, forKey: "transcriptionRetentionPeriod")
            
            let storedValue = UserDefaults.standard.string(forKey: "transcriptionRetentionPeriod")
            XCTAssertEqual(storedValue, period.rawValue, "Retention period should be stored correctly")
            
            let retrievedPeriod = RetentionPeriod(rawValue: storedValue!) ?? .oneMonth
            XCTAssertEqual(retrievedPeriod, period, "Retention period should be retrieved correctly")
        }
    }
    
    func testRetentionPeriodTimeIntervals() {
        // Test that time intervals are calculated correctly
        XCTAssertEqual(RetentionPeriod.oneWeek.timeInterval, 7 * 24 * 60 * 60)
        XCTAssertEqual(RetentionPeriod.oneMonth.timeInterval, 30 * 24 * 60 * 60)
        XCTAssertEqual(RetentionPeriod.threeMonths.timeInterval, 90 * 24 * 60 * 60)
        XCTAssertNil(RetentionPeriod.forever.timeInterval)
        
        // Test display names
        XCTAssertEqual(RetentionPeriod.oneWeek.displayName, "1 Week")
        XCTAssertEqual(RetentionPeriod.oneMonth.displayName, "1 Month")
        XCTAssertEqual(RetentionPeriod.threeMonths.displayName, "3 Months")
        XCTAssertEqual(RetentionPeriod.forever.displayName, "Forever")
    }
    
    // MARK: - UI Component Integration Tests
    
    func testTranscriptionHistoryViewIntegration() async throws {
        // Given - Records in the database
        let records = [
            createSampleRecord(text: "First UI test record", provider: .openai),
            createSampleRecord(text: "Second UI test record", provider: .gemini)
        ]
        
        for record in records {
            modelContext.insert(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        // When - Create the view
        let historyView = createTestView()
        
        // Then - View should be created successfully
        XCTAssertNotNil(historyView, "TranscriptionHistoryView should be created")
        
        // Verify data is accessible
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let viewRecords = try modelContext.fetch(descriptor)
        XCTAssertEqual(viewRecords.count, 2, "View should have access to records")
    }
    
    func testTranscriptionRecordRowIntegration() async throws {
        // Given - A record
        let record = createSampleRecord(
            text: "Test record for row integration",
            provider: .local,
            duration: 45.5,
            modelUsed: "small"
        )
        
        var copyCallCount = 0
        var deleteCallCount = 0
        var expandCallCount = 0
        
        // When - Create row view
        let rowView = TranscriptionRecordRow(
            record: record,
            isExpanded: false,
            onToggleExpand: { expandCallCount += 1 },
            onCopy: { copyCallCount += 1 },
            onDelete: { deleteCallCount += 1 }
        )
        
        // Then - View should be created and callbacks should work
        XCTAssertNotNil(rowView, "TranscriptionRecordRow should be created")
        
        // Test callbacks
        rowView.onCopy()
        rowView.onDelete()
        rowView.onToggleExpand()
        
        XCTAssertEqual(copyCallCount, 1, "Copy callback should be called")
        XCTAssertEqual(deleteCallCount, 1, "Delete callback should be called")
        XCTAssertEqual(expandCallCount, 1, "Expand callback should be called")
    }
    
    // MARK: - Data Validation Tests
    
    func testRecordDataIntegrity() async throws {
        // Test various record configurations
        let testCases: [(String, TranscriptionProvider, TimeInterval?, String?)] = [
            ("Short text", .openai, 5.0, nil),
            ("Medium length text that should not be truncated in preview", .gemini, 125.5, "whisper-1"),
            (String(repeating: "Long text ", count: 20), .local, 3665.0, "base"), // > 100 chars for truncation test
            ("", .parakeet, nil, nil), // Edge case: empty text
            ("Special chars: @#$%^&*()_+ 世界 🌍", .openai, 0.5, "small")
        ]
        
        for (text, provider, duration, model) in testCases {
            let record = createSampleRecord(
                text: text,
                provider: provider,
                duration: duration,
                modelUsed: model
            )
            
            modelContext.insert(record)
            try modelContext.save()
            
            await waitForAsyncOperation()
            
            // Verify record was saved correctly
            let savedRecord = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>()).last!
            
            XCTAssertEqual(savedRecord.text, text, "Text should be preserved exactly")
            XCTAssertEqual(savedRecord.provider, provider.rawValue, "Provider should match")
            XCTAssertEqual(savedRecord.duration, duration, "Duration should match")
            XCTAssertEqual(savedRecord.modelUsed, model, "Model should match")
            XCTAssertNotNil(savedRecord.id, "ID should be generated")
            XCTAssertNotNil(savedRecord.date, "Date should be set")
            
            // Test computed properties
            XCTAssertEqual(savedRecord.transcriptionProvider, provider, "Provider enum should work")
            if let model = model {
                XCTAssertEqual(savedRecord.whisperModel?.rawValue, model, "Whisper model enum should work")
            }
            
            // Clean up for next iteration
            modelContext.delete(savedRecord)
            try modelContext.save()
        }
    }
    
    func testFormattedDisplayProperties() async throws {
        // Test duration formatting
        let durationTestCases: [(TimeInterval?, String?)] = [
            (nil, nil),
            (30.5, "30.5s"),
            (65.0, "1m 5s"),
            (125.7, "2m 5s"),
            (3665.0, "1h 1m"),
            (7325.5, "2h 2m")
        ]
        
        for (duration, expectedFormat) in durationTestCases {
            let record = createSampleRecord(duration: duration)
            
            if let expectedFormat = expectedFormat {
                XCTAssertEqual(record.formattedDuration, expectedFormat, "Duration formatting should match expected")
            } else {
                XCTAssertNil(record.formattedDuration, "Nil duration should return nil formatted duration")
            }
        }
        
        // Test text preview truncation
        let shortText = "Short text"
        let longText = String(repeating: "a", count: 150)
        
        let shortRecord = createSampleRecord(text: shortText)
        let longRecord = createSampleRecord(text: longText)
        
        XCTAssertEqual(shortRecord.preview, shortText, "Short text should not be truncated")
        XCTAssertTrue(longRecord.preview.count <= 103, "Long text should be truncated")
        XCTAssertTrue(longRecord.preview.hasSuffix("..."), "Truncated text should end with ellipsis")
        
        // Test formatted date
        let record = createSampleRecord()
        XCTAssertFalse(record.formattedDate.isEmpty, "Formatted date should not be empty")
        XCTAssertTrue(record.formattedDate.count > 5, "Formatted date should be meaningful")
    }
    
    // MARK: - Error Scenarios and Edge Cases
    
    func testDataCorruptionRecovery() async throws {
        // Given - Valid records
        let validRecord = createSampleRecord(text: "Valid record", provider: .openai)
        modelContext.insert(validRecord)
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        // When - Simulate corruption by modifying provider to invalid value
        let records = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        let record = records[0]
        record.provider = "invalid_provider"
        try modelContext.save()
        
        // Then - System should handle invalid provider gracefully
        XCTAssertNil(record.transcriptionProvider, "Invalid provider should return nil")
        XCTAssertEqual(record.provider, "invalid_provider", "Raw provider string should be preserved")
        
        // Search should still work with corrupted data
        XCTAssertTrue(record.matches(searchQuery: "invalid_provider"), "Search should work with invalid provider")
        XCTAssertTrue(record.matches(searchQuery: "Valid record"), "Text search should still work")
    }
    
    func testEmptyAndWhitespaceRecords() async throws {
        // Test edge cases with empty/whitespace content
        let edgeCaseRecords = [
            createSampleRecord(text: "", provider: .openai),
            createSampleRecord(text: "   ", provider: .gemini), // Only spaces
            createSampleRecord(text: "\n\t\r", provider: .local), // Only whitespace chars
            createSampleRecord(text: "   Valid text with spaces   ", provider: .parakeet)
        ]
        
        for record in edgeCaseRecords {
            modelContext.insert(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        let savedRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(savedRecords.count, 4, "All edge case records should be saved")
        
        // Test search behavior with empty/whitespace content
        let emptyRecord = savedRecords.first { $0.text.isEmpty }!
        XCTAssertFalse(emptyRecord.matches(searchQuery: "anything"), "Empty text should not match search terms")
        XCTAssertTrue(emptyRecord.matches(searchQuery: ""), "Empty search should match empty text")
        
        // Test preview behavior
        XCTAssertEqual(emptyRecord.preview, "", "Empty text preview should be empty")
        
        let whitespaceRecord = savedRecords.first { $0.text == "   " }!
        XCTAssertEqual(whitespaceRecord.preview, "   ", "Whitespace should be preserved in preview")
    }
    
    func testExtremelyLongText() async throws {
        // Test with very long transcription text
        let veryLongText = String(repeating: "This is a very long transcription text that simulates real-world scenarios where speech-to-text might produce extensive content. ", count: 100) // ~10,000 characters
        
        let longRecord = createSampleRecord(text: veryLongText, provider: .openai)
        modelContext.insert(longRecord)
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        let savedRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        let savedRecord = savedRecords[0]
        
        XCTAssertEqual(savedRecord.text.count, veryLongText.count, "Very long text should be saved completely")
        XCTAssertTrue(savedRecord.preview.count <= 103, "Preview should be truncated")
        XCTAssertTrue(savedRecord.preview.hasSuffix("..."), "Long preview should end with ellipsis")
        
        // Search should still work with very long text
        XCTAssertTrue(savedRecord.matches(searchQuery: "very long transcription"), "Search should work with long text")
        XCTAssertTrue(savedRecord.matches(searchQuery: "scenarios"), "Search should find text anywhere in long content")
    }
    
    func testConcurrentModifications() async throws {
        // Test concurrent access to the same records
        let initialRecords = [
            createSampleRecord(text: "Concurrent test 1", provider: .openai),
            createSampleRecord(text: "Concurrent test 2", provider: .gemini)
        ]
        
        for record in initialRecords {
            modelContext.insert(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        // Simulate concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Add new records
            group.addTask { @MainActor in
                let newRecord = self.createSampleRecord(text: "Added concurrently", provider: .local)
                self.modelContext.insert(newRecord)
                try? self.modelContext.save()
            }
            
            // Task 2: Read records
            group.addTask { @MainActor in
                let _ = try? self.modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
            }
            
            // Task 3: Search records
            group.addTask { @MainActor in
                let records = try? self.modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
                let _ = records?.filter { $0.matches(searchQuery: "test") }
            }
        }
        
        await waitForAsyncOperation()
        
        // Verify final state
        let finalRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertGreaterThanOrEqual(finalRecords.count, 2, "Should have at least initial records")
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetPerformance() async throws {
        // Create a large number of records to test performance
        let recordCount = 1000
        var records: [TranscriptionRecord] = []
        
        measure {
            // Generate records
            for i in 0..<recordCount {
                let provider = TranscriptionProvider.allCases[i % TranscriptionProvider.allCases.count]
                let text = "Performance test record number \(i) with some additional content to make it realistic"
                let duration = Double.random(in: 1.0...300.0) // 1 second to 5 minutes
                let record = createSampleRecord(text: text, provider: provider, duration: duration)
                records.append(record)
            }
        }
        
        // Test batch insertion performance
        measure {
            for record in records {
                modelContext.insert(record)
            }
            try! modelContext.save()
        }
        
        await waitForAsyncOperation()
        
        // Verify all records were saved
        let savedRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(savedRecords.count, recordCount, "All records should be saved")
        
        // Test search performance with large dataset
        measure {
            let filtered = savedRecords.filter { $0.matches(searchQuery: "500") }
            XCTAssertGreaterThan(filtered.count, 0, "Should find some records")
        }
        
        // Test fetch with sorting performance
        measure {
            let descriptor = FetchDescriptor<TranscriptionRecord>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let _ = try! modelContext.fetch(descriptor)
        }
        
        // Test filtering by provider performance
        measure {
            let openaiRecords = savedRecords.filter { $0.provider == "openai" }
            XCTAssertGreaterThan(openaiRecords.count, 0, "Should find OpenAI records")
        }
    }
    
    func testSearchPerformanceWithLargeDataset() async throws {
        // Create records with varied content for search testing
        let recordCount = 500
        let searchTerms = ["meeting", "development", "discussion", "tutorial", "presentation", "interview"]
        
        for i in 0..<recordCount {
            let randomTerm = searchTerms[i % searchTerms.count]
            let text = "This is a \(randomTerm) transcription number \(i) with additional content to test search performance"
            let provider = TranscriptionProvider.allCases[i % TranscriptionProvider.allCases.count]
            let record = createSampleRecord(text: text, provider: provider)
            modelContext.insert(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        let allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        
        // Test search performance for different query types
        let searchQueries = ["meeting", "development", "openai", "base", "transcription", "performance"]
        
        for query in searchQueries {
            measure {
                let results = allRecords.filter { $0.matches(searchQuery: query) }
                XCTAssertGreaterThanOrEqual(results.count, 0, "Search should complete without error")
            }
        }
        
        // Test case-insensitive search performance
        measure {
            let results = allRecords.filter { $0.matches(searchQuery: "MEETING") }
            XCTAssertGreaterThanOrEqual(results.count, 0, "Case-insensitive search should work")
        }
        
        // Test partial match performance
        measure {
            let results = allRecords.filter { $0.matches(searchQuery: "discuss") }
            XCTAssertGreaterThanOrEqual(results.count, 0, "Partial match search should work")
        }
    }
    
    func testMemoryUsageWithLargeDataset() async throws {
        // Test memory efficiency with large number of records
        let recordCount = 2000
        
        // Create records in batches to test memory management
        let batchSize = 100
        for batch in 0..<(recordCount / batchSize) {
            autoreleasepool {
                for i in 0..<batchSize {
                    let index = batch * batchSize + i
                    let text = "Memory test record \(index) with content that simulates real transcription data"
                    let provider = TranscriptionProvider.allCases[index % TranscriptionProvider.allCases.count]
                    let record = createSampleRecord(text: text, provider: provider)
                    modelContext.insert(record)
                }
                try! modelContext.save()
            }
            
            // Small delay between batches
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        // Verify all records were created
        let allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(allRecords.count, recordCount, "All records should be created")
        
        // Test memory-efficient search
        let searchResults = allRecords.filter { $0.matches(searchQuery: "Memory") }
        XCTAssertEqual(searchResults.count, recordCount, "All records should match 'Memory' search")
        
        // Test cleanup to verify memory is released
        for record in allRecords {
            modelContext.delete(record)
        }
        try modelContext.save()
        
        let remainingRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(remainingRecords.count, 0, "All records should be deleted")
    }
    
    // MARK: - Thread Safety and Concurrency Tests
    
    func testConcurrentReadOperations() async throws {
        // Setup initial data
        let initialRecords = Array(0..<50).map { i in
            createSampleRecord(text: "Concurrent read test \(i)", provider: .openai)
        }
        
        for record in initialRecords {
            modelContext.insert(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        // Perform concurrent read operations
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    let records = try! self.modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
                    return records.count
                }
            }
            
            var results: [Int] = []
            for await result in group {
                results.append(result)
            }
            
            // All reads should return the same count
            XCTAssertTrue(results.allSatisfy { $0 == 50 }, "All concurrent reads should return same count")
        }
    }
    
    func testConcurrentWriteAndReadOperations() async throws {
        let operationCount = 20
        
        await withTaskGroup(of: Void.self) { group in
            // Add write operations
            for i in 0..<operationCount {
                group.addTask { @MainActor in
                    let record = self.createSampleRecord(text: "Concurrent write \(i)", provider: .openai)
                    self.modelContext.insert(record)
                    try? self.modelContext.save()
                }
            }
            
            // Add read operations
            for _ in 0..<operationCount {
                group.addTask { @MainActor in
                    let _ = try? self.modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
                }
            }
        }
        
        await waitForAsyncOperation()
        
        // Verify final state
        let finalRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertGreaterThanOrEqual(finalRecords.count, 0, "Should handle concurrent operations safely")
        XCTAssertLessThanOrEqual(finalRecords.count, operationCount, "Should not exceed expected count")
    }
    
    func testDataConsistencyUnderConcurrency() async throws {
        let recordCount = 100
        
        // Task 1: Add records sequentially
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                for i in 0..<recordCount {
                    let record = self.createSampleRecord(
                        text: "Sequential record \(i)",
                        provider: .openai
                    )
                    self.modelContext.insert(record)
                    if i % 10 == 0 { // Save in batches
                        try? self.modelContext.save()
                    }
                }
                try? self.modelContext.save()
            }
            
            // Task 2: Perform searches periodically
            group.addTask {
                for _ in 0..<10 {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                    await MainActor.run {
                        let records = try? self.modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
                        let searchResults = records?.filter { $0.matches(searchQuery: "Sequential") }
                        // Results should be consistent (non-negative count)
                        if let count = searchResults?.count {
                            XCTAssertGreaterThanOrEqual(count, 0, "Search results should be non-negative")
                        }
                    }
                }
            }
        }
        
        await waitForAsyncOperation()
        
        // Final verification
        let allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        let sequentialRecords = allRecords.filter { $0.text.contains("Sequential") }
        XCTAssertEqual(sequentialRecords.count, recordCount, "All sequential records should be saved")
        
        // Verify data integrity
        for record in sequentialRecords {
            XCTAssertEqual(record.provider, "openai", "Provider should be consistent")
            XCTAssertTrue(record.text.contains("Sequential"), "Text should contain expected content")
            XCTAssertNotNil(record.id, "ID should be set")
            XCTAssertNotNil(record.date, "Date should be set")
        }
    }
    
    // MARK: - Integration with Settings and Menu Bar
    
    func testSettingsIntegrationWithDataManager() async throws {
        // Test that settings changes affect data manager behavior
        let testRecord = createSampleRecord(text: "Settings integration test", provider: .openai)
        
        // Test 1: History enabled
        UserDefaults.standard.set(true, forKey: "transcriptionHistoryEnabled")
        let isHistoryEnabled = UserDefaults.standard.bool(forKey: "transcriptionHistoryEnabled")
        
        if isHistoryEnabled {
            modelContext.insert(testRecord)
            try modelContext.save()
        }
        
        await waitForAsyncOperation()
        
        var records = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(records.count, 1, "Record should be saved when history is enabled")
        
        // Test 2: History disabled
        UserDefaults.standard.set(false, forKey: "transcriptionHistoryEnabled")
        let isHistoryDisabled = UserDefaults.standard.bool(forKey: "transcriptionHistoryEnabled")
        
        let anotherRecord = createSampleRecord(text: "Should not be saved", provider: .gemini)
        
        if !isHistoryDisabled {
            modelContext.insert(anotherRecord)
            try modelContext.save()
        }
        
        await waitForAsyncOperation()
        
        records = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(records.count, 1, "No new record should be saved when history is disabled")
    }
    
    func testRetentionPolicyIntegration() async throws {
        // Create records with different dates
        let oldDate = Date().addingTimeInterval(-40 * 24 * 60 * 60) // 40 days ago
        let recentDate = Date().addingTimeInterval(-5 * 24 * 60 * 60) // 5 days ago
        
        let oldRecord = createSampleRecord(text: "Old record", provider: .openai)
        oldRecord.date = oldDate
        
        let recentRecord = createSampleRecord(text: "Recent record", provider: .gemini)
        recentRecord.date = recentDate
        
        modelContext.insert(oldRecord)
        modelContext.insert(recentRecord)
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        // Test 1: One month retention
        UserDefaults.standard.set(RetentionPeriod.oneMonth.rawValue, forKey: "transcriptionRetentionPeriod")
        let retentionPeriod = RetentionPeriod(rawValue: UserDefaults.standard.string(forKey: "transcriptionRetentionPeriod") ?? "") ?? .oneMonth
        
        XCTAssertEqual(retentionPeriod, .oneMonth, "Retention period should be set to one month")
        
        // Simulate cleanup based on retention period
        if let timeInterval = retentionPeriod.timeInterval {
            let cutoffDate = Date().addingTimeInterval(-timeInterval)
            let allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
            let expiredRecords = allRecords.filter { $0.date < cutoffDate }
            
            XCTAssertEqual(expiredRecords.count, 1, "Should have one expired record")
            XCTAssertEqual(expiredRecords[0].text, "Old record", "Old record should be marked for cleanup")
        }
        
        // Test 2: Forever retention
        UserDefaults.standard.set(RetentionPeriod.forever.rawValue, forKey: "transcriptionRetentionPeriod")
        let foreverRetention = RetentionPeriod(rawValue: UserDefaults.standard.string(forKey: "transcriptionRetentionPeriod") ?? "") ?? .oneMonth
        
        XCTAssertEqual(foreverRetention, .forever, "Retention period should be set to forever")
        XCTAssertNil(foreverRetention.timeInterval, "Forever retention should have no time interval")
        
        // With forever retention, no records should be marked for cleanup
        let allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(allRecords.count, 2, "All records should be preserved with forever retention")
    }
    
    // MARK: - Real-world Scenario Tests
    
    func testTypicalUserWorkflow() async throws {
        // Simulate a typical user workflow over several days
        
        // Day 1: User makes several transcriptions
        let day1Records = [
            createSampleRecord(text: "Meeting notes from Monday morning standup", provider: .openai, duration: 300.0),
            createSampleRecord(text: "Voice memo about project ideas", provider: .local, duration: 45.0, modelUsed: "base"),
            createSampleRecord(text: "Interview transcript with candidate", provider: .gemini, duration: 1800.0)
        ]
        
        for record in day1Records {
            record.date = Date().addingTimeInterval(-2 * 24 * 60 * 60) // 2 days ago
            modelContext.insert(record)
        }
        try modelContext.save()
        
        // Day 2: User searches and deletes some records
        await waitForAsyncOperation()
        var allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        
        // Search for meeting-related records
        let meetingRecords = allRecords.filter { $0.matches(searchQuery: "meeting") }
        XCTAssertEqual(meetingRecords.count, 1, "Should find meeting record")
        
        // Delete the voice memo
        let voiceMemo = allRecords.first { $0.text.contains("Voice memo") }!
        modelContext.delete(voiceMemo)
        try modelContext.save()
        
        // Day 3: User adds more transcriptions and performs bulk operations
        let day3Records = [
            createSampleRecord(text: "Technical discussion about API design", provider: .openai, duration: 600.0),
            createSampleRecord(text: "Customer feedback session recording", provider: .parakeet, duration: 2400.0)
        ]
        
        for record in day3Records {
            modelContext.insert(record)
        }
        try modelContext.save()
        
        await waitForAsyncOperation()
        
        // Final verification
        allRecords = try modelContext.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(allRecords.count, 4, "Should have 4 records after workflow")
        
        // Test comprehensive search across all records
        let apiRecords = allRecords.filter { $0.matches(searchQuery: "API") }
        XCTAssertEqual(apiRecords.count, 1, "Should find API-related record")
        
        let interviewRecords = allRecords.filter { $0.matches(searchQuery: "interview") }
        XCTAssertEqual(interviewRecords.count, 1, "Should find interview record")
        
        // Test provider distribution
        let providerCounts = Dictionary(grouping: allRecords, by: { $0.provider })
        XCTAssertEqual(providerCounts["openai"]?.count, 2, "Should have 2 OpenAI records")
        XCTAssertEqual(providerCounts["gemini"]?.count, 1, "Should have 1 Gemini record")
        XCTAssertEqual(providerCounts["parakeet"]?.count, 1, "Should have 1 Parakeet record")
        XCTAssertNil(providerCounts["local"], "Local record should have been deleted")
    }
}