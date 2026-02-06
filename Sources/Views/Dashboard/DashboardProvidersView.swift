import SwiftUI

internal struct DashboardProvidersView: View {
    // Persistent settings - Transcription
    @AppStorage(AppDefaults.Keys.transcriptionProvider) var transcriptionProvider = AppDefaults.defaultTranscriptionProvider
    @AppStorage(AppDefaults.Keys.selectedWhisperModel) var selectedWhisperModel = AppDefaults.defaultWhisperModel
    @AppStorage(AppDefaults.Keys.selectedParakeetModel) var selectedParakeetModel = AppDefaults.defaultParakeetModel
    @AppStorage(AppDefaults.Keys.hasSetupParakeet) var hasSetupParakeet = false
    @AppStorage(AppDefaults.Keys.hasSetupLocalLLM) var hasSetupLocalLLM = false
    @AppStorage("openAIBaseURL") var openAIBaseURL = ""
    @AppStorage("geminiBaseURL") var geminiBaseURL = ""
    @AppStorage(AppDefaults.Keys.maxModelStorageGB) var maxModelStorageGB = 5.0
    
    // Persistent settings - Correction
    @AppStorage(AppDefaults.Keys.semanticCorrectionMode) private var semanticCorrectionModeRaw = AppDefaults.defaultSemanticCorrectionMode.rawValue
    @AppStorage(AppDefaults.Keys.semanticCorrectionModelRepo) private var semanticCorrectionModelRepo = AppDefaults.defaultSemanticCorrectionModelRepo

    // UI state
    @State var openAIKey = ""
    @State var geminiKey = ""
    @State var showOpenAIKey = false
    @State var showGeminiKey = false
    @State var showAdvancedAPISettings = false
    @State var downloadError: String?
    @State var parakeetVerifyMessage: String?
    @State var envReady = false
    @State var isCheckingEnv = false
    @State var isVerifyingParakeet = false
    @State var showSetupSheet = false
    @State var isSettingUp = false
    @State var setupLogs = ""
    @State var setupStatus: String?
    @State var totalModelsSize: Int64 = 0
    @State var downloadedModels: [WhisperModel] = []
    @State var modelDownloadStates: [WhisperModel: Bool] = [:]
    @State var downloadStartTime: [WhisperModel: Date] = [:]
    
    // Correction UI state
    @State var mlxModelManager = MLXModelManager.shared
    @State private var isRefreshingMLXModels = false
    @State private var isVerifyingMLX = false
    @State private var mlxVerifyMessage: String?
    @State private var showMLXModelsSheet = false

    @State var modelManager = ModelManager.shared
    let keychainService: KeychainServiceProtocol = KeychainService.shared

