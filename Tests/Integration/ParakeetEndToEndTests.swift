import XCTest
@testable import AudioWhisper

/// End-to-end integration test that exercises the real Parakeet/MLX subprocess
/// flow: venv bootstrap -> model load -> daemon spawn -> JSON-RPC -> transcription.
///
/// This test is OPT-IN. It requires:
///   - Apple Silicon (Parakeet-MLX requires arm64)
///   - Network access on first run (downloads ~2.5 GB model)
///   - One of:
///       * `RUN_E2E=1` — the new generic e2e gate (preferred), or
///       * `RUN_PARAKEET_E2E=1` — backwards-compatible alias
///
/// The test self-bootstraps the model if it isn't cached, so nightly CI can
/// run it from a clean machine. Subsequent runs reuse the HuggingFace cache.
///
/// Run from the command line:
///   RUN_E2E=1 swift test --filter ParakeetEndToEndTests
///
/// CI runs this nightly only; per-PR runs skip it via XCTSkip below.
final class ParakeetEndToEndTests: XCTestCase {

    func test_e2e_transcribeShortClip() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_E2E"] == "1"
                || ProcessInfo.processInfo.environment["RUN_PARAKEET_E2E"] == "1",
            "Parakeet E2E test is gated. Set RUN_E2E=1 (or RUN_PARAKEET_E2E=1) to run."
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

        // Step 1: Ensure the model is on disk. MLXModelManager is the
        // canonical entry point used by the in-app Settings flow; calling it
        // here means a fresh CI box can run this test end-to-end without a
        // manual pre-cache step. `ensureParakeetModel()` short-circuits when
        // the cache is already populated.
        await MLXModelManager.shared.ensureParakeetModel()

        // Step 2: Warm up the daemon and verify the cache is consistent. This
        // throws `ParakeetError.modelNotReady` if the download above failed
        // (e.g. no network on a sandboxed runner) so the test fails with a
        // clear signal instead of a generic transcription error.
        let service = ParakeetService.shared
        try await service.validateSetup()

        // Step 3: Transcribe the fixture.
        let text = try await service.transcribe(audioFileURL: fixtureURL)

        XCTAssertFalse(
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "Parakeet returned an empty transcript -- check daemon logs."
        )
        // Don't assert on exact text content -- the model is non-deterministic
        // across versions; presence-of-output is sufficient.
    }
}
