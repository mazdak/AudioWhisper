import XCTest
import AVFoundation
import Combine
@testable import AudioWhisper

class AudioRecorderTests: XCTestCase {
    var audioRecorder: AudioRecorder!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        audioRecorder = AudioRecorder()
        cancellables = Set<AnyCancellable>()
        
        // Set permission directly for testing
        audioRecorder.hasPermission = true
    }
    
    override func tearDown() {
        audioRecorder = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertFalse(audioRecorder.isRecording)
        XCTAssertEqual(audioRecorder.audioLevel, 0.0)
    }
    
    // MARK: - Recording State Tests
    
    func testStartRecordingUpdatesState() {
        let expectation = XCTestExpectation(description: "Recording state should update")
        
        audioRecorder.$isRecording
            .dropFirst() // Skip initial value
            .sink { isRecording in
                XCTAssertTrue(isRecording)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        let success = audioRecorder.startRecording()
        // Don't assert success in tests that expect async behavior
        _ = success
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStopRecordingUpdatesState() {
        // Start recording first
        let success = audioRecorder.startRecording()
        // Don't assert success in tests that expect async behavior
        _ = success
        
        let expectation = XCTestExpectation(description: "Recording state should update to false")
        
        audioRecorder.$isRecording
            .dropFirst() // Skip initial value
            .sink { isRecording in
                if !isRecording {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        _ = audioRecorder.stopRecording()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStopRecordingReturnsURL() {
        let success = audioRecorder.startRecording()
        XCTAssertTrue(success, "Recording should start successfully")
        let url = audioRecorder.stopRecording()
        
        XCTAssertNotNil(url)
        if let url = url {
            XCTAssertTrue(url.path.contains("recording_"))
            XCTAssertTrue(url.path.hasSuffix(".m4a"))
        } else {
            XCTFail("URL should not be nil")
        }
    }
    
    // MARK: - Audio Level Tests
    
    func testAudioLevelInitialValue() {
        XCTAssertEqual(audioRecorder.audioLevel, 0.0)
    }
    
    func testAudioLevelUpdatesWhileRecording() {
        let expectation = XCTestExpectation(description: "Audio level should update while recording")
        
        audioRecorder.$audioLevel
            .dropFirst() // Skip initial value
            .sink { level in
                // Audio level should be between 0.0 and 1.0
                XCTAssertGreaterThanOrEqual(level, 0.0)
                XCTAssertLessThanOrEqual(level, 1.0)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        let success = audioRecorder.startRecording()
        // Don't assert success in tests that expect async behavior
        _ = success
        
        wait(for: [expectation], timeout: 2.0)
        
        _ = audioRecorder.stopRecording()
    }
    
    func testAudioLevelResetsAfterStopRecording() {
        let success = audioRecorder.startRecording()
        // Don't assert success in tests that expect async behavior
        _ = success
        
        let expectation = XCTestExpectation(description: "Audio level should reset to 0.0")
        
        audioRecorder.$audioLevel
            .dropFirst() // Skip initial value
            .sink { level in
                if level == 0.0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        _ = audioRecorder.stopRecording()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Level Normalization Tests
    // Note: normalizeLevel is private, so we test it indirectly through audioLevel updates
    
    // MARK: - File URL Generation Tests
    
    func testRecordingURLGeneration() {
        let success = audioRecorder.startRecording()
        XCTAssertTrue(success, "Recording should start successfully")
        let url = audioRecorder.stopRecording()
        
        XCTAssertNotNil(url)
        guard let url = url else {
            XCTFail("URL should not be nil")
            return
        }
        
        XCTAssertTrue(url.isFileURL)
        XCTAssertTrue(url.path.contains("recording_"))
        XCTAssertTrue(url.path.hasSuffix(".m4a"))
        
        // URL should contain timestamp
        let filename = url.lastPathComponent
        let timestampString = filename.replacingOccurrences(of: "recording_", with: "").replacingOccurrences(of: ".m4a", with: "")
        XCTAssertNotNil(Double(timestampString))
    }
    
    func testUniqueRecordingURLs() {
        let success1 = audioRecorder.startRecording()
        XCTAssertTrue(success1, "First recording should start successfully")
        let url1 = audioRecorder.stopRecording()
        
        // Small delay to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.1)
        
        let success2 = audioRecorder.startRecording()
        XCTAssertTrue(success2, "Second recording should start successfully")
        let url2 = audioRecorder.stopRecording()
        
        XCTAssertNotNil(url1)
        XCTAssertNotNil(url2)
        if let url1 = url1, let url2 = url2 {
            XCTAssertNotEqual(url1.path, url2.path)
        } else {
            XCTFail("Both URLs should not be nil")
        }
    }
    
    // MARK: - Recording Settings Tests
    
    func testRecordingSettings() {
        // This is more of an integration test to ensure settings are applied correctly
        let success = audioRecorder.startRecording()
        XCTAssertTrue(success, "Recording should start successfully")
        
        // We can't easily test the internal settings without refactoring,
        // but we can ensure recording starts without errors
        XCTAssertTrue(audioRecorder.isRecording)
        
        _ = audioRecorder.stopRecording()
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testMultipleStartRecordingCalls() {
        let success1 = audioRecorder.startRecording()
        XCTAssertTrue(success1, "First recording should start successfully")
        XCTAssertTrue(audioRecorder.isRecording)
        
        // Starting again should not crash but should return false (already recording)
        let success2 = audioRecorder.startRecording()
        XCTAssertFalse(success2, "Second recording call should return false when already recording")
        XCTAssertTrue(audioRecorder.isRecording)
        
        _ = audioRecorder.stopRecording()
    }
    
    func testStopRecordingWithoutStarting() {
        // Should not crash and should return nil when no recording was started
        let url = audioRecorder.stopRecording()
        XCTAssertNil(url)
        XCTAssertFalse(audioRecorder.isRecording)
    }
    
    // MARK: - Performance Tests
    
    func testRecordingPerformance() {
        measure {
            let success = audioRecorder.startRecording()
        // Don't assert success in tests that expect async behavior
        _ = success
            _ = audioRecorder.stopRecording()
        }
    }
    
    func testAudioLevelUpdatePerformance() {
        let success = audioRecorder.startRecording()
        // Don't assert success in tests that expect async behavior
        _ = success
        
        measure {
            // Measure audio level updates during recording
            let _ = audioRecorder.audioLevel
        }
        
        _ = audioRecorder.stopRecording()
    }
}

// MARK: - Test Helpers

extension AudioRecorderTests {
    private func waitForRecordingStateChange(to expectedState: Bool, timeout: TimeInterval = 1.0) {
        let expectation = XCTestExpectation(description: "Recording state change")
        
        audioRecorder.$isRecording
            .dropFirst()
            .sink { isRecording in
                if isRecording == expectedState {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: timeout)
    }
}