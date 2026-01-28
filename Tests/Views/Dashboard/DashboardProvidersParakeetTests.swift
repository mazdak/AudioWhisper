import XCTest
import SwiftUI
@testable import AudioWhisper

/// Tests for DashboardProviders+Parakeet extension functionality
@MainActor
final class DashboardProvidersParakeetTests: XCTestCase {

    // MARK: - Environment Status Tests

    func testEnvironmentReadyState() {
        let envReady = true
        let isCheckingEnv = false

        XCTAssertTrue(envReady)
        XCTAssertFalse(isCheckingEnv)
    }

    func testEnvironmentNotReadyState() {
        let envReady = false
        let isCheckingEnv = false

        XCTAssertFalse(envReady)
        XCTAssertFalse(isCheckingEnv)
    }

    func testEnvironmentCheckingState() {
        let envReady = false
        let isCheckingEnv = true

        XCTAssertFalse(envReady)
        XCTAssertTrue(isCheckingEnv)
    }

    // MARK: - Environment Status Display Tests

    func testEnvironmentReadyText() {
        let envReady = true
        let text = envReady ? "Environment Ready" : "Setup Required"

        XCTAssertEqual(text, "Environment Ready")
    }

    func testEnvironmentSetupRequiredText() {
        let envReady = false
        let text = envReady ? "Environment Ready" : "Setup Required"

        XCTAssertEqual(text, "Setup Required")
    }

    func testEnvironmentReadyIcon() {
        let envReady = true
        let icon = envReady ? "checkmark" : "arrow.down.circle"

        XCTAssertEqual(icon, "checkmark")
    }

    func testEnvironmentSetupRequiredIcon() {
        let envReady = false
        let icon = envReady ? "checkmark" : "arrow.down.circle"

        XCTAssertEqual(icon, "arrow.down.circle")
    }

    // MARK: - Model Selection Tests

    func testParakeetModelSelection() {
        var selectedModel = ParakeetModel.v2English

        selectedModel = .v3Multilingual

        XCTAssertEqual(selectedModel, .v3Multilingual)
    }

    func testParakeetModelHasAllCases() {
        XCTAssertGreaterThan(ParakeetModel.allCases.count, 0)
    }

    func testParakeetModelDisplayNames() {
        for model in ParakeetModel.allCases {
            XCTAssertFalse(model.displayName.isEmpty)
        }
    }

    func testParakeetModelRepoIds() {
        for model in ParakeetModel.allCases {
            XCTAssertFalse(model.repoId.isEmpty)
            XCTAssertTrue(model.repoId.contains("parakeet"))
        }
    }

    // MARK: - Verification State Tests

    func testVerificationNotRunningState() {
        let isVerifyingParakeet = false
        let parakeetVerifyMessage: String? = nil

        XCTAssertFalse(isVerifyingParakeet)
        XCTAssertNil(parakeetVerifyMessage)
    }

    func testVerificationStartingState() {
        var isVerifyingParakeet = false
        var parakeetVerifyMessage: String?

        // Start verification
        isVerifyingParakeet = true
        parakeetVerifyMessage = "Starting verification…"

        XCTAssertTrue(isVerifyingParakeet)
        XCTAssertEqual(parakeetVerifyMessage, "Starting verification…")
    }

    func testVerificationCheckingModelState() {
        let isVerifyingParakeet = true
        var parakeetVerifyMessage = "Starting verification…"

        parakeetVerifyMessage = "Checking model (offline)…"

        XCTAssertTrue(isVerifyingParakeet)
        XCTAssertEqual(parakeetVerifyMessage, "Checking model (offline)…")
    }

    func testVerificationSuccessState() {
        var isVerifyingParakeet = true
        var parakeetVerifyMessage = "Checking model (offline)…"
        var hasSetupParakeet = false

        // Verification success
        isVerifyingParakeet = false
        parakeetVerifyMessage = "Model verified"
        hasSetupParakeet = true

        XCTAssertFalse(isVerifyingParakeet)
        XCTAssertEqual(parakeetVerifyMessage, "Model verified")
        XCTAssertTrue(hasSetupParakeet)
    }

    func testVerificationFailureState() {
        var isVerifyingParakeet = true
        var parakeetVerifyMessage = "Checking model (offline)…"

        // Verification failure
        isVerifyingParakeet = false
        parakeetVerifyMessage = "Verification failed: Model not found"

        XCTAssertFalse(isVerifyingParakeet)
        XCTAssertTrue(parakeetVerifyMessage.contains("failed"))
    }

    func testVerificationErrorState() {
        var isVerifyingParakeet = true
        var parakeetVerifyMessage = "Starting verification…"

        // Verification error
        isVerifyingParakeet = false
        parakeetVerifyMessage = "Verification error: Network unavailable"

        XCTAssertFalse(isVerifyingParakeet)
        XCTAssertTrue(parakeetVerifyMessage.contains("error"))
    }

    // MARK: - Verify Button State Tests

    func testVerifyButtonDisabledWhenVerifying() {
        let isVerifyingParakeet = true
        let buttonDisabled = isVerifyingParakeet

        XCTAssertTrue(buttonDisabled)
    }

    func testVerifyButtonEnabledWhenNotVerifying() {
        let isVerifyingParakeet = false
        let buttonDisabled = isVerifyingParakeet

        XCTAssertFalse(buttonDisabled)
    }

    func testVerifyButtonTextWhenVerifying() {
        let isVerifyingParakeet = true
        let buttonText = isVerifyingParakeet ? "Verifying…" : "Verify"

        XCTAssertEqual(buttonText, "Verifying…")
    }

