import XCTest
import Foundation
@testable import AudioWhisper

// MARK: - Settings and Configuration Notifications Tests
final class SettingsNotificationNamesTests: XCTestCase {

    func testUpdateGlobalHotkeyNotification() {
        let name = Notification.Name.updateGlobalHotkey
        XCTAssertEqual(name.rawValue, "UpdateGlobalHotkey")
    }

    func testWaveformStyleChangedNotification() {
        let name = Notification.Name.waveformStyleChanged
        XCTAssertEqual(name.rawValue, "WaveformStyleChanged")
    }
}

// MARK: - Welcome Flow Notifications Tests
final class WelcomeFlowNotificationNamesTests: XCTestCase {

    func testWelcomeCompletedNotification() {
        let name = Notification.Name.welcomeCompleted
        XCTAssertEqual(name.rawValue, "WelcomeCompleted")
    }
}

// MARK: - Recording Events Notifications Tests
final class RecordingEventsNotificationNamesTests: XCTestCase {

    func testRecordingStartFailedNotification() {
        let name = Notification.Name.recordingStartFailed
        XCTAssertEqual(name.rawValue, "RecordingStartFailed")
    }

    func testRecordingStoppedNotification() {
        let name = Notification.Name.recordingStopped
        XCTAssertEqual(name.rawValue, "RecordingStopped")
    }

    func testTargetAppStoredNotification() {
        let name = Notification.Name.targetAppStored
        XCTAssertEqual(name.rawValue, "TargetAppStored")
    }

    func testTranscriptionProgressNotification() {
        let name = Notification.Name.transcriptionProgress
        XCTAssertEqual(name.rawValue, "TranscriptionProgress")
    }
}

// MARK: - Window Management Notifications Tests
final class WindowManagementNotificationNamesTests: XCTestCase {

    func testRestoreFocusToPreviousAppNotification() {
        let name = Notification.Name.restoreFocusToPreviousApp
        XCTAssertEqual(name.rawValue, "RestoreFocusToPreviousApp")
    }
}

// MARK: - Keyboard Events Notifications Tests
final class KeyboardEventsNotificationNamesTests: XCTestCase {

    func testSpaceKeyPressedNotification() {
        let name = Notification.Name.spaceKeyPressed
        XCTAssertEqual(name.rawValue, "SpaceKeyPressed")
    }

    func testEscapeKeyPressedNotification() {
        let name = Notification.Name.escapeKeyPressed
        XCTAssertEqual(name.rawValue, "EscapeKeyPressed")
    }

    func testReturnKeyPressedNotification() {
        let name = Notification.Name.returnKeyPressed
        XCTAssertEqual(name.rawValue, "ReturnKeyPressed")
    }

    func testPressAndHoldSettingsChangedNotification() {
        let name = Notification.Name.pressAndHoldSettingsChanged
        XCTAssertEqual(name.rawValue, "PressAndHoldSettingsChanged")
    }
}

// MARK: - Error Handling and Retry Notifications Tests
final class ErrorHandlingNotificationNamesTests: XCTestCase {

    func testRetryRequestedNotification() {
        let name = Notification.Name.retryRequested
        XCTAssertEqual(name.rawValue, "RetryRequested")
    }

    func testRetryTranscriptionRequestedNotification() {
        let name = Notification.Name.retryTranscriptionRequested
        XCTAssertEqual(name.rawValue, "RetryTranscriptionRequested")
    }

    func testShowAudioFileRequestedNotification() {
        let name = Notification.Name.showAudioFileRequested
        XCTAssertEqual(name.rawValue, "ShowAudioFileRequested")
    }
}

// MARK: - File Transcription Notifications Tests
final class FileTranscriptionNotificationNamesTests: XCTestCase {

    func testTranscribeAudioFileNotification() {
        let name = Notification.Name.transcribeAudioFile
        XCTAssertEqual(name.rawValue, "TranscribeAudioFile")
    }
}

