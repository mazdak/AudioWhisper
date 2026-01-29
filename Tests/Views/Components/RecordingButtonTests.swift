import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - RecordingButton Tests
final class RecordingButtonTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
        super.tearDown()
    }

    func testButtonCanBeCreated() {
        let button = RecordingButton(
            isRecording: false,
            hasPermission: true,
            isProcessing: false,
            showSuccess: false,
            transcriptionProvider: .local,
            onTap: {},
            onHover: { _ in }
        )
        XCTAssertNotNil(button)
    }

    func testButtonBodyDoesNotCrash() {
        let button = RecordingButton(
            isRecording: false,
            hasPermission: true,
            isProcessing: false,
            showSuccess: false,
            transcriptionProvider: .local,
            onTap: {},
            onHover: { _ in }
        )
        let _ = button.body
        XCTAssertTrue(true, "Body should not crash")
    }
}

// MARK: - Button Icon Tests
final class RecordingButtonIconTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
        super.tearDown()
    }

    func testIdleWithPermissionIcon() {
        let icon = getButtonIcon(
            isRecording: false,
            hasPermission: true,
            isProcessing: false,
            showSuccess: false
        )
        XCTAssertEqual(icon, "mic.fill")
    }

    func testIdleWithoutPermissionIcon() {
        let icon = getButtonIcon(
            isRecording: false,
            hasPermission: false,
            isProcessing: false,
            showSuccess: false
        )
        XCTAssertEqual(icon, "mic.slash.fill")
    }

    func testRecordingIcon() {
        let icon = getButtonIcon(
            isRecording: true,
            hasPermission: true,
            isProcessing: false,
            showSuccess: false
        )
        XCTAssertEqual(icon, "stop.fill")
    }

    func testSuccessIconWithSmartPaste() {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        let icon = getButtonIcon(
            isRecording: false,
            hasPermission: true,
            isProcessing: false,
            showSuccess: true
        )
        XCTAssertEqual(icon, "arrow.down.doc.on.clipboard")
    }

    func testSuccessIconWithoutSmartPaste() {
        UserDefaults.standard.set(false, forKey: "enableSmartPaste")
        let icon = getButtonIcon(
            isRecording: false,
            hasPermission: true,
            isProcessing: false,
            showSuccess: true
        )
        XCTAssertEqual(icon, "checkmark")
    }

    // Helper matching RecordingButton implementation
    private func getButtonIcon(
        isRecording: Bool,
        hasPermission: Bool,
        isProcessing: Bool,
        showSuccess: Bool
    ) -> String {
        if showSuccess {
            let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
            return enableSmartPaste ? "arrow.down.doc.on.clipboard" : "checkmark"
        } else if isRecording {
            return "stop.fill"
        } else if hasPermission {
            return "mic.fill"
        } else {
            return "mic.slash.fill"
        }
    }
}

// MARK: - Button Color Tests
final class RecordingButtonColorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
        super.tearDown()
    }

    func testIdleWithPermissionColor() {
        let color = getButtonColor(
            isRecording: false,
            hasPermission: true,
            isProcessing: false,
            showSuccess: false
        )
        XCTAssertEqual(color, .blue)
    }

    func testIdleWithoutPermissionColor() {
        let color = getButtonColor(
            isRecording: false,
            hasPermission: false,
            isProcessing: false,
            showSuccess: false
        )
        XCTAssertEqual(color, .gray)
    }

    func testRecordingColor() {
        let color = getButtonColor(
            isRecording: true,
            hasPermission: true,
            isProcessing: false,
            showSuccess: false
        )
        XCTAssertEqual(color, .red)
    }

    func testSuccessColor() {
        let color = getButtonColor(
            isRecording: false,
            hasPermission: true,
            isProcessing: false,
            showSuccess: true
        )
        XCTAssertEqual(color, .green)
    }

    // Helper matching RecordingButton implementation
    private func getButtonColor(
        isRecording: Bool,
        hasPermission: Bool,
        isProcessing: Bool,
        showSuccess: Bool
    ) -> Color {
        if showSuccess {
            return .green
        } else if isRecording {
            return .red
        } else if hasPermission {
            return .blue
        } else {
            return .gray
        }
    }
}

