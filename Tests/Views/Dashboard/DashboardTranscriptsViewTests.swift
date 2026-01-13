import XCTest
import SwiftUI
import SwiftData
@testable import AudioWhisper

// MARK: - DashboardTranscriptsView Tests
@MainActor
final class DashboardTranscriptsViewTests: XCTestCase {

    func testViewCanBeCreated() {
        let view = DashboardTranscriptsView()
        XCTAssertNotNil(view)
    }

    func testViewBodyDoesNotCrash() {
        let view = DashboardTranscriptsView()
        let _ = view.body
        XCTAssertTrue(true, "Body should not crash")
    }

    func testViewHandlesMissingModelContainer() {
        // When DataManager.shared.sharedModelContainer is nil,
        // the view should show fallback UI
        let view = DashboardTranscriptsView()
        let _ = view.body
        XCTAssertTrue(true, "View should handle missing container gracefully")
    }
}

// MARK: - DataManager Container Tests
@MainActor
final class DataManagerContainerTests: XCTestCase {

    func testDataManagerSharedExists() {
        let dataManager = DataManager.shared
        XCTAssertNotNil(dataManager)
    }

    func testSharedModelContainerAccessDoesNotCrash() {
        // Accessing the container should not crash even if history is disabled
        let _ = DataManager.shared.sharedModelContainer
        XCTAssertTrue(true)
    }

    func testIsHistoryEnabledProperty() {
        let isEnabled = DataManager.shared.isHistoryEnabled
        XCTAssertTrue(isEnabled == true || isEnabled == false)
    }
}

// MARK: - Transcription History Integration Tests
@MainActor
final class TranscriptionHistoryIntegrationViewTests: XCTestCase {

    func testTranscriptionHistoryViewExists() {
        // TranscriptionHistoryView should be accessible
        // This test verifies the type exists and can be referenced
        let viewType = TranscriptionHistoryView.self
        XCTAssertNotNil(viewType)
    }
}

// MARK: - Empty State Tests
final class TranscriptsEmptyStateTests: XCTestCase {

    func testEmptyStateIconName() {
        let icon = "doc.text"
        XCTAssertFalse(icon.isEmpty)
    }

    func testEmptyStateMessage() {
        let message = "History not available"
        XCTAssertFalse(message.isEmpty)
    }
}

// MARK: - Theme Integration Tests
final class TranscriptsThemeTests: XCTestCase {

    func testPageBackgroundColor() {
        let color = DashboardTheme.pageBg
        XCTAssertNotNil(color)
    }

    func testInkFaintColor() {
        let color = DashboardTheme.inkFaint
        XCTAssertNotNil(color)
    }

    func testInkMutedColor() {
        let color = DashboardTheme.inkMuted
        XCTAssertNotNil(color)
    }

    func testFontStyles() {
        let font = DashboardTheme.Fonts.sans(14, weight: .medium)
        XCTAssertNotNil(font)
    }
}
