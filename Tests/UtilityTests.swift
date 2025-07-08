import XCTest
import Foundation
import AVFoundation
@testable import AudioWhisper

class UtilityTests: XCTestCase {
    
    // MARK: - File System Tests
    
    func testTemporaryFileCreation() {
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = Date().timeIntervalSince1970
        let audioFilename = tempDir.appendingPathComponent("recording_\(timestamp).m4a")
        
        // Create temporary file
        guard let testData = "test data".data(using: .utf8) else {
            XCTFail("Failed to create test data")
            return
        }
        
        do {
            try testData.write(to: audioFilename)
            
            // Verify file exists
            XCTAssertTrue(FileManager.default.fileExists(atPath: audioFilename.path))
            
            // Clean up
            try FileManager.default.removeItem(at: audioFilename)
        } catch {
            XCTFail("Failed to create temporary file: \(error)")
        }
    }
    
    func testDocumentsDirectoryAccess() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        XCTAssertTrue(documentsPath.isFileURL)
        XCTAssertTrue(documentsPath.path.contains("Documents"))
    }
    
    func testUniqueFilenameGeneration() {
        let timestamp1 = Date().timeIntervalSince1970
        Thread.sleep(forTimeInterval: 0.001) // Small delay
        let timestamp2 = Date().timeIntervalSince1970
        
        let filename1 = "recording_\(timestamp1).m4a"
        let filename2 = "recording_\(timestamp2).m4a"
        
        XCTAssertNotEqual(filename1, filename2)
    }
    
    // MARK: - Audio Format Tests
    
    func testAudioRecordingSettings() {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        XCTAssertEqual(settings[AVFormatIDKey] as? Int, Int(kAudioFormatMPEG4AAC))
        XCTAssertEqual(settings[AVSampleRateKey] as? Int, 44100)
        XCTAssertEqual(settings[AVNumberOfChannelsKey] as? Int, 1)
        XCTAssertEqual(settings[AVEncoderAudioQualityKey] as? Int, AVAudioQuality.high.rawValue)
    }
    
    func testAudioQualityValues() {
        let qualities = [
            AVAudioQuality.min,
            AVAudioQuality.low,
            AVAudioQuality.medium,
            AVAudioQuality.high,
            AVAudioQuality.max
        ]
        
        for quality in qualities {
            XCTAssertTrue(quality.rawValue >= 0)
        }
        
        // High quality should be better than low quality
        XCTAssertGreaterThan(AVAudioQuality.high.rawValue, AVAudioQuality.low.rawValue)
    }
    
    // MARK: - Data Conversion Tests
    
    func testBase64AudioEncoding() {
        let testAudioData = "fake audio data".data(using: .utf8)!
        let base64String = testAudioData.base64EncodedString()
        
        XCTAssertFalse(base64String.isEmpty)
        
        // Decode back
        let decodedData = Data(base64Encoded: base64String)
        XCTAssertEqual(decodedData, testAudioData)
    }
    
    func testStringDataConversion() {
        let testString = "test API key"
        let data = testString.data(using: .utf8)!
        let decodedString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(decodedString, testString)
    }
    
    func testUnicodeStringHandling() {
        let unicodeString = "Hello 世界 🌍"
        let data = unicodeString.data(using: .utf8)!
        let decodedString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(decodedString, unicodeString)
    }
    
    // MARK: - URL Validation Tests
    
    func testValidURLs() {
        let validURLs = [
            "https://api.openai.com/v1/audio/transcriptions",
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent",
            "https://platform.openai.com/api-keys",
            "https://makersuite.google.com/app/apikey"
        ]
        
        for urlString in validURLs {
            let url = URL(string: urlString)
            XCTAssertNotNil(url)
            XCTAssertTrue(url!.scheme == "https")
        }
    }
    
    func testInvalidURLs() {
        let invalidURLs = [
            "", // Empty string
        ]
        
        for urlString in invalidURLs {
            let url = URL(string: urlString)
            XCTAssertNil(url)
        }
    }
    
    // MARK: - Timer Tests
    
    func testTimerCreation() {
        let expectation = XCTestExpectation(description: "Timer should fire")
        var counter = 0
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            counter += 1
            if counter >= 3 {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
        timer.invalidate()
        
        XCTAssertGreaterThanOrEqual(counter, 3)
    }
    
    func testTimerInvalidation() {
        var counter = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            counter += 1
        }
        
        // Let it run briefly
        Thread.sleep(forTimeInterval: 0.2)
        timer.invalidate()
        
        let counterAfterInvalidation = counter
        
        // Wait longer and verify counter didn't increase
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertEqual(counter, counterAfterInvalidation)
    }
    
    // MARK: - UserDefaults Tests
    
    func testUserDefaultsOperations() {
        let testKey = "test-key"
        let testValue = "test-value"
        
        // Set value
        UserDefaults.standard.set(testValue, forKey: testKey)
        
        // Get value
        let retrievedValue = UserDefaults.standard.string(forKey: testKey)
        XCTAssertEqual(retrievedValue, testValue)
        
        // Remove value
        UserDefaults.standard.removeObject(forKey: testKey)
        
        // Verify removed
        let removedValue = UserDefaults.standard.string(forKey: testKey)
        XCTAssertNil(removedValue)
    }
    
    func testUserDefaultsBoolOperations() {
        let testKey = "test-bool-key"
        
        // Set true
        UserDefaults.standard.set(true, forKey: testKey)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: testKey))
        
        // Set false
        UserDefaults.standard.set(false, forKey: testKey)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: testKey))
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: testKey)
    }
    
    // MARK: - Date and Time Tests
    
    func testTimestampGeneration() {
        let timestamp1 = Date().timeIntervalSince1970
        Thread.sleep(forTimeInterval: 0.001)
        let timestamp2 = Date().timeIntervalSince1970
        
        XCTAssertLessThan(timestamp1, timestamp2)
        XCTAssertGreaterThan(timestamp2 - timestamp1, 0)
    }
    
    func testDateFormatting() {
        let date = Date()
        let timestamp = date.timeIntervalSince1970
        
        XCTAssertGreaterThan(timestamp, 0)
        
        let recreatedDate = Date(timeIntervalSince1970: timestamp)
        XCTAssertEqual(date.timeIntervalSince1970, recreatedDate.timeIntervalSince1970, accuracy: 0.001)
    }
    
    // MARK: - String Manipulation Tests
    
    func testStringOperations() {
        let testString = "Hello, World!"
        
        XCTAssertFalse(testString.isEmpty)
        XCTAssertTrue(testString.contains("World"))
        XCTAssertTrue(testString.hasPrefix("Hello"))
        XCTAssertTrue(testString.hasSuffix("World!"))
    }
    
    func testStringCleaning() {
        let dirtyString = "  \n\t Test String \r\n  "
        let cleanString = dirtyString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        XCTAssertEqual(cleanString, "Test String")
    }
    
    // MARK: - Array and Collection Tests
    
    func testArrayOperations() {
        let numbers = [1, 2, 3, 4, 5]
        
        XCTAssertEqual(numbers.count, 5)
        XCTAssertEqual(numbers.first, 1)
        XCTAssertEqual(numbers.last, 5)
        XCTAssertTrue(numbers.contains(3))
        XCTAssertFalse(numbers.contains(6))
    }
    
    func testDictionaryOperations() {
        var dict = [String: String]()
        
        dict["key1"] = "value1"
        dict["key2"] = "value2"
        
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict["key1"], "value1")
        XCTAssertNil(dict["nonexistent"])
        
        dict.removeValue(forKey: "key1")
        XCTAssertEqual(dict.count, 1)
        XCTAssertNil(dict["key1"])
    }
    
    // MARK: - Performance Tests
    
    func testFileOperationPerformance() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let testData = "performance test data".data(using: .utf8) else {
            XCTFail("Failed to create performance test data")
            return
        }
        
        measure {
            for i in 0..<100 {
                let filename = tempDir.appendingPathComponent("perf_test_\(i).txt")
                do {
                    try testData.write(to: filename)
                    _ = try Data(contentsOf: filename)
                    try FileManager.default.removeItem(at: filename)
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }
    
    func testStringOperationPerformance() {
        let testString = "This is a test string for performance testing"
        
        measure {
            for _ in 0..<10000 {
                _ = testString.data(using: .utf8)
                _ = testString.uppercased()
                _ = testString.components(separatedBy: " ")
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryLeakPrevention() {
        weak var weakTimer: Timer?
        
        autoreleasepool {
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                // Do nothing
            }
            weakTimer = timer
            timer.invalidate()
        }
        
        // Timer should be deallocated
        XCTAssertNil(weakTimer)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        enum TestError: Error {
            case testCase
        }
        
        do {
            throw TestError.testCase
        } catch TestError.testCase {
            // Expected
        } catch {
            XCTFail("Unexpected error type")
        }
    }
    
    func testOptionalHandling() {
        let optionalString: String? = "test"
        let nilString: String? = nil
        
        XCTAssertNotNil(optionalString)
        XCTAssertNil(nilString)
        
        let unwrappedString = optionalString ?? "default"
        XCTAssertEqual(unwrappedString, "test")
        
        let unwrappedNil = nilString ?? "default"
        XCTAssertEqual(unwrappedNil, "default")
    }
}

// MARK: - Test Extensions and Helpers

extension UtilityTests {
    private func createTemporaryFile(content: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = tempDir.appendingPathComponent("temp_\(UUID().uuidString).txt")
        
        guard let data = content.data(using: .utf8) else {
            fatalError("Failed to create test data from content")
        }
        do {
            try data.write(to: filename)
        } catch {
            fatalError("Failed to write test file: \(error)")
        }
        return filename
    }
    
    private func cleanupTemporaryFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}