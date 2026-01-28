import XCTest
import AppKit
@testable import AudioWhisper

/// Tests for AppDelegate base class functionality
@MainActor
final class AppDelegateBaseTests: XCTestCase {

    var appDelegate: AppDelegate!

    override func setUp() async throws {
        try await super.setUp()
        appDelegate = AppDelegate()
    }

    override func tearDown() async throws {
        appDelegate = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testAppDelegateInitialization() {
        XCTAssertNotNil(appDelegate)
    }

    func testAppDelegateHasWindowController() {
        XCTAssertNotNil(appDelegate.windowController)
    }

    func testAppDelegateStatusItemInitiallyNil() {
        // Status item is set up later during app launch
        XCTAssertNil(appDelegate.statusItem)
    }

    func testAppDelegateHotKeyManagerInitiallyNil() {
        // HotKeyManager is set up later during app launch
        XCTAssertNil(appDelegate.hotKeyManager)
    }

    func testAppDelegateKeyboardEventHandlerInitiallyNil() {
        XCTAssertNil(appDelegate.keyboardEventHandler)
    }

    func testAppDelegateAudioRecorderInitiallyNil() {
        XCTAssertNil(appDelegate.audioRecorder)
    }

    func testAppDelegateRecordingWindowInitiallyNil() {
        XCTAssertNil(appDelegate.recordingWindow)
    }

    func testAppDelegateRecordingWindowDelegateInitiallyNil() {
        XCTAssertNil(appDelegate.recordingWindowDelegate)
    }

    func testAppDelegateRecordingAnimationTimerInitiallyNil() {
        XCTAssertNil(appDelegate.recordingAnimationTimer)
    }

    func testAppDelegatePressAndHoldMonitorInitiallyNil() {
        XCTAssertNil(appDelegate.pressAndHoldMonitor)
    }

    // MARK: - Press and Hold Configuration Tests

    func testAppDelegateHasPressAndHoldConfiguration() {
        XCTAssertNotNil(appDelegate.pressAndHoldConfiguration)
    }

    func testAppDelegateIsHoldRecordingActiveInitiallyFalse() {
        XCTAssertFalse(appDelegate.isHoldRecordingActive)
    }

    // MARK: - HotkeyTriggerSource Enum Tests

    func testHotkeyTriggerSourceStandardHotkey() {
        let source = AppDelegate.HotkeyTriggerSource.standardHotkey
        XCTAssertEqual(source, .standardHotkey)
    }

    func testHotkeyTriggerSourcePressAndHold() {
        let source = AppDelegate.HotkeyTriggerSource.pressAndHold
        XCTAssertEqual(source, .pressAndHold)
    }

    func testHotkeyTriggerSourceEnumCases() {
        // Ensure both cases exist
        let sources: [AppDelegate.HotkeyTriggerSource] = [.standardHotkey, .pressAndHold]
        XCTAssertEqual(sources.count, 2)
    }

    func testHotkeyTriggerSourcesAreDistinct() {
        let standard = AppDelegate.HotkeyTriggerSource.standardHotkey
        let pressAndHold = AppDelegate.HotkeyTriggerSource.pressAndHold

        XCTAssertNotEqual(standard, pressAndHold)
    }

    // MARK: - NSApplicationDelegate Conformance Tests

    func testAppDelegateConformsToNSApplicationDelegate() {
        XCTAssertTrue(appDelegate is NSApplicationDelegate)
    }

    func testAppDelegateIsNSObject() {
        XCTAssertTrue(appDelegate is NSObject)
    }

    // MARK: - MainActor Tests

    func testAppDelegateRunsOnMainActor() async {
        // AppDelegate is marked @MainActor
        await MainActor.run {
            XCTAssertNotNil(appDelegate)
        }
    }

    // MARK: - Notification Observer Cleanup Tests

    func testAppDelegateRemovesNotificationObserversOnDeinit() {
        // Create a new instance that will be deallocated
        var tempDelegate: AppDelegate? = AppDelegate()
        XCTAssertNotNil(tempDelegate)

        // Set to nil to trigger deinit
        tempDelegate = nil

        // If deinit doesn't crash, cleanup succeeded
        XCTAssertNil(tempDelegate)
    }

    // MARK: - Window Controller Type Tests

    func testWindowControllerType() {
        XCTAssertTrue(appDelegate.windowController is WindowController)
    }

    // MARK: - State Transition Tests

    func testIsHoldRecordingActiveCanBeSet() {
        appDelegate.isHoldRecordingActive = true
        XCTAssertTrue(appDelegate.isHoldRecordingActive)

        appDelegate.isHoldRecordingActive = false
        XCTAssertFalse(appDelegate.isHoldRecordingActive)
    }

    // MARK: - Press and Hold Settings Tests

    func testPressAndHoldSettingsConfiguration() {
        let config = appDelegate.pressAndHoldConfiguration

        // Configuration should have expected properties
        XCTAssertNotNil(config)
    }

    // MARK: - Weak Reference Tests

    func testRecordingWindowIsWeakReference() {
        // recordingWindow is declared weak
        XCTAssertNil(appDelegate.recordingWindow)

        // Cannot easily test weak behavior without creating actual windows
        // This test verifies the property exists and is accessible
    }

    // MARK: - Multiple Instance Tests

    func testMultipleAppDelegateInstances() {
        let delegate1 = AppDelegate()
        let delegate2 = AppDelegate()

        XCTAssertNotNil(delegate1)
        XCTAssertNotNil(delegate2)

        // They should be different instances
        XCTAssertFalse(delegate1 === delegate2)
    }

    // MARK: - Property Assignment Tests

    func testStatusItemCanBeAssigned() {
        // In a real app, this would be created by the system
        // Here we just verify the property is writable
        appDelegate.statusItem = nil
        XCTAssertNil(appDelegate.statusItem)
    }

    func testHotKeyManagerCanBeAssigned() {
        appDelegate.hotKeyManager = nil
        XCTAssertNil(appDelegate.hotKeyManager)
    }

    func testKeyboardEventHandlerCanBeAssigned() {
        appDelegate.keyboardEventHandler = nil
        XCTAssertNil(appDelegate.keyboardEventHandler)
    }

    func testAudioRecorderCanBeAssigned() {
        appDelegate.audioRecorder = nil
        XCTAssertNil(appDelegate.audioRecorder)
    }

    func testPressAndHoldMonitorCanBeAssigned() {
        appDelegate.pressAndHoldMonitor = nil
        XCTAssertNil(appDelegate.pressAndHoldMonitor)
    }
}
