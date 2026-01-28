import Foundation

/// Centralized, type-safe wrapper for all UserDefaults access in the app.
/// All UserDefaults keys are defined here to prevent typos and provide documentation.
@MainActor
enum AppDefaults {
    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    /// All UserDefaults keys used in the app, centralized for discoverability and safety.
    enum Key: String {
        // Transcription
        case transcriptionProvider
        case selectedWhisperModel
        case selectedParakeetModel
        case useOpenAI  // Legacy key

        // API Configuration
        case openAIBaseURL
        case geminiBaseURL

        // Semantic Correction
        case semanticCorrectionMode
        case semanticCorrectionModelRepo

        // Recording
        case globalHotkey
        case immediateRecording
        case selectedMicrophone
        case pressAndHoldEnabled
        case pressAndHoldKeyIdentifier
        case pressAndHoldMode
        case autoBoostMicrophoneVolume

        // Visual
        case waveformStyle
        case visualIntensity
        case menuBarIconSize

        // Behavior
        case enableSmartPaste
        case playCompletionSound
        case startAtLogin

        // Data
        case transcriptionHistoryEnabled
        case transcriptionRetentionPeriod
        case maxModelStorageGB

        // Setup State
        case hasSetupParakeet
        case hasSetupLocalLLM
        case hasCompletedWelcome
        case lastWelcomeVersion
        case hasShownFirstModelUseHint
    }

    // MARK: - Transcription Settings

