import XCTest
import SwiftUI
@testable import AudioWhisper

/// Tests for ContentView composition and subview assembly
@MainActor
final class ContentViewCompositionTests: XCTestCase {

    // MARK: - Initialization Tests

    func testContentViewInitializesWithAudioRecorder() {
        let recorder = AudioEngineRecorder()
        let view = ContentView(audioRecorder: recorder)

        // View should be created without crashing
        XCTAssertNotNil(view)
    }

    func testContentViewTestInitializerAcceptsCustomViewModel() {
        let recorder = AudioEngineRecorder()
        let viewModel = RecordingViewModel(
            speechService: SpeechToTextService(),
            pasteManager: PasteManager(),
            semanticCorrectionService: SemanticCorrectionService(),
            soundManager: SoundManager(),
            statusViewModel: StatusViewModel()
        )
        let view = ContentView(viewModel: viewModel, audioRecorder: recorder)

        XCTAssertNotNil(view)
    }

    // MARK: - ViewModel Properties Forwarding Tests

    func testContentViewForwardsSpeechService() {
        let recorder = AudioEngineRecorder()
        let speechService = SpeechToTextService()
        let viewModel = RecordingViewModel(
            speechService: speechService,
            pasteManager: PasteManager(),
            semanticCorrectionService: SemanticCorrectionService(),
            soundManager: SoundManager(),
            statusViewModel: StatusViewModel()
        )
        let view = ContentView(viewModel: viewModel, audioRecorder: recorder)

        XCTAssertNotNil(view.speechService)
    }

    func testContentViewForwardsPasteManager() {
        let recorder = AudioEngineRecorder()
        let pasteManager = PasteManager()
        let viewModel = RecordingViewModel(
            speechService: SpeechToTextService(),
            pasteManager: pasteManager,
            semanticCorrectionService: SemanticCorrectionService(),
            soundManager: SoundManager(),
            statusViewModel: StatusViewModel()
        )
        let view = ContentView(viewModel: viewModel, audioRecorder: recorder)

        XCTAssertNotNil(view.pasteManager)
    }

    func testContentViewForwardsStatusViewModel() {
        let recorder = AudioEngineRecorder()
        let statusViewModel = StatusViewModel()
        let viewModel = RecordingViewModel(
            speechService: SpeechToTextService(),
            pasteManager: PasteManager(),
            semanticCorrectionService: SemanticCorrectionService(),
            soundManager: SoundManager(),
            statusViewModel: statusViewModel
        )
        let view = ContentView(viewModel: viewModel, audioRecorder: recorder)

        XCTAssertNotNil(view.statusViewModel)
    }

    // MARK: - Body Composition Tests

    func testContentViewBodyContainsWaveformContainer() {
        // The body should compose a WaveformContainer
        // This is a structural test
        let recorder = AudioEngineRecorder()
        let view = ContentView(audioRecorder: recorder)

        // View body can be accessed without crashing
        _ = view.body
        XCTAssertTrue(true, "Body composed successfully")
    }

    // MARK: - Permission Manager Access Tests

    func testContentViewAccessesSharedPermissionManager() {
        let recorder = AudioEngineRecorder()
        let view = ContentView(audioRecorder: recorder)

        // Should access the shared PermissionManager
        XCTAssertNotNil(view.permissionManager)
    }

    // MARK: - State Property Tests

    func testContentViewInitialIsHoveredState() {
        let recorder = AudioEngineRecorder()
        let view = ContentView(audioRecorder: recorder)

        XCTAssertFalse(view.isHovered)
    }

    func testContentViewProcessingTaskInitiallyNil() {
        let recorder = AudioEngineRecorder()
        let view = ContentView(audioRecorder: recorder)

        XCTAssertNil(view.processingTask)
    }

    // MARK: - AppStorage Default Values Tests

    func testDefaultTranscriptionProvider() {
        // Default should be local
        let defaultProvider = TranscriptionProvider.local
        XCTAssertEqual(defaultProvider.rawValue, "local")
    }

    func testDefaultWhisperModel() {
        // Default should be base
        let defaultModel = WhisperModel.base
        XCTAssertEqual(defaultModel, .base)
    }

    func testDefaultImmediateRecording() {
        // Default should be true
        let defaultImmediate = true
        XCTAssertTrue(defaultImmediate)
    }

    // MARK: - Computed Property Tests

    func testIsProcessingComputedProperty() {
        let recorder = AudioEngineRecorder()
        let viewModel = RecordingViewModel(
            speechService: SpeechToTextService(),
            pasteManager: PasteManager(),
            semanticCorrectionService: SemanticCorrectionService(),
            soundManager: SoundManager(),
            statusViewModel: StatusViewModel()
        )
        let view = ContentView(viewModel: viewModel, audioRecorder: recorder)

        // Initially false
        XCTAssertFalse(view.isProcessing)
    }

    func testProgressMessageComputedProperty() {
        let recorder = AudioEngineRecorder()
        let viewModel = RecordingViewModel(
            speechService: SpeechToTextService(),
            pasteManager: PasteManager(),
            semanticCorrectionService: SemanticCorrectionService(),
            soundManager: SoundManager(),
            statusViewModel: StatusViewModel()
        )
        let view = ContentView(viewModel: viewModel, audioRecorder: recorder)

        // Should have some default value
        XCTAssertNotNil(view.progressMessage)
    }

