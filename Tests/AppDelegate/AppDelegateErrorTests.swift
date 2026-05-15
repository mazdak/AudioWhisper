import XCTest
import AppKit
@testable import AudioWhisper

/// Tests for error handling in app initialization and edge cases
@MainActor
final class AppDelegateErrorTests: IsolatedXCTestCase {
    // TODO(D1): AppDelegate error path tests toggle synthetic keys on
    // UserDefaults.standard. Migrate to a UUID-scoped suite once the
    // production paths accept an injected UserDefaults.
    override var enforcesStandardUserDefaultsIsolation: Bool { false }

    var appDelegate: AppDelegate!

    override func setUp() {
        super.setUp()
        appDelegate = AppDelegate()
    }

    override func tearDown() {
        appDelegate = nil
        super.tearDown()
    }

    // MARK: - Bundle Identifier Handling

    func testAppEnvironmentDetectsTestEnvironment() {
        XCTAssertTrue(AppEnvironment.isRunningTests)
    }

    func testLoggerFallbackForNilBundleIdentifier() {
        // Logger should work even in test environment where bundle ID may be nil
        // If this doesn't crash, the fallback works
        let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
        appDelegate.applicationDidFinishLaunching(notification)
        XCTAssertNotNil(appDelegate)
    }

    // MARK: - API Key Error Handling

    func testHasAPIKeyWithNonexistentService() {
        let service = "nonexistent.\(UUID().uuidString)"
        let hasKey = appDelegate.hasAPIKey(service: service, account: "test")
        XCTAssertFalse(hasKey)
    }

    func testHasAPIKeyWithEmptyStrings() {
        let hasKey = appDelegate.hasAPIKey(service: "", account: "")
        XCTAssertFalse(hasKey)
    }

    func testHasAPIKeyWithSpecialCharacters() {
        let service = "test.service.with-special_chars"
        let account = "test@account.com"
        let hasKey = appDelegate.hasAPIKey(service: service, account: account)
        XCTAssertFalse(hasKey)
    }

    // MARK: - Animation Timer Cleanup

    func testTerminationWithNilAnimationTimer() {
        appDelegate.recordingAnimationTimer = nil
        let notification = Notification(name: NSApplication.willTerminateNotification)
        appDelegate.applicationWillTerminate(notification)
        XCTAssertNil(appDelegate.recordingAnimationTimer)
    }

    func testAnimationTimerCancellationOnTerminate() {
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + 100, repeating: .seconds(1))
        timer.resume()
        appDelegate.recordingAnimationTimer = timer

        let notification = Notification(name: NSApplication.willTerminateNotification)
        appDelegate.applicationWillTerminate(notification)

        XCTAssertNil(appDelegate.recordingAnimationTimer)
    }

    func testMultipleTerminationCallsSafe() {
        // Multiple termination calls should not crash
        let notification = Notification(name: NSApplication.willTerminateNotification)
        appDelegate.applicationWillTerminate(notification)
        appDelegate.applicationWillTerminate(notification)
        appDelegate.applicationWillTerminate(notification)

        XCTAssertNotNil(appDelegate)
    }

    // MARK: - Window Controller

    func testWindowControllerExistsOnInit() {
        XCTAssertNotNil(appDelegate.windowController)
    }

    func testWindowControllerToggleInTestEnvironment() {
        // Should not crash in test environment
        appDelegate.windowController.toggleRecordWindow()
        XCTAssertNotNil(appDelegate.windowController)
    }

    func testWindowControllerMultipleTogglesSafe() {
        // Multiple toggles should not crash
        appDelegate.windowController.toggleRecordWindow()
        appDelegate.windowController.toggleRecordWindow()
        appDelegate.windowController.toggleRecordWindow()

        XCTAssertNotNil(appDelegate.windowController)
    }

    // MARK: - Window State Cleanup

    func testWindowStateCleanupKey() {
        // Verify the cleanup flag key exists and is consistent
        let key = "hasCleanedWindowState"

        // Reading the key should not crash
        _ = UserDefaults.standard.bool(forKey: key)

        XCTAssertNotNil(key)
    }

    func testWindowStateCleanupFlagCanBeSet() {
        let testKey = "testWindowStateCleanup.\(UUID().uuidString)"

        // Should be able to set and read the flag
        UserDefaults.standard.set(true, forKey: testKey)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: testKey))

        // Cleanup
        UserDefaults.standard.removeObject(forKey: testKey)
    }

    func testSavedApplicationStateDirectoryExists() {
        // Verify the Library directory exists
        let libraryPaths = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
        XCTAssertFalse(libraryPaths.isEmpty)

        let libraryPath = libraryPaths.first!
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryPath.path))
    }

    // MARK: - Initialization Edge Cases

    func testAppDelegateCanBeCreatedMultipleTimes() {
        // Creating multiple AppDelegate instances should not crash
        let delegate1 = AppDelegate()
        let delegate2 = AppDelegate()

        XCTAssertNotNil(delegate1)
        XCTAssertNotNil(delegate2)
    }

    func testLaunchNotificationWithEmptyUserInfo() {
        // Launch with empty user info should not crash
        let notification = Notification(
            name: NSApplication.didFinishLaunchingNotification,
            object: nil,
            userInfo: [:]
        )
        appDelegate.applicationDidFinishLaunching(notification)
        XCTAssertNotNil(appDelegate)
    }

    func testLaunchNotificationWithNilUserInfo() {
        // Launch with nil user info should not crash
        let notification = Notification(
            name: NSApplication.didFinishLaunchingNotification,
            object: nil,
            userInfo: nil
        )
        appDelegate.applicationDidFinishLaunching(notification)
        XCTAssertNotNil(appDelegate)
    }
}
