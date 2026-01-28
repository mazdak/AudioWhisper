import Foundation

// MARK: - OpenAI Response Models

internal struct WhisperResponse: Codable {
    let text: String
}

// MARK: - Gemini Response Models

internal struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

internal struct GeminiCandidate: Codable {
    let content: GeminiContent
}

internal struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

internal struct GeminiPart: Codable {
    let text: String?
}

internal struct GeminiFileResponse: Codable {
    let file: GeminiFile
}

internal struct GeminiFile: Codable {
    let uri: String
    let name: String
}

// MARK: - Transcription Pipeline Configuration

/// Configuration for the transcription pipeline.
internal struct TranscriptionPipelineConfig {
    let provider: TranscriptionProvider
    let whisperModel: WhisperModel?
    let applySemanticCorrection: Bool
    let sourceAppBundleId: String?

    init(
        provider: TranscriptionProvider,
        whisperModel: WhisperModel? = nil,
        applySemanticCorrection: Bool = true,
        sourceAppBundleId: String? = nil
    ) {
        self.provider = provider
        self.whisperModel = whisperModel
        self.applySemanticCorrection = applySemanticCorrection
        self.sourceAppBundleId = sourceAppBundleId
    }
}

// MARK: - Audio MIME Types

internal enum AudioMimeType {
    /// Returns the MIME type for a given audio file URL based on extension.
    static func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "m4a", "mp4", "aac": return "audio/mp4"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "aiff", "aif": return "audio/aiff"
        case "caf": return "audio/x-caf"
        case "flac": return "audio/flac"
        case "ogg": return "audio/ogg"
        default: return "audio/mp4"
        }
    }
}
