import XCTest
import AVFoundation
@testable import AudioWhisper

@MainActor
final class AudioRecorderTests: IsolatedXCTestCase {
    // TODO(D1): AudioRecorder reads `autoBoostMicrophoneVolume` from
    // UserDefaults.standard directly. Once it accepts an injected
    // UserDefaults, route writes through a UUID-scoped suite and re-enable.
    override var enforcesStandardUserDefaultsIsolation: Bool { false }

    override func setUp() {
        super.setUp()
        // Reset permission state for each test
        PermissionManager.shared.microphonePermissionState = .unknown
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "autoBoostMicrophoneVolume")
        PermissionManager.shared.microphonePermissionState = .unknown
        super.tearDown()
    }
    
    func testStartRecordingSetsStateWhenPermissionGranted() {
        let startDate = Date(timeIntervalSince1970: 1_000)
        let sessionDate = Date(timeIntervalSince1970: 1_005)
        let recorder = makeRecorder(
            dates: [startDate, sessionDate],
            recorderFactory: { _, _ in MockAVAudioRecorder() }
        )
        PermissionManager.shared.microphonePermissionState = .granted

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
        PermissionManager.shared.microphonePermissionState = .denied

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
        PermissionManager.shared.microphonePermissionState = .granted

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
        PermissionManager.shared.microphonePermissionState = .granted
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
        PermissionManager.shared.microphonePermissionState = .granted
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
        PermissionManager.shared.microphonePermissionState = .granted

        let didStart = recorder.startRecording()
        
        XCTAssertFalse(didStart)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertNil(recorder.currentSessionStart)
    }
    
    // MARK: - Volume Restoration Tests (bug regression prevention)

    func testCleanupRecordingDoesNotRestoreVolume() async {
        // cleanupRecording should not restore volume because cancelRecording
        // also restores volume, which would cause double restoration.
        // This test verifies cleanupRecording does NOT restore volume.

        let mockVolumeManager = MockMicrophoneVolumeManager()
        let recorder = AudioRecorder(
            volumeManager: mockVolumeManager,
            recorderFactory: { _, _ in MockAVAudioRecorder() },
            dateProvider: { Date() }
        )
        PermissionManager.shared.microphonePermissionState = .granted
        UserDefaults.standard.set(true, forKey: "autoBoostMicrophoneVolume")

        // Start recording - this should boost volume
        XCTAssertTrue(recorder.startRecording())
        // Wait for async boost
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(mockVolumeManager.boostCount, 1, "Volume should be boosted once on start")

        // Reset restore count before testing cleanup
        mockVolumeManager.restoreCount = 0

        // Call cleanupRecording directly (not through cancelRecording)
        recorder.cleanupRecording()

        // Wait for any async operations
        try? await Task.sleep(nanoseconds: 100_000_000)

        // After fix, cleanupRecording should NOT restore volume
        XCTAssertEqual(mockVolumeManager.restoreCount, 0, "cleanupRecording should not restore volume (bug fix)")
    }

    func testCancelRecordingRestoresVolumeAtMostOnce() async {
        // Verify that cancelRecording restores volume at most once (bug fix prevents double restoration)
        // Note: This test verifies cleanupRecording doesn't restore volume; actual Task execution is timing-dependent

        let mockVolumeManager = MockMicrophoneVolumeManager()
        let recorder = AudioRecorder(
            volumeManager: mockVolumeManager,
            recorderFactory: { _, _ in MockAVAudioRecorder() },
            dateProvider: { Date() }
        )
        PermissionManager.shared.microphonePermissionState = .granted
        UserDefaults.standard.set(true, forKey: "autoBoostMicrophoneVolume")

        // Start recording
        XCTAssertTrue(recorder.startRecording())
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Reset counts before cancel
        mockVolumeManager.restoreCount = 0

        // Cancel recording
        recorder.cancelRecording()

        // Wait for async operations
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Should restore at most once (cleanupRecording no longer restores - bug fix)
        // Due to Task scheduling, restoreCount may be 0 or 1, but never more than 1
        XCTAssertLessThanOrEqual(mockVolumeManager.restoreCount, 1, "Volume should be restored at most once during cancel")
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

// MARK: - Mock Volume Manager for bug testing

private final class MockMicrophoneVolumeManager: MicrophoneVolumeManaging {
    var boostCount = 0
    var restoreCount = 0

    func boostMicrophoneVolume() async -> Bool {
        boostCount += 1
        return true
    }

    func restoreMicrophoneVolume() async {
        restoreCount += 1
    }

    func isVolumeControlAvailable() async -> Bool {
        return true
    }
}
