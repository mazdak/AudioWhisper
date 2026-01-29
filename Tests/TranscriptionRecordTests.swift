import XCTest
import SwiftData
@testable import AudioWhisper

final class TranscriptionRecordTests: XCTestCase {
    
    func testTranscriptionRecordInitialization() {
        // Test basic initialization
        let record = TranscriptionRecord(
            text: "Hello, world!",
            provider: .parakeet,
            duration: 5.5,
            modelUsed: "parakeet-v2"
        )

        XCTAssertEqual(record.text, "Hello, world!")
        XCTAssertEqual(record.provider, "parakeet")
        XCTAssertEqual(record.duration, 5.5)
        XCTAssertEqual(record.modelUsed, "parakeet-v2")
        XCTAssertNotNil(record.id)
        XCTAssertNotNil(record.date)
    }
    
    func testTranscriptionRecordWithAllProviders() {
        // Test that all TranscriptionProvider cases work
        for provider in TranscriptionProvider.allCases {
            let record = TranscriptionRecord(
                text: "Test transcription",
                provider: provider
            )
            
            XCTAssertEqual(record.provider, provider.rawValue)
            XCTAssertEqual(record.transcriptionProvider, provider)
        }
    }
    
    func testTranscriptionRecordWithWhisperModels() {
        // Test that all WhisperModel cases work
        for model in WhisperModel.allCases {
            let record = TranscriptionRecord(
                text: "Test transcription",
                provider: .local,
                modelUsed: model.rawValue
            )
            
            XCTAssertEqual(record.modelUsed, model.rawValue)
            XCTAssertEqual(record.whisperModel, model)
        }
    }
    
    func testFormattedDateIsNotEmpty() {
        let record = TranscriptionRecord(
            text: "Test",
            provider: .local
        )

        XCTAssertFalse(record.formattedDate.isEmpty)
    }
    
    func testFormattedDurationFormatting() {
        // Test short duration (less than 1 minute)
        let shortRecord = TranscriptionRecord(
            text: "Short",
            provider: .local,
            duration: 30.5
        )
        XCTAssertEqual(shortRecord.formattedDuration, "30.5s")

        // Test medium duration (minutes)
        let mediumRecord = TranscriptionRecord(
            text: "Medium",
            provider: .local,
            duration: 125.0 // 2 minutes 5 seconds
        )
        XCTAssertEqual(mediumRecord.formattedDuration, "2m 5s")

        // Test long duration (hours)
        let longRecord = TranscriptionRecord(
            text: "Long",
            provider: .parakeet,
            duration: 3900.0 // 1 hour 5 minutes
        )
        XCTAssertEqual(longRecord.formattedDuration, "1h 5m")

        // Test nil duration
        let noDurationRecord = TranscriptionRecord(
            text: "No duration",
            provider: .parakeet
        )
        XCTAssertNil(noDurationRecord.formattedDuration)
    }
    
    func testPreviewTextTruncation() {
        // Test short text (no truncation)
        let shortRecord = TranscriptionRecord(
            text: "Short text",
            provider: .local
        )
        XCTAssertEqual(shortRecord.preview, "Short text")

        // Test long text (should be truncated)
        let longText = String(repeating: "a", count: 150)
        let longRecord = TranscriptionRecord(
            text: longText,
            provider: .parakeet
        )
        XCTAssertTrue(longRecord.preview.hasSuffix("..."))
        XCTAssertTrue(longRecord.preview.count < longText.count)
    }
    
    func testSearchMatching() {
        let record = TranscriptionRecord(
            text: "This is a test transcription about Swift programming",
            provider: .local,
            modelUsed: "small"
        )

        // Test text matching
        XCTAssertTrue(record.matches(searchQuery: "Swift"))
        XCTAssertTrue(record.matches(searchQuery: "swift")) // Case insensitive
        XCTAssertTrue(record.matches(searchQuery: "test"))

        // Test provider matching
        XCTAssertTrue(record.matches(searchQuery: "local"))
        XCTAssertTrue(record.matches(searchQuery: "Local")) // Case insensitive

        // Test model matching
        XCTAssertTrue(record.matches(searchQuery: "small"))

        // Test no match
        XCTAssertFalse(record.matches(searchQuery: "Python"))

        // Test empty query (should match all)
        XCTAssertTrue(record.matches(searchQuery: ""))
    }
    
    func testTranscriptionProviderComputed() {
        // Test valid provider
        let validRecord = TranscriptionRecord(
            text: "Test",
            provider: .parakeet
        )
        XCTAssertEqual(validRecord.transcriptionProvider, .parakeet)

        // Test invalid provider (should return nil)
        let invalidRecord = TranscriptionRecord(
            text: "Test",
            provider: .local
        )
        // Manually set an invalid provider to test edge case
        invalidRecord.provider = "invalid_provider"
        XCTAssertNil(invalidRecord.transcriptionProvider)
    }
    
    func testWhisperModelComputed() {
        // Test valid model
        let validRecord = TranscriptionRecord(
            text: "Test",
            provider: .local,
            modelUsed: WhisperModel.small.rawValue
        )
        XCTAssertEqual(validRecord.whisperModel, .small)
        
        // Test invalid model (should return nil)
        let invalidRecord = TranscriptionRecord(
            text: "Test",
            provider: .local,
            modelUsed: "invalid_model"
        )
        XCTAssertNil(invalidRecord.whisperModel)
        
        // Test no model (should return nil)
        let noModelRecord = TranscriptionRecord(
            text: "Test",
            provider: .parakeet
        )
        XCTAssertNil(noModelRecord.whisperModel)
    }

    // MARK: - Word/Character Count Tests (bug regression prevention)

    func testTranscriptionRecordWithMetrics() {
        let text = "Hello world test"
        let record = TranscriptionRecord(
            text: text,
            provider: .local,
            duration: 5.0,
            modelUsed: nil,
            wordCount: 3,
            characterCount: 16
        )

        XCTAssertEqual(record.wordCount, 3)
        XCTAssertEqual(record.characterCount, 16)
    }

    func testTranscriptionRecordDefaultMetricsAreZero() {
        let record = TranscriptionRecord(
            text: "Test",
            provider: .parakeet
        )

        // Verify defaults are 0 (not nil)
        XCTAssertEqual(record.wordCount, 0)
        XCTAssertEqual(record.characterCount, 0)
    }

    func testWordsPerMinuteCalculation() {
        let record = TranscriptionRecord(
            text: "Test",
            provider: .local,
            duration: 60.0,  // 1 minute
            wordCount: 120,
            characterCount: 600
        )

        // 120 words / 1 minute = 120 WPM
        XCTAssertEqual(record.wordsPerMinute, 120.0)
    }

    func testWordsPerMinuteWithZeroWordCount() {
        let record = TranscriptionRecord(
            text: "",
            provider: .parakeet,
            duration: 60.0,
            wordCount: 0,
            characterCount: 0
        )

        // Should return nil when wordCount is 0
        XCTAssertNil(record.wordsPerMinute)
    }

    func testWordsPerMinuteWithZeroDuration() {
        let record = TranscriptionRecord(
            text: "Test",
            provider: .local,
            duration: 0.0,
            wordCount: 10,
            characterCount: 50
        )

        // Should return nil when duration is 0
        XCTAssertNil(record.wordsPerMinute)
    }

    func testWordsPerMinuteWithNilDuration() {
        let record = TranscriptionRecord(
            text: "Test",
            provider: .parakeet,
            duration: nil,
            wordCount: 10,
            characterCount: 50
        )

        // Should return nil when duration is nil
        XCTAssertNil(record.wordsPerMinute)
    }
}