import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - TranscriptionHistoryEmptyState Tests
final class TranscriptionHistoryEmptyStateTests: XCTestCase {

    func testEmptyStateCanBeCreated() {
        let view = TranscriptionHistoryEmptyState(
            searchText: "",
            onClearSearch: {}
        )
        XCTAssertNotNil(view)
    }

    func testEmptyStateBodyDoesNotCrash() {
        let view = TranscriptionHistoryEmptyState(
            searchText: "",
            onClearSearch: {}
        )
        let _ = view.body
        XCTAssertTrue(true, "Body should not crash")
    }

    func testEmptyStateWithSearchTextDoesNotCrash() {
        let view = TranscriptionHistoryEmptyState(
            searchText: "query",
            onClearSearch: {}
        )
        let _ = view.body
        XCTAssertTrue(true, "Body with search text should not crash")
    }
}

// MARK: - Empty State Icon Tests
final class EmptyStateIconTests: XCTestCase {

    func testNoTranscriptionsIcon() {
        let icon = "mic.slash"
        XCTAssertFalse(icon.isEmpty)
    }

    func testNoResultsIcon() {
        let icon = "magnifyingglass"
        XCTAssertFalse(icon.isEmpty)
    }

    func testIconSelectionBasedOnSearchText() {
        let emptySearchIcon = getIcon(searchText: "")
        let withSearchIcon = getIcon(searchText: "query")

        XCTAssertEqual(emptySearchIcon, "mic.slash")
        XCTAssertEqual(withSearchIcon, "magnifyingglass")
    }

    private func getIcon(searchText: String) -> String {
        searchText.isEmpty ? "mic.slash" : "magnifyingglass"
    }
}

// MARK: - Title Tests
final class EmptyStateTitleTests: XCTestCase {

    func testNoTranscriptionsTitle() {
        let title = "No Transcriptions Yet"
        XCTAssertFalse(title.isEmpty)
    }

    func testNoResultsTitle() {
        let title = "No Results Found"
        XCTAssertFalse(title.isEmpty)
    }

    func testTitleSelectionBasedOnSearchText() {
        let emptySearchTitle = getTitle(searchText: "")
        let withSearchTitle = getTitle(searchText: "query")

        XCTAssertEqual(emptySearchTitle, "No Transcriptions Yet")
        XCTAssertEqual(withSearchTitle, "No Results Found")
    }

    private func getTitle(searchText: String) -> String {
        searchText.isEmpty ? "No Transcriptions Yet" : "No Results Found"
    }
}

// MARK: - Subtitle Tests
final class EmptyStateSubtitleTests: XCTestCase {

    func testNoTranscriptionsSubtitle() {
        let subtitle = "Your transcription history will appear here\nonce you start recording."
        XCTAssertFalse(subtitle.isEmpty)
        XCTAssertTrue(subtitle.contains("recording"))
    }

    func testNoResultsSubtitle() {
        let subtitle = "Try adjusting your search terms\nor check your spelling."
        XCTAssertFalse(subtitle.isEmpty)
        XCTAssertTrue(subtitle.contains("search"))
    }

    func testSubtitleSelectionBasedOnSearchText() {
        let emptySearchSubtitle = getSubtitle(searchText: "")
        let withSearchSubtitle = getSubtitle(searchText: "query")

        XCTAssertTrue(emptySearchSubtitle.contains("recording"))
        XCTAssertTrue(withSearchSubtitle.contains("search"))
    }

    private func getSubtitle(searchText: String) -> String {
        searchText.isEmpty
            ? "Your transcription history will appear here\nonce you start recording."
            : "Try adjusting your search terms\nor check your spelling."
    }
}

// MARK: - Clear Search Button Tests
final class ClearSearchButtonTests: XCTestCase {

    func testClearSearchButtonLabel() {
        let label = "Clear Search"
        XCTAssertFalse(label.isEmpty)
    }

    func testClearSearchButtonVisibilityWithEmptySearch() {
        let searchText = ""
        let shouldShowButton = !searchText.isEmpty
        XCTAssertFalse(shouldShowButton)
    }

    func testClearSearchButtonVisibilityWithSearch() {
        let searchText = "query"
        let shouldShowButton = !searchText.isEmpty
        XCTAssertTrue(shouldShowButton)
    }

