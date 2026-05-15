import SwiftUI
import AppKit

internal struct DashboardProvidersView: View {
    // Persistent settings - Transcription
    @AppStorage("transcriptionProvider") var transcriptionProvider = TranscriptionProvider.parakeet
    @AppStorage("selectedWhisperModel") var selectedWhisperModel = WhisperModel.base
    @AppStorage("selectedParakeetModel") var selectedParakeetModel = ParakeetModel.v3Multilingual
    @AppStorage("hasSetupParakeet") var hasSetupParakeet = false
    @AppStorage("hasSetupLocalLLM") var hasSetupLocalLLM = false
    @AppStorage("maxModelStorageGB") var maxModelStorageGB = 5.0

    // Persistent settings - Correction
    @AppStorage("semanticCorrectionMode") var semanticCorrectionModeRaw = SemanticCorrectionMode.off.rawValue
    @AppStorage("semanticCorrectionModelRepo") var semanticCorrectionModelRepo = "mlx-community/Qwen3-1.7B-4bit"

    // Consolidated UI state container
    @State var state = ProviderSettingsState()

    // Model managers
    @State var mlxModelManager = MLXModelManager.shared
    @State var modelManager = ModelManager.shared

    // Computed properties for backward compatibility with extensions
    var downloadError: String? {
        get { state.downloadError }
        nonmutating set { state.downloadError = newValue }
    }
    var parakeetVerifyMessage: String? {
        get { state.parakeetVerifyMessage }
        nonmutating set { state.parakeetVerifyMessage = newValue }
    }
    var envReady: Bool {
        get { state.envReady }
        nonmutating set { state.envReady = newValue }
    }
    var isCheckingEnv: Bool {
        get { state.isCheckingEnv }
        nonmutating set { state.isCheckingEnv = newValue }
    }
    var isVerifyingParakeet: Bool {
        get { state.isVerifyingParakeet }
        nonmutating set { state.isVerifyingParakeet = newValue }
    }
    var showSetupSheet: Bool {
        get { state.showSetupSheet }
        nonmutating set { state.showSetupSheet = newValue }
    }
    var isSettingUp: Bool {
        get { state.isSettingUp }
        nonmutating set { state.isSettingUp = newValue }
    }
    var setupLogs: String {
        get { state.setupLogs }
        nonmutating set { state.setupLogs = newValue }
    }
    var setupStatus: String? {
        get { state.setupStatus }
        nonmutating set { state.setupStatus = newValue }
    }
    var totalModelsSize: Int64 {
        get { state.totalModelsSize }
        nonmutating set { state.totalModelsSize = newValue }
    }
    var downloadedModels: [WhisperModel] {
        get { state.downloadedModels }
        nonmutating set { state.downloadedModels = newValue }
    }
    var modelDownloadStates: [WhisperModel: Bool] {
        get { state.modelDownloadStates }
        nonmutating set { state.modelDownloadStates = newValue }
    }
    var downloadStartTime: [WhisperModel: Date] {
        get { state.downloadStartTime }
        nonmutating set { state.downloadStartTime = newValue }
    }
    var isRefreshingMLXModels: Bool {
        get { state.isRefreshingMLXModels }
        nonmutating set { state.isRefreshingMLXModels = newValue }
    }
    private var isVerifyingMLX: Bool {
        get { state.isVerifyingMLX }
        nonmutating set { state.isVerifyingMLX = newValue }
    }
    private var mlxVerifyMessage: String? {
        get { state.mlxVerifyMessage }
        nonmutating set { state.mlxVerifyMessage = newValue }
    }
    private var isLoaded: Bool {
        get { state.isLoaded }
        nonmutating set { state.isLoaded = newValue }
    }

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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Transcription providers")
        .sheet(isPresented: $state.showSetupSheet) {
            SetupEnvironmentSheet(
                isPresented: $state.showSetupSheet,
                isRunning: $state.isSettingUp,
                logs: $state.setupLogs,
                title: setupStatus ?? "Setting up environment…",
                onStart: { }
            )
        }
        .onAppear {
            state.loadModelStates(from: modelManager)
            state.checkEnvReady()
            Task {
                isRefreshingMLXModels = true
                await mlxModelManager.refreshModelList()
                await MainActor.run { isRefreshingMLXModels = false }
            }
            withAnimation { isLoaded = true }
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

// MARK: - Testable Helpers
extension DashboardProvidersView {
    /// Returns the status info tuple for a given provider
    /// Used for testing status badge logic
    static func testableStatusInfo(
        for provider: TranscriptionProvider,
        downloadedModels: [WhisperModel],
        envReady: Bool
    ) -> (String, Bool) {
        switch provider {
        case .local:
            return downloadedModels.isEmpty ? ("Setup", false) : ("Ready", true)
        case .parakeet:
            return envReady ? ("Ready", true) : ("Setup", false)
        }
    }

    /// Returns the engine config for a given provider
    /// Used for testing engine card configuration
    static func testableEngineConfig(for provider: TranscriptionProvider) -> (icon: String, tagline: String) {
        switch provider {
        case .local:
            return ("desktopcomputer", "WhisperKit on Apple Silicon")
        case .parakeet:
            return ("bird", "NVIDIA's neural speech engine")
        }
    }

    /// Returns the semantic correction mode from raw string
    static func testableSemanticCorrectionMode(from rawValue: String) -> SemanticCorrectionMode? {
        SemanticCorrectionMode(rawValue: rawValue)
    }

    /// Returns whether MLX section should be shown based on correction mode
    static func testableShowsMLXSection(modeRaw: String) -> Bool {
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
        return mode == .localMLX
    }
}
