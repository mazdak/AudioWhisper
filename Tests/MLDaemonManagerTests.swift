import XCTest
@testable import AudioWhisper

final class MLDaemonManagerTests: XCTestCase {
    private let manager = MLDaemonManager.shared

    override func setUp() async throws {
        try await super.setUp()
        await manager.resetForTesting()
        await manager.setTestResponder { method, _ in
            switch method {
            case "transcribe":
                return ["success": true, "text": "hello world", "error": NSNull()]
            case "correct":
                throw MLDaemonError.remoteError("remote boom")
            default:
                return ["success": "invalid"]
            }
        }
    }

    override func tearDown() async throws {
        try await super.tearDown()
        await manager.resetForTesting()
    }

    func testTranscribeSuccessReturnsText() async throws {
        let text = try await manager.transcribe(repo: "repo", pcmPath: "/tmp/audio.pcm")
        XCTAssertEqual(text, "hello world")
    }

    func testRemoteErrorIsPropagated() async throws {
        do {
            _ = try await self.manager.correct(repo: "repo", text: "hi", prompt: nil)
            XCTFail("Expected remote error")
        } catch {
            guard case MLDaemonError.remoteError(let message) = error else {
                return XCTFail("Expected remoteError, got \(error)")
            }
            XCTAssertEqual(message, "remote boom")
        }
    }

    func testInvalidResponseSurfacesAsInvalidResponseError() async throws {
        do {
            try await self.manager.warmup(type: "invalid", repo: "repo")
            XCTFail("Expected invalidResponse to throw")
        } catch {
            guard case MLDaemonError.invalidResponse = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
        }
    }
}
