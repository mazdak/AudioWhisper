import Foundation
import os.log
import Observation

internal enum SpeechToTextError: Error, LocalizedError {
    case invalidURL
    case transcriptionFailed(String)
    case localTranscriptionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return LocalizedStrings.Errors.invalidAudioFile
        case .transcriptionFailed(let message):
            return LocalizedStrings.Errors.transcriptionFailed
                .replacingOccurrences(of: "%@", with: message)
        case .localTranscriptionFailed(let error):
            return LocalizedStrings.Errors.localTranscriptionFailed
                .replacingOccurrences(of: "%@", with: error.localizedDescription)
        }
    }
}

/// Routes a transcription request to the correct provider (OpenAI, Gemini,
/// WhisperKit, Parakeet) based on user settings.
@Observable
internal class SpeechToTextService {
    // Use shared singleton to avoid multiple WhisperKit caches
    private let localWhisperService = LocalWhisperService.shared
    private let parakeetService = ParakeetService.shared
    private let correctionService = SemanticCorrectionService()

    init(keychainService: KeychainServiceProtocol = KeychainService.shared) {
        // keychainService parameter kept for API compatibility but no longer used
    }

    /// Runs `AudioValidator` on `url` and surfaces any failure as
    /// `SpeechToTextError.transcriptionFailed(...)`. Returns the URL unchanged
    /// so callers can chain. Centralising the validation here ensures both
    /// `transcribe(audioURL:provider:model:)` and `transcribeRaw(...)` apply the
    /// same checks even if `AudioValidator` evolves.
    @discardableResult
    private func validatedAudioURL(_ url: URL) async throws -> URL {
        let validationResult = await AudioValidator.validateAudioFile(at: url)
        switch validationResult {
        case .valid:
            return url
        case .invalid(let error):
            throw SpeechToTextError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Raw transcription without semantic correction.
    /// Validates the audio file then delegates to the selected provider.
    /// Throws `SpeechToTextError` on validation or transcription failure.
    /// Unlike `transcribe(_:)`, this returns the provider's raw output with no post-processing.
    func transcribeRaw(audioURL: URL, provider: TranscriptionProvider, model: WhisperModel? = nil) async throws -> String {
        let validated = try await validatedAudioURL(audioURL)
        switch provider {
        case .local:
            guard let model = model else {
                throw SpeechToTextError.transcriptionFailed("Whisper model required for local transcription")
            }
            return try await transcribeWithLocal(audioURL: validated, model: model)
        case .parakeet:
            return try await transcribeWithParakeet(audioURL: validated)
        }
    }

    /// Convenience method that auto-selects provider based on UserDefaults.
    /// Defaults to Parakeet on Apple Silicon, otherwise Local Whisper.
    func transcribe(audioURL: URL) async throws -> String {
        let provider: TranscriptionProvider = Arch.isAppleSilicon ? .parakeet : .local
        return try await transcribe(audioURL: audioURL, provider: provider, model: nil)
    }

    /// Transcribes an audio file and applies semantic correction inline.
    /// Throws `SpeechToTextError` on validation or transcription failure.
    /// The returned string is the corrected transcript; use `transcribeRaw(_:)` for the
    /// uncorrected output. Note: correction is applied here today; audit item B1 plans
    /// to consolidate correction in `TranscriptionPipeline` instead.
    func transcribe(audioURL: URL, provider: TranscriptionProvider, model: WhisperModel? = nil) async throws -> String {
        let validated = try await validatedAudioURL(audioURL)

        switch provider {
        case .local:
            guard let model = model else {
                throw SpeechToTextError.transcriptionFailed("Whisper model required for local transcription")
            }
            let text = try await transcribeWithLocal(audioURL: validated, model: model)
            return await correctionService.correct(text: text, providerUsed: .local)
        case .parakeet:
            let text = try await transcribeWithParakeet(audioURL: validated)
            return await correctionService.correct(text: text, providerUsed: .parakeet)
        }
    }

    /// Delegates to `LocalWhisperService` (WhisperKit / CoreML).
    /// Correction is currently applied by the caller in `transcribe(_:)`; audit item B1
    /// tracks moving that into `TranscriptionPipeline`.
    private func transcribeWithLocal(audioURL: URL, model: WhisperModel) async throws -> String {
        do {
            let text = try await localWhisperService.transcribe(audioFileURL: audioURL, model: model) { progress in
                NotificationCenter.default.post(name: .transcriptionProgress, object: progress)
            }
            return Self.cleanTranscriptionText(text)
        } catch {
            throw SpeechToTextError.localTranscriptionFailed(error)
        }
    }

    /// Delegates to `ParakeetService` (Parakeet-MLX, Apple-Silicon only) and warms up
    /// the MLX correction daemon in parallel when correction is enabled.
    /// Correction is currently applied by the caller in `transcribe(_:)`; audit item B1
    /// tracks moving that into `TranscriptionPipeline`.
    private func transcribeWithParakeet(audioURL: URL) async throws -> String {
        guard Arch.isAppleSilicon else {
            throw SpeechToTextError.transcriptionFailed("Parakeet requires an Apple Silicon Mac.")
        }
        let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
        let semanticCorrectionMode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
        let shouldWarmup = semanticCorrectionMode != .off
        // Ensure managed Python environment with uv
        let pyURL = try UvBootstrap.ensureVenv(userPython: nil)
        let pythonPath = pyURL.path
        do {
            if shouldWarmup {
                let modelRepo = UserDefaults.standard.string(forKey: "semanticCorrectionModelRepo") ?? "mlx-community/Llama-3.2-1B-Instruct-4bit"
                async let warmupTask: Void = MLDaemonManager.shared.warmup(type: "mlx", repo: modelRepo)
                async let transcription = parakeetService.transcribe(audioFileURL: audioURL, pythonPath: pythonPath)
                let (text, _) = try await (transcription, warmupTask)
                return Self.cleanTranscriptionText(text)
            } else {
                let text = try await parakeetService.transcribe(audioFileURL: audioURL, pythonPath: pythonPath)
                return Self.cleanTranscriptionText(text)
            }
        } catch {
            // Pass through model-not-ready distinctly so UI can redirect to Settings
            if let pe = error as? ParakeetError, pe == .modelNotReady {
                throw pe
            }
            throw SpeechToTextError.transcriptionFailed("Parakeet error: \(error.localizedDescription)")
        }
    }

    // MARK: - Text Cleaning

    /// Cleans transcription text by removing common markers and artifacts
    static func cleanTranscriptionText(_ text: String) -> String {
        var cleanedText = text

        // Remove bracketed markers iteratively to handle nested cases
        var previousLength = 0
        while cleanedText.count != previousLength {
            previousLength = cleanedText.count
            cleanedText = cleanedText.replacingOccurrences(
                of: "\\[[^\\[\\]]*\\]",
                with: "",
                options: .regularExpression
            )
        }

        // Remove parenthetical markers iteratively to handle nested cases
        previousLength = 0
        while cleanedText.count != previousLength {
            previousLength = cleanedText.count
            cleanedText = cleanedText.replacingOccurrences(
                of: "\\([^\\(\\)]*\\)",
                with: "",
                options: .regularExpression
            )
        }

        // Clean up whitespace and return
        return cleanedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

}
