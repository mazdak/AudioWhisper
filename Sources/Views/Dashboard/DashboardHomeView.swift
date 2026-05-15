import SwiftUI
import SwiftData
import AppKit

internal struct DashboardHomeView: View {
    @Binding var selectedNav: DashboardNavItem
    @State var metricsStore: UsageMetricsStore
    @State var sourceUsageStore: SourceUsageStore
    @State var recentRecords: [TranscriptionRecord] = []
    @State var dailyActivity: [Date: Int] = [:]
    @State var providerStats: [(provider: String, words: Int, icon: String)] = []
    @State var isLoaded = false

    /// Data manager for fetching records (injectable for testing)
    let dataManager: DataManagerProtocol

    init(
        selectedNav: Binding<DashboardNavItem>,
        metricsStore: UsageMetricsStore? = nil,
        sourceUsageStore: SourceUsageStore? = nil,
        dataManager: DataManagerProtocol? = nil
    ) {
        self._selectedNav = selectedNav
        self._metricsStore = State(initialValue: metricsStore ?? .shared)
        self._sourceUsageStore = State(initialValue: sourceUsageStore ?? .shared)
        self.dataManager = dataManager ?? DataManager.shared
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Page header
                pageHeader

                // Main content grid
                VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xl) {
                    // Stats section
                    statsSection
                        .opacity(isLoaded ? 1 : 0)
                        .offset(y: isLoaded ? 0 : 12)
                        .animation(.easeOut(duration: 0.35).delay(DashboardTheme.Animation.stagger(1)), value: isLoaded)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Usage statistics")

                    // Two-column layout
                    HStack(alignment: .top, spacing: DashboardTheme.Spacing.xl) {
                        // Left column - Activity
                        activitySection
                            .frame(maxWidth: .infinity)
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : 12)
                            .animation(.easeOut(duration: 0.35).delay(DashboardTheme.Animation.stagger(2)), value: isLoaded)

                        // Right column - Sources
                        sourcesSection
                            .frame(maxWidth: .infinity)
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : 12)
                            .animation(.easeOut(duration: 0.35).delay(DashboardTheme.Animation.stagger(3)), value: isLoaded)
                    }

                    // Recent transcripts
                    recentSection
                        .opacity(isLoaded ? 1 : 0)
                        .offset(y: isLoaded ? 0 : 12)
                        .animation(.easeOut(duration: 0.35).delay(DashboardTheme.Animation.stagger(4)), value: isLoaded)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Recent activity")
                }
                .padding(.horizontal, DashboardTheme.Spacing.xl)
                .padding(.bottom, DashboardTheme.Spacing.xxl)
            }
        }
        .background(DashboardTheme.pageBg)
        .onAppear {
            loadDashboardData()
        }
        .task {
            // Delay animation to avoid layout recursion during initial layout pass
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation {
                isLoaded = true
            }
        }
    }
}

// MARK: - Shared Components
extension DashboardHomeView {
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
            .foregroundStyle(DashboardTheme.inkMuted)
            .tracking(0.8)
            .textCase(.uppercase)
    }
}

// MARK: - Data + Helpers
extension DashboardHomeView {
    func loadDashboardData() {
        Task {
            // First, ensure daily activity is bootstrapped from records if needed
            await metricsStore.bootstrapIfNeeded(dataManager: dataManager)

            let records = await dataManager.fetchAllRecordsQuietly()
            await MainActor.run {
                recentRecords = records
                calculateProviderStats(from: records)
                // Now calculate daily activity (will use metricsStore data)
                calculateDailyActivity(from: records)
            }
        }
    }

    func calculateProviderStats(from records: [TranscriptionRecord]) {
        var stats: [String: Int] = [:]
        for record in records {
            stats[record.provider, default: 0] += record.wordCount
        }

        providerStats = stats.map { (provider: $0.key, words: $0.value, icon: providerIcon(for: $0.key)) }
            .sorted { $0.words > $1.words }
    }

    func calculateDailyActivity(from records: [TranscriptionRecord]) {
        // First, get activity from UsageMetricsStore (always available)
        var activity = metricsStore.getDailyActivity(days: 28)

        // Merge with any additional data from records (if history is enabled)
        let calendar = Calendar.current
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            // Only add if not already tracked (avoid double counting)
            if activity[day] == nil || activity[day] == 0 {
                activity[day, default: 0] += record.wordCount
            }
        }

