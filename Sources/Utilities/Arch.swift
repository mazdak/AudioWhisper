import Foundation

/// CPU architecture detection used to gate Apple-Silicon-only features
/// (Parakeet-MLX transcription and local MLX semantic correction).
/// Intel Macs fall back to OpenAI/Gemini/WhisperKit-CoreML paths only.
internal enum Arch {
    static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
}