    var body: some View {
        Form {
            Section {
                engineSection
            } header: {
                Text("Engine")
            } footer: {
                Text(engineConfig(for: transcriptionProvider).tagline)
            }

            if transcriptionProvider == .openai || transcriptionProvider == .gemini {
                Section("API Credentials") {
                    credentialsSection
                }
            }

            if transcriptionProvider == .parakeet {
                Section("Parakeet Setup") {
                    parakeetCard
                }
            }

            if transcriptionProvider == .local {
                Section("Local Models") {
                    localWhisperCard
                }
            }

            Section {
                correctionSection
            } header: {
                Text("Semantic Correction")
            } footer: {
                Text("Clean up grammar, punctuation, and filler words after transcription.")
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showSetupSheet) {
            SetupEnvironmentSheet(
                isPresented: $showSetupSheet,
                isRunning: $isSettingUp,
                logs: $setupLogs,
                title: setupStatus ?? "Setting up environment…",
                onStart: { }
            )
        }
        .onAppear {
            loadAPIKeys()
            loadModelStates()
            checkEnvReady()
            Task {
                isRefreshingMLXModels = true
                await mlxModelManager.refreshModelList()
                await MainActor.run { isRefreshingMLXModels = false }
            }
        }
    }
    
    // MARK: - Correction Section
    private var correctionSection: some View {
        let mode = SemanticCorrectionMode(rawValue: semanticCorrectionModeRaw) ?? .off

        return Group {
            Picker("Mode", selection: $semanticCorrectionModeRaw) {
                ForEach(SemanticCorrectionMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
            .pickerStyle(.menu)

            switch mode {
            case .off:
                EmptyView()
            case .localMLX:
                correctionMLXSection
            case .cloud:
                correctionCloudInfo
            }
        }
        .sheet(isPresented: $showMLXModelsSheet) {
            MLXModelsSheet(selectedModelRepo: $semanticCorrectionModelRepo)
        }
    }
    
    private var correctionMLXSection: some View {
        let models = mlxModelsForPicker()
        let repo = semanticCorrectionModelRepo
        let selectedModel = models.first(where: { $0.repo == repo })
        let isDownloaded = mlxModelManager.downloadedModels.contains(repo)
        let isDownloading = mlxModelManager.isDownloading[repo] ?? false
        let sizeText = mlxModelManager.modelSizes[repo].map { mlxModelManager.formatBytes($0) }
            ?? selectedModel?.estimatedSize
            ?? ""
        let progressText = mlxModelManager.downloadProgress[repo]

        return Group {
            LabeledContent("Environment") {
                HStack(spacing: 10) {
                    Label(envReady ? "Ready" : "Setup required",
                          systemImage: envReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(envReady ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange))

                    if !envReady {
                        Button("Install…") { runCorrectionSetup() }
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            LabeledContent("Model") {
                HStack(spacing: 10) {
                    Picker("", selection: $semanticCorrectionModelRepo) {
                        ForEach(models, id: \.repo) { model in
                            Text(model.displayName).tag(model.repo)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 260)

                    if isDownloading {
                        ProgressView().controlSize(.small)
                    } else if isDownloaded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color(nsColor: .systemGreen))
                            .help("Downloaded")
                    } else {
                        Button("Get") { downloadMLXModel(repo) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let selectedModel {
                Text(selectedModel.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !sizeText.isEmpty || (progressText?.isEmpty == false) {
                let status = (progressText?.isEmpty == false) ? (progressText ?? "") : (isDownloaded ? "Downloaded" : "Not downloaded")
                let line = status + (sizeText.isEmpty ? "" : " • \(sizeText)")
                Text(line)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Manage Models…") { showMLXModelsSheet = true }
                    .controlSize(.small)

                Spacer()

                if mlxModelManager.unusedModelCount > 0 {
                    Button("Clean Up Old Models…") {
                        Task { await mlxModelManager.cleanupUnusedModels() }
                    }
                    .controlSize(.small)
                }

                Button {
                    isRefreshingMLXModels = true
                    Task {
                        await mlxModelManager.refreshModelList()
                        await MainActor.run { isRefreshingMLXModels = false }
                    }
                } label: {
                    if isRefreshingMLXModels {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .help("Refresh model list")
            }

            Text("Cache: ~/.cache/huggingface/hub")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
    
    private var correctionCloudInfo: some View {
        Label("Uses your selected cloud provider for post-processing.", systemImage: "cloud")
            .foregroundStyle(.secondary)
            .font(.callout)
    }

    private func mlxModelsForPicker() -> [MLXModel] {
        let current = semanticCorrectionModelRepo
        if MLXModelManager.recommendedModels.contains(where: { $0.repo == current }) {
            return MLXModelManager.recommendedModels
        }
        let custom = MLXModel(repo: current, estimatedSize: "", description: "Custom model")
        return [custom] + MLXModelManager.recommendedModels
    }

    private func downloadMLXModel(_ repo: String) {
        Task { await mlxModelManager.downloadModel(repo) }
    }
    
    private func runCorrectionSetup() {
        setupStatus = "Installing correction dependencies…"
        setupLogs = ""
        isSettingUp = true
        showSetupSheet = true
        Task {
            do {
                _ = try UvBootstrap.ensureVenv(userPython: nil) { msg in
                    Task { @MainActor in
                        setupLogs += (setupLogs.isEmpty ? "" : "\n") + msg
                    }
                }
                await MainActor.run {
                    isSettingUp = false
                    setupStatus = "✓ Environment ready"
                    envReady = true
                    hasSetupLocalLLM = true
                }
                try? await Task.sleep(for: .milliseconds(600))
                await MainActor.run { showSetupSheet = false }
            } catch {
                await MainActor.run {
                    isSettingUp = false
                    setupStatus = "✗ Setup failed"
                    setupLogs += "\nError: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Engine Selection
    private var engineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $transcriptionProvider) {
                ForEach(TranscriptionProvider.allCases, id: \.self) { provider in
                    Label(provider.displayName, systemImage: providerIcon(for: provider))
                        .tag(provider)
                }
            }
            .labelsHidden()
            .pickerStyle(.radioGroup)

            selectedEngineStatus
                .font(.footnote)
        }
    }
    
    private struct EngineConfig {
        let tagline: String
    }
    
    private func engineConfig(for provider: TranscriptionProvider) -> EngineConfig {
        switch provider {
        case .openai:
            return EngineConfig(tagline: "Industry-leading accuracy via cloud")
        case .gemini:
            return EngineConfig(tagline: "Google's multimodal intelligence")
        case .local:
            return EngineConfig(tagline: "WhisperKit on Apple Silicon")
        case .parakeet:
            return EngineConfig(tagline: "NVIDIA's neural speech engine")
        }
    }
    
    private var selectedEngineStatus: some View {
        let (text, isReady) = statusInfo(for: transcriptionProvider)
        return Label(text, systemImage: isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(isReady ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange))
    }

    private func statusInfo(for provider: TranscriptionProvider) -> (String, Bool) {
        switch provider {
        case .openai:
            return openAIKey.isEmpty ? ("Setup", false) : ("Ready", true)
        case .gemini:
            return geminiKey.isEmpty ? ("Setup", false) : ("Ready", true)
        case .local:
            return downloadedModels.isEmpty ? ("Setup", false) : ("Ready", true)
        case .parakeet:
            return envReady ? ("Ready", true) : ("Setup", false)
        }
    }

    // Small bit of visual identity, while still using system SF Symbols.
    private func providerIcon(for provider: TranscriptionProvider) -> String {
        switch provider {
        case .openai:
            return "cloud"
        case .gemini:
            return "sparkles"
        case .local:
            return "laptopcomputer"
        case .parakeet:
            return "bird"
        }
    }
    
    // MARK: - Credentials Section
    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            // Show relevant key based on provider
            if transcriptionProvider == .openai {
                apiKeyField(
                    provider: "OpenAI",
                    hint: "Get your key at platform.openai.com",
                    key: $openAIKey,
                    isShowing: $showOpenAIKey,
                    placeholder: "sk-..."
                ) {
                    saveAPIKey(openAIKey, service: "AudioWhisper", account: "OpenAI")
                }
            }

            if transcriptionProvider == .gemini {
                apiKeyField(
                    provider: "Gemini",
                    hint: "Get your key at aistudio.google.com",
                    key: $geminiKey,
                    isShowing: $showGeminiKey,
                    placeholder: "AIza..."
                ) {
                    saveAPIKey(geminiKey, service: "AudioWhisper", account: "Gemini")
                }
            }

            // Advanced settings
            advancedSection
        }
    }
    
    private func apiKeyField(
        provider: String,
        hint: String,
        key: Binding<String>,
        isShowing: Binding<Bool>,
        placeholder: String,
        onSave: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: DashboardTheme.Spacing.sm) {
                        Text(provider)
                            .font(DashboardTheme.Fonts.sans(15, weight: .semibold))
                            .foregroundStyle(DashboardTheme.ink)
                        
                        if !key.wrappedValue.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(DashboardTheme.success)
                        }
                    }
                    
                    Text(hint)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
                
                Spacer()
            }
            
            // Key input field
                HStack(spacing: DashboardTheme.Spacing.sm) {
                    HStack(spacing: 0) {
                        Group {
                            if isShowing.wrappedValue {
                                TextField(placeholder, text: key)
                            } else {
                                SecureField(placeholder, text: key)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .font(DashboardTheme.Fonts.mono(13, weight: .regular))
                        
                        Button {
                            isShowing.wrappedValue.toggle()
                    } label: {
                        Image(systemName: isShowing.wrappedValue ? "eye.slash" : "eye")
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.inkMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button("Save", action: onSave)
                        .buttonStyle(.borderedProminent)
                }
        }
        .padding(DashboardTheme.Spacing.lg)
    }
    
    private var advancedSection: some View {
        DisclosureGroup("Advanced", isExpanded: $showAdvancedAPISettings) {
            Text("Custom base URLs for enterprise proxies")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            LabeledContent("OpenAI") {
                TextField("https://api.openai.com/v1", text: $openAIBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                    .frame(maxWidth: 320)
            }

            LabeledContent("Gemini") {
                TextField("https://generativelanguage.googleapis.com", text: $geminiBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                    .frame(maxWidth: 320)
            }
        }
    }
    
}

private struct MLXModelsSheet: View {
    @Binding var selectedModelRepo: String
    @Environment(\.dismiss) private var dismiss
    @State private var modelManager = MLXModelManager.shared
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(MLXModelManager.recommendedModels, id: \.repo) { model in
                        row(for: model)
                    }
                } footer: {
                    Text("Cache: ~/.cache/huggingface/hub")
                }
            }
            .listStyle(.inset)
            .navigationTitle("MLX Models")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isRefreshing = true
                        Task {
                            await modelManager.refreshModelList()
                            await MainActor.run { isRefreshing = false }
                        }
                    } label: {
                        if isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .help("Refresh model list")
                }
            }
        }
        .frame(width: 640, height: 520)
        .onAppear {
            Task { await modelManager.refreshModelList() }
        }
    }

    @ViewBuilder
    private func row(for model: MLXModel) -> some View {
        let isSelected = selectedModelRepo == model.repo
        let isDownloaded = modelManager.downloadedModels.contains(model.repo)
        let isDownloading = modelManager.isDownloading[model.repo] ?? false
        let statusText = modelManager.downloadProgress[model.repo]
        let sizeText = modelManager.modelSizes[model.repo].map(modelManager.formatBytes) ?? model.estimatedSize

        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.body)

                Text(model.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let statusText, !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(sizeText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if isDownloading {
                ProgressView().controlSize(.small)
            } else if isDownloaded {
                Button(role: .destructive) {
                    Task { await modelManager.deleteModel(model.repo) }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete model")
            } else {
                Button("Get") {
                    Task { await modelManager.downloadModel(model.repo) }
                }
                .controlSize(.small)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedModelRepo = model.repo
        }
    }
}
