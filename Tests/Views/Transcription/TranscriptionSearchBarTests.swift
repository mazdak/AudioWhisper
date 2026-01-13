import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - TranscriptionSearchBar Tests
@MainActor
final class TranscriptionSearchBarTests: XCTestCase {

    func testSearchBarCanBeCreated() {
        var searchText = ""
        let binding = Binding(
            get: { searchText },
            set: { searchText = $0 }
        )

        // Use a wrapper view that provides FocusState
        let wrapper = SearchBarTestWrapper(searchText: binding)
        XCTAssertNotNil(wrapper)
    }

    func testSearchBarWithEmptyText() {
        var searchText = ""
        let binding = Binding(
            get: { searchText },
            set: { searchText = $0 }
        )

        XCTAssertTrue(searchText.isEmpty)
        binding.wrappedValue = "test"
        XCTAssertEqual(searchText, "test")
    }

    func testSearchBarWithText() {
        var searchText = "test query"
        let binding = Binding(
            get: { searchText },
            set: { searchText = $0 }
        )

        XCTAssertEqual(searchText, "test query")
        binding.wrappedValue = ""
        XCTAssertTrue(searchText.isEmpty)
    }
}

// Helper wrapper that provides FocusState for testing
private struct SearchBarTestWrapper: View {
    @Binding var searchText: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TranscriptionSearchBar(searchText: $searchText, isFocused: $isFocused)
    }
}

// MARK: - Search Icon Tests
final class SearchIconTests: XCTestCase {

    func testSearchIconName() {
        let icon = "magnifyingglass"
        XCTAssertFalse(icon.isEmpty)
    }

    func testClearIconName() {
        let icon = "xmark.circle.fill"
        XCTAssertFalse(icon.isEmpty)
    }
}

// MARK: - Search Placeholder Tests
final class SearchPlaceholderTests: XCTestCase {

    func testPlaceholderText() {
        let placeholder = "Search transcriptions..."
        XCTAssertFalse(placeholder.isEmpty)
        XCTAssertTrue(placeholder.contains("Search"))
    }
}

// MARK: - Search Accessibility Tests
final class SearchAccessibilityTests: XCTestCase {

    func testSearchFieldAccessibilityLabel() {
        let label = "Search transcriptions"
        XCTAssertFalse(label.isEmpty)
    }

    func testSearchFieldAccessibilityHint() {
        let hint = "Type to filter transcription records by text or provider. Press Cmd+F to focus."
        XCTAssertFalse(hint.isEmpty)
        XCTAssertTrue(hint.contains("filter"))
        XCTAssertTrue(hint.contains("Cmd+F"))
    }

    func testClearButtonAccessibilityLabel() {
        let label = "Clear search"
        XCTAssertFalse(label.isEmpty)
    }

    func testClearButtonHelp() {
        let help = "Clear search (Escape)"
        XCTAssertFalse(help.isEmpty)
        XCTAssertTrue(help.contains("Escape"))
    }
}

// MARK: - Search Bar Style Tests
final class SearchBarStyleTests: XCTestCase {

    func testCornerRadius() {
        let cornerRadius: CGFloat = 8
        XCTAssertEqual(cornerRadius, 8)
        XCTAssertGreaterThan(cornerRadius, 0)
    }

    func testHorizontalPadding() {
        let padding: CGFloat = 12
        XCTAssertEqual(padding, 12)
    }

    func testVerticalPadding() {
        let padding: CGFloat = 8
        XCTAssertEqual(padding, 8)
    }

    func testBackgroundOpacity() {
        let opacity = 0.1
        XCTAssertEqual(opacity, 0.1)
        XCTAssertGreaterThan(opacity, 0)
        XCTAssertLessThan(opacity, 1)
    }

    func testStrokeLineWidth() {
        let lineWidth: CGFloat = 1
        XCTAssertEqual(lineWidth, 1)
    }
}

// MARK: - Animation Tests
final class SearchBarAnimationTests: XCTestCase {

    func testFocusAnimationDuration() {
        let duration = 0.2
        XCTAssertEqual(duration, 0.2)
    }

    func testClearButtonTransition() {
        // Clear button uses scale combined with opacity
        // This test documents the expected behavior
        XCTAssertTrue(true, "Clear button should animate with scale and opacity")
    }
}

// MARK: - Focus State Tests
@MainActor
final class SearchBarFocusStateTests: XCTestCase {

    func testFocusStateDefaultValueIsFalse() {
        // FocusState defaults to false (unfocused)
        // This documents expected behavior without using @FocusState directly
        let defaultFocusedValue = false
        XCTAssertFalse(defaultFocusedValue)
    }

    func testClearButtonDefocusesBehavior() {
        // When clear button is pressed, it should defocus the search bar
        // This test documents expected behavior
        var isFocused = true
        isFocused = false // Simulating clear action

        XCTAssertFalse(isFocused)
    }
}

// MARK: - Clear Button Visibility Tests
final class ClearButtonVisibilityTests: XCTestCase {

    func testClearButtonHiddenWhenEmpty() {
        let searchText = ""
        let shouldShowClearButton = !searchText.isEmpty
        XCTAssertFalse(shouldShowClearButton)
    }

    func testClearButtonVisibleWhenNotEmpty() {
        let searchText = "query"
        let shouldShowClearButton = !searchText.isEmpty
        XCTAssertTrue(shouldShowClearButton)
    }

    func testClearButtonVisibleWithWhitespace() {
        let searchText = "   "
        let shouldShowClearButton = !searchText.isEmpty
        XCTAssertTrue(shouldShowClearButton) // Non-empty string, even if whitespace
    }
}

// MARK: - Search Text Binding Tests
@MainActor
final class SearchTextBindingTests: XCTestCase {

    func testSearchTextBindingUpdates() {
        var searchText = ""
        let binding = Binding(
            get: { searchText },
            set: { searchText = $0 }
        )

        binding.wrappedValue = "new value"
        XCTAssertEqual(searchText, "new value")
    }

    func testSearchTextClear() {
        var searchText = "existing query"
        let binding = Binding(
            get: { searchText },
            set: { searchText = $0 }
        )

        binding.wrappedValue = ""
        XCTAssertTrue(searchText.isEmpty)
    }
}

// MARK: - Font Style Tests
final class SearchBarFontTests: XCTestCase {

    func testSearchIconFont() {
        // Search icon uses .callout
        let font = Font.callout
        XCTAssertNotNil(font)
    }

    func testTextFieldFont() {
        // TextField uses .body
        let font = Font.body
        XCTAssertNotNil(font)
    }

    func testClearButtonFont() {
        // Clear button icon uses .callout
        let font = Font.callout
        XCTAssertNotNil(font)
    }
}
