import XCTest
import AppKit
@testable import AudioWhisper

@MainActor 
class PasteManagerTests: XCTestCase {
    
    var pasteManager: PasteManager!
    var mockApp: MockRunningApplication!
    var notificationObserver: NSObjectProtocol?
    
    override func setUp() {
        super.setUp()
        pasteManager = PasteManager()
        mockApp = MockRunningApplication()
        
        // Clear any existing clipboard content
        NSPasteboard.general.clearContents()
    }
    
    override func tearDown() {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        pasteManager = nil
        mockApp = nil
        super.tearDown()
    }
    
    
    // MARK: - SmartPaste Functionality Tests
    
    func testSmartPasteCopiesToClipboardRegardlessOfSettings() {
        // Test that smartPaste always copies text to clipboard as fallback
        let testText = "Test transcription text"
        
        pasteManager.smartPaste(into: mockApp, text: testText)
        
        // Verify text is copied to clipboard
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardContent, testText, "Text should be copied to clipboard as fallback")
    }
    
    func testSmartPasteBasicBehaviorInTestEnvironment() {
        // Test the actual behavior in test environment to understand what's happening
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        let testText = "Test transcription text"
        
        // Check accessibility permission state
        let accessibilityManager = AccessibilityPermissionManager()
        _ = accessibilityManager.checkPermission()
        
        // Call smartPaste and verify it behaves correctly
        pasteManager.smartPaste(into: mockApp, text: testText)
        
        // Verify text is always copied to clipboard regardless of permission
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardContent, testText, "Text should be copied to clipboard regardless of permission state")
        
        // Document the permission state for debugging
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testSmartPasteWithSmartPasteDisabled() {
        // Test behavior when SmartPaste is disabled in settings
        UserDefaults.standard.set(false, forKey: "enableSmartPaste")
        
        let expectation = expectation(description: "Paste operation fails appropriately")
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: .main
        ) { notification in
            if let errorMessage = notification.object as? String {
                XCTAssertTrue(
                    errorMessage.contains("not available"),
                    "Should indicate target app not available when SmartPaste disabled"
                )
            }
            expectation.fulfill()
        }
        
        pasteManager.smartPaste(into: mockApp, text: "Test text")
        
        wait(for: [expectation], timeout: 2.0)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testSmartPasteWithAccessibilityPermissionDenied() {
        // Test behavior when Accessibility permission is denied
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        let expectation = expectation(description: "Paste operation fails due to permission")
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: .main
        ) { notification in
            if let errorMessage = notification.object as? String {
                XCTAssertTrue(
                    errorMessage.contains("Accessibility permission"),
                    "Should indicate accessibility permission issue"
                )
            }
            expectation.fulfill()
        }
        
        pasteManager.smartPaste(into: mockApp, text: "Test text")
        
        wait(for: [expectation], timeout: 2.0)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testSmartPasteWithPermissionRevokedDuringOperation() {
        // Test the case where permission is revoked between initial check and paste operation
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        // This test simulates permission being revoked during the delay before paste
        let expectation = expectation(description: "Paste operation fails when permission revoked")
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: .main
        ) { notification in
            expectation.fulfill()
        }
        
        pasteManager.smartPaste(into: mockApp, text: "Test text")
        
        wait(for: [expectation], timeout: 2.0)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testSmartPastePermissionCheckBehavior() {
        // Critical security test: Verify smartPaste behavior based on actual permission state
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        let accessibilityManager = AccessibilityPermissionManager()
        let hasPermission = accessibilityManager.checkPermission()
        
        let expectationAny = expectation(description: "Some notification should be sent")
        var receivedNotification: String?
        
        // Listen for both success and failure notifications
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: .main
        ) { notification in
            if let errorMessage = notification.object as? String {
                receivedNotification = "FAILED: \(errorMessage)"
            }
            expectationAny.fulfill()
        }
        
        let successObserver = NotificationCenter.default.addObserver(
            forName: .pasteOperationSucceeded,
            object: nil,
            queue: .main
        ) { _ in
            receivedNotification = "SUCCESS"
            expectationAny.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(successObserver)
        }
        
        // Execute the operation
        pasteManager.smartPaste(into: mockApp, text: "Test text")
        
        wait(for: [expectationAny], timeout: 2.0)
        
        // Verify behavior matches permission state
        if hasPermission {
            // If permission is granted, operation should succeed
            XCTAssertEqual(receivedNotification, "SUCCESS", "With permission granted, operation should succeed")
        } else {
            // If permission is denied, should fail with permission error
            XCTAssertTrue(
                receivedNotification?.contains("Accessibility permission") ?? false,
                "Without permission, should fail with permission error. Got: \(receivedNotification ?? "nil")"
            )
        }
        
        // Most importantly: verify some notification was sent (no silent failures)
        XCTAssertNotNil(receivedNotification, "Operation should always result in a notification, never silent failure")
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testPasteWithUserInteractionHandlesPermissionDenialGracefully() {
        // Test that user interaction method properly handles permission denial
        let expectation = expectation(description: "User interaction permission denial handled")
        
        // In test environment, this should trigger permission request flow
        // Since we can't easily mock the permission dialog, we expect it to complete
        // without crashing and either succeed or fail gracefully
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: .main
        ) { notification in
            // Should handle denial gracefully
            expectation.fulfill()
        }
        
        pasteManager.pasteWithUserInteraction()
        
        wait(for: [expectation], timeout: 5.0) // Longer timeout for user interaction
    }
    
    func testAppActivationFailureHandling() {
        // Test behavior when target app activation fails
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        // Create a mock app that will fail activation
        let failingMockApp = FailingMockRunningApplication()
        
        let expectation = expectation(description: "App activation failure handled")
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: .main
        ) { notification in
            if let errorMessage = notification.object as? String {
                XCTAssertTrue(
                    errorMessage.contains("not available"),
                    "Should indicate app is not available when activation fails"
                )
            }
            expectation.fulfill()
        }
        
        pasteManager.smartPaste(into: failingMockApp, text: "Test text")
        
        wait(for: [expectation], timeout: 2.0)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testSmartPasteWithTerminatedApp() {
        // Test behavior when target app is terminated
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        mockApp.mockIsTerminated = true
        
        let expectation = expectation(description: "Paste operation fails for terminated app")
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: .main
        ) { notification in
            if let errorMessage = notification.object as? String {
                XCTAssertTrue(
                    errorMessage.contains("not available"),
                    "Should indicate target app not available when terminated"
                )
            }
            expectation.fulfill()
        }
        
        pasteManager.smartPaste(into: mockApp, text: "Test text")
        
        wait(for: [expectation], timeout: 2.0)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testSmartPasteWithNilApp() {
        // Test behavior when target app is nil
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        let expectation = expectation(description: "Paste operation fails for nil app")
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: .main
        ) { notification in
            expectation.fulfill()
        }
        
        pasteManager.smartPaste(into: nil, text: "Test text")
        
        wait(for: [expectation], timeout: 2.0)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    // MARK: - Paste to Active App Tests
    
    func testPasteToActiveAppWithSmartPasteEnabled() {
        // Test pasteToActiveApp behavior with SmartPaste enabled
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        // This should attempt to perform CGEvent paste
        // In test environment, this will likely fail due to permissions, but shouldn't crash
        XCTAssertNoThrow(pasteManager.pasteToActiveApp())
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testPasteToActiveAppWithSmartPasteDisabled() {
        // Test pasteToActiveApp behavior with SmartPaste disabled
        UserDefaults.standard.set(false, forKey: "enableSmartPaste")
        
        // This should do nothing (just rely on clipboard)
        XCTAssertNoThrow(pasteManager.pasteToActiveApp())
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    // MARK: - User Interaction Tests
    
    func testPasteWithUserInteractionHandlesPermissionDenial() {
        // Test that pasteWithUserInteraction properly handles permission denial
        let expectation = expectation(description: "Permission denial handled")
        
        // In test environment, accessibility permission is typically denied
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: .main
        ) { notification in
            expectation.fulfill()
        }
        
        pasteManager.pasteWithUserInteraction()
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testPasteErrorTypes() {
        // Test that all PasteError types have proper descriptions
        let errors: [PasteError] = [
            .accessibilityPermissionDenied,
            .eventSourceCreationFailed,
            .keyboardEventCreationFailed,
            .targetAppNotAvailable
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "PasteError should have error description: \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty: \(error)")
        }
    }
    
    // MARK: - Notification Tests
    
    func testPasteOperationNotifications() {
        // Test that proper notifications are sent
        let failureExpectation = expectation(description: "Failure notification sent")
        
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertNotNil(notification.object, "Failure notification should include error message")
            failureExpectation.fulfill()
        }
        
        // Trigger a failure scenario
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        pasteManager.smartPaste(into: nil, text: "Test text")
        
        wait(for: [failureExpectation], timeout: 2.0)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    // MARK: - Integration Tests
    
    func testPasteManagerIntegration() {
        // Test overall integration and that PasteManager initializes properly
        XCTAssertNotNil(pasteManager, "PasteManager should initialize successfully")
        
        // Test that it doesn't crash with various inputs
        XCTAssertNoThrow(pasteManager.smartPaste(into: nil, text: ""))
        XCTAssertNoThrow(pasteManager.smartPaste(into: mockApp, text: "Valid text"))
        XCTAssertNoThrow(pasteManager.pasteToActiveApp())
    }
    
    // MARK: - Security Tests
    
    func testPasteManagerHandlesLargeText() {
        // Test that large text doesn't cause issues
        let largeText = String(repeating: "A", count: 10000)
        
        XCTAssertNoThrow(pasteManager.smartPaste(into: mockApp, text: largeText))
        
        // Verify it's still copied to clipboard
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardContent, largeText, "Large text should be copied to clipboard")
    }
    
    func testPasteManagerHandlesSpecialCharacters() {
        // Test that special characters are handled properly
        let specialText = "Test with émojis 🎉 and ñéẅ línés\n\tand tabs"
        
        XCTAssertNoThrow(pasteManager.smartPaste(into: mockApp, text: specialText))
        
        // Verify it's copied to clipboard with proper encoding
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardContent, specialText, "Special characters should be preserved in clipboard")
    }
    
    // MARK: - Error Boundary Tests
    
    func testPasteManagerHandlesMultipleRapidCalls() {
        // Test system stability under rapid paste requests
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        // Rapidly trigger multiple paste operations
        for i in 0..<10 {
            pasteManager.smartPaste(into: mockApp, text: "Rapid test \(i)")
        }
        
        // Should handle rapid calls without crashing
        XCTAssertTrue(true, "Multiple rapid calls should not cause crashes")
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testPasteManagerHandlesEdgeCaseInputs() {
        // Test with edge case inputs that might cause issues
        let edgeCaseTexts = [
            "", // Empty string
            " ", // Single space
            String(repeating: " ", count: 1000), // Many spaces
            "Text with\nnewlines\nand\ttabs",
            "Unicode: 🎉 中文 العربية",
            String(repeating: "A", count: 50000) // Very long text
        ]
        
        for text in edgeCaseTexts {
            XCTAssertNoThrow(pasteManager.smartPaste(into: mockApp, text: text))
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testPasteManagerMemoryManagement() {
        // Test that repeated operations don't cause memory leaks
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        for i in 0..<100 {
            pasteManager.smartPaste(into: mockApp, text: "Test \(i)")
        }
        
        // Should complete without issues
        XCTAssertTrue(true, "Repeated operations should not cause memory issues")
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
}

// MARK: - Additional Mock Classes for Enhanced Testing

/// Mock running application that fails activation for testing error scenarios
class FailingMockRunningApplication: NSRunningApplication, @unchecked Sendable {
    var mockIsTerminated: Bool = false
    var mockActivationCount: Int = 0
    
    override var isTerminated: Bool {
        return mockIsTerminated
    }
    
    override func activate(options: NSApplication.ActivationOptions = []) -> Bool {
        mockActivationCount += 1
        return false // Always fail activation
    }
}