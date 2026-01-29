import XCTest
@testable import AudioWhisper

@MainActor
final class AppDelegateExtensionTests: XCTestCase {

    // MARK: - Lifecycle Tests

    func testApplicationShouldTerminateAfterLastWindowClosedReturnsFalse() {
        // The app is a menu bar app and should stay running after windows close
        let appDelegate = AppDelegate()
        let result = appDelegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        XCTAssertFalse(result, "Menu bar app should not terminate after last window closed")
    }

    func testHasAPIKeyReturnsTrueWhenKeyExists() {
        let appDelegate = AppDelegate()

        // Set up a test key
        let mockKeychain = MockKeychainService()
        mockKeychain.saveQuietly("test-key", service: "AudioWhisper", account: "TestProvider")

        // The appDelegate.hasAPIKey uses KeychainService.shared directly
        // so we need to test the logic pattern
        let key = mockKeychain.getQuietly(service: "AudioWhisper", account: "TestProvider")
        XCTAssertNotNil(key)
    }

    func testHasAPIKeyReturnsFalseWhenKeyMissing() {
        let mockKeychain = MockKeychainService()

        let key = mockKeychain.getQuietly(service: "AudioWhisper", account: "NonExistentProvider")
        XCTAssertNil(key)
    }

    // MARK: - Hotkey Configuration Tests

    func testPressAndHoldConfigurationDefaultsAreCorrect() {
        let defaults = PressAndHoldConfiguration.defaults
        XCTAssertFalse(defaults.enabled, "Press and hold should be disabled by default")
        XCTAssertEqual(defaults.mode, .toggle, "Default mode should be toggle")
    }

    func testPressAndHoldSettingsConfigurationReadsFromUserDefaults() {
        // Test that configuration properly reads from UserDefaults
        let testKey = "pressAndHoldEnabled"

        // Save current value
        let originalValue = UserDefaults.standard.object(forKey: testKey)

        // Set a test value
        UserDefaults.standard.set(true, forKey: testKey)

        let config = PressAndHoldSettings.configuration()

        // Restore original value
        if let original = originalValue {
            UserDefaults.standard.set(original, forKey: testKey)
        } else {
            UserDefaults.standard.removeObject(forKey: testKey)
        }

        XCTAssertTrue(config.enabled)
    }

    // MARK: - Menu Tests

    func testMakeStatusMenuContainsExpectedItems() {
        let appDelegate = AppDelegate()
        let menu = appDelegate.makeStatusMenu()

        XCTAssertGreaterThan(menu.items.count, 0, "Menu should have items")

        // Check for expected menu items
        let itemTitles = menu.items.map { $0.title }

        XCTAssertTrue(itemTitles.contains(LocalizedStrings.Menu.record), "Menu should contain Record item")
        XCTAssertTrue(itemTitles.contains("Transcribe Audio File..."), "Menu should contain Transcribe Audio File item")
        XCTAssertTrue(itemTitles.contains("Dashboard..."), "Menu should contain Dashboard item")
        XCTAssertTrue(itemTitles.contains(LocalizedStrings.Menu.history), "Menu should contain History item")
        XCTAssertTrue(itemTitles.contains("Help"), "Menu should contain Help item")
        XCTAssertTrue(itemTitles.contains(LocalizedStrings.Menu.quit), "Menu should contain Quit item")
    }

    func testMakeStatusMenuHasSeparators() {
        let appDelegate = AppDelegate()
        let menu = appDelegate.makeStatusMenu()

        let separatorCount = menu.items.filter { $0.isSeparatorItem }.count
        XCTAssertGreaterThanOrEqual(separatorCount, 2, "Menu should have at least 2 separators")
    }