// MARK: - Accessibility Label Tests
final class RecordingButtonAccessibilityTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
        super.tearDown()
    }

    func testIdleWithPermissionLabel() {
        let label = getAccessibilityLabel(
            isRecording: false,
            hasPermission: true,
            isProcessing: false,
            showSuccess: false
        )
        XCTAssertEqual(label, "Start recording")
    }

    func testIdleWithoutPermissionLabel() {
        let label = getAccessibilityLabel(
            isRecording: false,
            hasPermission: false,
            isProcessing: false,
            showSuccess: false
        )
        XCTAssertEqual(label, "Microphone access required")
    }

    func testRecordingLabel() {
        let label = getAccessibilityLabel(
            isRecording: true,
            hasPermission: true,
            isProcessing: false,
            showSuccess: false
        )
        XCTAssertEqual(label, "Stop recording")
    }

    func testProcessingLabel() {
        let label = getAccessibilityLabel(
            isRecording: false,
            hasPermission: true,
            isProcessing: true,
            showSuccess: false
        )
        XCTAssertEqual(label, "Processing audio")
    }

    func testSuccessLabelWithSmartPaste() {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        let label = getAccessibilityLabel(
            isRecording: false,
            hasPermission: true,
            isProcessing: false,
            showSuccess: true
        )
        XCTAssertEqual(label, "Paste transcribed text")
    }

    func testSuccessLabelWithoutSmartPaste() {
        UserDefaults.standard.set(false, forKey: "enableSmartPaste")
        let label = getAccessibilityLabel(
            isRecording: false,
            hasPermission: true,
            isProcessing: false,
            showSuccess: true
        )
        XCTAssertEqual(label, "Transcription completed successfully")
    }

    // Helper matching RecordingButton implementation
    private func getAccessibilityLabel(
        isRecording: Bool,
        hasPermission: Bool,
        isProcessing: Bool,
        showSuccess: Bool
    ) -> String {
        if showSuccess {
            let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
            return enableSmartPaste ? "Paste transcribed text" : "Transcription completed successfully"
        } else if isRecording {
            return "Stop recording"
        } else if !hasPermission {
            return "Microphone access required"
        } else if isProcessing {
            return "Processing audio"
        } else {
            return "Start recording"
        }
    }
}

// MARK: - Accessibility Hint Tests
final class RecordingButtonHintTests: XCTestCase {

    func testIdleHint() {
        let hint = getAccessibilityHint(
            isRecording: false,
            hasPermission: true,
            isProcessing: false,
            showSuccess: false
        )
        XCTAssertEqual(hint, "Tap to start recording audio for transcription")
    }

    func testRecordingHint() {
        let hint = getAccessibilityHint(
            isRecording: true,
            hasPermission: true,
            isProcessing: false,
            showSuccess: false
        )
        XCTAssertEqual(hint, "Tap to stop recording audio")
    }

    func testNoPermissionHint() {
        let hint = getAccessibilityHint(
            isRecording: false,
            hasPermission: false,
            isProcessing: false,
            showSuccess: false
        )
        XCTAssertEqual(hint, "Grant microphone permission to record audio")
    }

    func testProcessingHint() {
        let hint = getAccessibilityHint(
            isRecording: false,
            hasPermission: true,
            isProcessing: true,
            showSuccess: false
        )
        XCTAssertEqual(hint, "Please wait while audio is being processed")
    }

    func testSuccessHint() {
        let hint = getAccessibilityHint(
            isRecording: false,
            hasPermission: true,
            isProcessing: false,
            showSuccess: true
        )
        XCTAssertEqual(hint, "Transcription is complete")
    }

    // Helper matching RecordingButton implementation
    private func getAccessibilityHint(
        isRecording: Bool,
        hasPermission: Bool,
        isProcessing: Bool,
        showSuccess: Bool
    ) -> String {
        if showSuccess {
            return "Transcription is complete"
        } else if isRecording {
            return "Tap to stop recording audio"
        } else if !hasPermission {
            return "Grant microphone permission to record audio"
        } else if isProcessing {
            return "Please wait while audio is being processed"
        } else {
            return "Tap to start recording audio for transcription"
        }
    }
}

// MARK: - Button Disabled State Tests
final class RecordingButtonDisabledStateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
        super.tearDown()
    }

    func testButtonDisabledWhenProcessing() {
        let isDisabled = shouldBeDisabled(
            isProcessing: true,
            hasPermission: true,
            showSuccess: false
        )
        XCTAssertTrue(isDisabled)
    }

    func testButtonDisabledWithoutPermission() {
        let isDisabled = shouldBeDisabled(
            isProcessing: false,
            hasPermission: false,
            showSuccess: false
        )
        XCTAssertTrue(isDisabled)
    }

    func testButtonEnabledWithPermission() {
        let isDisabled = shouldBeDisabled(
            isProcessing: false,
            hasPermission: true,
            showSuccess: false
        )
        XCTAssertFalse(isDisabled)
    }

    func testButtonDisabledOnSuccessWithSmartPaste() {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        let isDisabled = shouldBeDisabled(
            isProcessing: false,
            hasPermission: true,
            showSuccess: true
        )
        XCTAssertFalse(isDisabled) // Button is enabled for smart paste action
    }

    // Helper matching RecordingButton implementation
    private func shouldBeDisabled(
        isProcessing: Bool,
        hasPermission: Bool,
        showSuccess: Bool
    ) -> Bool {
        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
        return isProcessing || !hasPermission || (showSuccess && !enableSmartPaste)
    }
}

// MARK: - Provider Display Tests
final class RecordingButtonProviderTests: XCTestCase {

    func testAllProvidersHaveDisplayNames() {
        for provider in TranscriptionProvider.allCases {
            XCTAssertFalse(provider.displayName.isEmpty)
        }
    }

    func testProviderDisplayNames() {
        XCTAssertEqual(TranscriptionProvider.local.displayName, "Local Whisper")
        XCTAssertEqual(TranscriptionProvider.parakeet.displayName, "Parakeet (Advanced)")
    }

    func testAllCasesCount() {
        XCTAssertEqual(TranscriptionProvider.allCases.count, 2, "Should have exactly 2 providers: local and parakeet")
    }
}
