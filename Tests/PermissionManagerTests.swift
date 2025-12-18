import XCTest
@testable import AudioWhisper

@MainActor
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

    // MARK: - PermissionManager Initial State Tests

    func testInitialState() {
        XCTAssertEqual(permissionManager.microphonePermissionState, .unknown)
        XCTAssertEqual(permissionManager.accessibilityPermissionState, .unknown)
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }

    // MARK: - Modal State Logic Tests

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
}
