import SwiftUI
import AVFoundation

internal struct ContentView: View {
    // MARK: - Core Dependencies

    @ObservedObject var audioRecorder: AudioEngineRecorder
    @State var viewModel: RecordingViewModel
    @EnvironmentObject var windowCoordinator: WindowCoordinator
    @Environment(PermissionManager.self) var permissionManager

    // MARK: - Persisted Settings (AppStorage)

    @AppStorage("transcriptionProvider") var transcriptionProvider = TranscriptionProvider.parakeet
    @AppStorage("selectedWhisperModel") var selectedWhisperModel = WhisperModel.base
    @AppStorage("immediateRecording") var immediateRecording = true
    @AppStorage("hasShownFirstModelUseHint") var hasShownFirstModelUseHint = false

    // MARK: - View-Local State

    @State var isHovered = false
    @State var processingTask: Task<Void, Never>?
    @State var notificationCoordinator = NotificationCoordinator()

    // MARK: - Read-Only Forwarder
    //
    // `isProcessing` is intentionally read-only from the view: the underlying
    // `RecordingViewModel.isProcessing` has a `private(set)` setter, so writes
    // from the view layer must be discarded. The remaining state lives on the
    // view-model and is accessed directly via `viewModel.xxx` at the call sites.
    var isProcessing: Bool {
        get { viewModel.isProcessing }
        nonmutating set { /* read-only from view; VM owns the write */ }
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
        ErrorPresenter.shared.showError(viewModel.errorMessage)
        viewModel.showError = false
    }

    var body: some View {
        WaveformContainer(
            status: viewModel.statusViewModel.currentStatus,
            audioLevel: audioRecorder.audioLevel,
            waveformSamples: audioRecorder.waveformSamples,
            frequencyBands: audioRecorder.frequencyBands,
            onTap: {
                if audioRecorder.isRecording {
                    stopAndProcess()
                } else if viewModel.showSuccess {
                    let enableSmartPaste = AppDefaults.enableSmartPaste
                    if enableSmartPaste {
                        performUserTriggeredPaste()
                    } else {
                        viewModel.showSuccess = false
                    }
                } else if permissionManager.microphonePermissionState != .granted {
                    permissionManager.requestPermissionWithEducation()
                } else {
                    startRecording()
                }
            }
        )
        .overlay(alignment: .top) {
            // Audit item A4: surface silent correction failures inline so the
            // user knows raw text was used. Sits just above the success/status
            // indicator; auto-clears via the timer in
            // RecordingViewModel.presentCorrectionFailure().
            if let message = viewModel.correctionFailedMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.orange.opacity(0.85))
                    )
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityLabel(Text(message))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.correctionFailedMessage)
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
        .onChange(of: viewModel.isProcessing) { _, _ in
            updateStatus()
        }
        .onChange(of: viewModel.progressMessage) { _, _ in
            updateStatus()
        }
        .onChange(of: permissionManager.microphonePermissionState) { _, _ in
            updateStatus()
        }
        .onChange(of: viewModel.showSuccess) { _, _ in
            updateStatus()
        }
        .onChange(of: viewModel.showError) { _, newValue in
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
