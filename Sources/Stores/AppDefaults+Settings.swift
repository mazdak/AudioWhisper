import Foundation

/// User-facing settings: provider/model selections, hotkey, microphone,
/// smart paste, completion sound, start at login, data retention.
extension AppDefaults {

    // MARK: - Transcription Settings

    static var transcriptionProvider: TranscriptionProvider {
        get {
            guard let rawValue = defaults.string(forKey: Key.transcriptionProvider.rawValue),
                  let provider = TranscriptionProvider(rawValue: rawValue) else {
                return .parakeet
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
}
