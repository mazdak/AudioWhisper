import SwiftUI
import AppKit
import AVFoundation
import os.log

internal extension ContentView {
    func startRecording() {
        if permissionManager.microphonePermissionState != .granted {
            permissionManager.requestPermissionWithEducation()
            return
        }

        viewModel.lastAudioURL = nil

        let success = audioRecorder.startRecording()
        if !success {
            viewModel.errorMessage = LocalizedStrings.Errors.failedToStartRecording
            viewModel.showError = true
        }
    }

    func stopAndProcess() {
        processingTask?.cancel()
        NotificationCenter.default.post(name: .recordingStopped, object: nil)

        let shouldHintThisRun = !hasShownFirstModelUseHint && isLocalModelInvocationPlanned()
        if shouldHintThisRun { viewModel.showFirstModelUseHint = true }

        // Set isProcessing before creating Task to prevent race condition
        isProcessing = true
        viewModel.transcriptionStartTime = Date()

        processingTask = Task {
            viewModel.progressMessage = "Preparing audio..."

            // Capture a source value once duration is known so success and
            // error tails share the same dashboard reason/duration metadata.
            var source: TranscriptionSource = .liveRecording(sessionDuration: 0)

            do {
                try Task.checkCancellation()
                guard let audioURL = audioRecorder.stopRecording() else {
                    throw NSError(domain: "AudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: LocalizedStrings.Errors.failedToGetRecordingURL])
                }
                let sessionDuration = audioRecorder.lastRecordingDuration
                source = .liveRecording(sessionDuration: sessionDuration)

                guard !audioURL.path.isEmpty else {
                    throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: LocalizedStrings.Errors.recordingURLEmpty])
                }

                viewModel.lastAudioURL = audioURL
                try Task.checkCancellation()

                let pipelineResult = try await runTranscriptionPipeline(audioURL: audioURL)
                try Task.checkCancellation()

                await viewModel.finishTranscription(
                    text: pipelineResult.text,
                    correctionOutcome: pipelineResult.correctionOutcome,
                    source: source,
                    transcriptionProvider: transcriptionProvider,
                    selectedWhisperModel: selectedWhisperModel,
                    shouldHintThisRun: shouldHintThisRun,
                    setHintShown: { hasShownFirstModelUseHint = true }
                )
            } catch is CancellationError {
                await MainActor.run {
                    isProcessing = false
                    viewModel.transcriptionStartTime = nil
                    if shouldHintThisRun { hasShownFirstModelUseHint = true; viewModel.showFirstModelUseHint = false }
                }
            } catch {
                await handleTranscriptionFailure(error, source: source, shouldHintThisRun: shouldHintThisRun)
            }
        }
    }

    func transcribeExternalAudioFile(_ audioURL: URL) {
        processingTask?.cancel()

        let shouldHintThisRun = !hasShownFirstModelUseHint && isLocalModelInvocationPlanned()
        if shouldHintThisRun { viewModel.showFirstModelUseHint = true }

        // Set isProcessing before creating Task to prevent race condition
        isProcessing = true
        viewModel.transcriptionStartTime = Date()

        processingTask = Task {
            viewModel.progressMessage = "Transcribing file..."

            // Compute the source once duration is loaded so success and error
            // tails share the same dashboard reason / metrics duration.
            var source: TranscriptionSource = .importedFile(audioURL, estimatedDuration: 0)

            do {
                try Task.checkCancellation()
                viewModel.lastAudioURL = audioURL
                try Task.checkCancellation()

                // Load real file duration from AVAsset (more accurate than file size).
                let asset = AVAsset(url: audioURL)
                let estimatedDuration: TimeInterval
                if #available(macOS 12.0, *) {
                    estimatedDuration = (try? await asset.load(.duration).seconds) ?? 0
                } else {
                    estimatedDuration = asset.duration.seconds
                }
                source = .importedFile(audioURL, estimatedDuration: estimatedDuration)

                let pipelineResult = try await runTranscriptionPipeline(audioURL: audioURL)
                try Task.checkCancellation()

                await viewModel.finishTranscription(
                    text: pipelineResult.text,
                    correctionOutcome: pipelineResult.correctionOutcome,
                    source: source,
                    transcriptionProvider: transcriptionProvider,
                    selectedWhisperModel: selectedWhisperModel,
                    shouldHintThisRun: shouldHintThisRun,
                    setHintShown: { hasShownFirstModelUseHint = true }
                )
            } catch is CancellationError {
                await MainActor.run {
                    isProcessing = false
                    viewModel.transcriptionStartTime = nil
                    if shouldHintThisRun { hasShownFirstModelUseHint = true; viewModel.showFirstModelUseHint = false }
                }
            } catch {
                await handleTranscriptionFailure(error, source: source, shouldHintThisRun: shouldHintThisRun)
            }
        }
    }

    /// Runs the transcription pipeline (validation → provider → optional
    /// semantic correction) for `audioURL` using the view's current provider
    /// and whisper model selection.
    ///
    /// This is the single point where ContentView consults
    /// `TranscriptionPipeline`. After audit item B1 the pipeline is the sole
    /// orchestrator of `SemanticCorrectionService`, so live and file flows
    /// no longer call `SemanticCorrectionService.correct(...)` themselves.
    @MainActor
    private func runTranscriptionPipeline(audioURL: URL) async throws -> TranscriptionResult {
        let mode = AppDefaults.semanticCorrectionMode
        let sourceBundleId: String? = currentSourceAppInfo().bundleIdentifier

        let pipeline = TranscriptionPipeline(
            speechService: viewModel.speechService,
            correctionService: viewModel.semanticCorrectionService
        )
        let config = TranscriptionPipelineConfig(
            provider: transcriptionProvider,
            whisperModel: transcriptionProvider == .local ? selectedWhisperModel : nil,
            applySemanticCorrection: mode != .off,
            sourceAppBundleId: sourceBundleId
        )
        if mode != .off {
            viewModel.progressMessage = "Semantic correction..."
        }
        return try await pipeline.transcribe(audioURL: audioURL, config: config)
    }

    /// Shared error tail for both `stopAndProcess()` and
    /// `transcribeExternalAudioFile(_:)`. Delegates to the view model so the
    /// dashboard-redirect behaviour is unified, while routing the dashboard
    /// presentation through this view's `windowCoordinator` so reason tags
    /// surface in `WindowCoordinator` logs.
    ///
    /// `isProcessing` is owned by the view model (`private(set)`) and is reset
    /// inside `handleTranscriptionError` — the ContentView `isProcessing`
    /// accessor is a read-only forwarder, so no extra mirror write is needed.
    @MainActor
    private func handleTranscriptionFailure(_ error: Error, source: TranscriptionSource, shouldHintThisRun: Bool) async {
        viewModel.handleTranscriptionError(
            error,
            source: source,
            transcriptionProvider: transcriptionProvider,
            shouldHintThisRun: shouldHintThisRun,
            setHintShown: { hasShownFirstModelUseHint = true },
            presentDashboard: { reason in
                windowCoordinator.presentDashboard(reason: reason)
            }
        )
    }

    func showConfirmationAndPaste(text: String) {
        Logger.paste.debug("showConfirmationAndPaste called with text length: \(text.count)")
        viewModel.showSuccess = true
        isProcessing = false
        viewModel.soundManager.playCompletionSound()

        let enableSmartPaste = AppDefaults.enableSmartPaste
        Logger.paste.debug("showConfirmationAndPaste: enableSmartPaste = \(enableSmartPaste)")
        if enableSmartPaste {
            Logger.paste.debug("showConfirmationAndPaste: awaitingSemanticPaste = \(viewModel.awaitingSemanticPaste)")
            // Capture flag value at schedule time to prevent race condition (#26 fix)
            let shouldPasteNow = !viewModel.awaitingSemanticPaste
            if shouldPasteNow {
                Logger.paste.debug("showConfirmationAndPaste: scheduling performUserTriggeredPaste")
                // Delay to allow celebration animation to play before hiding window
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    Logger.paste.debug("showConfirmationAndPaste: executing performUserTriggeredPaste")
                    performUserTriggeredPaste()
                }
            } else {
                Logger.paste.debug("showConfirmationAndPaste: skipping paste due to awaitingSemanticPaste")
            }
        } else {
            // Note: ContentView is a struct, so no weak self needed.
            // SwiftUI captures a copy of the struct, and @State properties
            // are backed by heap storage that remains valid.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let recordWindow = NSApp.windows.first { window in
                    window.title == WindowTitles.recording
                }

                let onFadeComplete = {
                    NotificationCenter.default.post(name: .restoreFocusToPreviousApp, object: nil)
                    self.viewModel.showSuccess = false
                }

                if let window = recordWindow {
                    self.fadeOutWindow(window, completion: onFadeComplete)
                } else if let keyWindow = NSApplication.shared.keyWindow {
                    self.fadeOutWindow(keyWindow, completion: onFadeComplete)
                } else {
                    // No window to fade, execute immediately
                    onFadeComplete()
                }
            }
        }
    }

    func retryLastTranscription() {
        guard !isProcessing else { return }

        guard let audioURL = viewModel.lastAudioURL else {
            viewModel.errorMessage = "No audio file available to retry. Please record again."
            viewModel.showError = true
            return
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            viewModel.errorMessage = "Audio file no longer exists. Please record again."
            viewModel.showError = true
            viewModel.lastAudioURL = nil
            return
        }

        processingTask?.cancel()

        // Set isProcessing before creating Task to prevent race condition
        isProcessing = true
        viewModel.transcriptionStartTime = Date()

        processingTask = Task {
            viewModel.progressMessage = "Retrying transcription..."

            // Retry replays an existing live recording, so use `.liveRecording`
            // with a nil session duration to match the prior behaviour where
            // the retry path passed `duration: nil` to history.
            let source: TranscriptionSource = .liveRecording(sessionDuration: nil)

            do {
                try Task.checkCancellation()

                // Audit item B1: route retry through TranscriptionPipeline so
                // it shares the single semantic-correction orchestration path
                // with stopAndProcess and the file-import flow. Previously the
                // retry path copied raw text to the clipboard before correction
                // ran; the pipeline now returns only the final text, so the
                // brief raw-paste window is gone. This is a UX improvement —
                // the target field no longer flashes the uncorrected version.
                let pipelineResult = try await runTranscriptionPipeline(audioURL: audioURL)

                try Task.checkCancellation()

                await viewModel.finishTranscription(
                    text: pipelineResult.text,
                    correctionOutcome: pipelineResult.correctionOutcome,
                    source: source,
                    transcriptionProvider: transcriptionProvider,
                    selectedWhisperModel: selectedWhisperModel,
                    shouldHintThisRun: false,
                    setHintShown: { }
                )
            } catch is CancellationError {
                await MainActor.run {
                    isProcessing = false
                    viewModel.transcriptionStartTime = nil
                    viewModel.awaitingSemanticPaste = false  // Reset on cancellation
                }
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                    isProcessing = false
                    viewModel.transcriptionStartTime = nil
                }
            }
        }
    }

    func showLastAudioFile() {
        guard let audioURL = viewModel.lastAudioURL else {
            viewModel.errorMessage = "No audio file available to show."
            viewModel.showError = true
            return
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            viewModel.errorMessage = "Audio file no longer exists."
            viewModel.showError = true
            viewModel.lastAudioURL = nil
            return
        }

        NSWorkspace.shared.selectFile(audioURL.path, inFileViewerRootedAtPath: audioURL.deletingLastPathComponent().path)
    }

    private func isLocalModelInvocationPlanned() -> Bool {
        if transcriptionProvider == .local || transcriptionProvider == .parakeet { return true }
        if AppDefaults.semanticCorrectionMode == .localMLX { return true }
        return false
    }
}
