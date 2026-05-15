import SwiftUI
import AppKit
import AVFoundation
import os.log

/// Identifies the origin of a transcription so the post-transcription tail
/// (history save, paste, success UI, dashboard redirect on missing models) can
/// branch on the right metadata. Introduced by audit item C1 to consolidate
/// the duplicated "finish transcription" path in `ContentView+Recording`.
internal enum TranscriptionSource {
    /// Live recording captured by `AudioEngineRecorder`. The associated
    /// `sessionDuration` comes from the recorder and may be `nil` if the
    /// engine couldn't compute one (matches the prior pass-through behaviour).
    case liveRecording(sessionDuration: TimeInterval?)
    /// User-imported audio file. The associated `audioURL` is the source file
    /// and `estimatedDuration` is read from the file's `AVAsset` duration.
    case importedFile(URL, estimatedDuration: TimeInterval)

    /// Duration used for analytics and the history record. Optional so the
    /// live-recording path can flow a `nil` duration through unchanged when
    /// the recorder couldn't compute one.
    var duration: TimeInterval? {
        switch self {
        case .liveRecording(let sessionDuration): return sessionDuration
        case .importedFile(_, let estimatedDuration): return estimatedDuration
        }
    }

    /// Dashboard redirect reason tag for "model not downloaded" errors.
    /// Live and file flows surface distinct reasons so analytics/logs can tell
    /// them apart.
    func dashboardReason(for provider: TranscriptionProvider) -> String {
        switch (self, provider) {
        case (.liveRecording, .local): return "liveLocalModelMissing"
        case (.liveRecording, .parakeet): return "liveParakeetModelMissing"
        case (.importedFile, .local): return "fileLocalModelMissing"
        case (.importedFile, .parakeet): return "fileParakeetModelMissing"
        }
    }
}

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
    /// Pipeline that orchestrates validation → transcription → semantic
    /// correction. After audit item B1 this is the sole owner of correction
    /// orchestration. Built lazily from `speechService` and
    /// `semanticCorrectionService` so dependency-injected mocks compose.
    /// `@ObservationIgnored` because lazy stored properties are incompatible
    /// with the `@Observable` macro's init-accessor codegen.
    @ObservationIgnored
    private lazy var transcriptionPipeline: TranscriptionPipeline = {
        TranscriptionPipeline(
            speechService: speechService,
            correctionService: semanticCorrectionService
        )
    }()

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

            // Capture a stable `liveRecording` source value once we know the
            // session duration; reused for both the success and error tails
            // so dashboard reasons line up.
            var source: TranscriptionSource = .liveRecording(sessionDuration: 0)

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
                source = .liveRecording(sessionDuration: sessionDuration)

                guard !audioURL.path.isEmpty else {
                    throw NSError(
                        domain: "AudioRecorder",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: LocalizedStrings.Errors.recordingURLEmpty]
                    )
                }

                lastAudioURL = audioURL
                try Task.checkCancellation()

                let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode")
                    ?? SemanticCorrectionMode.off.rawValue
                let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
                let sourceBundleId: String? = currentSourceAppInfo().bundleIdentifier

                if mode != .off {
                    progressMessage = "Semantic correction..."
                }

                // After audit item B1, correction is owned by TranscriptionPipeline.
                let pipelineConfig = TranscriptionPipelineConfig(
                    provider: transcriptionProvider,
                    whisperModel: transcriptionProvider == .local ? selectedWhisperModel : nil,
                    applySemanticCorrection: mode != .off,
                    sourceAppBundleId: sourceBundleId
                )
                let finalText = try await transcriptionPipeline.transcribe(
                    audioURL: audioURL,
                    config: pipelineConfig
                )

                try Task.checkCancellation()

                await finishTranscription(
                    text: finalText,
                    source: source,
                    transcriptionProvider: transcriptionProvider,
                    selectedWhisperModel: selectedWhisperModel,
                    shouldHintThisRun: shouldHintThisRun,
                    setHintShown: setHintShown
                )

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
                    source: source,
                    transcriptionProvider: transcriptionProvider,
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

    private func recordSourceUsage(words: Int, characters: Int) {
        guard words > 0 else { return }
        let info = currentSourceAppInfo()
        SourceUsageStore.shared.recordUsage(for: info, words: words, characters: characters)
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
    /// `isProcessing` is reset inside `showConfirmationAndPaste(_:)` to match
    /// the prior behaviour where the success UI appears in the same tick.
    func finishTranscription(
        text: String,
        source: TranscriptionSource,
        transcriptionProvider: TranscriptionProvider,
        selectedWhisperModel: WhisperModel,
        shouldHintThisRun: Bool,
        setHintShown: @escaping () -> Void
    ) async {
        let wordCount = UsageMetricsStore.estimatedWordCount(for: text)
        let characterCount = text.count

        PasteManager.copyToClipboard(text)

        if DataManager.shared.isHistoryEnabled {
            let modelUsed: String? = (transcriptionProvider == .local)
                ? selectedWhisperModel.rawValue
                : nil
            let sourceInfo = currentSourceAppInfo()
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
        transcriptionStartTime = nil
        showConfirmationAndPaste(text: text)

        if shouldHintThisRun {
            setHintShown()
            showFirstModelUseHint = false
        }
    }

    /// Public-facing error handler used by both VM `stopAndProcess` and the
    /// ContentView file/live entry points. Routes "model not downloaded"
    /// errors to a dashboard presenter via `presentDashboard`; all other
    /// errors set `errorMessage` / `showError`.
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
        // Default to opening the dashboard via the shared manager when the
        // caller didn't provide its own presenter. Inlined here so the default
        // parameter doesn't need to capture a `@MainActor`-isolated symbol.
        let present = presentDashboard ?? { _ in
            DashboardWindowManager.shared.showDashboardWindow()
        }

        if case let SpeechToTextError.localTranscriptionFailed(inner) = error,
           let lwError = inner as? LocalWhisperError,
           lwError == .modelNotDownloaded {
            errorMessage = "Local Whisper model not downloaded. Opening Settings…"
            showError = true
            isProcessing = false
            transcriptionStartTime = nil
            present(source.dashboardReason(for: transcriptionProvider))
        } else if let pe = error as? ParakeetError, pe == .modelNotReady {
            errorMessage = "Parakeet model not downloaded. Opening Settings…"
            showError = true
            isProcessing = false
            transcriptionStartTime = nil
            present(source.dashboardReason(for: transcriptionProvider))
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
