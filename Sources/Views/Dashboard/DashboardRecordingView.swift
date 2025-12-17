import SwiftUI
import AVFoundation
import HotKey
import AppKit

internal struct DashboardRecordingView: View {
    @AppStorage("selectedMicrophone") private var selectedMicrophone = ""
    @AppStorage("globalHotkey") private var globalHotkey = "⌘⇧Space"
    @AppStorage("pressAndHoldEnabled") private var pressAndHoldEnabled = PressAndHoldConfiguration.defaults.enabled
    @AppStorage("pressAndHoldKeyIdentifier") private var pressAndHoldKeyIdentifier = PressAndHoldConfiguration.defaults.key.rawValue
    @AppStorage("pressAndHoldMode") private var pressAndHoldModeRaw = PressAndHoldConfiguration.defaults.mode.rawValue
    
    @State private var availableMicrophones: [AVCaptureDevice] = []
    @State private var isRecordingHotkey = false
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @State private var recordedKey: Key?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xl) {
                pageHeader
                microphoneSection
                hotkeySection
                pressAndHoldSection
            }
            .padding(DashboardTheme.Spacing.xl)
        }
        .background(DashboardTheme.pageBg)
        .environment(\.colorScheme, .light)
        .onAppear(perform: loadMicrophones)
    }
    
    // MARK: - Header
    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
            Text("Recording")
                .font(DashboardTheme.Fonts.serif(28, weight: .semibold))
                .foregroundStyle(DashboardTheme.ink)
            
            Text("Configure your microphone, hotkey, and recording behavior")
                .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
        }
    }
    
    // MARK: - Microphone
    private var microphoneSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("Microphone")
            
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
                if availableMicrophones.isEmpty {
                    Text("No microphones detected. Plug in a microphone or check system permissions.")
                        .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                        .padding(DashboardTheme.Spacing.md)
                } else {
                    settingsRow(title: "Input Device", subtitle: "Select which microphone to record from") {
                        Picker("", selection: $selectedMicrophone) {
                            Text("System Default").tag("")
                            ForEach(availableMicrophones, id: \.uniqueID) { device in
                                Text(device.localizedName).tag(device.uniqueID)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }
                }
            }
            .cardStyle()
        }
    }
    
    // MARK: - Hotkey
    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("Global Hotkey")
            
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
                HStack(alignment: .center, spacing: DashboardTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                        Text("Record / Stop")
                            .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                            .foregroundStyle(DashboardTheme.ink)
                        
                        Text("Starts and stops recording globally")
                            .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                            .foregroundStyle(DashboardTheme.inkMuted)
                    }
                    
                    Spacer()
                    
                    if isRecordingHotkey {
                        HotKeyRecorderView(
                            isRecording: $isRecordingHotkey,
                            recordedModifiers: $recordedModifiers,
                            recordedKey: $recordedKey,
                            onComplete: { newHotkey in
                                globalHotkey = newHotkey
                                updateGlobalHotkey(newHotkey)
                            }
                        )
                    } else {
                        HStack(spacing: DashboardTheme.Spacing.sm) {
                            Text(globalHotkey)
                                .font(DashboardTheme.Fonts.mono(13, weight: .medium))
                                .foregroundStyle(DashboardTheme.accent)
                                .padding(.horizontal, DashboardTheme.Spacing.sm + 2)
                                .padding(.vertical, DashboardTheme.Spacing.xs + 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DashboardTheme.accentLight)
                                )
                            
                            Button("Change") {
                                isRecordingHotkey = true
                                recordedModifiers = []
                                recordedKey = nil
                            }
                            .buttonStyle(PaperButtonStyle())
                        }
                    }
                }
                .padding(DashboardTheme.Spacing.md)
            }
            .cardStyle()
        }
    }
    
    // MARK: - Press & Hold
    private var pressAndHoldSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("Press & Hold")
            
            VStack(alignment: .leading, spacing: 0) {
                // Enable toggle
                settingsRow(title: "Enable Press & Hold", subtitle: "Hold a modifier key to control recording") {
                    Toggle("", isOn: $pressAndHoldEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(DashboardTheme.accent)
                }
                .onChange(of: pressAndHoldEnabled) { _, _ in
                    publishPressAndHoldConfiguration()
                }
                
                if pressAndHoldEnabled {
                    Divider()
                        .background(DashboardTheme.rule)
                    
                    // Mode picker
                    settingsRow(title: "Behavior", subtitle: "Hold to record or press to toggle") {
                        Picker("", selection: $pressAndHoldModeRaw) {
                            ForEach(PressAndHoldMode.allCases, id: \.rawValue) { mode in
                                Text(mode.displayName).tag(mode.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                    .onChange(of: pressAndHoldModeRaw) { _, _ in
                        publishPressAndHoldConfiguration()
                    }
                    
                    Divider()
                        .background(DashboardTheme.rule)
                    
                    // Key picker
                    settingsRow(title: "Key", subtitle: "Choose which modifier key to use") {
                        Picker("", selection: $pressAndHoldKeyIdentifier) {
                            ForEach(PressAndHoldKey.allCases, id: \.rawValue) { key in
                                Text(key.displayName).tag(key.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                    .onChange(of: pressAndHoldKeyIdentifier) { _, _ in
                        publishPressAndHoldConfiguration()
                    }
                    
                    Divider()
                        .background(DashboardTheme.rule)
                    
                    // Info
                    HStack(spacing: DashboardTheme.Spacing.sm) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.inkFaint)
                        
                        Text("Requires Accessibility permission. Works system-wide.")
                            .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                            .foregroundStyle(DashboardTheme.inkMuted)
                    }
                    .padding(DashboardTheme.Spacing.md)
                }
            }
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
    
    private func loadMicrophones() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        availableMicrophones = discoverySession.devices
    }
    
    private func publishPressAndHoldConfiguration() {
        let selectedMode = PressAndHoldMode(rawValue: pressAndHoldModeRaw) ?? PressAndHoldConfiguration.defaults.mode
        let selectedKey = PressAndHoldKey(rawValue: pressAndHoldKeyIdentifier) ?? PressAndHoldConfiguration.defaults.key
        let configuration = PressAndHoldConfiguration(
            enabled: pressAndHoldEnabled,
            key: selectedKey,
            mode: selectedMode
        )
        NotificationCenter.default.post(name: .pressAndHoldSettingsChanged, object: configuration)
    }
    
    private func updateGlobalHotkey(_ newHotkey: String) {
        NotificationCenter.default.post(
            name: .updateGlobalHotkey,
            object: newHotkey
        )
    }
}

// MARK: - Card Style Modifier
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

// MARK: - Paper Button Style
internal struct PaperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DashboardTheme.Fonts.sans(12, weight: .medium))
            .foregroundStyle(DashboardTheme.ink)
            .padding(.horizontal, DashboardTheme.Spacing.md)
            .padding(.vertical, DashboardTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? DashboardTheme.rule : DashboardTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(DashboardTheme.ruleBold, lineWidth: 1)
            )
    }
}

// MARK: - Accent Button Style
internal struct PaperAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DashboardTheme.Fonts.sans(12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, DashboardTheme.Spacing.md)
            .padding(.vertical, DashboardTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? DashboardTheme.accent.opacity(0.8) : DashboardTheme.accent)
            )
    }
}
