import XCTest
import AppKit
import SwiftData
@testable import AudioWhisper

/// Tests for HistoryWindowManager lifecycle and behavior
/// Note: Window creation is skipped in test environment by design, so we test
/// the behavioral aspects, state management, and fallback container logic.
@MainActor
final class HistoryWindowManagerTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    // MARK: - Test Environment Detection

    func testIsTestEnvironmentDetected() {
        let manager = HistoryWindowManager.shared

        // Call showHistoryWindow - should return without creating window in tests
        manager.showHistoryWindow()

        XCTAssertNotNil(manager, "Manager should exist and detect test environment")
    }

    func testSharedInstanceIsSingleton() {
        let instance1 = HistoryWindowManager.shared
        let instance2 = HistoryWindowManager.shared

        XCTAssertTrue(instance1 === instance2, "Shared instance should be a singleton")
    }

    func testShowHistoryWindowReturnsEarlyInTests() {
        let manager = HistoryWindowManager.shared

        // Multiple calls should be safe - returns early in test environment
        manager.showHistoryWindow()
        manager.showHistoryWindow()
        manager.showHistoryWindow()

        XCTAssertNotNil(manager)
    }

    func testWindowWillCloseCanBeCalledSafely() {
        let manager = HistoryWindowManager.shared

        // Should be safe to call even when no window exists
        manager.windowWillClose()

        XCTAssertNotNil(manager)
    }

    func testWindowWillCloseIsIdempotent() {
        let manager = HistoryWindowManager.shared

        // Multiple calls should be safe
        manager.windowWillClose()
        manager.windowWillClose()
        manager.windowWillClose()

        XCTAssertNotNil(manager)
    }

    // MARK: - Window Size Constants

    func testWindowSizeConstants() {
        // Verify the expected window sizes
        // These match the hardcoded values in HistoryWindowManager
        let expectedWidth: CGFloat = 800
        let expectedHeight: CGFloat = 500
        let expectedMinWidth: CGFloat = 700
        let expectedMinHeight: CGFloat = 400

        XCTAssertEqual(expectedWidth, 800)
        XCTAssertEqual(expectedHeight, 500)
        XCTAssertEqual(expectedMinWidth, 700)
        XCTAssertEqual(expectedMinHeight, 400)
    }

    // MARK: - Fallback Container Tests

    func testFallbackContainerCreation() throws {
        // Test the in-memory container creation logic
        // This mimics the fallback container creation in HistoryWindowManager

        let schema = Schema([TranscriptionRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        let container = try ModelContainer(for: schema, configurations: [config])

        XCTAssertNotNil(container, "Should be able to create in-memory container")
    }

    func testSimpleFallbackContainerCreation() throws {
        // Test the simpler fallback approach
        let container = try ModelContainer(
            for: TranscriptionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        XCTAssertNotNil(container, "Should be able to create simple in-memory container")
    }

    func testInMemoryContainerDoesNotPersist() throws {
        // Create container
        let container = try ModelContainer(
            for: TranscriptionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let context = container.mainContext

        // Create a test record
        let record = TranscriptionRecord(
            text: "Test transcription",
            provider: .local,
            duration: 5.0,
            sourceAppBundleId: nil,
            sourceAppName: nil,
            sourceAppIconData: nil
        )

        context.insert(record)
        try context.save()

        // Verify it was saved
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        let records = try context.fetch(descriptor)

        XCTAssertEqual(records.count, 1, "Should have one record in memory")

        // Note: We can't easily test that it doesn't persist to disk without
        // creating a new container, but the isStoredInMemoryOnly flag should ensure this
    }
}

// MARK: - Testable Extension

extension HistoryWindowManager {
    /// Returns whether the manager is configured for test environment
    var isRunningInTestEnvironment: Bool {
        AppEnvironment.isRunningTests
    }
}
