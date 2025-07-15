import SwiftUI
import AVFoundation
import ApplicationServices

// Helper class to safely capture observer in closure
// Uses a lock to ensure thread-safe access to the mutable observer property
// @unchecked is required because we have mutable state but we ensure thread safety via NSLock
private final class ObserverBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _observer: NSObjectProtocol?
    
    var observer: NSObjectProtocol? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _observer
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _observer = newValue
        }
    }
}

struct ContentView: View {
    @StateObject private var audioRecorder: AudioRecorder
    @AppStorage("transcriptionProvider") private var transcriptionProvider = TranscriptionProvider.openai
    @AppStorage("selectedWhisperModel") private var selectedWhisperModel = WhisperModel.base
    @AppStorage("immediateRecording") private var immediateRecording = false
    @StateObject private var speechService: SpeechToTextService
    @StateObject private var pasteManager = PasteManager()
    @StateObject private var statusViewModel = StatusViewModel()
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var soundManager = SoundManager()
    @State private var isProcessing = false
    @State private var progressMessage = "Processing..."
    @State private var transcriptionStartTime: Date?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var isHovered = false
    @State private var isHandlingSpaceKey = false
    @State private var processingTask: Task<Void, Never>?
    @State private var transcriptionProgressObserver: NSObjectProtocol?
    @State private var spaceKeyObserver: NSObjectProtocol?
    @State private var escapeKeyObserver: NSObjectProtocol?
    @State private var returnKeyObserver: NSObjectProtocol?
    @State private var targetAppObserver: NSObjectProtocol?
    @State private var recordingFailedObserver: NSObjectProtocol?
    @State private var targetAppForPaste: NSRunningApplication?
    @State private var windowFocusObserver: NSObjectProtocol?
    @State private var retryObserver: NSObjectProtocol?
    @State private var showAudioFileObserver: NSObjectProtocol?
    @State private var lastAudioURL: URL?
    
    init(speechService: SpeechToTextService = SpeechToTextService(), audioRecorder: AudioRecorder) {
        self._speechService = StateObject(wrappedValue: speechService)
        self._audioRecorder = StateObject(wrappedValue: audioRecorder)
    }
    
