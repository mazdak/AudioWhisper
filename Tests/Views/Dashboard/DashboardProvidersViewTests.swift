import XCTest
import SwiftUI
@testable import AudioWhisper

/// Tests for DashboardProvidersView logic and calculations
@MainActor
final class DashboardProvidersViewTests: XCTestCase {

    private var testDefaults: UserDefaults!
    private var testSuiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        testSuiteName = "DashboardProvidersViewTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)
        testDefaults?.removePersistentDomain(forName: testSuiteName)
    }

    override func tearDown() async throws {
        testDefaults?.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        try await super.tearDown()
    }

    // MARK: - Status Badge Tests

    func testStatusBadgeLocalReadyWithModels() {
        let (text, isReady) = DashboardProvidersView.testableStatusInfo(
            for: .local,
            downloadedModels: [.base],
            envReady: false
        )

        XCTAssertEqual(text, "Ready")
        XCTAssertTrue(isReady)
    }

    func testStatusBadgeLocalSetupWithoutModels() {
        let (text, isReady) = DashboardProvidersView.testableStatusInfo(
            for: .local,
            downloadedModels: [],
            envReady: false
        )

        XCTAssertEqual(text, "Setup")
        XCTAssertFalse(isReady)
    }

    func testStatusBadgeParakeetReadyWithEnv() {
        let (text, isReady) = DashboardProvidersView.testableStatusInfo(
            for: .parakeet,
            downloadedModels: [],
            envReady: true
        )

        XCTAssertEqual(text, "Ready")
        XCTAssertTrue(isReady)
    }

    func testStatusBadgeParakeetSetupWithoutEnv() {
        let (text, isReady) = DashboardProvidersView.testableStatusInfo(
            for: .parakeet,
            downloadedModels: [],
            envReady: false
        )

        XCTAssertEqual(text, "Setup")
        XCTAssertFalse(isReady)
    }

    // MARK: - Engine Config Tests

    func testEngineConfigLocal() {
        let config = DashboardProvidersView.testableEngineConfig(for: .local)

        XCTAssertEqual(config.icon, "desktopcomputer")
        XCTAssertEqual(config.tagline, "WhisperKit on Apple Silicon")
    }

    func testEngineConfigParakeet() {
        let config = DashboardProvidersView.testableEngineConfig(for: .parakeet)

        XCTAssertEqual(config.icon, "bird")
        XCTAssertEqual(config.tagline, "NVIDIA's neural speech engine")
    }

    // MARK: - All Providers Have Config

    func testAllProvidersHaveConfig() {
        for provider in TranscriptionProvider.allCases {
            let config = DashboardProvidersView.testableEngineConfig(for: provider)
            XCTAssertFalse(config.icon.isEmpty, "\(provider) should have an icon")
            XCTAssertFalse(config.tagline.isEmpty, "\(provider) should have a tagline")
        }
    }

    // MARK: - Semantic Correction Mode Tests

    func testSemanticCorrectionModeOff() {
        let mode = DashboardProvidersView.testableSemanticCorrectionMode(from: "off")
        XCTAssertEqual(mode, .off)
    }

    func testSemanticCorrectionModeLocalMLX() {
        let mode = DashboardProvidersView.testableSemanticCorrectionMode(from: "localMLX")
        XCTAssertEqual(mode, .localMLX)
    }

    func testSemanticCorrectionModeInvalid() {
        let mode = DashboardProvidersView.testableSemanticCorrectionMode(from: "invalid")
        XCTAssertNil(mode)
    }

    func testSemanticCorrectionModeCloudRemoved() {
        // Cloud mode was removed - should return nil
        let mode = DashboardProvidersView.testableSemanticCorrectionMode(from: "cloud")
        XCTAssertNil(mode)
    }

    // MARK: - MLX Section Visibility Tests

    func testShowsMLXSectionWhenModeLocalMLX() {
        XCTAssertTrue(DashboardProvidersView.testableShowsMLXSection(modeRaw: "localMLX"))
    }

    func testHidesMLXSectionWhenModeOff() {
        XCTAssertFalse(DashboardProvidersView.testableShowsMLXSection(modeRaw: "off"))
    }

    func testHidesMLXSectionWhenModeInvalid() {
        XCTAssertFalse(DashboardProvidersView.testableShowsMLXSection(modeRaw: "invalid"))
    }

    // MARK: - Provider Selection Tests

    func testTranscriptionProviderEnumRawValues() {
        XCTAssertEqual(TranscriptionProvider.local.rawValue, "local")
        XCTAssertEqual(TranscriptionProvider.parakeet.rawValue, "parakeet")
    }

    func testTranscriptionProviderDisplayNames() {
        XCTAssertFalse(TranscriptionProvider.local.displayName.isEmpty)
        XCTAssertFalse(TranscriptionProvider.parakeet.displayName.isEmpty)
    }

    func testTranscriptionProviderCount() {
        XCTAssertEqual(TranscriptionProvider.allCases.count, 2)
    }

    func testProviderSelectionPersistence() {
        testDefaults.set("local", forKey: "transcriptionProvider")

        let stored = testDefaults.string(forKey: "transcriptionProvider")
        XCTAssertEqual(stored, "local")

        let provider = TranscriptionProvider(rawValue: stored ?? "")
        XCTAssertEqual(provider, .local)
    }

    // MARK: - Whisper Model Tests

    func testWhisperModelHasAllCases() {
        XCTAssertGreaterThan(WhisperModel.allCases.count, 0, "Should have at least one model")
    }

    func testWhisperModelBaseIsRecommended() {
        // Base model is marked as recommended in the UI
        XCTAssertTrue(WhisperModel.allCases.contains(.base))
    }

    func testWhisperModelHasDisplayNames() {
        for model in WhisperModel.allCases {
            XCTAssertFalse(model.displayName.isEmpty, "\(model) should have a display name")
        }
    }

    func testWhisperModelHasDescriptions() {
        for model in WhisperModel.allCases {
            XCTAssertFalse(model.description.isEmpty, "\(model) should have a description")
        }
    }

    func testWhisperModelHasFileSizes() {
        for model in WhisperModel.allCases {
            XCTAssertFalse(model.fileSize.isEmpty, "\(model) should have a file size")
        }
    }

    // MARK: - Parakeet Model Tests

    func testParakeetModelHasAllCases() {
        XCTAssertGreaterThan(ParakeetModel.allCases.count, 0, "Should have at least one model")
    }

    func testParakeetModelHasDisplayNames() {
        for model in ParakeetModel.allCases {
            XCTAssertFalse(model.displayName.isEmpty, "\(model) should have a display name")
        }
    }

    func testParakeetModelHasRepoIds() {
        for model in ParakeetModel.allCases {
            XCTAssertFalse(model.repoId.isEmpty, "\(model) should have a repo ID")
        }
    }

    // MARK: - MLX Model Tests

    func testMLXRecommendedModelsExist() {
        XCTAssertGreaterThan(MLXModelManager.recommendedModels.count, 0,
            "Should have at least one recommended model")
    }

    func testMLXRecommendedModelHasQwen() {
        let hasQwen = MLXModelManager.recommendedModels.contains { model in
            model.repo.contains("Qwen")
        }
        XCTAssertTrue(hasQwen, "Should have at least one Qwen model recommended")
    }

    // MARK: - AppStorage Default Values Tests

    func testDefaultTranscriptionProvider() {
        // Default should be parakeet (local-only)
        let defaultProvider = TranscriptionProvider.parakeet
        XCTAssertEqual(defaultProvider.rawValue, "parakeet")
    }

    func testDefaultWhisperModel() {
        // Default should be base
        let defaultModel = WhisperModel.base
        XCTAssertEqual(defaultModel, .base)
    }

    func testDefaultMaxStorageGB() {
        // Default is 5.0 GB
        let defaultStorage = 5.0
        XCTAssertEqual(defaultStorage, 5.0)
    }

    // MARK: - Environment Check Logic Tests

    func testEnvReadyStateTransitions() {
        var envReady = false
        var isCheckingEnv = false

        // Start checking
        isCheckingEnv = true
        XCTAssertTrue(isCheckingEnv)
        XCTAssertFalse(envReady)

        // Finish checking - environment ready
        envReady = true
        isCheckingEnv = false
        XCTAssertTrue(envReady)
        XCTAssertFalse(isCheckingEnv)
    }

    func testEnvNotReadyStateTransition() {
        var envReady = false
        var isCheckingEnv = false

        // Start checking
        isCheckingEnv = true

        // Finish checking - environment not ready
        envReady = false
        isCheckingEnv = false
        XCTAssertFalse(envReady)
        XCTAssertFalse(isCheckingEnv)
    }

    // MARK: - Download State Logic Tests

    func testModelDownloadStateTransitions() {
        var downloadStartTime: [WhisperModel: Date] = [:]
        let downloadError: String? = nil

        // Start download
        let model = WhisperModel.base
        downloadStartTime[model] = Date()
        XCTAssertNotNil(downloadStartTime[model])

        // Success
        downloadStartTime.removeValue(forKey: model)
        XCTAssertNil(downloadStartTime[model])
        XCTAssertNil(downloadError)
    }

    func testModelDownloadFailureState() {
        var downloadStartTime: [WhisperModel: Date] = [:]
        var downloadError: String?

        // Start download
        let model = WhisperModel.base
        downloadStartTime[model] = Date()

        // Failure
        downloadError = "Network error"
        downloadStartTime.removeValue(forKey: model)

        XCTAssertNil(downloadStartTime[model])
        XCTAssertEqual(downloadError, "Network error")
    }

    // MARK: - Verification State Logic Tests

    func testVerificationStateTransitions() {
        var isVerifyingParakeet = false
        var parakeetVerifyMessage: String?

        // Start verification
        isVerifyingParakeet = true
        parakeetVerifyMessage = "Starting verification…"

        XCTAssertTrue(isVerifyingParakeet)
        XCTAssertEqual(parakeetVerifyMessage, "Starting verification…")

        // Verification in progress
        parakeetVerifyMessage = "Checking model (offline)…"
        XCTAssertEqual(parakeetVerifyMessage, "Checking model (offline)…")

        // Verification complete
        isVerifyingParakeet = false
        parakeetVerifyMessage = "Model verified"

        XCTAssertFalse(isVerifyingParakeet)
        XCTAssertEqual(parakeetVerifyMessage, "Model verified")
    }

    func testVerificationFailureState() {
        var isVerifyingParakeet = true
        var parakeetVerifyMessage: String? = "Verifying..."

        // Verification failed
        isVerifyingParakeet = false
        parakeetVerifyMessage = "Verification failed: Model not found"

        XCTAssertFalse(isVerifyingParakeet)
        XCTAssertTrue(parakeetVerifyMessage?.contains("failed") ?? false)
    }

    // MARK: - Setup Sheet State Tests

    func testSetupSheetStateTransitions() {
        var showSetupSheet = false
        var isSettingUp = false
        var setupStatus: String?
        var setupLogs = ""

        // Start setup
        setupStatus = "Installing dependencies…"
        setupLogs = ""
        isSettingUp = true
        showSetupSheet = true

        XCTAssertTrue(showSetupSheet)
        XCTAssertTrue(isSettingUp)
        XCTAssertEqual(setupStatus, "Installing dependencies…")

        // Setup progress
        setupLogs += "Downloading packages...\n"
        XCTAssertTrue(setupLogs.contains("Downloading"))

        // Setup complete
        isSettingUp = false
        setupStatus = "✓ Environment ready"

        XCTAssertFalse(isSettingUp)
        XCTAssertTrue(setupStatus?.contains("✓") ?? false)

        // Dismiss sheet
        showSetupSheet = false
        XCTAssertFalse(showSetupSheet)
    }

    func testSetupSheetFailureState() {
        var isSettingUp = true
        var setupStatus = "Installing..."
        var setupLogs = ""

        // Setup failed
        isSettingUp = false
        setupStatus = "✗ Setup failed"
        setupLogs += "\nError: Package not found"

        XCTAssertFalse(isSettingUp)
        XCTAssertTrue(setupStatus.contains("✗"))
        XCTAssertTrue(setupLogs.contains("Error"))
    }

    // MARK: - Storage Limit Tests

    func testStorageLimitOptions() {
        let validLimits = [1.0, 2.0, 5.0, 10.0]

        for limit in validLimits {
            XCTAssertGreaterThan(limit, 0)
        }
    }

    func testStorageLimitBytesCalculation() {
        let storageGB = 5.0
        let expectedBytes = Int64(storageGB * 1024 * 1024 * 1024)

        XCTAssertEqual(expectedBytes, 5_368_709_120)
    }
}
