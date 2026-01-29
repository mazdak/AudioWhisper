import XCTest
import SwiftUI
@testable import AudioWhisper

/// Tests for DashboardHomeView calculations and logic
@MainActor
final class DashboardHomeViewTests: XCTestCase {

    // MARK: - Heatmap Color Tests

    func testHeatmapColorForZeroWords() {
        let color = DashboardHomeView.testableHeatmapColor(for: 0)
        XCTAssertEqual(color, DashboardTheme.heatmapEmpty)
    }

    func testHeatmapColorForLowWords() {
        // 1-49 words should be low
        for wordCount in [1, 25, 49] {
            let color = DashboardHomeView.testableHeatmapColor(for: wordCount)
            XCTAssertEqual(color, DashboardTheme.heatmapLow,
                "Word count \(wordCount) should be heatmapLow")
        }
    }

    func testHeatmapColorForMediumWords() {
        // 50-149 words should be medium
        for wordCount in [50, 100, 149] {
            let color = DashboardHomeView.testableHeatmapColor(for: wordCount)
            XCTAssertEqual(color, DashboardTheme.heatmapMedium,
                "Word count \(wordCount) should be heatmapMedium")
        }
    }

    func testHeatmapColorForHighWords() {
        // 150-299 words should be high
        for wordCount in [150, 200, 299] {
            let color = DashboardHomeView.testableHeatmapColor(for: wordCount)
            XCTAssertEqual(color, DashboardTheme.heatmapHigh,
                "Word count \(wordCount) should be heatmapHigh")
        }
    }

    func testHeatmapColorForMaxWords() {
        // 300+ words should be max
        for wordCount in [300, 500, 1000] {
            let color = DashboardHomeView.testableHeatmapColor(for: wordCount)
            XCTAssertEqual(color, DashboardTheme.heatmapMax,
                "Word count \(wordCount) should be heatmapMax")
        }
    }

    // MARK: - Streak Calculation Tests

    func testStreakWithNoActivity() {
        let activity: [Date: Int] = [:]
        let streak = DashboardHomeView.testableCalculateStreak(from: activity)
        XCTAssertEqual(streak, 0, "Empty activity should have zero streak")
    }

    func testStreakWithTodayOnly() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let activity: [Date: Int] = [today: 100]

