import XCTest
@testable import AudioWhisper

@MainActor
final class ProviderSettingsStateTests: XCTestCase {

    private var state: ProviderSettingsState!

    override func setUp() {
        super.setUp()
        state = ProviderSettingsState()
    }

    override func tearDown() {
        state = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialEnvironmentState() {
        XCTAssertFalse(state.envReady)
        XCTAssertFalse(state.isCheckingEnv)
    }

    func testInitialSetupSheetState() {
        XCTAssertFalse(state.showSetupSheet)
        XCTAssertFalse(state.isSettingUp)
        XCTAssertEqual(state.setupLogs, "")
        XCTAssertNil(state.setupStatus)
    }

    func testInitialParakeetState() {
        XCTAssertNil(state.parakeetVerifyMessage)
        XCTAssertFalse(state.isVerifyingParakeet)
    }

    func testInitialModelDownloadState() {
        XCTAssertNil(state.downloadError)
        XCTAssertEqual(state.totalModelsSize, 0)
        XCTAssertTrue(state.downloadedModels.isEmpty)
        XCTAssertTrue(state.modelDownloadStates.isEmpty)
        XCTAssertTrue(state.downloadStartTime.isEmpty)
    }

    func testInitialMLXCorrectionState() {
        XCTAssertFalse(state.isRefreshingMLXModels)
        XCTAssertFalse(state.isVerifyingMLX)
        XCTAssertNil(state.mlxVerifyMessage)
    }

    func testInitialAnimationState() {
        XCTAssertFalse(state.isLoaded)
    }

    // MARK: - Status Info Tests

    func testStatusInfoLocalProviderNoModels() {
        state.downloadedModels = []
        let info = state.statusInfo(for: .local)

        XCTAssertEqual(info.text, "Setup")
        XCTAssertFalse(info.isReady)
    }

    func testStatusInfoLocalProviderWithModels() {
        state.downloadedModels = [.base]
        let info = state.statusInfo(for: .local)

        XCTAssertEqual(info.text, "Ready")
        XCTAssertTrue(info.isReady)
    }

    func testStatusInfoParakeetProviderNotReady() {
        state.envReady = false
        let info = state.statusInfo(for: .parakeet)

        XCTAssertEqual(info.text, "Setup")
        XCTAssertFalse(info.isReady)
    }

    func testStatusInfoParakeetProviderReady() {
        state.envReady = true
        let info = state.statusInfo(for: .parakeet)

        XCTAssertEqual(info.text, "Ready")
        XCTAssertTrue(info.isReady)
    }

    // MARK: - Model Download State Tests

    func testUpdateModelDownloadStateStartsDownload() {
        XCTAssertNil(state.downloadStartTime[.base])

        state.updateModelDownloadState(.base, isDownloading: true)

        XCTAssertNotNil(state.downloadStartTime[.base])
    }

    func testUpdateModelDownloadStateStopsDownload() {
        state.downloadStartTime[.base] = Date()
        XCTAssertNotNil(state.downloadStartTime[.base])

        state.updateModelDownloadState(.base, isDownloading: false)

        XCTAssertNil(state.downloadStartTime[.base])
    }

    func testModelDownloadStatesCanBeSetDirectly() {
        state.modelDownloadStates[.base] = true
        state.modelDownloadStates[.small] = true
        state.modelDownloadStates[.tiny] = false

        XCTAssertEqual(state.modelDownloadStates[.base], true)
        XCTAssertEqual(state.modelDownloadStates[.small], true)
        XCTAssertEqual(state.modelDownloadStates[.tiny], false)
    }

    func testDownloadedModelsCanBeSetDirectly() {
        state.downloadedModels = [.base, .small]

        XCTAssertEqual(state.downloadedModels.count, 2)
        XCTAssertTrue(state.downloadedModels.contains(.base))
        XCTAssertTrue(state.downloadedModels.contains(.small))
    }

    // MARK: - Setup Operation Tests

    func testBeginSetup() {
        state.beginSetup(title: "Setting up Parakeet")

        XCTAssertEqual(state.setupStatus, "Setting up Parakeet")
        XCTAssertEqual(state.setupLogs, "")
        XCTAssertTrue(state.isSettingUp)
        XCTAssertTrue(state.showSetupSheet)
    }

    func testCompleteSetupSuccess() {
        state.beginSetup(title: "Test")
        state.completeSetup(success: true, message: "Setup complete!")

        XCTAssertFalse(state.isSettingUp)
        XCTAssertEqual(state.setupStatus, "Setup complete!")
        XCTAssertTrue(state.envReady)
    }

    func testCompleteSetupFailure() {
        state.envReady = false
        state.beginSetup(title: "Test")
        state.completeSetup(success: false, message: "Setup failed!")

        XCTAssertFalse(state.isSettingUp)
        XCTAssertEqual(state.setupStatus, "Setup failed!")
        XCTAssertFalse(state.envReady)
    }

    func testAppendSetupLogToEmpty() {
        XCTAssertEqual(state.setupLogs, "")

        state.appendSetupLog("First log")

        XCTAssertEqual(state.setupLogs, "First log")
    }

    func testAppendSetupLogToExisting() {
        state.setupLogs = "First log"

        state.appendSetupLog("Second log")

        XCTAssertEqual(state.setupLogs, "First log\nSecond log")
    }

    func testAppendSetupLogMultiple() {
        state.appendSetupLog("Line 1")
        state.appendSetupLog("Line 2")
        state.appendSetupLog("Line 3")

        XCTAssertEqual(state.setupLogs, "Line 1\nLine 2\nLine 3")
    }

    func testDismissSetupSheet() {
        state.showSetupSheet = true
        XCTAssertTrue(state.showSetupSheet)

        state.dismissSetupSheet()

        XCTAssertFalse(state.showSetupSheet)
    }

    // MARK: - Reset Tests

    func testResetClearsAllState() {
        // Set various state values
        state.envReady = true
        state.isCheckingEnv = true
        state.showSetupSheet = true
        state.isSettingUp = true
        state.setupLogs = "Some logs"
        state.setupStatus = "Status"
        state.parakeetVerifyMessage = "Verified"
        state.isVerifyingParakeet = true
        state.downloadError = "Error"
        state.totalModelsSize = 1000
        state.downloadedModels = [.base]
        state.modelDownloadStates[.base] = true
        state.downloadStartTime[.base] = Date()
        state.isRefreshingMLXModels = true
        state.isVerifyingMLX = true
        state.mlxVerifyMessage = "MLX OK"
        state.isLoaded = true

        // Reset
        state.reset()

        // Verify all reset to initial state
        XCTAssertFalse(state.envReady)
        XCTAssertFalse(state.isCheckingEnv)
        XCTAssertFalse(state.showSetupSheet)
        XCTAssertFalse(state.isSettingUp)
        XCTAssertEqual(state.setupLogs, "")
        XCTAssertNil(state.setupStatus)
        XCTAssertNil(state.parakeetVerifyMessage)
        XCTAssertFalse(state.isVerifyingParakeet)
        XCTAssertNil(state.downloadError)
        XCTAssertEqual(state.totalModelsSize, 0)
        XCTAssertTrue(state.downloadedModels.isEmpty)
        XCTAssertTrue(state.modelDownloadStates.isEmpty)
        XCTAssertTrue(state.downloadStartTime.isEmpty)
        XCTAssertFalse(state.isRefreshingMLXModels)
        XCTAssertFalse(state.isVerifyingMLX)
        XCTAssertNil(state.mlxVerifyMessage)
        XCTAssertFalse(state.isLoaded)
    }

    // MARK: - Environment Check Tests

    func testCheckEnvReadySetsCheckingFlag() {
        XCTAssertFalse(state.isCheckingEnv)

        state.checkEnvReady()

        XCTAssertTrue(state.isCheckingEnv)
    }

    // MARK: - State Transitions Tests

    func testFullSetupFlowTransitions() {
        // Initial state
        XCTAssertFalse(state.showSetupSheet)
        XCTAssertFalse(state.isSettingUp)

        // Begin setup
        state.beginSetup(title: "Installing dependencies")
        XCTAssertTrue(state.showSetupSheet)
        XCTAssertTrue(state.isSettingUp)

        // Add logs during setup
        state.appendSetupLog("Downloading...")
        state.appendSetupLog("Installing...")
        XCTAssertEqual(state.setupLogs, "Downloading...\nInstalling...")

        // Complete setup
        state.completeSetup(success: true, message: "Done!")
        XCTAssertFalse(state.isSettingUp)
        XCTAssertTrue(state.showSetupSheet) // Sheet still visible to show completion

        // Dismiss sheet
        state.dismissSetupSheet()
        XCTAssertFalse(state.showSetupSheet)
    }

    // MARK: - Multiple Model States Tests

    func testMultipleModelDownloadStates() {
        // Start multiple downloads
        state.updateModelDownloadState(.base, isDownloading: true)
        state.updateModelDownloadState(.small, isDownloading: true)

        XCTAssertNotNil(state.downloadStartTime[.base])
        XCTAssertNotNil(state.downloadStartTime[.small])
        XCTAssertNil(state.downloadStartTime[.tiny])

        // Stop one download
        state.updateModelDownloadState(.base, isDownloading: false)

        XCTAssertNil(state.downloadStartTime[.base])
        XCTAssertNotNil(state.downloadStartTime[.small])
    }

    func testStatusInfoForAllProviders() {
        // Test both providers
        for provider in TranscriptionProvider.allCases {
            let info = state.statusInfo(for: provider)
            XCTAssertFalse(info.text.isEmpty)
        }
    }
}
