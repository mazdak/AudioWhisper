import XCTest
import AVFoundation
@testable import AudioWhisper

final class PermissionManagerTests: XCTestCase {
    
    var permissionManager: PermissionManager!
    
    override func setUp() {
        super.setUp()
        permissionManager = PermissionManager()
    }
    
    override func tearDown() {
        permissionManager = nil
        super.tearDown()
    }
    
    // MARK: - PermissionState Tests
    
    func testPermissionStateNeedsRequest() {
        XCTAssertTrue(PermissionState.unknown.needsRequest)
        XCTAssertTrue(PermissionState.notRequested.needsRequest)
        XCTAssertFalse(PermissionState.requesting.needsRequest)
        XCTAssertFalse(PermissionState.granted.needsRequest)
        XCTAssertFalse(PermissionState.denied.needsRequest)
        XCTAssertFalse(PermissionState.restricted.needsRequest)
    }
    
    func testPermissionStateCanRetry() {
        XCTAssertFalse(PermissionState.unknown.canRetry)
        XCTAssertFalse(PermissionState.notRequested.canRetry)
        XCTAssertFalse(PermissionState.requesting.canRetry)
        XCTAssertFalse(PermissionState.granted.canRetry)
        XCTAssertTrue(PermissionState.denied.canRetry)
        XCTAssertFalse(PermissionState.restricted.canRetry)
    }
    
    // MARK: - PermissionManager Tests
    
    func testInitialState() {
        XCTAssertEqual(permissionManager.microphonePermissionState, .unknown)
        XCTAssertEqual(permissionManager.accessibilityPermissionState, .unknown)
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }
    
    func testCheckPermissionStateGranted() {
        // This test would need to mock AVCaptureDevice.authorizationStatus
        // For now, we test the logic flow
        permissionManager.checkPermissionState()
        
        // The actual state depends on system permissions
        // In CI/testing environment, it's typically .denied or .notDetermined
        XCTAssertTrue([.unknown, .notRequested, .denied, .granted, .restricted].contains(permissionManager.microphonePermissionState))
        XCTAssertTrue([.unknown, .notRequested, .denied, .granted, .restricted].contains(permissionManager.accessibilityPermissionState))
    }
    