        let streak = DashboardHomeView.testableCalculateStreak(from: activity)
        XCTAssertEqual(streak, 1, "Activity only today should have streak of 1")
    }

    func testStreakWithConsecutiveDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var activity: [Date: Int] = [:]
        for dayOffset in 0..<5 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                activity[date] = 100
            }
        }

        let streak = DashboardHomeView.testableCalculateStreak(from: activity)
        XCTAssertEqual(streak, 5, "5 consecutive days should have streak of 5")
    }

    func testStreakBreaksOnGap() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var activity: [Date: Int] = [:]
        // Today and yesterday have activity
        activity[today] = 100
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            activity[yesterday] = 50
        }
        // Day before yesterday is missing (gap)
        // 3 days ago has activity
        if let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today) {
            activity[threeDaysAgo] = 75
        }

        let streak = DashboardHomeView.testableCalculateStreak(from: activity)
        XCTAssertEqual(streak, 2, "Streak should be 2 due to gap on day before yesterday")
    }

    func testStreakWithZeroWordsDayBreaks() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var activity: [Date: Int] = [:]
        activity[today] = 100
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            activity[yesterday] = 0  // Zero words breaks streak
        }

        let streak = DashboardHomeView.testableCalculateStreak(from: activity)
        XCTAssertEqual(streak, 1, "Zero word day should break streak")
    }

    // MARK: - Active Days Calculation Tests

    func testActiveDaysWithNoActivity() {
        let activity: [Date: Int] = [:]
        let activeDays = DashboardHomeView.testableCalculateActiveDays(from: activity)
        XCTAssertEqual(activeDays, 0)
    }

    func testActiveDaysCountsNonZeroDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var activity: [Date: Int] = [:]
        activity[today] = 100
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            activity[yesterday] = 50
        }
        if let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today) {
            activity[twoDaysAgo] = 0  // Should not count
        }
        if let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today) {
            activity[threeDaysAgo] = 25
        }

        let activeDays = DashboardHomeView.testableCalculateActiveDays(from: activity)
        XCTAssertEqual(activeDays, 3, "Should count only non-zero days")
    }

    // MARK: - Provider Stats Tests

    func testProviderStatsAggregation() {
        let records = [
            makeTestRecord(provider: "local", wordCount: 100),
            makeTestRecord(provider: "local", wordCount: 50),
            makeTestRecord(provider: "parakeet", wordCount: 200),
        ]

        let stats = DashboardHomeView.testableCalculateProviderStats(from: records)

        XCTAssertEqual(stats.count, 2, "Should have 2 providers")

        // Check sorting (highest first)
        XCTAssertEqual(stats[0].provider, "parakeet", "Parakeet should be first with 200 words")
        XCTAssertEqual(stats[0].words, 200)

        XCTAssertEqual(stats[1].provider, "local", "Local should be second with 150 words")
        XCTAssertEqual(stats[1].words, 150)
    }

    func testProviderStatsIconMapping() {
        let records = [
            makeTestRecord(provider: "local", wordCount: 100),
            makeTestRecord(provider: "parakeet", wordCount: 100),
        ]

        let stats = DashboardHomeView.testableCalculateProviderStats(from: records)
        let iconsByProvider = Dictionary(uniqueKeysWithValues: stats.map { ($0.provider, $0.icon) })

        XCTAssertEqual(iconsByProvider["local"], "laptopcomputer")
        XCTAssertEqual(iconsByProvider["parakeet"], "bird")
    }

    func testProviderStatsEmptyRecords() {
        let stats = DashboardHomeView.testableCalculateProviderStats(from: [])
        XCTAssertTrue(stats.isEmpty, "Empty records should produce empty stats")
    }

    // MARK: - Week Generation Tests

    func testWeekGenerationProducesFourWeeks() {
        let weeks = DashboardHomeView.testableGenerateActivityWeeks()
        XCTAssertEqual(weeks.count, 4, "Should generate 4 weeks")
    }

    func testWeekGenerationProducesSevenDaysPerWeek() {
        let weeks = DashboardHomeView.testableGenerateActivityWeeks()

        for (index, week) in weeks.enumerated() {
            XCTAssertEqual(week.count, 7, "Week \(index) should have 7 days")
        }
    }

    func testWeekGenerationStartsWithSunday() {
        let weeks = DashboardHomeView.testableGenerateActivityWeeks()
        let calendar = Calendar.current

        for (weekIndex, week) in weeks.enumerated() {
            let firstDay = week[0]
            let weekday = calendar.component(.weekday, from: firstDay)
            XCTAssertEqual(weekday, 1, "Week \(weekIndex) should start with Sunday (weekday 1)")
        }
    }

    func testWeekGenerationEndsWithSaturday() {
        let weeks = DashboardHomeView.testableGenerateActivityWeeks()
        let calendar = Calendar.current

        for (weekIndex, week) in weeks.enumerated() {
            let lastDay = week[6]
            let weekday = calendar.component(.weekday, from: lastDay)
            XCTAssertEqual(weekday, 7, "Week \(weekIndex) should end with Saturday (weekday 7)")
        }
    }

    func testWeekGenerationDaysAreConsecutive() {
        let weeks = DashboardHomeView.testableGenerateActivityWeeks()
        let calendar = Calendar.current

        for week in weeks {
            for i in 1..<week.count {
                let daysDiff = calendar.dateComponents([.day], from: week[i-1], to: week[i]).day
                XCTAssertEqual(daysDiff, 1, "Days within a week should be consecutive")
            }
        }
    }

    // MARK: - Duration Formatting Tests

    func testFormatDurationZero() {
        let result = DashboardHomeView.testableFormatDuration(0)
        XCTAssertEqual(result, "0m")
    }

    func testFormatDurationMinutesOnly() {
        let result = DashboardHomeView.testableFormatDuration(1800) // 30 minutes
        XCTAssertEqual(result, "30m")
    }

    func testFormatDurationHoursAndMinutes() {
        let result = DashboardHomeView.testableFormatDuration(5400) // 1.5 hours
        XCTAssertEqual(result, "1h 30m")
    }

    func testFormatDurationMultipleHours() {
        let result = DashboardHomeView.testableFormatDuration(7200) // 2 hours
        XCTAssertEqual(result, "2h 0m")
    }

    func testFormatDurationNegative() {
        let result = DashboardHomeView.testableFormatDuration(-100)
        XCTAssertEqual(result, "0m", "Negative duration should return 0m")
    }

    // MARK: - View Initialization Tests

    func testViewInitializationWithDefaults() {
        var selectedNav: DashboardNavItem = .dashboard
        let binding = Binding(get: { selectedNav }, set: { selectedNav = $0 })

        // Should not crash with default parameters
        let view = DashboardHomeView(selectedNav: binding)
        XCTAssertNotNil(view)
    }

    func testViewInitializationWithCustomDependencies() {
        var selectedNav: DashboardNavItem = .dashboard
        let binding = Binding(get: { selectedNav }, set: { selectedNav = $0 })
        let mockDataManager = MockDataManager()

        let view = DashboardHomeView(
            selectedNav: binding,
            dataManager: mockDataManager
        )

        XCTAssertNotNil(view)
    }

    // MARK: - Helpers

    private func makeTestRecord(
        provider: String,
        wordCount: Int,
        date: Date = Date()
    ) -> TranscriptionRecord {
        TranscriptionRecord(
            text: String(repeating: "word ", count: wordCount),
            provider: TranscriptionProvider(rawValue: provider) ?? .local,
            duration: 5.0,
            wordCount: wordCount,
            characterCount: wordCount * 5,
            sourceAppBundleId: nil,
            sourceAppName: nil,
            sourceAppIconData: nil
        )
    }
}
