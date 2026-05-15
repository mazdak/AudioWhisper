import SwiftUI
import AppKit

internal extension ContentView {
    func handleOnAppear() {
        setupNotificationObservers()
        permissionManager.checkPermissionState()
        loadStoredTranscriptionProvider()
        updateStatus()
    }

    func handleOnDisappear() {
        notificationCoordinator.removeAll()
        processingTask?.cancel()
        processingTask = nil
        viewModel.lastAudioURL = nil
    }

    private func setupNotificationObservers() {
        // Clear any existing observers first
        notificationCoordinator.removeAll()

        // Transcription progress updates
        notificationCoordinator.observeOnMainActor(.transcriptionProgress) { notification in
            if let message = notification.object as? String {
                viewModel.progressMessage = enhanceProgressMessage(message)
            }
        }

        // Space key - toggle recording
        // Note: The await Task.sleep below does NOT block the main thread.
        // Swift Concurrency suspends the async task while the main actor continues processing events.
        // This implements a 1-second debounce to prevent rapid repeated triggers.
        notificationCoordinator.observeOnMainActor(.spaceKeyPressed) { _ in
            guard !viewModel.isHandlingSpaceKey else { return }
            viewModel.isHandlingSpaceKey = true

            if audioRecorder.isRecording {
                stopAndProcess()
            } else if !isProcessing && permissionManager.microphonePermissionState == .granted && !viewModel.showSuccess {
                startRecording()
            } else if permissionManager.microphonePermissionState != .granted {
                permissionManager.requestPermissionWithEducation()
            }

            // Debounce: prevent rapid repeated space key triggers
            try? await Task.sleep(for: .seconds(1))
            viewModel.isHandlingSpaceKey = false
        }

        // Escape key - cancel or close
        notificationCoordinator.observeOnMainActor(.escapeKeyPressed) { _ in
            if audioRecorder.isRecording {
                audioRecorder.cancelRecording()
                viewModel.showError = false
            } else if isProcessing {
                processingTask?.cancel()
                viewModel.showError = false
            } else {
                // Only close the recording window, not any other window
                if let recordWindow = NSApp.windows.first(where: { $0.title == WindowTitles.recording }) {
                    recordWindow.orderOut(nil)
                    NotificationCenter.default.post(name: .restoreFocusToPreviousApp, object: nil)
                }
                viewModel.showSuccess = false
            }
        }

        // Return key - trigger paste when showing success
        notificationCoordinator.observeOnMainActor(.returnKeyPressed) { _ in
            if viewModel.showSuccess {
                let enableSmartPaste = AppDefaults.enableSmartPaste
                if enableSmartPaste {
                    performUserTriggeredPaste()
                }
            }
        }

        // Target app stored - update paste target
        notificationCoordinator.observeOnMainActor(.targetAppStored) { notification in
            if let app = notification.object as? NSRunningApplication {
                viewModel.targetAppForPaste = app
                if let info = SourceAppInfo.from(app: app) {
                    viewModel.lastSourceAppInfo = info
                }
            }
        }

        // Recording failed notification
        notificationCoordinator.observeOnMainActor(.recordingStartFailed) { _ in
            viewModel.errorMessage = LocalizedStrings.Errors.failedToStartRecording
            viewModel.showError = true
        }

        // Window focus - ensure proper first responder
        notificationCoordinator.observe(NSWindow.didBecomeKeyNotification) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let window = NSApp.keyWindow {
                    window.makeFirstResponder(window.contentView)
                }
            }
        }

        // Retry transcription request
        notificationCoordinator.observe(.retryTranscriptionRequested) { _ in
            Task { @MainActor in
                retryLastTranscription()
            }
        }

        // Show audio file request
        notificationCoordinator.observe(.showAudioFileRequested) { _ in
            Task { @MainActor in
                showLastAudioFile()
            }
        }

        // Transcribe external file
        notificationCoordinator.observeOnMainActor(.transcribeAudioFile) { notification in
            if let url = notification.object as? URL {
                transcribeExternalAudioFile(url)
            }
        }
    }

    private func loadStoredTranscriptionProvider() {
        // Only update from defaults if the key has actually been set; otherwise leave
        // the view's existing `transcriptionProvider` value alone (preserves prior behavior).
        if AppDefaults.hasValue(for: .transcriptionProvider) {
            transcriptionProvider = AppDefaults.transcriptionProvider
        }
    }
}