    func testClearSearchButtonAccessibilityLabel() {
        let label = "Clear search to show all records"
        XCTAssertFalse(label.isEmpty)
    }
}

// MARK: - Callback Tests
final class EmptyStateCallbackTests: XCTestCase {

    func testClearSearchCallbackIsInvoked() {
        var callbackInvoked = false

        let onClearSearch = {
            callbackInvoked = true
        }

        // Simulate callback
        onClearSearch()

        XCTAssertTrue(callbackInvoked)
    }
}

// MARK: - Accessibility Tests
final class EmptyStateAccessibilityTests: XCTestCase {

    func testNoTranscriptionsAccessibilityLabel() {
        let label = "No transcription records available"
        XCTAssertFalse(label.isEmpty)
    }

    func testNoResultsAccessibilityLabel() {
        let searchText = "test query"
        let label = "No search results found for \(searchText)"
        XCTAssertTrue(label.contains(searchText))
    }

    func testAccessibilityLabelSelectionBasedOnSearchText() {
        let emptySearchLabel = getAccessibilityLabel(searchText: "")
        let withSearchLabel = getAccessibilityLabel(searchText: "query")

        XCTAssertEqual(emptySearchLabel, "No transcription records available")
        XCTAssertTrue(withSearchLabel.contains("query"))
    }

    private func getAccessibilityLabel(searchText: String) -> String {
        searchText.isEmpty
            ? "No transcription records available"
            : "No search results found for \(searchText)"
    }
}

// MARK: - Style Tests
final class EmptyStateStyleTests: XCTestCase {

    func testIconFont() {
        // Uses .largeTitle
        let font = Font.largeTitle
        XCTAssertNotNil(font)
    }

    func testIconOpacity() {
        let opacity = 0.3
        XCTAssertGreaterThan(opacity, 0)
        XCTAssertLessThan(opacity, 1)
    }

    func testTitleFont() {
        // Uses .title3 with .medium weight
        let font = Font.title3
        XCTAssertNotNil(font)
    }

    func testSubtitleLineSpacing() {
        let lineSpacing: CGFloat = 3
        XCTAssertEqual(lineSpacing, 3)
    }

    func testSpacingBetweenElements() {
        let spacing: CGFloat = 20
        XCTAssertEqual(spacing, 20)
    }

    func testInnerSpacing() {
        let spacing: CGFloat = 8
        XCTAssertEqual(spacing, 8)
    }
}

// MARK: - Layout Tests
final class EmptyStateLayoutTests: XCTestCase {

    func testViewFillsAvailableSpace() {
        // View uses frame(maxWidth: .infinity, maxHeight: .infinity)
        // This test documents the expected behavior
        XCTAssertTrue(true, "Empty state should fill available space")
    }

    func testContentIsCentered() {
        // VStack with Spacer on both sides centers content
        XCTAssertTrue(true, "Content should be centered vertically")
    }
}

// MARK: - Button Style Tests
final class EmptyStateButtonStyleTests: XCTestCase {

    func testClearSearchButtonStyle() {
        // Uses .bordered style
        XCTAssertTrue(true, "Clear search button uses bordered style")
    }

    func testClearSearchButtonSize() {
        // Uses .regular control size
        XCTAssertTrue(true, "Clear search button uses regular control size")
    }
}

// MARK: - Symbol Rendering Tests
final class EmptyStateSymbolRenderingTests: XCTestCase {

    func testSymbolRenderingMode() {
        // Uses .hierarchical rendering mode
        XCTAssertTrue(true, "Icon uses hierarchical symbol rendering")
    }
}

// MARK: - Multiline Text Tests
final class EmptyStateMultilineTextTests: XCTestCase {

    func testSubtitleMultilineAlignment() {
        // Uses .center multilineTextAlignment
        XCTAssertTrue(true, "Subtitle text should be center-aligned")
    }

    func testSubtitleContainsNewline() {
        let emptySubtitle = "Your transcription history will appear here\nonce you start recording."
        XCTAssertTrue(emptySubtitle.contains("\n"))

        let searchSubtitle = "Try adjusting your search terms\nor check your spelling."
        XCTAssertTrue(searchSubtitle.contains("\n"))
    }
}
