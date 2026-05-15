import XCTest
import Foundation
@testable import AudioWhisper

class ParakeetServiceTests: IsolatedXCTestCase {
    // TODO(D1): ParakeetService reads `selectedParakeetModel` from
    // UserDefaults.standard via AppDefaults. Once AppDefaults accepts an
    // injected UserDefaults, route writes through a UUID-scoped suite and
    // re-enable isolation.
    override var enforcesStandardUserDefaultsIsolation: Bool { false }

    var parakeetService: ParakeetService!
    var originalRepo: String?
    
    override func setUp() {
        super.setUp()
        originalRepo = UserDefaults.standard.string(forKey: "selectedParakeetModel")
        parakeetService = ParakeetService()
    }
    
    override func tearDown() {
        if let originalRepo {
            UserDefaults.standard.set(originalRepo, forKey: "selectedParakeetModel")
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedParakeetModel")
        }
        parakeetService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests

    func testParakeetServiceInitialization() {
        XCTAssertNotNil(parakeetService)
    }

    // MARK: - B4: Persisted model validation

    func test_invalidStoredModelName_fallsBackToDefault() {
        let key = "selectedParakeetModel"

        // Bogus stored value should resolve to the documented default model.
        UserDefaults.standard.set("nonexistent-model-name", forKey: key)
        XCTAssertEqual(parakeetService.safeSelectedParakeetModel, ParakeetService.defaultModel)

        // Empty/missing value should likewise fall back to the default.
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertEqual(parakeetService.safeSelectedParakeetModel, ParakeetService.defaultModel)

        // A valid stored value round-trips back to the matching enum case.
        UserDefaults.standard.set(ParakeetModel.v2English.rawValue, forKey: key)
        XCTAssertEqual(parakeetService.safeSelectedParakeetModel, .v2English)
        // tearDown restores the original value captured in setUp.
    }
    
    // MARK: - Error Tests
    
    func testParakeetErrorDescriptions() {
        let pythonNotFoundError = ParakeetError.pythonNotFound(path: "/invalid/path")
        let scriptNotFoundError = ParakeetError.scriptNotFound
        let transcriptionFailedError = ParakeetError.transcriptionFailed("Test error")
        let invalidResponseError = ParakeetError.invalidResponse("Invalid JSON")
        let dependencyMissingError = ParakeetError.dependencyMissing("parakeet-mlx", installCommand: "pip install parakeet-mlx")
        let timeoutError = ParakeetError.processTimedOut(30)
        
        XCTAssertTrue(pythonNotFoundError.errorDescription!.contains("/invalid/path"))
        XCTAssertEqual(scriptNotFoundError.errorDescription, "Parakeet transcription script not found in app bundle")
        XCTAssertEqual(transcriptionFailedError.errorDescription, "Parakeet transcription failed: Test error")
        XCTAssertEqual(invalidResponseError.errorDescription, "Invalid response from Parakeet: Invalid JSON")
        XCTAssertTrue(dependencyMissingError.errorDescription!.contains("uv"))
        XCTAssertTrue(timeoutError.errorDescription!.contains("30.0 seconds"))
    }
    
    // MARK: - Validation Tests
    
    func testValidateSetupRequiresCachedModel() async throws {
        // The persisted preference is now validated against `ParakeetModel`, so we
        // must pick a real enum case that isn't cached locally instead of using a
        // random throw-away repo string. If both supported models happen to be
        // cached on this machine, the precondition can't be met — skip rather
        // than fail spuriously.
        guard let uncachedModel = Self.firstUncachedParakeetModel() else {
            throw XCTSkip("Both Parakeet models appear cached locally; cannot exercise modelNotReady path.")
        }
        UserDefaults.standard.set(uncachedModel.rawValue, forKey: "selectedParakeetModel")

        do {
            try await parakeetService.validateSetup(pythonPath: "/usr/bin/python3")
            XCTFail("Should have thrown modelNotReady when cache is missing")
        } catch let error as ParakeetError {
            XCTAssertEqual(error, ParakeetError.modelNotReady)
        } catch {
            XCTFail("Should have thrown ParakeetError, got \(error)")
        }
    }
    
    // MARK: - Response Parsing Tests
    
    func testParakeetResponseParsing() throws {
        let successResponseJSON = """
        {
            "text": "Hello world",
            "success": true
        }
        """
        
        let failureResponseJSON = """
        {
            "text": "",
            "success": false,
            "error": "Model not found"
        }
        """
        
        let successData = successResponseJSON.data(using: .utf8)!
        let failureData = failureResponseJSON.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        
        let successResponse = try decoder.decode(ParakeetResponse.self, from: successData)
        XCTAssertEqual(successResponse.text, "Hello world")
        XCTAssertTrue(successResponse.success)
        XCTAssertNil(successResponse.error)
        
        let failureResponse = try decoder.decode(ParakeetResponse.self, from: failureData)
        XCTAssertEqual(failureResponse.text, "")
        XCTAssertFalse(failureResponse.success)
        XCTAssertEqual(failureResponse.error, "Model not found")
    }
    
    // MARK: - File Path Tests
    
    func testTranscribeRequiresCachedModel() async throws {
        // See note on testValidateSetupRequiresCachedModel — must pick a real
        // enum case that isn't cached locally, since the persisted preference
        // is now validated against `ParakeetModel`.
        guard let uncachedModel = Self.firstUncachedParakeetModel() else {
            throw XCTSkip("Both Parakeet models appear cached locally; cannot exercise modelNotReady path.")
        }
        UserDefaults.standard.set(uncachedModel.rawValue, forKey: "selectedParakeetModel")
        let testAudioURL = URL(fileURLWithPath: "/tmp/test.m4a")

        do {
            _ = try await parakeetService.transcribe(audioFileURL: testAudioURL, pythonPath: "/usr/bin/python3")
            XCTFail("Expected modelNotReady when model cache is missing")
        } catch let error as ParakeetError {
            XCTAssertEqual(error, .modelNotReady)
        } catch {
            XCTFail("Should have thrown ParakeetError, got \(error)")
        }
    }

    /// Returns the first `ParakeetModel` whose Hugging Face cache directory is
    /// not present on disk, or `nil` if all supported models appear cached.
    private static func firstUncachedParakeetModel() -> ParakeetModel? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ParakeetModel.allCases.first { model in
            let escaped = model.rawValue.replacingOccurrences(of: "/", with: "--")
            let dir = home.appendingPathComponent(".cache/huggingface/hub/models--\(escaped)")
            return !FileManager.default.fileExists(atPath: dir.path)
        }
    }
    
