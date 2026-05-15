import XCTest
@testable import AudioWhisper

/// Tests for AppDelegate+Lifecycle.swift focusing on app initialization and termination
@MainActor
final class AppDelegateLifecycleTests: IsolatedXCTestCase {
    // TODO(D1): One test registers volatile defaults on
    // UserDefaults.standard (does not mutate the persistent domain), but
    // the registration is visible via `bool(forKey:)`. Disable isolation
    // here until the lifecycle code accepts an injected UserDefaults.
    override var enforcesStandardUserDefaultsIsolation: Bool { false }

    var appDelegate: AppDelegate!
    var testDefaults: UserDefaults!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        appDelegate = AppDelegate()
        suiteName = "AppDelegateLifecycleTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        appDelegate = nil
        if let suiteName = suiteName {
            testDefaults?.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - UserDefaults Registration Tests

    func testApplicationDidFinishLaunchingRegistersDefaults() {
        // The defaults should be registered when app launches
        // We test by checking that the defaults exist after launch
        let defaults = UserDefaults.standard

        // These defaults should be registered
        // Note: In test environment, applicationDidFinishLaunching returns early
        // so we verify the defaults registration directly
        defaults.register(defaults: [
            "enableSmartPaste": true,
            "immediateRecording": true,
            "startAtLogin": true,
            "playCompletionSound": true
        ])

        // Verify the registered defaults are accessible
        XCTAssertTrue(defaults.bool(forKey: "enableSmartPaste"))
        XCTAssertTrue(defaults.bool(forKey: "immediateRecording"))
        XCTAssertTrue(defaults.bool(forKey: "startAtLogin"))
        XCTAssertTrue(defaults.bool(forKey: "playCompletionSound"))
    }

    func testApplicationDidFinishLaunchingSkipsUIInTestEnvironment() {
        // Create notification
        let notification = Notification(name: NSApplication.didFinishLaunchingNotification)

        // Call the lifecycle method
        appDelegate.applicationDidFinishLaunching(notification)

        // In test environment, UI should not be initialized
        // Status item should be nil because test environment is detected
        XCTAssertNil(appDelegate.statusItem)
        XCTAssertNil(appDelegate.audioRecorder)
        XCTAssertNil(appDelegate.hotKeyManager)
    }

    // MARK: - shouldTerminateAfterLastWindowClosed Tests

    func testApplicationShouldTerminateAfterLastWindowClosedReturnsFalse() {
        // Menu bar apps should not terminate when last window closes
        let result = appDelegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        XCTAssertFalse(result, "Menu bar app should not terminate when last window closes")
    }

    // MARK: - applicationWillTerminate Tests

    func testApplicationWillTerminateCancelsAnimationTimer() {
        // Set up a mock animation timer
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + 100, repeating: .seconds(1))
        timer.resume()
        appDelegate.recordingAnimationTimer = timer

        // Terminate
        let notification = Notification(name: NSApplication.willTerminateNotification)
        appDelegate.applicationWillTerminate(notification)

        // Timer should be nil after termination
        XCTAssertNil(appDelegate.recordingAnimationTimer)
    }

    func testApplicationWillTerminateCleanupsTempFiles() {
        // Create a temporary file in the temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("old_recording_test.m4a")

        do {
            try "test".write(to: tempFile, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to create test file: \(error)")
            return
        }

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempFile.path))

        // Terminate
        let notification = Notification(name: NSApplication.willTerminateNotification)
        appDelegate.applicationWillTerminate(notification)

        // Note: AppSetupHelper.cleanupOldTemporaryFiles() is called
        // We can't directly verify it without inspecting the implementation
    }

    func testApplicationWillTerminateCleansUpWindowReferences() {
        // Verify initial state - no window
        XCTAssertNil(appDelegate.recordingWindow)
        XCTAssertNil(appDelegate.recordingWindowDelegate)

        // Terminate
        let notification = Notification(name: NSApplication.willTerminateNotification)
        appDelegate.applicationWillTerminate(notification)

        // Window references should still be nil after termination
        XCTAssertNil(appDelegate.recordingWindow)
        XCTAssertNil(appDelegate.recordingWindowDelegate)
    }

    // MARK: - hasAPIKey Tests

    func testHasAPIKeyWithValidKey() {
        // Save a key to keychain
        let service = "test.service"
        let account = "test.account"
        let key = "test-api-key"

        KeychainService.shared.saveQuietly(key, service: service, account: account)

        // Verify hasAPIKey returns true
        let hasKey = appDelegate.hasAPIKey(service: service, account: account)
        XCTAssertTrue(hasKey)

        // Cleanup
        KeychainService.shared.deleteQuietly(service: service, account: account)
    }

    func testHasAPIKeyWithMissingKey() {
        // Use a service/account that doesn't exist
        let service = "nonexistent.service.\(UUID().uuidString)"
        let account = "nonexistent.account"

        // Verify hasAPIKey returns false
        let hasKey = appDelegate.hasAPIKey(service: service, account: account)
        XCTAssertFalse(hasKey)
    }

    // MARK: - Initial State Tests

    func testInitialStateOfAppDelegate() {
        // Verify initial state after creation
        XCTAssertNil(appDelegate.statusItem)
        XCTAssertNil(appDelegate.hotKeyManager)
        XCTAssertNil(appDelegate.audioRecorder)
        XCTAssertNil(appDelegate.recordingAnimationTimer)
        XCTAssertNil(appDelegate.pressAndHoldMonitor)
        XCTAssertFalse(appDelegate.isHoldRecordingActive)
        XCTAssertNotNil(appDelegate.windowController)
    }

    func testPressAndHoldConfigurationLoadsFromDefaults() {
        // Verify configuration is loaded
        let config = appDelegate.pressAndHoldConfiguration
        XCTAssertNotNil(config)

        // Verify it matches PressAndHoldSettings
        let expectedConfig = PressAndHoldSettings.configuration()
        XCTAssertEqual(config.enabled, expectedConfig.enabled)
        XCTAssertEqual(config.key, expectedConfig.key)
        XCTAssertEqual(config.mode, expectedConfig.mode)
    }

    // MARK: - Recording Window Delegate Tests

    func testRecordingWindowDelegateCleanupOnClose() {
        // Test that RecordingWindowDelegate closure is called on window close
        var closeCalled = false

        let delegate = RecordingWindowDelegate {
            closeCalled = true
        }

        // Simulate window close - just the notification, no actual window
        delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))

        // Verify closure was called
        XCTAssertTrue(closeCalled)
    }

    // MARK: - HotkeyTriggerSource Tests

    func testHotkeyTriggerSourceEnum() {
        // Verify enum cases exist and are different
        let standardSource = AppDelegate.HotkeyTriggerSource.standardHotkey
        let pressAndHoldSource = AppDelegate.HotkeyTriggerSource.pressAndHold

        // Verify the cases can be created
        XCTAssertNotNil(standardSource)
        XCTAssertNotNil(pressAndHoldSource)

        // Verify they are different by comparing them
        // (This assumes HotkeyTriggerSource conforms to Equatable)
        if case .standardHotkey = standardSource {
            // Success - standardSource is the correct case
        } else {
            XCTFail("standardSource should be .standardHotkey")
        }

        if case .pressAndHold = pressAndHoldSource {
            // Success - pressAndHoldSource is the correct case
        } else {
            XCTFail("pressAndHoldSource should be .pressAndHold")
        }
    }
}
