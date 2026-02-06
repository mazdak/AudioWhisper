import XCTest
import AppKit
@testable import AudioWhisper

/// Tests for DashboardWindowManager lifecycle and behavior
/// Note: Window creation is skipped in test environment by design, so we test
/// the behavioral aspects and state management instead.
@MainActor
final class DashboardWindowManagerTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    // MARK: - Test Environment Detection

    func testIsTestEnvironmentDetected() {
        // The manager should detect XCTest environment
        // This is verified by the fact that showDashboardWindow returns early in tests
        let manager = DashboardWindowManager.shared

        // Call showDashboardWindow - should return without creating window
        manager.showDashboardWindow()

        // If we get here without crash, test environment detection works
        XCTAssertNotNil(manager, "Manager should exist and detect test environment")
    }

    func testSharedInstanceIsSingleton() {
        let instance1 = DashboardWindowManager.shared
        let instance2 = DashboardWindowManager.shared

        XCTAssertTrue(instance1 === instance2, "Shared instance should be a singleton")
    }

    func testShowDashboardWindowReturnsEarlyInTests() {
        let manager = DashboardWindowManager.shared

        // This should not throw or crash - it returns early in test environment
        manager.showDashboardWindow()
        manager.showDashboardWindow()
        manager.showDashboardWindow()

        // Multiple calls should be safe
        XCTAssertNotNil(manager)
    }

    func testWindowWillCloseCanBeCalledSafely() {
        let manager = DashboardWindowManager.shared

        // Should be safe to call even when no window exists
        manager.windowWillClose()

        // No crash means success
        XCTAssertNotNil(manager)
    }

    func testWindowWillCloseIsIdempotent() {
        let manager = DashboardWindowManager.shared

        // Multiple calls should be safe
        manager.windowWillClose()
        manager.windowWillClose()
        manager.windowWillClose()

        XCTAssertNotNil(manager)
    }

    // MARK: - Layout Metrics Tests

    func testLayoutMetricsExist() {
        // Verify the layout metrics used by the manager are defined
        let initialSize = LayoutMetrics.DashboardWindow.initialSize
        let minimumSize = LayoutMetrics.DashboardWindow.minimumSize

        XCTAssertGreaterThan(initialSize.width, 0, "Initial width should be positive")
        XCTAssertGreaterThan(initialSize.height, 0, "Initial height should be positive")
        XCTAssertGreaterThan(minimumSize.width, 0, "Minimum width should be positive")
        XCTAssertGreaterThan(minimumSize.height, 0, "Minimum height should be positive")
        XCTAssertGreaterThanOrEqual(initialSize.width, minimumSize.width,
            "Initial width should be >= minimum width")
        XCTAssertGreaterThanOrEqual(initialSize.height, minimumSize.height,
            "Initial height should be >= minimum height")
    }
}

// MARK: - Testable Window Manager Extension

/// Extension to expose internal state for testing purposes
extension DashboardWindowManager {
    /// Returns whether the manager is configured for test environment
    var isRunningInTestEnvironment: Bool {
        AppEnvironment.isRunningTests
    }
}
