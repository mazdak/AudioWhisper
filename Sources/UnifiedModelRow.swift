import SwiftUI

struct UnifiedModelRow: View {
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
        HStack(spacing: 12) {
            // Selection indicator (active when downloaded)
            if isDownloaded {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 16))
                    .onTapGesture { onSelect() }
            } else {
                Image(systemName: "circle.dashed")
                    .foregroundColor(.secondary.opacity(0.5))
                    .font(.system(size: 16))
            }

            // Info and status
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.9)
                    if let badge = badgeText, !badge.isEmpty {
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .cornerRadius(4)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(2) // Favor showing the badge; let title truncate
                    }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if let status = statusText, !status.isEmpty {
                    Text(status)
                        .font(.caption2)
                        .foregroundColor(statusColor ?? .secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Size & installed state
            VStack(alignment: .trailing, spacing: 2) {
                if let size = sizeText {
                    Text(size)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if isDownloaded {
                    Text("Installed")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }

            // Action area
            if isDownloading {
                VStack(spacing: 2) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 72)
            } else if isDeleting {
                VStack(spacing: 2) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Deleting...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 72)
            } else if isDownloaded {
                Button("Delete") {
                    isDeleting = true
                    Task {
                        onDelete()
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        await MainActor.run { isDeleting = false }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(width: 72)
                .disabled(isDeleting)
            } else {
                Button("Get") { onDownload() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(width: 72)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { if isDownloaded { onSelect() } }
    }
}
