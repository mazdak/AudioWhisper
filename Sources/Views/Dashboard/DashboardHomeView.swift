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
    @State private var isLoaded = false
    
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
                        .animation(.easeOut(duration: 0.35).delay(0.05), value: isLoaded)
                    
                    // Two-column layout
                    HStack(alignment: .top, spacing: DashboardTheme.Spacing.xl) {
                        // Left column - Activity
                        activitySection
                            .frame(maxWidth: .infinity)
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : 12)
                            .animation(.easeOut(duration: 0.35).delay(0.1), value: isLoaded)
                        
                        // Right column - Sources
                        sourcesSection
                            .frame(maxWidth: .infinity)
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : 12)
                            .animation(.easeOut(duration: 0.35).delay(0.15), value: isLoaded)
                    }
                    
                    // Recent transcripts
                    recentSection
                        .opacity(isLoaded ? 1 : 0)
                        .offset(y: isLoaded ? 0 : 12)
                        .animation(.easeOut(duration: 0.35).delay(0.2), value: isLoaded)
                }
                .padding(.horizontal, DashboardTheme.Spacing.xl)
                .padding(.bottom, DashboardTheme.Spacing.xxl)
            }
        }
        .background(DashboardTheme.pageBg)
        .onAppear {
            loadDashboardData()
            withAnimation {
                isLoaded = true
            }
        }
    }
}

// MARK: - Page Header
private extension DashboardHomeView {
    var pageHeader: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
            Text("Overview")
                .font(DashboardTheme.Fonts.serif(28, weight: .semibold))
                .foregroundStyle(DashboardTheme.ink)
            
            Text(headerSubtitle)
                .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DashboardTheme.Spacing.xl)
        .padding(.top, DashboardTheme.Spacing.xl)
        .padding(.bottom, DashboardTheme.Spacing.lg)
    }
    
    var headerSubtitle: String {
        let activeDays = calculateActiveDays()
        if activeDays == 0 {
            return "Start recording to see your stats"
        }
        return "Active for \(activeDays) day\(activeDays == 1 ? "" : "s") this month"
    }
}

// MARK: - Stats Section
private extension DashboardHomeView {
    var statsSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("This Month")
            
            HStack(spacing: 0) {
                statItem(
                    value: formatNumber(metricsStore.snapshot.totalWords),
                    label: "Words",
                    alignment: .leading
                )
                
                Spacer()
                
                verticalDivider
                
                Spacer()
                
                statItem(
                    value: formatDuration(metricsStore.snapshot.estimatedTimeSaved),
                    label: "Time Saved",
                    alignment: .center
                )
                
                Spacer()
                
                verticalDivider
                
                Spacer()
                
                statItem(
                    value: formatDecimal(metricsStore.snapshot.wordsPerMinute),
                    label: "Avg. WPM",
                    alignment: .trailing
                )
            }
            .padding(.vertical, DashboardTheme.Spacing.lg)
            .padding(.horizontal, DashboardTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(DashboardTheme.cardBg)
                    .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(DashboardTheme.rule, lineWidth: 1)
            )
        }
    }
    
    func statItem(value: String, label: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: DashboardTheme.Spacing.xs) {
            Text(value)
                .font(DashboardTheme.Fonts.serif(32, weight: .semibold))
                .foregroundStyle(DashboardTheme.ink)
            
            Text(label)
                .font(DashboardTheme.Fonts.sans(11, weight: .medium))
                .foregroundStyle(DashboardTheme.inkMuted)
                .tracking(0.3)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
    
    var verticalDivider: some View {
        Rectangle()
            .fill(DashboardTheme.rule)
            .frame(width: 1, height: 50)
    }
}

// MARK: - Activity Section
private extension DashboardHomeView {
    var activitySection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader("Activity")
                
                Spacer()
                