    // MARK: - Performance Tests
    
    func testParakeetServiceCreationPerformance() {
        measure {
            let service = ParakeetService()
            XCTAssertNotNil(service)
        }
    }
    
    func testErrorDescriptionPerformance() {
        let errors: [ParakeetError] = [
            .pythonNotFound(path: "/test/path"),
            .scriptNotFound,
            .transcriptionFailed("Test"),
            .invalidResponse("Test")
        ]
        
        measure {
            for error in errors {
                _ = error.errorDescription
            }
        }
    }
    
    // MARK: - Bundle Resource Tests
    
    func testDaemonScriptExists() {
        // Test that the ML daemon script can be found in the bundle
        // In test environment, check both Bundle.main and source directory
        let scriptURL = Bundle.main.url(forResource: "ml_daemon", withExtension: "py")
        
        if scriptURL != nil {
            // Script found in bundle
            XCTAssertNotNil(scriptURL, "ML daemon script should be available in app bundle")
        } else {
            // In test environment, check if script exists in source directory
            let currentDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            let sourceDir = currentDir.deletingLastPathComponent().appendingPathComponent("Sources")
            let sourceScriptURL = sourceDir.appendingPathComponent("ml_daemon.py")
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: sourceScriptURL.path), 
                         "ML daemon script should be available in source directory during tests")
        }
    }
}
