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

    // MARK: - B4: Persisted model validation

    func test_invalidStoredModelName_fallsBackToDefault() {
        // Capture and restore real preference so this test is hermetic.
        let key = "selectedWhisperModel"
        let original = UserDefaults.standard.string(forKey: key)
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        // Bogus stored value should resolve to the documented default model.
        UserDefaults.standard.set("nonexistent-model-name", forKey: key)
        XCTAssertEqual(LocalWhisperService.safeSelectedWhisperModel, LocalWhisperService.defaultModel)

        // Empty/missing value should likewise fall back to the default.
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertEqual(LocalWhisperService.safeSelectedWhisperModel, LocalWhisperService.defaultModel)

        // A valid stored value round-trips back to the matching enum case.
        UserDefaults.standard.set(WhisperModel.largeTurbo.rawValue, forKey: key)
        XCTAssertEqual(LocalWhisperService.safeSelectedWhisperModel, .largeTurbo)
    }
}

// MARK: - LocalWhisperError Tests
class LocalWhisperErrorTests: XCTestCase {
    
    func testErrorDescriptions() {
        let errors: [(LocalWhisperError, String)] = [
            (.modelNotDownloaded, "Whisper model not downloaded. Please download the model in Settings before using offline transcription."),
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

// MARK: - WhisperModel Tests
class WhisperModelTests: XCTestCase {

    func testWhisperModelDisplayNames() {
        // Display names include the file size
        XCTAssertTrue(WhisperModel.tiny.displayName.hasPrefix("Tiny"))
        XCTAssertTrue(WhisperModel.base.displayName.hasPrefix("Base"))
        XCTAssertTrue(WhisperModel.small.displayName.hasPrefix("Small"))
        XCTAssertTrue(WhisperModel.largeTurbo.displayName.hasPrefix("Large Turbo"))

        // All display names should include size info
        for model in [WhisperModel.tiny, .base, .small, .largeTurbo] {
            XCTAssertTrue(model.displayName.contains("MB") || model.displayName.contains("GB"),
                          "\(model) displayName should contain size")
        }
    }

    func testWhisperModelWhisperKitNames() {
        // Verify all models have valid WhisperKit model names
        for model in [WhisperModel.tiny, .base, .small, .largeTurbo] {
            XCTAssertTrue(model.whisperKitModelName.hasPrefix("openai_whisper-"))
            XCTAssertFalse(model.whisperKitModelName.isEmpty)
        }
    }

    func testWhisperModelEstimatedSizesAreReasonable() {
        // Verify sizes are in reasonable range (1MB to 2GB)
        let minSize: Int64 = 1 * 1024 * 1024  // 1 MB
        let maxSize: Int64 = 2 * 1024 * 1024 * 1024  // 2 GB

        for model in [WhisperModel.tiny, .base, .small, .largeTurbo] {
            XCTAssertGreaterThan(model.estimatedSize, minSize, "\(model.displayName) size too small")
            XCTAssertLessThan(model.estimatedSize, maxSize, "\(model.displayName) size too large")
        }
    }

    func testWhisperModelSizesAreOrdered() {
        // Tiny < Base < Small < Large Turbo
        XCTAssertLessThan(WhisperModel.tiny.estimatedSize, WhisperModel.base.estimatedSize)
        XCTAssertLessThan(WhisperModel.base.estimatedSize, WhisperModel.small.estimatedSize)
        XCTAssertLessThan(WhisperModel.small.estimatedSize, WhisperModel.largeTurbo.estimatedSize)
    }
}

// MARK: - Cache Management Tests
class LocalWhisperServiceCacheTests: XCTestCase {
    var service: LocalWhisperService!

    override func setUp() {
        super.setUp()
        service = LocalWhisperService()
    }

    override func tearDown() async throws {
        await service.clearCache()
        service = nil
        try super.tearDownWithError()
    }

    func testClearCacheDoesNotThrow() async {
        // Clearing an empty cache should not throw
        await service.clearCache()

        // Clearing again should also be fine
        await service.clearCache()
    }

    func testMultipleClearCacheCalls() async {
        // Multiple sequential clears should work
        for _ in 0..<5 {
            await service.clearCache()
        }
    }

    func testConcurrentCacheClear() async {
        // Concurrent cache clears should be handled safely
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await self.service.clearCache()
                }
            }
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
