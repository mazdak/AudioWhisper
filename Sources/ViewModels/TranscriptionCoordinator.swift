import Foundation
import SwiftUI
import os.log

/// Coordinates the transcription pipeline + post-processing tail for the
/// `RecordingViewModel`. Owns the bridge between captured audio and the
/// pipeline: validation → provider → optional semantic correction → history
/// save → metrics → paste-trigger.
///
/// Introduced by audit item A2 to shrink `RecordingViewModel`. The coordinator
/// does not own audio capture or paste-target state; those remain on the view
/// model. Mutations to user-visible UI state (`isProcessing`, `errorMessage`,
/// `showSuccess`, `correctionFailedMessage`, etc.) are written back to the
/// view model via a weak reference so the VM remains the single
/// `@Observable` source of truth that SwiftUI binds to.
@MainActor
final class TranscriptionCoordinator {
    /// Pipeline that orchestrates validation → transcription → semantic
    /// correction. After audit item B1 this is the sole owner of correction
    /// orchestration.
    private let pipeline: TranscriptionPipeline

    /// Weak back-reference to the owning view model. The coordinator is
    /// constructed and stored by the view model so the lifetime is bounded by
    /// the VM. `weak` keeps the cycle broken without requiring manual
    /// teardown.
    weak var viewModel: RecordingViewModel?

    init(pipeline: TranscriptionPipeline) {
        self.pipeline = pipeline
    }

    /// Convenience init that builds a pipeline from the given services so
    /// `RecordingViewModel` can construct a default coordinator inline.
    convenience init(
        speechService: SpeechToTextService,
        correctionService: SemanticCorrectionService
    ) {
        self.init(pipeline: TranscriptionPipeline(
            speechService: speechService,
            correctionService: correctionService
        ))
    }

    // MARK: - Pipeline Entry Point

    /// Runs the full pipeline for `audioURL` and returns the result. Pure
    /// pass-through to `TranscriptionPipeline` — kept on the coordinator so
    /// callers don't reach across into the pipeline directly.
    func runTranscription(
        audioURL: URL,
        config: TranscriptionPipelineConfig
    ) async throws -> TranscriptionResult {
        try await pipeline.transcribe(audioURL: audioURL, config: config)
    }

    // MARK: - Shared Transcription Tail (audit item C1)

    /// Common tail run after a successful transcription, regardless of whether
    /// the audio came from a live recording or an imported file.
    ///
    /// Order of operations preserved from the prior duplicated branches:
    /// 1. Copy `text` to the clipboard.
    /// 2. Save a `TranscriptionRecord` to history if enabled.
    /// 3. Record session metrics + per-source usage.
    /// 4. Clear `transcriptionStartTime`.
    /// 5. Show the success UI / chime / schedule smart paste.
    /// 6. Advance the first-model-use hint flag if applicable.
    ///
    /// `isProcessing` is reset inside `RecordingViewModel.showConfirmationAndPaste(_:)`
    /// to match the prior behaviour where the success UI appears in the same tick.
    func finishTranscription(
        text: String,
        correctionOutcome: CorrectionOutcome? = nil,
        source: TranscriptionSource,
        transcriptionProvider: TranscriptionProvider,
        selectedWhisperModel: WhisperModel,
        shouldHintThisRun: Bool,
        setHintShown: @escaping () -> Void
    ) async {
        guard let viewModel else { return }

        let wordCount = UsageMetricsStore.estimatedWordCount(for: text)
        let characterCount = text.count

        PasteManager.copyToClipboard(text)

        if DataManager.shared.isHistoryEnabled {
            let modelUsed: String? = (transcriptionProvider == .local)
                ? selectedWhisperModel.rawValue
                : nil
            let sourceInfo = viewModel.currentSourceAppInfo()
            let record = TranscriptionRecord(
                text: text,
                provider: transcriptionProvider,
                duration: source.duration,
                modelUsed: modelUsed,
                wordCount: wordCount,
                characterCount: characterCount,
                sourceAppBundleId: sourceInfo.bundleIdentifier,
                sourceAppName: sourceInfo.displayName,
                sourceAppIconData: sourceInfo.iconData
            )
            await DataManager.shared.saveTranscriptionQuietly(record)
        }

        UsageMetricsStore.shared.recordSession(
            duration: source.duration,
            wordCount: wordCount,
            characterCount: characterCount
        )
        recordSourceUsage(words: wordCount, characters: characterCount)
        viewModel.transcriptionStartTime = nil

        // Surface silent correction failures to the UI (audit item A4). The
        // raw transcript is still copied/pasted via showConfirmationAndPaste;
        // this just shows a brief warning so the user knows correction was
        // attempted but didn't apply.
        if case .failed = correctionOutcome {
            presentCorrectionFailure()
        }

        viewModel.showConfirmationAndPaste(text: text)

        if shouldHintThisRun {
            setHintShown()
            viewModel.showFirstModelUseHint = false
        }
    }

