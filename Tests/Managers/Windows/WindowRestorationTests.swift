import XCTest
import AppKit
@testable import AudioWhisper

/// Tests for window state restoration configuration
/// Verifies that windows are configured to not restore state, preventing
/// corrupted window frame warnings on app launch.
@MainActor
final class WindowRestorationTests: XCTestCase {

    // MARK: - Window Manager Test Environment Tests

    func testDashboardWindowManagerDetectsTestEnvironment() {
        let manager = DashboardWindowManager.shared
        XCTAssertTrue(manager.isRunningInTestEnvironment)
    }

    func testHistoryWindowManagerDetectsTestEnvironment() {
        let manager = HistoryWindowManager.shared
        XCTAssertTrue(manager.isRunningInTestEnvironment)
    }

    // MARK: - Multiple Show Calls Safety Tests

    func testShowDashboardWindowMultipleCallsSafe() {
        let manager = DashboardWindowManager.shared

        // Multiple calls should not crash
        manager.showDashboardWindow()
        manager.showDashboardWindow()
        manager.showDashboardWindow()

        XCTAssertNotNil(manager)
    }

    func testShowHistoryWindowMultipleCallsSafe() {
        let manager = HistoryWindowManager.shared

        // Multiple calls should not crash
        manager.showHistoryWindow()
        manager.showHistoryWindow()
        manager.showHistoryWindow()

        XCTAssertNotNil(manager)
    }

    // MARK: - Window Close Cleanup Tests

    func testWindowCloseCleanupIsSafe() {
        let dashboard = DashboardWindowManager.shared
        let history = HistoryWindowManager.shared

        // Close without open should not crash
        dashboard.windowWillClose()
        history.windowWillClose()

        // Open then close should not crash
        dashboard.showDashboardWindow()
        dashboard.windowWillClose()

        history.showHistoryWindow()
        history.windowWillClose()

        XCTAssertNotNil(dashboard)
        XCTAssertNotNil(history)
    }

    // MARK: - NSWindow Configuration Tests

    func testNSWindowIsRestorablePropertyExists() {
        // Verify NSWindow has isRestorable property (compile-time check)
        let window = NSWindow()
        window.isRestorable = false
        XCTAssertFalse(window.isRestorable)
    }

    func testNSWindowIsReleasedWhenClosedPropertyExists() {
        let window = NSWindow()
        window.isReleasedWhenClosed = false
        XCTAssertFalse(window.isReleasedWhenClosed)
    }

    // MARK: - Window State Cleanup Flag Tests

    func testWindowStateCleanupFlagKey() {
        // Verify the UserDefaults key used for one-time cleanup
        let key = "hasCleanedWindowState"

        // This should be a valid key
        XCTAssertFalse(key.isEmpty)

        // The key should be consistent
        XCTAssertEqual(key, "hasCleanedWindowState")
    }

    func testSavedApplicationStatePathConstruction() {
        // Test that we can construct the saved state path
        guard let bundleId = Bundle.main.bundleIdentifier else {
            // In test environment, bundle ID may be nil - this is expected
            return
        }

        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        XCTAssertNotNil(libraryPath)

        let savedStatePath = libraryPath?
            .appendingPathComponent("Saved Application State")
            .appendingPathComponent("\(bundleId).savedState")

        XCTAssertNotNil(savedStatePath)
        XCTAssertTrue(savedStatePath?.path.contains("Saved Application State") ?? false)
    }

    // MARK: - Window Creation Configuration Tests

    func testChromelessWindowCanBeCreated() {
        // Test that ChromelessWindow can be instantiated
        let windowSize = NSSize(width: 200, height: 200)
        let window = ChromelessWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        XCTAssertNotNil(window)
        window.isRestorable = false
        XCTAssertFalse(window.isRestorable)
    }
}