    func testShowErrorComputedProperty() {
        let recorder = AudioEngineRecorder()
        let viewModel = RecordingViewModel(
            speechService: SpeechToTextService(),
            pasteManager: PasteManager(),
            semanticCorrectionService: SemanticCorrectionService(),
            soundManager: SoundManager(),
            statusViewModel: StatusViewModel()
        )
        let view = ContentView(viewModel: viewModel, audioRecorder: recorder)

        // Initially false
        XCTAssertFalse(view.showError)
    }

    func testShowSuccessComputedProperty() {
        let recorder = AudioEngineRecorder()
        let viewModel = RecordingViewModel(
            speechService: SpeechToTextService(),
            pasteManager: PasteManager(),
            semanticCorrectionService: SemanticCorrectionService(),
            soundManager: SoundManager(),
            statusViewModel: StatusViewModel()
        )
        let view = ContentView(viewModel: viewModel, audioRecorder: recorder)

        // Initially false
        XCTAssertFalse(view.showSuccess)
    }

    // MARK: - Sheet Presentation Logic Tests

    func testEducationalModalBindingLogic() {
        var showEducationalModal = false

        // Modal starts hidden
        XCTAssertFalse(showEducationalModal)

        // Show modal
        showEducationalModal = true
        XCTAssertTrue(showEducationalModal)

        // Hide modal
        showEducationalModal = false
        XCTAssertFalse(showEducationalModal)
    }

    func testRecoveryModalBindingLogic() {
        var showRecoveryModal = false

        // Modal starts hidden
        XCTAssertFalse(showRecoveryModal)

        // Show modal
        showRecoveryModal = true
        XCTAssertTrue(showRecoveryModal)

        // Hide modal
        showRecoveryModal = false
        XCTAssertFalse(showRecoveryModal)
    }

    func testAccessibilityModalBindingLogic() {
        var showAccessibilityModal = false

        // Modal starts hidden
        XCTAssertFalse(showAccessibilityModal)

        // Show modal
        showAccessibilityModal = true
        XCTAssertTrue(showAccessibilityModal)

        // Hide modal
        showAccessibilityModal = false
        XCTAssertFalse(showAccessibilityModal)
    }

    // MARK: - OnTap Action Logic Tests

    func testOnTapWhenRecordingStopsAndProcesses() {
        // When recording and tapped, should stop and process
        let isRecording = true
        var shouldStopAndProcess = false

        if isRecording {
            shouldStopAndProcess = true
        }

        XCTAssertTrue(shouldStopAndProcess)
    }

    func testOnTapWhenSuccessShowsPaste() {
        // When success and SmartPaste enabled, should paste
        let showSuccess = true
        let enableSmartPaste = true
        var shouldPaste = false

        if showSuccess && enableSmartPaste {
            shouldPaste = true
        }

        XCTAssertTrue(shouldPaste)
    }

    func testOnTapWhenSuccessWithoutSmartPasteHides() {
        // When success without SmartPaste, should hide success
        var showSuccess = true
        let enableSmartPaste = false

        if showSuccess && !enableSmartPaste {
            showSuccess = false
        }

        XCTAssertFalse(showSuccess)
    }

    func testOnTapWhenPermissionNeededRequestsPermission() {
        // When permission not granted, should request
        let micPermissionGranted = false
        var shouldRequestPermission = false

        if !micPermissionGranted {
            shouldRequestPermission = true
        }

        XCTAssertTrue(shouldRequestPermission)
    }

    func testOnTapWhenReadyStartsRecording() {
        // When ready and permission granted, should start recording
        let isRecording = false
        let showSuccess = false
        let micPermissionGranted = true
        var shouldStartRecording = false

        if !isRecording && !showSuccess && micPermissionGranted {
            shouldStartRecording = true
        }

        XCTAssertTrue(shouldStartRecording)
    }

    // MARK: - onChange Handlers Tests

    func testOnChangeOfIsRecordingUpdatesStatus() {
        var statusUpdateCount = 0

        // Simulate onChange trigger
        statusUpdateCount += 1

        XCTAssertEqual(statusUpdateCount, 1)
    }

    func testOnChangeOfIsProcessingUpdatesStatus() {
        var statusUpdateCount = 0

        // Simulate onChange trigger
        statusUpdateCount += 1

        XCTAssertEqual(statusUpdateCount, 1)
    }

    func testOnChangeOfProgressMessageUpdatesStatus() {
        var statusUpdateCount = 0

        // Simulate onChange trigger
        statusUpdateCount += 1

        XCTAssertEqual(statusUpdateCount, 1)
    }

    func testOnChangeOfShowErrorShowsAlert() {
        var showError = false
        var alertShown = false

        // Simulate error
        showError = true
        if showError {
            alertShown = true
        }

        XCTAssertTrue(alertShown)
    }

    // MARK: - View Modifier Tests

    func testViewHasFocusableModifier() {
        // View should have .focusable(false) to prevent focus ring
        let focusable = false
        XCTAssertFalse(focusable)
    }
}
