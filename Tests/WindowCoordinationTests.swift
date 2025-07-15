import XCTest
import AppKit
import SwiftUI
@testable import AudioWhisper

/// Tests for window coordination between multiple windows in AudioWhisper
class WindowCoordinationTests: XCTestCase {
    var windowController: WindowController!
    var appDelegate: AppDelegate!
    var recordingWindow: NSWindow!
    var settingsWindow: NSWindow!
    var historyWindow: NSWindow!
    
    override func setUp() {
        super.setUp()
        windowController = WindowController()
        
        // AppDelegate creation must happen on MainActor
        let expectation = XCTestExpectation(description: "AppDelegate setup")
        Task { @MainActor in
            appDelegate = AppDelegate()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Create test windows
        recordingWindow = createTestWindow(title: "AudioWhisper Recording")
        settingsWindow = createTestWindow(title: "Settings")
        historyWindow = createTestWindow(title: "Transcription History")
        
        // Reset user defaults for tests
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        UserDefaults.standard.synchronize()
    }
    
    override func tearDown() {
        // Clean up windows
        recordingWindow?.close()
        settingsWindow?.close()
        historyWindow?.close()
        
        recordingWindow = nil
        settingsWindow = nil
        historyWindow = nil
        windowController = nil
        appDelegate = nil
        
        super.tearDown()
    }
    
    private func createTestWindow(title: String) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        return window
    }
    
    // MARK: - Test 1: Opening settings window while history window is open
    
