import SwiftUI
import AVFoundation

internal struct ContentView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @AppStorage(AppDefaults.Keys.transcriptionProvider) var transcriptionProvider = AppDefaults.defaultTranscriptionProvider
    @AppStorage(AppDefaults.Keys.selectedWhisperModel) var selectedWhisperModel = AppDefaults.defaultWhisperModel
    @AppStorage(AppDefaults.Keys.immediateRecording) var immediateRecording = false
    @State var modelManager = ModelManager.shared
    @State var speechService: SpeechToTextService
    @State var pasteManager = PasteManager()
    @State var statusViewModel = StatusViewModel()
    @State var permissionManager = PermissionManager()
    @StateObject var soundManager = SoundManager()
    let semanticCorrectionService = SemanticCorrectionService()
    @State var isProcessing = false
    @State var progressMessage = "Processing..."
    @State var transcriptionStartTime: Date?
    @State var showError = false
    @State var errorMessage = ""
    @State var showSuccess = false
    @State var isHovered = false
    @State var isHandlingSpaceKey = false
    @State var processingTask: Task<Void, Never>?
    @State var transcriptionProgressObserver: NSObjectProtocol?
    @State var spaceKeyObserver: NSObjectProtocol?
    @State var escapeKeyObserver: NSObjectProtocol?
    @State var returnKeyObserver: NSObjectProtocol?
    @State var targetAppObserver: NSObjectProtocol?
    @State var recordingFailedObserver: NSObjectProtocol?
    @State var targetAppForPaste: NSRunningApplication?
    @State var windowFocusObserver: NSObjectProtocol?
    @State var retryObserver: NSObjectProtocol?
    @State var showAudioFileObserver: NSObjectProtocol?
    @State var transcribeFileObserver: NSObjectProtocol?
    @State var lastAudioURL: URL?
    @State var awaitingSemanticPaste = false
    @State var lastSourceAppInfo: SourceAppInfo?
    @AppStorage("hasShownFirstModelUseHint") var hasShownFirstModelUseHint = false
    @State var showFirstModelUseHint = false
    
    init(speechService: SpeechToTextService = SpeechToTextService(), audioRecorder: AudioRecorder) {
        self._speechService = State(initialValue: speechService)
        self.audioRecorder = audioRecorder
    }
    
    private func showErrorAlert() {
        ErrorPresenter.shared.showError(errorMessage)
        showError = false
    }
    
    var body: some View {
        WaveformRecordingView(
            status: statusViewModel.currentStatus,
            audioLevel: audioRecorder.audioLevel,
            onTap: {
                if audioRecorder.isRecording {
                    stopAndProcess()
                } else if showSuccess {
                    let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
                    if enableSmartPaste {
                        performUserTriggeredPaste()
                    } else {
                        showSuccess = false
                    }
                } else if !audioRecorder.hasPermission {
                    permissionManager.requestPermissionWithEducation()
                } else {
                    startRecording()
                }
            }
        )
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
        .onAppear { handleOnAppear() }
        .onDisappear { handleOnDisappear() }
        .onChange(of: audioRecorder.isRecording) { _, _ in
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
        .onChange(of: transcriptionProvider) { _, _ in
            if transcriptionProvider == .local {
                startWhisperModelDownloadIfNeeded(selectedWhisperModel)
            }
            updateStatus()
        }
        .onChange(of: selectedWhisperModel) { _, _ in
            if transcriptionProvider == .local {
                startWhisperModelDownloadIfNeeded(selectedWhisperModel)
            }
            updateStatus()
        }
        .onChange(of: modelManager.downloadStages[selectedWhisperModel]?.displayText ?? "") { _, _ in
            updateStatus()
        }
        .onChange(of: modelManager.downloadingModels.contains(selectedWhisperModel)) { _, _ in
            updateStatus()
        }
        .onChange(of: showError) { _, newValue in
            updateStatus()
            if newValue {
                showErrorAlert()
            }
        }
        .onChange(of: permissionManager.allPermissionsGranted) { _, _ in
            audioRecorder.hasPermission = (permissionManager.microphonePermissionState == .granted)
            updateStatus()
        }
    }
}
