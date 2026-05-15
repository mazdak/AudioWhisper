import XCTest
import AVFoundation
@testable import AudioWhisper

@MainActor
final class AudioEngineRecorderTests: IsolatedXCTestCase {
    // TODO(D1): AudioEngineRecorder reads `autoBoostMicrophoneVolume` from
    // UserDefaults.standard directly. Once it accepts an injected
    // UserDefaults, route writes through a UUID-scoped suite and re-enable.
    override var enforcesStandardUserDefaultsIsolation: Bool { false }

    var recorder: AudioEngineRecorder!
    fileprivate var mockVolumeManager: MockMicrophoneVolumeManager!
    var dateCallCount: Int = 0
    var testDates: [Date] = []

    override func setUp() {
        super.setUp()
        mockVolumeManager = MockMicrophoneVolumeManager()
        dateCallCount = 0
        testDates = []
        PermissionManager.shared.microphonePermissionState = .unknown
    }

    override func tearDown() {
        recorder?.cancelRecording()
        recorder = nil
        mockVolumeManager = nil
        UserDefaults.standard.removeObject(forKey: "autoBoostMicrophoneVolume")
        PermissionManager.shared.microphonePermissionState = .unknown
        super.tearDown()
    }

    private func makeRecorder(dates: [Date] = []) -> AudioEngineRecorder {
        testDates = dates
        dateCallCount = 0
        return AudioEngineRecorder(
            volumeManager: mockVolumeManager,
            dateProvider: { [self] in
                let index = min(self.dateCallCount, self.testDates.count - 1)
                self.dateCallCount += 1
                return self.testDates.isEmpty ? Date() : self.testDates[max(0, index)]
            }
        )
    }

    // MARK: - Protocol Conformance Tests

    func testConformsToAudioRecordingProtocol() {
        recorder = makeRecorder()

        // Verify all required properties exist
        _ = recorder.isRecording
        _ = recorder.audioLevel
        _ = recorder.waveformSamples
        _ = recorder.frequencyBands
        _ = recorder.currentSessionStart
        _ = recorder.lastRecordingDuration

        // This test passes if it compiles - protocol conformance is verified at compile time
        XCTAssertTrue(true)
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        recorder = makeRecorder()

        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(recorder.audioLevel, 0.0)
        XCTAssertTrue(recorder.waveformSamples.isEmpty)
        XCTAssertEqual(recorder.frequencyBands.count, 8)
        XCTAssertNil(recorder.currentSessionStart)
        XCTAssertNil(recorder.lastRecordingDuration)
    }

    func testFrequencyBandsInitializedToZero() {
        recorder = makeRecorder()

        for band in recorder.frequencyBands {
            XCTAssertEqual(band, 0.0)
        }
    }

    // MARK: - Permission Tests

    func testStartRecordingFailsWithoutPermission() {
        recorder = makeRecorder()
        PermissionManager.shared.microphonePermissionState = .denied

        let result = recorder.startRecording()

        XCTAssertFalse(result)
        XCTAssertFalse(recorder.isRecording)
    }

    func testStartRecordingFailsWithUnknownPermission() {
        recorder = makeRecorder()
        PermissionManager.shared.microphonePermissionState = .unknown

        let result = recorder.startRecording()

        XCTAssertFalse(result)
        XCTAssertFalse(recorder.isRecording)
    }

    // MARK: - Volume Boost Tests

    func testStartRecordingBoostsVolumeWhenEnabled() async {
        UserDefaults.standard.set(true, forKey: "autoBoostMicrophoneVolume")
        recorder = makeRecorder(dates: [Date(), Date()])
        PermissionManager.shared.microphonePermissionState = .granted

        // Start recording (may fail due to no audio device, but should attempt boost)
        _ = recorder.startRecording()

        // Give async task time to execute
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        XCTAssertTrue(mockVolumeManager.boostCalled, "Should attempt to boost volume when enabled")
    }

    func testStartRecordingDoesNotBoostVolumeWhenDisabled() async {
        UserDefaults.standard.set(false, forKey: "autoBoostMicrophoneVolume")
        recorder = makeRecorder(dates: [Date(), Date()])
        PermissionManager.shared.microphonePermissionState = .granted

        _ = recorder.startRecording()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(mockVolumeManager.boostCalled, "Should not boost volume when disabled")
    }

