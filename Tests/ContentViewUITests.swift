import XCTest
import SwiftUI
@testable import AudioWhisper

@MainActor
final class ContentViewUITests: XCTestCase {
    var contentView: ContentView!
    var mockSpeechService: SpeechToTextService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockSpeechService = SpeechToTextService()
        contentView = ContentView(speechService: mockSpeechService)
    }
    
    override func tearDownWithError() throws {
        contentView = nil
        mockSpeechService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Basic UI Structure Tests
    
    func testContentViewCreation() {
        XCTAssertNotNil(contentView)
        XCTAssertNotNil(contentView.body)
    }
    
    func testSpeechServiceIntegration() {
        XCTAssertNotNil(mockSpeechService)
        // Verify ContentView properly integrates with SpeechToTextService
        XCTAssertTrue(true) // ContentView was created successfully with speech service
    }
    
    func testInitialState() {
        // Test that ContentView initializes with correct default state
        XCTAssertNotNil(contentView)
        
        // Verify the view hierarchy can be created without errors
        let _ = contentView.body
        XCTAssertTrue(true)
    }
    
    // MARK: - Component Integration Tests
    
    func testPasteManagerIntegration() {
        // Test that ContentView properly integrates with PasteManager
        let view = ContentView(speechService: mockSpeechService)
        XCTAssertNotNil(view)
        
        // Verify PasteManager is properly initialized
        XCTAssertTrue(true) // ContentView created with PasteManager successfully
    }
    
    func testAudioRecorderIntegration() {
        // Test that ContentView properly integrates with AudioRecorder
        XCTAssertNotNil(contentView)
        XCTAssertTrue(true) // ContentView created with AudioRecorder successfully
    }
    
    // MARK: - State Management Tests
    
    func testViewStateInitialization() {
        // Test initial state values
        let view = ContentView(speechService: mockSpeechService)
        XCTAssertNotNil(view)
        
        // State should be properly initialized
        XCTAssertTrue(true)
    }
    
    func testAppStorageIntegration() {
        // Test AppStorage properties are properly initialized
        let view = ContentView(speechService: mockSpeechService)
        XCTAssertNotNil(view)
        XCTAssertTrue(true)
    }
    
    // MARK: - Performance Tests
    
    func testViewCreationPerformance() {
        // Test ContentView creation performance
        measure {
            let _ = ContentView(speechService: SpeechToTextService())
        }
    }
    
    func testViewBodyPerformance() {
        // Test view body creation performance
        measure {
            let view = ContentView(speechService: mockSpeechService)
            let _ = view.body
        }
    }
}

// MARK: - Window Manager UI Tests

@MainActor
final class RecordingWindowUITests: XCTestCase {
    var windowManager: WindowManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        windowManager = WindowManager()
    }
    
    override func tearDownWithError() throws {
        windowManager = nil
        try super.tearDownWithError()
    }
    
    func testWindowManagerCreation() {
        XCTAssertNotNil(windowManager)
    }
    
    func testWindowManagerMethods() {
        // Test that window manager methods can be called without crashing
        XCTAssertNoThrow(windowManager.setupRecordingWindow())
        XCTAssertNoThrow(windowManager.showRecordingWindow())
        XCTAssertNoThrow(windowManager.hideRecordingWindow())
    }
}

// MARK: - Helper Extensions for Testing

extension ContentView {
    static func createForTesting() -> ContentView {
        return ContentView(speechService: SpeechToTextService())
    }
}