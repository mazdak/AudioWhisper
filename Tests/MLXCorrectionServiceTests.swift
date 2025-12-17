import XCTest
@testable import AudioWhisper

private final class MockMLDaemon: MLDaemonManaging {
    var lastRepo: String?
    var lastText: String?
    var lastPrompt: String?
    var nextCorrectResult: Result<String, Error> = .success("corrected")
    var pingResult: Bool = true
    
    func correct(repo: String, text: String, prompt: String?) async throws -> String {
        lastRepo = repo
        lastText = text
        lastPrompt = prompt
        return try nextCorrectResult.get()
    }
    
    func ping() async -> Bool {
        pingResult
    }
}

final class MLXCorrectionServiceTests: XCTestCase {
    func testCorrectUsesPromptLoaderAndReturnsResult() async throws {
        let daemon = MockMLDaemon()
        daemon.nextCorrectResult = .success("fixed text")
        
        var loaderCalled = false
        let service = MLXCorrectionService(
            daemon: daemon,
            promptLoader: {
                loaderCalled = true
                return "file prompt"
            }
        )
        
        let result = try await service.correct(
            text: "hello",
            modelRepo: "mlx-community/model",
            pythonPath: "/tmp/python"
        )
        
        XCTAssertEqual(result, "fixed text")
        XCTAssertTrue(loaderCalled, "Prompt loader should be used when systemPrompt is nil")
        XCTAssertEqual(daemon.lastRepo, "mlx-community/model")
        XCTAssertEqual(daemon.lastText, "hello")
        XCTAssertEqual(daemon.lastPrompt, "file prompt")
    }
    
    func testCorrectPrefersExplicitSystemPrompt() async throws {
        let daemon = MockMLDaemon()
        let service = MLXCorrectionService(
            daemon: daemon,
            promptLoader: { "fallback prompt" }
        )
        
        _ = try await service.correct(
            text: "hi",
            modelRepo: "repo",
            pythonPath: "/tmp/python",
            systemPrompt: "explicit prompt"
        )
        
        XCTAssertEqual(daemon.lastPrompt, "explicit prompt", "Explicit systemPrompt should override loader")
    }
    
    func testCorrectMapsDependencyMissingError() async {
        let daemon = MockMLDaemon()
        daemon.nextCorrectResult = .failure(
            MLDaemonError.remoteError("ModuleNotFoundError: No module named 'mlx_lm'")
        )
        let service = MLXCorrectionService(daemon: daemon, promptLoader: { nil })
        
        do {
            _ = try await service.correct(text: "text", modelRepo: "repo", pythonPath: "/tmp/python")
            XCTFail("Expected dependencyMissing error")
        } catch {
            guard case MLXCorrectionError.dependencyMissing(let dep, let command) = error else {
                return XCTFail("Expected dependencyMissing error")
            }
            XCTAssertEqual(dep, "mlx-lm")
            XCTAssertEqual(command, "uv add mlx-lm")
        }
    }
    
    func testCorrectMapsScriptNotFoundError() async {
        let daemon = MockMLDaemon()
        daemon.nextCorrectResult = .failure(MLDaemonError.scriptNotFound)
        let service = MLXCorrectionService(daemon: daemon, promptLoader: { nil })
        
        do {
            _ = try await service.correct(text: "text", modelRepo: "repo", pythonPath: "/tmp/python")
            XCTFail("Expected scriptNotFound")
        } catch {
            XCTAssertEqual(error as? MLXCorrectionError, .scriptNotFound)
        }
    }
    
    func testCorrectMapsDaemonUnavailableError() async {
        let daemon = MockMLDaemon()
        daemon.nextCorrectResult = .failure(MLDaemonError.daemonUnavailable("down"))
        let service = MLXCorrectionService(daemon: daemon, promptLoader: { nil })
        
        do {
            _ = try await service.correct(text: "text", modelRepo: "repo", pythonPath: "/tmp/python")
            XCTFail("Expected daemonUnavailable")
        } catch {
            XCTAssertEqual(error as? MLXCorrectionError, .daemonUnavailable("down"))
        }
    }
    
    func testCorrectWrapsUnknownError() async {
        let daemon = MockMLDaemon()
        daemon.nextCorrectResult = .failure(NSError(domain: "test", code: 1))
        let service = MLXCorrectionService(daemon: daemon, promptLoader: { nil })
        
        do {
            _ = try await service.correct(text: "text", modelRepo: "repo", pythonPath: "/tmp/python")
            XCTFail("Expected correctionFailed")
        } catch {
            guard case MLXCorrectionError.correctionFailed(let message) = error else {
                return XCTFail("Expected correctionFailed")
            }
            XCTAssertFalse(message.isEmpty)
        }
    }
    
    func testValidateSetupMissingPythonPathThrows() async {
        let daemon = MockMLDaemon()
        let service = MLXCorrectionService(daemon: daemon, promptLoader: { nil })
        
        do {
            _ = try await service.validateSetup(pythonPath: "/path/does/not/exist")
            XCTFail("Expected pythonNotFound")
        } catch {
            guard case MLXCorrectionError.pythonNotFound(let path) = error else {
                return XCTFail("Expected pythonNotFound")
            }
            XCTAssertEqual(path, "/path/does/not/exist")
        }
    }
    
    func testValidateSetupPingFailureThrows() async throws {
        let daemon = MockMLDaemon()
        daemon.pingResult = false
        
        // Create a real temporary file so fileExists passes
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tempFile.path, contents: Data())
        
        let service = MLXCorrectionService(daemon: daemon, promptLoader: { nil })
        
        do {
            _ = try await service.validateSetup(pythonPath: tempFile.path)
            XCTFail("Expected daemonUnavailable")
        } catch {
            XCTAssertEqual(error as? MLXCorrectionError, .daemonUnavailable("daemon not responding"))
        }
    }
    
    func testValidateSetupSucceedsWhenPathExistsAndPingOk() async throws {
        let daemon = MockMLDaemon()
        daemon.pingResult = true
        
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tempFile.path, contents: Data())
        
        let service = MLXCorrectionService(daemon: daemon, promptLoader: { nil })
        
        try await service.validateSetup(pythonPath: tempFile.path)
    }
}
