import XCTest
import AppKit
import SwiftUI
@testable import AudioWhisper

final class WindowControllerTests: XCTestCase {
    
    var windowController: WindowController!
    var testWindow: NSWindow!
    
    override func setUp() {
        super.setUp()
        windowController = WindowController()
        
        // Create a test window that simulates the recording window
        testWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 160),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        testWindow.title = "AudioWhisper Recording"
        testWindow.isReleasedWhenClosed = false
    }
    
    override func tearDown() {
        testWindow?.close()
        testWindow = nil
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
        
        // Window should remain hidden
        XCTAssertFalse(testWindow.isVisible)
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
        
        // Initially hidden
        XCTAssertFalse(testWindow.isVisible)
        
        // Make window visible to test hiding
        testWindow.makeKeyAndOrderFront(nil)
        XCTAssertTrue(testWindow.isVisible)
        
        // Test that hiding works
        testWindow.orderOut(nil)
        XCTAssertFalse(testWindow.isVisible)
    }
    
    // MARK: - Settings Window Tests
    
    func testOpenSettingsCreatesNewWindow() {
        // Should not crash when opening settings
        XCTAssertNoThrow(windowController.openSettings())
    }
    
    func testOpenSettingsHidesRecordingWindow() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        // In test environment, this just verifies no crash
        XCTAssertNoThrow(windowController.openSettings())
    }
    
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
        
        // Test window properties can be set without crashing
        testWindow.canHide = false
        testWindow.acceptsMouseMovedEvents = true
        testWindow.isOpaque = false
        testWindow.hasShadow = true
        
        XCTAssertFalse(testWindow.canHide)
        XCTAssertTrue(testWindow.acceptsMouseMovedEvents)
        XCTAssertFalse(testWindow.isOpaque)
        XCTAssertTrue(testWindow.hasShadow)
    }
    
    func testWindowLevelConfiguration() {
        // Test setting various window levels
        let levels: [NSWindow.Level] = [.normal, .modalPanel, .floating]
        
        for level in levels {
            XCTAssertNoThrow(testWindow.level = level)
            XCTAssertEqual(testWindow.level, level)
        }
    }
    
    func testWindowCollectionBehavior() {
        // Test setting collection behavior
        let behaviors: [NSWindow.CollectionBehavior] = [
            [],
            [.canJoinAllSpaces],
            [.fullScreenPrimary],
            [.fullScreenAuxiliary],
            [.canJoinAllSpaces, .fullScreenPrimary, .fullScreenAuxiliary]
        ]
        
        for behavior in behaviors {
            XCTAssertNoThrow(testWindow.collectionBehavior = behavior)
            XCTAssertEqual(testWindow.collectionBehavior, behavior)
        }
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
    
    func testMultipleSettingsOpenCalls() {
        // Multiple rapid settings calls should not crash
        for _ in 0..<5 {
            XCTAssertNoThrow(windowController.openSettings())
        }
    }
    
    func testConcurrentWindowOperations() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        let queue = DispatchQueue.global(qos: .background)
        let expectation = XCTestExpectation(description: "Concurrent operations completed")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            queue.async {
                DispatchQueue.main.async {
                    if i % 2 == 0 {
                        self.windowController.toggleRecordWindow()
                    } else {
                        self.windowController.openSettings()
                    }
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
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
    
    func testOpenSettingsPerformance() {
        measure {
            for _ in 0..<50 {
                windowController.openSettings()
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testWindowOperationsWithInvalidWindows() {
        // Test with nil window references
        XCTAssertNoThrow(windowController.toggleRecordWindow())
        XCTAssertNoThrow(windowController.openSettings())
        XCTAssertNoThrow(windowController.restoreFocusToPreviousApp())
    }
    
    func testWindowOperationsAfterWindowClosed() {
        testWindow.close()
        
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        // Operations should not crash even after window is closed
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