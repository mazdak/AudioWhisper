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

                let finalText = try await runTranscriptionPipeline(audioURL: audioURL)
                try Task.checkCancellation()

                await viewModel.finishTranscription(
                    text: finalText,
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

                let finalText = try await runTranscriptionPipeline(audioURL: audioURL)
                try Task.checkCancellation()

                await viewModel.finishTranscription(
                    text: finalText,
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
    private func runTranscriptionPipeline(audioURL: URL) async throws -> String {
        let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
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

        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
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

            do {
                try Task.checkCancellation()

                let text: String
                if transcriptionProvider == .local {
                    text = try await viewModel.speechService.transcribeRaw(audioURL: audioURL, provider: transcriptionProvider, model: selectedWhisperModel)
                } else {
                    text = try await viewModel.speechService.transcribeRaw(audioURL: audioURL, provider: transcriptionProvider)
                }

                try Task.checkCancellation()

                await MainActor.run { PasteManager.copyToClipboard(text) }

                let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
                let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
                let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
                let shouldAwaitSemanticForPaste = enableSmartPaste && (mode == .localMLX)

                if shouldAwaitSemanticForPaste {
                    await MainActor.run {
                        viewModel.awaitingSemanticPaste = true
                        viewModel.progressMessage = "Semantic correction..."
                    }
                    // Capture all values before async work to avoid implicit self capture
                    // Use regular Task instead of Task.detached so it can be cancelled
                    let capturedBundleId: String? = await MainActor.run { currentSourceAppInfo().bundleIdentifier }
                    let capturedModelUsed: String? = await MainActor.run { (transcriptionProvider == .local) ? selectedWhisperModel.rawValue : nil }
                    let capturedSourceInfo: SourceAppInfo = await MainActor.run { currentSourceAppInfo() }
                    let shouldSave2: Bool = await MainActor.run { DataManager.shared.isHistoryEnabled }
                    let capturedSemanticService = viewModel.semanticCorrectionService

                    // Check for cancellation before starting semantic correction
                    try Task.checkCancellation()

                    let corrected = await capturedSemanticService.correct(text: text, providerUsed: transcriptionProvider, sourceAppBundleId: capturedBundleId)

                    // Check for cancellation after semantic correction
                    try Task.checkCancellation()

                    let wordCount = UsageMetricsStore.estimatedWordCount(for: corrected)
                    let characterCount = corrected.count
                    if shouldSave2 {
                        let record = TranscriptionRecord(
                            text: corrected,
                            provider: transcriptionProvider,
                            duration: nil,
                            modelUsed: capturedModelUsed,
                            wordCount: wordCount,
                            characterCount: characterCount,
                            sourceAppBundleId: capturedSourceInfo.bundleIdentifier,
                            sourceAppName: capturedSourceInfo.displayName,
                            sourceAppIconData: capturedSourceInfo.iconData
                        )
                        await DataManager.shared.saveTranscriptionQuietly(record)
                    }
                    await MainActor.run {
                        PasteManager.copyToClipboard(corrected)
                        viewModel.transcriptionStartTime = nil
                        isProcessing = false
                        showConfirmationAndPaste(text: corrected)
                        if viewModel.awaitingSemanticPaste {
                            performUserTriggeredPaste()
                            viewModel.awaitingSemanticPaste = false
                        }
                    }
                } else {
                    // Only apply semantic correction if mode is not off
                    let finalText: String
                    if mode != .off {
                        let capturedBundleId2: String? = await MainActor.run { currentSourceAppInfo().bundleIdentifier }
                        finalText = await viewModel.semanticCorrectionService.correct(text: text, providerUsed: transcriptionProvider, sourceAppBundleId: capturedBundleId2)
                    } else {
                        finalText = text  // Skip semantic correction entirely when off
                    }

                    let wordCount = UsageMetricsStore.estimatedWordCount(for: finalText)
                    let characterCount = finalText.count

                    await MainActor.run { PasteManager.copyToClipboard(finalText) }

                    let shouldSave3: Bool = await MainActor.run { DataManager.shared.isHistoryEnabled }
                    if shouldSave3 {
                        let modelUsed: String? = await MainActor.run { (transcriptionProvider == .local) ? self.selectedWhisperModel.rawValue : nil }
                        let sourceInfo: SourceAppInfo = await MainActor.run { self.currentSourceAppInfo() }
                        let record = TranscriptionRecord(
                            text: finalText,
                            provider: transcriptionProvider,
                            duration: nil,
                            modelUsed: modelUsed,
                            wordCount: wordCount,
                            characterCount: characterCount,
                            sourceAppBundleId: sourceInfo.bundleIdentifier,
                            sourceAppName: sourceInfo.displayName,
                            sourceAppIconData: sourceInfo.iconData
                        )
                        await DataManager.shared.saveTranscriptionQuietly(record)
                    }

                    await MainActor.run {
                        viewModel.transcriptionStartTime = nil
                        isProcessing = false  // Reset flag when smart paste disabled
                        showConfirmationAndPaste(text: finalText)
                    }
                }
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
        let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
        if mode == .localMLX { return true }
        return false
    }
}
