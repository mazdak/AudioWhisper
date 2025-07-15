import XCTest
import Foundation
import AVFoundation
@preconcurrency import WhisperKit
@testable import AudioWhisper

// MARK: - Simple Test Implementation
class LocalWhisperServiceTests: XCTestCase {
    var service: LocalWhisperService!
    var testAudioURL: URL!
    
    override func setUp() {
        super.setUp()
        service = LocalWhisperService()
        
        // Create a temporary test audio file
        let tempDir = FileManager.default.temporaryDirectory
        testAudioURL = tempDir.appendingPathComponent("test_audio.m4a")
        
        // Create empty file for testing
        FileManager.default.createFile(atPath: testAudioURL.path, contents: Data(), attributes: nil)
    }
    
    override func tearDown() {
        // Clean up test file
        try? FileManager.default.removeItem(at: testAudioURL)
        super.tearDown()
    }
    
    func testWhisperModelMapping() {
        // Test that model names map correctly
        XCTAssertEqual(WhisperModel.tiny.whisperKitModelName, "openai_whisper-tiny")
        XCTAssertEqual(WhisperModel.base.whisperKitModelName, "openai_whisper-base")
        XCTAssertEqual(WhisperModel.small.whisperKitModelName, "openai_whisper-small")
        XCTAssertEqual(WhisperModel.largeTurbo.whisperKitModelName, "openai_whisper-large-v3_turbo")
    }
    
    func testEstimatedSizes() {
        // Test that estimated sizes are reasonable
        XCTAssertEqual(WhisperModel.tiny.estimatedSize, 39 * 1024 * 1024)
        XCTAssertEqual(WhisperModel.base.estimatedSize, 142 * 1024 * 1024)
        XCTAssertEqual(WhisperModel.small.estimatedSize, 466 * 1024 * 1024)
        XCTAssertEqual(WhisperModel.largeTurbo.estimatedSize, 1536 * 1024 * 1024)
    }
    
    func testCacheClearing() async {
        // Test that cache can be cleared without errors
        await service.clearCache()
        // If no exception is thrown, the test passes
    }
    
    // Note: Integration tests with actual WhisperKit would require models to be downloaded
    // For CI/CD, we'd need a separate test that can run with actual models
    func testServiceInitialization() {
        // Test that service can be initialized
        let newService = LocalWhisperService()
        XCTAssertNotNil(newService)
    }
}

// MARK: - LocalWhisperError Tests
class LocalWhisperErrorTests: XCTestCase {
    
    func testErrorDescriptions() {
        let errors: [(LocalWhisperError, String)] = [
            (.modelNotDownloaded, "Whisper model not downloaded. Please download the model first."),
            (.invalidAudioFile, "Invalid audio file format"),
            (.bufferAllocationFailed, "Failed to allocate audio buffer"),
            (.noChannelData, "No audio channel data found"),
            (.resamplingFailed, "Failed to resample audio"),
            (.transcriptionFailed, "Transcription failed")
        ]
        
        for (error, expectedDescription) in errors {
            XCTAssertEqual(error.errorDescription, expectedDescription)
        }
    }
}

// MARK: - Performance Tests
class LocalWhisperServicePerformanceTests: XCTestCase {
    
    func testServiceCreationPerformance() {
        measure {
            let service = LocalWhisperService()
            Task {
                await service.clearCache()
            }
        }
    }
}