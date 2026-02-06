import SwiftUI
import SwiftData
import AppKit

internal struct DashboardHomeView: View {
    @Binding var selectedNav: DashboardNavItem
    @State private var metricsStore = UsageMetricsStore.shared
    @State private var sourceUsageStore = SourceUsageStore.shared

    @State private var recentRecords: [TranscriptionRecord] = []
    @State private var dailyActivity: [Date: Int] = [:]
    @State private var providerStats: [(provider: String, words: Int, icon: String)] = []

    var body: some View {
        Form {
            Section("This Month") {
                LabeledContent("Words") {
                    Text(formatNumber(metricsStore.snapshot.totalWords))
                        .monospacedDigit()
                }

                LabeledContent("Time Saved") {
                    Text(formatDuration(metricsStore.snapshot.estimatedTimeSaved))
                        .monospacedDigit()
                }

                LabeledContent("Avg. WPM") {
                    Text(formatDecimal(metricsStore.snapshot.wordsPerMinute))
                        .monospacedDigit()
                }

                if activeDays > 0 {
                    LabeledContent("Active Days") {
                        Text("\(activeDays)")
                            .monospacedDigit()
                    }
                }
            }

            Section {
                ActivityHeatmapView(
                    dailyActivity: dailyActivity,
                    colorForCount: heatmapColor(for:),
                    tooltip: heatmapTooltip(date:words:),
                    weeks: generateActivityWeeks()
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

                if streak > 0 {
                    LabeledContent("Streak") {
                        Text("\(streak) day\(streak == 1 ? "" : "s")")
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Activity")
            } footer: {
                Text("Words transcribed over the last 28 days.")
            }

            Section("Top Sources") {
                topSourcesSection
            }

            Section("Recent Transcripts") {
                recentSection
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadDashboardData()
        }
    }

    private var activeDays: Int {
        dailyActivity.filter { $0.value > 0 }.count
    }

    private var streak: Int {
        calculateStreak()
    }

    private var topSourcesSection: some View {
        let sourceStats = sourceUsageStore.topSources(limit: 5)

        return Group {
            if sourceStats.isEmpty && providerStats.isEmpty {
                Text("No sources yet.")
                    .foregroundStyle(.secondary)
            } else if !sourceStats.isEmpty {
                ForEach(sourceStats.prefix(5)) { stat in
                    HStack(spacing: 10) {
                        appIcon(for: stat)

                        Text(stat.displayName)
                            .lineLimit(1)

                        Spacer()

                        Text(formatNumber(stat.totalWords))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } else {
                ForEach(providerStats.prefix(5), id: \.provider) { stat in
                    HStack(spacing: 10) {
                        Image(systemName: stat.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        Text(providerDisplayName(for: stat.provider))
                            .lineLimit(1)

                        Spacer()

                        Text(formatNumber(stat.words))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var recentSection: some View {
        Group {
            if recentRecords.isEmpty {
                Text("No transcripts yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(recentRecords.prefix(5).enumerated()), id: \.element.id) { _, record in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            if let iconData = record.sourceAppIconData,
                               let nsImage = NSImage(data: iconData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }

                            Text(record.sourceAppName ?? providerDisplayName(for: record.provider))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 0)

                            Text(formatTime(record.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Text(record.text)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 2)
                }

                Button("View All…") {
                    selectedNav = .transcripts
                }
            }
        }
    }

    private func appIcon(for stat: SourceUsageStats) -> some View {
        Group {
            if let image = stat.nsImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                    .overlay(
                        Text(stat.initials.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: 18, height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Activity Heatmap

private struct ActivityHeatmapView: View {
    let dailyActivity: [Date: Int]
    let colorForCount: (Int) -> Color
    let tooltip: (Date, Int) -> String
    let weeks: [[Date]]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
            }

            VStack(spacing: 6) {
                ForEach(0..<min(weeks.count, 4), id: \.self) { weekIndex in
                    HStack(spacing: 6) {
                        ForEach(0..<min(weeks[weekIndex].count, 7), id: \.self) { dayIndex in
                            let date = weeks[weekIndex][dayIndex]
                            let count = dailyActivity[Calendar.current.startOfDay(for: date)] ?? 0

                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorForCount(count))
                                .frame(width: 16, height: 16)
                                .help(tooltip(date, count))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Data + Helpers

private extension DashboardHomeView {
    func loadDashboardData() {
        Task {
            await metricsStore.bootstrapIfNeeded()

            let records = await DataManager.shared.fetchAllRecordsQuietly()
            await MainActor.run {
                recentRecords = records
                calculateProviderStats(from: records)
                calculateDailyActivity(from: records)
            }
        }
    }

    func calculateProviderStats(from records: [TranscriptionRecord]) {
        var stats: [String: Int] = [:]
        for record in records {
            stats[record.provider, default: 0] += record.wordCount
        }

        providerStats = stats
            .map { (provider: $0.key, words: $0.value, icon: providerIcon(for: $0.key)) }
            .sorted { $0.words > $1.words }
    }

    func calculateDailyActivity(from records: [TranscriptionRecord]) {
        // Start with aggregated activity (works even when history is disabled).
        var activity = metricsStore.getDailyActivity(days: 28)

        // Merge with history records, but avoid double-counting if the day already exists.
        let calendar = Calendar.current
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            if activity[day] == nil || activity[day] == 0 {
                activity[day, default: 0] += record.wordCount
            }
        }

        dailyActivity = activity
    }

    func generateActivityWeeks() -> [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the Saturday of the current week (end of week when Sunday = 1).
        let todayWeekday = calendar.component(.weekday, from: today) // 1 = Sunday, 7 = Saturday
        let daysUntilSaturday = 7 - todayWeekday
        guard let currentWeekSaturday = calendar.date(byAdding: .day, value: daysUntilSaturday, to: today) else {
            return []
        }

        var weeks: [[Date]] = []

        // Generate 4 weeks, most recent at bottom.
        for weekOffset in (0..<4).reversed() {
            var week: [Date] = []
            guard let weekSaturday = calendar.date(byAdding: .day, value: -weekOffset * 7, to: currentWeekSaturday) else {
                continue
            }
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
        let calendar = Calendar.current
        var currentDate = Date()
        var count = 0

        while true {
            let day = calendar.startOfDay(for: currentDate)
            if let words = dailyActivity[day], words > 0 {
                count += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            } else {
                break
            }
        }

        return count
    }

    func heatmapColor(for wordCount: Int) -> Color {
        switch wordCount {
        case 0:
            return Color(nsColor: .quaternaryLabelColor).opacity(0.35)
        case 1..<50:
            return Color.accentColor.opacity(0.20)
        case 50..<150:
            return Color.accentColor.opacity(0.35)
        case 150..<300:
            return Color.accentColor.opacity(0.55)
        default:
            return Color.accentColor.opacity(0.80)
        }
    }

    func heatmapTooltip(date: Date, words: Int) -> String {
        "\(Self.heatmapDateFormatter.string(from: date)): \(words) words"
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
        }
        return "\(minutes)m"
    }

    func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private static let heatmapDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

#Preview("Dashboard Home") {
    DashboardHomeView(selectedNav: .constant(.dashboard))
        .frame(width: 900, height: 700)
}
