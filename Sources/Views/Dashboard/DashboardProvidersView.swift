import SwiftUI
import AppKit

internal struct DashboardProvidersView: View {
    // Persistent settings - Transcription
    @AppStorage("transcriptionProvider") var transcriptionProvider = TranscriptionProvider.openai
    @AppStorage("selectedWhisperModel") var selectedWhisperModel = WhisperModel.base
    @AppStorage("selectedParakeetModel") var selectedParakeetModel = ParakeetModel.v3Multilingual
    @AppStorage("hasSetupParakeet") var hasSetupParakeet = false
    @AppStorage("hasSetupLocalLLM") var hasSetupLocalLLM = false
    @AppStorage("openAIBaseURL") var openAIBaseURL = ""
    @AppStorage("geminiBaseURL") var geminiBaseURL = ""
    @AppStorage("maxModelStorageGB") var maxModelStorageGB = 5.0
    
    // Persistent settings - Correction
    @AppStorage("semanticCorrectionMode") private var semanticCorrectionModeRaw = SemanticCorrectionMode.off.rawValue
    @AppStorage("semanticCorrectionModelRepo") private var semanticCorrectionModelRepo = "mlx-community/Qwen3-1.7B-4bit"

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
    @State private var isLoaded = false
    
    // Correction UI state
    @State private var mlxModelManager = MLXModelManager.shared
    @State private var isRefreshingMLXModels = false
    @State private var isVerifyingMLX = false
    @State private var mlxVerifyMessage: String?

    @State var modelManager = ModelManager.shared
    let keychainService: KeychainServiceProtocol = KeychainService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero header
                headerSection
                
