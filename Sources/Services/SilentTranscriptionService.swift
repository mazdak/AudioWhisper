import Foundation
import AppKit
import os.log

/// Handles transcription flow in silent mode without requiring the UI window.
/// This service bypasses the ContentView notification system and directly manages
/// the transcription process, clipboard operations, and optional smart paste.
@MainActor
internal class SilentTranscriptionService {
    static let shared = SilentTranscriptionService()

    private let speechService: SpeechToTextServiceProtocol
    private let semanticCorrectionService: SemanticCorrectionServiceProtocol
    private let soundManager: SoundManagerProtocol
    private let pasteManager: PasteManagerProtocol
    private let dataManager: DataManagerForSilentServiceProtocol
    private let usageMetricsStore: UsageMetricsStoreProtocol
    private let notificationCenter: NotificationCenter
    private let pasteboard: NSPasteboard

    /// Current transcription task, allowing cancellation
    private var currentTask: Task<Void, Never>?

    // MARK: - Timing Constants
    internal static let clipboardReadyDelay: Duration = .milliseconds(100)
    internal static let appActivationDelay: Duration = .milliseconds(200)

    /// Default initializer using production dependencies
    private convenience init() {
        self.init(
            speechService: SpeechToTextService(),
            semanticCorrectionService: SemanticCorrectionService(),
            soundManager: SoundManager(),
            pasteManager: PasteManager(),
            dataManager: DataManager.sharedInstance,
            usageMetricsStore: UsageMetricsStore.shared,
            notificationCenter: .default,
            pasteboard: .general
        )
    }

    /// Testable initializer with injectable dependencies
    internal init(
        speechService: SpeechToTextServiceProtocol,
        semanticCorrectionService: SemanticCorrectionServiceProtocol,
        soundManager: SoundManagerProtocol,
        pasteManager: PasteManagerProtocol,
        dataManager: DataManagerForSilentServiceProtocol,
        usageMetricsStore: UsageMetricsStoreProtocol,
        notificationCenter: NotificationCenter = .default,
        pasteboard: NSPasteboard = .general
    ) {
        self.speechService = speechService
        self.semanticCorrectionService = semanticCorrectionService
        self.soundManager = soundManager
        self.pasteManager = pasteManager
        self.dataManager = dataManager
        self.usageMetricsStore = usageMetricsStore
        self.notificationCenter = notificationCenter
        self.pasteboard = pasteboard
    }

    /// Cancels any in-progress transcription
    func cancelCurrentTranscription() {
        currentTask?.cancel()
        currentTask = nil
    }

    /// Performs silent transcription: stops recording, transcribes, copies to clipboard,
    /// plays completion sound, and optionally pastes to target app.
    func performSilentTranscription(
        audioRecorder: AudioRecorder,
        targetApp: NSRunningApplication?
    ) async {
        // Cancel any existing transcription
        cancelCurrentTranscription()

        // Store task reference for cancellation support
        let task = Task { @MainActor in
            await executeTranscription(audioRecorder: audioRecorder, targetApp: targetApp)
        }
        currentTask = task
        await task.value
        // Only clear if this is still our task (avoid race with newer invocation)
        if currentTask === task {
            currentTask = nil
        }
    }

