import SwiftUI
import AVFoundation
import ApplicationServices

// MARK: - Status Management

enum AppStatus: Equatable {
    case error(String)
    case recording
    case processing(String)
    case success
    case ready
    case permissionRequired
    
    var message: String {
        switch self {
        case .error(let message):
            return message
        case .recording:
            return "Recording..."
        case .processing(let message):
            return message
        case .success:
            return "Success!"
        case .ready:
            return "Ready"
        case .permissionRequired:
            return "Microphone access required"
        }
    }
    
    var color: Color {
        switch self {
        case .error:
            return .red
        case .recording:
            return .red
        case .processing:
            return .orange
        case .success:
            return .green
        case .ready:
            return .blue
        case .permissionRequired:
            return .gray
        }
    }
    
    var icon: String? {
        switch self {
        case .error:
            return "exclamationmark.triangle.fill"
        case .recording:
            return nil // Will use pulsing circle
        case .processing:
            return nil // Will use spinning indicator
        case .success:
            return "checkmark.circle.fill"
        case .ready:
            return nil
        case .permissionRequired:
            return "mic.slash.fill"
        }
    }
    
    var shouldAnimate: Bool {
        switch self {
        case .recording, .processing:
            return true
        default:
            return false
        }
    }
    
    var showInfoButton: Bool {
        switch self {
        case .permissionRequired:
            return true
        default:
            return false
        }
    }
}

class StatusViewModel: ObservableObject {
    @Published var currentStatus: AppStatus = .ready
    
    func updateStatus(
        isRecording: Bool,
        isProcessing: Bool,
        progressMessage: String,
        hasPermission: Bool,
        showSuccess: Bool,
        errorMessage: String? = nil
    ) {
        if let error = errorMessage {
            currentStatus = .error(error)
        } else if showSuccess {
            currentStatus = .success
        } else if isRecording {
            currentStatus = .recording
        } else if isProcessing {
            currentStatus = .processing(progressMessage)
        } else if hasPermission {
            currentStatus = .ready
        } else {
            currentStatus = .permissionRequired
        }
    }
}

// MARK: - Permission Management

enum PermissionState {
    case unknown
    case notRequested
    case requesting
    case granted
    case denied
    case restricted
    
    var needsRequest: Bool {
        switch self {
        case .unknown, .notRequested:
            return true
        default:
            return false
        }
    }
    
    var canRetry: Bool {
        switch self {
        case .denied:
            return true
        default:
            return false
        }
    }
}

class PermissionManager: ObservableObject {
    @Published var permissionState: PermissionState = .unknown
    @Published var showEducationalModal = false
    @Published var showRecoveryModal = false
    
    func checkPermissionState() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        DispatchQueue.main.async {
            switch status {
            case .authorized:
                self.permissionState = .granted
            case .denied:
                self.permissionState = .denied
            case .restricted:
                self.permissionState = .restricted
            case .notDetermined:
                self.permissionState = .notRequested
            @unknown default:
                self.permissionState = .unknown
            }
        }
    }
    
    func requestPermissionWithEducation() {
        if permissionState.needsRequest {
            showEducationalModal = true
        } else if permissionState.canRetry {
            showRecoveryModal = true
        }
    }
    
    func proceedWithPermissionRequest() {
        permissionState = .requesting
        
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionState = granted ? .granted : .denied
                if !granted {
                    // Small delay before showing recovery modal
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.showRecoveryModal = true
                    }
                }
            }
        }
    }
    
    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Status Display Components

struct StatusDisplayView: View {
    let status: AppStatus
    let audioLevel: Float
    let onPermissionInfoTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                StatusIndicator(status: status)
                StatusMessage(status: status)
                
                if status.showInfoButton {
                    Button(action: onPermissionInfoTapped) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Get help with microphone permissions")
                }
            }
            
            // Audio level indicator
            if case .recording = status {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(audioLevel), height: 4)
                            .animation(.easeOut(duration: 0.05), value: audioLevel)
                    }
                }
                .frame(height: 4)
                .accessibilityLabel("Audio level: \(Int(audioLevel * 100)) percent")
            }
        }
    }
}

struct StatusIndicator: View {
    let status: AppStatus
    @State private var isAnimating = false
    
    var body: some View {
        // Fixed size container to prevent any positional animation
        ZStack {
            Color.clear
                .frame(width: 12, height: 12) // Fixed container size
            
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .opacity(status.shouldAnimate ? (isAnimating ? 0.7 : 1.0) : 1.0)
                .onAppear {
                    if status.shouldAnimate {
                        withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    }
                }
                .onChange(of: status.shouldAnimate) { _, shouldAnimate in
                    if shouldAnimate {
                        withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isAnimating = false
                        }
                    }
                }
        }
    }
}

struct StatusMessage: View {
    let status: AppStatus
    
