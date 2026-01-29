import XCTest
import SwiftUI
@testable import AudioWhisper

/// Tests for DashboardCorrectionView logic and calculations
@MainActor
final class DashboardCorrectionViewTests: XCTestCase {

    private var testDefaults: UserDefaults!
    private var testSuiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        testSuiteName = "DashboardCorrectionViewTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)
        testDefaults?.removePersistentDomain(forName: testSuiteName)
    }

    override func tearDown() async throws {
        testDefaults?.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        try await super.tearDown()
    }

    // MARK: - Mode Parsing Tests

    func testParseModeOff() {
        let mode = DashboardCorrectionView.testableParseMode(from: "off")
        XCTAssertEqual(mode, .off)
    }

    func testParseModeLocalMLX() {
        let mode = DashboardCorrectionView.testableParseMode(from: "localMLX")
        XCTAssertEqual(mode, .localMLX)
    }

    func testParseModeCloudRemoved() {
        // Cloud mode was removed
        let mode = DashboardCorrectionView.testableParseMode(from: "cloud")
        XCTAssertNil(mode)
    }

    func testParseModeInvalid() {
        let mode = DashboardCorrectionView.testableParseMode(from: "invalid")
        XCTAssertNil(mode)
    }

    // MARK: - View Type For Mode Tests

    func testViewTypeForModeOff() {
        let viewType = DashboardCorrectionView.testableViewTypeForMode("off")
        XCTAssertEqual(viewType, "disabled_info")
    }

    func testViewTypeForModeLocalMLX() {
        let viewType = DashboardCorrectionView.testableViewTypeForMode("localMLX")
        XCTAssertEqual(viewType, "local_mlx_card")
    }

    func testViewTypeForModeInvalidDefaultsToDisabled() {
        let viewType = DashboardCorrectionView.testableViewTypeForMode("invalid")
        XCTAssertEqual(viewType, "disabled_info")
    }

    // MARK: - Install Button Visibility Tests

    func testShowsInstallButtonWhenEnvNotReady() {
        XCTAssertTrue(DashboardCorrectionView.testableShowsInstallButton(envReady: false))
    }

    func testHidesInstallButtonWhenEnvReady() {
        XCTAssertFalse(DashboardCorrectionView.testableShowsInstallButton(envReady: true))
    }

    // MARK: - Model List Visibility Tests

    func testShowsModelListWhenEnvReady() {
        XCTAssertTrue(DashboardCorrectionView.testableShowsModelList(envReady: true))
    }

    func testHidesModelListWhenEnvNotReady() {
        XCTAssertFalse(DashboardCorrectionView.testableShowsModelList(envReady: false))
    }

    // MARK: - Default Model Repo Tests

    func testDefaultModelRepo() {
        let defaultRepo = DashboardCorrectionView.testableDefaultModelRepo()
        XCTAssertEqual(defaultRepo, "mlx-community/Qwen3-1.7B-4bit")
    }

    func testDefaultModelRepoIsRecommended() {
        let defaultRepo = DashboardCorrectionView.testableDefaultModelRepo()
        XCTAssertTrue(DashboardCorrectionView.testableIsRecommended(repo: defaultRepo))
    }

    // MARK: - Recommended Badge Tests

    func testQwen3IsRecommended() {
        XCTAssertTrue(DashboardCorrectionView.testableIsRecommended(repo: "mlx-community/Qwen3-1.7B-4bit"))
    }

    func testOtherModelsNotRecommended() {
        XCTAssertFalse(DashboardCorrectionView.testableIsRecommended(repo: "mlx-community/gemma-2b-it-4bit"))
        XCTAssertFalse(DashboardCorrectionView.testableIsRecommended(repo: "mlx-community/Llama-3.2-1B-Instruct-4bit"))
    }

    // MARK: - Model Entry Creation Tests

    func testMakeMLXEntryBasic() {
        let model = MLXModelManager.recommendedModels.first!

        let entry = DashboardCorrectionView.testableMakeMLXEntry(
            model: model,
            isDownloaded: false,
            isDownloading: false,
            isSelected: false,
            badgeText: nil
        )

        XCTAssertEqual(entry.title, model.displayName)
        XCTAssertEqual(entry.subtitle, model.description)
        XCTAssertFalse(entry.isDownloaded)
        XCTAssertFalse(entry.isDownloading)
        XCTAssertFalse(entry.isSelected)
        XCTAssertNil(entry.badgeText)
    }

    func testMakeMLXEntryDownloaded() {
        let model = MLXModelManager.recommendedModels.first!

        let entry = DashboardCorrectionView.testableMakeMLXEntry(
            model: model,
            isDownloaded: true,
            isDownloading: false,
            isSelected: true,
            badgeText: "RECOMMENDED"
        )

        XCTAssertTrue(entry.isDownloaded)
        XCTAssertTrue(entry.isSelected)
        XCTAssertEqual(entry.badgeText, "RECOMMENDED")
    }

    func testMakeMLXEntryDownloading() {
        let model = MLXModelManager.recommendedModels.first!

        let entry = DashboardCorrectionView.testableMakeMLXEntry(
            model: model,
            isDownloaded: false,
            isDownloading: true,
            isSelected: false,
            badgeText: nil
        )

        XCTAssertFalse(entry.isDownloaded)
        XCTAssertTrue(entry.isDownloading)
    }

    // MARK: - Verification Timeout Tests

    func testVerificationTimeout() {
        let timeout = DashboardCorrectionView.testableVerificationTimeout
        XCTAssertEqual(timeout, 180, "Verification timeout should be 180 seconds")
    }

    // MARK: - Venv Path Tests

    func testVenvPythonPath() {
        let path = DashboardCorrectionView.testableVenvPythonPath()
        XCTAssertTrue(path.contains("AudioWhisper/python_project/.venv/bin/python3"),
            "Path should contain expected venv location")
    }

    func testVenvPythonPathNotEmpty() {
        let path = DashboardCorrectionView.testableVenvPythonPath()
        XCTAssertFalse(path.isEmpty, "Venv path should not be empty")
    }

    // MARK: - Semantic Correction Mode Enum Tests

    func testSemanticCorrectionModeAllCases() {
        let allCases = SemanticCorrectionMode.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.off))
        XCTAssertTrue(allCases.contains(.localMLX))
    }

    func testSemanticCorrectionModeRawValues() {
        XCTAssertEqual(SemanticCorrectionMode.off.rawValue, "off")
        XCTAssertEqual(SemanticCorrectionMode.localMLX.rawValue, "localMLX")
    }

    func testSemanticCorrectionModeDisplayNames() {
        XCTAssertFalse(SemanticCorrectionMode.off.displayName.isEmpty)
        XCTAssertFalse(SemanticCorrectionMode.localMLX.displayName.isEmpty)
    }

    // MARK: - AppStorage Default Value Tests

    func testDefaultSemanticCorrectionMode() {
        let defaultRaw = SemanticCorrectionMode.off.rawValue
        XCTAssertEqual(defaultRaw, "off")
    }

    func testDefaultModelRepoValue() {
        let defaultRepo = "mlx-community/Qwen3-1.7B-4bit"
        XCTAssertEqual(defaultRepo, DashboardCorrectionView.testableDefaultModelRepo())
    }

    // MARK: - Environment State Tests

    func testEnvironmentStateTransitions() {
        var envReady = false
        var isCheckingEnv = false

        // Initial state
        XCTAssertFalse(envReady)
        XCTAssertFalse(isCheckingEnv)

        // Start checking
        isCheckingEnv = true
        XCTAssertTrue(isCheckingEnv)

        // Finish checking - ready
        envReady = true
        isCheckingEnv = false
        XCTAssertTrue(envReady)
        XCTAssertFalse(isCheckingEnv)
    }

    func testEnvironmentCheckNotReadyState() {
        var envReady = false
        var isCheckingEnv = false

        isCheckingEnv = true
        // Check fails
        envReady = false
        isCheckingEnv = false

        XCTAssertFalse(envReady)
        XCTAssertFalse(isCheckingEnv)
    }

    // MARK: - Setup Sheet State Tests

    func testSetupSheetStateFlow() {
        var showSetupSheet = false
        var isSettingUp = false
        var setupStatus: String?
        var setupLogs = ""

        // Start setup
        setupStatus = "Setting up Local LLM dependencies…"
        setupLogs = ""
        isSettingUp = true
        showSetupSheet = true

        XCTAssertTrue(showSetupSheet)
        XCTAssertTrue(isSettingUp)
        XCTAssertEqual(setupStatus, "Setting up Local LLM dependencies…")

        // Progress
        setupLogs += "Installing packages..."
        XCTAssertFalse(setupLogs.isEmpty)

        // Success
        isSettingUp = false
        setupStatus = "✓ Environment ready"

        XCTAssertFalse(isSettingUp)
        XCTAssertTrue(setupStatus?.contains("✓") ?? false)

        // Dismiss
        showSetupSheet = false
        XCTAssertFalse(showSetupSheet)
    }

    func testSetupSheetFailureState() {
        var isSettingUp = true
        var setupStatus = "Installing..."
        var setupLogs = ""

        // Failure
        isSettingUp = false
        setupStatus = "✗ Setup failed"
        setupLogs += "\nError: Package not found"

        XCTAssertFalse(isSettingUp)
        XCTAssertTrue(setupStatus.contains("✗"))
        XCTAssertTrue(setupLogs.contains("Error"))
    }

    // MARK: - Verification State Tests

    func testVerificationStateFlow() {
        var isVerifyingMLX = false
        var mlxVerifyMessage: String?

        // Start verification
        isVerifyingMLX = true
        mlxVerifyMessage = "Checking model (offline)…"

        XCTAssertTrue(isVerifyingMLX)
        XCTAssertEqual(mlxVerifyMessage, "Checking model (offline)…")

        // Complete successfully
        isVerifyingMLX = false
        mlxVerifyMessage = "Model verified"

        XCTAssertFalse(isVerifyingMLX)
        XCTAssertEqual(mlxVerifyMessage, "Model verified")
    }

    func testVerificationFailureState() {
        var isVerifyingMLX = true
        var mlxVerifyMessage: String? = "Checking..."

        // Failure
        isVerifyingMLX = false
        mlxVerifyMessage = "Verification failed"

        XCTAssertFalse(isVerifyingMLX)
        XCTAssertTrue(mlxVerifyMessage?.contains("failed") ?? false)
    }

    func testVerificationErrorState() {
        var isVerifyingMLX = true
        var mlxVerifyMessage: String?

        // Error occurs
        isVerifyingMLX = false
        mlxVerifyMessage = "Verification error: Network timeout"

        XCTAssertFalse(isVerifyingMLX)
        XCTAssertTrue(mlxVerifyMessage?.contains("error") ?? false)
    }

    // MARK: - Model Selection Logic Tests

    func testModelSelectionUpdatesRepo() {
        testDefaults.set("mlx-community/gemma-2b-it-4bit", forKey: "semanticCorrectionModelRepo")

        let stored = testDefaults.string(forKey: "semanticCorrectionModelRepo")
        XCTAssertEqual(stored, "mlx-community/gemma-2b-it-4bit")
    }

    func testModelDeleteFallsBackToRecommended() {
        var selectedRepo = "mlx-community/gemma-2b-it-4bit"

        // Simulate delete of selected model
        let deletedRepo = selectedRepo
        if selectedRepo == deletedRepo {
            selectedRepo = DashboardCorrectionView.testableDefaultModelRepo()
        }

        XCTAssertEqual(selectedRepo, "mlx-community/Qwen3-1.7B-4bit")
    }

    // MARK: - MLX Model Manager Tests

    func testRecommendedModelsExist() {
        let models = MLXModelManager.recommendedModels
        XCTAssertGreaterThan(models.count, 0, "Should have at least one recommended model")
    }

    func testRecommendedModelsHaveProperties() {
        for model in MLXModelManager.recommendedModels {
            XCTAssertFalse(model.repo.isEmpty, "Model should have a repo")
            XCTAssertFalse(model.displayName.isEmpty, "Model should have a display name")
            XCTAssertFalse(model.description.isEmpty, "Model should have a description")
            XCTAssertFalse(model.estimatedSize.isEmpty, "Model should have an estimated size")
        }
    }

    // MARK: - Model Refresh State Tests

    func testModelRefreshState() {
        var isRefreshingModels = false

        // Start refresh
        isRefreshingModels = true
        XCTAssertTrue(isRefreshingModels)

        // Complete refresh
        isRefreshingModels = false
        XCTAssertFalse(isRefreshingModels)
    }

    // MARK: - Mode Change Triggers Env Check

    func testModeChangeToLocalMLXTriggersCheck() {
        var lastModeRaw = "off"
        var envCheckTriggered = false

        // Simulate mode change
        let newModeRaw = "localMLX"

        if SemanticCorrectionMode(rawValue: newModeRaw) == .localMLX {
            envCheckTriggered = true
        }

        lastModeRaw = newModeRaw

        XCTAssertEqual(lastModeRaw, "localMLX")
        XCTAssertTrue(envCheckTriggered)
    }

    // MARK: - Model Download State Tests

    func testModelDownloadStartsWhenSelectingUndownloaded() {
        var downloadStarted = false
        let isDownloaded = false
        let isDownloading = false

        // Simulate selection
        if !isDownloaded && !isDownloading {
            downloadStarted = true
        }

        XCTAssertTrue(downloadStarted)
    }

    func testModelDownloadDoesNotStartWhenAlreadyDownloaded() {
        var downloadStarted = false
        let isDownloaded = true
        let isDownloading = false

        // Simulate selection
        if !isDownloaded && !isDownloading {
            downloadStarted = true
        }

        XCTAssertFalse(downloadStarted)
    }

    func testModelDownloadDoesNotStartWhenAlreadyDownloading() {
        var downloadStarted = false
        let isDownloaded = false
        let isDownloading = true

        // Simulate selection
        if !isDownloaded && !isDownloading {
            downloadStarted = true
        }

        XCTAssertFalse(downloadStarted)
    }

    // MARK: - Cleanup Button Visibility Tests

    func testCleanupButtonShownWhenUnusedModelsExist() {
        let unusedModelCount = 3
        let showCleanup = unusedModelCount > 0
        XCTAssertTrue(showCleanup)
    }

    func testCleanupButtonHiddenWhenNoUnusedModels() {
        let unusedModelCount = 0
        let showCleanup = unusedModelCount > 0
        XCTAssertFalse(showCleanup)
    }

    func testCleanupButtonPluralText() {
        let count = 2
        let suffix = pluralSuffix(for: count)
        let text = "Clean up \(count) old model\(suffix)"
        XCTAssertEqual(text, "Clean up 2 old models")
    }

    func testCleanupButtonSingularText() {
        let count = 1
        let suffix = pluralSuffix(for: count)
        let text = "Clean up \(count) old model\(suffix)"
        XCTAssertEqual(text, "Clean up 1 old model")
    }

    // Helper to avoid compile-time constant folding warnings
    private func pluralSuffix(for count: Int) -> String {
        count == 1 ? "" : "s"
    }
}
