import SwiftUI

extension DashboardHomeView {
    // MARK: - Stats Section
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