    var body: some View {
        Text(status.message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(status == .permissionRequired ? .secondary : .primary)
            .accessibilityLabel(accessibilityMessage)
    }
    
    private var accessibilityMessage: String {
        switch status {
        case .error(let message):
            return "Error: \(message)"
        case .recording:
            return "Currently recording audio"
        case .processing(let message):
            return "Processing: \(message)"
        case .success:
            return "Transcription completed successfully"
        case .ready:
            return "Ready to record"
        case .permissionRequired:
            return "Microphone permission required to record audio"
        }
    }
}

// MARK: - Recording Button Component

struct RecordingButton: View {
    let isRecording: Bool
    let hasPermission: Bool
    let isProcessing: Bool
    let showSuccess: Bool
    let transcriptionProvider: TranscriptionProvider
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: buttonIcon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(buttonColor)
                )
                .scaleEffect(showSuccess ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: showSuccess)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .disabled(isProcessing || !hasPermission || showSuccess)
        .help(transcriptionProvider.displayName)
        .onHover(perform: onHover)
    }
    
    private var buttonIcon: String {
        if showSuccess {
            return "checkmark"
        } else if isRecording {
            return "stop.fill"
        } else if hasPermission {
            return "mic.fill"
        } else {
            return "mic.slash.fill"
        }
    }
    
    private var buttonColor: Color {
        if showSuccess {
            return .green
        } else if isRecording {
            return .red
        } else if hasPermission {
            return .blue
        } else {
            return .gray
        }
    }
    
    private var accessibilityLabel: String {
        if showSuccess {
            return "Transcription completed successfully"
        } else if isRecording {
            return "Stop recording"
        } else if !hasPermission {
            return "Microphone access required"
        } else if isProcessing {
            return "Processing audio"
        } else {
            return "Start recording"
        }
    }
    
    private var accessibilityHint: String {
        if showSuccess {
            return "Transcription is complete"
        } else if isRecording {
            return "Tap to stop recording audio"
        } else if !hasPermission {
            return "Grant microphone permission to record audio"
        } else if isProcessing {
            return "Please wait while audio is being processed"
        } else {
            return "Tap to start recording audio for transcription"
        }
    }
}

// MARK: - Permission Modal Views

struct PermissionEducationModal: View {
    let onProceed: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
                .accessibilityLabel("Microphone permission required")
            
            VStack(spacing: 12) {
                Text("Microphone Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("AudioWhisper needs access to your microphone to record audio for transcription.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Record high-quality audio", systemImage: "waveform.circle.fill")
                    Label("Process everything locally or in the cloud", systemImage: "cloud.circle.fill")
                    Label("Your audio is never stored permanently", systemImage: "lock.circle.fill")
                }
                .font(.callout)
                .foregroundColor(.primary)
            }
            
            HStack(spacing: 12) {
                Button("Not Now") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Dismiss this dialog without granting microphone permission")
                
                Button("Allow Microphone Access") {
                    onProceed()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Grant microphone permission to start recording audio")
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}

struct PermissionRecoveryModal: View {
    let onOpenSettings: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
                .accessibilityLabel("Warning: Microphone access denied")
            
            VStack(spacing: 12) {
                Text("Microphone Access Denied")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("To use AudioWhisper, you'll need to enable microphone access in System Settings.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("1.")
                            .fontWeight(.semibold)
                        Text("Click 'Open System Settings' below")
                    }
                    
                    HStack {
                        Text("2.")
                            .fontWeight(.semibold)
                        Text("Find AudioWhisper in the microphone list")
                    }
                    
                    HStack {
                        Text("3.")
                            .fontWeight(.semibold)
                        Text("Toggle the switch to enable access")
                    }
                }
                .font(.callout)
                .foregroundColor(.primary)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Dismiss this dialog without opening System Settings")
                
                Button("Open System Settings") {
                    onOpenSettings()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Open macOS System Settings to enable microphone access")
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}

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
    @State private var windowFocusObserver: NSObjectProtocol?
    @State private var windowVisibilityObserver: NSObjectProtocol?
    
    init(speechService: SpeechToTextService = SpeechToTextService()) {
        self._speechService = StateObject(wrappedValue: speechService)
    }
    
    private func showErrorAlert() {
        let alert = NSAlert()
        alert.messageText = LocalizedStrings.Alerts.errorTitle
        alert.informativeText = errorMessage
        alert.alertStyle = .critical
        
        // Add OK button (default)
        alert.addButton(withTitle: "OK")
        
        // Add contextual buttons based on error type
        if errorMessage.contains("API key") {
            alert.addButton(withTitle: "Open Settings")
        } else if errorMessage.contains("microphone") || errorMessage.contains("permission") {
            alert.addButton(withTitle: "Open System Settings")
        } else if errorMessage.contains("internet") || errorMessage.contains("connection") {
            alert.addButton(withTitle: "Try Again")
        }
        
        // Show alert without blocking UI across Spaces
        DispatchQueue.main.async {
            let response = alert.runModal()
            
            // Handle button responses
            if response == .alertSecondButtonReturn {
                if self.errorMessage.contains("API key") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsRequested"), object: nil)
                } else if self.errorMessage.contains("microphone") || self.errorMessage.contains("permission") {
                    self.permissionManager.openSystemSettings()
                } else if self.errorMessage.contains("internet") || self.errorMessage.contains("connection") {
                    if !self.audioRecorder.isRecording && !self.isProcessing {
                        self.startRecording()
                    }
                }
            }
            
            // Reset error state
            self.showError = false
        }
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
        .onKeyPress(.space) {
            // Disabled - using global key monitor instead
            return .ignored
        }
        .onKeyPress(.escape) {
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
            return .handled
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
        
        // Paste the text immediately
        pasteManager.pasteToActiveApp()
        
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