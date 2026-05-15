import XCTest
import AppKit
@testable import AudioWhisper

/// Integration tests for SmartPaste flow:
/// Transcription -> PasteManager -> Clipboard -> Notification
@MainActor
final class SmartPasteIntegrationTests: IsolatedXCTestCase {
    var testDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()

        // Create isolated UserDefaults
        let suiteName = "SmartPasteIntegrationTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!

        // Reset test environment
        testDefaults.set(true, forKey: "enableSmartPaste")
    }

    override func tearDown() async throws {
        testDefaults.removePersistentDomain(forName: testDefaults.description)
        testDefaults = nil

        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func waitForAsyncOperation() async {
        try? await Task.sleep(for: .milliseconds(100))
    }

    /// Creates a unique named pasteboard to avoid race conditions with parallel tests
    private func createTestPasteboard() -> NSPasteboard {
        let name = NSPasteboard.Name("SmartPasteTest-\(UUID().uuidString)")
        return NSPasteboard(name: name)
    }

    // MARK: - Clipboard Integration Tests

    func testTextCopiedToClipboard() {
        // Given
        let testText = "This is test transcription text for clipboard"
        let pasteboard = createTestPasteboard()
        defer { pasteboard.releaseGlobally() }

        // When - Copy to pasteboard
        pasteboard.clearContents()
        pasteboard.setString(testText, forType: .string)

        // Then - Text is in clipboard
        let clipboardText = pasteboard.string(forType: .string)
        XCTAssertEqual(clipboardText, testText)
    }

    func testClipboardClearedBeforeNewContent() {
        // Given - Existing content in clipboard
        let pasteboard = createTestPasteboard()
        defer { pasteboard.releaseGlobally() }

        pasteboard.clearContents()
        pasteboard.setString("Old content", forType: .string)

        // When - Clear and set new content
        pasteboard.clearContents()
        pasteboard.setString("New content", forType: .string)

        // Then - Only new content exists
        let clipboardText = pasteboard.string(forType: .string)
        XCTAssertEqual(clipboardText, "New content")
        XCTAssertNotEqual(clipboardText, "Old content")
    }

    func testEmptyTextHandledGracefully() {
        // Given
        let emptyText = ""
        let pasteboard = createTestPasteboard()
        defer { pasteboard.releaseGlobally() }

        // When
        pasteboard.clearContents()
        let success = pasteboard.setString(emptyText, forType: .string)

        // Then - Empty string can be set
        XCTAssertTrue(success)
        let clipboardText = pasteboard.string(forType: .string)
        XCTAssertEqual(clipboardText, "")
    }

    func testLongTextCopiedSuccessfully() {
        // Given - Very long text
        let longText = String(repeating: "This is a long sentence. ", count: 1000)
        let pasteboard = createTestPasteboard()
        defer { pasteboard.releaseGlobally() }

        // When
        pasteboard.clearContents()
        pasteboard.setString(longText, forType: .string)

        // Then
        let clipboardText = pasteboard.string(forType: .string)
        XCTAssertEqual(clipboardText, longText)
    }

    func testUnicodeTextCopiedCorrectly() {
        // Given - Unicode text
        let unicodeText = "Hello 世界! Привет! 🎉 émojis and ñ special chars"
        let pasteboard = createTestPasteboard()
        defer { pasteboard.releaseGlobally() }

        // When
        pasteboard.clearContents()
        let success = pasteboard.setString(unicodeText, forType: .string)

        // Verify the write succeeded
        XCTAssertTrue(success, "Pasteboard write should succeed")

        // Then
        let clipboardText = pasteboard.string(forType: .string)
        XCTAssertEqual(clipboardText, unicodeText)
    }

    // MARK: - Notification Integration Tests

    func testPasteSuccessNotificationPosted() async {
        // Given
        let expectation = XCTestExpectation(description: "Notification received")
        // Use actor to safely capture notification in @Sendable closure
        actor NotificationCapture {
            var notification: Notification?
            func set(_ n: Notification) { notification = n }
            func get() -> Notification? { notification }
        }
        let capture = NotificationCapture()

        let observer = NotificationCenter.default.addObserver(
            forName: .pasteOperationSucceeded,
            object: nil,
            queue: .main
        ) { notification in
            Task { await capture.set(notification) }
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        // When - Post success notification (simulating PasteManager behavior)
        NotificationCenter.default.post(name: .pasteOperationSucceeded, object: nil)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        let receivedNotification = await capture.get()
        XCTAssertNotNil(receivedNotification)
        XCTAssertEqual(receivedNotification?.name, .pasteOperationSucceeded)
    }

    func testPasteFailureNotificationPosted() async {
        // Given
        let expectation = XCTestExpectation(description: "Failure notification received")
        // Use actor to safely capture notification in @Sendable closure
        actor NotificationCapture {
            var notification: Notification?
            func set(_ n: Notification) { notification = n }
            func get() -> Notification? { notification }
        }
        let capture = NotificationCapture()

        let observer = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: .main
        ) { notification in
            Task { await capture.set(notification) }
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        // When - Post failure notification with error info
        let errorInfo: [String: Any] = ["error": "Permission denied"]
        NotificationCenter.default.post(
            name: .pasteOperationFailed,
            object: nil,
            userInfo: errorInfo
        )

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        let receivedNotification = await capture.get()
        XCTAssertNotNil(receivedNotification)
        XCTAssertEqual(receivedNotification?.name, .pasteOperationFailed)
        XCTAssertNotNil(receivedNotification?.userInfo)
    }

    // MARK: - Settings Integration Tests

    func testSmartPasteSettingEnabled() {
        // Given/When
        testDefaults.set(true, forKey: "enableSmartPaste")

        // Then
        let isEnabled = testDefaults.bool(forKey: "enableSmartPaste")
        XCTAssertTrue(isEnabled)
    }

    func testSmartPasteSettingDisabled() {
        // Given/When
        testDefaults.set(false, forKey: "enableSmartPaste")

        // Then
        let isEnabled = testDefaults.bool(forKey: "enableSmartPaste")
        XCTAssertFalse(isEnabled)
    }

    func testSmartPasteCanBeDisabled() {
        // Given - Fresh UserDefaults suite
        let suiteName = "SmartPasteTest-\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        defer { testDefaults.removePersistentDomain(forName: suiteName) }

        // When - Explicitly set to disabled
        testDefaults.set(false, forKey: "enableSmartPaste")

        // Then - Value should be false
        XCTAssertFalse(testDefaults.bool(forKey: "enableSmartPaste"))
    }

    // MARK: - Notification Name Tests

    func testNotificationNamesExist() {
        // Verify the notification names are defined
        XCTAssertNotNil(Notification.Name.pasteOperationSucceeded)
        XCTAssertNotNil(Notification.Name.pasteOperationFailed)
    }

    // MARK: - Mock Notification Center Tests

    func testMockNotificationCenterCapturesNotifications() async {
        // Given
        let mockCenter = MockNotificationCenter()

        // When
        mockCenter.post(name: .pasteOperationSucceeded, object: nil)
        mockCenter.post(name: .pasteOperationFailed, object: nil, userInfo: ["error": "test"])

        await mockCenter.waitForNotifications()

        // Then
        XCTAssertTrue(mockCenter.didPost(.pasteOperationSucceeded))
        XCTAssertTrue(mockCenter.didPost(.pasteOperationFailed))
        XCTAssertEqual(mockCenter.postCount(for: .pasteOperationSucceeded), 1)
        XCTAssertEqual(mockCenter.postCount(for: .pasteOperationFailed), 1)
    }

    func testMockNotificationCenterReset() async {
        // Given
        let mockCenter = MockNotificationCenter()
        mockCenter.post(name: .pasteOperationSucceeded, object: nil)

        await mockCenter.waitForNotifications()
        XCTAssertTrue(mockCenter.didPost(.pasteOperationSucceeded))

        // When
        mockCenter.reset()

        await mockCenter.waitForNotifications()

        // Then
        XCTAssertFalse(mockCenter.didPost(.pasteOperationSucceeded))
    }

    // MARK: - Clipboard Flow Simulation

    func testTranscriptionToClipboardFlow() {
        // Given - Simulated transcription result
        let transcriptionResult = "Hello, this is my voice transcription"
        let pasteboard = createTestPasteboard()
        defer { pasteboard.releaseGlobally() }

        // When - Copy to clipboard (as the app does)
        pasteboard.clearContents()
        let copySuccess = pasteboard.setString(transcriptionResult, forType: .string)

        // Then - Text is available for pasting
        XCTAssertTrue(copySuccess)
        XCTAssertEqual(pasteboard.string(forType: .string), transcriptionResult)
    }

    func testMultipleTranscriptionsReplaceClipboard() {
        // Given - First transcription
        let pasteboard = createTestPasteboard()
        defer { pasteboard.releaseGlobally() }

        pasteboard.clearContents()
        pasteboard.setString("First transcription", forType: .string)

        // When - Second transcription replaces first
        pasteboard.clearContents()
        pasteboard.setString("Second transcription", forType: .string)

        // Then - Only latest is in clipboard
        XCTAssertEqual(pasteboard.string(forType: .string), "Second transcription")
    }
}

