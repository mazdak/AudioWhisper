import SwiftUI

/// A reusable card component for displaying a transcription provider option.
internal struct ProviderSelectionCard: View {
    let provider: TranscriptionProvider
    let isSelected: Bool
    let statusText: String
    let isReady: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DashboardTheme.Spacing.md) {
                // Provider icon
                providerIcon
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                        .foregroundStyle(isSelected ? DashboardTheme.ink : DashboardTheme.inkMuted)

                    Text(provider.subtitle)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }

                Spacer()

                // Status badge
                statusBadge
            }
            .padding(DashboardTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DashboardTheme.Radius.md)
                    .fill(isSelected ? DashboardTheme.cardBgAlt : DashboardTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DashboardTheme.Radius.md)
                    .stroke(isSelected ? DashboardTheme.accent : DashboardTheme.rule, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var providerIcon: some View {
        switch provider {
        case .openai:
            Image(systemName: "brain")
                .font(.system(size: 18))
                .foregroundStyle(DashboardTheme.accent)
        case .gemini:
            Image(systemName: "sparkles")
                .font(.system(size: 18))
                .foregroundStyle(.purple)
        case .local:
            Image(systemName: "desktopcomputer")
                .font(.system(size: 18))
                .foregroundStyle(.orange)
        case .parakeet:
            Image(systemName: "bird")
                .font(.system(size: 18))
                .foregroundStyle(.green)
        }
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(DashboardTheme.Fonts.mono(10, weight: .medium))
            .foregroundStyle(isReady ? .green : DashboardTheme.inkMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isReady ? Color.green.opacity(0.15) : DashboardTheme.cardBgAlt)
            )
    }
}

// MARK: - Provider Display Extensions

extension TranscriptionProvider {
    var displayName: String {
        switch self {
        case .openai: return "OpenAI Whisper"
        case .gemini: return "Google Gemini"
        case .local: return "WhisperKit"
        case .parakeet: return "Parakeet MLX"
        }
    }

    var subtitle: String {
        switch self {
        case .openai: return "Cloud API"
        case .gemini: return "Cloud API"
        case .local: return "On-Device"
        case .parakeet: return "Apple Silicon"
        }
    }
}
