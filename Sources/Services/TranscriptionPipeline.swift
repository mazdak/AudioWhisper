import Foundation
import os.log

/// Result of running the transcription pipeline.
///
/// Exposes both the final text the UI should display/paste and the
/// `CorrectionOutcome` (when correction was attempted) so callers can surface
/// silent failures to the user — see audit item A4.
internal struct TranscriptionResult {
    /// The text to display / paste. Equal to the corrected text when correction
    /// succeeded, or the raw transcript otherwise (including when correction
    /// was off or failed).
    let text: String
    /// Outcome of the semantic-correction stage. `nil` when correction was
    /// disabled via `TranscriptionPipelineConfig.applySemanticCorrection`.
    let correctionOutcome: CorrectionOutcome?
}

/// Orchestrates the full transcription flow: validate audio → transcribe →
/// semantic correction → emit final text.
///
/// This class handles the high-level flow while delegating actual transcription
/// to `SpeechToTextService`.
@MainActor
internal class TranscriptionPipeline {
    private let speechService: SpeechToTextService
    private let correctionService: SemanticCorrectionService
    private let logger = Logger(subsystem: "com.audiowhisper.app", category: "TranscriptionPipeline")

    init(
        speechService: SpeechToTextService = SpeechToTextService(),
        correctionService: SemanticCorrectionService = SemanticCorrectionService()
    ) {
        self.speechService = speechService
        self.correctionService = correctionService
    }

    // MARK: - Pipeline Execution

    /// Executes the full transcription pipeline with the given configuration.
    /// Stages: (1) audio validation, (2) provider transcription, (3) optional
    /// semantic correction.
    ///
    /// As of audit item B1, this pipeline is the SOLE caller of
    /// `SemanticCorrectionService`. `SpeechToTextService` only returns raw
    /// transcripts. Any caller that needs corrected text must invoke this
    /// method (or one of its convenience wrappers).
    /// - Parameters:
    ///   - audioURL: URL to the audio file to transcribe.
    ///   - config: Configuration for the transcription pipeline.
    /// - Returns: A `TranscriptionResult` containing the final text and the
    ///   correction outcome (when correction was attempted). Callers should
    ///   inspect `correctionOutcome` to surface silent failures to the UI —
    ///   see audit item A4.
    func transcribe(audioURL: URL, config: TranscriptionPipelineConfig) async throws -> TranscriptionResult {
        logger.debug("Starting transcription pipeline with provider: \(config.provider.rawValue)")

        // Step 1: Validate audio file
        let validationResult = await AudioValidator.validateAudioFile(at: audioURL)
        switch validationResult {
        case .valid:
            logger.debug("Audio validation passed")
        case .invalid(let error):
            logger.error("Audio validation failed: \(error.localizedDescription)")
            throw SpeechToTextError.transcriptionFailed(error.localizedDescription)
        }

        // Step 2: Perform transcription
        let rawText = try await performTranscription(audioURL: audioURL, config: config)
        logger.debug("Raw transcription completed: \(rawText.prefix(50))...")

        // Step 3: Apply semantic correction if enabled
        guard config.applySemanticCorrection else {
            return TranscriptionResult(text: rawText, correctionOutcome: nil)
        }

        let outcome = await correctionService.correctWithOutcome(
            text: rawText,
            providerUsed: config.provider,
            sourceAppBundleId: config.sourceAppBundleId
        )
        logger.debug("Semantic correction completed")

        // Guard against an empty/whitespace-only correction overwriting valid
        // raw text. Matches the prior inline safety behaviour from
        // `ContentView+Recording` and `RecordingViewModel`. On `.failed` the
        // outcome's `text` is already the original fallback, so this guard is
        // primarily defensive for the `.applied` case.
        let outcomeText = outcome.text
        let trimmed = outcomeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalText = trimmed.isEmpty ? rawText : outcomeText
        return TranscriptionResult(text: finalText, correctionOutcome: outcome)
    }

    /// Convenience method that transcribes without semantic correction.
    /// Returns just the raw text since correction is not attempted.
    func transcribeRaw(audioURL: URL, provider: TranscriptionProvider, model: WhisperModel? = nil) async throws -> String {
        let config = TranscriptionPipelineConfig(
            provider: provider,
            whisperModel: model,
            applySemanticCorrection: false
        )
        return try await transcribe(audioURL: audioURL, config: config).text
    }

    // MARK: - Private Helpers

    private func performTranscription(audioURL: URL, config: TranscriptionPipelineConfig) async throws -> String {
        switch config.provider {
        case .local:
            guard let model = config.whisperModel else {
                throw SpeechToTextError.transcriptionFailed("Whisper model required for local transcription")
            }
            return try await speechService.transcribeRaw(audioURL: audioURL, provider: .local, model: model)
        case .parakeet:
            return try await speechService.transcribeRaw(audioURL: audioURL, provider: .parakeet)
        }
    }

    // MARK: - Progress Reporting

    /// Represents a step in the transcription pipeline for progress reporting.
    enum PipelineStep: String {
        case validating = "Validating audio..."
        case transcribing = "Transcribing..."
        case correcting = "Applying corrections..."
        case complete = "Complete"
    }

    /// Posts a progress notification for the current pipeline step.
    func postProgress(_ step: PipelineStep) {
        NotificationCenter.default.post(name: .transcriptionProgress, object: step.rawValue)
    }
}
