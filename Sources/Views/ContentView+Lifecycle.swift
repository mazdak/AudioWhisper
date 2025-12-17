import SwiftUI
import AppKit

internal extension ContentView {
    func handleOnAppear() {
        audioRecorder.checkMicrophonePermission()
        setupNotificationObservers()
        permissionManager.checkPermissionState()
        loadStoredTranscriptionProvider()
        updateStatus()
    }
    
    func handleOnDisappear() {
        removeNotificationObservers()
        processingTask?.cancel()
        processingTask = nil
        lastAudioURL = nil
    }
    
    private func setupNotificationObservers() {
        transcriptionProgressObserver = NotificationCenter.default.addObserver(
            forName: .transcriptionProgress,
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                if let message = notification.object as? String {
                    progressMessage = enhanceProgressMessage(message)
                }
            }
        }
        
        spaceKeyObserver = NotificationCenter.default.addObserver(
            forName: .spaceKeyPressed,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard !isHandlingSpaceKey else { return }
                isHandlingSpaceKey = true
                
                if audioRecorder.isRecording {
                    stopAndProcess()
                } else if !isProcessing && audioRecorder.hasPermission && !showSuccess {
                    startRecording()
                } else if !audioRecorder.hasPermission {
                    permissionManager.requestPermissionWithEducation()
                }
                
                try? await Task.sleep(for: .seconds(1))
                isHandlingSpaceKey = false
            }
        }
        
        escapeKeyObserver = NotificationCenter.default.addObserver(
            forName: .escapeKeyPressed,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if audioRecorder.isRecording {
                    audioRecorder.cancelRecording()
                    isProcessing = false
                } else if isProcessing {
                    processingTask?.cancel()
                    isProcessing = false
                } else {
                    let recordWindow = NSApp.windows.first { window in
                        window.title == "AudioWhisper Recording"
                    }
                    
                    if let window = recordWindow {
                        window.orderOut(nil)
                    } else {
                        NSApplication.shared.keyWindow?.orderOut(nil)
                    }
                    
                    NotificationCenter.default.post(name: .restoreFocusToPreviousApp, object: nil)
                    
                    showSuccess = false
                }
            }
        }
        
        returnKeyObserver = NotificationCenter.default.addObserver(
            forName: .returnKeyPressed,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if showSuccess {
                    let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
                    if enableSmartPaste {
                        performUserTriggeredPaste()
                    }
                }
            }
        }
        
        targetAppObserver = NotificationCenter.default.addObserver(
            forName: .targetAppStored,
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                if let app = notification.object as? NSRunningApplication {
                    targetAppForPaste = app
                    if let info = SourceAppInfo.from(app: app) {
                        lastSourceAppInfo = info
                    }
                }
            }
        }
        
        recordingFailedObserver = NotificationCenter.default.addObserver(
            forName: .recordingStartFailed,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                errorMessage = LocalizedStrings.Errors.failedToStartRecording
                showError = true
            }
        }
        
        windowFocusObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let window = NSApp.keyWindow {
                    window.makeFirstResponder(window.contentView)
                }
            }
        }
        
        retryObserver = NotificationCenter.default.addObserver(
            forName: .retryTranscriptionRequested,
            object: nil,
            queue: .main
        ) { _ in
            retryLastTranscription()
        }
        
        showAudioFileObserver = NotificationCenter.default.addObserver(
            forName: .showAudioFileRequested,
            object: nil,
            queue: .main
        ) { _ in
            showLastAudioFile()
        }
        
        transcribeFileObserver = NotificationCenter.default.addObserver(
            forName: .transcribeAudioFile,
            object: nil,
            queue: .main
        ) { notification in
            if let url = notification.object as? URL {
                transcribeExternalAudioFile(url)
            }
        }
    }
    
    private func removeNotificationObservers() {
        removeObserver(&transcriptionProgressObserver)
        removeObserver(&spaceKeyObserver)
        removeObserver(&escapeKeyObserver)
        removeObserver(&returnKeyObserver)
        removeObserver(&targetAppObserver)
        removeObserver(&recordingFailedObserver)
        removeObserver(&windowFocusObserver)
        removeObserver(&retryObserver)
        removeObserver(&showAudioFileObserver)
        removeObserver(&transcribeFileObserver)
    }
    
    private func removeObserver(_ observer: inout NSObjectProtocol?) {
        if let existing = observer {
            NotificationCenter.default.removeObserver(existing)
            observer = nil
        }
    }
    
    private func loadStoredTranscriptionProvider() {
        if let storedProvider = UserDefaults.standard.string(forKey: "transcriptionProvider"),
           let provider = TranscriptionProvider(rawValue: storedProvider) {
            transcriptionProvider = provider
        }
    }
}
