import SwiftUI
import SwiftData
import AVFoundation
import ServiceManagement
import HotKey
import os.log

private actor VerificationMessageStore {
    private var stdout: String = ""
    private var stderr: String = ""

    func updateStdout(_ value: String) {
        stdout = value
    }

    func updateStderr(_ value: String) {
        stderr = value
    }

    func stdoutMessage() -> String {
        stdout
    }

    func stderrMessage() -> String {
        stderr
    }
}

struct SettingsView: View {
    @AppStorage("selectedMicrophone") private var selectedMicrophone = ""
    @AppStorage("globalHotkey") private var globalHotkey = "⌘⇧Space"
    @AppStorage("transcriptionProvider") private var transcriptionProvider = TranscriptionProvider.openai
    @AppStorage("selectedWhisperModel") private var selectedWhisperModel = WhisperModel.base
    @AppStorage("startAtLogin") private var startAtLogin = true
    @AppStorage("immediateRecording") private var immediateRecording = false
    @AppStorage("pressAndHoldEnabled") private var pressAndHoldEnabled = PressAndHoldConfiguration.defaults.enabled
    @AppStorage("pressAndHoldKeyIdentifier") private var pressAndHoldKeyIdentifier = PressAndHoldConfiguration.defaults.key.rawValue
    @AppStorage("pressAndHoldMode") private var pressAndHoldModeRaw = PressAndHoldConfiguration.defaults.mode.rawValue
    @AppStorage("autoBoostMicrophoneVolume") private var autoBoostMicrophoneVolume = false
    @AppStorage("enableSmartPaste") private var enableSmartPaste = false
    @AppStorage("playCompletionSound") private var playCompletionSound = true
    @AppStorage("maxModelStorageGB") private var maxModelStorageGB = 5.0
    @AppStorage("transcriptionHistoryEnabled") private var transcriptionHistoryEnabled = false
    @AppStorage("transcriptionRetentionPeriod") private var transcriptionRetentionPeriodRaw = RetentionPeriod.oneMonth.rawValue
    // Semantic correction settings
    @AppStorage("semanticCorrectionMode") private var semanticCorrectionModeRaw = SemanticCorrectionMode.off.rawValue
    @AppStorage("semanticCorrectionModelRepo") private var semanticCorrectionModelRepo = "mlx-community/Llama-3.2-3B-Instruct-4bit"
    @AppStorage("hasSetupParakeet") private var hasSetupParakeet = false
    @AppStorage("selectedParakeetModel") private var selectedParakeetModel = ParakeetModel.v3Multilingual
    @AppStorage("hasSetupLocalLLM") private var hasSetupLocalLLM = false
    @AppStorage("openAIBaseURL") private var openAIBaseURL = ""
    @AppStorage("openAIModel") private var openAIModel = ""
    @AppStorage("openAITemperature") private var openAITemperature = 0.0
    @AppStorage("openAILanguage") private var openAILanguage = ""
    @AppStorage("geminiBaseURL") private var geminiBaseURL = ""
    @State private var showAdvancedAPISettings = false
    @StateObject private var modelManager = ModelManager.shared
    @State private var availableMicrophones: [AVCaptureDevice] = []
    @State private var openAIKey = ""
    @State private var geminiKey = ""
    @State private var showOpenAIKey = false
    @State private var showGeminiKey = false
    @State private var downloadError: String?
    @State private var isRecordingHotkey = false
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @State private var recordedKey: Key?
    @State private var downloadedModels: [WhisperModel] = []
    @State private var totalModelsSize: Int64 = 0
    @State private var modelDownloadStates: [WhisperModel: Bool] = [:]
    @State private var isVerifyingLocalWhisper = false
    @State private var localWhisperVerifyMessage: String?
    @State private var isVerifyingMLX = false
    @State private var mlxVerifyMessage: String?
    
    private let keychainService: KeychainServiceProtocol
    private let skipOnAppear: Bool
    @State private var downloadStartTime: [WhisperModel: Date] = [:]
    @State private var isTestingMLX = false
    @State private var mlxTestResult: String?
    @State private var setupStatus: String?
    @State private var showParakeetConfirm = false
    @State private var showLocalLLMConfirm = false
    @State private var showArchUnsupportedAlert = false
    @State private var showSetupSheet = false
    @State private var isSettingUp = false
    @State private var setupLogs = ""
    @State private var envReady = false
    @State private var isCheckingEnv = false
    @State private var isVerifyingParakeet = false
    @State private var parakeetVerifyMessage: String?
    
    init(keychainService: KeychainServiceProtocol = KeychainService.shared, skipOnAppear: Bool = false) {
        self.keychainService = keychainService
        self.skipOnAppear = skipOnAppear
    }
    
