import SwiftUI
import ServiceManagement
import AppKit
import os.log

internal struct DashboardPreferencesView: View {
    @AppStorage("startAtLogin") private var startAtLogin = true
    @AppStorage("immediateRecording") private var immediateRecording = false
    @AppStorage("silentExpressMode") private var silentExpressMode = false
    @AppStorage("autoBoostMicrophoneVolume") private var autoBoostMicrophoneVolume = false
    @AppStorage("enableSmartPaste") private var enableSmartPaste = false
    @AppStorage("playCompletionSound") private var playCompletionSound = true
    @AppStorage("transcriptionHistoryEnabled") private var transcriptionHistoryEnabled = false
    @AppStorage("transcriptionRetentionPeriod") private var transcriptionRetentionPeriodRaw = RetentionPeriod.oneMonth.rawValue
    @AppStorage("maxModelStorageGB") private var maxModelStorageGB = 5.0

    @State private var loginItemError: String?

    private let storageOptions: [Double] = [1, 2, 5, 10, 20]

    private var retentionBinding: Binding<RetentionPeriod> {
        Binding(
            get: { RetentionPeriod(rawValue: transcriptionRetentionPeriodRaw) ?? .oneMonth },
            set: { transcriptionRetentionPeriodRaw = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xl) {
                pageHeader
                generalSection
                historySection
                storageSection
                aboutSection
            }
            .padding(DashboardTheme.Spacing.xl)
        }
        .background(DashboardTheme.pageBg)
    }

    // MARK: - Header
    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
            Text("Preferences")
                .font(DashboardTheme.Fonts.serif(28, weight: .semibold))
                .foregroundStyle(DashboardTheme.ink)
            
            Text("General settings, history, and storage management")
                .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
        }
    }

    // MARK: - General
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("General")
            
            VStack(alignment: .leading, spacing: 0) {
                SettingsToggleRow(
                    title: "Start at Login",
                    subtitle: "Launch AudioWhisper when you sign in",
                    isOn: $startAtLogin
                )
                .onChange(of: startAtLogin) { _, newValue in
                    updateLoginItem(enabled: newValue)
                }

                Divider().background(DashboardTheme.rule)

                SettingsToggleRow(
                    title: "Express Mode",
                    subtitle: "Hotkey immediately starts and stops recording",
                    isOn: $immediateRecording
                )
                .onChange(of: immediateRecording) { _, newValue in
                    // Reset silent mode when Express Mode is disabled
                    if !newValue {
                        silentExpressMode = false
                    }
                }

                if immediateRecording {
                    Divider().background(DashboardTheme.rule)

                    SettingsToggleRow(
                        title: "Silent Express Mode",
                        subtitle: "No popup window during transcription (prevents focus stealing)",
                        isOn: $silentExpressMode
                    )
                }

                Divider().background(DashboardTheme.rule)

                SettingsToggleRow(
                    title: "Auto-Boost Microphone",
                    subtitle: "Temporarily maximize mic input while recording",
                    isOn: $autoBoostMicrophoneVolume
                )

                Divider().background(DashboardTheme.rule)

                SettingsToggleRow(
                    title: "Smart Paste",
                    subtitle: "Automatically paste finished transcripts",
                    isOn: $enableSmartPaste
                )

                Divider().background(DashboardTheme.rule)

                SettingsToggleRow(
                    title: "Completion Sound",
                    subtitle: "Play a chime when transcription finishes",
                    isOn: $playCompletionSound
                )

                if let error = loginItemError {
                    Divider().background(DashboardTheme.rule)
                    Text(error)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(Color(red: 0.75, green: 0.30, blue: 0.28))
                        .padding(DashboardTheme.Spacing.md)
                }
            }
            .cardStyle()
        }
    }

    // MARK: - History
    private var historySection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("History")
            
            VStack(alignment: .leading, spacing: 0) {
                SettingsToggleRow(
                    title: "Save Transcription History",
                    subtitle: "Store transcriptions locally for review",
                    isOn: $transcriptionHistoryEnabled
                )

                if transcriptionHistoryEnabled {
                    Divider().background(DashboardTheme.rule)

                    SettingsPickerRow(
                        title: "Retention Period",
                        subtitle: "How long to keep transcriptions",
                        selection: retentionBinding,
                        options: RetentionPeriod.allCases,
                        display: { $0.displayName }
                    )

                    Divider().background(DashboardTheme.rule)

                    SettingsButtonRow(
                        title: "View History",
                        subtitle: "Open the searchable transcription log",
                        icon: "arrow.right"
                    ) {
                        HistoryWindowManager.shared.showHistoryWindow()
                    }

                    Divider().background(DashboardTheme.rule)

                    SettingsButtonRow(
                        title: "Open Recordings Folder",
                        subtitle: "Inspect saved audio snippets",
                        icon: "arrow.right"
                    ) {
                        openRecordingsFolder()
                    }
                } else {
                    Divider().background(DashboardTheme.rule)
                    SettingsInfoRow(text: "Enable history to browse and search previous transcriptions.")
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Storage
    private var storageSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("Storage")
            
            VStack(alignment: .leading, spacing: 0) {
                SettingsPickerRow(
                    title: "Max Model Storage",
                    subtitle: "Disk space limit for downloaded models",
                    selection: $maxModelStorageGB,
                    options: storageOptions,
                    display: { "\(Int($0)) GB" }
                )

                Divider().background(DashboardTheme.rule)

                SettingsInfoRow(text: "Currently reserving \(formattedGigabytes(maxModelStorageGB)) for local models.")
            }
            .cardStyle()
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("About")
            
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: DashboardTheme.Spacing.md) {
                    Text("AudioWhisper")
                        .font(DashboardTheme.Fonts.serif(16, weight: .semibold))
                        .foregroundStyle(DashboardTheme.ink)
                    
                    Text(VersionInfo.fullVersionInfo)
                        .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
                
                if VersionInfo.gitHash != "dev-build" && VersionInfo.gitHash != "unknown" {
                    HStack(spacing: DashboardTheme.Spacing.sm) {
                        Text("Git:")
                            .font(DashboardTheme.Fonts.sans(12, weight: .medium))
                            .foregroundStyle(DashboardTheme.inkMuted)
                        
                        Text(VersionInfo.gitHash)
                            .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                            .foregroundStyle(DashboardTheme.inkLight)
                    }
                }
                
                if !VersionInfo.buildDate.isEmpty {
                    HStack(spacing: DashboardTheme.Spacing.sm) {
                        Text("Built:")
                            .font(DashboardTheme.Fonts.sans(12, weight: .medium))
                            .foregroundStyle(DashboardTheme.inkMuted)
                        
                        Text(VersionInfo.buildDate)
                            .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                            .foregroundStyle(DashboardTheme.inkLight)
                    }
                }
            }
            .padding(DashboardTheme.Spacing.md)
            .cardStyle()
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

    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            Logger.settings.error("Failed to update login item: \(error.localizedDescription)")
            loginItemError = "Couldn't update login item: \(error.localizedDescription)"
        }
    }

    private func openRecordingsFolder() {
        NSWorkspace.shared.open(FileManager.default.temporaryDirectory)
    }

    private func formattedGigabytes(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        formatter.minimumFractionDigits = 0
        let formattedValue = formatter.string(from: NSNumber(value: value))
            ?? value.formatted(.number.precision(.fractionLength(1)))
        return "\(formattedValue) GB"
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
