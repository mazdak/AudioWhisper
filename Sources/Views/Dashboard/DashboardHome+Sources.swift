import SwiftUI
import AppKit

extension DashboardHomeView {
    // MARK: - Sources Section
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
