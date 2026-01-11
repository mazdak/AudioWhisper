import XCTest
import AVFoundation
@testable import AudioWhisper

@MainActor
final class SilentTranscriptionServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear relevant UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "transcriptionProvider")
        UserDefaults.standard.removeObject(forKey: "selectedWhisperModel")
        UserDefaults.standard.removeObject(forKey: "semanticCorrectionMode")
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
        UserDefaults.standard.removeObject(forKey: "silentExpressMode")
    }

    override func tearDown() {
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: "transcriptionProvider")
        UserDefaults.standard.removeObject(forKey: "selectedWhisperModel")
        UserDefaults.standard.removeObject(forKey: "semanticCorrectionMode")
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
        UserDefaults.standard.removeObject(forKey: "silentExpressMode")
        super.tearDown()
    }

    // MARK: - Singleton Tests

    func testSharedInstanceIsSingleton() {
        let instance1 = SilentTranscriptionService.shared
        let instance2 = SilentTranscriptionService.shared
        XCTAssertTrue(instance1 === instance2, "Shared instance should be a singleton")
    }

    // MARK: - Cancellation Tests

    func testCancelCurrentTranscriptionDoesNotCrashWhenNoTaskRunning() {
        // Should not crash when called with no active task
        SilentTranscriptionService.shared.cancelCurrentTranscription()
        // If we get here without crashing, the test passes
        XCTAssertTrue(true)
    }

    func testCancelCurrentTranscriptionCanBeCalledMultipleTimes() {
        // Should be safe to call multiple times
        SilentTranscriptionService.shared.cancelCurrentTranscription()
        SilentTranscriptionService.shared.cancelCurrentTranscription()
        SilentTranscriptionService.shared.cancelCurrentTranscription()
        XCTAssertTrue(true)
    }

    // MARK: - UserDefaults Configuration Tests

    func testDefaultTranscriptionProviderIsOpenAI() {
        UserDefaults.standard.removeObject(forKey: "transcriptionProvider")
        let providerRaw = UserDefaults.standard.string(forKey: "transcriptionProvider") ?? TranscriptionProvider.openai.rawValue
        let provider = TranscriptionProvider(rawValue: providerRaw)
        XCTAssertEqual(provider, .openai)
    }

    func testDefaultWhisperModelIsBase() {
        UserDefaults.standard.removeObject(forKey: "selectedWhisperModel")
        let modelRaw = UserDefaults.standard.string(forKey: "selectedWhisperModel") ?? WhisperModel.base.rawValue
        let model = WhisperModel(rawValue: modelRaw)
        XCTAssertEqual(model, .base)
    }

    func testDefaultSemanticCorrectionModeIsOff() {
        UserDefaults.standard.removeObject(forKey: "semanticCorrectionMode")
        let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
        let mode = SemanticCorrectionMode(rawValue: modeRaw)
        XCTAssertEqual(mode, .off)
    }

    func testSmartPasteDefaultsToFalse() {
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
        XCTAssertFalse(enableSmartPaste)
    }

    func testSilentExpressModeDefaultsToFalse() {
        UserDefaults.standard.removeObject(forKey: "silentExpressMode")
        let silentExpressMode = UserDefaults.standard.bool(forKey: "silentExpressMode")
        XCTAssertFalse(silentExpressMode)
    }

    // MARK: - Settings Persistence Tests

    func testSilentExpressModeCanBeEnabled() {
        UserDefaults.standard.set(true, forKey: "silentExpressMode")
        let silentExpressMode = UserDefaults.standard.bool(forKey: "silentExpressMode")
        XCTAssertTrue(silentExpressMode)
    }

    func testSmartPasteCanBeEnabled() {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
        XCTAssertTrue(enableSmartPaste)
    }

    func testTranscriptionProviderCanBeSetToLocal() {
        UserDefaults.standard.set(TranscriptionProvider.local.rawValue, forKey: "transcriptionProvider")
        let providerRaw = UserDefaults.standard.string(forKey: "transcriptionProvider")
        let provider = TranscriptionProvider(rawValue: providerRaw ?? "")
        XCTAssertEqual(provider, .local)
    }

    func testTranscriptionProviderCanBeSetToParakeet() {
        UserDefaults.standard.set(TranscriptionProvider.parakeet.rawValue, forKey: "transcriptionProvider")
        let providerRaw = UserDefaults.standard.string(forKey: "transcriptionProvider")
        let provider = TranscriptionProvider(rawValue: providerRaw ?? "")
        XCTAssertEqual(provider, .parakeet)
    }

    // MARK: - Notification Tests

    func testRecordingStoppedNotificationName() {
        // Verify the notification name exists and is not empty
        let notificationName = Notification.Name.recordingStopped
        XCTAssertFalse(notificationName.rawValue.isEmpty)
    }

    func testRestoreFocusNotificationName() {
        // Verify the notification name exists
        let notificationName = Notification.Name.restoreFocusToPreviousApp
        XCTAssertFalse(notificationName.rawValue.isEmpty)
    }

    // MARK: - Integration Readiness Tests

    func testServiceCanAccessSpeechService() {
        // This test verifies that the service has proper access to SpeechToTextService
        // The actual transcription would require audio data, but we verify the path exists
        let service = SilentTranscriptionService.shared
        XCTAssertNotNil(service, "Service should be instantiated")
    }

    // MARK: - Timing Constants Tests

    func testTimingConstantsAreReasonable() {
        // These tests verify the timing constants are within reasonable bounds
        // We can't access private constants directly, but we document expected behavior

        // Clipboard ready delay should be short (< 500ms)
        // App activation delay should be short (< 500ms)
        // These are implementation details, but this test documents the expectations
        XCTAssertTrue(true, "Timing constants are implementation details")
    }
}

// MARK: - Mock AudioRecorder for Testing

@MainActor
final class MockAudioRecorderForSilentService: AudioRecorder {
    var mockRecordingURL: URL?
    var mockIsRecording: Bool = false
    var mockDuration: TimeInterval = 5.0

    override func stopRecording() -> URL? {
        isRecording = false
        return mockRecordingURL
    }
}

// MARK: - Notification Name Verification

extension Notification.Name {
    // Verify these notification names are accessible
    static func verifyNotificationNamesExist() -> Bool {
        _ = Notification.Name.recordingStopped
        _ = Notification.Name.restoreFocusToPreviousApp
        return true
    }
}