    func testRequestPermissionWithEducationForNewPermission() {
        permissionManager.microphonePermissionState = .notRequested
        
        permissionManager.requestPermissionWithEducation()
        
        XCTAssertTrue(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }
    
    func testRequestPermissionWithEducationForDeniedPermission() {
        permissionManager.microphonePermissionState = .denied
        
        permissionManager.requestPermissionWithEducation()
        
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertTrue(permissionManager.showRecoveryModal)
    }
    
    func testRequestPermissionWithEducationForGrantedPermission() {
        permissionManager.microphonePermissionState = .granted
        permissionManager.accessibilityPermissionState = .granted
        
        permissionManager.requestPermissionWithEducation()
        
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }
    
    func testProceedWithPermissionRequest() {
        let expectation = XCTestExpectation(description: "Permission request completed")
        
        permissionManager.microphonePermissionState = .notRequested
        
        // Monitor for state changes
        let observation = permissionManager.$microphonePermissionState.sink { state in
            if state == .denied {
                expectation.fulfill()
            }
        }
        
        // Start the permission request
        permissionManager.proceedWithPermissionRequest()
        
        // In test environment, state change happens asynchronously
        // So we should still be in the initial state immediately after calling
        XCTAssertEqual(permissionManager.microphonePermissionState, .notRequested)
        
        wait(for: [expectation], timeout: 1.0)
        
        // In test environment, should be denied
        XCTAssertEqual(permissionManager.microphonePermissionState, .denied)
        
        observation.cancel()
    }
    
    func testProceedWithPermissionRequestShowsRecoveryOnDenial() {
        let expectation = XCTestExpectation(description: "Permission request completed")
        
        permissionManager.microphonePermissionState = .notRequested
        
        // Monitor for state changes
        let observation = permissionManager.$microphonePermissionState.sink { state in
            if state != .notRequested && state != .requesting {
                expectation.fulfill()
            }
        }
        
        permissionManager.proceedWithPermissionRequest()
        
        wait(for: [expectation], timeout: 1.0)
        
        // In test environment, should simulate denied state
        XCTAssertEqual(permissionManager.microphonePermissionState, .denied)
        XCTAssertTrue(permissionManager.showRecoveryModal)
        
        observation.cancel()
    }
    
    func testOpenSystemSettings() {
        // This test verifies the method doesn't crash
        // We can't easily test if the URL actually opens in a unit test
        XCTAssertNoThrow(permissionManager.openSystemSettings())
    }
    
    // MARK: - State Transition Tests
    
    func testStateTransitions() {
        // Test valid state transitions for microphone permission
        permissionManager.microphonePermissionState = .unknown
        XCTAssertEqual(permissionManager.microphonePermissionState, .unknown)
        
        permissionManager.microphonePermissionState = .notRequested
        XCTAssertEqual(permissionManager.microphonePermissionState, .notRequested)
        
        permissionManager.microphonePermissionState = .requesting
        XCTAssertEqual(permissionManager.microphonePermissionState, .requesting)
        
        permissionManager.microphonePermissionState = .granted
        XCTAssertEqual(permissionManager.microphonePermissionState, .granted)
        
        permissionManager.microphonePermissionState = .denied
        XCTAssertEqual(permissionManager.microphonePermissionState, .denied)
        
        permissionManager.microphonePermissionState = .restricted
        XCTAssertEqual(permissionManager.microphonePermissionState, .restricted)
        
        // Test valid state transitions for accessibility permission
        permissionManager.accessibilityPermissionState = .unknown
        XCTAssertEqual(permissionManager.accessibilityPermissionState, .unknown)
        
        permissionManager.accessibilityPermissionState = .notRequested
        XCTAssertEqual(permissionManager.accessibilityPermissionState, .notRequested)
        
        permissionManager.accessibilityPermissionState = .requesting
        XCTAssertEqual(permissionManager.accessibilityPermissionState, .requesting)
        
        permissionManager.accessibilityPermissionState = .granted
        XCTAssertEqual(permissionManager.accessibilityPermissionState, .granted)
        
        permissionManager.accessibilityPermissionState = .denied
        XCTAssertEqual(permissionManager.accessibilityPermissionState, .denied)
        
        permissionManager.accessibilityPermissionState = .restricted
        XCTAssertEqual(permissionManager.accessibilityPermissionState, .restricted)
    }
    
    func testModalStateManagement() {
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
        
        permissionManager.showEducationalModal = true
        XCTAssertTrue(permissionManager.showEducationalModal)
        
        permissionManager.showRecoveryModal = true
        XCTAssertTrue(permissionManager.showRecoveryModal)
        
        permissionManager.showEducationalModal = false
        permissionManager.showRecoveryModal = false
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }
    
    // MARK: - Edge Cases
    
    func testRequestPermissionInRestrictedState() {
        permissionManager.microphonePermissionState = .restricted
        
        permissionManager.requestPermissionWithEducation()
        
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }
    
    func testRequestPermissionWhileAlreadyRequesting() {
        permissionManager.microphonePermissionState = .requesting
        
        permissionManager.requestPermissionWithEducation()
        
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }
    
    // MARK: - Performance Tests
    
    func testPermissionStateCheckPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = PermissionState.unknown.needsRequest
                _ = PermissionState.denied.canRetry
                _ = PermissionState.granted.needsRequest
            }
        }
    }
    
    func testPermissionManagerCreationPerformance() {
        measure {
            for _ in 0..<100 {
                let manager = PermissionManager()
                _ = manager.microphonePermissionState
                _ = manager.accessibilityPermissionState
            }
        }
    }
    
    // MARK: - Multiple Instance Tests
    
    func testMultiplePermissionManagerInstances() {
        let manager1 = PermissionManager()
        let manager2 = PermissionManager()
        
        manager1.microphonePermissionState = .granted
        manager2.microphonePermissionState = .denied
        
        XCTAssertEqual(manager1.microphonePermissionState, .granted)
        XCTAssertEqual(manager2.microphonePermissionState, .denied)
        
        manager1.showEducationalModal = true
        manager2.showRecoveryModal = true
        
        XCTAssertTrue(manager1.showEducationalModal)
        XCTAssertFalse(manager1.showRecoveryModal)
        XCTAssertFalse(manager2.showEducationalModal)
        XCTAssertTrue(manager2.showRecoveryModal)
    }
    
    // MARK: - AllPermissionsGranted Tests
    
    func testAllPermissionsGrantedWithSmartPasteDisabled() {
        // When SmartPaste is disabled, only microphone permission is required
        UserDefaults.standard.set(false, forKey: "enableSmartPaste")
        
        permissionManager.microphonePermissionState = .granted
        permissionManager.accessibilityPermissionState = .denied
        
        XCTAssertTrue(permissionManager.allPermissionsGranted)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testAllPermissionsGrantedWithSmartPasteEnabled() {
        // When SmartPaste is enabled, both microphone and accessibility permissions are required
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        permissionManager.microphonePermissionState = .granted
        permissionManager.accessibilityPermissionState = .denied
        
        XCTAssertFalse(permissionManager.allPermissionsGranted)
        
        permissionManager.accessibilityPermissionState = .granted
        XCTAssertTrue(permissionManager.allPermissionsGranted)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testAllPermissionsGrantedWithMicrophoneDenied() {
        // Microphone permission is always required
        UserDefaults.standard.set(false, forKey: "enableSmartPaste")
        
        permissionManager.microphonePermissionState = .denied
        permissionManager.accessibilityPermissionState = .granted
        
        XCTAssertFalse(permissionManager.allPermissionsGranted)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    // MARK: - SmartPaste Permission Logic Tests
    
    func testCheckPermissionStateWithSmartPasteEnabled() {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        // Check that accessibility permission is checked when SmartPaste is enabled
        permissionManager.checkPermissionState()
        
        // Both permissions should be checked (we can't mock the actual results in this test)
        XCTAssertTrue([.unknown, .notRequested, .denied, .granted, .restricted].contains(permissionManager.microphonePermissionState))
        XCTAssertTrue([.unknown, .notRequested, .denied, .granted, .restricted].contains(permissionManager.accessibilityPermissionState))
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testCheckPermissionStateWithSmartPasteDisabled() {
        UserDefaults.standard.set(false, forKey: "enableSmartPaste")
        
        permissionManager.checkPermissionState()
        
        // Microphone permission should be checked
        XCTAssertTrue([.unknown, .notRequested, .denied, .granted, .restricted].contains(permissionManager.microphonePermissionState))
        
        // Accessibility permission should be set to granted (not needed)
        XCTAssertEqual(permissionManager.accessibilityPermissionState, .granted)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testRequestPermissionWithSmartPasteEnabled() {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        permissionManager.microphonePermissionState = .notRequested
        permissionManager.accessibilityPermissionState = .notRequested
        
        permissionManager.requestPermissionWithEducation()
        
        XCTAssertTrue(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testRequestPermissionWithSmartPasteDisabled() {
        UserDefaults.standard.set(false, forKey: "enableSmartPaste")
        
        permissionManager.microphonePermissionState = .notRequested
        permissionManager.accessibilityPermissionState = .denied  // This should be ignored
        
        permissionManager.requestPermissionWithEducation()
        
        XCTAssertTrue(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    func testRequestPermissionWithMixedStates() {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        permissionManager.microphonePermissionState = .granted
        permissionManager.accessibilityPermissionState = .denied
        
        permissionManager.requestPermissionWithEducation()
        
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertTrue(permissionManager.showRecoveryModal)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
    
    // MARK: - Combined Permission Testing
    
    func testProceedWithPermissionRequestWithSmartPasteEnabled() {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")
        
        let expectation = XCTestExpectation(description: "Permission request completed")
        
        permissionManager.microphonePermissionState = .notRequested
        permissionManager.accessibilityPermissionState = .notRequested
        
        // Monitor for state changes
        let observation = permissionManager.$microphonePermissionState.sink { state in
            if state == .denied {
                expectation.fulfill()
            }
        }
        
        // Start the permission request
        permissionManager.proceedWithPermissionRequest()
        
        // In test environment, state change happens asynchronously
        // So we should still be in the initial state immediately after calling
        XCTAssertEqual(permissionManager.microphonePermissionState, .notRequested)
        
        wait(for: [expectation], timeout: 1.0)
        
        // In test environment, should be denied and show recovery modal
        XCTAssertEqual(permissionManager.microphonePermissionState, .denied)
        XCTAssertEqual(permissionManager.accessibilityPermissionState, .denied)
        XCTAssertTrue(permissionManager.showRecoveryModal)
        
        observation.cancel()
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
    }
}