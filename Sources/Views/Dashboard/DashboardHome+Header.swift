import SwiftUI

extension DashboardHomeView {
    // MARK: - Page Header
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dashboard")
    }

    var headerSubtitle: String {
        let activeDays = calculateActiveDays()
        if activeDays == 0 {
            return "Start recording to see your stats"
        }
        return "Active for \(activeDays) day\(activeDays == 1 ? "" : "s") this month"
    }
}
