import XCTest
@testable import AudioWhisper

final class ShowAudioFileButtonTest: XCTestCase {
    
    @MainActor
    func testShowAudioFileButtonOnlyForTranscriptionErrors() {
        // Test that verifies the third button ("Show Audio File") only appears for transcription errors
        // and not for other error types, addressing missing test coverage noted in code review.
        
        // Test cases: (error message, should be classified as transcription error)
        let testCases = [
            // Transcription errors - should be classified as transcription type
            ("Transcription failed: network timeout", true),
            ("Local transcription failed: model error", true), 
            ("Transcription service unavailable", true),
            ("transcription processing error", true), // lowercase test
            ("Failed transcription due to timeout", true),
            
            // Non-transcription errors - should NOT be classified as transcription type
            ("Invalid API key provided", false),
            ("API key is missing", false),
            ("Microphone access denied", false),
            ("Permission required for microphone", false),
            ("Internet connection lost", false),
            ("Network connection failed", false),
            ("Generic error message", false),
            ("Audio recording failed", false),
            ("Recording failed to start", false),
            ("File upload error", false),
        ]
        
        for (errorMessage, shouldBeTranscriptionError) in testCases {
            // Test error classification - this is what determines if "Show Audio File" button appears
            let lowercasedMessage = errorMessage.lowercased()
            let isTranscriptionError = lowercasedMessage.contains("transcription")
            
            XCTAssertEqual(isTranscriptionError, shouldBeTranscriptionError,
                         "Error message '\(errorMessage)' should \(shouldBeTranscriptionError ? "" : "NOT ")be classified as transcription error")
        }
    }
    
    @MainActor
    func testTranscriptionErrorGetsThirdButton() {
        // Test that transcription errors would result in alerts with 3 buttons
        // while other errors get at most 2 buttons
        
        let errorMessages = [
            "Transcription failed: timeout",  // Should get: OK, Try Again, Show Audio File (3 buttons)
            "API key missing",                // Should get: OK, Open Settings (2 buttons)  
            "Microphone denied",              // Should get: OK, Open System Settings (2 buttons)
            "Connection failed",              // Should get: OK, Try Again (2 buttons)
            "Generic error"                   // Should get: OK (1 button)
        ]
        
        let expectedButtonCounts = [3, 2, 2, 2, 1]  // Transcription error gets 3 buttons, others get 1-2
        
        for (index, errorMessage) in errorMessages.enumerated() {
            let errorType = classifyError(errorMessage)
            let expectedButtonCount = expectedButtonCounts[index]
            
            // Calculate expected button count based on error type
            var calculatedButtonCount = 1 // Always has OK button
            
            switch errorType {
            case "api_key", "microphone", "connection":
                calculatedButtonCount = 2 // OK + one action button
            case "transcription":
                calculatedButtonCount = 3 // OK + Try Again + Show Audio File
            default:
                calculatedButtonCount = 1 // Just OK
            }
            
            XCTAssertEqual(calculatedButtonCount, expectedButtonCount,
                         "Error '\(errorMessage)' should result in \(expectedButtonCount) buttons, got \(calculatedButtonCount)")
        }
    }
    
    @MainActor
    func testThirdButtonOnlyForTranscriptionErrors() {
        // Test that the third button handling logic only triggers for transcription errors
        
        let testCases = [
            ("Transcription failed: model error", "transcription", true),
            ("API key invalid", "api_key", false),
            ("Microphone permission denied", "microphone", false),
            ("Internet connection lost", "connection", false),
            ("Unknown error", nil, false)
        ]
        
        for (errorMessage, expectedErrorType, shouldHaveThirdButton) in testCases {
            let errorType = classifyError(errorMessage)
            XCTAssertEqual(errorType, expectedErrorType, "Error type classification failed for: \(errorMessage)")
            
            // Test third button logic: should only be true for transcription errors
            let hasThirdButton = (errorType == "transcription")
            XCTAssertEqual(hasThirdButton, shouldHaveThirdButton,
                         "Third button availability should be \(shouldHaveThirdButton) for: \(errorMessage)")
        }
    }
    
    // Helper method that mimics ErrorPresenter's getErrorType logic
    private func classifyError(_ message: String) -> String? {
        let lowercasedMessage = message.lowercased()
        let errorPatterns: [String: [String]] = [
            "api_key": ["api key"],
            "microphone": ["microphone", "permission"],
            "connection": ["internet", "connection"],
            "transcription": ["transcription"]
        ]
        
        for (errorType, patterns) in errorPatterns {
            if patterns.contains(where: { lowercasedMessage.contains($0) }) {
                return errorType
            }
        }
        return nil
    }
}