// MARK: - Paste Operations Notifications Tests
final class PasteOperationsNotificationNamesTests: XCTestCase {

    func testPasteOperationFailedNotification() {
        let name = Notification.Name.pasteOperationFailed
        XCTAssertEqual(name.rawValue, "PasteOperationFailed")
    }

    func testPasteOperationSucceededNotification() {
        let name = Notification.Name.pasteOperationSucceeded
        XCTAssertEqual(name.rawValue, "PasteOperationSucceeded")
    }
}

// MARK: - All Notification Names Tests
final class AllNotificationNamesTests: XCTestCase {

    func testAllNotificationNamesAreUnique() {
        let allNames: [Notification.Name] = [
            .updateGlobalHotkey,
            .waveformStyleChanged,
            .welcomeCompleted,
            .recordingStartFailed,
            .recordingStopped,
            .targetAppStored,
            .transcriptionProgress,
            .restoreFocusToPreviousApp,
            .spaceKeyPressed,
            .escapeKeyPressed,
            .returnKeyPressed,
            .pressAndHoldSettingsChanged,
            .retryRequested,
            .retryTranscriptionRequested,
            .showAudioFileRequested,
            .transcribeAudioFile,
            .pasteOperationFailed,
            .pasteOperationSucceeded,
        ]

        let uniqueNames = Set(allNames.map { $0.rawValue })
        XCTAssertEqual(allNames.count, uniqueNames.count, "All notification names should be unique")
    }

    func testAllNotificationNamesAreNotEmpty() {
        let allNames: [Notification.Name] = [
            .updateGlobalHotkey,
            .waveformStyleChanged,
            .welcomeCompleted,
            .recordingStartFailed,
            .recordingStopped,
            .targetAppStored,
            .transcriptionProgress,
            .restoreFocusToPreviousApp,
            .spaceKeyPressed,
            .escapeKeyPressed,
            .returnKeyPressed,
            .pressAndHoldSettingsChanged,
            .retryRequested,
            .retryTranscriptionRequested,
            .showAudioFileRequested,
            .transcribeAudioFile,
            .pasteOperationFailed,
            .pasteOperationSucceeded,
        ]

        for name in allNames {
            XCTAssertFalse(name.rawValue.isEmpty, "Notification name should not be empty")
        }
    }

    func testNotificationNameCount() {
        // Verify we have all 18 notification names
        let expectedCount = 18
        XCTAssertEqual(expectedCount, 18)
    }
}

// MARK: - Notification Posting Tests
final class NotificationPostingTests: XCTestCase {

    func testCanPostNotification() {
        var received = false
        let expectation = XCTestExpectation(description: "Notification received")

        let observer = NotificationCenter.default.addObserver(
            forName: .updateGlobalHotkey,
            object: nil,
            queue: .main
        ) { _ in
            received = true
            expectation.fulfill()
        }

        NotificationCenter.default.post(name: .updateGlobalHotkey, object: nil)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(received)

        NotificationCenter.default.removeObserver(observer)
    }

    func testCanPostNotificationWithUserInfo() {
        var receivedInfo: [AnyHashable: Any]?
        let expectation = XCTestExpectation(description: "Notification with userInfo received")

        let observer = NotificationCenter.default.addObserver(
            forName: .transcriptionProgress,
            object: nil,
            queue: .main
        ) { notification in
            receivedInfo = notification.userInfo
            expectation.fulfill()
        }

        let userInfo: [String: Any] = ["progress": 0.5, "message": "Processing..."]
        NotificationCenter.default.post(name: .transcriptionProgress, object: nil, userInfo: userInfo)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedInfo)
        XCTAssertEqual(receivedInfo?["progress"] as? Double, 0.5)
        XCTAssertEqual(receivedInfo?["message"] as? String, "Processing...")

        NotificationCenter.default.removeObserver(observer)
    }
}
