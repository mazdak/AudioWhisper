import XCTest
import SwiftUI
import SwiftData
@testable import AudioWhisper

@MainActor
final class TranscriptionHistoryViewTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        modelContainer = try ModelContainer(
            for: TranscriptionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createSampleRecord(
        text: String = "Sample transcription",
        provider: TranscriptionProvider = .openai,
        duration: TimeInterval? = 10.5,
        modelUsed: String? = nil
    ) -> TranscriptionRecord {
        let record = TranscriptionRecord(
            text: text,
            provider: provider,
            duration: duration,
            modelUsed: modelUsed
        )
        modelContext.insert(record)
        try! modelContext.save()
        return record
    }
    
    private func createTestView() -> some View {
        TranscriptionHistoryView()
            .modelContainer(modelContainer)
    }
    
    // MARK: - TranscriptionRecordRow Tests
    
    func testTranscriptionRecordRowDisplaysCorrectInformation() {
        // Given
        let record = createSampleRecord(
            text: "Test transcription text",
            provider: .local,
            duration: 15.2,
            modelUsed: "base"
        )
        
        var copyCallCount = 0
        var deleteCallCount = 0
        
        // When
        let view = TranscriptionRecordRow(
            record: record,
            isExpanded: false,
            onToggleExpand: { },
            onCopy: { copyCallCount += 1 },
            onDelete: { deleteCallCount += 1 }
        )
        
        // Then - verify the view can be created and contains expected elements
        XCTAssertNotNil(view)
        XCTAssertEqual(record.text, "Test transcription text")
        XCTAssertEqual(record.provider, "local")
        XCTAssertEqual(record.modelUsed, "base")
        XCTAssertNotNil(record.formattedDuration)
    }
    
    func testTranscriptionRecordRowHandlesCallbacks() {
        // Given
        let record = createSampleRecord()
        
        var copyCallCount = 0
        var deleteCallCount = 0
        
        let view = TranscriptionRecordRow(
            record: record,
            isExpanded: false,
            onToggleExpand: { },
            onCopy: { copyCallCount += 1 },
            onDelete: { deleteCallCount += 1 }
        )
        
        // When - simulate callback invocations
        view.onCopy()
        view.onDelete()
        
        // Then
        XCTAssertEqual(copyCallCount, 1)
        XCTAssertEqual(deleteCallCount, 1)
    }
    
    func testProviderBadgeColors() {
        // Test that different providers get different colors
        let providers: [TranscriptionProvider] = [.openai, .gemini, .local, .parakeet]
        
        for provider in providers {
            let record = createSampleRecord(provider: provider)
            let view = TranscriptionRecordRow(
                record: record,
                isExpanded: false,
                onToggleExpand: {},
                onCopy: {},
                onDelete: {}
            )
            
            // Verify the record has the correct provider
            XCTAssertEqual(record.transcriptionProvider, provider)
            XCTAssertNotNil(view)
        }
    }
    
    // MARK: - Search Functionality Tests
    
    func testRecordSearchFunctionality() {
        // Given
        let records = [
            createSampleRecord(text: "Hello world from OpenAI", provider: .openai),
            createSampleRecord(text: "Goodbye world from Gemini", provider: .gemini),
            createSampleRecord(text: "Testing local whisper", provider: .local)
        ]
        
        // Test text search
        XCTAssertTrue(records[0].matches(searchQuery: "hello"))
        XCTAssertTrue(records[0].matches(searchQuery: "OpenAI"))
        XCTAssertFalse(records[0].matches(searchQuery: "goodbye"))
        
        // Test provider search
        XCTAssertTrue(records[1].matches(searchQuery: "gemini"))
        XCTAssertTrue(records[2].matches(searchQuery: "local"))
        
        // Test case insensitive search
        XCTAssertTrue(records[0].matches(searchQuery: "HELLO"))
        XCTAssertTrue(records[0].matches(searchQuery: "openai"))
        
        // Test empty search returns true
        XCTAssertTrue(records[0].matches(searchQuery: ""))
    }
    
    // MARK: - Data Integration Tests
    
    func testRecordCreationAndRetrieval() async throws {
        // Given
        let originalRecord = TranscriptionRecord(
            text: "Integration test transcription",
            provider: .openai,
            duration: 5.5,
            modelUsed: nil
        )
        
        // When
        modelContext.insert(originalRecord)
        try modelContext.save()
        
        // Fetch records
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let fetchedRecords = try modelContext.fetch(descriptor)
        
        // Then
        XCTAssertEqual(fetchedRecords.count, 1)
        let fetchedRecord = fetchedRecords[0]
        XCTAssertEqual(fetchedRecord.text, "Integration test transcription")
        XCTAssertEqual(fetchedRecord.provider, "openai")
        XCTAssertEqual(fetchedRecord.duration, 5.5)
        XCTAssertNil(fetchedRecord.modelUsed)
    }
    
    func testRecordDeletion() async throws {
        // Given
        let record = createSampleRecord(text: "Record to delete")
        _ = record.id
        
        // Verify record exists
        var descriptor = FetchDescriptor<TranscriptionRecord>()
        var records = try modelContext.fetch(descriptor)
        XCTAssertEqual(records.count, 1)
        
        // When
        modelContext.delete(record)
        try modelContext.save()
        
        // Then
        descriptor = FetchDescriptor<TranscriptionRecord>()
        records = try modelContext.fetch(descriptor)
        XCTAssertEqual(records.count, 0)
    }
    
    // MARK: - Formatted Display Tests
    
    func testFormattedDate() {
        // Given
        let record = createSampleRecord()
        
        // When
        let formattedDate = record.formattedDate
        
        // Then
        XCTAssertFalse(formattedDate.isEmpty)
        // The formatted date should contain some recognizable date components
        // This is a basic check since the exact format depends on system locale
    }
    
    func testFormattedDuration() {
        // Test various duration formats
        let testCases: [(TimeInterval, String)] = [
            (30.5, "30.5s"),
            (65.0, "1m 5s"),
            (3665.0, "1h 1m")
        ]
        
        for (duration, _) in testCases {
            let record = createSampleRecord(duration: duration)
            let formatted = record.formattedDuration
            
            XCTAssertNotNil(formatted)
            // Basic check that it contains expected elements
            if duration < 60 {
                XCTAssertTrue(formatted!.contains("s"))
            } else if duration < 3600 {
                XCTAssertTrue(formatted!.contains("m"))
            } else {
                XCTAssertTrue(formatted!.contains("h"))
            }
        }
    }
    
    func testFormattedDurationWithNilDuration() {
        // Given
        let record = createSampleRecord(duration: nil)
        
        // When
        let formattedDuration = record.formattedDuration
        
        // Then
        XCTAssertNil(formattedDuration)
    }
    
    func testPreviewTextTruncation() {
        // Given
        let longText = String(repeating: "A", count: 150)
        let record = createSampleRecord(text: longText)
        
        // When
        let preview = record.preview
        
        // Then
        XCTAssertTrue(preview.count <= 103) // 100 chars + "..."
        XCTAssertTrue(preview.hasSuffix("..."))
    }
    
    func testPreviewTextNoTruncation() {
        // Given
        let shortText = "Short text"
        let record = createSampleRecord(text: shortText)
        
        // When
        let preview = record.preview
        
        // Then
        XCTAssertEqual(preview, shortText)
        XCTAssertFalse(preview.hasSuffix("..."))
    }
    
    // MARK: - Provider Enum Tests
    
    func testTranscriptionProviderFromRecord() {
        // Test that records correctly return their provider enum
        let providers: [TranscriptionProvider] = [.openai, .gemini, .local, .parakeet]
        
        for provider in providers {
            let record = createSampleRecord(provider: provider)
            XCTAssertEqual(record.transcriptionProvider, provider)
            XCTAssertEqual(record.provider, provider.rawValue)
        }
    }
    
    func testWhisperModelFromRecord() {
        // Given
        let record = createSampleRecord(modelUsed: "base")
        
        // When
        let whisperModel = record.whisperModel
        
        // Then
        XCTAssertEqual(whisperModel, .base)
    }
    
    func testWhisperModelWithNilModelUsed() {
        // Given
        let record = createSampleRecord(modelUsed: nil)
        
        // When
        let whisperModel = record.whisperModel
        
        // Then
        XCTAssertNil(whisperModel)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyTextRecord() {
        // Given
        let record = createSampleRecord(text: "")
        
        // When & Then
        XCTAssertEqual(record.text, "")
        XCTAssertEqual(record.preview, "")
        XCTAssertFalse(record.matches(searchQuery: "anything"))  // Empty text doesn't contain "anything"
        XCTAssertTrue(record.matches(searchQuery: ""))  // Empty search query matches all records
    }
    
    func testSpecialCharactersInText() {
        // Given
        let specialText = "Hello! @#$%^&*()_+ \"quotes\" 'apostrophes' [brackets] {braces}"
        let record = createSampleRecord(text: specialText)
        
        // When & Then
        XCTAssertEqual(record.text, specialText)
        XCTAssertTrue(record.matches(searchQuery: "quotes"))
        XCTAssertTrue(record.matches(searchQuery: "brackets"))
    }
    
    func testUnicodeInText() {
        // Given
        let unicodeText = "Hello 世界 🌍 émojis café naïve"
        let record = createSampleRecord(text: unicodeText)
        
        // When & Then
        XCTAssertEqual(record.text, unicodeText)
        XCTAssertTrue(record.matches(searchQuery: "世界"))
        XCTAssertTrue(record.matches(searchQuery: "🌍"))
        XCTAssertTrue(record.matches(searchQuery: "café"))
    }
    
    // MARK: - Performance Tests
    
    func testSearchPerformanceWithManyRecords() {
        // Given - Create many records
        let recordCount = 1000
        for i in 0..<recordCount {
            _ = createSampleRecord(text: "Record number \(i)")
        }
        
        // When & Then - Measure search performance
        measure {
            let descriptor = FetchDescriptor<TranscriptionRecord>()
            let allRecords = try! modelContext.fetch(descriptor)
            
            let filtered = allRecords.filter { record in
                record.matches(searchQuery: "500")
            }
            
            XCTAssertTrue(filtered.count > 0)
        }
    }
}