    static var transcriptionProvider: TranscriptionProvider {
        get {
            guard let rawValue = defaults.string(forKey: Key.transcriptionProvider.rawValue),
                  let provider = TranscriptionProvider(rawValue: rawValue) else {
                return .openai
            }
            return provider
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.transcriptionProvider.rawValue)
        }
    }

    static var selectedWhisperModel: WhisperModel {
        get {
            guard let rawValue = defaults.string(forKey: Key.selectedWhisperModel.rawValue),
                  let model = WhisperModel(rawValue: rawValue) else {
                return .base
            }
            return model
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.selectedWhisperModel.rawValue)
        }
    }

    static var selectedParakeetModel: ParakeetModel {
        get {
            guard let rawValue = defaults.string(forKey: Key.selectedParakeetModel.rawValue),
                  let model = ParakeetModel(rawValue: rawValue) else {
                return .v3Multilingual
            }
            return model
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.selectedParakeetModel.rawValue)
        }
    }

    // MARK: - API Configuration

    static var openAIBaseURL: String {
        get { defaults.string(forKey: Key.openAIBaseURL.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: Key.openAIBaseURL.rawValue) }
    }

    static var geminiBaseURL: String {
        get { defaults.string(forKey: Key.geminiBaseURL.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: Key.geminiBaseURL.rawValue) }
    }

    // MARK: - Semantic Correction

    static var semanticCorrectionMode: SemanticCorrectionMode {
        get {
            guard let rawValue = defaults.string(forKey: Key.semanticCorrectionMode.rawValue),
                  let mode = SemanticCorrectionMode(rawValue: rawValue) else {
                return .off
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.semanticCorrectionMode.rawValue)
        }
    }

    static var semanticCorrectionModelRepo: String {
        get { defaults.string(forKey: Key.semanticCorrectionModelRepo.rawValue) ?? "mlx-community/Qwen3-1.7B-4bit" }
        set { defaults.set(newValue, forKey: Key.semanticCorrectionModelRepo.rawValue) }
    }

    // MARK: - Recording Settings

    static var globalHotkey: String {
        get { defaults.string(forKey: Key.globalHotkey.rawValue) ?? "⌘⇧Space" }
        set { defaults.set(newValue, forKey: Key.globalHotkey.rawValue) }
    }

    static var immediateRecording: Bool {
        get { defaults.bool(forKey: Key.immediateRecording.rawValue) }
        set { defaults.set(newValue, forKey: Key.immediateRecording.rawValue) }
    }

    static var selectedMicrophone: String {
        get { defaults.string(forKey: Key.selectedMicrophone.rawValue) ?? "" }
        set { defaults.set(newValue, forKey: Key.selectedMicrophone.rawValue) }
    }

    static var pressAndHoldEnabled: Bool {
        get {
            if defaults.object(forKey: Key.pressAndHoldEnabled.rawValue) == nil {
                return PressAndHoldConfiguration.defaults.enabled
            }
            return defaults.bool(forKey: Key.pressAndHoldEnabled.rawValue)
        }
        set { defaults.set(newValue, forKey: Key.pressAndHoldEnabled.rawValue) }
    }

    static var pressAndHoldKeyIdentifier: String {
        get { defaults.string(forKey: Key.pressAndHoldKeyIdentifier.rawValue) ?? PressAndHoldConfiguration.defaults.key.rawValue }
        set { defaults.set(newValue, forKey: Key.pressAndHoldKeyIdentifier.rawValue) }
    }

    static var pressAndHoldMode: String {
        get { defaults.string(forKey: Key.pressAndHoldMode.rawValue) ?? PressAndHoldConfiguration.defaults.mode.rawValue }
        set { defaults.set(newValue, forKey: Key.pressAndHoldMode.rawValue) }
    }

    static var autoBoostMicrophoneVolume: Bool {
        get { defaults.bool(forKey: Key.autoBoostMicrophoneVolume.rawValue) }
        set { defaults.set(newValue, forKey: Key.autoBoostMicrophoneVolume.rawValue) }
    }

    // MARK: - Visual Settings

    static var waveformStyle: WaveformStyle {
        get {
            guard let rawValue = defaults.string(forKey: Key.waveformStyle.rawValue),
                  let style = WaveformStyle(rawValue: rawValue) else {
                return .classic
            }
            return style
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.waveformStyle.rawValue)
        }
    }

    static var visualIntensity: VisualIntensity {
        get {
            guard let rawValue = defaults.string(forKey: Key.visualIntensity.rawValue),
                  let intensity = VisualIntensity(rawValue: rawValue) else {
                return .balanced
            }
            return intensity
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.visualIntensity.rawValue)
        }
    }

    static var menuBarIconSize: Double? {
        get { defaults.object(forKey: Key.menuBarIconSize.rawValue) as? Double }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Key.menuBarIconSize.rawValue)
            } else {
                defaults.removeObject(forKey: Key.menuBarIconSize.rawValue)
            }
        }
    }

    // MARK: - Behavior Settings

    static var enableSmartPaste: Bool {
        get {
            if defaults.object(forKey: Key.enableSmartPaste.rawValue) == nil {
                return true  // Default to true
            }
            return defaults.bool(forKey: Key.enableSmartPaste.rawValue)
        }
        set { defaults.set(newValue, forKey: Key.enableSmartPaste.rawValue) }
    }

    static var playCompletionSound: Bool {
        get {
            if defaults.object(forKey: Key.playCompletionSound.rawValue) == nil {
                return true  // Default to true
            }
            return defaults.bool(forKey: Key.playCompletionSound.rawValue)
        }
        set { defaults.set(newValue, forKey: Key.playCompletionSound.rawValue) }
    }

    static var startAtLogin: Bool {
        get {
            if defaults.object(forKey: Key.startAtLogin.rawValue) == nil {
                return true  // Default to true
            }
            return defaults.bool(forKey: Key.startAtLogin.rawValue)
        }
        set { defaults.set(newValue, forKey: Key.startAtLogin.rawValue) }
    }

    // MARK: - Data Settings

    static var transcriptionHistoryEnabled: Bool {
        get { defaults.bool(forKey: Key.transcriptionHistoryEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.transcriptionHistoryEnabled.rawValue) }
    }

    static var transcriptionRetentionPeriod: RetentionPeriod {
        get {
            guard let rawValue = defaults.string(forKey: Key.transcriptionRetentionPeriod.rawValue),
                  let period = RetentionPeriod(rawValue: rawValue) else {
                return .oneMonth
            }
            return period
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.transcriptionRetentionPeriod.rawValue)
        }
    }

    static var maxModelStorageGB: Double {
        get { defaults.object(forKey: Key.maxModelStorageGB.rawValue) as? Double ?? 5.0 }
        set { defaults.set(newValue, forKey: Key.maxModelStorageGB.rawValue) }
    }

    // MARK: - Setup State

    static var hasSetupParakeet: Bool {
        get { defaults.bool(forKey: Key.hasSetupParakeet.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasSetupParakeet.rawValue) }
    }

    static var hasSetupLocalLLM: Bool {
        get { defaults.bool(forKey: Key.hasSetupLocalLLM.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasSetupLocalLLM.rawValue) }
    }

    static var hasCompletedWelcome: Bool {
        get { defaults.bool(forKey: Key.hasCompletedWelcome.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasCompletedWelcome.rawValue) }
    }

    static var lastWelcomeVersion: String {
        get { defaults.string(forKey: Key.lastWelcomeVersion.rawValue) ?? "0" }
        set { defaults.set(newValue, forKey: Key.lastWelcomeVersion.rawValue) }
    }

    static var hasShownFirstModelUseHint: Bool {
        get { defaults.bool(forKey: Key.hasShownFirstModelUseHint.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasShownFirstModelUseHint.rawValue) }
    }

    // MARK: - Legacy Keys

    /// Legacy key, prefer using transcriptionProvider instead
    static var useOpenAI: Bool {
        get { defaults.bool(forKey: Key.useOpenAI.rawValue) }
        set { defaults.set(newValue, forKey: Key.useOpenAI.rawValue) }
    }

    // MARK: - Raw Access

    /// For cases where raw key access is needed (e.g., checking if a key exists)
    static func hasValue(for key: Key) -> Bool {
        defaults.object(forKey: key.rawValue) != nil
    }

    /// Remove a value from UserDefaults
    static func removeValue(for key: Key) {
        defaults.removeObject(forKey: key.rawValue)
    }

    /// Reset all app defaults to their default values
    static func resetAll() {
        for key in Key.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
}

// MARK: - CaseIterable for Key

extension AppDefaults.Key: CaseIterable {}