                // Main content
                VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xxl) {
                    // Engine selection - the star of the show
                    engineSection
                        .opacity(isLoaded ? 1 : 0)
                        .offset(y: isLoaded ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: isLoaded)
                    
                    // Conditional detail sections
                    Group {
                        if transcriptionProvider == .openai || transcriptionProvider == .gemini {
                            credentialsSection
                        }
                        
                        if transcriptionProvider == .parakeet {
                            parakeetCard
                        }
                        
                        if transcriptionProvider == .local {
                            localWhisperCard
                        }
                    }
                    .opacity(isLoaded ? 1 : 0)
                    .offset(y: isLoaded ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: isLoaded)
                    
                    // Correction section
                    correctionSection
                        .opacity(isLoaded ? 1 : 0)
                        .offset(y: isLoaded ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: isLoaded)
                }
                .padding(.horizontal, DashboardTheme.Spacing.xl)
                .padding(.bottom, DashboardTheme.Spacing.xxl)
            }
        }
        .background(DashboardTheme.pageBg)
        .environment(\.colorScheme, .light)
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
            withAnimation { isLoaded = true }
        }
    }
    
    // MARK: - Correction Section
    private var correctionSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.lg) {
            // Section label
            HStack(spacing: DashboardTheme.Spacing.sm) {
                Text("03")
                    .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                    .foregroundStyle(DashboardTheme.accent)
                
                Text("POST-PROCESSING")
                    .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
                    .foregroundStyle(DashboardTheme.inkMuted)
                    .tracking(1.5)
            }
            
            VStack(spacing: 0) {
                // Mode selection
                correctionModeSection
                
                let mode = SemanticCorrectionMode(rawValue: semanticCorrectionModeRaw) ?? .off
                
                if mode == .localMLX {
                    Divider().background(DashboardTheme.rule)
                    correctionMLXSection
                }
                
                if mode == .cloud {
                    Divider().background(DashboardTheme.rule)
                    correctionCloudInfo
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DashboardTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DashboardTheme.rule, lineWidth: 1)
            )
        }
    }
    
    private var correctionModeSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Semantic Correction")
                    .font(DashboardTheme.Fonts.sans(15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.ink)
                
                Text("Clean up grammar, punctuation, and filler words after transcription")
                    .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }
            
            // Mode picker as segmented control
            Picker("Mode", selection: $semanticCorrectionModeRaw) {
                ForEach(SemanticCorrectionMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(DashboardTheme.Spacing.lg)
    }
    
    private var correctionMLXSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            // Environment status (shares with Parakeet)
            HStack(spacing: DashboardTheme.Spacing.sm) {
                Image(systemName: envReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(envReady ? Color(red: 0.35, green: 0.60, blue: 0.40) : DashboardTheme.accent)
                
                Text(envReady ? "Environment ready" : "Setup required")
                    .font(DashboardTheme.Fonts.sans(12, weight: .medium))
                    .foregroundStyle(envReady ? Color(red: 0.35, green: 0.60, blue: 0.40) : DashboardTheme.accent)
                
                Spacer()
                
                if !envReady {
                    Button("Install") {
                        runCorrectionSetup()
                    }
                    .buttonStyle(PaperAccentButtonStyle())
                }
            }
            
            if envReady {
                // Model list header
                HStack {
                    Text("Correction Model")
                        .font(DashboardTheme.Fonts.sans(13, weight: .medium))
                        .foregroundStyle(DashboardTheme.ink)
                    
                    Spacer()
                    
                    if mlxModelManager.totalCacheSize > 0 {
                        Text(mlxModelManager.formatBytes(mlxModelManager.totalCacheSize))
                            .font(DashboardTheme.Fonts.mono(10, weight: .medium))
                            .foregroundStyle(DashboardTheme.inkMuted)
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
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DashboardTheme.inkMuted)
                }
                
                // Model rows
                VStack(spacing: 0) {
                    ForEach(MLXModelManager.recommendedModels, id: \.repo) { model in
                        correctionModelRow(model)
                        
                        if model.repo != MLXModelManager.recommendedModels.last?.repo {
                            Divider().background(DashboardTheme.rule)
                        }
                    }
                }
                .background(DashboardTheme.pageBg.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DashboardTheme.rule, lineWidth: 1)
                )
                
                // Footer
                HStack {
                    Text("~/.cache/huggingface/hub")
                        .font(DashboardTheme.Fonts.mono(10, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkFaint)
                    
                    Spacer()
                    
                    if mlxModelManager.unusedModelCount > 0 {
                        Button {
                            Task { await mlxModelManager.cleanupUnusedModels() }
                        } label: {
                            Text("Clean up \(mlxModelManager.unusedModelCount) old")
                                .font(DashboardTheme.Fonts.sans(10, weight: .medium))
                        }
                        .buttonStyle(PaperButtonStyle())
                    }
                }
            }
        }
        .padding(DashboardTheme.Spacing.md)
    }
    
    private func correctionModelRow(_ model: MLXModel) -> some View {
        let isSelected = semanticCorrectionModelRepo == model.repo
        let isDownloaded = mlxModelManager.downloadedModels.contains(model.repo)
        let isDownloading = mlxModelManager.isDownloading[model.repo] ?? false
        let isRecommended = model.repo == "mlx-community/Qwen3-1.7B-4bit"
        
        return HStack(spacing: DashboardTheme.Spacing.sm) {
            // Selection
            ZStack {
                Circle()
                    .stroke(isSelected ? DashboardTheme.accent : DashboardTheme.rule, lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                
                if isSelected {
                    Circle()
                        .fill(DashboardTheme.accent)
                        .frame(width: 8, height: 8)
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                        .foregroundStyle(DashboardTheme.ink)
                    
                    if isRecommended {
                        Text("REC")
                            .font(DashboardTheme.Fonts.sans(8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(DashboardTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
                
                Text(model.description)
                    .font(DashboardTheme.Fonts.sans(10, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }
            
            Spacer()
            
            // Size
            Text(mlxModelManager.modelSizes[model.repo].map { mlxModelManager.formatBytes($0) } ?? model.estimatedSize)
                .font(DashboardTheme.Fonts.mono(10, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
            
            // Action
            if isDownloading {
                ProgressView().controlSize(.small)
            } else if isDownloaded {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 0.35, green: 0.60, blue: 0.40))
                    
                    Button {
                        Task { await mlxModelManager.deleteModel(model.repo) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(DashboardTheme.inkMuted)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    Task {
                        await MainActor.run {
                            mlxModelManager.isDownloading[model.repo] = true
                        }
                        await mlxModelManager.downloadModel(model.repo)
                    }
                } label: {
                    Text("Get")
                        .font(DashboardTheme.Fonts.sans(10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DashboardTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DashboardTheme.Spacing.sm)
        .padding(.vertical, DashboardTheme.Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            semanticCorrectionModelRepo = model.repo
            if !isDownloaded && !isDownloading {
                Task {
                    await MainActor.run {
                        mlxModelManager.isDownloading[model.repo] = true
                    }
                    await mlxModelManager.downloadModel(model.repo)
                }
            }
        }
    }
    
    private var correctionCloudInfo: some View {
        HStack(spacing: DashboardTheme.Spacing.sm) {
            Image(systemName: "cloud")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.inkMuted)
            
            Text("Uses your selected cloud provider for post-processing")
                .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
        }
        .padding(DashboardTheme.Spacing.md)
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
    
    // MARK: - Hero Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent line
            Rectangle()
                .fill(DashboardTheme.accent)
                .frame(width: 40, height: 3)
                .padding(.bottom, DashboardTheme.Spacing.md)
            
            Text("Speech")
                .font(DashboardTheme.Fonts.serif(42, weight: .light))
                .foregroundStyle(DashboardTheme.ink)
            
            Text("Engines")
                .font(DashboardTheme.Fonts.serif(42, weight: .semibold))
                .foregroundStyle(DashboardTheme.ink)
                .padding(.top, -12)
            
            Text("Choose how your voice becomes text")
                .font(DashboardTheme.Fonts.sans(14, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
                .padding(.top, DashboardTheme.Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DashboardTheme.Spacing.xl)
        .padding(.top, DashboardTheme.Spacing.md)
    }
    
    // MARK: - Engine Selection Grid
    private var engineSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.lg) {
            // Section label
            HStack(spacing: DashboardTheme.Spacing.sm) {
                Text("01")
                    .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                    .foregroundStyle(DashboardTheme.accent)
                
                Text("SELECT ENGINE")
                    .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
                    .foregroundStyle(DashboardTheme.inkMuted)
                    .tracking(1.5)
            }
            
            // Provider grid - 2x2
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: DashboardTheme.Spacing.md),
                GridItem(.flexible(), spacing: DashboardTheme.Spacing.md)
            ], spacing: DashboardTheme.Spacing.md) {
                ForEach(TranscriptionProvider.allCases, id: \.self) { provider in
                    engineCard(provider)
                }
            }
        }
    }
    
    private func engineCard(_ provider: TranscriptionProvider) -> some View {
        let isSelected = transcriptionProvider == provider
        let config = engineConfig(for: provider)
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                transcriptionProvider = provider
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Top section with icon and status
                HStack(alignment: .top) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? DashboardTheme.accent : DashboardTheme.cardBgAlt)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: config.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isSelected ? .white : DashboardTheme.inkMuted)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    statusBadge(for: provider)
                }
                
                Spacer()
                
                // Bottom section with name and description
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(DashboardTheme.Fonts.sans(16, weight: .semibold))
                        .foregroundStyle(DashboardTheme.ink)
                    
                    Text(config.tagline)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Selection indicator line
                Rectangle()
                    .fill(isSelected ? DashboardTheme.accent : Color.clear)
                    .frame(height: 2)
                    .padding(.top, DashboardTheme.Spacing.sm)
            }
            .padding(DashboardTheme.Spacing.md)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DashboardTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? DashboardTheme.accent : DashboardTheme.rule, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: isSelected ? 12 : 4, y: isSelected ? 4 : 2)
        }
        .buttonStyle(.plain)
    }
    
    private struct EngineConfig {
        let icon: String
        let tagline: String
    }
    
    private func engineConfig(for provider: TranscriptionProvider) -> EngineConfig {
        switch provider {
        case .openai:
            return EngineConfig(icon: "waveform.circle", tagline: "Industry-leading accuracy via cloud")
        case .gemini:
            return EngineConfig(icon: "sparkles", tagline: "Google's multimodal intelligence")
        case .local:
            return EngineConfig(icon: "desktopcomputer", tagline: "WhisperKit on Apple Silicon")
        case .parakeet:
            return EngineConfig(icon: "bird", tagline: "NVIDIA's neural speech engine")
        }
    }
    
    @ViewBuilder
    private func statusBadge(for provider: TranscriptionProvider) -> some View {
        let (text, isReady) = statusInfo(for: provider)
        
        HStack(spacing: 4) {
            Circle()
                .fill(isReady ? Color(red: 0.35, green: 0.60, blue: 0.40) : DashboardTheme.accent)
                .frame(width: 6, height: 6)
            
            Text(text)
                .font(DashboardTheme.Fonts.sans(10, weight: .medium))
                .foregroundStyle(isReady ? Color(red: 0.35, green: 0.60, blue: 0.40) : DashboardTheme.accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((isReady ? Color(red: 0.35, green: 0.60, blue: 0.40) : DashboardTheme.accent).opacity(0.1))
        )
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
    
    // MARK: - Credentials Section
    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.lg) {
            // Section label
            HStack(spacing: DashboardTheme.Spacing.sm) {
                Text("02")
                    .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                    .foregroundStyle(DashboardTheme.accent)
                
                Text("API CREDENTIALS")
                    .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
                    .foregroundStyle(DashboardTheme.inkMuted)
                    .tracking(1.5)
            }
            
            VStack(spacing: 0) {
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
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DashboardTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DashboardTheme.rule, lineWidth: 1)
            )
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
                                .foregroundStyle(Color(red: 0.35, green: 0.60, blue: 0.40))
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
                    .textFieldStyle(.plain)
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
                .padding(.horizontal, DashboardTheme.Spacing.md)
                .padding(.vertical, DashboardTheme.Spacing.sm + 2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DashboardTheme.pageBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DashboardTheme.rule, lineWidth: 1)
                )
                
                Button(action: onSave) {
                    Text("Save")
                        .font(DashboardTheme.Fonts.sans(13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DashboardTheme.Spacing.md)
                        .padding(.vertical, DashboardTheme.Spacing.sm + 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(DashboardTheme.accent)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DashboardTheme.Spacing.lg)
    }
    
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().background(DashboardTheme.rule)
            
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showAdvancedAPISettings.toggle()
                }
            } label: {
                HStack {
                    Text("Advanced")
                        .font(DashboardTheme.Fonts.sans(13, weight: .medium))
                        .foregroundStyle(DashboardTheme.inkLight)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.inkMuted)
                        .rotationEffect(.degrees(showAdvancedAPISettings ? 90 : 0))
                }
                .padding(DashboardTheme.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if showAdvancedAPISettings {
                VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
                    Text("Custom base URLs for enterprise proxies")
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                    
                    VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                        Text("OpenAI")
                            .font(DashboardTheme.Fonts.sans(11, weight: .medium))
                            .foregroundStyle(DashboardTheme.inkMuted)
                        
                        TextField("https://api.openai.com/v1", text: $openAIBaseURL)
                            .textFieldStyle(.plain)
                            .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                            .padding(DashboardTheme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DashboardTheme.pageBg)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(DashboardTheme.rule, lineWidth: 1)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                        Text("Gemini")
                            .font(DashboardTheme.Fonts.sans(11, weight: .medium))
                            .foregroundStyle(DashboardTheme.inkMuted)
                        
                        TextField("https://generativelanguage.googleapis.com", text: $geminiBaseURL)
                            .textFieldStyle(.plain)
                            .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                            .padding(DashboardTheme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DashboardTheme.pageBg)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(DashboardTheme.rule, lineWidth: 1)
                            )
                    }
                }
                .padding(DashboardTheme.Spacing.md)
                .padding(.top, 0)
            }
        }
    }
    
    // MARK: - Helpers
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
            .foregroundStyle(DashboardTheme.inkMuted)
            .tracking(0.8)
            .textCase(.uppercase)
    }
}
