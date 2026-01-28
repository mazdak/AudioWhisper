import SwiftUI
import AppKit
import AVFoundation
import os.log

/// ViewModel that manages recording state and the transcription pipeline.
/// Consolidates state from ContentView to reduce complexity and improve testability.
@MainActor
@Observable
final class RecordingViewModel {
    // MARK: - Core Recording State

    private(set) var isProcessing = false
    var progressMessage = "Processing..."
    var transcriptionStartTime: Date?

    // MARK: - UI State

    var showError = false
    var errorMessage = ""
    var showSuccess = false
    var isHandlingSpaceKey = false
    var showFirstModelUseHint = false

    // MARK: - Paste State

    var targetAppForPaste: NSRunningApplication?
    var lastAudioURL: URL?
    var awaitingSemanticPaste = false
    var lastSourceAppInfo: SourceAppInfo?

    // MARK: - Dependencies

    let speechService: SpeechToTextService
    let pasteManager: PasteManager
    let semanticCorrectionService: SemanticCorrectionService
    let soundManager: SoundManager
    let statusViewModel: StatusViewModel

    // MARK: - Internal State

    private var processingTask: Task<Void, Never>?
    private var notificationTasks: [Task<Void, Never>] = []

    // MARK: - Initialization

    /// Creates a new RecordingViewModel with the specified dependencies.
    /// All parameters have default values that can be overridden for testing.
    init(
        speechService: SpeechToTextService,
        pasteManager: PasteManager,
        semanticCorrectionService: SemanticCorrectionService,
        soundManager: SoundManager,
        statusViewModel: StatusViewModel
    ) {
        self.speechService = speechService
        self.pasteManager = pasteManager
        self.semanticCorrectionService = semanticCorrectionService
        self.soundManager = soundManager
        self.statusViewModel = statusViewModel
    }

    /// Convenience initializer with default dependencies.
    convenience init() {
        self.init(
            speechService: SpeechToTextService(),
            pasteManager: PasteManager(),
            semanticCorrectionService: SemanticCorrectionService(),
            soundManager: SoundManager(),
            statusViewModel: StatusViewModel()
        )
    }

    // MARK: - Lifecycle

    func onAppear(permissionManager: PermissionManager, loadProvider: () -> Void) {
        setupNotificationObservers()
        permissionManager.checkPermissionState()
        loadProvider()
    }

    func onDisappear() {
        stopNotificationObservers()
        cancelProcessing()
        lastAudioURL = nil
    }

    // MARK: - Recording Actions

