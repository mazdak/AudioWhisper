import Foundation
import Observation

/// Observable state container for provider-related UI state.
/// Centralizes the scattered @State variables from DashboardProvidersView
/// for better testability and maintainability.
@Observable
@MainActor
final class ProviderSettingsState {
    // MARK: - Environment State
    var envReady = false
    var isCheckingEnv = false

    // MARK: - Setup Sheet State
    var showSetupSheet = false
    var isSettingUp = false
    var setupLogs = ""
    var setupStatus: String?

    // MARK: - Parakeet State
    var parakeetVerifyMessage: String?
    var isVerifyingParakeet = false

    // MARK: - Model Download State
    var downloadError: String?
    var totalModelsSize: Int64 = 0
    var downloadedModels: [WhisperModel] = []
    var modelDownloadStates: [WhisperModel: Bool] = [:]
    var downloadStartTime: [WhisperModel: Date] = [:]

    // MARK: - MLX Correction State
    var isRefreshingMLXModels = false
    var isVerifyingMLX = false
    var mlxVerifyMessage: String?

    // MARK: - Animation State
    var isLoaded = false

    // MARK: - Initialization

    init(keychainService: KeychainServiceProtocol = KeychainService.shared) {
        // keychainService parameter kept for API compatibility but no longer used
    }

    // MARK: - Status Helpers

    func statusInfo(for provider: TranscriptionProvider) -> (text: String, isReady: Bool) {
        switch provider {
        case .local:
            return downloadedModels.isEmpty ? ("Setup", false) : ("Ready", true)
        case .parakeet:
            return envReady ? ("Ready", true) : ("Setup", false)
        }
    }

    // MARK: - Environment Check

    func checkEnvReady() {
        isCheckingEnv = true
        Task {
            let ready = await UvBootstrap.isEnvReady()
            await MainActor.run {
                self.envReady = ready
                self.isCheckingEnv = false
            }
        }
    }

    // MARK: - Model State Management

    func loadModelStates(from modelManager: ModelManager) {
        downloadedModels = Array(modelManager.downloadedModels)
        for model in WhisperModel.allCases {
            modelDownloadStates[model] = downloadedModels.contains(model)
        }
    }

    func updateModelDownloadState(_ model: WhisperModel, isDownloading: Bool) {
        if isDownloading {
            downloadStartTime[model] = Date()
        } else {
            downloadStartTime.removeValue(forKey: model)
        }
    }

    // MARK: - Setup Operations

    func beginSetup(title: String) {
        setupStatus = title
        setupLogs = ""
        isSettingUp = true
        showSetupSheet = true
    }

    func completeSetup(success: Bool, message: String) {
        isSettingUp = false
        setupStatus = message
        if success {
            envReady = true
        }
    }

    func appendSetupLog(_ message: String) {
        setupLogs += (setupLogs.isEmpty ? "" : "\n") + message
    }

    func dismissSetupSheet() {
        showSetupSheet = false
    }

    // MARK: - Reset

    func reset() {
        envReady = false
        isCheckingEnv = false
        showSetupSheet = false
        isSettingUp = false
        setupLogs = ""
        setupStatus = nil
        parakeetVerifyMessage = nil
        isVerifyingParakeet = false
        downloadError = nil
        totalModelsSize = 0
        downloadedModels = []
        modelDownloadStates = [:]
        downloadStartTime = [:]
        isRefreshingMLXModels = false
        isVerifyingMLX = false
        mlxVerifyMessage = nil
        isLoaded = false
    }
}
