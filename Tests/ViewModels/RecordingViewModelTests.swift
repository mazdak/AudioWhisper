import XCTest
@testable import AudioWhisper

/// Tests for RecordingViewModel state management and behavior
@MainActor
final class RecordingViewModelTests: XCTestCase {
    private var mockSpeechService: MockSpeechToTextService!
    private var mockSemanticService: MockSemanticCorrectionService!
    private var mockDataManager: MockDataManager!
    private var mockMetricsStore: MockUsageMetricsStore!
    private var testUserDefaultsSuite: String!
    private var testDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        mockSpeechService = MockSpeechToTextService()
        mockSemanticService = MockSemanticCorrectionService()
        mockDataManager = MockDataManager()
        mockMetricsStore = MockUsageMetricsStore()

        testUserDefaultsSuite = "RecordingViewModelTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testUserDefaultsSuite)
        testDefaults?.removePersistentDomain(forName: testUserDefaultsSuite)
    }

    override func tearDown() async throws {
        mockSpeechService?.reset()
        mockSemanticService?.reset()
        mockDataManager?.reset()
        mockMetricsStore?.resetMock()
        testDefaults?.removePersistentDomain(forName: testUserDefaultsSuite)
        testDefaults = nil
        testUserDefaultsSuite = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() async throws {
        let viewModel = RecordingViewModel()

        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertEqual(viewModel.progressMessage, "Processing...")
        XCTAssertNil(viewModel.transcriptionStartTime)
        XCTAssertFalse(viewModel.showError)
        XCTAssertEqual(viewModel.errorMessage, "")
        XCTAssertFalse(viewModel.showSuccess)
        XCTAssertFalse(viewModel.isHandlingSpaceKey)
        XCTAssertFalse(viewModel.showFirstModelUseHint)
        XCTAssertNil(viewModel.targetAppForPaste)
        XCTAssertNil(viewModel.lastAudioURL)
        XCTAssertFalse(viewModel.awaitingSemanticPaste)
        XCTAssertNil(viewModel.lastSourceAppInfo)
    }

    func testDependencyInjection() async throws {
        let speechService = SpeechToTextService()
        let pasteManager = PasteManager()
        let semanticService = SemanticCorrectionService()
        let soundManager = SoundManager()
        let statusViewModel = StatusViewModel()

        let viewModel = RecordingViewModel(
            speechService: speechService,
            pasteManager: pasteManager,
            semanticCorrectionService: semanticService,
            soundManager: soundManager,
            statusViewModel: statusViewModel
        )

        XCTAssertNotNil(viewModel.speechService)
        XCTAssertNotNil(viewModel.pasteManager)
        XCTAssertNotNil(viewModel.semanticCorrectionService)
        XCTAssertNotNil(viewModel.soundManager)
        XCTAssertNotNil(viewModel.statusViewModel)
    }

    // MARK: - State Mutation Tests

    func testProgressMessageUpdate() async throws {
        let viewModel = RecordingViewModel()

        viewModel.progressMessage = "Transcribing..."
        XCTAssertEqual(viewModel.progressMessage, "Transcribing...")

        viewModel.progressMessage = "Semantic correction..."
        XCTAssertEqual(viewModel.progressMessage, "Semantic correction...")
    }

    func testErrorStateUpdate() async throws {
        let viewModel = RecordingViewModel()

        viewModel.errorMessage = "Test error"
        viewModel.showError = true

        XCTAssertEqual(viewModel.errorMessage, "Test error")
        XCTAssertTrue(viewModel.showError)

        viewModel.showError = false
        XCTAssertFalse(viewModel.showError)
    }

    func testSuccessStateUpdate() async throws {
        let viewModel = RecordingViewModel()

        viewModel.showSuccess = true
        XCTAssertTrue(viewModel.showSuccess)

        viewModel.showSuccess = false
        XCTAssertFalse(viewModel.showSuccess)
    }

    func testTranscriptionStartTime() async throws {
        let viewModel = RecordingViewModel()

        let now = Date()
        viewModel.transcriptionStartTime = now

        XCTAssertEqual(viewModel.transcriptionStartTime, now)

        viewModel.transcriptionStartTime = nil
        XCTAssertNil(viewModel.transcriptionStartTime)
    }

    // MARK: - Source App Info Tests

    func testCurrentSourceAppInfoReturnsValidInfoWhenNoCachedInfo() async throws {
        let viewModel = RecordingViewModel()

        // When no cached info and no stored target app
        WindowController.storedTargetApp = nil
        viewModel.targetAppForPaste = nil

        let info = viewModel.currentSourceAppInfo()

        // Should return some valid info (either unknown or a fallback app)
        // Note: During tests, findFallbackTargetApp may find a running app
        XCTAssertNotNil(info.bundleIdentifier)
        XCTAssertNotNil(info.displayName)
        XCTAssertFalse(info.displayName.isEmpty)
    }

    func testCurrentSourceAppInfoReturnsCachedInfo() async throws {
        let viewModel = RecordingViewModel()

        // Set cached info
        let testInfo = SourceAppInfo(
            bundleIdentifier: "com.test.app",
            displayName: "Test App",
            iconData: nil,
            fallbackSymbolName: nil
        )
        viewModel.lastSourceAppInfo = testInfo

        // Should return cached info
        let info = viewModel.currentSourceAppInfo()
        XCTAssertEqual(info.bundleIdentifier, "com.test.app")
        XCTAssertEqual(info.displayName, "Test App")
    }

    // MARK: - Find Target App Tests

    func testFindValidTargetAppReturnsNilWhenNoAppsAvailable() async throws {
        let viewModel = RecordingViewModel()

        // Clear any stored target app
        WindowController.storedTargetApp = nil
        viewModel.targetAppForPaste = nil

        // Should return a fallback app or nil
        _ = viewModel.findValidTargetApp()

        // Result depends on running apps - just verify it doesn't crash
        // In real usage, it might find a fallback app
    }

    func testFindValidTargetAppSkipsTerminatedApp() async throws {
        let viewModel = RecordingViewModel()

        // This test verifies the logic - actual NSRunningApplication can't be easily mocked
        // The viewModel should handle terminated apps gracefully
        WindowController.storedTargetApp = nil
        viewModel.targetAppForPaste = nil

        _ = viewModel.findValidTargetApp()
        // Should not crash when no valid app found
    }

    // MARK: - Status Update Tests

    func testUpdateStatusUpdatesStatusViewModel() async throws {
        let viewModel = RecordingViewModel()

        viewModel.updateStatus(isRecording: true, hasPermission: true)

        XCTAssertEqual(viewModel.statusViewModel.currentStatus, .recording)
    }

    func testUpdateStatusWithProcessing() async throws {
        let viewModel = RecordingViewModel()
        viewModel.progressMessage = "Processing..."

        viewModel.updateStatus(isRecording: false, hasPermission: true)

        // Status depends on internal isProcessing state
        // Since isProcessing is read-only and private(set), we can't directly set it
        // This tests the normal flow
    }

    // MARK: - Lifecycle Tests

    func testOnDisappearClearsLastAudioURL() async throws {
        let viewModel = RecordingViewModel()
        viewModel.lastAudioURL = URL(fileURLWithPath: "/tmp/test.m4a")

        viewModel.onDisappear()

        XCTAssertNil(viewModel.lastAudioURL)
    }

    // MARK: - Space Key Handling Tests

    func testIsHandlingSpaceKeyState() async throws {
        let viewModel = RecordingViewModel()

        XCTAssertFalse(viewModel.isHandlingSpaceKey)

        viewModel.isHandlingSpaceKey = true
        XCTAssertTrue(viewModel.isHandlingSpaceKey)

        viewModel.isHandlingSpaceKey = false
        XCTAssertFalse(viewModel.isHandlingSpaceKey)
    }

    // MARK: - Paste State Tests

    func testAwaitingSemanticPasteState() async throws {
        let viewModel = RecordingViewModel()

        XCTAssertFalse(viewModel.awaitingSemanticPaste)

        viewModel.awaitingSemanticPaste = true
        XCTAssertTrue(viewModel.awaitingSemanticPaste)

        viewModel.awaitingSemanticPaste = false
        XCTAssertFalse(viewModel.awaitingSemanticPaste)
    }

    // MARK: - First Model Use Hint Tests

    func testShowFirstModelUseHintState() async throws {
        let viewModel = RecordingViewModel()

        XCTAssertFalse(viewModel.showFirstModelUseHint)

        viewModel.showFirstModelUseHint = true
        XCTAssertTrue(viewModel.showFirstModelUseHint)

        viewModel.showFirstModelUseHint = false
        XCTAssertFalse(viewModel.showFirstModelUseHint)
    }
}
