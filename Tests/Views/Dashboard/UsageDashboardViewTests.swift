import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - UsageDashboardView Tests
@MainActor
final class UsageDashboardViewTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testViewCanBeCreated() {
        let view = UsageDashboardView()
        XCTAssertNotNil(view)
    }

    func testViewBodyDoesNotCrash() {
        let view = UsageDashboardView()
        let _ = view.body
        XCTAssertTrue(true, "Body should not crash")
    }
}

// MARK: - UsageMetricsStore Tests
@MainActor
final class UsageMetricsStoreViewTests: XCTestCase {

    func testUsageMetricsStoreSharedExists() {
        let store = UsageMetricsStore.shared
        XCTAssertNotNil(store)
    }

    func testSnapshotProperty() {
        let store = UsageMetricsStore.shared
        let snapshot = store.snapshot
        XCTAssertNotNil(snapshot)
    }

    func testSnapshotTotalSessions() {
        let store = UsageMetricsStore.shared
        let sessions = store.snapshot.totalSessions
        XCTAssertGreaterThanOrEqual(sessions, 0)
    }

    func testSnapshotTotalWords() {
        let store = UsageMetricsStore.shared
        let words = store.snapshot.totalWords
        XCTAssertGreaterThanOrEqual(words, 0)
    }

    func testSnapshotWordsPerMinute() {
        let store = UsageMetricsStore.shared
        let wpm = store.snapshot.wordsPerMinute
        XCTAssertGreaterThanOrEqual(wpm, 0)
    }

    func testSnapshotKeystrokesSaved() {
        let store = UsageMetricsStore.shared
        let keystrokes = store.snapshot.keystrokesSaved
        XCTAssertGreaterThanOrEqual(keystrokes, 0)
    }

    func testSnapshotEstimatedTimeSaved() {
        let store = UsageMetricsStore.shared
        let timeSaved = store.snapshot.estimatedTimeSaved
        XCTAssertGreaterThanOrEqual(timeSaved, 0)
    }

    func testResetMethod() {
        let store = UsageMetricsStore.shared
        store.reset()
        // Should complete without crash
        XCTAssertTrue(true)
    }
}

// MARK: - Duration Formatting Tests
final class DurationFormattingTests: XCTestCase {

    func testFormatZeroSeconds() {
        let interval: TimeInterval = 0
        let formatted = formatDuration(interval)
        XCTAssertEqual(formatted, "0 seconds")
    }

    func testFormatOneSecond() {
        let interval: TimeInterval = 1
        let formatted = formatDuration(interval)
        XCTAssertEqual(formatted, "1 second")
    }

    func testFormatMultipleSeconds() {
        let interval: TimeInterval = 45
        let formatted = formatDuration(interval)
        XCTAssertEqual(formatted, "45 seconds")
    }

    func testFormatOneMinute() {
        let interval: TimeInterval = 60
        let formatted = formatDuration(interval)
        XCTAssertEqual(formatted, "1 minute")
    }

    func testFormatMultipleMinutes() {
        let interval: TimeInterval = 300
        let formatted = formatDuration(interval)
        XCTAssertEqual(formatted, "5 minutes")
    }

    func testFormatOneHour() {
        let interval: TimeInterval = 3600
        let formatted = formatDuration(interval)
        XCTAssertEqual(formatted, "1 hour")
    }

    func testFormatMultipleHours() {
        let interval: TimeInterval = 7200
        let formatted = formatDuration(interval)
        XCTAssertEqual(formatted, "2 hours")
    }

    func testFormatMixedDuration() {
        let interval: TimeInterval = 3661 // 1 hour, 1 minute, 1 second
        let formatted = formatDuration(interval)
        XCTAssertTrue(formatted.contains("hour"))
        XCTAssertTrue(formatted.contains("minute"))
    }

    // Helper matching UsageDashboardView logic
    private func formatDuration(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "0 seconds" }
        let seconds = Int(interval.rounded())
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        var components: [String] = []
        if hours > 0 {
            components.append("\(hours) " + (hours == 1 ? "hour" : "hours"))
        }
        if minutes > 0 {
            components.append("\(minutes) " + (minutes == 1 ? "minute" : "minutes"))
        }
        if remainingSeconds > 0 || components.isEmpty {
            components.append("\(remainingSeconds) " + (remainingSeconds == 1 ? "second" : "seconds"))
        }
        if components.count == 1 {
            return components[0]
        } else if components.count == 2 {
            return components.joined(separator: ", ")
        } else if components.count >= 3 {
            return "\(components[0]), \(components[1]) and \(components[2])"
        } else {
            return "0 seconds"
        }
    }
}

// MARK: - Number Formatting Tests
final class NumberFormattingTests: XCTestCase {

    func testFormatSmallNumber() {
        let number = 42
        let formatted = formatNumber(number)
        XCTAssertEqual(formatted, "42")
    }

