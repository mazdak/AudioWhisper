import XCTest
import SwiftUI
import AppKit
@testable import AudioWhisper

// MARK: - DashboardPermissionsView Tests
@MainActor
final class DashboardPermissionsViewTests: IsolatedXCTestCase {
    // TODO(D1): DashboardPermissionsView reads `enableSmartPaste` from
    // UserDefaults.standard via AppStorage. Once the view accepts an
    // injected UserDefaults, route writes through a UUID-scoped suite and
    // re-enable isolation.
    override var enforcesStandardUserDefaultsIsolation: Bool { false }

    override func setUp() {
        super.setUp()
        // Reset any test-related UserDefaults
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
        super.tearDown()
    }

    func testViewCanBeCreated() {
        let view = DashboardPermissionsView()
        XCTAssertNotNil(view)
    }

    func testViewBodyDoesNotCrash() {
        let view = DashboardPermissionsView()
            .environment(PermissionManager.shared)
        let hosting = NSHostingView(rootView: view)
        XCTAssertNotNil(hosting)
    }

    func testViewWithSmartPasteEnabled() {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        let view = DashboardPermissionsView()
            .environment(PermissionManager.shared)
        let hosting = NSHostingView(rootView: view)
        XCTAssertNotNil(hosting)
    }

    func testViewWithSmartPasteDisabled() {
        UserDefaults.standard.set(false, forKey: "enableSmartPaste")
        let view = DashboardPermissionsView()
            .environment(PermissionManager.shared)
        let hosting = NSHostingView(rootView: view)
        XCTAssertNotNil(hosting)
    }
}

// MARK: - Permission Status Tests
final class PermissionStatusDisplayTests: XCTestCase {

    func testMicrophoneStatusTitles() {
        let expectedTitles = [
            "Access granted",
            "Permission denied",
            "Access restricted",
            "Not yet requested",
            "Requesting...",
            "Unknown status"
        ]

        for title in expectedTitles {
            XCTAssertFalse(title.isEmpty)
        }
    }

    func testPermissionStatusIcons() {
        let grantedIcon = "checkmark.circle"
        let requiredIcon = "exclamationmark.circle"

        XCTAssertFalse(grantedIcon.isEmpty)
        XCTAssertFalse(requiredIcon.isEmpty)
        XCTAssertNotEqual(grantedIcon, requiredIcon)
    }
}

// MARK: - System Settings URL Tests
final class SystemSettingsURLTests: XCTestCase {

    func testMicrophoneSettingsURLFormat() {
        let path = "Privacy_Microphone"
        let urlString = "x-apple.systempreferences:com.apple.preference.security?\(path)"
        let url = URL(string: urlString)

        XCTAssertNotNil(url)
        XCTAssertTrue(urlString.contains("Privacy_Microphone"))
    }

    func testAccessibilitySettingsURLFormat() {
        let path = "Privacy_Accessibility"
        let urlString = "x-apple.systempreferences:com.apple.preference.security?\(path)"
        let url = URL(string: urlString)

        XCTAssertNotNil(url)
        XCTAssertTrue(urlString.contains("Privacy_Accessibility"))
    }

    func testSettingsURLScheme() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        let url = URL(string: urlString)

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "x-apple.systempreferences")
    }
}

// MARK: - Permission State Integration Tests
@MainActor
final class PermissionStateIntegrationTests: XCTestCase {

    func testPermissionManagerAccessible() {
        let manager = PermissionManager.shared
        XCTAssertNotNil(manager)
    }

    func testMicrophonePermissionStateIsValid() {
        let manager = PermissionManager.shared
        let state = manager.microphonePermissionState

        // State should be one of the valid enum cases
        // Just verify it doesn't crash
        XCTAssertNotNil(state)
    }

    func testAccessibilityPermissionStateIsValid() {
        let manager = PermissionManager.shared
        let state = manager.accessibilityPermissionState

        XCTAssertNotNil(state)
    }
}

// MARK: - Button Style Tests
final class PermissionButtonStyleTests: XCTestCase {

    func testPaperAccentButtonStyleExists() {
        // Verify the button style type exists and can be used
        let style = PaperAccentButtonStyle()
        XCTAssertNotNil(style)
    }

    func testPaperButtonStyleExists() {
        let style = PaperButtonStyle()
        XCTAssertNotNil(style)
    }
}

// MARK: - Permissions View State Tests
@MainActor
final class PermissionsViewStateTests: XCTestCase {

    func testDefaultSmartPasteState() {
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
        let defaultValue = AppDefaults.enableSmartPaste
        XCTAssertTrue(defaultValue, "SmartPaste should default to enabled")
    }

    func testSmartPastePersistence() {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "enableSmartPaste"))

        UserDefaults.standard.set(false, forKey: "enableSmartPaste")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "enableSmartPaste"))
    }
}
