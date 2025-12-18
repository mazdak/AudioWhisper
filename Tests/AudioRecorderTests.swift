import XCTest
import AVFoundation
@testable import AudioWhisper

@MainActor
final class AudioRecorderTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "autoBoostMicrophoneVolume")
        super.tearDown()
    }
    
    func testStartRecordingSetsStateWhenPermissionGranted() {
        let startDate = Date(timeIntervalSince1970: 1_000)
        let sessionDate = Date(timeIntervalSince1970: 1_005)
        let recorder = makeRecorder(
            dates: [startDate, sessionDate],
            recorderFactory: { _, _ in MockAVAudioRecorder() }
        )
        recorder.hasPermission = true
        
        let didStart = recorder.startRecording()
        
        XCTAssertTrue(didStart)
        XCTAssertTrue(recorder.isRecording)
        XCTAssertEqual(recorder.currentSessionStart, sessionDate)
        XCTAssertNil(recorder.lastRecordingDuration)
    }
    
    func testStartRecordingReturnsFalseWithoutPermission() {
        var factoryCalled = false
        let recorder = makeRecorder(
            dates: [Date(), Date()],
            recorderFactory: { _, _ in
                factoryCalled = true
                return MockAVAudioRecorder()
            }
        )
        recorder.hasPermission = false
        
        let didStart = recorder.startRecording()
        
        XCTAssertFalse(didStart)
        XCTAssertFalse(factoryCalled, "Recorder factory should not be used without permission")
        XCTAssertFalse(recorder.isRecording)
    }
    
    func testStartRecordingPreventsReentrancy() {
        let recorder = makeRecorder(
            dates: [
                Date(timeIntervalSince1970: 2_000),
                Date(timeIntervalSince1970: 2_001),
                Date(timeIntervalSince1970: 2_002),
                Date(timeIntervalSince1970: 2_003)
            ],
            recorderFactory: { _, _ in MockAVAudioRecorder() }
        )
        recorder.hasPermission = true
        
        // Start recording first
        let firstStart = recorder.startRecording()
        XCTAssertTrue(firstStart, "First start should succeed")
        XCTAssertTrue(recorder.isRecording)

        // Attempt to start again while already recording
        let secondStart = recorder.startRecording()

        XCTAssertFalse(secondStart, "Second start should fail due to reentrancy guard")
        XCTAssertTrue(recorder.isRecording, "Should still be recording after failed reentrancy")
    }
    
    func testStopRecordingSetsDurationAndResetsState() {
        let startDate = Date(timeIntervalSince1970: 3_000)
        let sessionDate = Date(timeIntervalSince1970: 3_005)
        let endDate = Date(timeIntervalSince1970: 3_010)
        let recorder = makeRecorder(
            dates: [startDate, sessionDate, endDate],
            recorderFactory: { _, _ in MockAVAudioRecorder() }
        )
        recorder.hasPermission = true
        XCTAssertTrue(recorder.startRecording())
        
        let url = recorder.stopRecording()
        
        XCTAssertNotNil(url)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertNil(recorder.currentSessionStart)
        XCTAssertEqual(recorder.lastRecordingDuration ?? -1, endDate.timeIntervalSince(sessionDate), accuracy: 0.001)
    }
    
    func testStopRecordingWhenNotRecordingReturnsNil() {
        let recorder = makeRecorder(
            dates: [],
            recorderFactory: { _, _ in MockAVAudioRecorder() }
        )
        
        let url = recorder.stopRecording()
        
        XCTAssertNil(url)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertNil(recorder.currentSessionStart)
        XCTAssertNil(recorder.lastRecordingDuration)
    }
    
    func testCancelRecordingResetsState() {
        let recorder = makeRecorder(
            dates: [
                Date(timeIntervalSince1970: 4_000),
                Date(timeIntervalSince1970: 4_001)
            ],
            recorderFactory: { _, _ in MockAVAudioRecorder() }
        )
        recorder.hasPermission = true
        XCTAssertTrue(recorder.startRecording())
        
        recorder.cancelRecording()
        
        XCTAssertFalse(recorder.isRecording)
        XCTAssertNil(recorder.currentSessionStart)
        XCTAssertNil(recorder.lastRecordingDuration)
    }
    
    func testStartRecordingReturnsFalseWhenRecorderFactoryThrows() {
        enum TestError: Error { case failed }
        
        let recorder = makeRecorder(
            dates: [Date(), Date()],
            recorderFactory: { _, _ in throw TestError.failed }
        )
        recorder.hasPermission = true
        
        let didStart = recorder.startRecording()
        
        XCTAssertFalse(didStart)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertNil(recorder.currentSessionStart)
    }
    
    // MARK: - Helpers
    
    private func makeRecorder(
        dates: [Date],
        recorderFactory: @escaping (URL, [String: Any]) throws -> AVAudioRecorder
    ) -> AudioRecorder {
        let dateProvider = StubDateProvider(dates: dates)
        return AudioRecorder(
            recorderFactory: recorderFactory,
            dateProvider: { dateProvider.nextDate() }
        )
    }
}

private final class StubDateProvider {
    private var dates: [Date]
    
    init(dates: [Date]) {
        self.dates = dates
    }
    
    func nextDate() -> Date {
        guard !dates.isEmpty else {
            return Date()
        }
        return dates.removeFirst()
    }
}
