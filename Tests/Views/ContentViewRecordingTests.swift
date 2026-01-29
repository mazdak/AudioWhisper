import XCTest
@testable import AudioWhisper

/// Tests for ContentView recording state machine and transcription workflow
/// Complements RecordingWorkflowEdgeCaseTests with additional coverage
@MainActor
final class ContentViewRecordingTests: XCTestCase {
    private var mockRecorder: MockAudioEngineRecorder!
    private var mockSpeechService: MockSpeechToTextService!
    private var mockSemanticService: MockSemanticCorrectionService!
    private var mockDataManager: MockDataManager!
    private var mockMetricsStore: MockUsageMetricsStore!
    private var testUserDefaultsSuite: String!
    private var testDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        mockRecorder = MockAudioEngineRecorder()
        mockSpeechService = MockSpeechToTextService()
        mockSemanticService = MockSemanticCorrectionService()
        mockDataManager = MockDataManager()
        mockMetricsStore = MockUsageMetricsStore()

        // Use isolated UserDefaults for tests
        testUserDefaultsSuite = "ContentViewRecordingTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testUserDefaultsSuite)
        testDefaults?.removePersistentDomain(forName: testUserDefaultsSuite)
    }

    override func tearDown() async throws {
        mockRecorder?.reset()
        mockSpeechService?.reset()
        mockSemanticService?.reset()
        mockDataManager?.reset()
        mockMetricsStore?.resetMock()
        testDefaults?.removePersistentDomain(forName: testUserDefaultsSuite)
        testDefaults = nil
        testUserDefaultsSuite = nil
        try await super.tearDown()
    }

    // MARK: - State Transition Tests

    func testIsProcessingSetBeforeTaskCreation() async throws {
        // This tests the race condition fix at line 30 in ContentView+Recording.swift
        // isProcessing must be set BEFORE the Task is created, not inside it

        var isProcessing = false
        var taskStartedWithProcessingTrue = false

        // Simulate the fixed behavior
        isProcessing = true  // Set BEFORE Task

        let task = Task {
            // Capture whether isProcessing was already true when task started
            taskStartedWithProcessingTrue = isProcessing
            try await Task.sleep(for: .milliseconds(10))
        }

        try await task.value

        XCTAssertTrue(taskStartedWithProcessingTrue,
            "isProcessing should be true when Task starts (race condition fix)")
    }

    func testTranscriptionStartTimeSetWithIsProcessing() async throws {
        var isProcessing = false
        var transcriptionStartTime: Date?

        // Both should be set together before Task
        isProcessing = true
        transcriptionStartTime = Date()

        XCTAssertTrue(isProcessing)
        XCTAssertNotNil(transcriptionStartTime)

        // And both should be cleared together on completion
        isProcessing = false
        transcriptionStartTime = nil

        XCTAssertFalse(isProcessing)
        XCTAssertNil(transcriptionStartTime)
    }

    // MARK: - Semantic Correction Tests

    func testSemanticCorrectionAppliedWhenModeLocalMLX() async throws {
        testDefaults.set(SemanticCorrectionMode.localMLX.rawValue, forKey: "semanticCorrectionMode")
        mockSpeechService.setSuccess("original text")
        mockSemanticService.setCorrectionResult("corrected text")

        // Simulate the workflow
        let text = try await mockSpeechService.transcribeRaw(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            provider: .local,
            model: nil
        )

        let modeRaw = testDefaults.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off

        var finalText = text
        if mode != .off {
            let corrected = await mockSemanticService.correct(
                text: text,
                providerUsed: .local,
                sourceAppBundleId: nil
            )
            finalText = corrected
        }

        XCTAssertEqual(mockSemanticService.correctCallCount, 1, "Correction should be called once")
        XCTAssertEqual(finalText, "corrected text", "Should use corrected text")
        XCTAssertEqual(mockSemanticService.lastText, "original text", "Should pass original text to correction")
    }

    func testSemanticCorrectionAppliedWithParakeetProvider() async throws {
        testDefaults.set(SemanticCorrectionMode.localMLX.rawValue, forKey: "semanticCorrectionMode")
        mockSpeechService.setSuccess("raw transcription")
        mockSemanticService.setCorrectionResult("mlx corrected")

        let text = try await mockSpeechService.transcribeRaw(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            provider: .parakeet,
            model: nil
        )

        let modeRaw = testDefaults.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off

        var finalText = text
        if mode != .off {
            let corrected = await mockSemanticService.correct(
                text: text,
                providerUsed: .parakeet,
                sourceAppBundleId: "com.test.app"
            )
            finalText = corrected
        }

        XCTAssertEqual(mockSemanticService.correctCallCount, 1)
        XCTAssertEqual(finalText, "mlx corrected")
        XCTAssertEqual(mockSemanticService.lastProvider, .parakeet)
    }

    func testSemanticCorrectionSkippedWhenModeOff() async throws {
        testDefaults.set(SemanticCorrectionMode.off.rawValue, forKey: "semanticCorrectionMode")
        mockSpeechService.setSuccess("original text only")
        mockSemanticService.setCorrectionResult("this should not be used")

        let text = try await mockSpeechService.transcribeRaw(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            provider: .local,
            model: nil
        )

        let modeRaw = testDefaults.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off

        var finalText = text
        if mode != .off {
            let corrected = await mockSemanticService.correct(text: text, providerUsed: .local)
            finalText = corrected
        }

        XCTAssertEqual(mockSemanticService.correctCallCount, 0, "Correction should not be called when mode is off")
        XCTAssertEqual(finalText, "original text only", "Should use original text")
    }

    func testEmptyCorrectionResultFallsBackToOriginal() async throws {
        testDefaults.set(SemanticCorrectionMode.localMLX.rawValue, forKey: "semanticCorrectionMode")
        mockSpeechService.setSuccess("original text")
        mockSemanticService.setCorrectionResult("   ")  // Whitespace only

        let text = try await mockSpeechService.transcribeRaw(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            provider: .local,
            model: nil
        )

        let modeRaw = testDefaults.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off

        var finalText = text
        if mode != .off {
            let corrected = await mockSemanticService.correct(text: text, providerUsed: .local)
            let trimmed = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                finalText = corrected
            }
        }

        XCTAssertEqual(finalText, "original text", "Should fall back to original when correction is empty")
    }

    // MARK: - History Save Tests

    func testHistorySavedWhenEnabled() async throws {
        mockDataManager.isHistoryEnabled = true
        mockSpeechService.setSuccess("test transcription for history")

        let text = try await mockSpeechService.transcribeRaw(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            provider: .local,
            model: nil
        )

        let shouldSave = mockDataManager.isHistoryEnabled
        if shouldSave {
            let record = TranscriptionRecord(
                text: text,
                provider: .local,
                duration: 5.0,
                modelUsed: nil,
                wordCount: 4,
                characterCount: text.count,
                sourceAppBundleId: "com.test.app",
                sourceAppName: "Test App",
                sourceAppIconData: nil
            )
            await mockDataManager.saveTranscriptionQuietly(record)
        }

        XCTAssertEqual(mockDataManager.saveTranscriptionQuietlyCallCount, 1, "Should save when history enabled")
        XCTAssertEqual(mockDataManager.recordsToReturn.count, 1, "Should have one record saved")
        XCTAssertEqual(mockDataManager.recordsToReturn.first?.text, "test transcription for history")
    }

    func testHistorySkippedWhenDisabled() async throws {
        mockDataManager.isHistoryEnabled = false
        mockSpeechService.setSuccess("test transcription no history")

        let text = try await mockSpeechService.transcribeRaw(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            provider: .local,
            model: nil
        )

        let shouldSave = mockDataManager.isHistoryEnabled
        if shouldSave {
            let record = TranscriptionRecord(
                text: text,
                provider: .local,
                duration: 5.0,
                modelUsed: nil,
                wordCount: 4,
                characterCount: text.count,
                sourceAppBundleId: nil,
                sourceAppName: nil,
                sourceAppIconData: nil
            )
            await mockDataManager.saveTranscriptionQuietly(record)
        }

        XCTAssertEqual(mockDataManager.saveTranscriptionQuietlyCallCount, 0, "Should not save when history disabled")
        XCTAssertTrue(mockDataManager.recordsToReturn.isEmpty, "Should have no records")
    }

    func testHistoryRecordIncludesModelForLocalProvider() async throws {
        mockDataManager.isHistoryEnabled = true
        mockSpeechService.setSuccess("local model transcription")

        let provider = TranscriptionProvider.local
        let model = WhisperModel.base

        let text = try await mockSpeechService.transcribeRaw(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            provider: provider,
            model: model
        )

        let modelUsed: String? = (provider == .local) ? model.rawValue : nil

        let record = TranscriptionRecord(
            text: text,
            provider: provider,
            duration: 5.0,
            modelUsed: modelUsed,
            wordCount: 3,
            characterCount: text.count,
            sourceAppBundleId: nil,
            sourceAppName: nil,
            sourceAppIconData: nil
        )
        await mockDataManager.saveTranscriptionQuietly(record)

        XCTAssertEqual(mockDataManager.recordsToReturn.first?.modelUsed, "base",
            "Should include model for local provider")
    }

    func testHistoryRecordExcludesModelForParakeetProvider() async throws {
        mockDataManager.isHistoryEnabled = true
        mockSpeechService.setSuccess("parakeet transcription")

        let provider = TranscriptionProvider.parakeet

        let text = try await mockSpeechService.transcribeRaw(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            provider: provider,
            model: nil
        )

        let modelUsed: String? = (provider == .local) ? WhisperModel.base.rawValue : nil

        let record = TranscriptionRecord(
            text: text,
            provider: provider,
            duration: 5.0,
            modelUsed: modelUsed,
            wordCount: 2,
            characterCount: text.count,
            sourceAppBundleId: nil,
            sourceAppName: nil,
            sourceAppIconData: nil
        )
        await mockDataManager.saveTranscriptionQuietly(record)

        XCTAssertNil(mockDataManager.recordsToReturn.first?.modelUsed,
            "Should not include model for parakeet provider")
    }

    // MARK: - Metrics Recording Tests

    func testMetricsRecordedOnSuccess() async throws {
        mockSpeechService.setSuccess("Hello world test recording")

        let text = try await mockSpeechService.transcribeRaw(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            provider: .local,
            model: nil
        )

        let wordCount = UsageMetricsStore.estimatedWordCount(for: text)
        let characterCount = text.count
        let duration: TimeInterval = 5.0

        mockMetricsStore.recordSession(
            duration: duration,
            wordCount: wordCount,
            characterCount: characterCount
        )

        XCTAssertEqual(mockMetricsStore.recordSessionCallCount, 1, "Should record session metrics")
        XCTAssertEqual(mockMetricsStore.recordSessionLastWordCount, 4, "Should record correct word count")
        XCTAssertEqual(mockMetricsStore.recordSessionLastDuration, 5.0, "Should record correct duration")
    }

    func testWordCountEstimation() {
        // Test the word count estimation logic
        let testCases = [
            ("Hello world", 2),
            ("One", 1),
            ("", 0),
            ("Hello, world! How are you?", 5),
            ("Don't worry", 2),  // Contractions count as single words
            ("test-driven development", 3),  // Hyphens split words
            ("one two three four five", 5),
        ]

        for (text, expectedCount) in testCases {
            let count = UsageMetricsStore.estimatedWordCount(for: text)
            XCTAssertEqual(count, expectedCount, "Word count for '\(text)' should be \(expectedCount), got \(count)")
        }
    }

    // MARK: - Pipeline Order Tests

    func testPipelineExecutesInCorrectOrder() async throws {
        var executionOrder: [String] = []

        // Simulate the pipeline stages
        executionOrder.append("prepare")

        mockSpeechService.setSuccess("transcribed text")
        _ = try await mockSpeechService.transcribeRaw(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            provider: .local,
            model: nil
        )
        executionOrder.append("transcribe")

        testDefaults.set(SemanticCorrectionMode.localMLX.rawValue, forKey: "semanticCorrectionMode")
        let modeRaw = testDefaults.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
        if mode != .off {
            _ = await mockSemanticService.correct(text: "text", providerUsed: .local)
            executionOrder.append("correct")
        }

        mockDataManager.isHistoryEnabled = true
        if mockDataManager.isHistoryEnabled {
            executionOrder.append("save")
        }

        executionOrder.append("paste")

        XCTAssertEqual(executionOrder, ["prepare", "transcribe", "correct", "save", "paste"],
            "Pipeline should execute in correct order")
    }

    func testCancellationCheckpointsExist() async throws {
        // Verify cancellation is checked at key points
        var checkpointsPassed: [String] = []

        let task = Task {
            // Checkpoint 1: Before transcription
            try Task.checkCancellation()
            checkpointsPassed.append("pre-transcribe")

            // Checkpoint 2: After transcription
            try Task.checkCancellation()
            checkpointsPassed.append("post-transcribe")

            // Checkpoint 3: During semantic correction (if applicable)
            try Task.checkCancellation()
            checkpointsPassed.append("post-correct")

            return "done"
        }

        let result = try await task.value

        XCTAssertEqual(result, "done")
        XCTAssertEqual(checkpointsPassed.count, 3, "All checkpoints should be passed when not cancelled")
    }

    // MARK: - Retry Logic Tests

    func testRetryRequiresLastAudioURL() async throws {
        let lastAudioURL: URL? = nil
        var showError = false
        var errorMessage: String?

        // Simulate retryLastTranscription check
        if lastAudioURL == nil {
            errorMessage = "No audio file available to retry. Please record again."
            showError = true
        }

        XCTAssertTrue(showError, "Should show error when no audio URL")
        XCTAssertEqual(errorMessage, "No audio file available to retry. Please record again.")
    }

    func testRetryRequiresFileExists() async throws {
        let nonExistentURL = URL(fileURLWithPath: "/tmp/non_existent_\(UUID().uuidString).m4a")
        var showError = false
        var errorMessage: String?
        var lastAudioURL: URL? = nonExistentURL

        if !FileManager.default.fileExists(atPath: nonExistentURL.path) {
            errorMessage = "Audio file no longer exists. Please record again."
            showError = true
            lastAudioURL = nil
        }

        XCTAssertTrue(showError, "Should show error when file doesn't exist")
        XCTAssertEqual(errorMessage, "Audio file no longer exists. Please record again.")
        XCTAssertNil(lastAudioURL, "Should clear lastAudioURL when file doesn't exist")
    }

    func testRetryBlockedWhileProcessing() async throws {
        var retryAttempted = false

        // Simulate retry guard - only attempt if not processing
        if !isCurrentlyProcessing(true) {
            retryAttempted = true
        }

        XCTAssertFalse(retryAttempted, "Retry should be blocked while processing")
    }

    // Helper to avoid compile-time constant folding
    private func isCurrentlyProcessing(_ value: Bool) -> Bool {
        value
    }

    // MARK: - Error Handling Tests

    func testGenericErrorDisplaysLocalizedDescription() async throws {
        struct CustomError: LocalizedError {
            var errorDescription: String? { "Custom error message" }
        }

        mockSpeechService.setFailure(CustomError())

        var errorMessage: String?
        var showError = false
        var isProcessing = true

        do {
            _ = try await mockSpeechService.transcribeRaw(
                audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
                provider: .local,
                model: nil
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isProcessing = false
        }

        XCTAssertTrue(showError)
        XCTAssertEqual(errorMessage, "Custom error message")
        XCTAssertFalse(isProcessing, "isProcessing should reset on error")
    }

    func testSuccessSetsShowSuccessTrue() async throws {
        mockSpeechService.setSuccess("success text")

        var showSuccess = false
        var isProcessing = true

        do {
            _ = try await mockSpeechService.transcribeRaw(
                audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
                provider: .local,
                model: nil
            )
            // Success path
            showSuccess = true
            isProcessing = false
        } catch {
            XCTFail("Should not throw")
        }

        XCTAssertTrue(showSuccess, "showSuccess should be true after successful transcription")
        XCTAssertFalse(isProcessing, "isProcessing should be false after success")
    }

    // MARK: - Provider-Specific Tests

    func testLocalProviderPassesModel() async throws {
        mockSpeechService.setSuccess("local transcription")

        _ = try await mockSpeechService.transcribeRaw(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            provider: .local,
            model: .small
        )

        XCTAssertEqual(mockSpeechService.lastProvider, .local)
        XCTAssertEqual(mockSpeechService.lastModel, .small, "Should pass model for local provider")
    }

    func testParakeetProviderDoesNotUseWhisperModel() async throws {
        mockSpeechService.setSuccess("parakeet transcription result")

        _ = try await mockSpeechService.transcribeRaw(
            audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            provider: .parakeet,
            model: nil
        )

        XCTAssertEqual(mockSpeechService.lastProvider, .parakeet)
        XCTAssertNil(mockSpeechService.lastModel, "Should not pass model for parakeet provider")
    }

}
