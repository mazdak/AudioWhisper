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
        
        lastAudioURL = nil
        
        let success = audioRecorder.startRecording()
        if !success {
            errorMessage = LocalizedStrings.Errors.failedToStartRecording
            showError = true
        }
    }
    
    func stopAndProcess() {
        processingTask?.cancel()
        NotificationCenter.default.post(name: .recordingStopped, object: nil)

        let shouldHintThisRun = !hasShownFirstModelUseHint && isLocalModelInvocationPlanned()
        if shouldHintThisRun { showFirstModelUseHint = true }

        // Set isProcessing before creating Task to prevent race condition
        isProcessing = true
        transcriptionStartTime = Date()

        processingTask = Task {
            progressMessage = "Preparing audio..."
            
            do {
                try Task.checkCancellation()
                guard let audioURL = audioRecorder.stopRecording() else {
                    throw NSError(domain: "AudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: LocalizedStrings.Errors.failedToGetRecordingURL])
                }
                let sessionDuration = audioRecorder.lastRecordingDuration
                
                guard !audioURL.path.isEmpty else {
                    throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: LocalizedStrings.Errors.recordingURLEmpty])
                }
                
                lastAudioURL = audioURL
                try Task.checkCancellation()
                
                let text: String
                if transcriptionProvider == .local {
                    text = try await speechService.transcribeRaw(audioURL: audioURL, provider: transcriptionProvider, model: selectedWhisperModel)
                } else {
                    text = try await speechService.transcribeRaw(audioURL: audioURL, provider: transcriptionProvider)
                }
                
                try Task.checkCancellation()
                
                let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
                let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
                var finalText = text
                let sourceBundleId: String? = await MainActor.run { currentSourceAppInfo().bundleIdentifier }
                if mode != .off {
                    await MainActor.run { progressMessage = "Semantic correction..." }
                    let corrected = await semanticCorrectionService.correct(text: text, providerUsed: transcriptionProvider, sourceAppBundleId: sourceBundleId)
                    let trimmed = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        finalText = corrected
                    }
                }
                let wordCount = UsageMetricsStore.estimatedWordCount(for: finalText)
                let characterCount = finalText.count

                await MainActor.run { PasteManager.copyToClipboard(finalText) }
                let shouldSave: Bool = await MainActor.run { DataManager.shared.isHistoryEnabled }
                if shouldSave {
                    let modelUsed: String? = await MainActor.run { (transcriptionProvider == .local) ? self.selectedWhisperModel.rawValue : nil }
                    let sourceInfo: SourceAppInfo = await MainActor.run { currentSourceAppInfo() }
                    let record = TranscriptionRecord(
                        text: finalText,
                        provider: transcriptionProvider,
                        duration: sessionDuration,
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
                    UsageMetricsStore.shared.recordSession(
                        duration: sessionDuration,
                        wordCount: wordCount,
                        characterCount: characterCount
                    )
                    recordSourceUsage(words: wordCount, characters: characterCount)
                    transcriptionStartTime = nil
                    showConfirmationAndPaste(text: finalText)
                    if shouldHintThisRun { hasShownFirstModelUseHint = true; showFirstModelUseHint = false }
                }
            } catch is CancellationError {
                await MainActor.run {
                    isProcessing = false
                    transcriptionStartTime = nil
                    if shouldHintThisRun { hasShownFirstModelUseHint = true; showFirstModelUseHint = false }
                }
            } catch {
                if case let SpeechToTextError.localTranscriptionFailed(inner) = error,
                   let lwError = inner as? LocalWhisperError,
                   lwError == .modelNotDownloaded {
                    await MainActor.run {
                        errorMessage = "Local Whisper model not downloaded. Opening Settings…"
                        showError = true
                        isProcessing = false
                        transcriptionStartTime = nil
                        DashboardWindowManager.shared.showDashboardWindow()
                        if shouldHintThisRun { hasShownFirstModelUseHint = true; showFirstModelUseHint = false }
                    }
                } else if let pe = error as? ParakeetError, pe == .modelNotReady {
                    await MainActor.run {
                        errorMessage = "Parakeet model not downloaded. Opening Settings…"
                        showError = true
                        isProcessing = false
                        transcriptionStartTime = nil
                        DashboardWindowManager.shared.showDashboardWindow()
                        if shouldHintThisRun { hasShownFirstModelUseHint = true; showFirstModelUseHint = false }
                    }
                } else {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                        isProcessing = false
                        transcriptionStartTime = nil
                        if shouldHintThisRun { hasShownFirstModelUseHint = true; showFirstModelUseHint = false }
                    }
                }
            }
        }
    }

    func transcribeExternalAudioFile(_ audioURL: URL) {
        processingTask?.cancel()

        let shouldHintThisRun = !hasShownFirstModelUseHint && isLocalModelInvocationPlanned()
        if shouldHintThisRun { showFirstModelUseHint = true }

        // Set isProcessing before creating Task to prevent race condition
        isProcessing = true
        transcriptionStartTime = Date()

        processingTask = Task {
            progressMessage = "Transcribing file..."

            do {
                try Task.checkCancellation()
                lastAudioURL = audioURL
                try Task.checkCancellation()

                let text: String
                if transcriptionProvider == .local {
                    text = try await speechService.transcribeRaw(audioURL: audioURL, provider: transcriptionProvider, model: selectedWhisperModel)
                } else {
                    text = try await speechService.transcribeRaw(audioURL: audioURL, provider: transcriptionProvider)
                }

                try Task.checkCancellation()

                let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
                let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
                var finalText = text
                let sourceBundleId: String? = await MainActor.run { currentSourceAppInfo().bundleIdentifier }
                if mode != .off {
                    await MainActor.run { progressMessage = "Semantic correction..." }
                    let corrected = await semanticCorrectionService.correct(text: text, providerUsed: transcriptionProvider, sourceAppBundleId: sourceBundleId)
                    let trimmed = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        finalText = corrected
                    }
                }
                let wordCount = UsageMetricsStore.estimatedWordCount(for: finalText)
                let characterCount = finalText.count

                // Use AVAsset to get actual duration instead of estimating from file size
                let asset = AVAsset(url: audioURL)
                let estimatedDuration: TimeInterval
                if #available(macOS 12.0, *) {
                    estimatedDuration = (try? await asset.load(.duration).seconds) ?? 0
                } else {
                    estimatedDuration = asset.duration.seconds
                }

                await MainActor.run { PasteManager.copyToClipboard(finalText) }
                let shouldSave: Bool = await MainActor.run { DataManager.shared.isHistoryEnabled }
                if shouldSave {
                    let modelUsed: String? = await MainActor.run { (transcriptionProvider == .local) ? self.selectedWhisperModel.rawValue : nil }
                    let sourceInfo: SourceAppInfo = await MainActor.run { currentSourceAppInfo() }
                    let record = TranscriptionRecord(
                        text: finalText,
                        provider: transcriptionProvider,
                        duration: estimatedDuration,
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
                    UsageMetricsStore.shared.recordSession(
                        duration: estimatedDuration,
                        wordCount: wordCount,
                        characterCount: characterCount
                    )
                    recordSourceUsage(words: wordCount, characters: characterCount)
                    transcriptionStartTime = nil
                    showConfirmationAndPaste(text: finalText)
                    if shouldHintThisRun { hasShownFirstModelUseHint = true; showFirstModelUseHint = false }
                }
            } catch is CancellationError {
                await MainActor.run {
                    isProcessing = false
                    transcriptionStartTime = nil
                    if shouldHintThisRun { hasShownFirstModelUseHint = true; showFirstModelUseHint = false }
                }
            } catch {
                if case let SpeechToTextError.localTranscriptionFailed(inner) = error,
                   let lwError = inner as? LocalWhisperError,
                   lwError == .modelNotDownloaded {
                    await MainActor.run {
                        errorMessage = "Local Whisper model not downloaded. Opening Settings…"
                        showError = true
                        isProcessing = false
                        transcriptionStartTime = nil
                        DashboardWindowManager.shared.showDashboardWindow()
                        if shouldHintThisRun { hasShownFirstModelUseHint = true; showFirstModelUseHint = false }
                    }
                } else if let pe = error as? ParakeetError, pe == .modelNotReady {
                    await MainActor.run {
                        errorMessage = "Parakeet model not downloaded. Opening Settings…"
                        showError = true
                        isProcessing = false
                        transcriptionStartTime = nil
                        DashboardWindowManager.shared.showDashboardWindow()
                        if shouldHintThisRun { hasShownFirstModelUseHint = true; showFirstModelUseHint = false }
                    }
                } else {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                        isProcessing = false
                        transcriptionStartTime = nil
                        if shouldHintThisRun { hasShownFirstModelUseHint = true; showFirstModelUseHint = false }
                    }
                }
            }
        }
    }

    func showConfirmationAndPaste(text: String) {
        Logger.paste.debug("showConfirmationAndPaste called with text length: \(text.count)")
        showSuccess = true
        isProcessing = false
        soundManager.playCompletionSound()

        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
        Logger.paste.debug("showConfirmationAndPaste: enableSmartPaste = \(enableSmartPaste)")
        if enableSmartPaste {
            Logger.paste.debug("showConfirmationAndPaste: awaitingSemanticPaste = \(awaitingSemanticPaste)")
            // Capture flag value at schedule time to prevent race condition (#26 fix)
            let shouldPasteNow = !awaitingSemanticPaste
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
                    self.showSuccess = false
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
        
        guard let audioURL = lastAudioURL else {
            errorMessage = "No audio file available to retry. Please record again."
            showError = true
            return
        }
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            errorMessage = "Audio file no longer exists. Please record again."
            showError = true
            lastAudioURL = nil
            return
        }
        
        processingTask?.cancel()

        // Set isProcessing before creating Task to prevent race condition
        isProcessing = true
        transcriptionStartTime = Date()

        processingTask = Task {
            progressMessage = "Retrying transcription..."
            
            do {
                try Task.checkCancellation()
                
                let text: String
                if transcriptionProvider == .local {
                    text = try await speechService.transcribeRaw(audioURL: audioURL, provider: transcriptionProvider, model: selectedWhisperModel)
                } else {
                    text = try await speechService.transcribeRaw(audioURL: audioURL, provider: transcriptionProvider)
                }
                
                try Task.checkCancellation()

                await MainActor.run { PasteManager.copyToClipboard(text) }

                let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
                let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
                let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
                let shouldAwaitSemanticForPaste = enableSmartPaste && ((mode == .localMLX) || (mode == .cloud && (transcriptionProvider == .openai || transcriptionProvider == .gemini)))

                if shouldAwaitSemanticForPaste {
                    await MainActor.run {
                        awaitingSemanticPaste = true
                        progressMessage = "Semantic correction..."
                    }
                    // Capture all values before async work to avoid implicit self capture
                    // Use regular Task instead of Task.detached so it can be cancelled
                    let capturedBundleId: String? = await MainActor.run { currentSourceAppInfo().bundleIdentifier }
                    let capturedModelUsed: String? = await MainActor.run { (transcriptionProvider == .local) ? selectedWhisperModel.rawValue : nil }
                    let capturedSourceInfo: SourceAppInfo = await MainActor.run { currentSourceAppInfo() }
                    let shouldSave2: Bool = await MainActor.run { DataManager.shared.isHistoryEnabled }
                    let capturedSemanticService = semanticCorrectionService

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
                        transcriptionStartTime = nil
                        isProcessing = false
                        showConfirmationAndPaste(text: corrected)
                        if awaitingSemanticPaste {
                            performUserTriggeredPaste()
                            awaitingSemanticPaste = false
                        }
                    }
                } else {
                    // Only apply semantic correction if mode is not off
                    let finalText: String
                    if mode != .off {
                        let capturedBundleId2: String? = await MainActor.run { currentSourceAppInfo().bundleIdentifier }
                        finalText = await semanticCorrectionService.correct(text: text, providerUsed: transcriptionProvider, sourceAppBundleId: capturedBundleId2)
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
                        transcriptionStartTime = nil
                        isProcessing = false  // Reset flag when smart paste disabled
                        showConfirmationAndPaste(text: finalText)
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    isProcessing = false
                    transcriptionStartTime = nil
                    awaitingSemanticPaste = false  // Reset on cancellation
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                    transcriptionStartTime = nil
                }
            }
        }
    }
    
    func showLastAudioFile() {
        guard let audioURL = lastAudioURL else {
            errorMessage = "No audio file available to show."
            showError = true
            return
        }
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            errorMessage = "Audio file no longer exists."
            showError = true
            lastAudioURL = nil
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
