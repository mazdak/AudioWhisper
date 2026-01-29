import Foundation

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
