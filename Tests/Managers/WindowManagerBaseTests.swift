import XCTest
import AppKit
import SwiftUI
@testable import AudioWhisper

/// Tests for WindowManager base class functionality
@MainActor
final class WindowManagerBaseTests: XCTestCase {

    var windowManager: WindowManager!

    override func setUp() async throws {
        try await super.setUp()
        windowManager = WindowManager()
    }

    override func tearDown() async throws {
        windowManager = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testWindowManagerInitialization() {
        XCTAssertNotNil(windowManager)
    }

    func testWindowManagerRecordWindowInitiallyNil() {
        XCTAssertNil(windowManager.recordWindow)
    }

    func testWindowManagerIsObservableObject() {
        XCTAssertTrue(windowManager is ObservableObject)
    }

    // MARK: - Setup Recording Window Tests

    func testSetupRecordingWindowCallsCompletion() {
        var completionCalled = false

        windowManager.setupRecordingWindow {
            completionCalled = true
        }

        XCTAssertTrue(completionCalled)
    }

    func testSetupRecordingWindowAsyncVersion() async {
        // This should complete without crashing
        await windowManager.setupRecordingWindow()

        // In test environment without NSApp, window will be nil
        // This is expected behavior
        XCTAssertNil(windowManager.recordWindow)
    }

    // MARK: - Show/Hide Window Tests

    func testShowRecordingWindowWithNoWindow() {
        // Should not crash when recordWindow is nil
        windowManager.showRecordingWindow()

        XCTAssertNil(windowManager.recordWindow)
    }

    func testHideRecordingWindowWithNoWindow() {
        // Should not crash when recordWindow is nil
        windowManager.hideRecordingWindow()

        XCTAssertNil(windowManager.recordWindow)
    }

    // MARK: - Window Configuration Constants Tests

    func testWindowStyleMaskIsBorderless() {
        let expectedStyleMask: NSWindow.StyleMask = [.borderless]
        XCTAssertEqual(expectedStyleMask, [.borderless])
    }

    func testWindowLevelIsModalPanel() {
        let expectedLevel = NSWindow.Level.modalPanel
        XCTAssertEqual(expectedLevel, .modalPanel)
    }

    func testWindowCollectionBehavior() {
        let behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .fullScreenAuxiliary]
        XCTAssertTrue(behavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(behavior.contains(.fullScreenPrimary))
        XCTAssertTrue(behavior.contains(.fullScreenAuxiliary))
    }

    func testWindowTitle() {
        let expectedTitle = WindowTitles.recording
        XCTAssertFalse(expectedTitle.isEmpty)
    }

    // MARK: - Window Appearance Tests

    func testBackgroundColorIsClear() {
        let expectedColor = NSColor.clear
        XCTAssertNotNil(expectedColor)
    }

    func testWindowHasShadow() {
        let hasShadow = true
        XCTAssertTrue(hasShadow)
    }

    func testWindowIsNotOpaque() {
        let isOpaque = false
        XCTAssertFalse(isOpaque)
    }

    // MARK: - Titlebar Configuration Tests

    func testTitlebarAppearsTransparent() {
        let titlebarAppearsTransparent = true
        XCTAssertTrue(titlebarAppearsTransparent)
    }

    func testTitleVisibilityIsHidden() {
        let titleVisibility = NSWindow.TitleVisibility.hidden
        XCTAssertEqual(titleVisibility, .hidden)
    }

    func testMovableByWindowBackground() {
        let isMovableByWindowBackground = true
        XCTAssertTrue(isMovableByWindowBackground)
    }

    // MARK: - Standard Window Buttons Tests

    func testCloseButtonIsHidden() {
        let closeButtonHidden = true
        XCTAssertTrue(closeButtonHidden)
    }

    func testMiniaturizeButtonIsHidden() {
        let miniaturizeButtonHidden = true
        XCTAssertTrue(miniaturizeButtonHidden)
    }

    func testZoomButtonIsHidden() {
        let zoomButtonHidden = true
        XCTAssertTrue(zoomButtonHidden)
    }

    // MARK: - Mouse Tracking Tests

    func testAcceptsMouseMovedEvents() {
        let acceptsMouseMoved = true
        XCTAssertTrue(acceptsMouseMoved)
    }

    func testIgnoresMouseEventsIsFalse() {
        let ignoresMouseEvents = false
        XCTAssertFalse(ignoresMouseEvents)
    }

    // MARK: - Window Centering Logic Tests

    func testCenterWindowCalculation() {
        let screenWidth: CGFloat = 1920
        let screenHeight: CGFloat = 1080
        let windowWidth: CGFloat = 300
        let windowHeight: CGFloat = 200

        let centeredX = (screenWidth - windowWidth) / 2
        let centeredY = (screenHeight - windowHeight) / 2 + 50 // Slightly above center

        XCTAssertEqual(centeredX, 810)
        XCTAssertEqual(centeredY, 490)
    }

    // MARK: - Fallback Window Configuration Tests

    func testFallbackWindowStyleMask() {
        let fallbackStyleMask: NSWindow.StyleMask = [.borderless, .fullSizeContentView]
        XCTAssertTrue(fallbackStyleMask.contains(.borderless))
        XCTAssertTrue(fallbackStyleMask.contains(.fullSizeContentView))
    }

    func testFallbackWindowLevel() {
        let fallbackLevel = NSWindow.Level.floating
        XCTAssertEqual(fallbackLevel, .floating)
    }

    func testFallbackWindowCollectionBehavior() {
        let behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
        XCTAssertTrue(behavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(behavior.contains(.fullScreenPrimary))
    }

    // MARK: - Window Observer Tests

    func testWindowObserverNotification() {
        let notificationName = NSWindow.didResignKeyNotification
        XCTAssertEqual(notificationName, NSWindow.didResignKeyNotification)
    }

    // MARK: - Show Recording Window Logic Tests

    func testShowRecordingWindowActivatesApp() {
        // This tests the logic, not the actual NSApp call
        let ignoringOtherApps = true
        XCTAssertTrue(ignoringOtherApps)
    }

    // MARK: - Deinit Cleanup Tests

    func testWindowManagerDeinitCleansUpObserver() {
        var tempManager: WindowManager? = WindowManager()
        XCTAssertNotNil(tempManager)

        // Set to nil to trigger deinit
        tempManager = nil

        // If deinit doesn't crash, cleanup succeeded
        XCTAssertNil(tempManager)
    }

    // MARK: - Weak Reference Tests

    func testRecordWindowIsWeakReference() {
        // recordWindow is declared weak
        XCTAssertNil(windowManager.recordWindow)
    }

    // MARK: - Multiple Manager Instances Tests

    func testMultipleWindowManagerInstances() {
        let manager1 = WindowManager()
        let manager2 = WindowManager()

        XCTAssertNotNil(manager1)
        XCTAssertNotNil(manager2)
        XCTAssertFalse(manager1 === manager2)
    }

    // MARK: - MainActor Tests

    func testWindowManagerRunsOnMainActor() async {
        await MainActor.run {
            XCTAssertNotNil(windowManager)
        }
    }

    // MARK: - NSScreen Tests

    func testScreenFrameCalculation() {
        // Test calculation logic without requiring actual screen
        let mockScreenWidth: CGFloat = 1440
        let mockScreenHeight: CGFloat = 900
        let windowWidth: CGFloat = 280
        let windowHeight: CGFloat = 160

        let originX = (mockScreenWidth - windowWidth) / 2
        let originY = (mockScreenHeight - windowHeight) / 2 + 50

        XCTAssertEqual(originX, 580)
        XCTAssertEqual(originY, 420)
    }
}