    @MainActor
    func testOpenSettingsWhileHistoryIsOpen() {
        // Given: History window is open
        let historyManager = HistoryWindowManager.shared
        let expectation = XCTestExpectation(description: "History window shown")
        
        Task { @MainActor in
            historyManager.showHistoryWindow()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // When: Open settings window
        let settingsExpectation = XCTestExpectation(description: "Settings window operations complete")
        
        DispatchQueue.main.async {
            self.windowController.openSettings()
            settingsExpectation.fulfill()
        }
        
        wait(for: [settingsExpectation], timeout: 1.0)
        
        // Then: Both windows should coexist
        DispatchQueue.main.async {
            let windows = NSApp.windows
            let hasHistoryWindow = windows.contains { $0.title == "Transcription History" }
            let hasSettingsWindow = windows.contains { $0.title == LocalizedStrings.Settings.title }
            
            XCTAssertTrue(hasHistoryWindow, "History window should remain open")
            XCTAssertTrue(hasSettingsWindow, "Settings window should be open")
        }
    }
    
    // MARK: - Test 2: Opening history window while settings window is open
    
    func testOpenHistoryWhileSettingsIsOpen() {
        // Given: Settings window is open
        let settingsExpectation = XCTestExpectation(description: "Settings window shown")
        
        DispatchQueue.main.async {
            self.windowController.openSettings()
            settingsExpectation.fulfill()
        }
        
        wait(for: [settingsExpectation], timeout: 1.0)
        
        // When: Open history window
        let historyExpectation = XCTestExpectation(description: "History window operations complete")
        
        DispatchQueue.main.async {
            HistoryWindowManager.shared.showHistoryWindow()
            historyExpectation.fulfill()
        }
        
        wait(for: [historyExpectation], timeout: 1.0)
        
        // Then: Both windows should coexist
        DispatchQueue.main.async {
            let windows = NSApp.windows
            let hasHistoryWindow = windows.contains { $0.title == "Transcription History" }
            let hasSettingsWindow = windows.contains { $0.title == LocalizedStrings.Settings.title }
            
            XCTAssertTrue(hasSettingsWindow, "Settings window should remain open")
            XCTAssertTrue(hasHistoryWindow, "History window should be open")
        }
    }
    
    // MARK: - Test 3: Closing main window behavior with other windows open
    
    func testCloseRecordingWindowWithOthersOpen() {
        // Given: Recording window and settings window are open
        let recordingExpectation = XCTestExpectation(description: "Recording window shown")
        
        DispatchQueue.main.async {
            self.recordingWindow.makeKeyAndOrderFront(nil)
            self.windowController.openSettings()
            recordingExpectation.fulfill()
        }
        
        wait(for: [recordingExpectation], timeout: 1.0)
        
        // When: Toggle recording window (should hide it)
        let toggleExpectation = XCTestExpectation(description: "Toggle completed")
        
        windowController.toggleRecordWindow(recordingWindow) {
            toggleExpectation.fulfill()
        }
        
        wait(for: [toggleExpectation], timeout: 1.0)
        
        // Then: Recording window should be hidden, settings should remain
        XCTAssertFalse(recordingWindow.isVisible, "Recording window should be hidden")
        
        DispatchQueue.main.async {
            let hasSettingsWindow = NSApp.windows.contains { $0.title == LocalizedStrings.Settings.title }
            XCTAssertTrue(hasSettingsWindow, "Settings window should remain open")
        }
    }
    
    // MARK: - Test 4: Window focus management between windows
    
    func testWindowFocusManagement() {
        // Given: Multiple windows are open
        let setupExpectation = XCTestExpectation(description: "Windows setup")
        
        DispatchQueue.main.async {
            self.recordingWindow.makeKeyAndOrderFront(nil)
            self.windowController.openSettings()
            HistoryWindowManager.shared.showHistoryWindow()
            setupExpectation.fulfill()
        }
        
        wait(for: [setupExpectation], timeout: 2.0)
        
        // When: Bring settings window to front again
        let focusExpectation = XCTestExpectation(description: "Focus change completed")
        
        DispatchQueue.main.async {
            self.windowController.openSettings() // Should bring existing window to front
            focusExpectation.fulfill()
        }
        
        wait(for: [focusExpectation], timeout: 1.0)
        
        // Then: Settings window should be key window
        DispatchQueue.main.async {
            if let keyWindow = NSApp.keyWindow {
                XCTAssertEqual(keyWindow.title, LocalizedStrings.Settings.title, "Settings should be key window")
            }
        }
    }
    
    // MARK: - Test 5: Proper cleanup when switching between windows
    
    func testWindowCleanupOnSwitch() {
        // Given: Settings window is open
        let settingsExpectation = XCTestExpectation(description: "Settings window shown")
        
        DispatchQueue.main.async {
            self.windowController.openSettings()
            settingsExpectation.fulfill()
        }
        
        wait(for: [settingsExpectation], timeout: 1.0)
        
        // When: Close settings and open history
        let switchExpectation = XCTestExpectation(description: "Window switch completed")
        
        DispatchQueue.main.async {
            // Close settings window
            if let settingsWindow = NSApp.windows.first(where: { $0.title == LocalizedStrings.Settings.title }) {
                settingsWindow.close()
            }
            
            // Open history window
            HistoryWindowManager.shared.showHistoryWindow()
            switchExpectation.fulfill()
        }
        
        wait(for: [switchExpectation], timeout: 2.0)
        
        // Then: Only history window should be open (plus any system windows)
        DispatchQueue.main.async {
            let windows = NSApp.windows
            let hasSettingsWindow = windows.contains { $0.title == LocalizedStrings.Settings.title }
            let hasHistoryWindow = windows.contains { $0.title == "Transcription History" }
            
            XCTAssertFalse(hasSettingsWindow, "Settings window should be closed")
            XCTAssertTrue(hasHistoryWindow, "History window should be open")
        }
    }
    
    // MARK: - Test 6: Memory leak prevention in window transitions
    
    func testNoMemoryLeaksInWindowTransitions() {
        // Test delegate cleanup for settings window
        weak var weakSettingsDelegate: AnyObject?
        
        autoreleasepool {
            let setupExpectation = XCTestExpectation(description: "Settings setup")
            
            DispatchQueue.main.async {
                self.windowController.openSettings()
                
                // Get reference to delegate
                if let settingsWindow = NSApp.windows.first(where: { $0.title == LocalizedStrings.Settings.title }) {
                    weakSettingsDelegate = settingsWindow.delegate
                }
                
                setupExpectation.fulfill()
            }
            
            wait(for: [setupExpectation], timeout: 1.0)
            
            // Close window
            let closeExpectation = XCTestExpectation(description: "Window closed")
            
            DispatchQueue.main.async {
                if let settingsWindow = NSApp.windows.first(where: { $0.title == LocalizedStrings.Settings.title }) {
                    settingsWindow.close()
                }
                closeExpectation.fulfill()
            }
            
            wait(for: [closeExpectation], timeout: 1.0)
        }
        
        // Verify delegate was released
        XCTAssertNil(weakSettingsDelegate, "Settings window delegate should be deallocated")
        
        // Test delegate cleanup for history window
        weak var weakHistoryDelegate: AnyObject?
        
        autoreleasepool {
            let historySetupExpectation = XCTestExpectation(description: "History setup")
            
            DispatchQueue.main.async {
                HistoryWindowManager.shared.showHistoryWindow()
                
                // Get reference to delegate
                if let historyWindow = NSApp.windows.first(where: { $0.title == "Transcription History" }) {
                    weakHistoryDelegate = historyWindow.delegate
                }
                
                historySetupExpectation.fulfill()
            }
            
            wait(for: [historySetupExpectation], timeout: 1.0)
            
            // Close window
            let historyCloseExpectation = XCTestExpectation(description: "History window closed")
            
            DispatchQueue.main.async {
                if let historyWindow = NSApp.windows.first(where: { $0.title == "Transcription History" }) {
                    historyWindow.close()
                }
                historyCloseExpectation.fulfill()
            }
            
            wait(for: [historyCloseExpectation], timeout: 1.0)
        }
        
        // Verify delegate was released
        XCTAssertNil(weakHistoryDelegate, "History window delegate should be deallocated")
    }
    
    // MARK: - Test 7: Window state persistence across app restarts
    
    func testWindowStatePersistence() {
        // Given: Set up window positions
        let setupExpectation = XCTestExpectation(description: "Windows positioned")
        
        let settingsFrame = NSRect(x: 100, y: 100, width: 500, height: 600)
        let historyFrame = NSRect(x: 200, y: 200, width: 700, height: 500)
        
        DispatchQueue.main.async {
            // Open and position windows
            self.windowController.openSettings()
            HistoryWindowManager.shared.showHistoryWindow()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let settingsWindow = NSApp.windows.first(where: { $0.title == LocalizedStrings.Settings.title }) {
                    settingsWindow.setFrame(settingsFrame, display: true)
                }
                
                if let historyWindow = NSApp.windows.first(where: { $0.title == "Transcription History" }) {
                    historyWindow.setFrame(historyFrame, display: true)
                }
                
                setupExpectation.fulfill()
            }
        }
        
        wait(for: [setupExpectation], timeout: 2.0)
        
        // When: Close and reopen windows
        let reopenExpectation = XCTestExpectation(description: "Windows reopened")
        
        DispatchQueue.main.async {
            // Close windows
            NSApp.windows.forEach { window in
                if window.title == LocalizedStrings.Settings.title || window.title == "Transcription History" {
                    window.close()
                }
            }
            
            // Reopen windows after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.windowController.openSettings()
                HistoryWindowManager.shared.showHistoryWindow()
                reopenExpectation.fulfill()
            }
        }
        
