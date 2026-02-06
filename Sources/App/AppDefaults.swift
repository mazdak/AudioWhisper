import Foundation

/// Centralized defaults so "fresh install" behavior is deterministic and consistent across the app.
///
/// Notes:
/// - We use `register(defaults:)` (registration domain) rather than eagerly writing values, so we don't
///   accidentally clobber user preferences or treat a first-run as "already configured".
/// - AppStorage initial values across the app should match these constants.
internal enum AppDefaults {
    internal enum Keys {
        static let transcriptionProvider = "transcriptionProvider"
        static let selectedWhisperModel = "selectedWhisperModel"
        static let selectedParakeetModel = "selectedParakeetModel"

        static let semanticCorrectionMode = "semanticCorrectionMode"
        static let semanticCorrectionModelRepo = "semanticCorrectionModelRepo"

        static let startAtLogin = "startAtLogin"
        static let playCompletionSound = "playCompletionSound"
        static let transcriptionHistoryEnabled = "transcriptionHistoryEnabled"
        static let transcriptionRetentionPeriod = "transcriptionRetentionPeriod"
        static let maxModelStorageGB = "maxModelStorageGB"
        static let enableSmartPaste = "enableSmartPaste"
        static let immediateRecording = "immediateRecording"
        static let globalHotkey = "globalHotkey"

        static let pressAndHoldEnabled = "pressAndHoldEnabled"
        static let pressAndHoldKeyIdentifier = "pressAndHoldKeyIdentifier"
        static let pressAndHoldMode = "pressAndHoldMode"

        static let hasCompletedWelcome = "hasCompletedWelcome"
        static let lastWelcomeVersion = "lastWelcomeVersion"

        static let hasSetupLocalLLM = "hasSetupLocalLLM"
        static let hasSetupParakeet = "hasSetupParakeet"
    }

    // Bump when the welcome flow/content needs to be re-shown for existing users.
    internal static let currentWelcomeVersion = "1.1"

    // Chosen defaults.
    internal static let defaultTranscriptionProvider: TranscriptionProvider = .local
    internal static let defaultWhisperModel: WhisperModel = .base
    internal static let defaultParakeetModel: ParakeetModel = .v3Multilingual
    internal static let defaultSemanticCorrectionMode: SemanticCorrectionMode = .off
    internal static let defaultSemanticCorrectionModelRepo: String = "mlx-community/Qwen3-1.7B-4bit"

    internal static func register() {
        UserDefaults.standard.register(defaults: [
            Keys.transcriptionProvider: defaultTranscriptionProvider.rawValue,
            Keys.selectedWhisperModel: defaultWhisperModel.rawValue,
            Keys.selectedParakeetModel: defaultParakeetModel.rawValue,

            Keys.semanticCorrectionMode: defaultSemanticCorrectionMode.rawValue,
            Keys.semanticCorrectionModelRepo: defaultSemanticCorrectionModelRepo,

            Keys.startAtLogin: true,
            Keys.playCompletionSound: true,
            Keys.transcriptionHistoryEnabled: false,
            Keys.transcriptionRetentionPeriod: RetentionPeriod.oneMonth.rawValue,
            Keys.maxModelStorageGB: 5.0,
            Keys.enableSmartPaste: false,
            Keys.immediateRecording: false,
            Keys.globalHotkey: "⌘⇧Space",

            Keys.pressAndHoldEnabled: PressAndHoldConfiguration.defaults.enabled,
            Keys.pressAndHoldKeyIdentifier: PressAndHoldConfiguration.defaults.key.rawValue,
            Keys.pressAndHoldMode: PressAndHoldConfiguration.defaults.mode.rawValue,

            Keys.hasCompletedWelcome: false,
            Keys.lastWelcomeVersion: "0",

            Keys.hasSetupLocalLLM: false,
            Keys.hasSetupParakeet: false
        ])
    }
}

