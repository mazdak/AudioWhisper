import XCTest
@testable import AudioWhisper

@MainActor
final class HotkeyIntegrationTests: IsolatedXCTestCase {
    // TODO(D1): AppDelegate reads `immediateRecording` and press-and-hold
    // keys directly from UserDefaults.standard. Once those code paths accept
    // an injected UserDefaults, switch to a UUID-scoped suite and re-enable.
    override var enforcesStandardUserDefaultsIsolation: Bool { false }


    // MARK: - Notification Tests

    func testSpaceKeyNotificationPosted() {
        let expectation = XCTestExpectation(description: "Space key notification posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .spaceKeyPressed,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        NotificationCenter.default.post(name: .spaceKeyPressed, object: nil)

        wait(for: [expectation], timeout: 1.0)
    }

    func testRecordingStoppedNotificationPosted() {
        let expectation = XCTestExpectation(description: "Recording stopped notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .recordingStopped,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        NotificationCenter.default.post(name: .recordingStopped, object: nil)

        wait(for: [expectation], timeout: 1.0)
    }

    func testRecordingStartFailedNotificationPosted() {
        let expectation = XCTestExpectation(description: "Recording start failed notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .recordingStartFailed,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        NotificationCenter.default.post(name: .recordingStartFailed, object: nil)

        wait(for: [expectation], timeout: 1.0)
    }

    func testPressAndHoldSettingsChangedNotification() {
        let expectation = XCTestExpectation(description: "Settings changed notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .pressAndHoldSettingsChanged,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        NotificationCenter.default.post(name: .pressAndHoldSettingsChanged, object: nil)

        wait(for: [expectation], timeout: 1.0)
    }

    func testRestoreFocusNotificationPosted() {
        let expectation = XCTestExpectation(description: "Restore focus notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .restoreFocusToPreviousApp,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        NotificationCenter.default.post(name: .restoreFocusToPreviousApp, object: nil)

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Settings Persistence Tests

    func testPressAndHoldSettingsRoundTrip() {
        let original = PressAndHoldConfiguration(enabled: true, key: .rightOption, mode: .toggle)

        // Save
        PressAndHoldSettings.update(original)

        // Load
        let loaded = PressAndHoldSettings.configuration()

        XCTAssertEqual(loaded.enabled, original.enabled)
        XCTAssertEqual(loaded.key, original.key)
        XCTAssertEqual(loaded.mode, original.mode)

        // Cleanup
        PressAndHoldSettings.update(PressAndHoldConfiguration.defaults)
    }

    func testPressAndHoldDefaultConfiguration() {
        // Clear any existing settings
        UserDefaults.standard.removeObject(forKey: "pressAndHoldEnabled")
        UserDefaults.standard.removeObject(forKey: "pressAndHoldKeyIdentifier")
        UserDefaults.standard.removeObject(forKey: "pressAndHoldMode")

        let config = PressAndHoldSettings.configuration()

        XCTAssertEqual(config, PressAndHoldConfiguration.defaults)
    }

    func testPressAndHoldSettingsUpdatePostsNotification() {
        let expectation = XCTestExpectation(description: "Settings update posts notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .pressAndHoldSettingsChanged,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        let config = PressAndHoldConfiguration(enabled: true, key: .leftCommand, mode: .hold)
        PressAndHoldSettings.update(config)

        wait(for: [expectation], timeout: 1.0)

        // Cleanup
        PressAndHoldSettings.update(PressAndHoldConfiguration.defaults)
    }

    // MARK: - Key Configuration Tests

    func testAllPressAndHoldKeysHaveValidKeyCodes() {
        for key in PressAndHoldKey.allCases {
            XCTAssertGreaterThan(key.keyCode, 0, "\(key) should have valid keyCode")
        }
    }

    func testAllPressAndHoldKeysHaveModifierFlags() {
        for key in PressAndHoldKey.allCases {
            XCTAssertFalse(key.modifierFlag.isEmpty, "\(key) should have modifier flag")
        }
    }

    func testAllPressAndHoldKeysHaveDisplayNames() {
        for key in PressAndHoldKey.allCases {
            XCTAssertFalse(key.displayName.isEmpty, "\(key) should have display name")
        }
    }

    func testKeyCodeUniqueness() {
        let keyCodes = PressAndHoldKey.allCases.map { $0.keyCode }
        let uniqueKeyCodes = Set(keyCodes)
        XCTAssertEqual(keyCodes.count, uniqueKeyCodes.count, "All key codes should be unique")
    }

    // MARK: - Mode Tests

    func testAllPressAndHoldModesHaveDisplayNames() {
        for mode in PressAndHoldMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty, "\(mode) should have display name")
        }
    }

    func testModeRawValueRoundTrip() {
        for mode in PressAndHoldMode.allCases {
            let rawValue = mode.rawValue
            let restored = PressAndHoldMode(rawValue: rawValue)
            XCTAssertEqual(restored, mode)
        }
    }

    // MARK: - Configuration Equality Tests

    func testConfigurationEquality() {
        let config1 = PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold)
        let config2 = PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold)
        let config3 = PressAndHoldConfiguration(enabled: false, key: .rightCommand, mode: .hold)

        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }

    func testConfigurationDefaultsEquality() {
        let defaults = PressAndHoldConfiguration.defaults
        let manual = PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold)

        XCTAssertEqual(defaults, manual)
    }

    // MARK: - UserDefaults Integration Tests

    func testImmediateRecordingSettingPersistence() {
        let originalValue = UserDefaults.standard.bool(forKey: "immediateRecording")

        UserDefaults.standard.set(true, forKey: "immediateRecording")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "immediateRecording"))

        UserDefaults.standard.set(false, forKey: "immediateRecording")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "immediateRecording"))

        // Restore
        UserDefaults.standard.set(originalValue, forKey: "immediateRecording")
    }

    func testEnableSmartPasteSettingPersistence() {
        let originalValue = UserDefaults.standard.bool(forKey: "enableSmartPaste")

        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "enableSmartPaste"))

        UserDefaults.standard.set(false, forKey: "enableSmartPaste")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "enableSmartPaste"))

        // Restore
        UserDefaults.standard.set(originalValue, forKey: "enableSmartPaste")
    }

    // MARK: - Notification Name Tests

    func testNotificationNamesAreUnique() {
        let names: [Notification.Name] = [
            .spaceKeyPressed,
            .recordingStopped,
            .recordingStartFailed,
            .pressAndHoldSettingsChanged,
            .restoreFocusToPreviousApp
        ]

        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count, "All notification names should be unique")
    }
}