    private func showErrorAlert() {
        ErrorPresenter.shared.showError(errorMessage)
        showError = false
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Simplified status display
            StatusDisplayView(
                status: statusViewModel.currentStatus,
                audioLevel: audioRecorder.audioLevel,
                onPermissionInfoTapped: {
                    permissionManager.requestPermissionWithEducation()
                }
            )
            
            // Record/Stop button
            RecordingButton(
                isRecording: audioRecorder.isRecording,
                hasPermission: audioRecorder.hasPermission,
                isProcessing: isProcessing,
                showSuccess: showSuccess,
                transcriptionProvider: transcriptionProvider,
                onTap: {
                    if audioRecorder.isRecording {
                        stopAndProcess()
                    } else if showSuccess {
                        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
                        if enableSmartPaste {
                            // User-triggered paste: Focus target app FIRST, then paste
                            performUserTriggeredPaste()
                        } else {
                            // SmartPaste disabled - just dismiss window
                            showSuccess = false
                        }
                    } else {
                        startRecording()
                    }
                },
                onHover: { hovering in
                    isHovered = hovering
                }
            )
            
            // Instruction text below microphone
            if audioRecorder.hasPermission && !isProcessing && !audioRecorder.isRecording {
                if showSuccess {
                    let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
                    if enableSmartPaste {
                        Text("Pasting...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    } else {
                        Text("Text copied to clipboard")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                } else {
                    Text(LocalizedStrings.UI.spaceToRecord)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .padding(20)
        .sheet(isPresented: $permissionManager.showEducationalModal) {
            PermissionEducationModal(
                onProceed: {
                    permissionManager.showEducationalModal = false
                    permissionManager.proceedWithPermissionRequest()
                },
                onCancel: {
                    permissionManager.showEducationalModal = false
                }
            )
        }
        .sheet(isPresented: $permissionManager.showRecoveryModal) {
            PermissionRecoveryModal(
                onOpenSettings: {
                    permissionManager.showRecoveryModal = false
                    permissionManager.openSystemSettings()
                },
                onCancel: {
                    permissionManager.showRecoveryModal = false
                }
            )
        }
        .focusable(false)
        .onAppear {
            // Check permission status when view appears
            audioRecorder.checkMicrophonePermission()
            
            // Immediate recording is now handled by the hotkey handler in AudioWhisperApp
            
            // Listen for transcription progress updates
            transcriptionProgressObserver = NotificationCenter.default.addObserver(
                forName: .transcriptionProgress,
                object: nil,
                queue: .main
            ) { notification in
                if let message = notification.object as? String {
                    progressMessage = enhanceProgressMessage(message)
                }
            }
            
            // Listen for global space key events
            spaceKeyObserver = NotificationCenter.default.addObserver(
                forName: .spaceKeyPressed,
                object: nil,
                queue: .main
            ) { _ in
                // Prevent rapid double-triggering
                guard !isHandlingSpaceKey else { return }
                
                isHandlingSpaceKey = true
                
                if audioRecorder.isRecording {
                    stopAndProcess()
                } else if !isProcessing && audioRecorder.hasPermission && !showSuccess {
                    startRecording()
                } else if !audioRecorder.hasPermission {
                    permissionManager.requestPermissionWithEducation()
                }
                
                // Reset the flag after a delay to prevent double-triggering
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    await MainActor.run {
                        isHandlingSpaceKey = false
                    }
                }
            }
            
            // Listen for global escape key events
            escapeKeyObserver = NotificationCenter.default.addObserver(
                forName: .escapeKeyPressed,
                object: nil,
                queue: .main
            ) { _ in
                if audioRecorder.isRecording {
                    // Cancel recording
                    audioRecorder.cancelRecording()
                    isProcessing = false
                } else if isProcessing {
                    // Cancel processing task
                    processingTask?.cancel()
                    isProcessing = false
                } else {
                    // Hide window - use reliable window finding method
                    let recordWindow = NSApp.windows.first { window in
                        window.title == "AudioWhisper Recording"
                    }
                    
                    if let window = recordWindow {
                        window.orderOut(nil)
                    } else {
                        // Fallback to key window if title search fails
                        NSApplication.shared.keyWindow?.orderOut(nil)
                    }
                    
                    // Notify app delegate to restore focus to previous app
                    NotificationCenter.default.post(name: .restoreFocusToPreviousApp, object: nil)
                    
                    // Reset success state
                    showSuccess = false
                }
            }
            
            // Listen for Return key to paste when in success state
            returnKeyObserver = NotificationCenter.default.addObserver(
                forName: .returnKeyPressed,
                object: nil,
                queue: .main
            ) { _ in
                if showSuccess {
                    let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
                    if enableSmartPaste {
                        // User pressed Return - trigger paste
                        performUserTriggeredPaste()
                    }
                }
            }
            
            // Listen for target app storage from WindowController
            targetAppObserver = NotificationCenter.default.addObserver(
                forName: .targetAppStored,
                object: nil,
                queue: .main
            ) { notification in
                if let app = notification.object as? NSRunningApplication {
                    targetAppForPaste = app
                }
            }
            
            // Listen for recording start failures from hotkey handler
            recordingFailedObserver = NotificationCenter.default.addObserver(
                forName: .recordingStartFailed,
                object: nil,
                queue: .main
            ) { _ in
                errorMessage = LocalizedStrings.Errors.failedToStartRecording
                showError = true
            }
            
            
            // Listen for window becoming key - combined handler for immediate recording and focus
            windowFocusObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { _ in
                // Ensure window is ready for keyboard input
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if let window = NSApp.keyWindow {
                        window.makeFirstResponder(window.contentView)
                    }
                }
                
                // Immediate recording is now handled by the hotkey handler in AudioWhisperApp
            }
            
            // Listen for retry transcription requests
            retryObserver = NotificationCenter.default.addObserver(
                forName: .retryTranscriptionRequested,
                object: nil,
                queue: .main
            ) { _ in
                retryLastTranscription()
            }
            
            // Listen for show audio file requests
            showAudioFileObserver = NotificationCenter.default.addObserver(
                forName: .showAudioFileRequested,
                object: nil,
                queue: .main
            ) { _ in
                showLastAudioFile()
            }
        }
        .onDisappear {
            // Clean up observers to prevent memory leaks
            if let observer = transcriptionProgressObserver {
                NotificationCenter.default.removeObserver(observer)
                transcriptionProgressObserver = nil
            }
            
            if let observer = spaceKeyObserver {
                NotificationCenter.default.removeObserver(observer)
                spaceKeyObserver = nil
            }
            
            if let observer = escapeKeyObserver {
                NotificationCenter.default.removeObserver(observer)
                escapeKeyObserver = nil
            }
            
            if let observer = returnKeyObserver {
                NotificationCenter.default.removeObserver(observer)
                returnKeyObserver = nil
            }
            
            if let observer = targetAppObserver {
                NotificationCenter.default.removeObserver(observer)
                targetAppObserver = nil
            }
            
            if let observer = recordingFailedObserver {
                NotificationCenter.default.removeObserver(observer)
                recordingFailedObserver = nil
            }
            
            if let observer = windowFocusObserver {
                NotificationCenter.default.removeObserver(observer)
                windowFocusObserver = nil
            }
            
            if let observer = retryObserver {
                NotificationCenter.default.removeObserver(observer)
                retryObserver = nil
            }
            
            if let observer = showAudioFileObserver {
                NotificationCenter.default.removeObserver(observer)
                showAudioFileObserver = nil
            }
            
            // Cancel any running processing task
            processingTask?.cancel()
            processingTask = nil
            
            // Clear audio URL to prevent memory retention
            lastAudioURL = nil
        }
        .onChange(of: audioRecorder.isRecording) { oldValue, recording in
            updateStatus()
        }
        .onChange(of: isProcessing) { _, _ in
            updateStatus()
        }
        .onChange(of: progressMessage) { _, _ in
            updateStatus()
        }
        .onChange(of: audioRecorder.hasPermission) { _, _ in
            updateStatus()
        }
        .onChange(of: showSuccess) { _, _ in
            updateStatus()
        }
        .onChange(of: showError) { _, newValue in
            updateStatus()
            if newValue {
                showErrorAlert()
            }
        }
        .onChange(of: permissionManager.allPermissionsGranted) { _, granted in
            // Sync permission manager state with audio recorder
            audioRecorder.hasPermission = (permissionManager.microphonePermissionState == .granted)
            updateStatus()
        }
        .onAppear {
            // Initialize permission state
            permissionManager.checkPermissionState()
            updateStatus()
        }
    }
    
    // MARK: - Progress Enhancement
    
    private func enhanceProgressMessage(_ message: String) -> String {
        // Simply return the message without elapsed time since it's not dynamically updated
        return message
    }
    
    // MARK: - Status Management
    
    private func updateStatus() {
        statusViewModel.updateStatus(
            isRecording: audioRecorder.isRecording,
            isProcessing: isProcessing,
            progressMessage: progressMessage,
            hasPermission: audioRecorder.hasPermission,
            showSuccess: showSuccess,
            errorMessage: showError ? errorMessage : nil
        )
    }
    
    // MARK: - Paste Management
    
    private func performUserTriggeredPaste() {
        guard let targetApp = findValidTargetApp() else {
            showSuccess = false
            hideRecordingWindow()
            return
        }
        
        // Small delay to ensure Return key event is fully consumed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Hide window after ensuring key event is consumed
            self.hideRecordingWindow()
            
            // Then activate target app and paste
            self.activateTargetAppAndPaste(targetApp)
        }
    }
    
    private func findValidTargetApp() -> NSRunningApplication? {
        // Try stored target app first
        var targetApp = WindowController.storedTargetApp
        if targetApp == nil {
            targetApp = targetAppForPaste
        }
        
        // Verify the stored app is still running and valid
        if let stored = targetApp, stored.isTerminated {
            targetApp = nil
        }
        
        // Fallback: find a suitable app, avoiding known problematic ones
        if targetApp == nil {
            targetApp = findFallbackTargetApp()
        }
        
        return targetApp
    }
    
    private func findFallbackTargetApp() -> NSRunningApplication? {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        return runningApps.first { app in
            app.bundleIdentifier != Bundle.main.bundleIdentifier &&
            app.bundleIdentifier != "com.tinyspeck.slackmacgap" &&
            app.bundleIdentifier != "com.cron.electron" &&  // Notion Calendar
            app.activationPolicy == .regular &&
            !app.isTerminated
        }
    }
    
    private func hideRecordingWindow() {
        let recordWindow = NSApp.windows.first { window in
            window.title == "AudioWhisper Recording"
        }
        if let window = recordWindow {
            window.orderOut(nil)
        } else {
            NSApplication.shared.keyWindow?.orderOut(nil)
        }
    }
    
    private func activateTargetAppAndPaste(_ target: NSRunningApplication) {
        Task { @MainActor in
            do {
                // Activate the target app and wait for it to become active
                try await activateApplication(target)
                
                // Perform paste operation with completion handling
                await pasteManager.pasteWithCompletionHandler()
                
                // Reset success state after paste completes
                self.showSuccess = false
            } catch {
                // Failed to activate app and paste - error already handled above
                self.showSuccess = false
            }
        }
    }
    
    private func activateApplication(_ target: NSRunningApplication) async throws {
        // Try direct activation first
        let success = target.activate(options: [])
        
        if !success {
            // Try fallback activation through NSWorkspace
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
                throw NSError(domain: "AudioWhisper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to activate target application"])
            }
        }
        
