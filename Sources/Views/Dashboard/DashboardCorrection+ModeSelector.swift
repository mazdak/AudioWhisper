import SwiftUI

extension DashboardCorrectionView {
    // MARK: - Mode Selector
    var modeSelectorSection: some View {
        SettingsSectionCard(title: "Correction Mode", icon: "text.badge.checkmark") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose where semantic correction runs after transcription.")
                    .font(.footnote)
                    .foregroundStyle(DashboardTheme.inkMuted)

                HStack(alignment: .center, spacing: DashboardTheme.Spacing.sm) {
                    Text("Mode")
                        .font(DashboardTheme.Fonts.sans(12, weight: .medium))
                        .foregroundStyle(DashboardTheme.inkMuted)

                    Spacer()

                    Picker("", selection: $semanticCorrectionMode) {
                        ForEach(SemanticCorrectionMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(DashboardTheme.accent)
                }
            }
        }
    }
}