    private func executeTranscription(
        audioRecorder: AudioRecorder,
        targetApp: NSRunningApplication?
    ) async {
        // Stop recording and get the audio URL FIRST
        let audioURL = audioRecorder.stopRecording()
        guard let audioURL = audioURL else {
            Logger.app.error("SilentTranscriptionService: Failed to get recording URL")
            NSSound.beep()
            // Notify that recording stopped (even on failure)
            notificationCenter.post(name: .recordingStopped, object: nil)
            return
        }

        // NOW notify that recording has stopped (after it actually stopped)
        notificationCenter.post(name: .recordingStopped, object: nil)

        let sessionDuration = audioRecorder.lastRecordingDuration

        // Get user preferences
        let providerRaw = UserDefaults.standard.string(forKey: "transcriptionProvider") ?? TranscriptionProvider.openai.rawValue
        let transcriptionProvider = TranscriptionProvider(rawValue: providerRaw) ?? .openai
        let selectedModelRaw = UserDefaults.standard.string(forKey: "selectedWhisperModel") ?? WhisperModel.base.rawValue
        let selectedWhisperModel = WhisperModel(rawValue: selectedModelRaw) ?? .base

        do {
            // Check for cancellation before starting transcription
            try Task.checkCancellation()

            // Transcribe the audio
            let model: WhisperModel? = (transcriptionProvider == .local) ? selectedWhisperModel : nil
            let text = try await speechService.transcribeRaw(audioURL: audioURL, provider: transcriptionProvider, model: model)

            try Task.checkCancellation()

            // Apply semantic correction if enabled
            let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
            let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off

            var finalText = text
            if mode != .off {
                let corrected = await semanticCorrectionService.correct(text: text, providerUsed: transcriptionProvider, sourceAppBundleId: targetApp?.bundleIdentifier)
                let trimmed = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    finalText = corrected
                }
            }

            try Task.checkCancellation()

            // Copy to clipboard
            pasteboard.clearContents()
            pasteboard.setString(finalText, forType: .string)

            // Calculate metrics (always, regardless of history setting)
            let wordCount = UsageMetricsStore.estimatedWordCount(for: finalText)
            let characterCount = finalText.count

            // Save to history if enabled
            if dataManager.isHistoryEnabled {
                let modelUsed: String? = (transcriptionProvider == .local) ? selectedWhisperModel.rawValue : nil

                let sourceInfo: SourceAppInfo
                if let app = targetApp, let info = SourceAppInfo.from(app: app) {
                    sourceInfo = info
                } else {
                    sourceInfo = .unknown
                }

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
                await dataManager.saveTranscriptionQuietly(record)
            }

            // Record usage metrics ALWAYS (outside history conditional)
            usageMetricsStore.recordSession(
                duration: sessionDuration,
                wordCount: wordCount,
                characterCount: characterCount
            )

            // Play completion sound
            soundManager.playCompletionSound()

            // Handle paste or focus restore
            let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
            if enableSmartPaste {
                if let app = targetApp {
                    await performSmartPaste(to: app)
                } else {
                    // Smart paste enabled but no target app - restore focus to frontmost
                    restoreFocusToPreviousApp()
                }
            } else {
                // No smart paste - restore focus to previous app
                restoreFocusToPreviousApp()
            }

            Logger.app.info("SilentTranscriptionService: Transcription completed successfully")

        } catch is CancellationError {
            Logger.app.info("SilentTranscriptionService: Transcription cancelled")
            // Don't beep on cancellation - user initiated it
        } catch {
            Logger.app.error("SilentTranscriptionService: Transcription failed: \(error)")
            NSSound.beep()

            // Still restore focus on error
            restoreFocusToPreviousApp()
        }
    }

    private func performSmartPaste(to targetApp: NSRunningApplication) async {
        // Small delay to ensure clipboard is ready
        try? await Task.sleep(for: Self.clipboardReadyDelay)

        // Activate target app
        let activated = targetApp.activate(options: [])

        if !activated {
            // Try opening the app if simple activation fails
            if let bundleURL = targetApp.bundleURL {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true

                do {
                    try await NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration)
                } catch {
                    Logger.app.error("SilentTranscriptionService: Failed to activate target app: \(error)")
                    return
                }
            } else {
                Logger.app.error("SilentTranscriptionService: Failed to activate target app")
                return
            }
        }

        // Wait for app activation
        try? await Task.sleep(for: Self.appActivationDelay)

        // Perform paste
        await pasteManager.pasteWithCompletionHandler()
    }

    private func restoreFocusToPreviousApp() {
        notificationCenter.post(name: .restoreFocusToPreviousApp, object: nil)
    }
}