    func startRecording(audioRecorder: AudioEngineRecorder, permissionManager: PermissionManager) {
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

    func stopAndProcess(
        audioRecorder: AudioEngineRecorder,
        transcriptionProvider: TranscriptionProvider,
        selectedWhisperModel: WhisperModel,
        hasShownFirstModelUseHint: Bool,
        setHintShown: @escaping () -> Void
    ) {
        processingTask?.cancel()
        NotificationCenter.default.post(name: .recordingStopped, object: nil)

        let shouldHintThisRun = !hasShownFirstModelUseHint && isLocalModelInvocationPlanned(
            transcriptionProvider: transcriptionProvider
        )
        if shouldHintThisRun { showFirstModelUseHint = true }

        isProcessing = true
        transcriptionStartTime = Date()

        processingTask = Task {
            progressMessage = "Preparing audio..."

            do {
                try Task.checkCancellation()
                guard let audioURL = audioRecorder.stopRecording() else {
                    throw NSError(
                        domain: "AudioRecorder",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: LocalizedStrings.Errors.failedToGetRecordingURL]
                    )
                }
                let sessionDuration = audioRecorder.lastRecordingDuration

                guard !audioURL.path.isEmpty else {
                    throw NSError(
                        domain: "AudioRecorder",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: LocalizedStrings.Errors.recordingURLEmpty]
                    )
                }

                lastAudioURL = audioURL
                try Task.checkCancellation()

                let text: String
                if transcriptionProvider == .local {
                    text = try await speechService.transcribeRaw(
                        audioURL: audioURL,
                        provider: transcriptionProvider,
                        model: selectedWhisperModel
                    )
                } else {
                    text = try await speechService.transcribeRaw(
                        audioURL: audioURL,
                        provider: transcriptionProvider
                    )
                }

                try Task.checkCancellation()

                let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode")
                    ?? SemanticCorrectionMode.off.rawValue
                let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
                var finalText = text
                let sourceBundleId: String? = currentSourceAppInfo().bundleIdentifier

                if mode != .off {
                    progressMessage = "Semantic correction..."
                    let corrected = await semanticCorrectionService.correct(
                        text: text,
                        providerUsed: transcriptionProvider,
                        sourceAppBundleId: sourceBundleId
                    )
                    let trimmed = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        finalText = corrected
                    }
                }

                let wordCount = UsageMetricsStore.estimatedWordCount(for: finalText)
                let characterCount = finalText.count

                PasteManager.copyToClipboard(finalText)

                let shouldSave = DataManager.shared.isHistoryEnabled
                if shouldSave {
                    let modelUsed: String? = (transcriptionProvider == .local)
                        ? selectedWhisperModel.rawValue
                        : nil
                    let sourceInfo = currentSourceAppInfo()
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

                UsageMetricsStore.shared.recordSession(
                    duration: sessionDuration,
                    wordCount: wordCount,
                    characterCount: characterCount
                )
                recordSourceUsage(words: wordCount, characters: characterCount)
                transcriptionStartTime = nil
                showConfirmationAndPaste(text: finalText)

                if shouldHintThisRun {
                    setHintShown()
                    showFirstModelUseHint = false
                }

            } catch is CancellationError {
                isProcessing = false
                transcriptionStartTime = nil
                if shouldHintThisRun {
                    setHintShown()
                    showFirstModelUseHint = false
                }
            } catch {
                handleTranscriptionError(
                    error,
                    shouldHintThisRun: shouldHintThisRun,
                    setHintShown: setHintShown
                )
            }
        }
    }

    func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
    }

    // MARK: - Status Updates

    func updateStatus(
        isRecording: Bool,
        hasPermission: Bool
    ) {
        statusViewModel.updateStatus(
            isRecording: isRecording,
            isProcessing: isProcessing,
            progressMessage: progressMessage,
            hasPermission: hasPermission,
            showSuccess: showSuccess,
            errorMessage: showError ? errorMessage : nil
        )
    }

    // MARK: - Source App Info

    func currentSourceAppInfo() -> SourceAppInfo {
        if let cached = lastSourceAppInfo {
            return cached
        }

        if let stored = WindowController.storedTargetApp,
           let info = SourceAppInfo.from(app: stored) {
            lastSourceAppInfo = info
            return info
        }

        if let app = targetAppForPaste,
           let info = SourceAppInfo.from(app: app) {
            lastSourceAppInfo = info
            return info
        }

        if let fallback = findFallbackTargetApp(),
           let info = SourceAppInfo.from(app: fallback) {
            lastSourceAppInfo = info
            return info
        }

        return SourceAppInfo.unknown
    }

    // MARK: - Private Helpers

    private func isLocalModelInvocationPlanned(transcriptionProvider: TranscriptionProvider) -> Bool {
        if transcriptionProvider == .local || transcriptionProvider == .parakeet {
            return true
        }
        let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode")
            ?? SemanticCorrectionMode.off.rawValue
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
        return mode == .localMLX
    }

    private func handleTranscriptionError(
        _ error: Error,
        shouldHintThisRun: Bool,
        setHintShown: @escaping () -> Void
    ) {
        if case let SpeechToTextError.localTranscriptionFailed(inner) = error,
           let lwError = inner as? LocalWhisperError,
           lwError == .modelNotDownloaded {
            errorMessage = "Local Whisper model not downloaded. Opening Settings…"
            showError = true
            isProcessing = false
            transcriptionStartTime = nil
            DashboardWindowManager.shared.showDashboardWindow()
        } else if let pe = error as? ParakeetError, pe == .modelNotReady {
            errorMessage = "Parakeet model not downloaded. Opening Settings…"
            showError = true
            isProcessing = false
            transcriptionStartTime = nil
            DashboardWindowManager.shared.showDashboardWindow()
        } else {
            errorMessage = error.localizedDescription
            showError = true
            isProcessing = false
            transcriptionStartTime = nil
        }

        if shouldHintThisRun {
            setHintShown()
            showFirstModelUseHint = false
        }
    }

    private func recordSourceUsage(words: Int, characters: Int) {
        guard words > 0 else { return }
        let info = currentSourceAppInfo()
        SourceUsageStore.shared.recordUsage(for: info, words: words, characters: characters)
    }

    private func showConfirmationAndPaste(text: String) {
        Logger.paste.debug("showConfirmationAndPaste called with text length: \(text.count)")
        showSuccess = true
        isProcessing = false
        soundManager.playCompletionSound()

        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
        Logger.paste.debug("showConfirmationAndPaste: enableSmartPaste = \(enableSmartPaste)")

        if enableSmartPaste {
            let shouldPasteNow = !awaitingSemanticPaste
            if shouldPasteNow {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                    self?.performUserTriggeredPaste()
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                let recordWindow = NSApp.windows.first { $0.title == WindowTitles.recording }

                let onFadeComplete = {
                    NotificationCenter.default.post(name: .restoreFocusToPreviousApp, object: nil)
                    self.showSuccess = false
                }

                if let window = recordWindow {
                    self.fadeOutWindow(window, completion: onFadeComplete)
                } else if let keyWindow = NSApplication.shared.keyWindow {
                    self.fadeOutWindow(keyWindow, completion: onFadeComplete)
                } else {
                    onFadeComplete()
                }
            }
        }
    }

    // MARK: - Paste Support

    func performUserTriggeredPaste() {
        Logger.paste.debug("performUserTriggeredPaste called")
        guard let targetApp = findValidTargetApp() else {
            Logger.paste.warning("No valid target app found for paste")
            showSuccess = false
            hideRecordingWindow()
            return
        }

        Logger.paste.debug("Target app found: \(targetApp.localizedName ?? "unknown", privacy: .public)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.hideRecordingWindow()
            self?.activateTargetAppAndPaste(targetApp)
        }
    }

    func findValidTargetApp() -> NSRunningApplication? {
        var targetApp = WindowController.storedTargetApp

        if targetApp == nil {
            targetApp = targetAppForPaste
        }

        if let stored = targetApp, stored.isTerminated {
            targetApp = nil
        }

        if targetApp == nil {
            targetApp = findFallbackTargetApp()
        }

        return targetApp
    }

    func findFallbackTargetApp() -> NSRunningApplication? {
        let runningApps = NSWorkspace.shared.runningApplications

        return runningApps.first { app in
            app.bundleIdentifier != Bundle.main.bundleIdentifier &&
            app.bundleIdentifier != "com.tinyspeck.slackmacgap" &&
            app.bundleIdentifier != "com.cron.electron" &&
            app.activationPolicy == .regular &&
            !app.isTerminated
        }
    }

    private func hideRecordingWindow() {
        let recordWindow = NSApp.windows.first { $0.title == WindowTitles.recording }
        if let window = recordWindow {
            fadeOutWindow(window)
        } else if let keyWindow = NSApplication.shared.keyWindow {
            fadeOutWindow(keyWindow)
        }
    }

    private func fadeOutWindow(_ window: NSWindow, duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        // Retain window during animation to prevent deallocation
        let retainedWindow = window
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            retainedWindow.animator().alphaValue = 0.0
        }, completionHandler: {
            // Check window is still valid before operating on it
            guard retainedWindow.isVisible || retainedWindow.alphaValue == 0 else {
                completion?()
                return
            }
            retainedWindow.orderOut(nil)
            retainedWindow.alphaValue = 1.0
            completion?()
        })
    }

    private func activateTargetAppAndPaste(_ target: NSRunningApplication) {
        Task { @MainActor in
            do {
                try await activateApplication(target)
                await pasteManager.pasteWithCompletionHandler()
                showSuccess = false
            } catch {
                Logger.paste.error("activateTargetAppAndPaste failed: \(error.localizedDescription)")
                showSuccess = false
            }
        }
    }

    private func activateApplication(_ target: NSRunningApplication) async throws {
        let success = target.activate(options: [])

        if !success {
            if let bundleURL = target.bundleURL {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true

                return try await withCheckedThrowingContinuation { continuation in
                    NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            } else {
                throw NSError(
                    domain: "AudioWhisper",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to activate target application"]
                )
            }
        }

        await waitForApplicationActivation(target)
    }

    private func waitForApplicationActivation(_ target: NSRunningApplication) async {
        if target.isActive { return }

        // Use actor for thread-safe resume coordination
        let coordinator = ActivationCoordinator()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let timeoutTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                let shouldResume = await coordinator.tryResume()
                if shouldResume {
                    continuation.resume()
                }
            }

            let observer = NotificationCenter.default.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   activatedApp.processIdentifier == target.processIdentifier {
                    timeoutTask.cancel()
                    Task {
                        let shouldResume = await coordinator.tryResume()
                        if shouldResume {
                            continuation.resume()
                        }
                    }
                }
            }

            // Clean up observer after a delay
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        stopNotificationObservers()

        // Transcription progress
        let progressTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .transcriptionProgress) {
                if let message = notification.object as? String {
                    self?.progressMessage = message
                }
            }
        }
        notificationTasks.append(progressTask)

        // Target app stored
        let targetAppTask = Task { @MainActor [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .targetAppStored) {
                if let app = notification.object as? NSRunningApplication {
                    self?.targetAppForPaste = app
                    if let info = SourceAppInfo.from(app: app) {
                        self?.lastSourceAppInfo = info
                    }
                }
            }
        }
        notificationTasks.append(targetAppTask)

        // Recording failed
        let recordingFailedTask = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .recordingStartFailed) {
                self?.errorMessage = LocalizedStrings.Errors.failedToStartRecording
                self?.showError = true
            }
        }
        notificationTasks.append(recordingFailedTask)
    }

    private func stopNotificationObservers() {
        for task in notificationTasks {
            task.cancel()
        }
        notificationTasks.removeAll()
    }
}

// MARK: - Activation Coordinator

/// Actor to safely coordinate single resume of continuation
private actor ActivationCoordinator {
    private var resumed = false

    func tryResume() -> Bool {
        if resumed { return false }
        resumed = true
        return true
    }
}
