import SwiftUI

internal struct DashboardVisualsView: View {
    @AppDefault(\.waveformStyle) private var waveformStyle
    @AppDefault(\.visualIntensity) private var visualIntensity

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xl) {
                pageHeader
                waveformSection
                celebrationSection
            }
            .padding(DashboardTheme.Spacing.xl)
        }
        .background(DashboardTheme.pageBg)
    }

    // MARK: - Header
    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
            Text("Visuals")
                .font(DashboardTheme.Fonts.serif(28, weight: .semibold))
                .foregroundStyle(DashboardTheme.ink)

            Text("Customize your recording and success animations")
                .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
        }
    }

    // MARK: - Waveform Section
    private var waveformSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("Waveform")

            VStack(alignment: .leading, spacing: 0) {
                settingsRow(title: "Waveform Style", subtitle: "Choose your recording visualization") {
                    Picker("", selection: $waveformStyle) {
                        ForEach(WaveformStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                .onChange(of: waveformStyle) { _, newValue in
                    NotificationCenter.default.post(
                        name: .waveformStyleChanged,
                        object: newValue
                    )
                }

                Divider()
                    .background(DashboardTheme.rule)

                // Style description
                HStack(spacing: DashboardTheme.Spacing.sm) {
                    Image(systemName: styleIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.accent)

                    Text(currentStyle.description)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
                .padding(DashboardTheme.Spacing.md)
            }
            .cardStyle()
        }
    }

    // MARK: - Celebration Section
    private var celebrationSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("Celebration")

            VStack(alignment: .leading, spacing: 0) {
                settingsRow(title: "Celebration Style", subtitle: "Success feedback animation style") {
                    Picker("", selection: $visualIntensity) {
                        ForEach(VisualIntensity.allCases) { intensity in
                            Text(intensity.rawValue).tag(intensity)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                Divider()
                    .background(DashboardTheme.rule)

                // Intensity description
                HStack(spacing: DashboardTheme.Spacing.sm) {
                    Image(systemName: currentIntensity.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.accent)

                    Text(currentIntensity.description)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
                .padding(DashboardTheme.Spacing.md)
            }
            .cardStyle()
        }
    }

    // MARK: - Computed Properties
    private var currentStyle: WaveformStyle { waveformStyle }

    private var currentIntensity: VisualIntensity { visualIntensity }

    private var styleIcon: String {
        switch currentStyle {
        case .classic:
            return "waveform"
        case .neon:
            return "sparkles"
        case .spectrum:
            return "chart.bar.fill"
        case .circular:
            return "sun.max.fill"
        case .pulseRings:
            return "dot.radiowaves.left.and.right"
        case .particles:
            return "sparkle"
        }
    }

    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
            .foregroundStyle(DashboardTheme.inkMuted)
            .tracking(0.8)
            .textCase(.uppercase)
    }

    private func settingsRow<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: DashboardTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                Text(title)
                    .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                    .foregroundStyle(DashboardTheme.ink)

                Text(subtitle)
                    .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }

            Spacer()

            content()
        }
        .padding(DashboardTheme.Spacing.md)
    }
}

// MARK: - Card Style
private extension View {
    func cardStyle() -> some View {
        self
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

// MARK: - Testable Helpers
extension DashboardVisualsView {
    /// Gets the SF Symbol icon name for a waveform style
    static func testableStyleIcon(for style: WaveformStyle) -> String {
        switch style {
        case .classic:
            return "waveform"
        case .neon:
            return "sparkles"
        case .spectrum:
            return "chart.bar.fill"
        case .circular:
            return "sun.max.fill"
        case .pulseRings:
            return "dot.radiowaves.left.and.right"
        case .particles:
            return "sparkle"
        }
    }

    /// Parses waveform style from raw string value
    static func testableWaveformStyle(from rawValue: String) -> WaveformStyle {
        WaveformStyle(rawValue: rawValue) ?? .classic
    }

    /// Parses visual intensity from raw string value
    static func testableVisualIntensity(from rawValue: String) -> VisualIntensity {
        VisualIntensity(rawValue: rawValue) ?? .balanced
    }
}