    /// Sets `correctionFailedMessage` on the view model and schedules an
    /// auto-clear. Matches the existing success-toast pattern (delay then
    /// clear).
    private func presentCorrectionFailure() {
        viewModel?.correctionFailedMessage = "Correction failed; raw transcript copied"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.viewModel?.correctionFailedMessage = nil
        }
    }

    // MARK: - Error Handling

    /// Public-facing error handler used by both VM `stopAndProcess` and the
    /// ContentView file/live entry points. Routes "model not downloaded"
    /// errors to a dashboard presenter via `presentDashboard`; all other
    /// errors set `errorMessage` / `showError` on the view model.
    ///
    /// `presentDashboard` is a closure so the ContentView can route through
    /// `WindowCoordinator.presentDashboard(reason:)` while the VM's own
    /// `stopAndProcess` falls back to `DashboardWindowManager.shared`.
    func handleTranscriptionError(
        _ error: Error,
        source: TranscriptionSource,
        transcriptionProvider: TranscriptionProvider,
        shouldHintThisRun: Bool,
        setHintShown: @escaping () -> Void,
        presentDashboard: ((String) -> Void)? = nil
    ) {
        guard let viewModel else { return }

        // Default to opening the dashboard via the shared manager when the
        // caller didn't provide its own presenter. Inlined here so the default
        // parameter doesn't need to capture a `@MainActor`-isolated symbol.
        let present = presentDashboard ?? { _ in
            DashboardWindowManager.shared.showDashboardWindow()
        }

        if case let SpeechToTextError.localTranscriptionFailed(inner) = error,
           let lwError = inner as? LocalWhisperError,
           lwError == .modelNotDownloaded {
            viewModel.errorMessage = "Local Whisper model not downloaded. Opening Settings…"
            viewModel.showError = true
            viewModel.markProcessingFinished()
            viewModel.transcriptionStartTime = nil
            present(source.dashboardReason(for: transcriptionProvider))
        } else if let pe = error as? ParakeetError, pe == .modelNotReady {
            viewModel.errorMessage = "Parakeet model not downloaded. Opening Settings…"
            viewModel.showError = true
            viewModel.markProcessingFinished()
            viewModel.transcriptionStartTime = nil
            present(source.dashboardReason(for: transcriptionProvider))
        } else {
            viewModel.errorMessage = error.localizedDescription
            viewModel.showError = true
            viewModel.markProcessingFinished()
            viewModel.transcriptionStartTime = nil
        }

        if shouldHintThisRun {
            setHintShown()
            viewModel.showFirstModelUseHint = false
        }
    }

    // MARK: - Private Helpers

    private func recordSourceUsage(words: Int, characters: Int) {
        guard words > 0, let viewModel else { return }
        let info = viewModel.currentSourceAppInfo()
        SourceUsageStore.shared.recordUsage(for: info, words: words, characters: characters)
    }
}
