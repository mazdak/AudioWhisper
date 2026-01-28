import SwiftUI

/// A reusable section for managing cloud provider API credentials.
internal struct CloudCredentialsSection: View {
    let provider: TranscriptionProvider
    @Binding var apiKey: String
    @Binding var showKey: Bool
    @Binding var showAdvanced: Bool
    @Binding var customBaseURL: String
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.lg) {
            // Section header
            sectionHeader

            // Main content card
            VStack(spacing: 0) {
                // API Key input
                apiKeySection
                    .padding(DashboardTheme.Spacing.md)

                Divider()
                    .background(DashboardTheme.rule)

                // Advanced settings toggle
                advancedToggle
                    .padding(DashboardTheme.Spacing.md)

                // Advanced settings (collapsed by default)
                if showAdvanced {
                    Divider()
                        .background(DashboardTheme.rule)

                    advancedSettings
                        .padding(DashboardTheme.Spacing.md)
                }
            }
            .background(DashboardTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: DashboardTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DashboardTheme.Radius.md)
                    .stroke(DashboardTheme.rule, lineWidth: 1)
            )
        }
    }

    private var sectionHeader: some View {
        HStack(spacing: DashboardTheme.Spacing.sm) {
            Text("02")
                .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                .foregroundStyle(DashboardTheme.accent)

            Text("CREDENTIALS")
                .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
                .foregroundStyle(DashboardTheme.inkMuted)
                .tracking(1.5)
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(provider.displayName) API Key")
                        .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                        .foregroundStyle(DashboardTheme.ink)

                    Text(provider.apiKeyHint)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }

                Spacer()

                Button(action: onSave) {
                    Text("Save")
                        .font(DashboardTheme.Fonts.sans(12, weight: .medium))
                }
                .buttonStyle(PaperButtonStyle())
            }

            HStack(spacing: DashboardTheme.Spacing.sm) {
                Group {
                    if showKey {
                        TextField(provider.apiKeyPlaceholder, text: $apiKey)
                    } else {
                        SecureField(provider.apiKeyPlaceholder, text: $apiKey)
                    }
                }
                .textFieldStyle(.plain)
                .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                .padding(DashboardTheme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DashboardTheme.cardBgAlt)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DashboardTheme.rule, lineWidth: 1)
                )

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var advancedToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showAdvanced.toggle()
            }
        } label: {
            HStack {
                Text("Advanced Settings")
                    .font(DashboardTheme.Fonts.sans(13, weight: .medium))
                    .foregroundStyle(DashboardTheme.inkMuted)

                Spacer()

                Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }
        }
        .buttonStyle(.plain)
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.sm) {
            Text("Custom API Base URL")
                .font(DashboardTheme.Fonts.sans(13, weight: .medium))
                .foregroundStyle(DashboardTheme.ink)

            Text("Override the default API endpoint (e.g., for Azure OpenAI)")
                .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)

            TextField("https://api.example.com/v1", text: $customBaseURL)
                .textFieldStyle(.plain)
                .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                .padding(DashboardTheme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DashboardTheme.cardBgAlt)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DashboardTheme.rule, lineWidth: 1)
                )
        }
    }
}

// MARK: - Provider API Key Extensions

extension TranscriptionProvider {
    var apiKeyHint: String {
        switch self {
        case .openai: return "Get your API key from platform.openai.com"
        case .gemini: return "Get your API key from makersuite.google.com"
        default: return ""
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .openai: return "sk-..."
        case .gemini: return "AI..."
        default: return "Enter API key"
        }
    }
}
