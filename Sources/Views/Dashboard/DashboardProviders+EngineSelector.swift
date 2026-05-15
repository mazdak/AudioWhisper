import SwiftUI

extension DashboardProvidersView {
    // MARK: - Hero Header
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent line
            Rectangle()
                .fill(DashboardTheme.accent)
                .frame(width: 40, height: 3)
                .padding(.bottom, DashboardTheme.Spacing.md)

            Text("Speech")
                .font(DashboardTheme.Fonts.serif(42, weight: .light))
                .foregroundStyle(DashboardTheme.ink)

            Text("Models")
                .font(DashboardTheme.Fonts.serif(42, weight: .semibold))
                .foregroundStyle(DashboardTheme.ink)
                .padding(.top, -12)

            Text("Choose your transcription engine and models")
                .font(DashboardTheme.Fonts.sans(14, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
                .padding(.top, DashboardTheme.Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DashboardTheme.Spacing.xl)
        .padding(.top, DashboardTheme.Spacing.md)
    }

    // MARK: - Engine Selection Grid
    var engineSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.lg) {
            // Section label
            HStack(spacing: DashboardTheme.Spacing.sm) {
                Text("01")
                    .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                    .foregroundStyle(DashboardTheme.accent)

                Text("SELECT ENGINE")
                    .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
                    .foregroundStyle(DashboardTheme.inkMuted)
                    .tracking(1.5)
            }

            // Provider grid - 1x2
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: DashboardTheme.Spacing.md),
                GridItem(.flexible(), spacing: DashboardTheme.Spacing.md)
            ], spacing: DashboardTheme.Spacing.md) {
                ForEach(TranscriptionProvider.allCases, id: \.self) { provider in
                    engineCard(provider)
                }
            }
        }
    }

    func engineCard(_ provider: TranscriptionProvider) -> some View {
        let isSelected = transcriptionProvider == provider
        let config = engineConfig(for: provider)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                transcriptionProvider = provider
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Top section with icon and status
                HStack(alignment: .top) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? DashboardTheme.accent : DashboardTheme.cardBgAlt)
                            .frame(width: 40, height: 40)

                        Image(systemName: config.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isSelected ? .white : DashboardTheme.inkMuted)
                    }

                    Spacer()

                    // Status indicator
                    statusBadge(for: provider)
                }

                Spacer()

                // Bottom section with name and description
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(DashboardTheme.Fonts.sans(16, weight: .semibold))
                        .foregroundStyle(DashboardTheme.ink)

                    Text(config.tagline)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Selection indicator line
                Rectangle()
                    .fill(isSelected ? DashboardTheme.accent : Color.clear)
                    .frame(height: 2)
                    .padding(.top, DashboardTheme.Spacing.sm)
            }
            .padding(DashboardTheme.Spacing.md)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DashboardTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? DashboardTheme.accent : DashboardTheme.rule, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: isSelected ? 12 : 4, y: isSelected ? 4 : 2)
        }
        .buttonStyle(.plain)
    }

    struct EngineConfig {
        let icon: String
        let tagline: String
    }

    func engineConfig(for provider: TranscriptionProvider) -> EngineConfig {
        switch provider {
        case .local:
            return EngineConfig(icon: "desktopcomputer", tagline: "WhisperKit on Apple Silicon")
        case .parakeet:
            return EngineConfig(icon: "bird", tagline: "NVIDIA's neural speech engine")
        }
    }

    @ViewBuilder
    func statusBadge(for provider: TranscriptionProvider) -> some View {
        let (text, isReady) = statusInfo(for: provider)

        HStack(spacing: 4) {
            Circle()
                .fill(isReady ? DashboardTheme.success : DashboardTheme.accent)
                .frame(width: 6, height: 6)

            Text(text)
                .font(DashboardTheme.Fonts.sans(10, weight: .medium))
                .foregroundStyle(isReady ? DashboardTheme.success : DashboardTheme.accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((isReady ? DashboardTheme.success : DashboardTheme.accent).opacity(0.1))
        )
    }

    func statusInfo(for provider: TranscriptionProvider) -> (String, Bool) {
        switch provider {
        case .local:
            return downloadedModels.isEmpty ? ("Setup", false) : ("Ready", true)
        case .parakeet:
            return envReady ? ("Ready", true) : ("Setup", false)
        }
    }
}