    var body: some View {
        Form {
            Section("Microphone") {
                Picker("Input Device", selection: $selectedMicrophone) {
                    Text("System Default").tag("")
                    ForEach(availableMicrophones, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Microphone input device")
                .accessibilityHint("Choose which microphone to use for recording")
            }
            
            Section("Global Hotkey") {
                HStack {
                    Text("Record/Stop")
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
                        Text(globalHotkey)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                        
                        Button("Change") {
                            isRecordingHotkey = true
                            recordedModifiers = []
                            recordedKey = nil
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Change global hotkey")
                        .accessibilityHint("Press to record a new keyboard shortcut for starting and stopping recordings")
                    }
                }
            }

            Section("Press & Hold Hotkey") {
                Toggle("Enable Press & Hold", isOn: $pressAndHoldEnabled)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Enable press and hold recording")
                    .accessibilityHint("When enabled, holding a modifier key can start and stop recording globally")
                    .onChange(of: pressAndHoldEnabled) { _, _ in
                        publishPressAndHoldConfiguration()
                    }

                if pressAndHoldEnabled {
                    Picker("Behavior", selection: $pressAndHoldModeRaw) {
                        ForEach(PressAndHoldMode.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Press and hold behavior")
                    .accessibilityHint("Choose whether holding the key records or toggles recording")
                    .onChange(of: pressAndHoldModeRaw) { _, _ in
                        publishPressAndHoldConfiguration()
                    }

                    Picker("Key", selection: $pressAndHoldKeyIdentifier) {
                        ForEach(PressAndHoldKey.allCases) { key in
                            Text(key.displayName).tag(key.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Press and hold key")
                    .accessibilityHint("Select which modifier key will control recordings")
                    .onChange(of: pressAndHoldKeyIdentifier) { _, _ in
                        publishPressAndHoldConfiguration()
                    }

                    Text("Hold the selected key anywhere to start recording. Release it to finish when using Press and Hold mode. Requires Accessibility permission.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            
            Section("General") {
                Toggle("Start at Login", isOn: $startAtLogin)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Start AudioWhisper at login")
                    .accessibilityHint("When enabled, AudioWhisper will automatically start when you log into your Mac")
                    .onChange(of: startAtLogin) { oldValue, newValue in
                        updateLoginItem(enabled: newValue)
                    }
                
                Toggle("Express Mode: Hotkey Start & Stop", isOn: $immediateRecording)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Hotkey start and stop mode")
                    .accessibilityHint("When enabled, the hotkey starts recording immediately and pressing it again stops recording and pastes the text")
                
                Toggle("Auto-Boost Microphone Volume", isOn: $autoBoostMicrophoneVolume)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Automatically boost microphone volume")
                    .accessibilityHint("When enabled, microphone volume is temporarily increased to 100% during recording and restored afterward")
                
                Toggle("Smart Paste (Auto ⌘V)", isOn: $enableSmartPaste)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Automatically paste transcribed text")
                    .accessibilityHint("When enabled, automatically simulates ⌘V to paste transcribed text. Requires Input Monitoring permission.")
                
                Toggle("Play Completion Sound", isOn: $playCompletionSound)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Play sound when transcription completes")
                    .accessibilityHint("When enabled, plays a gentle sound when transcription is finished and text is pasted")
            }
            
            Section(header: Text("History")) {
                Toggle("Save Transcription History", isOn: $transcriptionHistoryEnabled)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Save transcription history")
                    .accessibilityHint("When enabled, transcriptions are saved locally for review and search")
                
                if transcriptionHistoryEnabled {
                    Picker("Keep History For", selection: $transcriptionRetentionPeriodRaw) {
                        ForEach(RetentionPeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("History retention period")
                    .accessibilityHint("Choose how long to keep transcription history")
                    
                    Button("View History...") {
                        showHistoryWindow()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("View transcription history")
                    .accessibilityHint("Opens a window to view and manage saved transcriptions")
                }

                Button("Open Recordings Folder...") {
                    NSWorkspace.shared.open(FileManager.default.temporaryDirectory)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Open recordings folder")
                .accessibilityHint("Opens the temporary folder where audio recordings are stored")

                Text("Audio recordings are temporarily stored here until transcription completes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Usage Stats")) {
                UsageDashboardView()
            }
            
            Section(header: Text("Speech-to-Text Provider")) {
                Picker("Service", selection: $transcriptionProvider) {
                    ForEach(TranscriptionProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Speech-to-text service")
                .accessibilityHint("Choose between OpenAI, Google Gemini, or local Whisper for transcription")
                
                // Cloud Provider API Key input
                if transcriptionProvider == .openai || transcriptionProvider == .gemini {
                    HStack {
                        Group {
                            if transcriptionProvider == .openai {
                                if showOpenAIKey {
                                    TextField("OpenAI API Key", text: $openAIKey)
                                        .accessibilityLabel("OpenAI API Key")
                                        .accessibilityHint("Enter your OpenAI API key to use OpenAI transcription service")
                                } else {
                                    SecureField("OpenAI API Key", text: $openAIKey)
                                        .accessibilityLabel("OpenAI API Key")
                                        .accessibilityHint("Enter your OpenAI API key to use OpenAI transcription service")
                                }
                            } else {
                                if showGeminiKey {
                                    TextField("Gemini API Key", text: $geminiKey)
                                        .accessibilityLabel("Gemini API Key")
                                        .accessibilityHint("Enter your Google Gemini API key to use Gemini transcription service")
                                } else {
                                    SecureField("Gemini API Key", text: $geminiKey)
                                        .accessibilityLabel("Gemini API Key")
                                        .accessibilityHint("Enter your Google Gemini API key to use Gemini transcription service")
                                }
                            }
                        }
                        
                        Button(action: { 
                            if transcriptionProvider == .openai {
                                showOpenAIKey.toggle()
                            } else {
                                showGeminiKey.toggle()
                            }
                        }) {
                            Image(systemName: (transcriptionProvider == .openai ? showOpenAIKey : showGeminiKey) ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel((transcriptionProvider == .openai ? showOpenAIKey : showGeminiKey) ? "Hide API key" : "Show API key")
                        .accessibilityHint("Toggle between showing and hiding the API key")
                        
                        Button("Save") {
                            if transcriptionProvider == .openai {
                                saveAPIKey(openAIKey, service: "AudioWhisper", account: "OpenAI")
                            } else {
                                saveAPIKey(geminiKey, service: "AudioWhisper", account: "Gemini")
                            }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Save API key")
                        .accessibilityHint("Save the entered API key to use for transcription")
                    }
                    
                    Link("Get API Key", destination: URL(string: transcriptionProvider == .openai ? "https://platform.openai.com/api-keys" : "https://makersuite.google.com/app/apikey")!)
                        .font(.caption)
                        .accessibilityLabel("Get API key from \(transcriptionProvider == .openai ? "OpenAI" : "Google")")
                        .accessibilityHint("Opens \(transcriptionProvider == .openai ? "OpenAI" : "Google") website to create an API key")

                    // Advanced API settings (custom base URL for proxies)
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: { showAdvancedAPISettings.toggle() }) {
                            HStack {
                                Image(systemName: showAdvancedAPISettings ? "chevron.down" : "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Advanced")
                                    .font(.caption)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if showAdvancedAPISettings {
                            VStack(alignment: .leading, spacing: 8) {
                                if transcriptionProvider == .openai {
                                    TextField("Custom Endpoint (optional)", text: $openAIBaseURL)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.caption)
                                    Text("Base URL or full endpoint. Examples:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("• https://api.openai.com/v1 (base URL)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("• https://your-resource.openai.azure.com/openai/deployments/whisper/audio/transcriptions?api-version=2024-02-01")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    TextField("Model (optional)", text: $openAIModel)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.caption)
                                        .padding(.top, 8)
                                    Text("Default: whisper-1. Override for other OpenAI-compatible APIs")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("Language (optional)", text: $openAILanguage)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.caption)
                                        .padding(.top, 8)
                                    Text("ISO-639-1 code (e.g. en, es, fr). Leave empty for auto-detect")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Text("Temperature:")
                                            .font(.caption)
                                        Slider(value: $openAITemperature, in: 0...1, step: 0.1)
                                        Text(String(format: "%.1f", openAITemperature))
                                            .font(.caption)
                                            .frame(width: 30)
                                    }
                                    .padding(.top, 8)
                                    Text("0 = deterministic, higher = more variation")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                } else {
                                    TextField("Custom Base URL (optional)", text: $geminiBaseURL)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.caption)
                                    Text("Default: https://generativelanguage.googleapis.com")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 4)
                            .padding(.leading, 16)
                        }
                    }
                }
                
                // Parakeet Configuration
                if transcriptionProvider == .parakeet {
                    VStack(alignment: .leading, spacing: 16) {
                        // Info banner with icon
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "cpu")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Advanced Local Processing")
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                Text("Requires Apple Silicon and Python dependencies. First use may download ~2.5 GB model.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        // Model selection picker
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Model", selection: $selectedParakeetModel) {
                                ForEach(ParakeetModel.allCases, id: \.self) { model in
                                    VStack(alignment: .leading) {
                                        Text(model.displayName)
                                    }
                                    .tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedParakeetModel) { _, newModel in
                                // Trigger download of newly selected model if not cached
                                Task {
                                    await MLXModelManager.shared.ensureParakeetModel()
                                }
                            }

                            Text(selectedParakeetModel.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if Arch.isAppleSilicon {
                            HStack(spacing: 6) {
                                if isCheckingEnv { ProgressView().controlSize(.small) }
                                Text(envReady ? "✅ Environment ready" : "Environment not installed")
                                    .font(.subheadline)
                                    .foregroundColor(envReady ? .green : .secondary)
                                if envReady {
                                    Button(action: { revealEnvInFinder() }) {
                                        Image(systemName: "folder")
                                    }
                                    .buttonStyle(.plain)
                                    .help("Reveal Python environment in Finder")
                                    Button(action: { revealPromptsInFinder() }) {
                                        Image(systemName: "doc.text")
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open Prompts Folder")
                                }
                            }
                            if !envReady {
                                Button("Install Dependencies") {
                                runUvSetupSheet(title: "Setting up Parakeet dependencies…")
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                HStack(spacing: 8) {
                                    if isVerifyingParakeet { ProgressView().controlSize(.small) }
                                    Button(isVerifyingParakeet ? "Verifying…" : "Verify Parakeet Model") {
                                        verifyParakeetModel()
                                    }
                                    .disabled(isVerifyingParakeet)
                                    .buttonStyle(.bordered)
                                    if let msg = parakeetVerifyMessage, !msg.isEmpty {
                                        Text(msg)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } else {
                            Text("Parakeet is only available on Apple Silicon Macs.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Link("Learn more about Parakeet",
                             destination: URL(string: "https://github.com/senstella/parakeet-mlx")!)
                            .font(.caption)

                        // Info text with clickable path (models cache)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Models are stored in:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            HStack {
                                Text("~/.cache/huggingface/hub/")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .textSelection(.enabled)
                                Button(action: {
                                    let path = FileManager.default.homeDirectoryForCurrentUser
                                        .appendingPathComponent(".cache/huggingface/hub")
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
                                }) {
                                    Image(systemName: "folder").font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .help("Open in Finder")
                            }
                        }
                    }
                }
            }

            // Local Whisper Model Management (moved above Semantic Correction)
            if transcriptionProvider == .local {
                Section("Local Whisper Models") {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header with refresh info
                        HStack {
                            Text("Choose a model for offline transcription")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            HStack(spacing: 8) {
                                Button(action: {
                                    Task {
                                        await modelManager.refreshModelStates()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption)
                                        Text("Refresh")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)

                                Button("Show in Finder") {
                                    showModelsInFinder()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)

                                // "Clear All" removed; individual deletes are supported per model
                            }
                        }
                        .padding(.bottom, 12)

                        // Model list (shared row using LocalWhisperEntry)
                        VStack(spacing: 8) {
                            let entries: [ModelEntry] = WhisperModel.allCases.map { m in
                                LocalWhisperEntry(
                                    model: m,
                                    stage: modelManager.getDownloadStage(for: m),
                                    estimatedTimeRemaining: modelManager.getEstimatedTimeRemaining(for: m),
                                    isDownloaded: modelManager.downloadedModels.contains(m),
                                    isDownloading: modelManager.getDownloadStage(for: m)?.isActive ?? false,
                                    isSelected: selectedWhisperModel == m,
                                    onSelect: {
                                        selectedWhisperModel = m
                                        if !modelManager.downloadedModels.contains(m) {
                                            downloadModel(m)
                                        }
                                    },
                                    onDownload: { downloadModel(m) },
                                    onDelete: { deleteModel(m) }
                                )
                            }
                            ForEach(entries.indices, id: \.self) { i in
                                let e = entries[i]
                                UnifiedModelRow(
                                    title: e.title,
                                    subtitle: e.subtitle,
                                    sizeText: e.sizeText,
                                    statusText: e.statusText,
                                    statusColor: e.statusColor,
                                    isDownloaded: e.isDownloaded,
                                    isDownloading: e.isDownloading,
                                    isSelected: e.isSelected,
                                    badgeText: e.badgeText,
                                    onSelect: e.onSelect,
                                    onDownload: e.onDownload,
                                    onDelete: e.onDelete
                                )
                            }
                        }

                        // Download background info
                        if !modelManager.downloadingModels.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Downloads continue in background even when settings are closed")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }

                        // Storage controls and summary
                        VStack(alignment: .leading, spacing: 8) {
                            // Storage limit setting
                            HStack {
                                Text("Max Storage for Models:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Picker(selection: $maxModelStorageGB, label: EmptyView()) {
                                    Text("1 GB").tag(1.0)
                                    Text("2 GB").tag(2.0)
                                    Text("5 GB").tag(5.0)
                                    Text("10 GB").tag(10.0)
                                    Text("20 GB").tag(20.0)
                                }
                                .pickerStyle(.menu)
                                .controlSize(.small)
                                .accessibilityLabel("Storage limit for downloaded models")
                            }

                            // Storage summary
                            if !modelManager.downloadedModels.isEmpty {
                                HStack {
                                    Image(systemName: "externaldrive.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text("Using \(formatBytes(totalModelsSize)) of \(formatBytes(Int64(maxModelStorageGB * 1024 * 1024 * 1024)))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            } else {
                                HStack {
                                    Image(systemName: "externaldrive")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text("No models downloaded (limit: \(formatBytes(Int64(maxModelStorageGB * 1024 * 1024 * 1024))))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 12)

                        // Verify selected model
                        HStack(spacing: 8) {
                            if isVerifyingLocalWhisper { ProgressView().controlSize(.small) }
                            Button(isVerifyingLocalWhisper ? "Verifying…" : "Verify Selected Model") {
                                verifyLocalWhisperModel()
                            }
                            .disabled(isVerifyingLocalWhisper)
                            .buttonStyle(.bordered)
                            if let msg = localWhisperVerifyMessage, !msg.isEmpty {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 10)

                        // Error Display
                        if let error = downloadError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }

            // Semantic Correction Layer
            Section(header: Text("Semantic Correction")) {
                Picker("Mode", selection: $semanticCorrectionModeRaw) {
                    ForEach(SemanticCorrectionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Semantic correction mode")

                let mode = SemanticCorrectionMode(rawValue: semanticCorrectionModeRaw) ?? .off
                if mode == .localMLX {
                    VStack(alignment: .leading, spacing: 16) {
                        // Info banner with icon
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "cpu")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Local LLM (MLX)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Applies only to Local Whisper and Parakeet. Requires Apple Silicon and Python dependencies. Downloads a small instruct model for correction.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        // Quick setup with uv
                        if Arch.isAppleSilicon {
                            HStack(spacing: 6) {
                                if isCheckingEnv { ProgressView().controlSize(.small) }
                                Text(envReady ? "✅ Environment ready" : "Environment not installed")
                                    .font(.subheadline)
                                    .foregroundColor(envReady ? .green : .secondary)
                                if envReady {
                                    Button(action: { revealEnvInFinder() }) {
                                        Image(systemName: "folder")
                                    }
                                    .buttonStyle(.plain)
                                    .help("Reveal Python environment in Finder")
                                    Button(action: { revealPromptsInFinder() }) {
                                        Image(systemName: "doc.text")
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open Prompts Folder")
                                }
                            }
                            if !envReady {
                                Button("Install Dependencies") {
                                runUvSetupSheet(title: "Setting up Local LLM dependencies…")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            Text("Local LLM (MLX) correction is only available on Apple Silicon Macs.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Model Management
                        MLXModelManagementView(
                            selectedModelRepo: $semanticCorrectionModelRepo
                        )
                        .padding(16)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        // Verify MLX model
                        HStack(spacing: 8) {
                            if isVerifyingMLX { ProgressView().controlSize(.small) }
                            Button(isVerifyingMLX ? "Verifying…" : "Verify MLX Model") {
                                verifyMLXModel()
                            }
                            .disabled(isVerifyingMLX)
                            .buttonStyle(.bordered)
                            if let msg = mlxVerifyMessage, !msg.isEmpty {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 10)
                        
                        // Learn more about MLX
                        Link("Learn more about MLX", 
                             destination: URL(string: "https://github.com/ml-explore/mlx-examples/tree/main/llms")!)
                            .font(.caption)
                    }
                } else if mode == .cloud {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Uses the same cloud provider as selected for transcription (OpenAI or Gemini).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Correction runs only when a cloud provider is used.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // (moved Local Whisper section above)
            
            // Version Info Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(VersionInfo.fullVersionInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if VersionInfo.gitHash != "dev-build" && VersionInfo.gitHash != "unknown" {
                            Text("Git: \(VersionInfo.gitHash)")
                                .font(.caption2)
                                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                                .textSelection(.enabled)
                        }
                        
                        if !VersionInfo.buildDate.isEmpty {
                            Text("Built: \(VersionInfo.buildDate)")
                                .font(.caption2)
                                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 600)
        .onKeyPress(.escape) {
            // Close settings window safely
            if let window = NSApplication.shared.keyWindow {
                window.performClose(nil)
            }
            return .handled
        }
        .focusable(false)
        .onAppear {
            if !skipOnAppear {
                loadAvailableMicrophones()
                loadAPIKeys()
                loadModelStates()
                checkEnvReady()
                
                // Ensure transcription provider is loaded correctly on app launch
                // This helps prevent settings from being reset during app updates
                if let storedProvider = UserDefaults.standard.string(forKey: "transcriptionProvider"),
                   let provider = TranscriptionProvider(rawValue: storedProvider) {
                    transcriptionProvider = provider
                    // Pre-flight checks/downloads happen here, not during recording
                    if provider == .parakeet {
                        Task { await MLXModelManager.shared.ensureParakeetModel() }
                    } else if provider == .local {
                        // Ensure selected Whisper model is present; start download if missing
                        Task { @MainActor in
                            if !(await ModelManager.shared.isModelDownloaded(selectedWhisperModel)) {
                                downloadModel(selectedWhisperModel)
                            }
                        }
                    }
                }
                // Normalize MLX selection: remove Gemma 2 from choices
                if semanticCorrectionModelRepo.contains("gemma-2-2b") {
                    semanticCorrectionModelRepo = "mlx-community/Llama-3.2-3B-Instruct-4bit"
                }
                // Ensure MLX correction model is present when Local MLX mode is selected
                let mode = SemanticCorrectionMode(rawValue: semanticCorrectionModeRaw) ?? .off
                if mode == .localMLX {
                    Task {
                        await MLXModelManager.shared.refreshModelList()
                        if !MLXModelManager.shared.downloadedModels.contains(semanticCorrectionModelRepo) {
                            await MLXModelManager.shared.downloadModel(semanticCorrectionModelRepo)
                        }
                    }
                }
                
                // Make sure the view can receive key events
                DispatchQueue.main.async {
                    NSApplication.shared.keyWindow?.makeFirstResponder(nil)
                }
            }
        }
        .onChange(of: transcriptionProvider) { oldValue, newValue in
            if newValue == .parakeet {
                if !Arch.isAppleSilicon {
                    showArchUnsupportedAlert = true
                } else {
                    // Refresh env status quickly
                    checkEnvReady()
                    if !envReady { showParakeetConfirm = true }
                    else {
                        hasSetupParakeet = true
                        Task { await MLXModelManager.shared.ensureParakeetModel() }
                    }
                }
            } else if newValue == .local {
                // Auto-start download for selected local Whisper model
                Task { @MainActor in
                    if !(await ModelManager.shared.isModelDownloaded(selectedWhisperModel)) {
                        downloadModel(selectedWhisperModel)
                    }
                }
            }
        }
        .onChange(of: semanticCorrectionModeRaw) { oldValue, newValue in
            if SemanticCorrectionMode(rawValue: newValue) == .localMLX {
                if !Arch.isAppleSilicon {
                    showArchUnsupportedAlert = true
                } else {
                    // Refresh env status quickly
                    checkEnvReady()
                    if !envReady { showLocalLLMConfirm = true }
                    else {
                        hasSetupLocalLLM = true
                        // Ensure selected MLX correction model is downloaded
                        Task {
                            await MLXModelManager.shared.refreshModelList()
                            if !MLXModelManager.shared.downloadedModels.contains(semanticCorrectionModelRepo) {
                                await MLXModelManager.shared.downloadModel(semanticCorrectionModelRepo)
                            }
                        }
                    }
                }
            }
        }
        .alert("Prepare Python environment?", isPresented: $showParakeetConfirm) {
            Button("Cancel", role: .cancel) {
                // Revert selection to previous stored provider
                if let stored = UserDefaults.standard.string(forKey: "transcriptionProvider"),
                   let prov = TranscriptionProvider(rawValue: stored) {
                    transcriptionProvider = prov
                } else {
                    transcriptionProvider = .openai
                }
            }
            Button("Install") {
                runUvSetupSheet(title: "Setting up Parakeet dependencies…") { hasSetupParakeet = true }
            }
        } message: {
            Text("Parakeet requires Python deps managed by uv. Install now?")
        }
        .alert("Prepare Python environment?", isPresented: $showLocalLLMConfirm) {
            Button("Cancel", role: .cancel) {
                semanticCorrectionModeRaw = SemanticCorrectionMode.off.rawValue
            }
            Button("Install") {
                runUvSetupSheet(title: "Setting up Local LLM dependencies…") { hasSetupLocalLLM = true }
            }
        } message: {
            Text("Local LLM correction requires Python deps via uv. Install now?")
        }
        .alert("Not Supported on Intel", isPresented: $showArchUnsupportedAlert) {
            Button("OK", role: .cancel) {
                // Revert selections that triggered this
                if transcriptionProvider == .parakeet {
                    transcriptionProvider = .openai
                }
                if SemanticCorrectionMode(rawValue: semanticCorrectionModeRaw) == .localMLX {
                    semanticCorrectionModeRaw = SemanticCorrectionMode.off.rawValue
                }
            }
        } message: {
            Text("Parakeet and Local LLM require an Apple Silicon Mac.")
        }
        .sheet(isPresented: $showSetupSheet) {
            SetupEnvironmentSheet(
                isPresented: $showSetupSheet,
                isRunning: $isSettingUp,
                logs: $setupLogs,
                title: setupStatus ?? "Setting up environment…",
                onStart: { }
            )
        }
    }
    
    private func loadAvailableMicrophones() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        availableMicrophones = discoverySession.devices
    }
    
    private func loadAPIKeys() {
        openAIKey = keychainService.getQuietly(service: "AudioWhisper", account: "OpenAI") ?? ""
        geminiKey = keychainService.getQuietly(service: "AudioWhisper", account: "Gemini") ?? ""
    }
    
    func saveAPIKey(_ key: String, service: String, account: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { keychainService.deleteQuietly(service: service, account: account) }
        else { keychainService.saveQuietly(trimmed, service: service, account: account) }
    }
    
    func getAPIKey(service: String, account: String) -> String? {
        return keychainService.getQuietly(service: service, account: account)
    }
    
    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.settings.error("Failed to update login item: \(error.localizedDescription)")
        }
    }
    
    private func downloadModel(_ model: WhisperModel) {
        downloadError = nil
        downloadStartTime[model] = Date()
        Task {
            do {
                try await modelManager.downloadModel(model)
                downloadStartTime.removeValue(forKey: model)
                loadModelStates()
            } catch {
                downloadError = error.localizedDescription
                downloadStartTime.removeValue(forKey: model)
            }
        }
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
    
    // Note: Python path configuration has been removed; uv bootstrap manages the environment.

    private func runUvSetupSheet(title: String, onComplete: (() -> Void)? = nil) {
        setupStatus = title
        setupLogs = ""
        isSettingUp = true
        showSetupSheet = true
        Task {
            do {
                _ = try UvBootstrap.ensureVenv(userPython: nil) { msg in
                    DispatchQueue.main.async {
                        setupLogs += (setupLogs.isEmpty ? "" : "\n") + msg
                    }
                }
                await MainActor.run {
                    isSettingUp = false
                    setupStatus = "✓ Environment ready"
                    envReady = true
                }
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run {
                    showSetupSheet = false
                    onComplete?()
                }
            } catch {
                await MainActor.run {
                    isSettingUp = false
                    setupStatus = "✗ Setup failed"
                    // Show detailed error in the logs area instead of the title
                    let msg = error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription
                    setupLogs += (setupLogs.isEmpty ? "" : "\n") + "Error: \(msg)"
                    envReady = false
                }
            }
        }
    }

    private func checkEnvReady() {
        isCheckingEnv = true
        Task {
            let fm = FileManager.default
            let py = venvPythonPath()
            var ready = false
            if fm.isExecutableFile(atPath: py) {
                // Quick import check for mlx_lm
                let process = Process()
                process.executableURL = URL(fileURLWithPath: py)
                process.arguments = ["-c", "import mlx_lm; print('OK')"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        ready = true
                    }
                } catch {
                    ready = false
                }
            }
            await MainActor.run {
                self.envReady = ready
                self.isCheckingEnv = false
                if ready {
                    // Mark both gates as completed to avoid future prompts
                    self.hasSetupParakeet = true
                    self.hasSetupLocalLLM = true
                }
            }
        }
    }

    private func venvPythonPath() -> String {
        let appSupport = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
        let base = appSupport?.appendingPathComponent("AudioWhisper/python_project/.venv/bin/python3").path
        return base ?? ""
    }

    private func verifyParakeetModel() {
        isVerifyingParakeet = true
        parakeetVerifyMessage = "Starting verification…"
        Task {
            do {
                let py = try await Task.detached(priority: .userInitiated) {
                    try UvBootstrap.ensureVenv(userPython: nil) { msg in
                        // optional: stream uv logs
                    }
                }.value
                let pythonPath = py.path
                await MainActor.run { parakeetVerifyMessage = "Checking model (offline)…" }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonPath)
                // Find verify_parakeet.py in bundle or Sources
                var scriptURL = Bundle.main.url(forResource: "verify_parakeet", withExtension: "py")
                if scriptURL == nil {
                    let src = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/verify_parakeet.py")
                    if FileManager.default.fileExists(atPath: src.path) { scriptURL = src }
                }
                guard let scriptURL else { parakeetVerifyMessage = "Script not found"; isVerifyingParakeet = false; return }
                let repoToVerify = self.selectedParakeetModel.repoId
                process.arguments = [scriptURL.path, repoToVerify]
                let out = Pipe(); let err = Pipe()
                process.standardOutput = out; process.standardError = err

                let messageStore = VerificationMessageStore()
                out.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
                    let lines = s.split(separator: "\n").map(String.init)
                    for line in lines {
                        if let d = line.data(using: .utf8),
                           let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                           let msg = j["message"] as? String {
                            Task {
                                await messageStore.updateStdout(msg)
                                await MainActor.run { parakeetVerifyMessage = msg }
                            }
                        }
                    }
                }
                err.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
                    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        await messageStore.updateStderr(trimmed)
                        await MainActor.run { parakeetVerifyMessage = trimmed }
                    }
                }

                try process.run()
                // Add a timeout so the UI cannot get stuck if the process hangs
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: 180_000_000_000) // 180s
                    if process.isRunning { process.terminate() }
                }
                await Task.detached { process.waitUntilExit() }.value
                timeoutTask.cancel()

                let lastStdoutMessage = await messageStore.stdoutMessage()
                let lastStderrMessage = await messageStore.stderrMessage()

                await MainActor.run {
                    isVerifyingParakeet = false
                    if process.terminationStatus == 0 {
                        parakeetVerifyMessage = (lastStdoutMessage.isEmpty ? "Model verified" : lastStdoutMessage)
                        hasSetupParakeet = true
                        Task { await MLXModelManager.shared.refreshModelList() }
                    } else {
                        let msg = lastStdoutMessage.isEmpty ? lastStderrMessage : lastStdoutMessage
                        parakeetVerifyMessage = msg.isEmpty ? "Verification failed" : "Verification failed: \(msg)"
                    }
                }
            } catch {
                await MainActor.run {
                    isVerifyingParakeet = false
                    parakeetVerifyMessage = "Verification error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func revealEnvInFinder() {
        let appSupport = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
        let dir = appSupport?.appendingPathComponent("AudioWhisper/python_project/.venv/")
        if let dir = dir {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir.path)
        }
    }

    private func revealPromptsInFinder() {
        let appSupport = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
        let dir = appSupport?.appendingPathComponent("AudioWhisper/prompts/")
        if let dir = dir {
            // Ensure directory exists (created on startup), still guard here
            if !FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir.path)
        }
    }

    private func localWhisperModelPath(for model: WhisperModel) -> URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent(model.whisperKitModelName)
    }

    private func verifyLocalWhisperModel() {
        isVerifyingLocalWhisper = true
        localWhisperVerifyMessage = "Checking files…"
        let model = selectedWhisperModel
        Task {
            // Fast existence check via ModelManager
            let isPresent = await ModelManager.shared.isModelDownloaded(model)
            if !isPresent {
                await MainActor.run {
                    isVerifyingLocalWhisper = false
                    localWhisperVerifyMessage = "Model files missing — click Get to download."
                }
                return
            }
            // Inspect folder contents for sanity
            if let path = localWhisperModelPath(for: model) {
                let files = (try? FileManager.default.contentsOfDirectory(atPath: path.path)) ?? []
                let hasCoreML = files.contains { $0.hasSuffix(".mlmodelc") }
                let hasJSON = files.contains { $0.hasSuffix(".json") }
                await MainActor.run { localWhisperVerifyMessage = "Files OK" + (hasCoreML ? " • CoreML" : "") + (hasJSON ? " • JSON" : "") }
            }
            await MainActor.run {
                isVerifyingLocalWhisper = false
                if (localWhisperVerifyMessage ?? "").isEmpty { localWhisperVerifyMessage = "Model verified" }
            }
        }
    }

    private func verifyMLXModel() {
        isVerifyingMLX = true
        mlxVerifyMessage = "Checking model (offline)…"
        let repo = semanticCorrectionModelRepo
        Task {
            do {
                let py = try await Task.detached(priority: .userInitiated) {
                    try UvBootstrap.ensureVenv(userPython: nil) { _ in }
                }.value
                let pythonPath = py.path
                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonPath)
                // Find verify_mlx.py in bundle or Sources
                var scriptURL = Bundle.main.url(forResource: "verify_mlx", withExtension: "py")
                if scriptURL == nil {
                    let src = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/verify_mlx.py")
                    if FileManager.default.fileExists(atPath: src.path) { scriptURL = src }
                }
                guard let scriptURL else { mlxVerifyMessage = "Script not found"; isVerifyingMLX = false; return }
                process.arguments = [scriptURL.path, repo]
                let out = Pipe(); let err = Pipe()
                process.standardOutput = out; process.standardError = err
                let messageStore = VerificationMessageStore()
                out.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
                    for line in s.split(separator: "\n").map(String.init) {
                        if let d = line.data(using: .utf8),
                           let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                           let msg = j["message"] as? String {
                            Task {
                                await messageStore.updateStdout(msg)
                                await MainActor.run { mlxVerifyMessage = msg }
                            }
                        }
                    }
                }
                err.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
                    let msg = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { @MainActor in mlxVerifyMessage = msg }
                }
                try process.run()
                let timeout = Task { try await Task.sleep(nanoseconds: 180_000_000_000); if process.isRunning { process.terminate() } }
                await Task.detached { process.waitUntilExit() }.value
                timeout.cancel()
                let lastMsg = await messageStore.stdoutMessage()
                await MainActor.run {
                    isVerifyingMLX = false
                    if process.terminationStatus == 0 {
                        mlxVerifyMessage = lastMsg.isEmpty ? "Model verified" : lastMsg
                        Task { await MLXModelManager.shared.refreshModelList() }
                    } else {
                        if (mlxVerifyMessage ?? "").isEmpty { mlxVerifyMessage = "Verification failed" }
                    }
                }
            } catch {
                await MainActor.run {
                    isVerifyingMLX = false
                    mlxVerifyMessage = "Verification error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteModel(_ model: WhisperModel) {
        Task {
            do {
                try await modelManager.deleteModel(model)
                loadModelStates()
            } catch {
                await MainActor.run {
                    downloadError = error.localizedDescription
                }
            }
        }
    }
    
    private func loadModelStates() {
        Task {
            let models = await modelManager.getDownloadedModels()
            let totalSize = await modelManager.getTotalModelsSize()
            
            // Update model download states asynchronously
            var states: [WhisperModel: Bool] = [:]
            for model in WhisperModel.allCases {
                let isDownloaded = await modelManager.isModelDownloaded(model)
                states[model] = isDownloaded
            }
            
            await MainActor.run {
                self.downloadedModels = models
                self.totalModelsSize = totalSize
                self.modelDownloadStates = states
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // Removed bulk delete; users can delete individual models
    
    private func showModelsInFinder() {
        // WhisperKit stores models in ~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let huggingFacePath = documentsPath.appendingPathComponent("huggingface")
        let modelsPath = huggingFacePath.appendingPathComponent("models")
        let argmaxPath = modelsPath.appendingPathComponent("argmaxinc")
        let whisperKitPath = argmaxPath.appendingPathComponent("whisperkit-coreml")
        
        // Check if the WhisperKit models directory exists
        if FileManager.default.fileExists(atPath: whisperKitPath.path) {
            NSWorkspace.shared.open(whisperKitPath)
        } else if FileManager.default.fileExists(atPath: argmaxPath.path) {
            NSWorkspace.shared.open(argmaxPath)
        } else if FileManager.default.fileExists(atPath: modelsPath.path) {
            NSWorkspace.shared.open(modelsPath)
        } else if FileManager.default.fileExists(atPath: huggingFacePath.path) {
            NSWorkspace.shared.open(huggingFacePath)
        } else {
            // Create the huggingface directory and open it
            try? FileManager.default.createDirectory(at: huggingFacePath, withIntermediateDirectories: true)
            NSWorkspace.shared.open(huggingFacePath)
        }
    }
    
    private func showHistoryWindow() {
        HistoryWindowManager.shared.showHistoryWindow()
    }
}

struct DownloadingView: View {
    let model: WhisperModel
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(0.8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Downloading \(model.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Model size: \(model.fileSize)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("No progress tracking available")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .italic()
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityLabel("Downloading \(model.displayName) model")
    }
}

struct HotKeyRecorderView: View {
    @Binding var isRecording: Bool
    @Binding var recordedModifiers: NSEvent.ModifierFlags
    @Binding var recordedKey: Key?
    let onComplete: (String) -> Void
    
    @State private var displayText = "Press keys..."
    @State private var eventMonitor: Any?
    
    var body: some View {
        HStack {
            Text(displayText)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
                .onAppear {
                    startRecording()
                }
                .onDisappear {
                    stopRecording()
                }
            
            Button("Cancel") {
                stopRecording()
                isRecording = false
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func startRecording() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleKeyEvent(event)
            return nil // Consume the event
        }
    }
    
    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            recordedModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            updateDisplayText()
        } else if event.type == .keyDown {
            if let key = keyFromKeyCode(event.keyCode) {
                recordedKey = key
                
                // Complete the recording if we have both modifiers and a key
                if (recordedKey != nil && !recordedModifiers.isEmpty) ||
                   (recordedKey != nil && isFunctionKey(key) && recordedModifiers.isEmpty) {
                    if isValidHotkey(modifiers: recordedModifiers, key: key) {
                        let hotkeyString = formatHotkey(modifiers: recordedModifiers, key: key)
                        stopRecording()
                        onComplete(hotkeyString)
                        isRecording = false
                    } else {
                        // Invalid hotkey, show error briefly
                        displayText = "Invalid combination"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            recordedModifiers = []
                            recordedKey = nil
                            displayText = "Press keys..."
                        }
                    }
                }
            }
        }
    }
    
    private func updateDisplayText() {
        var parts: [String] = []
        
        if recordedModifiers.contains(.command) { parts.append("⌘") }
        if recordedModifiers.contains(.shift) { parts.append("⇧") }
        if recordedModifiers.contains(.option) { parts.append("⌥") }
        if recordedModifiers.contains(.control) { parts.append("⌃") }
        
        if let key = recordedKey {
            parts.append(keyToString(key))
        }
        
        displayText = parts.isEmpty ? "Press keys..." : parts.joined()
    }
    
    private func formatHotkey(modifiers: NSEvent.ModifierFlags, key: Key) -> String {
        var parts: [String] = []
        
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        
        parts.append(keyToString(key))
        
        return parts.joined()
    }
    
    private func isValidHotkey(modifiers: NSEvent.ModifierFlags, key: Key) -> Bool {
        // Allow function keys with no modifiers
        if modifiers.isEmpty {
            return isFunctionKey(key)
        }
        
        // Some keys should not be used as hotkeys (like escape, which is used to cancel)
        let forbiddenKeys: [Key] = [.escape, .delete, .return, .tab]
        if forbiddenKeys.contains(key) {
            return false
        }
        
        // Single modifier keys (like just shift) should require Command or Control
        if modifiers == .shift || modifiers == .option {
            return false
        }
        
        return true
    }

    private func isFunctionKey(_ key: Key) -> Bool {
        switch key {
        case .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10,
             .f11, .f12, .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20:
            return true
        default:
            return false
        }
    }
    
    private func keyFromKeyCode(_ keyCode: UInt16) -> Key? {
        switch keyCode {
        case 0: return .a
        case 1: return .s
        case 2: return .d
        case 3: return .f
        case 4: return .h
        case 5: return .g
        case 6: return .z
        case 7: return .x
        case 8: return .c
        case 9: return .v
        case 11: return .b
        case 12: return .q
        case 13: return .w
        case 14: return .e
        case 15: return .r
        case 16: return .y
        case 17: return .t
        case 18: return .one
        case 19: return .two
        case 20: return .three
        case 21: return .four
        case 22: return .six
        case 23: return .five
        case 24: return .equal
        case 25: return .nine
        case 26: return .seven
        case 27: return .minus
        case 28: return .eight
        case 29: return .zero
        case 30: return .rightBracket
        case 31: return .o
        case 32: return .u
        case 33: return .leftBracket
        case 34: return .i
        case 35: return .p
        case 36: return .return
        case 37: return .l
        case 38: return .j
        case 39: return .quote
        case 40: return .k
        case 41: return .semicolon
        case 42: return .backslash
        case 43: return .comma
        case 44: return .slash
        case 45: return .n
        case 46: return .m
        case 47: return .period
        case 48: return .tab
        case 49: return .space
        case 50: return .grave
        case 51: return .delete
        case 53: return .escape
        case 122: return .f1
        case 120: return .f2
        case 99: return .f3
        case 118: return .f4
        case 96: return .f5
        case 97: return .f6
        case 98: return .f7
        case 100: return .f8
        case 101: return .f9
        case 109: return .f10
        case 103: return .f11
        case 111: return .f12
        case 105: return .f13
        case 107: return .f14
        case 113: return .f15
        case 106: return .f16
        case 64: return .f17
        case 79: return .f18
        case 80: return .f19
        case 90: return .f20
        case 126: return .upArrow
        case 125: return .downArrow
        case 123: return .leftArrow
        case 124: return .rightArrow
        default: return nil
        }
    }
    
    private func keyToString(_ key: Key) -> String {
        switch key {
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        case .f13: return "F13"
        case .f14: return "F14"
        case .f15: return "F15"
        case .f16: return "F16"
        case .f17: return "F17"
        case .f18: return "F18"
        case .f19: return "F19"
        case .f20: return "F20"
        case .a: return "A"
        case .s: return "S"
        case .d: return "D"
        case .f: return "F"
        case .h: return "H"
        case .g: return "G"
        case .z: return "Z"
        case .x: return "X"
        case .c: return "C"
        case .v: return "V"
        case .b: return "B"
        case .q: return "Q"
        case .w: return "W"
        case .e: return "E"
        case .r: return "R"
        case .y: return "Y"
        case .t: return "T"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .six: return "6"
        case .five: return "5"
        case .equal: return "="
        case .nine: return "9"
        case .seven: return "7"
        case .minus: return "-"
        case .eight: return "8"
        case .zero: return "0"
        case .rightBracket: return "]"
        case .o: return "O"
        case .u: return "U"
        case .leftBracket: return "["
        case .i: return "I"
        case .p: return "P"
        case .return: return "⏎"
        case .l: return "L"
        case .j: return "J"
        case .quote: return "'"
        case .k: return "K"
        case .semicolon: return ";"
        case .backslash: return "\\"
        case .comma: return ","
        case .slash: return "/"
        case .n: return "N"
        case .m: return "M"
        case .period: return "."
        case .tab: return "⇥"
        case .space: return "Space"
        case .grave: return "`"
        case .delete: return "⌫"
        case .escape: return "⎋"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        default: return ""
        }
    }
}
