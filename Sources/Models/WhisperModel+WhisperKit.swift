import Foundation

internal extension WhisperModel {
    var whisperKitModelName: String {
        switch self {
        case .tiny:
            return "openai_whisper-tiny"
        case .base:
            return "openai_whisper-base"
        case .small:
            return "openai_whisper-small"
        case .largeTurbo:
            return "openai_whisper-large-v3_turbo"
        }
    }
}

