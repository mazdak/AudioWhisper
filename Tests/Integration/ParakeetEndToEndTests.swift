import XCTest
@testable import AudioWhisper

/// End-to-end integration test that exercises the real Parakeet/MLX subprocess
/// flow: venv bootstrap -> model load -> daemon spawn -> JSON-RPC -> transcription.
///
/// This test is OPT-IN. It requires:
///   - Apple Silicon (Parakeet-MLX requires arm64)
///   - Network access on first run (downloads ~2.5 GB model)
///   - A pre-downloaded Parakeet model in ~/.cache/huggingface (the service
///     deliberately does not auto-download from this entry point; download via
///     the in-app Settings -> Parakeet pane first if needed)
///   - The env var `RUN_PARAKEET_E2E=1`
///
/// Run from the command line:
///   RUN_PARAKEET_E2E=1 swift test --filter ParakeetEndToEndTests
///
/// CI runs this nightly only; per-PR runs skip it via XCTSkip below.
final class ParakeetEndToEndTests: XCTestCase {

    func test_e2e_transcribeShortClip() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_PARAKEET_E2E"] == "1",
            "Parakeet E2E test is gated. Set RUN_PARAKEET_E2E=1 to run."
        )

        try XCTSkipUnless(
            Arch.isAppleSilicon,
            "Parakeet requires Apple Silicon."
        )

        guard let fixtureURL = Bundle.module.url(
            forResource: "test_audio",
            withExtension: "wav",
            subdirectory: "Resources"
        ) else {
            XCTFail("Missing Tests/Resources/test_audio.wav fixture")
            return
        }

        let service = ParakeetService.shared

        // Preflight: ensures the model cache is present and the MLX daemon
        // warms up. If the model has not been downloaded yet this will throw
        // `ParakeetError.modelNotReady` -- download via Settings first.
        try await service.validateSetup()

        let text = try await service.transcribe(audioFileURL: fixtureURL)

        XCTAssertFalse(
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "Parakeet returned an empty transcript -- check daemon logs."
        )
        // Don't assert on exact text content -- the model is non-deterministic
        // across versions; presence-of-output is sufficient.
    }
}