        dailyActivity = activity
    }

    func generateActivityWeeks() -> [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the Saturday of the current week (end of week when Sunday = 1)
        let todayWeekday = calendar.component(.weekday, from: today) // 1 = Sunday, 7 = Saturday
        let daysUntilSaturday = 7 - todayWeekday
        guard let currentWeekSaturday = calendar.date(byAdding: .day, value: daysUntilSaturday, to: today) else {
            return []
        }

        var weeks: [[Date]] = []

        // Generate 4 weeks, most recent at bottom
        for weekOffset in (0..<4).reversed() {
            var week: [Date] = []
            // Calculate the Saturday for this week
            guard let weekSaturday = calendar.date(byAdding: .day, value: -weekOffset * 7, to: currentWeekSaturday) else {
                continue
            }
            // Fill in Sunday (index 0) through Saturday (index 6)
            for dayIndex in 0..<7 {
                let daysFromSunday = dayIndex - 6 // Sunday is 6 days before Saturday
                if let date = calendar.date(byAdding: .day, value: daysFromSunday, to: weekSaturday) {
                    week.append(date)
                }
            }
            weeks.append(week)
        }

        return weeks
    }

    func calculateStreak() -> Int {
        // Calculate streak from the merged dailyActivity data
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()

        while true {
            let day = calendar.startOfDay(for: currentDate)
            if let words = dailyActivity[day], words > 0 {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    func calculateActiveDays() -> Int {
        dailyActivity.filter { $0.value > 0 }.count
    }

    func heatmapColor(for wordCount: Int) -> Color {
        switch wordCount {
        case 0:
            return DashboardTheme.heatmapEmpty
        case 1..<50:
            return DashboardTheme.heatmapLow
        case 50..<150:
            return DashboardTheme.heatmapMedium
        case 150..<300:
            return DashboardTheme.heatmapHigh
        default:
            return DashboardTheme.heatmapMax
        }
    }

    func heatmapTooltip(date: Date, words: Int) -> String {
        return "\(Self.heatmapDateFormatter.string(from: date)): \(words) words"
    }

    func providerColor(for provider: String) -> Color {
        switch provider.lowercased() {
        case "openai":
            return DashboardTheme.providerOpenAI
        case "gemini":
            return DashboardTheme.providerGemini
        case "local":
            return DashboardTheme.providerLocal
        case "parakeet":
            return DashboardTheme.providerParakeet
        default:
            return DashboardTheme.inkMuted
        }
    }

    func providerIcon(for provider: String) -> String {
        switch provider.lowercased() {
        case "openai":
            return "cloud"
        case "gemini":
            return "sparkles"
        case "local":
            return "laptopcomputer"
        case "parakeet":
            return "bird"
        default:
            return "waveform"
        }
    }

    func providerDisplayName(for provider: String) -> String {
        switch provider.lowercased() {
        case "openai":
            return "OpenAI"
        case "gemini":
            return "Gemini"
        case "local":
            return "Local Whisper"
        case "parakeet":
            return "Parakeet"
        default:
            return provider.capitalized
        }
    }

    func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func formatDecimal(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "0" }
        return value.formatted(.number.precision(.fractionLength(0)))
    }

    func formatDuration(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "0m" }
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    func formatTime(_ date: Date) -> String {
        return Self.timeFormatter.string(from: date)
    }

    static let heatmapDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

// MARK: - Testable Helpers
extension DashboardHomeView {
    /// Testable heatmap color calculation
    static func testableHeatmapColor(for wordCount: Int) -> Color {
        switch wordCount {
        case 0:
            return DashboardTheme.heatmapEmpty
        case 1..<50:
            return DashboardTheme.heatmapLow
        case 50..<150:
            return DashboardTheme.heatmapMedium
        case 150..<300:
            return DashboardTheme.heatmapHigh
        default:
            return DashboardTheme.heatmapMax
        }
    }

    /// Testable streak calculation
    static func testableCalculateStreak(from dailyActivity: [Date: Int]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()

        while true {
            let day = calendar.startOfDay(for: currentDate)
            if let words = dailyActivity[day], words > 0 {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    /// Testable active days calculation
    static func testableCalculateActiveDays(from dailyActivity: [Date: Int]) -> Int {
        dailyActivity.filter { $0.value > 0 }.count
    }

    /// Testable provider stats calculation
    static func testableCalculateProviderStats(from records: [TranscriptionRecord]) -> [(provider: String, words: Int, icon: String)] {
        var stats: [String: Int] = [:]
        for record in records {
            stats[record.provider, default: 0] += record.wordCount
        }

        func providerIcon(for provider: String) -> String {
            switch provider.lowercased() {
            case "openai": return "cloud"
            case "gemini": return "sparkles"
            case "local": return "laptopcomputer"
            case "parakeet": return "bird"
            default: return "waveform"
            }
        }

        return stats.map { (provider: $0.key, words: $0.value, icon: providerIcon(for: $0.key)) }
            .sorted { $0.words > $1.words }
    }

    /// Testable week generation
    static func testableGenerateActivityWeeks(from referenceDate: Date = Date()) -> [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        let todayWeekday = calendar.component(.weekday, from: today)
        let daysUntilSaturday = 7 - todayWeekday
        guard let currentWeekSaturday = calendar.date(byAdding: .day, value: daysUntilSaturday, to: today) else {
            return []
        }

        var weeks: [[Date]] = []

        for weekOffset in (0..<4).reversed() {
            var week: [Date] = []
            guard let weekSaturday = calendar.date(byAdding: .day, value: -weekOffset * 7, to: currentWeekSaturday) else {
                continue
            }
            for dayIndex in 0..<7 {
                let daysFromSunday = dayIndex - 6
                if let date = calendar.date(byAdding: .day, value: daysFromSunday, to: weekSaturday) {
                    week.append(date)
                }
            }
            weeks.append(week)
        }

        return weeks
    }

    /// Testable duration formatting
    static func testableFormatDuration(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "0m" }
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview("Dashboard Home") {
    DashboardHomeView(selectedNav: .constant(.dashboard))
        .frame(width: 900, height: 700)
}
