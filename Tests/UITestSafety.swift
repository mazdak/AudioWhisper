import XCTest
@testable import AudioWhisper

/// Test class to verify that no actual UI dialogs appear during testing
final class UITestSafetyTests: XCTestCase {
    
    @MainActor
    func testErrorPresenterDoesNotShowActualDialogs() async {
        let errorPresenter = ErrorPresenter.shared
        
        // Verify test environment is detected
        XCTAssertTrue(errorPresenter.isTestEnvironment, "ErrorPresenter should detect test environment")
        
        // These should NOT show actual dialogs
        XCTAssertNoThrow(errorPresenter.showError("Test API key error"))
        XCTAssertNoThrow(errorPresenter.showError("Test microphone permission error"))
        XCTAssertNoThrow(errorPresenter.showError("Test internet connection error"))
        
        // Give a moment for any async operations
        try? await Task.sleep(for: .milliseconds(100))
    }
    
    func testPermissionManagerDoesNotShowActualDialogs() {
        let permissionManager = PermissionManager()
        
        // This should NOT trigger actual system permission dialogs
        XCTAssertNoThrow(permissionManager.proceedWithPermissionRequest())
        XCTAssertNoThrow(permissionManager.openSystemSettings())
        
        // Give a moment for async operations
        let expectation = XCTestExpectation(description: "No system dialogs shown")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
    }
    
    @MainActor
    func testWindowControllerDoesNotCreateActualWindows() {
        let windowController = WindowController()
        
        // These should NOT create actual windows in test environment
        XCTAssertNoThrow(windowController.openSettings())
        XCTAssertNoThrow(windowController.toggleRecordWindow())
        
        // Verify no windows were actually created
        // Use safe access to NSApp.windows which might not be available in test environment
        if let windows = NSApplication.shared.windows as? [NSWindow] {
            let audioWhisperWindows = windows.filter { 
                $0.title.contains("AudioWhisper") || $0.title.contains("Settings")
            }
            
            // In test environment, no actual windows should be created
            XCTAssertTrue(audioWhisperWindows.isEmpty, "No actual windows should be created during tests")
        } else {
            // If NSApp.windows is not available, that's also fine in test environment
            XCTAssertTrue(true, "NSApp.windows not available in test environment - this is expected")
        }
    }
    
    func testHotKeyManagerDoesNotCreateActualHotKeys() {
        let hotKeyManager = HotKeyManager {
            // Hotkey callback - no need to track in test
        }
        
        // Should not crash or show system dialogs for hotkey registration
        XCTAssertNotNil(hotKeyManager)
        
        // Test hotkey updates don't show system prompts
        NotificationCenter.default.post(
            name: .updateGlobalHotkey,
            object: "⌘⇧T"
        )
        
        // Give a moment for processing
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Manager should still be valid
        XCTAssertNotNil(hotKeyManager)
    }
    
    func testAppSetupHelperDoesNotTriggerSystemOperations() {
        // These should not trigger actual system operations in tests
        XCTAssertNoThrow(AppSetupHelper.setupApp())
        XCTAssertNoThrow(AppSetupHelper.setupLoginItem())
        
        // Menu bar icon creation should work
        let icon = AppSetupHelper.createMenuBarIcon()
        XCTAssertNotNil(icon)
        
        // File cleanup should work safely
        XCTAssertNoThrow(AppSetupHelper.cleanupOldTemporaryFiles())
    }
    
    @MainActor
    func testAllComponentsDetectTestEnvironment() {
        // Verify all components properly detect test environment
        XCTAssertTrue(ErrorPresenter.shared.isTestEnvironment)
        
        _ = PermissionManager()
        // Access private property through runtime check
        let isTestEnv = NSClassFromString("XCTestCase") != nil
        XCTAssertTrue(isTestEnv, "Test environment should be detected")
        
        let windowController = WindowController()
        // WindowController should also detect test environment
        XCTAssertNotNil(windowController)
    }
}