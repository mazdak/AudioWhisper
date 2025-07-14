import SwiftUI
import AVFoundation
import ApplicationServices

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
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
    @State private var windowFocusObserver: NSObjectProtocol?
    @State private var windowVisibilityObserver: NSObjectProtocol?
    
    init(speechService: SpeechToTextService = SpeechToTextService()) {
        self._speechService = StateObject(wrappedValue: speechService)
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
                    } else if !showSuccess {
                        startRecording()
                    }
                },
                onHover: { hovering in
                    isHovered = hovering
                }
            )
            
            // Instruction text below microphone
            if audioRecorder.hasPermission && !showSuccess && !isProcessing && !audioRecorder.isRecording {
                Text(LocalizedStrings.UI.spaceToRecord)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
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
            
            // Start recording immediately if enabled (with a small delay to allow permission check)
            if immediateRecording {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if audioRecorder.hasPermission && !audioRecorder.isRecording && !isProcessing {
                        startRecording()
                    }
                }
            }
            
            // Listen for transcription progress updates
            transcriptionProgressObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("TranscriptionProgress"),
                object: nil,
                queue: .main
            ) { notification in
                if let message = notification.object as? String {
                    progressMessage = enhanceProgressMessage(message)
                }
            }
            
            // Listen for global space key events
            spaceKeyObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("SpaceKeyPressed"),
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
                
                // Reset the flag after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isHandlingSpaceKey = false
                }
            }
            
            // Listen for global escape key events
            escapeKeyObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("EscapeKeyPressed"),
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
                    NotificationCenter.default.post(name: NSNotification.Name("RestoreFocusToPreviousApp"), object: nil)
                    
                    // Reset success state
                    showSuccess = false
                }
            }
            
            // Listen for window becoming visible to handle immediate recording
            windowVisibilityObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { _ in
                // Start recording immediately if enabled and conditions are met
                if immediateRecording && !audioRecorder.isRecording && !isProcessing && audioRecorder.hasPermission && !showSuccess {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if !audioRecorder.isRecording && !isProcessing && audioRecorder.hasPermission {
                            startRecording()
                        }
                    }
                }
            }
            
            // Listen for window focus events to ensure keyboard input works
            windowFocusObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { _ in
                // When window becomes key, ensure it's ready for keyboard input
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if let window = NSApp.keyWindow {
                        window.makeFirstResponder(window.contentView)
                    }
                }
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
            
            if let observer = windowFocusObserver {
                NotificationCenter.default.removeObserver(observer)
                windowFocusObserver = nil
            }
            
            if let observer = windowVisibilityObserver {
                NotificationCenter.default.removeObserver(observer)
                windowVisibilityObserver = nil
            }
            
            // Cancel any running processing task
            processingTask?.cancel()
            processingTask = nil
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
        .onChange(of: permissionManager.permissionState) { _, newState in
            // Sync permission manager state with audio recorder
            audioRecorder.hasPermission = (newState == .granted)
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
    
    // MARK: - Recording Management
    
    private func startRecording() {
        if !audioRecorder.hasPermission {
            permissionManager.requestPermissionWithEducation()
            return
        }
        
        let success = audioRecorder.startRecording()
        if !success {
            errorMessage = LocalizedStrings.Errors.failedToStartRecording
            showError = true
        }
    }
    
    private func stopAndProcess() {
        // Cancel any existing processing task
        processingTask?.cancel()
        
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
        
        // First restore focus to previous app, then paste after a delay
        NotificationCenter.default.post(name: NSNotification.Name("RestoreFocusToPreviousApp"), object: nil)
        
        // Wait for focus restoration before pasting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.pasteManager.pasteToActiveApp()
        }
        
        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Find the recording window reliably by title
            let recordWindow = NSApp.windows.first { window in
                window.title == "AudioWhisper Recording"
            }
            
            if let window = recordWindow {
                window.orderOut(nil)
            } else {
                // Fallback to key window if title search fails
                NSApplication.shared.keyWindow?.orderOut(nil)
            }
            
            // Reset success state for next use
            showSuccess = false
        }
    }
    
}