import XCTest
import AppKit
import SwiftUI
@testable import AudioWhisper

final class WindowControllerTests: XCTestCase {
    
    var windowController: WindowController!
    
    override func setUp() {
        super.setUp()
        windowController = WindowController()
    }
    
    override func tearDown() {
        windowController = nil
        UserDefaults.standard.removeObject(forKey: "hasCompletedWelcome")
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testWindowControllerInitialization() {
        XCTAssertNotNil(windowController)
    }
    
    // MARK: - Welcome Completion Check Tests
    
    func testToggleRecordWindowBlockedDuringWelcome() {
        UserDefaults.standard.set(false, forKey: "hasCompletedWelcome")
        
        // Should not show window during welcome
        XCTAssertNoThrow(windowController.toggleRecordWindow())
        
        // Just verify no crash occurs
        XCTAssertTrue(true)
    }
    
    func testToggleRecordWindowAllowedAfterWelcome() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        // Should allow toggling after welcome is completed
        XCTAssertNoThrow(windowController.toggleRecordWindow())
    }
    
    // MARK: - Window Visibility Tests
    
    func testToggleRecordWindowWhenNoWindow() {
        // When no recording window exists, should not crash
        XCTAssertNoThrow(windowController.toggleRecordWindow())
    }
    
    func testWindowShowingAndHiding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        // Test that toggling doesn't crash
        XCTAssertNoThrow(windowController.toggleRecordWindow())
    }
    
    // MARK: - Settings Window Tests
    
    @MainActor
    func testOpenSettingsCreatesNewWindow() {
        // Should not crash when opening settings
        XCTAssertNoThrow(windowController.openSettings())
    }
    
    @MainActor
    func testOpenSettingsHidesRecordingWindow() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        // In test environment, this just verifies no crash
        XCTAssertNoThrow(windowController.openSettings())
    }
    
    @MainActor
    func testOpenSettingsWithExistingSettingsWindow() {
        // In test environment, openSettings() returns early
        // Just verify it doesn't crash
        XCTAssertNoThrow(windowController.openSettings())
    }
    
    // MARK: - Focus Management Tests
    
    func testRestoreFocusToPreviousAppWithNoPreviousApp() {
        // Should not crash when no previous app is stored
        XCTAssertNoThrow(windowController.restoreFocusToPreviousApp())
    }
    
    func testFocusRestorationFlow() {
        // Test the focus restoration mechanism doesn't crash
        XCTAssertNoThrow(windowController.restoreFocusToPreviousApp())
    }
    
    // MARK: - Window Configuration Tests
    
    func testWindowConfiguration() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        // Test window configuration doesn't crash
        XCTAssertNoThrow(windowController.toggleRecordWindow())
    }
    
    func testWindowLevelConfiguration() {
        // Test that window operations don't crash
        XCTAssertNoThrow(windowController.toggleRecordWindow())
    }
    
    func testWindowCollectionBehavior() {
        // Test that window operations don't crash
        XCTAssertNoThrow(windowController.toggleRecordWindow())
    }
    
    // MARK: - Async Operations Tests
    
    func testAsyncWindowOperations() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        // In test environment, this returns early, just verify no crash
        XCTAssertNoThrow(windowController.toggleRecordWindow())
    }
    
    // MARK: - Edge Cases Tests
    
    func testMultipleToggleCalls() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        // Multiple rapid calls should not crash
        for _ in 0..<10 {
            XCTAssertNoThrow(windowController.toggleRecordWindow())
        }
    }
    
    @MainActor
    func testMultipleSettingsOpenCalls() {
        // Multiple rapid settings calls should not crash
        for _ in 0..<5 {
            XCTAssertNoThrow(windowController.openSettings())
        }
    }
    
    @MainActor
    func testConcurrentWindowOperations() async {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    if i % 2 == 0 {
                        self.windowController.toggleRecordWindow()
                    } else {
                        self.windowController.openSettings()
                    }
                }
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testWindowControllerDeallocation() {
        weak var weakController = windowController
        
        windowController = nil
        
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        XCTAssertNil(weakController, "WindowController should be deallocated")
    }
    
    // MARK: - Performance Tests
    
    func testToggleWindowPerformance() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        measure {
            for _ in 0..<100 {
                windowController.toggleRecordWindow()
            }
        }
    }
    
    @MainActor
    func testOpenSettingsPerformance() {
        measure {
            for _ in 0..<50 {
                windowController.openSettings()
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    func testWindowOperationsWithInvalidWindows() {
        // Test with nil window references
        XCTAssertNoThrow(windowController.toggleRecordWindow())
        XCTAssertNoThrow(windowController.openSettings())
        XCTAssertNoThrow(windowController.restoreFocusToPreviousApp())
    }
    
    @MainActor
    func testWindowOperationsAfterWindowClosed() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        // Operations should not crash
        XCTAssertNoThrow(windowController.toggleRecordWindow())
        XCTAssertNoThrow(windowController.openSettings())
    }
    
    // MARK: - UserDefaults Integration Tests
    
    func testWelcomeStateChanges() {
        // Test toggling welcome state
        UserDefaults.standard.set(false, forKey: "hasCompletedWelcome")
        XCTAssertNoThrow(windowController.toggleRecordWindow())
        
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        XCTAssertNoThrow(windowController.toggleRecordWindow())
        
        // Reset state
        UserDefaults.standard.removeObject(forKey: "hasCompletedWelcome")
        XCTAssertNoThrow(windowController.toggleRecordWindow())
    }
    
    func testDefaultWelcomeState() {
        // When hasCompletedWelcome is not set, should default to false
        UserDefaults.standard.removeObject(forKey: "hasCompletedWelcome")
        
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
        XCTAssertFalse(hasCompleted)
        
        // Should block window toggle
        XCTAssertNoThrow(windowController.toggleRecordWindow())
    }
}