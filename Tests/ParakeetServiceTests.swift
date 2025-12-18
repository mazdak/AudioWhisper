import XCTest
import Foundation
@testable import AudioWhisper

class ParakeetServiceTests: XCTestCase {
    
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
    
    func testValidateSetupRequiresCachedModel() async {
        let missingRepo = "example.com/missing-repo-\(UUID().uuidString)"
        UserDefaults.standard.set(missingRepo, forKey: "selectedParakeetModel")
        
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
    
    func testTranscribeRequiresCachedModel() async {
        let missingRepo = "example.com/missing-repo-\(UUID().uuidString)"
        UserDefaults.standard.set(missingRepo, forKey: "selectedParakeetModel")
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