                let streak = calculateStreak()
                if streak > 0 {
                    Text("\(streak)-day streak")
                        .font(DashboardTheme.Fonts.sans(11, weight: .medium))
                        .foregroundStyle(DashboardTheme.accent)
                }
            }
            
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
                // Day labels
                HStack(spacing: 6) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(DashboardTheme.Fonts.sans(10, weight: .medium))
                            .foregroundStyle(DashboardTheme.inkFaint)
                            .frame(width: 18)
                    }
                }
                .padding(.leading, 2)
                
                // Activity grid
                activityGrid
                
                // Legend
                HStack(spacing: DashboardTheme.Spacing.md) {
                    Text("Less")
                        .font(DashboardTheme.Fonts.sans(10, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkFaint)
                    
                    HStack(spacing: 3) {
                        ForEach([
                            DashboardTheme.heatmapEmpty,
                            DashboardTheme.heatmapLow,
                            DashboardTheme.heatmapMedium,
                            DashboardTheme.heatmapHigh,
                            DashboardTheme.heatmapMax
                        ], id: \.self) { color in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(width: 12, height: 12)
                        }
                    }
                    
                    Text("More")
                        .font(DashboardTheme.Fonts.sans(10, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkFaint)
                }
            }
            .padding(DashboardTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(DashboardTheme.cardBg)
                    .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(DashboardTheme.rule, lineWidth: 1)
            )
        }
    }
    
    var activityGrid: some View {
        let weeks = generateActivityWeeks()
        
        return VStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { weekIndex in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let date = weeks[weekIndex][dayIndex]
                        let wordCount = dailyActivity[Calendar.current.startOfDay(for: date)] ?? 0
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatmapColor(for: wordCount))
                            .frame(width: 18, height: 18)
                            .help(heatmapTooltip(date: date, words: wordCount))
                    }
                }
            }
        }
    }
}

// MARK: - Sources Section
private extension DashboardHomeView {
    var sourcesSection: some View {
        let sourceStats = sourceUsageStore.topSources(limit: 5)
        
        return VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("Top Sources")
            
            VStack(alignment: .leading, spacing: 0) {
                if sourceStats.isEmpty && providerStats.isEmpty {
                    emptySourcesView
                } else if !sourceStats.isEmpty {
                    ForEach(Array(sourceStats.enumerated()), id: \.element.id) { index, stat in
                        sourceRow(stat, index: index + 1)
                        
                        if index < sourceStats.count - 1 {
                            Divider()
                                .background(DashboardTheme.rule)
                        }
                    }
                } else {
                    ForEach(Array(providerStats.prefix(5).enumerated()), id: \.element.provider) { index, stat in
                        providerRow(stat, index: index + 1)
                        
                        if index < min(providerStats.count, 5) - 1 {
                            Divider()
                                .background(DashboardTheme.rule)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(DashboardTheme.cardBg)
                    .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(DashboardTheme.rule, lineWidth: 1)
            )
        }
    }
    
    var emptySourcesView: some View {
        VStack(spacing: DashboardTheme.Spacing.sm) {
            Text("No sources yet")
                .font(DashboardTheme.Fonts.sans(13, weight: .medium))
                .foregroundStyle(DashboardTheme.inkLight)
            
            Text("Use AudioWhisper in different apps to see which ones you use most.")
                .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DashboardTheme.Spacing.xl)
        .padding(.horizontal, DashboardTheme.Spacing.md)
    }
    
    func sourceRow(_ stat: SourceUsageStats, index: Int) -> some View {
        HStack(spacing: DashboardTheme.Spacing.md) {
            // Rank number
            Text("\(index)")
                .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                .foregroundStyle(DashboardTheme.inkFaint)
                .frame(width: 16, alignment: .trailing)
            
            // App icon
            Group {
                if let image = stat.nsImage() {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(DashboardTheme.rule)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(stat.initials.uppercased())
                                .font(DashboardTheme.Fonts.sans(10, weight: .semibold))
                                .foregroundStyle(DashboardTheme.inkMuted)
                        )
                }
            }
            
            // App name
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.displayName)
                    .font(DashboardTheme.Fonts.sans(13, weight: .medium))
                    .foregroundStyle(DashboardTheme.ink)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Word count
            Text("\(formatNumber(stat.totalWords))")
                .font(DashboardTheme.Fonts.mono(12, weight: .medium))
                .foregroundStyle(DashboardTheme.inkLight)
        }
        .padding(.horizontal, DashboardTheme.Spacing.md)
        .padding(.vertical, DashboardTheme.Spacing.sm + 4)
    }
    
