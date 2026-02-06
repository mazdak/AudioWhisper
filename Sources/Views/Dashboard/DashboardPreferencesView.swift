import SwiftUI
import ServiceManagement
import os.log

internal struct DashboardPreferencesView: View {
    @AppStorage("startAtLogin") private var startAtLogin = true
    @AppStorage("immediateRecording") private var immediateRecording = false
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
        Form {
            Section("General") {
                Toggle(isOn: $startAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start at Login")
                        Text("Launch AudioWhisper when you sign in.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: startAtLogin) { _, newValue in
                    updateLoginItem(enabled: newValue)
                }

                Toggle(isOn: $immediateRecording) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Express Mode")
                        Text("Hotkey immediately starts and stops recording.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $autoBoostMicrophoneVolume) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Boost Microphone")
                        Text("Temporarily maximize mic input while recording.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $enableSmartPaste) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart Paste")
                        Text("Automatically paste finished transcripts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $playCompletionSound) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Completion Sound")
                        Text("Play a chime when transcription finishes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let loginItemError {
                    Text(loginItemError)
                        .foregroundStyle(Color(nsColor: .systemRed))
                }
            }

            Section {
                Toggle(isOn: $transcriptionHistoryEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save Transcription History")
                        Text("Store transcripts locally so you can search and review them later.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if transcriptionHistoryEnabled {
                    Picker("Retention Period", selection: retentionBinding) {
                        ForEach(RetentionPeriod.allCases, id: \.rawValue) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text("History")
            } footer: {
                Text("View saved transcripts in the Transcripts section in the sidebar.")
            }

            Section("Storage") {
                Picker("Max Model Storage", selection: $maxModelStorageGB) {
                    ForEach(storageOptions, id: \.self) { option in
                        Text("\(Int(option)) GB").tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("About") {
                LabeledContent("Version") {
                    Text(VersionInfo.fullVersionInfo)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if VersionInfo.gitHash != "dev-build" && VersionInfo.gitHash != "unknown" {
                    LabeledContent("Git") {
                        Text(VersionInfo.gitHash)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if !VersionInfo.buildDate.isEmpty {
                    LabeledContent("Built") {
                        Text(VersionInfo.buildDate)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .formStyle(.grouped)
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
}

#Preview {
    DashboardPreferencesView()
        .frame(width: 900, height: 700)
}