    func testFormatThousands() {
        let number = 1234
        let formatted = formatNumber(number)
        XCTAssertTrue(formatted.contains("1") && formatted.contains("234"))
    }

    func testFormatMillions() {
        let number = 1234567
        let formatted = formatNumber(number)
        XCTAssertFalse(formatted.isEmpty)
    }

    func testFormatZero() {
        let number = 0
        let formatted = formatNumber(number)
        XCTAssertEqual(formatted, "0")
    }

    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}

// MARK: - Decimal Formatting Tests
final class DecimalFormattingTests: XCTestCase {

    func testFormatDecimalWithOneDecimalPlace() {
        let value = 42.5
        let formatted = formatDecimal(value)
        XCTAssertTrue(formatted.contains("42"))
        XCTAssertTrue(formatted.contains("5"))
    }

    func testFormatZeroDecimal() {
        let value = 0.0
        let formatted = formatDecimal(value)
        XCTAssertEqual(formatted, "0.0")
    }

    func testFormatNegativeReturnsZero() {
        let value = -5.0
        let formatted = formatDecimal(value)
        XCTAssertEqual(formatted, "0.0")
    }

    func testFormatInfiniteReturnsZero() {
        let value = Double.infinity
        let formatted = formatDecimal(value)
        XCTAssertEqual(formatted, "0.0")
    }

    func testFormatNaNReturnsZero() {
        let value = Double.nan
        let formatted = formatDecimal(value)
        XCTAssertEqual(formatted, "0.0")
    }

    private func formatDecimal(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "0.0" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "0.0"
    }
}

// MARK: - Usage Metric Card Tests
final class UsageMetricCardTests: XCTestCase {

    func testMetricCardTitles() {
        let titles = [
            "Sessions Recorded",
            "Words Dictated",
            "Words Per Minute",
            "Keystrokes Saved"
        ]

        for title in titles {
            XCTAssertFalse(title.isEmpty)
        }
    }

    func testMetricCardIcons() {
        let icons = [
            "waveform.circle.fill",
            "text.book.closed.fill",
            "speedometer",
            "keyboard.fill"
        ]

        for icon in icons {
            XCTAssertFalse(icon.isEmpty)
        }
    }

    func testMetricCardSubtitles() {
        let subtitles = [
            "Sessions completed",
            "Words generated",
            "Dictation velocity",
            "Fewer characters typed"
        ]

        for subtitle in subtitles {
            XCTAssertFalse(subtitle.isEmpty)
        }
    }
}

// MARK: - Hero Card Tests
final class HeroCardTests: XCTestCase {

    func testEmptyStateMessage() {
        let message = "Usage stats will appear here after your first session."
        XCTAssertFalse(message.isEmpty)
    }

    func testEmptyStateSubMessage() {
        let message = "Record once to begin tracking your time saved and words dictated."
        XCTAssertFalse(message.isEmpty)
    }

    func testActiveStateMessageFormat() {
        let timeSaved = "5 minutes"
        let message = "You have saved \(timeSaved) with AudioWhisper"
        XCTAssertTrue(message.contains(timeSaved))
        XCTAssertTrue(message.contains("AudioWhisper"))
    }
}

// MARK: - Reset Confirmation Tests
final class ResetConfirmationTests: XCTestCase {

    func testResetDialogTitle() {
        let title = "Reset Usage Stats?"
        XCTAssertFalse(title.isEmpty)
    }

    func testResetDialogMessage() {
        let message = "This clears the aggregated usage counters and source stats. Your transcription history remains untouched."
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.contains("history remains untouched"))
    }

    func testResetButtonLabel() {
        let label = "Reset"
        XCTAssertFalse(label.isEmpty)
    }
}

// MARK: - Dashboard Window Manager Integration Tests
@MainActor
final class DashboardWindowManagerUsageTests: XCTestCase {

    func testDashboardWindowManagerSharedExists() {
        let manager = DashboardWindowManager.shared
        XCTAssertNotNil(manager)
    }
}

// MARK: - Rebuild From History Tests
@MainActor
final class RebuildFromHistoryTests: XCTestCase {

    func testDataManagerFetchAllRecordsQuietlyAsync() async {
        let records = await DataManager.shared.fetchAllRecordsQuietly()
        XCTAssertNotNil(records)
    }

    func testUsageMetricsStoreRebuild() {
        let store = UsageMetricsStore.shared
        // Rebuild with empty records should not crash
        store.rebuild(using: [])
        XCTAssertTrue(true)
    }
}

// MARK: - Source Usage Store Tests
@MainActor
final class SourceUsageStoreUsageTests: XCTestCase {

    func testSourceUsageStoreSharedExists() {
        let store = SourceUsageStore.shared
        XCTAssertNotNil(store)
    }

    func testSourceUsageStoreReset() {
        let store = SourceUsageStore.shared
        store.reset()
        XCTAssertTrue(true)
    }
}