    func providerRow(_ stat: (provider: String, words: Int, icon: String), index: Int) -> some View {
        HStack(spacing: DashboardTheme.Spacing.md) {
            Text("\(index)")
                .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                .foregroundStyle(DashboardTheme.inkFaint)
                .frame(width: 16, alignment: .trailing)
            
            Image(systemName: stat.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(providerColor(for: stat.provider))
                .frame(width: 24, height: 24)
            
            Text(providerDisplayName(for: stat.provider))
                .font(DashboardTheme.Fonts.sans(13, weight: .medium))
                .foregroundStyle(DashboardTheme.ink)
            
            Spacer()
            
            Text("\(formatNumber(stat.words))")
                .font(DashboardTheme.Fonts.mono(12, weight: .medium))
                .foregroundStyle(DashboardTheme.inkLight)
        }
        .padding(.horizontal, DashboardTheme.Spacing.md)
        .padding(.vertical, DashboardTheme.Spacing.sm + 4)
    }
}

// MARK: - Recent Section
private extension DashboardHomeView {
    var recentSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader("Recent Transcripts")
                
                Spacer()
                
                if !recentRecords.isEmpty {
                    Button {
                        selectedNav = .transcripts
                    } label: {
                        Text("View all →")
                            .font(DashboardTheme.Fonts.sans(12, weight: .medium))
                            .foregroundStyle(DashboardTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if recentRecords.isEmpty {
                emptyRecentView
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(recentRecords.prefix(5).enumerated()), id: \.element.id) { index, record in
                        transcriptRow(record)
                        
                        if index < min(recentRecords.count, 5) - 1 {
                            Divider()
                                .background(DashboardTheme.rule)
                                .padding(.leading, 80)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DashboardTheme.cardBg)
                        .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(DashboardTheme.rule, lineWidth: 1)
                )
            }
        }
    }
    
    var emptyRecentView: some View {
        VStack(spacing: DashboardTheme.Spacing.md) {
            Image(systemName: "waveform")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(DashboardTheme.inkFaint)
            
            VStack(spacing: DashboardTheme.Spacing.xs) {
                Text("No transcripts yet")
                    .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                    .foregroundStyle(DashboardTheme.inkLight)
                
                Text("Press your hotkey to start recording")
                    .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DashboardTheme.Spacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(DashboardTheme.cardBg)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(DashboardTheme.rule, lineWidth: 1)
        )
    }
    
    func transcriptRow(_ record: TranscriptionRecord) -> some View {
        HStack(alignment: .top, spacing: DashboardTheme.Spacing.md) {
            // Timestamp
            Text(formatTime(record.date))
                .font(DashboardTheme.Fonts.mono(11, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
                .frame(width: 64, alignment: .leading)
            
            // Content
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                // Source app
                HStack(spacing: DashboardTheme.Spacing.sm) {
                    if let iconData = record.sourceAppIconData,
                       let nsImage = NSImage(data: iconData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    
                    Text(record.sourceAppName ?? record.provider)
                        .font(DashboardTheme.Fonts.sans(12, weight: .medium))
                        .foregroundStyle(DashboardTheme.inkLight)
                }
                
                // Transcript text
                Text(record.text)
                    .font(DashboardTheme.Fonts.sans(14, weight: .regular))
                    .foregroundStyle(DashboardTheme.ink)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
            
            Spacer(minLength: DashboardTheme.Spacing.md)
            
            // Word count
            Text("\(record.wordCount) words")
                .font(DashboardTheme.Fonts.mono(11, weight: .regular))
                .foregroundStyle(DashboardTheme.inkFaint)
        }
        .padding(.horizontal, DashboardTheme.Spacing.md)
        .padding(.vertical, DashboardTheme.Spacing.md)
    }
}

// MARK: - Shared Components
private extension DashboardHomeView {
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
            .foregroundStyle(DashboardTheme.inkMuted)
            .tracking(0.8)
            .textCase(.uppercase)
    }
}

// MARK: - Data + Helpers
private extension DashboardHomeView {
    func loadDashboardData() {
        Task {
            // First, ensure daily activity is bootstrapped from records if needed
            await metricsStore.bootstrapIfNeeded()
            
            let records = await DataManager.shared.fetchAllRecordsQuietly()
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
