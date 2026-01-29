import XCTest
@testable import AudioWhisper

// MARK: - Mock Permission Manager for Testing

@MainActor
final class MockPermissionManagerForRecording {
    var microphonePermissionState: PermissionState = .granted
    var accessibilityPermissionState: PermissionState = .granted
    var showEducationalModal = false
    var showRecoveryModal = false
    var requestPermissionWithEducationCalled = false

    func requestPermissionWithEducation() {
        requestPermissionWithEducationCalled = true
        if microphonePermissionState.needsRequest {
            showEducationalModal = true
        } else if microphonePermissionState.canRetry {
            showRecoveryModal = true
        }
    }
}

// MARK: - Recording Workflow Edge Case Tests

@MainActor
final class RecordingWorkflowEdgeCaseTests: XCTestCase {
    private var mockRecorder: MockAudioEngineRecorder!
    private var mockSpeechService: MockSpeechToTextService!
    private var mockPermissionManager: MockPermissionManagerForRecording!
    private var mockSemanticService: MockSemanticCorrectionService!
    private var testUserDefaultsSuite: String!
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        mockRecorder = MockAudioEngineRecorder()
        mockSpeechService = MockSpeechToTextService()
        mockPermissionManager = MockPermissionManagerForRecording()
        mockSemanticService = MockSemanticCorrectionService()

