import SwiftUI

internal extension DashboardProvidersView {
    // MARK: - Cloud Access Helpers
    func loadAPIKeys() {
        openAIKey = keychainService.getQuietly(service: "AudioWhisper", account: "OpenAI") ?? ""
        geminiKey = keychainService.getQuietly(service: "AudioWhisper", account: "Gemini") ?? ""
    }

    func saveAPIKey(_ key: String, service: String, account: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { keychainService.deleteQuietly(service: service, account: account) }
        else { keychainService.saveQuietly(trimmed, service: service, account: account) }
    }

    // MARK: - Cloud Access UI (Legacy - kept for backward compatibility)
    @ViewBuilder
    func cloudKeyBlock(
        title: String,
        hint: String,
        text: Binding<String>,
        isShowing: Binding<Bool>,
        placeholder: String,
        accent: Color,
        onSave: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                        .foregroundStyle(DashboardTheme.ink)
                    Text(hint)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
                Spacer()
                Button(action: onSave) {
                    Text("Save")
                        .font(DashboardTheme.Fonts.sans(12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: DashboardTheme.Spacing.sm) {
                Group {
                    if isShowing.wrappedValue {
                        TextField(placeholder, text: text)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(DashboardTheme.Fonts.mono(12, weight: .regular))

                Button {
                    isShowing.wrappedValue.toggle()
                } label: {
                    Image(systemName: isShowing.wrappedValue ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DashboardTheme.Spacing.md)
    }
}