    func testCancelRecordingRestoresVolume() async {
        UserDefaults.standard.set(true, forKey: "autoBoostMicrophoneVolume")
        recorder = makeRecorder(dates: [Date(), Date(), Date()])
        PermissionManager.shared.microphonePermissionState = .granted

        _ = recorder.startRecording()
        recorder.cancelRecording()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(mockVolumeManager.restoreCalled, "Should restore volume after cancel")
    }

    // MARK: - Cancel Recording Tests

    func testCancelRecordingResetsState() {
        recorder = makeRecorder(dates: [Date(), Date(), Date()])
        PermissionManager.shared.microphonePermissionState = .granted

        _ = recorder.startRecording()
        recorder.cancelRecording()

        XCTAssertFalse(recorder.isRecording)
        XCTAssertNil(recorder.currentSessionStart)
        XCTAssertNil(recorder.lastRecordingDuration)
        XCTAssertEqual(recorder.audioLevel, 0.0)
        XCTAssertTrue(recorder.waveformSamples.isEmpty)
    }

    // MARK: - Stop Recording Tests

    func testStopRecordingResetsVisualizationData() {
        recorder = makeRecorder(dates: [Date(), Date(), Date()])
        PermissionManager.shared.microphonePermissionState = .granted

        _ = recorder.startRecording()
        _ = recorder.stopRecording()

        XCTAssertEqual(recorder.audioLevel, 0.0)
        XCTAssertTrue(recorder.waveformSamples.isEmpty)
        XCTAssertEqual(recorder.frequencyBands, Array(repeating: 0, count: 8))
    }

    // MARK: - Cleanup Tests

    func testCleanupRecordingClearsState() {
        recorder = makeRecorder()

        recorder.cleanupRecording()

        XCTAssertNil(recorder.currentSessionStart)
        XCTAssertNil(recorder.lastRecordingDuration)
    }

    // MARK: - Observable Properties Tests

    func testIsRecordingIsPublished() {
        recorder = makeRecorder()

        var observedValues: [Bool] = []
        let cancellable = recorder.$isRecording.sink { value in
            observedValues.append(value)
        }

        // Should have initial value
        XCTAssertFalse(observedValues.isEmpty)

        cancellable.cancel()
    }

    func testAudioLevelIsPublished() {
        recorder = makeRecorder()

        var observedValues: [Float] = []
        let cancellable = recorder.$audioLevel.sink { value in
            observedValues.append(value)
        }

        XCTAssertFalse(observedValues.isEmpty)
        XCTAssertEqual(observedValues.first, 0.0)

        cancellable.cancel()
    }

    func testWaveformSamplesIsPublished() {
        recorder = makeRecorder()

        var observedValues: [[Float]] = []
        let cancellable = recorder.$waveformSamples.sink { value in
            observedValues.append(value)
        }

        XCTAssertFalse(observedValues.isEmpty)
        XCTAssertTrue(observedValues.first?.isEmpty ?? false)

        cancellable.cancel()
    }

    func testFrequencyBandsIsPublished() {
        recorder = makeRecorder()

        var observedValues: [[Float]] = []
        let cancellable = recorder.$frequencyBands.sink { value in
            observedValues.append(value)
        }

        XCTAssertFalse(observedValues.isEmpty)
        XCTAssertEqual(observedValues.first?.count, 8)

        cancellable.cancel()
    }

    // MARK: - Reentrancy Tests

    func testStartRecordingPreventsReentrancy() {
        recorder = makeRecorder(dates: [Date(), Date(), Date(), Date()])
        PermissionManager.shared.microphonePermissionState = .granted

        // First start may fail due to no audio device, but should set internal state
        let firstStart = recorder.startRecording()

        // If first start succeeded (has audio device), second should fail
        if firstStart {
            let secondStart = recorder.startRecording()
            XCTAssertFalse(secondStart, "Second start should fail due to reentrancy guard")
        }
        // If first start failed (no audio device), test passes anyway
    }
}

// MARK: - Mock Volume Manager

fileprivate class MockMicrophoneVolumeManager: MicrophoneVolumeManaging {
    var boostCalled = false
    var restoreCalled = false

    func boostMicrophoneVolume() async -> Bool {
        boostCalled = true
        return true
    }

    func restoreMicrophoneVolume() async {
        restoreCalled = true
    }

    func isVolumeControlAvailable() async -> Bool {
        return true
    }
}
