import SwiftUI

internal struct UnifiedModelRow: View {
    let title: String
    let subtitle: String
    let sizeText: String?
    let statusText: String?
    let statusColor: Color?
    let isDownloaded: Bool
    let isDownloading: Bool
    let isSelected: Bool
    let badgeText: String?
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    @State private var isDeleting = false

    var body: some View {
        HStack(spacing: DashboardTheme.Spacing.md) {
            Button(action: onSelect) {
                HStack(spacing: DashboardTheme.Spacing.md) {
                    // Selection indicator
                    selectionIndicator
                    
                    // Info and status
                    VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                        HStack(spacing: DashboardTheme.Spacing.sm) {
                            Text(title)
                                .font(DashboardTheme.Fonts.mono(13, weight: .medium))
                                .foregroundStyle(DashboardTheme.ink)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            if let badge = badgeText, !badge.isEmpty {
                                Text(badge)
                                    .font(DashboardTheme.Fonts.sans(9, weight: .semibold))
                                    .foregroundStyle(DashboardTheme.accent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(DashboardTheme.accentLight)
                                    )
                                    .fixedSize()
                            }
                        }

                        Text(subtitle)
                            .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                            .foregroundStyle(DashboardTheme.inkMuted)
                            .lineLimit(2)

                        if let status = statusText, !status.isEmpty {
                            Text(status)
                                .font(DashboardTheme.Fonts.sans(11, weight: .regular))
                                .foregroundStyle(statusColor ?? DashboardTheme.inkMuted)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    // Size & installed state
                    VStack(alignment: .trailing, spacing: 2) {
                        if let size = sizeText {
                            Text(size)
                                .font(DashboardTheme.Fonts.mono(11, weight: .regular))
                                .foregroundStyle(DashboardTheme.inkMuted)
                        }
                        if isDownloaded {
                            Text("Installed")
                                .font(DashboardTheme.Fonts.sans(10, weight: .medium))
                                .foregroundStyle(DashboardTheme.success)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isDownloaded)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Action area
            actionButton
        }
        .padding(DashboardTheme.Spacing.md)
        .background(
            isSelected ? DashboardTheme.accentSubtle : Color.clear
        )
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private var selectionIndicator: some View {
        if isDownloaded {
            Circle()
                .strokeBorder(isSelected ? DashboardTheme.accent : DashboardTheme.rule, lineWidth: 2)
                .background(
                    Circle()
                        .fill(isSelected ? DashboardTheme.accent : Color.clear)
                        .padding(4)
                )
                .frame(width: 18, height: 18)
        } else {
            Circle()
                .strokeBorder(DashboardTheme.rule.opacity(0.5), lineWidth: 1)
                .frame(width: 18, height: 18)
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if isDownloading {
            VStack(spacing: 2) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading...")
                    .font(DashboardTheme.Fonts.sans(10, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }
            .frame(width: 72)
        } else if isDeleting {
            VStack(spacing: 2) {
                ProgressView()
                    .controlSize(.small)
                Text("Deleting...")
                    .font(DashboardTheme.Fonts.sans(10, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }
            .frame(width: 72)
        } else if isDownloaded {
            Button("Delete") {
                isDeleting = true
                Task {
                    onDelete()
                    try? await Task.sleep(for: .milliseconds(400))
                    await MainActor.run { isDeleting = false }
                }
            }
            .buttonStyle(PaperButtonStyle())
            .frame(width: 72)
            .disabled(isDeleting)
        } else {
            Button("Get") { onDownload() }
                .buttonStyle(PaperAccentButtonStyle())
                .frame(width: 72)
        }
    }
}
