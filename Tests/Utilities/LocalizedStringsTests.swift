import XCTest
@testable import AudioWhisper

// MARK: - LocalizedStrings UI Tests
final class LocalizedStringsUITests: XCTestCase {

    func testReadyString() {
        XCTAssertEqual(LocalizedStrings.UI.ready, "Ready")
    }

    func testRecordingString() {
        XCTAssertEqual(LocalizedStrings.UI.recording, "Recording...")
    }

    func testProcessingString() {
        XCTAssertEqual(LocalizedStrings.UI.processing, "Processing...")
    }

    func testSuccessString() {
        XCTAssertEqual(LocalizedStrings.UI.success, "Success!")
    }

    func testMicrophoneAccessRequiredString() {
        XCTAssertEqual(LocalizedStrings.UI.microphoneAccessRequired, "Microphone access required")
    }

    func testSpaceToRecordString() {
        XCTAssertEqual(LocalizedStrings.UI.spaceToRecord, "Space to Record • Escape to Cancel")
    }

    func testUIStringsNotEmpty() {
        XCTAssertFalse(LocalizedStrings.UI.ready.isEmpty)
        XCTAssertFalse(LocalizedStrings.UI.recording.isEmpty)
        XCTAssertFalse(LocalizedStrings.UI.processing.isEmpty)
        XCTAssertFalse(LocalizedStrings.UI.success.isEmpty)
        XCTAssertFalse(LocalizedStrings.UI.microphoneAccessRequired.isEmpty)
        XCTAssertFalse(LocalizedStrings.UI.spaceToRecord.isEmpty)
    }
}

// MARK: - LocalizedStrings Alerts Tests
final class LocalizedStringsAlertsTests: XCTestCase {

    func testErrorTitle() {
        XCTAssertEqual(LocalizedStrings.Alerts.errorTitle, "Something went wrong")
    }

    func testMicrophoneAccessTitle() {
        XCTAssertEqual(LocalizedStrings.Alerts.microphoneAccessTitle, "Microphone Access Required")
    }

    func testMicrophoneAccessMessage() {
        let message = LocalizedStrings.Alerts.microphoneAccessMessage
        XCTAssertTrue(message.contains("microphone"))
        XCTAssertTrue(message.contains("System Settings"))
    }

    func testOpenSystemSettingsButton() {
        XCTAssertEqual(LocalizedStrings.Alerts.openSystemSettings, "Open System Settings")
    }

    func testCancelButton() {
        XCTAssertEqual(LocalizedStrings.Alerts.cancel, "Cancel")
    }

    func testAlertStringsNotEmpty() {
        XCTAssertFalse(LocalizedStrings.Alerts.errorTitle.isEmpty)
        XCTAssertFalse(LocalizedStrings.Alerts.microphoneAccessTitle.isEmpty)
        XCTAssertFalse(LocalizedStrings.Alerts.microphoneAccessMessage.isEmpty)
        XCTAssertFalse(LocalizedStrings.Alerts.openSystemSettings.isEmpty)
        XCTAssertFalse(LocalizedStrings.Alerts.cancel.isEmpty)
    }
}

// MARK: - LocalizedStrings Errors Tests
final class LocalizedStringsErrorsTests: XCTestCase {

    func testFailedToStartRecording() {
        let error = LocalizedStrings.Errors.failedToStartRecording
        XCTAssertTrue(error.contains("recording"))
    }

    func testFailedToGetRecordingURL() {
        let error = LocalizedStrings.Errors.failedToGetRecordingURL
        XCTAssertTrue(error.contains("recording"))
    }

    func testRecordingURLEmpty() {
        let error = LocalizedStrings.Errors.recordingURLEmpty
        XCTAssertTrue(error.contains("Recording"))
    }

    func testTranscriptionFailedContainsPlaceholder() {
        let error = LocalizedStrings.Errors.transcriptionFailed
        XCTAssertTrue(error.contains("%@"))
    }

    func testLocalTranscriptionFailedContainsPlaceholder() {
        let error = LocalizedStrings.Errors.localTranscriptionFailed
        XCTAssertTrue(error.contains("%@"))
    }

    func testFileTooLarge() {
        let error = LocalizedStrings.Errors.fileTooLarge
        XCTAssertTrue(error.contains("25MB"))
    }

    func testInvalidAudioFile() {
        let error = LocalizedStrings.Errors.invalidAudioFile
        XCTAssertTrue(error.contains("corrupted"))
    }

    func testApiKeyMissingContainsPlaceholder() {
        let error = LocalizedStrings.Errors.apiKeyMissing
        XCTAssertTrue(error.contains("%@"))
        XCTAssertTrue(error.contains("API key"))
    }

    func testFileUploadFailedContainsPlaceholder() {
        let error = LocalizedStrings.Errors.fileUploadFailed
        XCTAssertTrue(error.contains("%@"))
    }

