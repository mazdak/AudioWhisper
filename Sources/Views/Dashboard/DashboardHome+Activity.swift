import SwiftUI

extension DashboardHomeView {
    // MARK: - Activity Section
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
                // Day labels (use index as ID to avoid duplicate "S" and "T" warnings)
                HStack(spacing: 6) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
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
            ForEach(0..<weeks.count, id: \.self) { weekIndex in
                HStack(spacing: 6) {
                    ForEach(0..<weeks[weekIndex].count, id: \.self) { dayIndex in
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
