import XCTest
import AppKit
@testable import AudioWhisper

@MainActor
final class PasteManagerTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "enableSmartPaste")
        NSPasteboard.general.clearContents()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeManager(permissionGranted: Bool) -> PasteManager {
        let manager = PasteManager(
            accessibilityManager: AccessibilityPermissionManager(permissionCheck: { permissionGranted })
        )
        return manager
    }

    // MARK: - Tests

    func testSmartPasteDisabledPostsFailureAndSkipsActivation() async throws {
        UserDefaults.standard.set(false, forKey: "enableSmartPaste")

        let mockApp = MockRunningApplication()
        let manager = makeManager(permissionGranted: true)

        // Set up notification expectation before calling smartPaste
        let notificationReceived = expectation(description: "PasteOperationFailed fired")
        let observer = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.smartPaste(into: mockApp, text: "hello world")

        await fulfillment(of: [notificationReceived], timeout: 1.0)
        XCTAssertEqual(mockApp.mockActivationCount, 0)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "hello world")
    }

    func testSmartPasteFailsWhenPermissionDenied() async throws {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")

        let mockApp = MockRunningApplication()
        let manager = makeManager(permissionGranted: false)

        let notificationReceived = expectation(description: "PasteOperationFailed fired")
        let observer = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.smartPaste(into: mockApp, text: "needs permission")

        await fulfillment(of: [notificationReceived], timeout: 1.0)
        XCTAssertEqual(mockApp.mockActivationCount, 0)
    }

    func testSmartPasteFailsForNilTargetApplication() async throws {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")

        let manager = makeManager(permissionGranted: true)

        let notificationReceived = expectation(description: "PasteOperationFailed fired")
        let observer = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.smartPaste(into: nil, text: "no target app")

        await fulfillment(of: [notificationReceived], timeout: 1.0)
    }

    func testSmartPasteAttemptsActivationThenFailsInsideTests() async throws {
        UserDefaults.standard.set(true, forKey: "enableSmartPaste")

        let mockApp = MockRunningApplication()
        let manager = makeManager(permissionGranted: true)

        let notificationReceived = expectation(description: "PasteOperationFailed fired")
        let observer = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.smartPaste(into: mockApp, text: "attempt paste")

        await fulfillment(of: [notificationReceived], timeout: 1.0)
        XCTAssertEqual(mockApp.mockActivationCount, 1)
    }
}