    func testErrorStringsNotEmpty() {
        XCTAssertFalse(LocalizedStrings.Errors.failedToStartRecording.isEmpty)
        XCTAssertFalse(LocalizedStrings.Errors.failedToGetRecordingURL.isEmpty)
        XCTAssertFalse(LocalizedStrings.Errors.recordingURLEmpty.isEmpty)
        XCTAssertFalse(LocalizedStrings.Errors.transcriptionFailed.isEmpty)
        XCTAssertFalse(LocalizedStrings.Errors.localTranscriptionFailed.isEmpty)
        XCTAssertFalse(LocalizedStrings.Errors.fileTooLarge.isEmpty)
        XCTAssertFalse(LocalizedStrings.Errors.invalidAudioFile.isEmpty)
        XCTAssertFalse(LocalizedStrings.Errors.apiKeyMissing.isEmpty)
        XCTAssertFalse(LocalizedStrings.Errors.fileUploadFailed.isEmpty)
    }
}

// MARK: - LocalizedStrings LocalWhisper Tests
final class LocalizedStringsLocalWhisperTests: XCTestCase {

    func testModelNotDownloaded() {
        let error = LocalizedStrings.LocalWhisper.modelNotDownloaded
        XCTAssertTrue(error.contains("model"))
        XCTAssertTrue(error.contains("downloaded"))
    }

    func testInvalidAudioFormat() {
        let error = LocalizedStrings.LocalWhisper.invalidAudioFormat
        XCTAssertTrue(error.contains("format"))
    }

    func testFailedToAllocateBuffer() {
        let error = LocalizedStrings.LocalWhisper.failedToAllocateBuffer
        XCTAssertTrue(error.contains("memory"))
    }

    func testNoAudioChannelData() {
        let error = LocalizedStrings.LocalWhisper.noAudioChannelData
        XCTAssertTrue(error.contains("audio"))
    }

    func testFailedToResampleAudio() {
        let error = LocalizedStrings.LocalWhisper.failedToResampleAudio
        XCTAssertTrue(error.contains("audio"))
    }

    func testLocalWhisperStringsNotEmpty() {
        XCTAssertFalse(LocalizedStrings.LocalWhisper.modelNotDownloaded.isEmpty)
        XCTAssertFalse(LocalizedStrings.LocalWhisper.invalidAudioFormat.isEmpty)
        XCTAssertFalse(LocalizedStrings.LocalWhisper.failedToAllocateBuffer.isEmpty)
        XCTAssertFalse(LocalizedStrings.LocalWhisper.noAudioChannelData.isEmpty)
        XCTAssertFalse(LocalizedStrings.LocalWhisper.failedToResampleAudio.isEmpty)
    }
}

// MARK: - LocalizedStrings Menu Tests
final class LocalizedStringsMenuTests: XCTestCase {

    func testRecord() {
        XCTAssertEqual(LocalizedStrings.Menu.record, "Record")
    }

    func testSettings() {
        XCTAssertEqual(LocalizedStrings.Menu.settings, "Settings...")
    }

    func testQuit() {
        XCTAssertEqual(LocalizedStrings.Menu.quit, "Quit")
    }

    func testCloseWindow() {
        XCTAssertEqual(LocalizedStrings.Menu.closeWindow, "Close Window")
    }

    func testHistory() {
        XCTAssertEqual(LocalizedStrings.Menu.history, "History...")
    }

    func testMenuStringsNotEmpty() {
        XCTAssertFalse(LocalizedStrings.Menu.record.isEmpty)
        XCTAssertFalse(LocalizedStrings.Menu.settings.isEmpty)
        XCTAssertFalse(LocalizedStrings.Menu.quit.isEmpty)
        XCTAssertFalse(LocalizedStrings.Menu.closeWindow.isEmpty)
        XCTAssertFalse(LocalizedStrings.Menu.history.isEmpty)
    }
}

// MARK: - LocalizedStrings Settings Tests
final class LocalizedStringsSettingsTests: XCTestCase {

    func testTitle() {
        XCTAssertEqual(LocalizedStrings.Settings.title, "AudioWhisper Settings")
    }
}

// MARK: - LocalizedStrings Accessibility Tests
final class LocalizedStringsAccessibilityTests: XCTestCase {

    func testMicrophoneIcon() {
        XCTAssertEqual(LocalizedStrings.Accessibility.microphoneIcon, "AudioWhisper")
    }

    func testRecordingButton() {
        XCTAssertEqual(LocalizedStrings.Accessibility.recordingButton, "Recording button")
    }

    func testProgressIndicator() {
        XCTAssertEqual(LocalizedStrings.Accessibility.progressIndicator, "Download progress")
    }

    func testModelDownloadStatus() {
        XCTAssertEqual(LocalizedStrings.Accessibility.modelDownloadStatus, "Model download status")
    }

    func testAccessibilityStringsNotEmpty() {
        XCTAssertFalse(LocalizedStrings.Accessibility.microphoneIcon.isEmpty)
        XCTAssertFalse(LocalizedStrings.Accessibility.recordingButton.isEmpty)
        XCTAssertFalse(LocalizedStrings.Accessibility.progressIndicator.isEmpty)
        XCTAssertFalse(LocalizedStrings.Accessibility.modelDownloadStatus.isEmpty)
    }
}