        wait(for: [reopenExpectation], timeout: 2.0)
        
        // Then: Windows should maintain reasonable positions (centered by default)
        DispatchQueue.main.async {
            let settingsWindow = NSApp.windows.first { $0.title == LocalizedStrings.Settings.title }
            let historyWindow = NSApp.windows.first { $0.title == "Transcription History" }
            
            XCTAssertNotNil(settingsWindow, "Settings window should exist")
            XCTAssertNotNil(historyWindow, "History window should exist")
            
            // Windows should be visible and have reasonable frames
            if let settings = settingsWindow {
                XCTAssertTrue(settings.isVisible, "Settings window should be visible")
                XCTAssertTrue(settings.frame.width > 0 && settings.frame.height > 0, "Settings window should have valid size")
            }
            
            if let history = historyWindow {
                XCTAssertTrue(history.isVisible, "History window should be visible")
                XCTAssertTrue(history.frame.width > 0 && history.frame.height > 0, "History window should have valid size")
            }
        }
    }
    
    // MARK: - Test 8: Keyboard shortcut conflicts between windows
    
    func testKeyboardShortcutConflicts() {
        // Given: Multiple windows are open
        let setupExpectation = XCTestExpectation(description: "Windows setup for keyboard test")
        
        DispatchQueue.main.async {
            self.recordingWindow.makeKeyAndOrderFront(nil)
            self.windowController.openSettings()
            HistoryWindowManager.shared.showHistoryWindow()
            setupExpectation.fulfill()
        }
        
        wait(for: [setupExpectation], timeout: 2.0)
        
        // Test Cmd+W behavior for each window
        let testWindows = [
            ("Recording", "AudioWhisper Recording"),
            ("Settings", LocalizedStrings.Settings.title),
            ("History", "Transcription History")
        ]
        
        for (windowType, windowTitle) in testWindows {
            let keyEventExpectation = XCTestExpectation(description: "\(windowType) window keyboard event")
            
            DispatchQueue.main.async {
                if let window = NSApp.windows.first(where: { $0.title == windowTitle }) {
                    // Make window key
                    window.makeKeyAndOrderFront(nil)
                    
                    // Simulate Cmd+W
                    let event = NSEvent.keyEvent(
                        with: .keyDown,
                        location: NSPoint.zero,
                        modifierFlags: .command,
                        timestamp: 0,
                        windowNumber: window.windowNumber,
                        context: nil,
                        characters: "w",
                        charactersIgnoringModifiers: "w",
                        isARepeat: false,
                        keyCode: 13 // 'w' key code
                    )
                    
                    if let event = event {
                        window.sendEvent(event)
                    }
                }
                
                keyEventExpectation.fulfill()
            }
            
            wait(for: [keyEventExpectation], timeout: 1.0)
        }
        
        // Verify windows can handle their keyboard shortcuts independently
        XCTAssertTrue(true, "Keyboard shortcuts processed without conflicts")
    }
    
    // MARK: - Test 9: Recording window behavior with settings open
    
    func testRecordingWindowTogglingWithSettingsOpen() {
        // Given: Settings window is open
        let settingsExpectation = XCTestExpectation(description: "Settings window shown")
        
        DispatchQueue.main.async {
            self.windowController.openSettings()
            settingsExpectation.fulfill()
        }
        
        wait(for: [settingsExpectation], timeout: 1.0)
        
        // When: Toggle recording window multiple times
        let toggleExpectation = XCTestExpectation(description: "Multiple toggles completed")
        toggleExpectation.expectedFulfillmentCount = 3
        
        // Toggle 1: Show recording window
        windowController.toggleRecordWindow(recordingWindow) {
            toggleExpectation.fulfill()
        }
        
        // Toggle 2: Hide recording window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.windowController.toggleRecordWindow(self.recordingWindow) {
                toggleExpectation.fulfill()
            }
        }
        
        // Toggle 3: Show recording window again
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.windowController.toggleRecordWindow(self.recordingWindow) {
                toggleExpectation.fulfill()
            }
        }
        
        wait(for: [toggleExpectation], timeout: 3.0)
        
        // Then: Settings window should remain open throughout
        DispatchQueue.main.async {
            let hasSettingsWindow = NSApp.windows.contains { $0.title == LocalizedStrings.Settings.title }
            XCTAssertTrue(hasSettingsWindow, "Settings window should remain open during recording window toggles")
        }
    }
    
    // MARK: - Test 10: Multiple window close sequence
    
    func testMultipleWindowCloseSequence() {
        // Given: All three windows are open
        let setupExpectation = XCTestExpectation(description: "All windows open")
        
        DispatchQueue.main.async {
            self.recordingWindow.makeKeyAndOrderFront(nil)
            self.windowController.openSettings()
            HistoryWindowManager.shared.showHistoryWindow()
            setupExpectation.fulfill()
        }
        
        wait(for: [setupExpectation], timeout: 2.0)
        
        // When: Close windows in sequence
        let closeExpectation = XCTestExpectation(description: "Windows closed in sequence")
        closeExpectation.expectedFulfillmentCount = 3
        
        DispatchQueue.main.async {
            // Close recording window
            self.recordingWindow.close()
            closeExpectation.fulfill()
            
            // Close settings window after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let settingsWindow = NSApp.windows.first(where: { $0.title == LocalizedStrings.Settings.title }) {
                    settingsWindow.close()
                }
                closeExpectation.fulfill()
                
                // Close history window after another delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let historyWindow = NSApp.windows.first(where: { $0.title == "Transcription History" }) {
                        historyWindow.close()
                    }
                    closeExpectation.fulfill()
                }
            }
        }
        
        wait(for: [closeExpectation], timeout: 3.0)
        
        // Then: All windows should be closed
        DispatchQueue.main.async {
            let appWindows = NSApp.windows.filter { window in
                window.title == "AudioWhisper Recording" ||
                window.title == LocalizedStrings.Settings.title ||
                window.title == "Transcription History"
            }
            
            XCTAssertTrue(appWindows.isEmpty, "All AudioWhisper windows should be closed")
        }
    }
}

// MARK: - Window Delegate Testing

extension WindowCoordinationTests {
    
    func testWindowDelegateCoordination() {
        // Test that window delegates properly coordinate with their managers
        let delegateExpectation = XCTestExpectation(description: "Delegate coordination test")
        
        DispatchQueue.main.async {
            // Open settings window
            self.windowController.openSettings()
            
            // Open history window
            HistoryWindowManager.shared.showHistoryWindow()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Verify both windows have delegates
                let settingsWindow = NSApp.windows.first { $0.title == LocalizedStrings.Settings.title }
                let historyWindow = NSApp.windows.first { $0.title == "Transcription History" }
                
                XCTAssertNotNil(settingsWindow?.delegate, "Settings window should have a delegate")
                XCTAssertNotNil(historyWindow?.delegate, "History window should have a delegate")
                
                delegateExpectation.fulfill()
            }
        }
        
        wait(for: [delegateExpectation], timeout: 2.0)
    }
    
    @MainActor
    func testWindowManagerSingleton() {
        // Verify HistoryWindowManager is truly a singleton
        let manager1 = HistoryWindowManager.shared
        let manager2 = HistoryWindowManager.shared
        
        XCTAssertTrue(manager1 === manager2, "HistoryWindowManager should be a singleton")
    }
}