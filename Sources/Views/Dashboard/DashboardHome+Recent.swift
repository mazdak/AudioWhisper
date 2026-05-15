import SwiftUI
import AppKit

extension DashboardHomeView {
    // MARK: - Recent Section
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
