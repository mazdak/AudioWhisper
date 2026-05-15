import XCTest
@testable import AudioWhisper

@MainActor
final class AppDefaultsTests: IsolatedXCTestCase {
    // TODO(D1): AppDefaults reads/writes UserDefaults.standard directly and
    // is the canonical accessor; these tests exercise it against `.standard`
    // by design. Re-enable isolation once AppDefaults accepts an injected
    // UserDefaults instance.
    override var enforcesStandardUserDefaultsIsolation: Bool { false }

    private var testDefaults: UserDefaults!
    private var originalDefaults: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        // Store original values for keys we'll modify
        for key in AppDefaults.Key.allCases {
            if let value = UserDefaults.standard.object(forKey: key.rawValue) {
                originalDefaults[key.rawValue] = value
            }
        }
    }

    override func tearDown() {
        // Restore original values
        for key in AppDefaults.Key.allCases {
            if let original = originalDefaults[key.rawValue] {
                UserDefaults.standard.set(original, forKey: key.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: key.rawValue)
            }
        }
        originalDefaults.removeAll()
        super.tearDown()
    }

    // MARK: - Key Enum Tests

    func testAllKeysHaveRawValues() {
        for key in AppDefaults.Key.allCases {
            XCTAssertFalse(key.rawValue.isEmpty, "Key \(key) should have non-empty rawValue")
        }
    }

    func testKeyRawValuesAreUnique() {
        let rawValues = AppDefaults.Key.allCases.map { $0.rawValue }
        let uniqueValues = Set(rawValues)
        XCTAssertEqual(rawValues.count, uniqueValues.count, "All key rawValues should be unique")
    }

    func testKeyCaseIterableConformance() {
        XCTAssertGreaterThan(AppDefaults.Key.allCases.count, 0)
    }

    // MARK: - Transcription Provider Tests

    func testTranscriptionProviderDefaultValue() {
        AppDefaults.removeValue(for: .transcriptionProvider)
        XCTAssertEqual(AppDefaults.transcriptionProvider, .parakeet)
    }

    func testTranscriptionProviderSetAndGet() {
        AppDefaults.transcriptionProvider = .local
        XCTAssertEqual(AppDefaults.transcriptionProvider, .local)

        AppDefaults.transcriptionProvider = .parakeet
        XCTAssertEqual(AppDefaults.transcriptionProvider, .parakeet)
    }

    // MARK: - Whisper Model Tests

    func testSelectedWhisperModelDefaultValue() {
        AppDefaults.removeValue(for: .selectedWhisperModel)
        XCTAssertEqual(AppDefaults.selectedWhisperModel, .base)
    }

    func testSelectedWhisperModelSetAndGet() {
        for model in WhisperModel.allCases {
            AppDefaults.selectedWhisperModel = model
            XCTAssertEqual(AppDefaults.selectedWhisperModel, model)
        }
    }

    // MARK: - Parakeet Model Tests

    func testSelectedParakeetModelDefaultValue() {
        AppDefaults.removeValue(for: .selectedParakeetModel)
        XCTAssertEqual(AppDefaults.selectedParakeetModel, .v3Multilingual)
    }

    func testSelectedParakeetModelSetAndGet() {
        AppDefaults.selectedParakeetModel = .v2English
        XCTAssertEqual(AppDefaults.selectedParakeetModel, .v2English)

        AppDefaults.selectedParakeetModel = .v3Multilingual
        XCTAssertEqual(AppDefaults.selectedParakeetModel, .v3Multilingual)
    }

    // MARK: - Semantic Correction Tests

    func testSemanticCorrectionModeDefaultValue() {
        AppDefaults.removeValue(for: .semanticCorrectionMode)
        XCTAssertEqual(AppDefaults.semanticCorrectionMode, .off)
    }

    func testSemanticCorrectionModeSetAndGet() {
        AppDefaults.semanticCorrectionMode = .localMLX
        XCTAssertEqual(AppDefaults.semanticCorrectionMode, .localMLX)

        AppDefaults.semanticCorrectionMode = .off
        XCTAssertEqual(AppDefaults.semanticCorrectionMode, .off)
    }

    func testSemanticCorrectionModelRepoDefault() {
        AppDefaults.removeValue(for: .semanticCorrectionModelRepo)
        XCTAssertEqual(AppDefaults.semanticCorrectionModelRepo, "mlx-community/Qwen3-1.7B-4bit")
    }

    func testSemanticCorrectionModelRepoSetAndGet() {
        let customRepo = "custom/model-repo"
        AppDefaults.semanticCorrectionModelRepo = customRepo
        XCTAssertEqual(AppDefaults.semanticCorrectionModelRepo, customRepo)
    }

    // MARK: - Recording Settings Tests

    func testGlobalHotkeyDefault() {
        AppDefaults.removeValue(for: .globalHotkey)
        XCTAssertEqual(AppDefaults.globalHotkey, "⌘⇧Space")
    }

    func testGlobalHotkeySetAndGet() {
        AppDefaults.globalHotkey = "⌥⇧R"
        XCTAssertEqual(AppDefaults.globalHotkey, "⌥⇧R")
    }

    func testImmediateRecordingDefault() {
        AppDefaults.removeValue(for: .immediateRecording)
        XCTAssertFalse(AppDefaults.immediateRecording)
    }

    func testImmediateRecordingSetAndGet() {
        AppDefaults.immediateRecording = true
        XCTAssertTrue(AppDefaults.immediateRecording)

        AppDefaults.immediateRecording = false
        XCTAssertFalse(AppDefaults.immediateRecording)
    }

    func testSelectedMicrophoneDefault() {
        AppDefaults.removeValue(for: .selectedMicrophone)
        XCTAssertEqual(AppDefaults.selectedMicrophone, "")
    }

    func testSelectedMicrophoneSetAndGet() {
        AppDefaults.selectedMicrophone = "MacBook Pro Microphone"
        XCTAssertEqual(AppDefaults.selectedMicrophone, "MacBook Pro Microphone")
    }

    // MARK: - Press and Hold Tests
    // Note: Press-and-hold tests are in PressAndHoldKeyMonitorTests and AppDelegateHotkeysTests
    // to avoid parallel test interference with shared UserDefaults keys

    // MARK: - Visual Settings Tests
    // Note: waveformStyle tests are in WaveformStyleTests.swift to avoid parallel test interference

    func testVisualIntensityDefault() {
        AppDefaults.removeValue(for: .visualIntensity)
        XCTAssertEqual(AppDefaults.visualIntensity, .balanced)
    }

    func testVisualIntensitySetAndGet() {
        for intensity in VisualIntensity.allCases {
            AppDefaults.visualIntensity = intensity
            XCTAssertEqual(AppDefaults.visualIntensity, intensity)
        }
    }

    func testMenuBarIconSizeDefault() {
        AppDefaults.removeValue(for: .menuBarIconSize)
        XCTAssertNil(AppDefaults.menuBarIconSize)
    }

    func testMenuBarIconSizeSetAndGet() {
        AppDefaults.menuBarIconSize = 18.0
        XCTAssertEqual(AppDefaults.menuBarIconSize, 18.0)

        AppDefaults.menuBarIconSize = nil
        XCTAssertNil(AppDefaults.menuBarIconSize)
    }

    // MARK: - Behavior Settings Tests
    // Note: enableSmartPaste tests are in PasteManagerTests to avoid parallel test interference

    func testPlayCompletionSoundDefault() {
        AppDefaults.removeValue(for: .playCompletionSound)
        XCTAssertTrue(AppDefaults.playCompletionSound)
    }

    func testStartAtLoginDefault() {
        AppDefaults.removeValue(for: .startAtLogin)
        XCTAssertTrue(AppDefaults.startAtLogin)
    }

    // MARK: - Data Settings Tests

    func testTranscriptionHistoryEnabledDefault() {
        AppDefaults.removeValue(for: .transcriptionHistoryEnabled)
        XCTAssertFalse(AppDefaults.transcriptionHistoryEnabled)
    }

    func testTranscriptionRetentionPeriodDefault() {
        AppDefaults.removeValue(for: .transcriptionRetentionPeriod)
        XCTAssertEqual(AppDefaults.transcriptionRetentionPeriod, .oneMonth)
    }

    func testTranscriptionRetentionPeriodSetAndGet() {
        for period in RetentionPeriod.allCases {
            AppDefaults.transcriptionRetentionPeriod = period
            XCTAssertEqual(AppDefaults.transcriptionRetentionPeriod, period)
        }
    }

    func testMaxModelStorageGBDefault() {
        AppDefaults.removeValue(for: .maxModelStorageGB)
        XCTAssertEqual(AppDefaults.maxModelStorageGB, 5.0)
    }

    func testMaxModelStorageGBSetAndGet() {
        AppDefaults.maxModelStorageGB = 10.0
        XCTAssertEqual(AppDefaults.maxModelStorageGB, 10.0)
    }

    // MARK: - Setup State Tests

    func testHasSetupParakeetDefault() {
        AppDefaults.removeValue(for: .hasSetupParakeet)
        XCTAssertFalse(AppDefaults.hasSetupParakeet)
    }

    func testHasSetupLocalLLMDefault() {
        AppDefaults.removeValue(for: .hasSetupLocalLLM)
        XCTAssertFalse(AppDefaults.hasSetupLocalLLM)
    }

    func testHasCompletedWelcomeDefault() {
        AppDefaults.removeValue(for: .hasCompletedWelcome)
        XCTAssertFalse(AppDefaults.hasCompletedWelcome)
    }

    func testLastWelcomeVersionDefault() {
        AppDefaults.removeValue(for: .lastWelcomeVersion)
        XCTAssertEqual(AppDefaults.lastWelcomeVersion, "0")
    }

    func testHasShownFirstModelUseHintDefault() {
        AppDefaults.removeValue(for: .hasShownFirstModelUseHint)
        XCTAssertFalse(AppDefaults.hasShownFirstModelUseHint)
    }

    // MARK: - Utility Method Tests

    func testHasValueReturnsFalseForMissingKey() {
        AppDefaults.removeValue(for: .globalHotkey)
        XCTAssertFalse(AppDefaults.hasValue(for: .globalHotkey))
    }

    func testHasValueReturnsTrueForExistingKey() {
        AppDefaults.globalHotkey = "test"
        XCTAssertTrue(AppDefaults.hasValue(for: .globalHotkey))
    }

    func testRemoveValueRemovesKey() {
        AppDefaults.globalHotkey = "test"
        XCTAssertTrue(AppDefaults.hasValue(for: .globalHotkey))

        AppDefaults.removeValue(for: .globalHotkey)
        XCTAssertFalse(AppDefaults.hasValue(for: .globalHotkey))
    }

    func testResetAllClearsAllKeys() {
        // Set some values
        AppDefaults.globalHotkey = "test"
        AppDefaults.immediateRecording = true
        AppDefaults.selectedMicrophone = "test mic"

        // Reset all
        AppDefaults.resetAll()

        // Verify all are cleared
        XCTAssertFalse(AppDefaults.hasValue(for: .globalHotkey))
        XCTAssertFalse(AppDefaults.hasValue(for: .immediateRecording))
        XCTAssertFalse(AppDefaults.hasValue(for: .selectedMicrophone))
    }

    // MARK: - Invalid Value Handling Tests

    func testInvalidEnumValueFallsBackToDefault() {
        // Set an invalid raw value directly
        UserDefaults.standard.set("invalid_provider", forKey: AppDefaults.Key.transcriptionProvider.rawValue)
        XCTAssertEqual(AppDefaults.transcriptionProvider, .parakeet) // Falls back to default

        UserDefaults.standard.set("invalid_model", forKey: AppDefaults.Key.selectedWhisperModel.rawValue)
        XCTAssertEqual(AppDefaults.selectedWhisperModel, .base) // Falls back to default

        // Note: waveformStyle invalid value test is in WaveformStyleTests.swift
    }
}
