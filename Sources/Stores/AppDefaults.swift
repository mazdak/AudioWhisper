import Foundation

/// Centralized, type-safe wrapper for all UserDefaults access in the app.
/// All UserDefaults keys are defined here to prevent typos and provide documentation.
///
/// Accessors are split across concern-specific extension files:
/// - `AppDefaults+Settings.swift` — provider/model/recording/behavior settings
/// - `AppDefaults+FeatureFlags.swift` — one-time setup state and rollouts
/// - `AppDefaults+Visual.swift` — UI/visual state (waveform, intensity, icon)
///
/// Note: `UserDefaults` is thread-safe (see Apple docs), so `AppDefaults` is
/// not actor-isolated. This lets non-`@MainActor` services (audio, MLX, etc.)
/// read settings without hops to the main actor.
enum AppDefaults {
    /// Backing store. Effectively private (only used by `AppDefaults` extensions),
    /// but `internal` so extensions in other files can reach it.
    static let defaults: UserDefaults = .standard

    // MARK: - Keys

    /// All UserDefaults keys used in the app, centralized for discoverability and safety.
    enum Key: String {
        // Transcription
        case transcriptionProvider
        case selectedWhisperModel
        case selectedParakeetModel

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
        case hasCleanedWindowState
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

    /// Registers built-in default values for keys that should default to a non-nil value
    /// when the user has never set them. Called once at app launch.
    static func registerDefaults() {
        defaults.register(defaults: [
            Key.enableSmartPaste.rawValue: true,
            Key.immediateRecording.rawValue: true,
            Key.startAtLogin.rawValue: true,
            Key.playCompletionSound.rawValue: true
        ])
    }
}

// MARK: - CaseIterable for Key

extension AppDefaults.Key: CaseIterable {}
