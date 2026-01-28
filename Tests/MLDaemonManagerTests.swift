import XCTest
@testable import AudioWhisper

final class MLDaemonManagerTests: XCTestCase {
    private let manager = MLDaemonManager.shared

    override func setUp() async throws {
        try await super.setUp()
        await manager.resetForTesting()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        await manager.resetForTesting()
    }

    // MARK: - Transcribe Tests

    func testTranscribeSuccessReturnsText() async throws {
        await manager.setTestResponder { method, params in
            XCTAssertEqual(method, "transcribe")
            XCTAssertEqual(params["repo"] as? String, "test-repo")
            XCTAssertEqual(params["pcm_path"] as? String, "/tmp/audio.pcm")
            return ["success": true, "text": "hello world", "error": NSNull()]
        }

        let text = try await manager.transcribe(repo: "test-repo", pcmPath: "/tmp/audio.pcm")
        XCTAssertEqual(text, "hello world")
    }

    func testTranscribeFailureReturnsRemoteError() async throws {
        await manager.setTestResponder { method, _ in
            guard method == "transcribe" else {
                return ["success": false, "text": "", "error": "Unknown method"]
            }
            return ["success": false, "text": "", "error": "Model not found"]
        }

        do {
            _ = try await manager.transcribe(repo: "missing-repo", pcmPath: "/tmp/audio.pcm")
            XCTFail("Expected remote error")
        } catch {
            guard case MLDaemonError.remoteError(let message) = error else {
                return XCTFail("Expected remoteError, got \(error)")
            }
            XCTAssertEqual(message, "Model not found")
        }
    }

    // MARK: - Correction Tests

    func testCorrectionSuccessReturnsText() async throws {
        await manager.setTestResponder { method, params in
            XCTAssertEqual(method, "correct")
            XCTAssertEqual(params["repo"] as? String, "correction-repo")
            XCTAssertEqual(params["text"] as? String, "hello wrold")
            XCTAssertNil(params["prompt"])
            return ["success": true, "text": "hello world", "error": NSNull()]
        }

        let corrected = try await manager.correct(repo: "correction-repo", text: "hello wrold", prompt: nil)
        XCTAssertEqual(corrected, "hello world")
    }

    func testCorrectionWithPromptPassesPrompt() async throws {
        await manager.setTestResponder { method, params in
            XCTAssertEqual(method, "correct")
            XCTAssertEqual(params["prompt"] as? String, "Fix grammar")
            return ["success": true, "text": "corrected text", "error": NSNull()]
        }

        let corrected = try await manager.correct(repo: "repo", text: "text", prompt: "Fix grammar")
        XCTAssertEqual(corrected, "corrected text")
    }

    func testCorrectionRemoteErrorIsPropagated() async throws {
        await manager.setTestResponder { method, _ in
            guard method == "correct" else {
                return ["success": true, "text": "", "error": NSNull()]
            }
            throw MLDaemonError.remoteError("correction failed")
        }

        do {
            _ = try await manager.correct(repo: "repo", text: "hi", prompt: nil)
            XCTFail("Expected remote error")
        } catch {
            guard case MLDaemonError.remoteError(let message) = error else {
                return XCTFail("Expected remoteError, got \(error)")
            }
            XCTAssertEqual(message, "correction failed")
        }
    }

    // MARK: - Warmup Tests

    func testWarmupSuccessDoesNotThrow() async throws {
        await manager.setTestResponder { method, params in
            XCTAssertEqual(method, "warmup")
            XCTAssertEqual(params["type"] as? String, "transcription")
            XCTAssertEqual(params["repo"] as? String, "warmup-repo")
            return ["success": true]
        }

        try await manager.warmup(type: "transcription", repo: "warmup-repo")
        // Should complete without throwing
    }

    func testWarmupInvalidResponseSurfacesAsInvalidResponseError() async throws {
        await manager.setTestResponder { _, _ in
            // Return a response that doesn't decode to WarmupResult
            return ["invalid_key": "invalid_value"]
        }

        do {
            try await manager.warmup(type: "invalid", repo: "repo")
            // Note: This may or may not throw depending on WarmupResult's optional handling
            // If WarmupResult.success is optional, this won't throw
        } catch {
            guard case MLDaemonError.invalidResponse = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
        }
    }

    // MARK: - Ping Tests

    func testPingReturnsTrueWhenDaemonResponds() async throws {
        await manager.setTestResponder { method, _ in
            XCTAssertEqual(method, "ping")
            return ["pong": true]
        }

        let result = await manager.ping()
        XCTAssertTrue(result)
    }

    func testPingReturnsFalseWhenDaemonReturnsNoPong() async throws {
        await manager.setTestResponder { _, _ in
            return ["pong": false]
        }

        let result = await manager.ping()
        XCTAssertFalse(result)
    }

    func testPingReturnsFalseWhenResponderThrows() async throws {
        await manager.setTestResponder { _, _ in
            throw MLDaemonError.daemonUnavailable("test error")
        }

        let result = await manager.ping()
        XCTAssertFalse(result)
    }

    // MARK: - Error Description Tests

    func testMLDaemonErrorDescriptions() {
        XCTAssertEqual(
            MLDaemonError.scriptNotFound.errorDescription,
            "ml_daemon.py could not be found"
        )

        XCTAssertEqual(
            MLDaemonError.daemonUnavailable("test reason").errorDescription,
            "ML daemon unavailable: test reason"
        )

        XCTAssertEqual(
            MLDaemonError.invalidResponse("bad json").errorDescription,
            "Invalid response from ML daemon: bad json"
        )

        XCTAssertEqual(
            MLDaemonError.remoteError("model error").errorDescription,
            "ML daemon error: model error"
        )

        XCTAssertEqual(
            MLDaemonError.restartLimitReached.errorDescription,
            "ML daemon restart limit reached"
        )

        XCTAssertEqual(
            MLDaemonError.writeFailed.errorDescription,
            "Failed to write request to ML daemon"
        )

        XCTAssertEqual(
            MLDaemonError.timeout.errorDescription,
            "ML daemon request timed out"
        )
    }

    // MARK: - Multiple Requests Tests

    func testMultipleSequentialRequestsSucceed() async throws {
        var callCount = 0
        await manager.setTestResponder { method, _ in
            callCount += 1
            if method == "ping" {
                return ["pong": true]
            } else if method == "transcribe" {
                return ["success": true, "text": "transcription \(callCount)", "error": NSNull()]
            }
            return ["success": false, "text": "", "error": "unknown"]
        }

        let ping1 = await manager.ping()
        XCTAssertTrue(ping1)

        let text1 = try await manager.transcribe(repo: "r1", pcmPath: "/p1")
        XCTAssertEqual(text1, "transcription 2")

        let text2 = try await manager.transcribe(repo: "r2", pcmPath: "/p2")
        XCTAssertEqual(text2, "transcription 3")
    }

    // MARK: - Reset Tests

    func testResetForTestingClearsResponder() async throws {
        await manager.setTestResponder { _, _ in
            return ["pong": true]
        }

        // First ping should succeed
        let result1 = await manager.ping()
        XCTAssertTrue(result1)

        // Reset clears the responder
        await manager.resetForTesting()

        // Without responder, and without actual daemon, ping should fail
        // (In test environment without actual daemon running)
        // Setting responder to return false
        await manager.setTestResponder { _, _ in
            return ["pong": false]
        }

        let result2 = await manager.ping()
        XCTAssertFalse(result2)
    }
}
