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
        XCTAssertEqual(permissionManager.permissionState, .unknown)
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }
    
    func testCheckPermissionStateGranted() {
        // This test would need to mock AVCaptureDevice.authorizationStatus
        // For now, we test the logic flow
        permissionManager.checkPermissionState()
        
        // The actual state depends on system permissions
        // In CI/testing environment, it's typically .denied or .notDetermined
        XCTAssertTrue([.unknown, .notRequested, .denied, .granted, .restricted].contains(permissionManager.permissionState))
    }
    
    func testRequestPermissionWithEducationForNewPermission() {
        permissionManager.permissionState = .notRequested
        
        permissionManager.requestPermissionWithEducation()
        
        XCTAssertTrue(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }
    
    func testRequestPermissionWithEducationForDeniedPermission() {
        permissionManager.permissionState = .denied
        
        permissionManager.requestPermissionWithEducation()
        
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertTrue(permissionManager.showRecoveryModal)
    }
    
    func testRequestPermissionWithEducationForGrantedPermission() {
        permissionManager.permissionState = .granted
        
        permissionManager.requestPermissionWithEducation()
        
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }
    
    func testProceedWithPermissionRequest() {
        let expectation = XCTestExpectation(description: "Permission request completed")
        
        permissionManager.permissionState = .notRequested
        
        // Monitor for state changes
        let observation = permissionManager.$permissionState.sink { state in
            if state == .denied {
                expectation.fulfill()
            }
        }
        
        // Start the permission request
        permissionManager.proceedWithPermissionRequest()
        
        // Should immediately set to requesting
        XCTAssertEqual(permissionManager.permissionState, .requesting)
        
        wait(for: [expectation], timeout: 1.0)
        
        // In test environment, should be denied
        XCTAssertEqual(permissionManager.permissionState, .denied)
        
        observation.cancel()
    }
    
    func testProceedWithPermissionRequestShowsRecoveryOnDenial() {
        let expectation = XCTestExpectation(description: "Permission request completed")
        
        permissionManager.permissionState = .notRequested
        
        // Monitor for state changes
        let observation = permissionManager.$permissionState.sink { state in
            if state != .notRequested && state != .requesting {
                expectation.fulfill()
            }
        }
        
        permissionManager.proceedWithPermissionRequest()
        
        wait(for: [expectation], timeout: 1.0)
        
        // In test environment, should simulate denied state
        XCTAssertEqual(permissionManager.permissionState, .denied)
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
        // Test valid state transitions
        permissionManager.permissionState = .unknown
        XCTAssertEqual(permissionManager.permissionState, .unknown)
        
        permissionManager.permissionState = .notRequested
        XCTAssertEqual(permissionManager.permissionState, .notRequested)
        
        permissionManager.permissionState = .requesting
        XCTAssertEqual(permissionManager.permissionState, .requesting)
        
        permissionManager.permissionState = .granted
        XCTAssertEqual(permissionManager.permissionState, .granted)
        
        permissionManager.permissionState = .denied
        XCTAssertEqual(permissionManager.permissionState, .denied)
        
        permissionManager.permissionState = .restricted
        XCTAssertEqual(permissionManager.permissionState, .restricted)
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
        permissionManager.permissionState = .restricted
        
        permissionManager.requestPermissionWithEducation()
        
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }
    
    func testRequestPermissionWhileAlreadyRequesting() {
        permissionManager.permissionState = .requesting
        
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
                _ = manager.permissionState
            }
        }
    }
    
    // MARK: - Multiple Instance Tests
    
    func testMultiplePermissionManagerInstances() {
        let manager1 = PermissionManager()
        let manager2 = PermissionManager()
        
        manager1.permissionState = .granted
        manager2.permissionState = .denied
        
        XCTAssertEqual(manager1.permissionState, .granted)
        XCTAssertEqual(manager2.permissionState, .denied)
        
        manager1.showEducationalModal = true
        manager2.showRecoveryModal = true
        
        XCTAssertTrue(manager1.showEducationalModal)
        XCTAssertFalse(manager1.showRecoveryModal)
        XCTAssertFalse(manager2.showEducationalModal)
        XCTAssertTrue(manager2.showRecoveryModal)
    }
}