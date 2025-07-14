import SwiftUI
import AVFoundation
import ServiceManagement
import HotKey
import os.log

struct SettingsView: View {
    @AppStorage("selectedMicrophone") private var selectedMicrophone = ""
    @AppStorage("globalHotkey") private var globalHotkey = "⌘⇧Space"
    @AppStorage("transcriptionProvider") private var transcriptionProvider = TranscriptionProvider.openai
    @AppStorage("selectedWhisperModel") private var selectedWhisperModel = WhisperModel.base
    @AppStorage("startAtLogin") private var startAtLogin = true
    @AppStorage("immediateRecording") private var immediateRecording = false
    @AppStorage("autoBoostMicrophoneVolume") private var autoBoostMicrophoneVolume = false
    @AppStorage("enableSmartPaste") private var enableSmartPaste = false
    @AppStorage("playCompletionSound") private var playCompletionSound = true
    @AppStorage("maxModelStorageGB") private var maxModelStorageGB = 5.0
    @AppStorage("parakeetPythonPath") private var parakeetPythonPath = "/usr/bin/python3"
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
    
    private let keychainService: KeychainServiceProtocol
    private let skipOnAppear: Bool
    @State private var downloadStartTime: [WhisperModel: Date] = [:]
    
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
            
            Section("General") {
                Toggle("Start at Login", isOn: $startAtLogin)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Start AudioWhisper at login")
                    .accessibilityHint("When enabled, AudioWhisper will automatically start when you log into your Mac")
                    .onChange(of: startAtLogin) { oldValue, newValue in
                        updateLoginItem(enabled: newValue)
                    }
                
                Toggle("Start Recording Immediately", isOn: $immediateRecording)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Start recording immediately on hotkey")
                    .accessibilityHint("When enabled, recording starts immediately when you press the hotkey without needing to press space")
                
                Toggle("Auto-Boost Microphone Volume", isOn: $autoBoostMicrophoneVolume)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Automatically boost microphone volume")
                    .accessibilityHint("When enabled, microphone volume is temporarily increased to 100% during recording and restored afterward")
                
                Toggle("Smart Paste (Auto Cmd+V)", isOn: $enableSmartPaste)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Automatically paste transcribed text")
                    .accessibilityHint("When enabled, automatically simulates Cmd+V to paste transcribed text. Requires Input Monitoring permission.")
                
                Toggle("Play Completion Sound", isOn: $playCompletionSound)
                    .toggleStyle(.switch)
                    .accessibilityLabel("Play sound when transcription completes")
                    .accessibilityHint("When enabled, plays a gentle sound when transcription is finished and text is pasted")
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
                                
                                Text("Requires Python with parakeet-mlx. First use downloads ~600MB model.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        // Python Configuration Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "terminal")
                                    .foregroundColor(.blue)
                                Text("Python Path")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            TextField("Python executable path", text: $parakeetPythonPath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            
                            HStack(spacing: 8) {
                                Button("Browse...") {
                                    selectPythonPath()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                
                                Button("Test Setup") {
                                    testParakeetSetup()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                                
                                Spacer()
                            }
                        }
                        .padding(16)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        // Installation help
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("Install:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("uv add parakeet-mlx -U")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .monospaced()
                            }
                            
                            Link("Learn more about Parakeet", 
                                 destination: URL(string: "https://github.com/senstella/parakeet-mlx")!)
                                .font(.caption)
                        }
                    }
                }
            }
            
            // Enhanced Local Whisper Model Management
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
                                
                                if !modelManager.downloadedModels.isEmpty {
                                    Button(action: {
                                        deleteAllModels()
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                            Text("Clear All")
                                                .font(.caption)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .foregroundColor(.red)
                                    .controlSize(.mini)
                                }
                            }
                        }
                        .padding(.bottom, 12)
                        
                        // Model cards
                        VStack(spacing: 12) {
                            ForEach(WhisperModel.allCases, id: \.self) { model in
                                ModelCardView(
                                    model: model,
                                    isSelected: selectedWhisperModel == model,
                                    isDownloaded: modelManager.downloadedModels.contains(model),
                                    downloadStage: modelManager.getDownloadStage(for: model),
                                    estimatedTimeRemaining: modelManager.getEstimatedTimeRemaining(for: model),
                                    onDownload: {
                                        downloadModel(model)
                                    },
                                    onDelete: {
                                        deleteModel(model)
                                    },
                                    onSelect: {
                                        selectedWhisperModel = model
                                    }
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
                // Make sure the view can receive key events
                DispatchQueue.main.async {
                    NSApplication.shared.keyWindow?.makeFirstResponder(nil)
                }
            }
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
        keychainService.saveQuietly(key, service: service, account: account)
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
    
    private func updateGlobalHotkey(_ newHotkey: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("UpdateGlobalHotkey"),
            object: newHotkey
        )
    }
    
    private func selectPythonPath() {
        let panel = NSOpenPanel()
        panel.title = "Select Python Executable"
        panel.message = "Choose the Python executable with parakeet-mlx installed"
        panel.prompt = "Select"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = []
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                parakeetPythonPath = url.path
            }
        }
    }
    
    private func testParakeetSetup() {
        Task {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: parakeetPythonPath)
                process.arguments = ["-c", "import parakeet_mlx; print('OK')"]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if process.terminationStatus == 0 && output == "OK" {
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "Parakeet Setup Valid"
                        alert.informativeText = "Python path is valid and parakeet-mlx is installed.\n\nPython: \(parakeetPythonPath)\n\nThe Parakeet model will be downloaded on first use."
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                } else {
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "Parakeet Setup Failed"
                        alert.informativeText = """
                        parakeet-mlx is not installed in this Python environment.
                        
                        Python path: \(parakeetPythonPath)
                        
                        Error: \(errorOutput.isEmpty ? "Module not found" : errorOutput)
                        
                        To fix:
                        1. Use the Python where you installed parakeet-mlx
                        2. Or install it: pip install parakeet-mlx
                        
                        If using a virtual environment, make sure to use the Python binary from that environment.
                        """
                        alert.alertStyle = .critical
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            } catch {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "Test Failed"
                    alert.informativeText = """
                    Could not run Python at: \(parakeetPythonPath)
                    
                    Error: \(error.localizedDescription)
                    
                    Make sure the path points to a valid Python executable.
                    
                    Common Python locations:
                    • /usr/bin/python3
                    • /usr/local/bin/python3
                    • /opt/homebrew/bin/python3
                    • Virtual environment: venv/bin/python3
                    """
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
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
    
    private func deleteAllModels() {
        Task {
            for model in Array(modelManager.downloadedModels) {
                do {
                    try await modelManager.deleteModel(model)
                } catch {
                    await MainActor.run {
                        downloadError = "Failed to delete \(model.displayName): \(error.localizedDescription)"
                    }
                }
            }
            // Refresh the UI
            await modelManager.refreshModelStates()
        }
    }
    
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
                if !recordedModifiers.isEmpty && recordedKey != nil {
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
        // Must have at least one modifier
        if modifiers.isEmpty {
            return false
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
        case 126: return .upArrow
        case 125: return .downArrow
        case 123: return .leftArrow
        case 124: return .rightArrow
        default: return nil
        }
    }
    
    private func keyToString(_ key: Key) -> String {
        switch key {
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