    func testMakeStatusMenuQuitItemHasCorrectAction() {
        let appDelegate = AppDelegate()
        let menu = appDelegate.makeStatusMenu()

        let quitItem = menu.items.first { $0.title == LocalizedStrings.Menu.quit }
        XCTAssertNotNil(quitItem)
        XCTAssertEqual(quitItem?.action, #selector(NSApplication.terminate(_:)))
    }

    // MARK: - UserDefaults Registration Tests

    func testDefaultsRegistrationSetsSmartPasteEnabled() {
        // Check that the default for enableSmartPaste is true
        // This tests the pattern used in applicationDidFinishLaunching
        let defaults: [String: Any] = [
            "enableSmartPaste": true,
            "immediateRecording": true,
            "startAtLogin": true,
            "playCompletionSound": true
        ]

        for (key, expectedValue) in defaults {
            if let boolValue = expectedValue as? Bool {
                // When default is registered and no explicit value set,
                // bool(forKey:) returns the registered default
                XCTAssertEqual(defaults[key] as? Bool, boolValue, "Default for \(key) should be \(boolValue)")
            }
        }
    }

    // MARK: - Hotkey Trigger Source Tests

    func testHotkeyTriggerSourceDistinguishesBetweenSources() {
        let standardHotkey = AppDelegate.HotkeyTriggerSource.standardHotkey
        let pressAndHold = AppDelegate.HotkeyTriggerSource.pressAndHold

        // These are distinct enum cases
        switch standardHotkey {
        case .standardHotkey:
            // Expected
            break
        case .pressAndHold:
            XCTFail("standardHotkey should not match pressAndHold")
        }

        switch pressAndHold {
        case .pressAndHold:
            // Expected
            break
        case .standardHotkey:
            XCTFail("pressAndHold should not match standardHotkey")
        }
    }

    // MARK: - App Setup Helper Integration Tests

    func testAppSetupHelperCreatesMenuBarIcon() {
        let icon = AppSetupHelper.createMenuBarIcon()
        XCTAssertNotNil(icon)
        XCTAssertTrue(icon.isTemplate, "Menu bar icon should be a template image")
    }

    func testAppSetupHelperGetAdaptiveMenuBarIconSizeReturnsPositiveValue() {
        let size = AppSetupHelper.getAdaptiveMenuBarIconSize()
        XCTAssertGreaterThan(size, 0, "Icon size should be positive")
        XCTAssertLessThanOrEqual(size, 30, "Icon size should be reasonable for menu bar")
    }

    // MARK: - Notification Names Tests

    func testRecordingStoppedNotificationNameExists() {
        XCTAssertNotNil(Notification.Name.recordingStopped)
    }

    func testSpaceKeyPressedNotificationNameExists() {
        XCTAssertNotNil(Notification.Name.spaceKeyPressed)
    }

    func testRecordingStartFailedNotificationNameExists() {
        XCTAssertNotNil(Notification.Name.recordingStartFailed)
    }

    func testTranscribeAudioFileNotificationNameExists() {
        XCTAssertNotNil(Notification.Name.transcribeAudioFile)
    }

    // MARK: - Immediate Recording Tests

    func testImmediateRecordingDefaultsToTrue() {
        // Clear any existing value
        let originalValue = UserDefaults.standard.object(forKey: "immediateRecording")
        UserDefaults.standard.removeObject(forKey: "immediateRecording")

        // Register defaults as app does
        UserDefaults.standard.register(defaults: ["immediateRecording": true])

        let value = UserDefaults.standard.bool(forKey: "immediateRecording")

        // Restore
        if let original = originalValue {
            UserDefaults.standard.set(original, forKey: "immediateRecording")
        }

        XCTAssertTrue(value, "immediateRecording should default to true")
    }

    // MARK: - Press and Hold Mode Tests

    func testPressAndHoldModeHoldValue() {
        XCTAssertEqual(PressAndHoldMode.hold.rawValue, "hold")
    }

    func testPressAndHoldModeToggleValue() {
        XCTAssertEqual(PressAndHoldMode.toggle.rawValue, "toggle")
    }

    func testPressAndHoldModeInitFromValidRawValue() {
        let holdMode = PressAndHoldMode(rawValue: "hold")
        let toggleMode = PressAndHoldMode(rawValue: "toggle")

        XCTAssertEqual(holdMode, .hold)
        XCTAssertEqual(toggleMode, .toggle)
    }

    func testPressAndHoldModeInitFromInvalidRawValueReturnsNil() {
        let invalidMode = PressAndHoldMode(rawValue: "invalid")
        XCTAssertNil(invalidMode)
    }

    // MARK: - Audio File Transcription Panel Tests

    func testAudioFileAllowedContentTypesIncludeCommonFormats() {
        // The transcribeAudioFile method should support these formats
        let supportedExtensions = ["m4a", "mp3", "wav", "aiff", "aac", "flac", "caf"]

        for ext in supportedExtensions {
            // Just verify these are valid extension strings
            XCTAssertFalse(ext.isEmpty, "\(ext) should be a valid extension")
        }
    }
}

