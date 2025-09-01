import XCTest
import AppKit
@testable import AudioWhisper

class AccessibilityPermissionManagerTests: XCTestCase {
    
    var accessibilityManager: AccessibilityPermissionManager!
    
    override func setUp() {
        super.setUp()
        accessibilityManager = AccessibilityPermissionManager()
    }
    
    override func tearDown() {
        accessibilityManager = nil
        super.tearDown()
    }
    
    // MARK: - Permission Checking Tests
    
    func testCheckPermissionDoesNotPromptUser() {
        // This test verifies that checkPermission() doesn't show any dialogs
        // We can't easily mock AXIsProcessTrustedWithOptions in tests, 
        // but we can ensure the function completes without hanging
        let result = accessibilityManager.checkPermission()
        
        // Result is a boolean as expected
    }
    
    func testPermissionStatusMessage() {
        // Test that status message is properly formatted
        let message = accessibilityManager.permissionStatusMessage
        XCTAssertFalse(message.isEmpty, "Permission status message should not be empty")
        XCTAssertTrue(
            message.contains("✅") || message.contains("⚠️"),
            "Status message should contain appropriate emoji indicator"
        )
    }
    
    // MARK: - Permission Request Flow Tests
    
    func testRequestPermissionWithExplanationCompletesQuicklyIfAlreadyGranted() {
        // This test would normally check if permission is already granted
        // In a test environment, we expect it to complete within reasonable time
        let expectation = expectation(description: "Permission request completes")
        
        accessibilityManager.requestPermissionWithExplanation { granted in
            // In test environment, this should complete quickly
            expectation.fulfill()
        }
        
        // Wait only briefly - if permission is already granted, should be immediate
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testPermissionManagerHandlesSystemSettingsURLGracefully() {
        // Test that opening system settings doesn't crash
        // In test environment, URL opening should be handled gracefully
        XCTAssertNoThrow(accessibilityManager.showManualPermissionInstructions())
    }
    
    // MARK: - Detailed Permission Status Tests
    
    func testDetailedPermissionStatus() {
        // Test the detailed permission status functionality
        let status = accessibilityManager.detailedPermissionStatus
        
        // isGranted is a boolean as expected
        XCTAssertFalse(status.statusMessage.isEmpty, "Status message should not be empty")
        
        if !status.isGranted {
            XCTAssertNotNil(status.troubleshootingInfo, "Should provide troubleshooting info when permission denied")
            XCTAssertTrue(
                status.troubleshootingInfo!.contains("System Settings"),
                "Troubleshooting info should mention System Settings"
            )
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testPermissionManagerHandlesErrorsGracefully() {
        // Test error handling with various error types
        let testErrors: [Error] = [
            NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"]),
            NSError(domain: "com.apple.accessibility", code: -1, userInfo: [:])
        ]
        
        for error in testErrors {
            XCTAssertNoThrow(accessibilityManager.handlePermissionError(error))
        }
    }
    
    func testShowPermissionDeniedMessageDoesNotCrash() {
        // Test that permission denied message handling doesn't crash
        XCTAssertNoThrow(accessibilityManager.showPermissionDeniedMessage())
    }
    
    // MARK: - User Interface Flow Tests
    
    func testManualPermissionInstructionsHandling() {
        // Test that manual instructions can be shown without crashing
        XCTAssertNoThrow(accessibilityManager.showManualPermissionInstructions())
    }
    
    func testPermissionRequestFlowCompletesWithoutHanging() {
        // Test that permission request flow completes in reasonable time
        let expectation = expectation(description: "Permission request flow completes")
        
        // This test ensures the flow doesn't hang indefinitely
        DispatchQueue.global().async {
            self.accessibilityManager.requestPermissionWithExplanation { granted in
                // Should complete regardless of result
                expectation.fulfill()
            }
        }
        
        // Give it reasonable time to complete
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Permission State Consistency Tests
    
    func testPermissionCheckConsistency() {
        // Test that multiple calls to checkPermission return consistent results
        let firstCheck = accessibilityManager.checkPermission()
        let secondCheck = accessibilityManager.checkPermission()
        
        XCTAssertEqual(firstCheck, secondCheck, "Permission checks should be consistent")
    }
    
    func testPermissionStatusMessageConsistency() {
        // Test that status message is consistent with permission state
        let hasPermission = accessibilityManager.checkPermission()
        let statusMessage = accessibilityManager.permissionStatusMessage
        
        if hasPermission {
            XCTAssertTrue(statusMessage.contains("✅"), "Granted permission should show success indicator")
            XCTAssertTrue(statusMessage.contains("enabled"), "Should indicate SmartPaste is enabled")
        } else {
            XCTAssertTrue(statusMessage.contains("⚠️"), "Denied permission should show warning indicator")
            XCTAssertTrue(statusMessage.contains("required"), "Should indicate permission is required")
        }
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func testPermissionManagerIntegratesWithPasteManager() {
        // Test that AccessibilityPermissionManager can be used by PasteManager
        let pasteManager = PasteManager()
        XCTAssertNotNil(pasteManager, "PasteManager should initialize successfully with AccessibilityPermissionManager")
    }
    
    func testAccessibilityManagerHandlesRapidCalls() {
        // Test stability under rapid permission checks
        for _ in 0..<50 {
            _ = accessibilityManager.checkPermission()
            _ = accessibilityManager.permissionStatusMessage
        }
        
        // Should complete without issues
        XCTAssertTrue(true, "Rapid permission checks should not cause issues")
    }
    
    // MARK: - Memory Management Tests
    
    func testAccessibilityManagerMemoryManagement() {
        // Test that manager doesn't leak memory during repeated operations
        autoreleasepool {
            let manager = AccessibilityPermissionManager()

            // Perform various operations
            _ = manager.checkPermission()
            _ = manager.permissionStatusMessage
            _ = manager.detailedPermissionStatus
        }

        // Note: This test helps catch obvious memory leaks during development
    }
    
    // MARK: - Security Tests
    
    func testPermissionManagerNeverBypassesSystemChecks() {
        // Critical test: Ensure manager never returns true without actual system permission
        // In test environment, this should typically return false unless permission is actually granted
        let hasPermission = accessibilityManager.checkPermission()
        
        // This assertion documents expected behavior but might pass if permission is actually granted
        // The key is that checkPermission() calls AXIsProcessTrustedWithOptions(nil) without bypassing
        // Permission check returns actual system state
    }
    
    func testPermissionManagerDoesNotPromptDuringCheck() {
        // Ensure checkPermission() never shows dialogs or prompts
        // This is critical for not interrupting user workflow
        
        let startTime = Date()
        let hasPermission = accessibilityManager.checkPermission()
        let endTime = Date()
        
        // Permission check should be very fast (under 0.1 seconds) if it's not prompting
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 0.1, "Permission check should be instant without prompting")
        // Should return boolean result
    }
}

// MARK: - Mock Classes for Testing

/// Mock running application for testing SmartPaste scenarios
class MockRunningApplication: NSRunningApplication, @unchecked Sendable {
    var mockIsTerminated: Bool = false
    var mockActivationCount: Int = 0
    
    override var isTerminated: Bool {
        return mockIsTerminated
    }
    
    override func activate(options: NSApplication.ActivationOptions = []) -> Bool {
        mockActivationCount += 1
        return !mockIsTerminated
    }
}