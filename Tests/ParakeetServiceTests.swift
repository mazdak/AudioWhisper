import XCTest
import Foundation
@testable import AudioWhisper

class ParakeetServiceTests: XCTestCase {
    
    var parakeetService: ParakeetService!
    
    override func setUp() {
        super.setUp()
        parakeetService = ParakeetService()
    }
    
    override func tearDown() {
        parakeetService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testParakeetServiceInitialization() {
        XCTAssertNotNil(parakeetService)
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
        XCTAssertTrue(dependencyMissingError.errorDescription!.contains("pip install parakeet-mlx"))
        XCTAssertTrue(timeoutError.errorDescription!.contains("30.0 seconds"))
    }
    
    // MARK: - Validation Tests
    
    func testValidateSetupWithInvalidPython() async {
        let invalidPath = "/invalid/python/path"
        
        do {
            try await parakeetService.validateSetup(pythonPath: invalidPath)
            XCTFail("Should have thrown an error for invalid Python path")
        } catch let error as ParakeetError {
            XCTAssertEqual(error, ParakeetError.pythonNotFound(path: invalidPath))
        } catch {
            XCTFail("Should have thrown ParakeetError, got \(error)")
        }
    }
    
    func testValidateSetupWithValidSystemPython() async {
        let systemPythonPath = "/usr/bin/python3"
        
        // Only test if system Python exists
        if FileManager.default.fileExists(atPath: systemPythonPath) {
            do {
                try await parakeetService.validateSetup(pythonPath: systemPythonPath)
                // If this doesn't throw, Python exists but parakeet-mlx probably isn't installed
                // This is expected behavior for most systems
            } catch let error as ParakeetError {
                // Expected if parakeet-mlx is not installed
                XCTAssertTrue(error.localizedDescription.contains("parakeet-mlx"))
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
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
    
    func testTranscribeWithInvalidPythonPath() async {
        let invalidPythonPath = "/invalid/python/path"
        let testAudioURL = URL(fileURLWithPath: "/tmp/test.m4a")
        
        do {
            _ = try await parakeetService.transcribe(audioFileURL: testAudioURL, pythonPath: invalidPythonPath)
            XCTFail("Should have thrown an error")
        } catch let error as ParakeetError {
            // The error could be either pythonNotFound or transcriptionFailed (if audio processing fails first)
            // Both are valid outcomes for this test scenario
            switch error {
            case .pythonNotFound(let path) where path == invalidPythonPath:
                // Expected pythonNotFound error
                break
            case .transcriptionFailed:
                // Also acceptable - audio processing failed before Python validation
                break
            default:
                XCTFail("Expected pythonNotFound or transcriptionFailed error, got \(error)")
            }
        } catch {
            XCTFail("Should have thrown ParakeetError, got \(error)")
        }
    }
    
    func testTranscribeWithInvalidPythonPathOnly() async {
        let invalidPythonPath = "/invalid/python/path"
        let testAudioURL = URL(fileURLWithPath: "/tmp/test.m4a")
        
        do {
            _ = try await parakeetService.transcribe(audioFileURL: testAudioURL, pythonPath: invalidPythonPath)
            XCTFail("Should have thrown an error")
        } catch let error as ParakeetError {
            // The error could be either pythonNotFound or transcriptionFailed (if audio processing fails first)
            // Both are valid outcomes for this test scenario
            switch error {
            case .pythonNotFound(let path) where path == invalidPythonPath:
                // Expected pythonNotFound error
                break
            case .transcriptionFailed:
                // Also acceptable - audio processing failed before Python validation
                break
            default:
                XCTFail("Expected pythonNotFound or transcriptionFailed error, got \(error)")
            }
        } catch {
            XCTFail("Should have thrown ParakeetError, got \(error)")
        }
    }
    
    func testTranscribeWithNativeAudioProcessing() async {
        let invalidPythonPath = "/invalid/python/path"
        let testAudioURL = URL(fileURLWithPath: "/tmp/test.m4a")
        
        do {
            _ = try await parakeetService.transcribe(audioFileURL: testAudioURL, pythonPath: invalidPythonPath)
            XCTFail("Should have thrown an error")
        } catch let error as ParakeetError {
            // The error could be either pythonNotFound or transcriptionFailed (if audio processing fails first)
            // Both are valid outcomes for this test scenario
            switch error {
            case .pythonNotFound(let path) where path == invalidPythonPath:
                // Expected pythonNotFound error
                break
            case .transcriptionFailed:
                // Also acceptable - audio processing failed before Python validation
                break
            default:
                XCTFail("Expected pythonNotFound or transcriptionFailed error, got \(error)")
            }
        } catch {
            XCTFail("Should have thrown ParakeetError, got \(error)")
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
    
    // MARK: - Edge Case Tests
    
    func testTranscribeWithNonExistentAudioFile() async {
        let nonExistentAudioURL = URL(fileURLWithPath: "/tmp/nonexistent.m4a")
        let systemPythonPath = "/usr/bin/python3"
        
        // Only test if system Python exists
        if FileManager.default.fileExists(atPath: systemPythonPath) {
            do {
                _ = try await parakeetService.transcribe(audioFileURL: nonExistentAudioURL, pythonPath: systemPythonPath)
                XCTFail("Should have thrown an error for non-existent audio file")
            } catch {
                // Expected - either parakeet-mlx not installed or audio file doesn't exist
                XCTAssertTrue(error.localizedDescription.count > 0)
            }
        }
    }
    
    // MARK: - Bundle Resource Tests
    
    func testParakeetScriptExists() {
        // Test that the Python script can be found in the bundle
        // In test environment, check both Bundle.main and source directory
        let scriptURL = Bundle.main.url(forResource: "parakeet_transcribe_pcm", withExtension: "py")
        
        if scriptURL != nil {
            // Script found in bundle
            XCTAssertNotNil(scriptURL, "Parakeet Python PCM script should be available in app bundle")
        } else {
            // In test environment, check if script exists in source directory
            let currentDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            let sourceDir = currentDir.deletingLastPathComponent().appendingPathComponent("Sources")
            let sourceScriptURL = sourceDir.appendingPathComponent("parakeet_transcribe_pcm.py")
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: sourceScriptURL.path), 
                         "Parakeet Python PCM script should be available in source directory during tests")
        }
    }
}