        // Wait for the app to become active using notification observer
        await waitForApplicationActivation(target)
    }
    
    private func waitForApplicationActivation(_ target: NSRunningApplication) async {
        // If already active, return immediately
        if target.isActive {
            return
        }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let observerBox = ObserverBox()
            
            // Set up timeout  
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                if let observer = observerBox.observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume()
            }
            
            // Observe app activation
            observerBox.observer = NotificationCenter.default.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   activatedApp.processIdentifier == target.processIdentifier {
                    timeoutTask.cancel()
                    if let observer = observerBox.observer {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    // Removed attemptFallbackActivation - integrated into activateApplication method
    
    // MARK: - Recording Management
    
    private func startRecording() {
        if !audioRecorder.hasPermission {
            permissionManager.requestPermissionWithEducation()
            return
        }
        
        // Clear previous audio URL when starting new recording
        lastAudioURL = nil
        
        // Note: Target app is already stored by WindowController.storePreviousApp() when window is shown
        // We don't need to store it again here since AudioWhisper may already be frontmost
        
        let success = audioRecorder.startRecording()
        if !success {
            errorMessage = LocalizedStrings.Errors.failedToStartRecording
            showError = true
        }
    }
    
    private func stopAndProcess() {
        // Cancel any existing processing task
        processingTask?.cancel()
        
        // Notify that recording has stopped (for menu bar icon update in hotkey mode)
        NotificationCenter.default.post(name: .recordingStopped, object: nil)
        
        processingTask = Task {
            isProcessing = true
            transcriptionStartTime = Date()
            progressMessage = "Preparing audio..."
            
            do {
                // Check for cancellation before starting
                try Task.checkCancellation()
                guard let audioURL = audioRecorder.stopRecording() else {
                    throw NSError(domain: "AudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: LocalizedStrings.Errors.failedToGetRecordingURL])
                }
                
                // Check if we got a valid recording URL
                guard !audioURL.path.isEmpty else {
                    throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: LocalizedStrings.Errors.recordingURLEmpty])
                }
                
                // Store the audio URL for potential retry
                lastAudioURL = audioURL
                
                // Check for cancellation before transcription
                try Task.checkCancellation()
                
                // Convert to text using selected provider and model
                let text: String
                if transcriptionProvider == .local {
                    text = try await speechService.transcribe(audioURL: audioURL, provider: transcriptionProvider, model: selectedWhisperModel)
                } else {
                    text = try await speechService.transcribe(audioURL: audioURL, provider: transcriptionProvider)
                }
                
                // Check for cancellation after transcription
                try Task.checkCancellation()
                
                // Save transcription to history if enabled
                if DataManager.shared.isHistoryEnabled {
                    let duration = transcriptionStartTime.map { Date().timeIntervalSince($0) }
                    let modelUsed = transcriptionProvider == .local ? selectedWhisperModel.rawValue : nil
                    
                    let record = TranscriptionRecord(
                        text: text,
                        provider: transcriptionProvider,
                        duration: duration,
                        modelUsed: modelUsed
                    )
                    
                    // Save quietly to avoid disrupting the transcription flow
                    await DataManager.shared.saveTranscriptionQuietly(record)
                }
                
                // Copy to clipboard
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                
                // Show confirmation and close
                await MainActor.run {
                    transcriptionStartTime = nil
                    showConfirmationAndPaste(text: text)
                }
            } catch is CancellationError {
                // Handle cancellation gracefully
                await MainActor.run {
                    isProcessing = false
                    transcriptionStartTime = nil
                    // Don't show error for intentional cancellation
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
    
    private func showConfirmationAndPaste(text: String) {
        // Show success state
        showSuccess = true
        isProcessing = false
        
        // Play gentle completion sound
        soundManager.playCompletionSound()
        
        // Handle auto-dismiss based on SmartPaste setting
        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
        if enableSmartPaste {
            // Automatically trigger paste after minimal delay
            // This associates the paste with the user's stop recording action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                performUserTriggeredPaste()
            }
        } else {
            // Restore focus to previous app when SmartPaste is disabled
            NotificationCenter.default.post(name: .restoreFocusToPreviousApp, object: nil)
            
            // Auto-dismiss after 2 seconds when SmartPaste is disabled
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let recordWindow = NSApp.windows.first { window in
                    window.title == "AudioWhisper Recording"
                }
                
                if let window = recordWindow {
                    window.orderOut(nil)
                } else {
                    // Fallback to key window if title search fails
                    NSApplication.shared.keyWindow?.orderOut(nil)
                }
                
                // Notify app delegate to restore focus to previous app
                NotificationCenter.default.post(name: .restoreFocusToPreviousApp, object: nil)
                
                // Reset success state
                showSuccess = false
            }
        }
    }
    
    // MARK: - Retry and Audio File Management
    
    private func retryLastTranscription() {
        // Prevent multiple concurrent retry attempts
        guard !isProcessing else {
            return
        }
        
        guard let audioURL = lastAudioURL else {
            errorMessage = "No audio file available to retry. Please record again."
            showError = true
            return
        }
        
        // Check if the audio file still exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            errorMessage = "Audio file no longer exists. Please record again."
            showError = true
            // Clear the invalid URL
            lastAudioURL = nil
            return
        }
        
        // Cancel any existing processing task
        processingTask?.cancel()
        
        // Retry transcription with the stored audio URL
        processingTask = Task {
            isProcessing = true
            transcriptionStartTime = Date()
            progressMessage = "Retrying transcription..."
            
            do {
                try Task.checkCancellation()
                
                // Convert to text using selected provider and model
                let text: String
                if transcriptionProvider == .local {
                    text = try await speechService.transcribe(audioURL: audioURL, provider: transcriptionProvider, model: selectedWhisperModel)
                } else {
                    text = try await speechService.transcribe(audioURL: audioURL, provider: transcriptionProvider)
                }
                
                // Check for cancellation after transcription
                try Task.checkCancellation()
                
                // Save transcription to history if enabled
                if DataManager.shared.isHistoryEnabled {
                    let duration = transcriptionStartTime.map { Date().timeIntervalSince($0) }
                    let modelUsed = transcriptionProvider == .local ? selectedWhisperModel.rawValue : nil
                    
                    let record = TranscriptionRecord(
                        text: text,
                        provider: transcriptionProvider,
                        duration: duration,
                        modelUsed: modelUsed
                    )
                    
                    // Save quietly to avoid disrupting the transcription flow
                    await DataManager.shared.saveTranscriptionQuietly(record)
                }
                
                // Copy to clipboard
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                
                // Show confirmation and close
                await MainActor.run {
                    transcriptionStartTime = nil
                    showConfirmationAndPaste(text: text)
                }
            } catch is CancellationError {
                // Handle cancellation gracefully
                await MainActor.run {
                    isProcessing = false
                    transcriptionStartTime = nil
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
    
    private func showLastAudioFile() {
        guard let audioURL = lastAudioURL else {
            errorMessage = "No audio file available to show."
            showError = true
            return
        }
        
        // Check if the audio file still exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            errorMessage = "Audio file no longer exists."
            showError = true
            // Clear the invalid URL to prevent memory retention
            lastAudioURL = nil
            return
        }
        
        // Reveal the audio file in Finder
        NSWorkspace.shared.selectFile(audioURL.path, inFileViewerRootedAtPath: audioURL.deletingLastPathComponent().path)
    }
    
}