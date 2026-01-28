import Foundation
import os.log

/// Orchestrates the transcription workflow including validation, provider selection,
/// transcription, and post-processing correction.
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
    /// - Parameters:
    ///   - audioURL: URL to the audio file to transcribe.
    ///   - config: Configuration for the transcription pipeline.
    /// - Returns: The transcribed (and optionally corrected) text.
    func transcribe(audioURL: URL, config: TranscriptionPipelineConfig) async throws -> String {
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
            return rawText
        }

        let correctedText = await correctionService.correct(
            text: rawText,
            providerUsed: config.provider,
            sourceAppBundleId: config.sourceAppBundleId
        )
        logger.debug("Semantic correction completed")

        return correctedText
    }

    /// Convenience method that transcribes without semantic correction.
    func transcribeRaw(audioURL: URL, provider: TranscriptionProvider, model: WhisperModel? = nil) async throws -> String {
        let config = TranscriptionPipelineConfig(
            provider: provider,
            whisperModel: model,
            applySemanticCorrection: false
        )
        return try await transcribe(audioURL: audioURL, config: config)
    }

    // MARK: - Private Helpers

    private func performTranscription(audioURL: URL, config: TranscriptionPipelineConfig) async throws -> String {
        switch config.provider {
        case .openai, .gemini:
            return try await speechService.transcribeRaw(audioURL: audioURL, provider: config.provider)
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
