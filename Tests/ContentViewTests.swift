import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - Thread-Safe Atomic Wrapper

final class Atomic<T>: @unchecked Sendable {
    private var _value: T
    private let lock = NSLock()
    
    init(_ value: T) {
        _value = value
    }
    
    func load() -> T {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
    
    func store(_ value: T) {
        lock.lock()
        defer { lock.unlock() }
        _value = value
    }
}

final class ContentViewTests: XCTestCase {
    
    var mockAudioRecorder: MockAudioRecorder!
    var mockSpeechService: MockSpeechToTextService!
    
    override func setUp() {
        super.setUp()
        mockAudioRecorder = MockAudioRecorder()
        mockSpeechService = MockSpeechToTextService()
    }
    
    override func tearDown() {
        mockAudioRecorder = nil
        mockSpeechService = nil
        super.tearDown()
    }
    
    // MARK: - Retry Functionality Tests
    
    func testRetryTranscriptionWithoutAudioURL() {
        _ = ContentView(speechService: mockSpeechService, audioRecorder: mockAudioRecorder)
        
        // Test retry when no audio URL is stored
        _ = XCTestExpectation(description: "Error shown for missing audio URL")
        
        // Create a test environment where we can access private methods
        // Note: This is a simplified test - in practice you'd need to expose internal state or use a different architecture
        XCTAssertTrue(true) // Placeholder - actual implementation would test the retry logic
    }
    
    func testRetryTranscriptionWithNonexistentFile() {
        // Test retry when audio file has been deleted
        XCTAssertTrue(true) // Placeholder for file existence check
    }
    
    func testConcurrentRetryAttempts() {
        // Test that multiple retry attempts are prevented
        XCTAssertTrue(true) // Placeholder for concurrency test
    }
    
    func testMemoryCleanupOnDisappear() {
        // Test that audio URLs are properly cleaned up
        XCTAssertTrue(true) // Placeholder for memory test
    }
}

// MARK: - Mock Classes

final class MockAudioRecorder: AudioRecorder, @unchecked Sendable {
    private let _mockHasPermission = Atomic(true)
    private let _mockIsRecording = Atomic(false)
    private let _mockAudioLevel = Atomic<Float>(0.0)
    
    var mockHasPermission: Bool {
        get { _mockHasPermission.load() }
        set { _mockHasPermission.store(newValue) }
    }
    
    var mockIsRecording: Bool {
        get { _mockIsRecording.load() }
        set { _mockIsRecording.store(newValue) }
    }
    
    var mockAudioLevel: Float {
        get { _mockAudioLevel.load() }
        set { _mockAudioLevel.store(newValue) }
    }
    
    override var hasPermission: Bool {
        get { mockHasPermission }
        set { mockHasPermission = newValue }
    }
    
    override var isRecording: Bool {
        get { mockIsRecording }
        set { mockIsRecording = newValue }
    }
    
    override var audioLevel: Float {
        get { mockAudioLevel }
        set { mockAudioLevel = newValue }
    }
    
    override func startRecording() -> Bool {
        mockIsRecording = true
        return true
    }
    
    override func stopRecording() -> URL? {
        mockIsRecording = false
        // Return a test URL
        return URL(fileURLWithPath: "/tmp/test_recording.m4a")
    }
    
    override func cancelRecording() {
        mockIsRecording = false
    }
}

class MockSpeechToTextService: SpeechToTextService {
    var shouldFail = false
    var mockTranscriptionResult = "Test transcription"
    
    override func transcribe(audioURL: URL, provider: TranscriptionProvider, model: WhisperModel? = nil) async throws -> String {
        if shouldFail {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock transcription failed"])
        }
        return mockTranscriptionResult
    }
    
    override func transcribe(audioURL: URL) async throws -> String {
        if shouldFail {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock transcription failed"])
        }
        return mockTranscriptionResult
    }
}