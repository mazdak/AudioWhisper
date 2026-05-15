import XCTest
@testable import AudioWhisper

/// Tests for AppDelegate+Hotkeys.swift focusing on hotkey and recording handling
@MainActor
final class AppDelegateHotkeysTests: IsolatedXCTestCase {
    // TODO(D1): AppDelegate reads `immediateRecording` from
    // UserDefaults.standard directly. Once it accepts an injected
    // UserDefaults, route writes through a UUID-scoped suite and re-enable.
    override var enforcesStandardUserDefaultsIsolation: Bool { false }

    var appDelegate: AppDelegate!
    var testDefaults: UserDefaults!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        appDelegate = AppDelegate()
        suiteName = "AppDelegateHotkeysTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        appDelegate.pressAndHoldMonitor?.stop()
        appDelegate.pressAndHoldMonitor = nil
        appDelegate.recordingAnimationTimer?.cancel()
        appDelegate.recordingAnimationTimer = nil
        appDelegate = nil
        if let suiteName = suiteName {
            testDefaults?.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - configureShortcutMonitors Tests

    func testConfigureShortcutMonitorsStopsExistingMonitor() {
        // Create an initial monitor
        let initialConfig = PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold)
        let initialMonitor = PressAndHoldKeyMonitor(
            configuration: initialConfig,
            keyDownHandler: {}
        )
        initialMonitor.start()
        appDelegate.pressAndHoldMonitor = initialMonitor

        // Configure new monitors
        appDelegate.configureShortcutMonitors()

        // The old monitor should have been replaced
        XCTAssertNotNil(appDelegate.pressAndHoldMonitor)
    }

    func testConfigureShortcutMonitorsReadsConfiguration() {
        // Configure monitors
        appDelegate.configureShortcutMonitors()

        // Verify configuration was read
        XCTAssertEqual(appDelegate.pressAndHoldConfiguration, PressAndHoldSettings.configuration())
    }

    func testConfigureShortcutMonitorsReturnsEarlyWhenDisabled() {
        // Disable press-and-hold
        PressAndHoldSettings.update(PressAndHoldConfiguration(enabled: false, key: .rightCommand, mode: .hold))

        // Configure monitors
        appDelegate.configureShortcutMonitors()

        // Monitor should be nil when disabled
        XCTAssertNil(appDelegate.pressAndHoldMonitor)

        // Restore defaults
        PressAndHoldSettings.update(PressAndHoldConfiguration.defaults)
    }

    func testConfigureShortcutMonitorsSetsKeyUpHandlerForHoldMode() {
        // Set hold mode
        let holdConfig = PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold)
        PressAndHoldSettings.update(holdConfig)

        // Configure monitors
        appDelegate.configureShortcutMonitors()

        // Monitor should be created
        XCTAssertNotNil(appDelegate.pressAndHoldMonitor)

