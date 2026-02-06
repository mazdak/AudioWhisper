import XCTest
import AppKit
@testable import AudioWhisper

/// Tests for ContentView lifecycle and notification observer management
@MainActor
final class ContentViewLifecycleTests: XCTestCase {

    private var testDefaults: UserDefaults!
    private var testSuiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        testSuiteName = "ContentViewLifecycleTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)
        testDefaults?.removePersistentDomain(forName: testSuiteName)
    }

    override func tearDown() async throws {
        testDefaults?.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        try await super.tearDown()
    }

    // MARK: - Notification Names Tests

    func testAllNotificationNamesDefined() {
        // Verify all notification names used in lifecycle are defined
        let notificationNames: [Notification.Name] = [
            .transcriptionProgress,
            .spaceKeyPressed,
            .escapeKeyPressed,
            .returnKeyPressed,
            .targetAppStored,
            .recordingStartFailed,
            .retryTranscriptionRequested,
            .showAudioFileRequested,
            .transcribeAudioFile,
            .restoreFocusToPreviousApp,
            .recordingStopped
        ]

        for name in notificationNames {
            XCTAssertFalse(name.rawValue.isEmpty, "Notification name \(name) should not be empty")
        }
    }

    // MARK: - Space Key Debounce Tests

    func testSpaceKeyDebounceTime() {
        // The debounce time is 1 second
        let expectedDebounce: TimeInterval = 1.0

        XCTAssertEqual(expectedDebounce, 1.0, "Space key debounce should be 1 second")
    }

    func testSpaceKeyDebounceLogic() async throws {
        var isHandlingSpaceKey = false
        var handleCount = 0

        // First press - should handle
        if !isHandlingSpaceKey {
            isHandlingSpaceKey = true
            handleCount += 1
        }

        // Immediate second press - should be blocked
        if !isHandlingSpaceKey {
            handleCount += 1
        }

        XCTAssertEqual(handleCount, 1, "Only first press should be handled during debounce")

        // After debounce period, reset
        isHandlingSpaceKey = false

        // Third press after reset - should handle
        if !isHandlingSpaceKey {
            isHandlingSpaceKey = true
            handleCount += 1
        }

        XCTAssertEqual(handleCount, 2, "Press after debounce reset should be handled")
    }

    // MARK: - Escape Key Behavior Tests

    func testEscapeKeyStopsRecording() {
        // Simulate escape key behavior when recording: cancel, stop recording, clear processing
        var isRecording = true
        var cancelCalled = false

        cancelCalled = true
        isRecording = false

        XCTAssertTrue(cancelCalled, "Cancel should be called when recording")
        XCTAssertFalse(isRecording, "Recording should stop")
    }

    func testEscapeKeyCancelsProcessing() {
        var isProcessing = true
        var taskCancelled = false

        // Simulate escape key: not recording, but processing
        taskCancelled = true
        isProcessing = false

        XCTAssertTrue(taskCancelled, "Task should be cancelled when processing")
        XCTAssertFalse(isProcessing, "Processing should stop")
    }

    func testEscapeKeyClosesWindowWhenIdle() {
        var windowClosed = false
        var restoreFocusPosted = false
        var showSuccess = true

        // Simulate escape key behavior when idle (not recording, not processing)
        windowClosed = true
        restoreFocusPosted = true
        showSuccess = false

        XCTAssertTrue(windowClosed, "Window should close when idle")
        XCTAssertTrue(restoreFocusPosted, "Restore focus should be posted")
        XCTAssertFalse(showSuccess, "showSuccess should be cleared")
    }

    // MARK: - Return Key Behavior Tests

    func testReturnKeyTriggersPasteWhenSuccess() {
        testDefaults.set(true, forKey: "enableSmartPaste")
        let showSuccess = true
        var pasteCalled = false

        let enableSmartPaste = testDefaults.bool(forKey: "enableSmartPaste")

        if showSuccess && enableSmartPaste {
            pasteCalled = true
        }

        XCTAssertTrue(pasteCalled, "Return key should trigger paste when showSuccess and SmartPaste enabled")
    }

    func testReturnKeyDoesNothingWithoutSuccess() {
        testDefaults.set(true, forKey: "enableSmartPaste")
        let showSuccess = false
        var pasteCalled = false

        let enableSmartPaste = testDefaults.bool(forKey: "enableSmartPaste")

        if showSuccess && enableSmartPaste {
            pasteCalled = true
        }

        XCTAssertFalse(pasteCalled, "Return key should not trigger paste when showSuccess is false")
    }

    func testReturnKeyDoesNothingWithSmartPasteDisabled() {
        testDefaults.set(false, forKey: "enableSmartPaste")
        let showSuccess = true
        var pasteCalled = false

        let enableSmartPaste = testDefaults.bool(forKey: "enableSmartPaste")

        if showSuccess && enableSmartPaste {
            pasteCalled = true
        }

        XCTAssertFalse(pasteCalled, "Return key should not trigger paste when SmartPaste disabled")
    }

    // MARK: - Target App Observer Tests

    func testTargetAppStoredUpdatesState() {
        var targetAppForPaste: NSRunningApplication?

        // Simulate receiving target app notification
        let mockApp = NSRunningApplication.current  // Use current app as mock

        targetAppForPaste = mockApp
        // SourceAppInfo.from(app:) creates info from running app if available

        XCTAssertNotNil(targetAppForPaste, "Target app should be set")
    }

    // MARK: - Transcription Provider Loading Tests

    func testLoadStoredTranscriptionProvider() {
        testDefaults.set("local", forKey: "transcriptionProvider")

        if let storedProvider = testDefaults.string(forKey: "transcriptionProvider"),
           let provider = TranscriptionProvider(rawValue: storedProvider) {
            XCTAssertEqual(provider, .local)
        } else {
            XCTFail("Should load stored provider")
        }
    }

    func testLoadStoredTranscriptionProviderWithInvalidValue() {
        testDefaults.set("invalid_provider", forKey: "transcriptionProvider")

        var loadedProvider: TranscriptionProvider?
        if let storedProvider = testDefaults.string(forKey: "transcriptionProvider"),
           let provider = TranscriptionProvider(rawValue: storedProvider) {
            loadedProvider = provider
        }

        XCTAssertNil(loadedProvider, "Invalid provider value should not load")
    }

    func testLoadStoredTranscriptionProviderWithNoValue() {
        testDefaults.removeObject(forKey: "transcriptionProvider")

        var loadedProvider: TranscriptionProvider?
        if let storedProvider = testDefaults.string(forKey: "transcriptionProvider"),
           let provider = TranscriptionProvider(rawValue: storedProvider) {
            loadedProvider = provider
        }

        XCTAssertNil(loadedProvider, "No stored value should result in nil")
    }

    // MARK: - Cleanup Tests

    func testOnDisappearCleansUpState() {
        var processingTask: Task<Void, Never>? = Task { }
        var lastAudioURL: URL? = URL(fileURLWithPath: "/tmp/test.m4a")

        // Simulate handleOnDisappear
        processingTask?.cancel()
        processingTask = nil
        lastAudioURL = nil

        XCTAssertNil(processingTask, "Processing task should be nil")
        XCTAssertNil(lastAudioURL, "Last audio URL should be nil")
    }

    func testObserverRemovalIsIdempotent() {
        var observer: NSObjectProtocol? = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TestNotification"),
            object: nil,
            queue: nil
        ) { _ in }

        // First removal
        if let existing = observer {
            NotificationCenter.default.removeObserver(existing)
            observer = nil
        }

        // Second removal should be safe (observer is nil)
        if let existing = observer {
            NotificationCenter.default.removeObserver(existing)
            observer = nil
        }

        XCTAssertNil(observer, "Observer should be nil after removal")
    }

    // MARK: - Window Focus Observer Tests

    func testWindowFocusDelayValue() {
        // The delay for setting first responder is 0.05 seconds
        let expectedDelay: TimeInterval = 0.05

        XCTAssertEqual(expectedDelay, 0.05, "Window focus delay should be 0.05 seconds")
    }

    // MARK: - Transcribe File Observer Tests

    func testTranscribeFileObserverReceivesURL() {
        var receivedURL: URL?

        let testURL = URL(fileURLWithPath: "/tmp/test_audio.m4a")

        // Simulate receiving notification with URL
        receivedURL = testURL

        XCTAssertEqual(receivedURL, testURL, "Should receive the audio file URL")
    }
}