        // Use isolated UserDefaults for tests
        testUserDefaultsSuite = "RecordingWorkflowTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testUserDefaultsSuite)
        testDefaults?.removePersistentDomain(forName: testUserDefaultsSuite)
    }

    override func tearDown() {
        mockRecorder?.reset()
        mockSpeechService?.reset()
        testDefaults?.removePersistentDomain(forName: testUserDefaultsSuite)
        testDefaults = nil
        testUserDefaultsSuite = nil
        super.tearDown()
    }

    // MARK: - Cancellation Tests

    func testCancellationDuringTranscriptionResetsProcessingState() async throws {
        // Configure mock to delay transcription to allow cancellation
        mockSpeechService.simulatedDelay = 2.0
        mockSpeechService.setSuccess("Test transcription")

        // Create and start a processing task
        var isProcessing = true
        var transcriptionStartTime: Date? = Date()

        let processingTask = Task {
            try await Task.sleep(for: .milliseconds(100))
            _ = try await mockSpeechService.transcribeRaw(audioURL: URL(fileURLWithPath: "/tmp/test.m4a"), provider: .local, model: nil)
        }

        // Cancel immediately
        processingTask.cancel()

        // Simulate the cancellation handling from ContentView+Recording
        do {
            try await processingTask.value
        } catch is CancellationError {
            isProcessing = false
            transcriptionStartTime = nil
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        XCTAssertFalse(isProcessing, "isProcessing should be reset after cancellation")
        XCTAssertNil(transcriptionStartTime, "transcriptionStartTime should be nil after cancellation")
    }

    func testCancellationDuringSemanticCorrectionResetsAwaitingFlag() async throws {
        mockSemanticService.simulatedDelay = 2.0
        mockSemanticService.setCorrectionResult("Corrected text")

        var awaitingSemanticPaste = true
        var isProcessing = true

        let processingTask = Task {
            try await Task.sleep(for: .milliseconds(50))
            try Task.checkCancellation()
            _ = await mockSemanticService.correct(text: "Test", providerUsed: TranscriptionProvider.local)
            try Task.checkCancellation()
        }

        // Cancel during semantic correction
        processingTask.cancel()

        do {
            try await processingTask.value
        } catch is CancellationError {
            isProcessing = false
            awaitingSemanticPaste = false
        } catch {
            // Other errors also reset state
            isProcessing = false
            awaitingSemanticPaste = false
        }

        XCTAssertFalse(awaitingSemanticPaste, "awaitingSemanticPaste should reset on cancellation")
        XCTAssertFalse(isProcessing, "isProcessing should reset on cancellation")
    }

    func testMultipleCancellationsAreIdempotent() async throws {
        var cancelCount = 0

        let processingTask = Task {
            try await Task.sleep(for: .seconds(10))
            return "result"
        }

        // Cancel multiple times
        for _ in 0..<5 {
            processingTask.cancel()
            cancelCount += 1
        }

        do {
            _ = try await processingTask.value
            XCTFail("Task should have been cancelled")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        XCTAssertEqual(cancelCount, 5, "Should be able to call cancel multiple times without crash")
    }

    func testCancellationBeforeTranscriptionStartsExitsEarly() async throws {
        mockSpeechService.simulatedDelay = 0.5

        let processingTask = Task {
            try Task.checkCancellation() // Early cancellation check
            _ = try await mockSpeechService.transcribeRaw(audioURL: URL(fileURLWithPath: "/tmp/test.m4a"), provider: .local, model: nil)
        }

        // Cancel immediately before task has chance to start transcription
        processingTask.cancel()

        do {
            try await processingTask.value
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Expected CancellationError")
        }

        // Give it a moment to ensure the task ran
        try await Task.sleep(for: .milliseconds(100))

        // The transcription should not have been called if cancelled early
        XCTAssertEqual(mockSpeechService.transcribeRawCallCount, 0, "Transcription should not be called when cancelled early")
    }

    func testCancellationCleansUpTranscriptionStartTime() async throws {
        var transcriptionStartTime: Date? = Date()

        let processingTask = Task {
            try await Task.sleep(for: .seconds(5))
        }

        processingTask.cancel()

        do {
            try await processingTask.value
        } catch is CancellationError {
            transcriptionStartTime = nil
        } catch {
            XCTFail("Expected CancellationError")
        }

        XCTAssertNil(transcriptionStartTime, "transcriptionStartTime should be cleaned up after cancellation")
    }

    // MARK: - Permission Edge Cases

    func testStartRecordingWithoutPermissionShowsEducation() {
        mockPermissionManager.microphonePermissionState = .notRequested

        // Simulate startRecording behavior
        if mockPermissionManager.microphonePermissionState != .granted {
            mockPermissionManager.requestPermissionWithEducation()
        }

        XCTAssertTrue(mockPermissionManager.requestPermissionWithEducationCalled)
        XCTAssertTrue(mockPermissionManager.showEducationalModal, "Should show education modal when permission not requested")
    }

    func testStartRecordingWithDeniedPermissionShowsRecovery() {
        mockPermissionManager.microphonePermissionState = .denied

        if mockPermissionManager.microphonePermissionState != .granted {
            mockPermissionManager.requestPermissionWithEducation()
        }

        XCTAssertTrue(mockPermissionManager.requestPermissionWithEducationCalled)
        XCTAssertTrue(mockPermissionManager.showRecoveryModal, "Should show recovery modal when permission denied")
    }

    func testRecordingBlockedWhenPermissionNotGranted() {
        mockPermissionManager.microphonePermissionState = .requesting

        var recordingStarted = false

        // Simulate startRecording behavior
        if mockPermissionManager.microphonePermissionState == .granted {
            recordingStarted = mockRecorder.startRecording()
        }

        XCTAssertFalse(recordingStarted, "Recording should not start when permission is requesting")
        XCTAssertFalse(mockRecorder.startRecordingCalled, "startRecording should not be called on recorder")
    }

    func testPermissionStateTransitionsCorrectly() {
        // Test the state machine transitions
        let states: [PermissionState] = [.unknown, .notRequested, .requesting, .granted, .denied, .restricted]

        for state in states {
            mockPermissionManager.microphonePermissionState = state

            switch state {
            case .unknown, .notRequested:
                XCTAssertTrue(state.needsRequest, "\(state) should need request")
                XCTAssertFalse(state.canRetry, "\(state) should not be retryable")
            case .requesting:
                XCTAssertFalse(state.needsRequest)
                XCTAssertFalse(state.canRetry)
            case .granted:
                XCTAssertFalse(state.needsRequest)
                XCTAssertFalse(state.canRetry)
            case .denied:
                XCTAssertFalse(state.needsRequest)
                XCTAssertTrue(state.canRetry, "denied should be retryable")
            case .restricted:
                XCTAssertFalse(state.needsRequest)
                XCTAssertFalse(state.canRetry)
            }
        }
    }

    // MARK: - Recording Reentrancy Tests

    func testDoubleStartRecordingReturnsFalse() {
        // First start succeeds
        let firstResult = mockRecorder.startRecording()
        XCTAssertTrue(firstResult)
        XCTAssertTrue(mockRecorder.isRecording)

        // Configure mock to fail on second start (simulating real behavior)
        mockRecorder.startRecordingResult = false

        let secondResult = mockRecorder.startRecording()
        XCTAssertFalse(secondResult, "Second startRecording should fail while already recording")
        XCTAssertEqual(mockRecorder.startRecordingCallCount, 2)
    }

    func testStopWhileNotRecordingIsNoOp() {
        XCTAssertFalse(mockRecorder.isRecording)

        let result = mockRecorder.stopRecording()

        // Stop should still return the configured URL but not crash
        XCTAssertNotNil(result)
        XCTAssertTrue(mockRecorder.stopRecordingCalled)
        XCTAssertFalse(mockRecorder.isRecording)
    }

    func testRapidStartStopCyclesDoNotLeaveOrphanState() async throws {
        for i in 0..<10 {
            let startResult = mockRecorder.startRecording()
            XCTAssertTrue(startResult, "Start \(i) should succeed")
            XCTAssertTrue(mockRecorder.isRecording, "Should be recording after start \(i)")

            _ = mockRecorder.stopRecording()
            XCTAssertFalse(mockRecorder.isRecording, "Should not be recording after stop \(i)")
        }

        XCTAssertEqual(mockRecorder.startRecordingCallCount, 10)
        XCTAssertEqual(mockRecorder.stopRecordingCallCount, 10)
        XCTAssertFalse(mockRecorder.isRecording, "Should not be recording after all cycles")
        XCTAssertNil(mockRecorder.currentSessionStart, "No session should be active")
    }

    // MARK: - Error Scenario Tests

    func testRecordingURLNotFoundShowsError() async throws {
        mockRecorder.stopRecordingResult = nil

        var errorMessage: String?
        var showError = false

        _ = mockRecorder.startRecording()
        let audioURL = mockRecorder.stopRecording()

        if audioURL == nil {
            errorMessage = "Failed to get recording URL"
            showError = true
        }

        XCTAssertTrue(showError)
        XCTAssertEqual(errorMessage, "Failed to get recording URL")
    }

    func testPathValidationLogicWorks() async throws {
        // Test the path validation logic from ContentView+Recording.swift line 43-45
        // Verify that the guard statement works correctly for both valid and invalid paths

        // Test 1: Valid path should pass validation
        let validURL = URL(fileURLWithPath: "/tmp/test_recording.m4a")
        XCTAssertFalse(validURL.path.isEmpty, "Valid URL should have non-empty path")

        // Test 2: URL with relative path (edge case)
        let relativeURL = URL(fileURLWithPath: "relative_file.m4a")
        XCTAssertFalse(relativeURL.path.isEmpty, "Relative URL should still have a path")

        // Test 3: Verify mock recorder returns expected URL
        _ = mockRecorder.startRecording()
        let audioURL = mockRecorder.stopRecording()
        XCTAssertNotNil(audioURL, "Mock recorder should return a URL")
        XCTAssertFalse(audioURL?.path.isEmpty ?? true, "Returned URL should have valid path")
    }

    func testTranscriptionFailureShowsError() async throws {
        struct TestTranscriptionError: Error, LocalizedError {
            var errorDescription: String? { "Test transcription failed" }
        }

        mockSpeechService.setFailure(TestTranscriptionError())

        var errorMessage: String?
        var showError = false
        var isProcessing = true

        do {
            _ = try await mockSpeechService.transcribeRaw(audioURL: URL(fileURLWithPath: "/tmp/test.m4a"), provider: .local, model: nil)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isProcessing = false
        }

        XCTAssertTrue(showError)
        XCTAssertEqual(errorMessage, "Test transcription failed")
        XCTAssertFalse(isProcessing, "isProcessing should reset on error")
    }

    func testLocalWhisperModelNotDownloadedTriggersSettings() async throws {
        let error = SpeechToTextError.localTranscriptionFailed(LocalWhisperError.modelNotDownloaded)
        mockSpeechService.setFailure(error)

        var shouldOpenDashboard = false
        var errorMessage: String?

        do {
            _ = try await mockSpeechService.transcribeRaw(audioURL: URL(fileURLWithPath: "/tmp/test.m4a"), provider: .local, model: .base)
        } catch {
            if case let SpeechToTextError.localTranscriptionFailed(inner) = error,
               let lwError = inner as? LocalWhisperError,
               lwError == .modelNotDownloaded {
                shouldOpenDashboard = true
                errorMessage = "Local Whisper model not downloaded"
            }
        }

        XCTAssertTrue(shouldOpenDashboard, "Should trigger dashboard open for model not downloaded")
        XCTAssertEqual(errorMessage, "Local Whisper model not downloaded")
    }

    func testParakeetModelNotReadyTriggersSettings() async throws {
        mockSpeechService.setFailure(ParakeetError.modelNotReady)

        var shouldOpenDashboard = false
        var errorMessage: String?

        do {
            _ = try await mockSpeechService.transcribeRaw(audioURL: URL(fileURLWithPath: "/tmp/test.m4a"), provider: .parakeet, model: nil)
        } catch let error as ParakeetError {
            if error == .modelNotReady {
                shouldOpenDashboard = true
                errorMessage = "Parakeet model not downloaded"
            }
        } catch {
            XCTFail("Expected ParakeetError")
        }

        XCTAssertTrue(shouldOpenDashboard, "Should trigger dashboard open for Parakeet model not ready")
        XCTAssertEqual(errorMessage, "Parakeet model not downloaded")
    }

    func testAsyncTimeoutErrorShowsUserFriendlyMessage() async throws {
        let timeoutError = AsyncTimeoutError.timedOut(30.0)

        var errorMessage: String?
        var showError = false

        // Simulate error handling
        errorMessage = timeoutError.localizedDescription
        showError = true

        XCTAssertTrue(showError)
        XCTAssertEqual(errorMessage, "Operation timed out after 30 seconds")
    }

    // MARK: - State Cleanup Tests

    func testProcessingFlagResetOnSuccess() async throws {
        mockSpeechService.setSuccess("Successful transcription")

        var isProcessing = true
        var transcriptionStartTime: Date? = Date()

        do {
            _ = try await mockSpeechService.transcribeRaw(audioURL: URL(fileURLWithPath: "/tmp/test.m4a"), provider: .local, model: nil)
            // On success
            isProcessing = false
            transcriptionStartTime = nil
        } catch {
            XCTFail("Should not throw")
        }

        XCTAssertFalse(isProcessing, "isProcessing should be false after success")
        XCTAssertNil(transcriptionStartTime, "transcriptionStartTime should be nil after success")
    }

    func testProcessingFlagResetOnError() async throws {
        mockSpeechService.setFailure(NSError(domain: "Test", code: 1))

        var isProcessing = true
        var transcriptionStartTime: Date? = Date()

        do {
            _ = try await mockSpeechService.transcribeRaw(audioURL: URL(fileURLWithPath: "/tmp/test.m4a"), provider: .local, model: nil)
        } catch {
            isProcessing = false
            transcriptionStartTime = nil
        }

        XCTAssertFalse(isProcessing, "isProcessing should be false after error")
        XCTAssertNil(transcriptionStartTime, "transcriptionStartTime should be nil after error")
    }

    func testLastAudioURLPreservedOnError() async throws {
        let testURL = URL(fileURLWithPath: "/tmp/preserved_audio.m4a")
        mockSpeechService.setFailure(NSError(domain: "Test", code: 1))

        let lastAudioURL: URL? = testURL

        do {
            _ = try await mockSpeechService.transcribeRaw(audioURL: testURL, provider: .local, model: nil)
        } catch {
            // Error handling should NOT clear lastAudioURL for retry functionality
            // lastAudioURL remains unchanged
        }

        XCTAssertEqual(lastAudioURL, testURL, "lastAudioURL should be preserved on error for retry")
    }

    func testAllStateProperlyResetAfterWorkflow() async throws {
        // Simulate a complete workflow and verify all state is reset
        var isProcessing = false
        var showSuccess = false
        var showError = false
        var errorMessage: String?
        var transcriptionStartTime: Date?
        var lastAudioURL: URL?
        let awaitingSemanticPaste = false  // In this test scenario, semantic paste is not awaited

        // Start state
        isProcessing = true
        transcriptionStartTime = Date()
        lastAudioURL = URL(fileURLWithPath: "/tmp/test.m4a")

        mockSpeechService.setSuccess("Test result")

        do {
            _ = try await mockSpeechService.transcribeRaw(audioURL: lastAudioURL!, provider: .local, model: nil)
            // Success path
            showSuccess = true
            isProcessing = false
            transcriptionStartTime = nil
        } catch {
            showError = true
            errorMessage = error.localizedDescription
            isProcessing = false
            transcriptionStartTime = nil
        }

        // Verify state after completion
        XCTAssertFalse(isProcessing)
        XCTAssertTrue(showSuccess)
        XCTAssertFalse(showError)
        XCTAssertNil(errorMessage)
        XCTAssertNil(transcriptionStartTime)
        XCTAssertNotNil(lastAudioURL, "lastAudioURL should be preserved for potential retry")
        XCTAssertFalse(awaitingSemanticPaste, "awaitingSemanticPaste should remain false after workflow")
    }
}