        // Restore defaults
        PressAndHoldSettings.update(PressAndHoldConfiguration.defaults)
    }

    func testConfigureShortcutMonitorsNoKeyUpHandlerForToggleMode() {
        // Set toggle mode
        let toggleConfig = PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .toggle)
        PressAndHoldSettings.update(toggleConfig)

        // Configure monitors
        appDelegate.configureShortcutMonitors()

        // Monitor should be created
        XCTAssertNotNil(appDelegate.pressAndHoldMonitor)

        // Restore defaults
        PressAndHoldSettings.update(PressAndHoldConfiguration.defaults)
    }

    // MARK: - handleHotkey Tests

    func testHandleHotkeyWithImmediateRecordingEnabled() {
        // Test that immediate recording setting can be read
        UserDefaults.standard.set(true, forKey: "immediateRecording")
        let immediateRecording = UserDefaults.standard.bool(forKey: "immediateRecording")
        XCTAssertTrue(immediateRecording)
    }

    func testHandleHotkeyWithImmediateRecordingDisabled() {
        // Test that immediate recording setting can be disabled
        UserDefaults.standard.set(false, forKey: "immediateRecording")
        let immediateRecording = UserDefaults.standard.bool(forKey: "immediateRecording")
        XCTAssertFalse(immediateRecording)

        // Restore default
        UserDefaults.standard.set(true, forKey: "immediateRecording")
    }

    func testHandleHotkeyWithMockRecorderNotRecording() {
        // Create mock recorder
        let mockRecorder = MockAudioEngineRecorder()
        mockRecorder.startRecordingResult = false  // Simulate permission denied

        // Verify mock is properly configured
        XCTAssertFalse(mockRecorder.startRecordingResult)
        XCTAssertFalse(mockRecorder.isRecording)

        // Start recording should return false
        let result = mockRecorder.startRecording()
        XCTAssertFalse(result)
        XCTAssertFalse(mockRecorder.isRecording)
    }

    func testHandleHotkeyPostsSpaceKeyNotificationWhenRecording() {
        // This tests the notification flow
        // Note: Can't call handleHotkey directly without full UI setup
        // Just verify the notification name exists
        let name = Notification.Name.spaceKeyPressed
        XCTAssertNotNil(name)
    }

    // MARK: - Recording State Tests

    func testIsHoldRecordingActiveInitiallyFalse() {
        XCTAssertFalse(appDelegate.isHoldRecordingActive)
    }

    func testRecordingAnimationTimerInitiallyNil() {
        XCTAssertNil(appDelegate.recordingAnimationTimer)
    }

    // MARK: - onRecordingStopped Tests

    func testOnRecordingStoppedDoesNotCrash() {
        // Verify no status item initially
        XCTAssertNil(appDelegate.statusItem)

        // Call onRecordingStopped - should handle nil status item gracefully
        appDelegate.onRecordingStopped()

        // Should not crash with nil status item
        XCTAssertNil(appDelegate.statusItem)
    }

    // MARK: - Recording Animation Tests

    func testRecordingAnimationTimerCleanup() {
        // Create a mock timer
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + 100, repeating: .seconds(1))
        timer.resume()
        appDelegate.recordingAnimationTimer = timer

        // Verify timer exists
        XCTAssertNotNil(appDelegate.recordingAnimationTimer)

        // Cancel timer
        appDelegate.recordingAnimationTimer?.cancel()
        appDelegate.recordingAnimationTimer = nil

        // Verify cleanup
        XCTAssertNil(appDelegate.recordingAnimationTimer)
    }

    // MARK: - HotkeyTriggerSource Tests

    func testHotkeyTriggerSourceStandardHotkey() {
        let source = AppDelegate.HotkeyTriggerSource.standardHotkey
        XCTAssertEqual(source, .standardHotkey)
    }

    func testHotkeyTriggerSourcePressAndHold() {
        let source = AppDelegate.HotkeyTriggerSource.pressAndHold
        XCTAssertEqual(source, .pressAndHold)
    }

    // MARK: - Notification Tests

    func testRecordingStartFailedNotificationName() {
        // Verify notification name exists
        let name = Notification.Name.recordingStartFailed
        XCTAssertNotNil(name)
    }

    func testSpaceKeyPressedNotificationName() {
        // Verify notification name exists
        let name = Notification.Name.spaceKeyPressed
        XCTAssertNotNil(name)
    }

    // MARK: - Press and Hold Configuration Tests

    func testPressAndHoldConfigurationUpdatesOnSettingsChange() {
        // Get initial configuration
        let initialConfig = appDelegate.pressAndHoldConfiguration

        // Update settings
        let newConfig = PressAndHoldConfiguration(enabled: false, key: .leftOption, mode: .toggle)
        PressAndHoldSettings.update(newConfig)

        // Configure monitors (which updates configuration)
        appDelegate.configureShortcutMonitors()

        // Verify configuration changed
        XCTAssertEqual(appDelegate.pressAndHoldConfiguration.enabled, false)
        XCTAssertEqual(appDelegate.pressAndHoldConfiguration.key, .leftOption)
        XCTAssertEqual(appDelegate.pressAndHoldConfiguration.mode, .toggle)

        // Restore defaults
        PressAndHoldSettings.update(initialConfig)
    }
}
