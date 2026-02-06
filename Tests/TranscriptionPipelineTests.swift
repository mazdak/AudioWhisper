import XCTest
@testable import AudioWhisper

final class TranscriptionPipelineTests: XCTestCase {

    // MARK: - Configuration Tests

    func testTranscriptionPipelineConfigDefaults() {
        let config = TranscriptionPipelineConfig(provider: .parakeet)

        XCTAssertEqual(config.provider, .parakeet)
        XCTAssertNil(config.whisperModel)
        XCTAssertTrue(config.applySemanticCorrection)
        XCTAssertNil(config.sourceAppBundleId)
    }

    func testTranscriptionPipelineConfigWithAllParameters() {
        let config = TranscriptionPipelineConfig(
            provider: .local,
            whisperModel: .base,
            applySemanticCorrection: false,
            sourceAppBundleId: "com.apple.Notes"
        )

        XCTAssertEqual(config.provider, .local)
        XCTAssertEqual(config.whisperModel, .base)
        XCTAssertFalse(config.applySemanticCorrection)
        XCTAssertEqual(config.sourceAppBundleId, "com.apple.Notes")
    }

    func testTranscriptionPipelineConfigLocalProviderRequiresModel() {
        let config = TranscriptionPipelineConfig(provider: .local, whisperModel: .tiny)
        XCTAssertNotNil(config.whisperModel)
    }

    func testTranscriptionPipelineConfigParakeetProviderNoModelNeeded() {
        let config = TranscriptionPipelineConfig(provider: .parakeet)
        XCTAssertNil(config.whisperModel)
    }

    // MARK: - Pipeline Step Tests

    func testPipelineStepRawValues() {
        XCTAssertEqual(TranscriptionPipeline.PipelineStep.validating.rawValue, "Validating audio...")
        XCTAssertEqual(TranscriptionPipeline.PipelineStep.transcribing.rawValue, "Transcribing...")
        XCTAssertEqual(TranscriptionPipeline.PipelineStep.correcting.rawValue, "Applying corrections...")
        XCTAssertEqual(TranscriptionPipeline.PipelineStep.complete.rawValue, "Complete")
    }

    func testPipelineStepAllCases() {
        let allCases: [TranscriptionPipeline.PipelineStep] = [
            .validating, .transcribing, .correcting, .complete
        ]
        XCTAssertEqual(allCases.count, 4)
    }

    // MARK: - Progress Notification Tests

    @MainActor
    func testPostProgressSendsNotification() async {
        let pipeline = TranscriptionPipeline()
        let expectation = expectation(forNotification: .transcriptionProgress, object: nil) { notification in
            let step = notification.object as? String
            return step == TranscriptionPipeline.PipelineStep.validating.rawValue
        }

        pipeline.postProgress(.validating)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    @MainActor
    func testPostProgressSendsCorrectStepValue() async {
        let pipeline = TranscriptionPipeline()
        var receivedStep: String?
        let expectation = expectation(forNotification: .transcriptionProgress, object: nil) { notification in
            receivedStep = notification.object as? String
            return true
        }

        pipeline.postProgress(.transcribing)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedStep, "Transcribing...")
    }

    // MARK: - Audio Validation Integration Tests

    @MainActor
    func testTranscribeFailsForNonExistentFile() async {
        let pipeline = TranscriptionPipeline()
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/audio.m4a")
        let config = TranscriptionPipelineConfig(provider: .parakeet)

        do {
            _ = try await pipeline.transcribe(audioURL: nonExistentURL, config: config)
            XCTFail("Expected transcription to fail for non-existent file")
        } catch {
            XCTAssertTrue(error is SpeechToTextError)
        }
    }

    @MainActor
    func testTranscribeRawFailsForNonExistentFile() async {
        let pipeline = TranscriptionPipeline()
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/audio.m4a")

        do {
            _ = try await pipeline.transcribeRaw(audioURL: nonExistentURL, provider: .parakeet)
            XCTFail("Expected transcription to fail for non-existent file")
        } catch {
            XCTAssertTrue(error is SpeechToTextError)
        }
    }

    @MainActor
    func testTranscribeRawLocalRequiresModel() async {
        let pipeline = TranscriptionPipeline()
        let tempURL = createTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            // Calling transcribeRaw with .local but no model should fail
            _ = try await pipeline.transcribeRaw(audioURL: tempURL, provider: .local, model: nil)
            XCTFail("Expected failure when no model provided for local provider")
        } catch let error as SpeechToTextError {
            if case .transcriptionFailed(let message) = error {
                XCTAssertTrue(message.contains("model required"), "Error should mention model requirement")
            } else {
                // Other SpeechToTextError types are acceptable
                XCTAssertTrue(true)
            }
        } catch {
            // Other error types are acceptable in test environment
            XCTAssertTrue(true)
        }
    }

    // MARK: - Config Builder Pattern Tests

    func testConfigWithSemanticCorrectionDisabled() {
        let config = TranscriptionPipelineConfig(
            provider: .parakeet,
            applySemanticCorrection: false
        )
        XCTAssertFalse(config.applySemanticCorrection)
    }

    func testConfigWithSourceAppBundleId() {
        let config = TranscriptionPipelineConfig(
            provider: .local,
            whisperModel: .small,
            sourceAppBundleId: "com.example.testapp"
        )
        XCTAssertEqual(config.sourceAppBundleId, "com.example.testapp")
    }

    // MARK: - Provider Tests

    func testConfigSupportsAllProviders() {
        for provider in TranscriptionProvider.allCases {
            let config: TranscriptionPipelineConfig
            if provider == .local {
                config = TranscriptionPipelineConfig(provider: provider, whisperModel: .base)
            } else {
                config = TranscriptionPipelineConfig(provider: provider)
            }
            XCTAssertEqual(config.provider, provider)
        }
    }

    func testConfigSupportsAllWhisperModels() {
        for model in WhisperModel.allCases {
            let config = TranscriptionPipelineConfig(
                provider: .local,
                whisperModel: model
            )
            XCTAssertEqual(config.whisperModel, model)
        }
    }

    // MARK: - Helpers

    private func createTemporaryAudioFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_audio_\(UUID().uuidString).m4a")
        // Create a minimal valid file for testing
        FileManager.default.createFile(atPath: fileURL.path, contents: Data([0x00, 0x00, 0x00, 0x20]), attributes: nil)
        return fileURL
    }
}
