import SwiftUI
import AVFoundation

internal struct ContentView: View {
    // MARK: - Core Dependencies

    @ObservedObject var audioRecorder: AudioEngineRecorder
    @State var viewModel: RecordingViewModel
    var permissionManager: PermissionManager { PermissionManager.shared }

    // MARK: - Persisted Settings (AppStorage)

    @AppStorage("transcriptionProvider") var transcriptionProvider = TranscriptionProvider.parakeet
    @AppStorage("selectedWhisperModel") var selectedWhisperModel = WhisperModel.base
    @AppStorage("immediateRecording") var immediateRecording = true
    @AppStorage("hasShownFirstModelUseHint") var hasShownFirstModelUseHint = false

    // MARK: - View-Local State

    @State var isHovered = false
    @State var processingTask: Task<Void, Never>?
    @State var notificationCoordinator = NotificationCoordinator()

    // MARK: - Computed Properties (forwarding to ViewModel)

    var speechService: SpeechToTextService { viewModel.speechService }
    var pasteManager: PasteManager { viewModel.pasteManager }
    var statusViewModel: StatusViewModel { viewModel.statusViewModel }
    var semanticCorrectionService: SemanticCorrectionService { viewModel.semanticCorrectionService }
    var soundManager: SoundManager { viewModel.soundManager }

    var isProcessing: Bool {
        get { viewModel.isProcessing }
        nonmutating set { /* read-only from view */ }
    }
    var progressMessage: String {
        get { viewModel.progressMessage }
        nonmutating set { viewModel.progressMessage = newValue }
    }
    var transcriptionStartTime: Date? {
        get { viewModel.transcriptionStartTime }
        nonmutating set { viewModel.transcriptionStartTime = newValue }
    }
    var showError: Bool {
        get { viewModel.showError }
        nonmutating set { viewModel.showError = newValue }
    }
    var errorMessage: String {
        get { viewModel.errorMessage }
        nonmutating set { viewModel.errorMessage = newValue }
    }
    var showSuccess: Bool {
        get { viewModel.showSuccess }
        nonmutating set { viewModel.showSuccess = newValue }
    }
    var isHandlingSpaceKey: Bool {
        get { viewModel.isHandlingSpaceKey }
        nonmutating set { viewModel.isHandlingSpaceKey = newValue }
    }
    var targetAppForPaste: NSRunningApplication? {
        get { viewModel.targetAppForPaste }
        nonmutating set { viewModel.targetAppForPaste = newValue }
    }
    var lastAudioURL: URL? {
        get { viewModel.lastAudioURL }
        nonmutating set { viewModel.lastAudioURL = newValue }
    }
    var awaitingSemanticPaste: Bool {
        get { viewModel.awaitingSemanticPaste }
        nonmutating set { viewModel.awaitingSemanticPaste = newValue }
    }
    var lastSourceAppInfo: SourceAppInfo? {
        get { viewModel.lastSourceAppInfo }
        nonmutating set { viewModel.lastSourceAppInfo = newValue }
    }
    var showFirstModelUseHint: Bool {
        get { viewModel.showFirstModelUseHint }
        nonmutating set { viewModel.showFirstModelUseHint = newValue }
    }

    // MARK: - Initialization

    init(speechService: SpeechToTextService = SpeechToTextService(), audioRecorder: AudioEngineRecorder) {
        self._audioRecorder = ObservedObject(wrappedValue: audioRecorder)
        self._viewModel = State(initialValue: RecordingViewModel(
            speechService: speechService,
            pasteManager: PasteManager(),
            semanticCorrectionService: SemanticCorrectionService(),
            soundManager: SoundManager(),
            statusViewModel: StatusViewModel()
        ))
    }

    /// Test-friendly initializer that accepts a custom ViewModel
    init(viewModel: RecordingViewModel, audioRecorder: AudioEngineRecorder) {
        self._audioRecorder = ObservedObject(wrappedValue: audioRecorder)
        self._viewModel = State(initialValue: viewModel)
    }
    
    private func showErrorAlert() {
        ErrorPresenter.shared.showError(errorMessage)
        showError = false
    }
    
    var body: some View {
        WaveformContainer(
            status: statusViewModel.currentStatus,
            audioLevel: audioRecorder.audioLevel,
            waveformSamples: audioRecorder.waveformSamples,
            frequencyBands: audioRecorder.frequencyBands,
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
                } else if permissionManager.microphonePermissionState != .granted {
                    permissionManager.requestPermissionWithEducation()
                } else {
                    startRecording()
                }
            }
        )
        .sheet(isPresented: Binding(
            get: { permissionManager.showEducationalModal },
            set: { permissionManager.showEducationalModal = $0 }
        )) {
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
        .sheet(isPresented: Binding(
            get: { permissionManager.showRecoveryModal },
            set: { permissionManager.showRecoveryModal = $0 }
        )) {
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
        .sheet(isPresented: Binding(
            get: { permissionManager.showAccessibilityModal },
            set: { permissionManager.showAccessibilityModal = $0 }
        )) {
            AccessibilityPermissionModal(
                onAllow: {
                    permissionManager.handleAccessibilityModalResponse(allowed: true)
                },
                onDontAllow: {
                    permissionManager.handleAccessibilityModalResponse(allowed: false)
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
        .onChange(of: permissionManager.microphonePermissionState) { _, _ in
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
        .onChange(of: permissionManager.allPermissionsGranted) { _, _ in
            updateStatus()
        }
    }
}