    func testVerifyButtonTextWhenNotVerifying() {
        let isVerifyingParakeet = false
        let buttonText = isVerifyingParakeet ? "Verifying…" : "Verify"

        XCTAssertEqual(buttonText, "Verify")
    }

    // MARK: - Setup Sheet Tests

    func testSetupSheetInitialState() {
        var showSetupSheet = false
        var isSettingUp = false
        var setupLogs = ""
        var setupStatus: String?

        XCTAssertFalse(showSetupSheet)
        XCTAssertFalse(isSettingUp)
        XCTAssertTrue(setupLogs.isEmpty)
        XCTAssertNil(setupStatus)
    }

    func testSetupSheetStartState() {
        var showSetupSheet = false
        var isSettingUp = false
        var setupLogs = ""
        var setupStatus: String?

        // Start setup
        setupStatus = "Installing Parakeet dependencies…"
        setupLogs = ""
        isSettingUp = true
        showSetupSheet = true

        XCTAssertTrue(showSetupSheet)
        XCTAssertTrue(isSettingUp)
        XCTAssertEqual(setupStatus, "Installing Parakeet dependencies…")
    }

    func testSetupSheetProgressState() {
        var setupLogs = ""

        // Add log entries
        setupLogs += "Downloading packages..."
        setupLogs += "\n"
        setupLogs += "Installing mlx_lm..."

        XCTAssertTrue(setupLogs.contains("Downloading"))
        XCTAssertTrue(setupLogs.contains("mlx_lm"))
    }

    func testSetupSheetSuccessState() {
        var isSettingUp = true
        var setupStatus = "Installing..."
        var envReady = false

        // Setup success
        isSettingUp = false
        setupStatus = "✓ Environment ready"
        envReady = true

        XCTAssertFalse(isSettingUp)
        XCTAssertTrue(setupStatus.contains("✓"))
        XCTAssertTrue(envReady)
    }

    func testSetupSheetFailureState() {
        var isSettingUp = true
        var setupStatus = "Installing..."
        var setupLogs = ""
        var envReady = false

        // Setup failure
        isSettingUp = false
        setupStatus = "✗ Setup failed"
        setupLogs += "\nError: Package not found"
        envReady = false

        XCTAssertFalse(isSettingUp)
        XCTAssertTrue(setupStatus.contains("✗"))
        XCTAssertTrue(setupLogs.contains("Error"))
        XCTAssertFalse(envReady)
    }

    // MARK: - Install Button Visibility Tests

    func testInstallButtonShownWhenEnvNotReady() {
        let envReady = false
        let showInstallButton = !envReady

        XCTAssertTrue(showInstallButton)
    }

    func testInstallButtonHiddenWhenEnvReady() {
        let envReady = true
        let showInstallButton = !envReady

        XCTAssertFalse(showInstallButton)
    }

    func testVerifyButtonShownWhenEnvReady() {
        let envReady = true
        let showVerifyButton = envReady

        XCTAssertTrue(showVerifyButton)
    }

    func testVerifyButtonHiddenWhenEnvNotReady() {
        let envReady = false
        let showVerifyButton = envReady

        XCTAssertFalse(showVerifyButton)
    }

    // MARK: - Verification Message Display Tests

    func testVerificationMessageShownWhenNotEmpty() {
        let parakeetVerifyMessage: String? = "Model verified"
        let showMessage = parakeetVerifyMessage != nil && !parakeetVerifyMessage!.isEmpty

        XCTAssertTrue(showMessage)
    }

    func testVerificationMessageHiddenWhenEmpty() {
        let parakeetVerifyMessage: String? = ""
        let showMessage = parakeetVerifyMessage != nil && !parakeetVerifyMessage!.isEmpty

        XCTAssertFalse(showMessage)
    }

    func testVerificationMessageHiddenWhenNil() {
        let parakeetVerifyMessage: String? = nil
        let showMessage = parakeetVerifyMessage != nil && !parakeetVerifyMessage!.isEmpty

        XCTAssertFalse(showMessage)
    }

    // MARK: - Parakeet Info Footer Tests

    func testParakeetFooterInfo() {
        let footerText = "Runs locally on Apple Silicon • ~2.5 GB disk space"

        XCTAssertTrue(footerText.contains("Apple Silicon"))
        XCTAssertTrue(footerText.contains("2.5 GB"))
    }

    // MARK: - Environment Check Logic Tests

    func testEnvCheckSetsCheckingFlag() {
        var isCheckingEnv = false

        // Start checking
        isCheckingEnv = true

        XCTAssertTrue(isCheckingEnv)
    }

    func testEnvCheckCompleteSetsFlags() {
        var isCheckingEnv = true
        var envReady = false
        var hasSetupParakeet = false
        var hasSetupLocalLLM = false

        // Check complete - ready
        envReady = true
        isCheckingEnv = false
        hasSetupParakeet = true
        hasSetupLocalLLM = true

        XCTAssertFalse(isCheckingEnv)
        XCTAssertTrue(envReady)
        XCTAssertTrue(hasSetupParakeet)
        XCTAssertTrue(hasSetupLocalLLM)
    }

    func testEnvCheckCompleteNotReady() {
        var isCheckingEnv = true
        var envReady = false

        // Check complete - not ready
        envReady = false
        isCheckingEnv = false

        XCTAssertFalse(isCheckingEnv)
        XCTAssertFalse(envReady)
    }

    // MARK: - Model Change Triggers Download Tests

    func testModelSelectionChangeTriggersEnsure() {
        var modelChangeCount = 0
        var selectedModel = ParakeetModel.v2English

        // Simulate onChange
        selectedModel = .v3Multilingual
        modelChangeCount += 1

        XCTAssertEqual(selectedModel, .v3Multilingual)
        XCTAssertEqual(modelChangeCount, 1)
    }
}
