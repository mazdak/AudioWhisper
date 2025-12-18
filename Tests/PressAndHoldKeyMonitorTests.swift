import XCTest
import AppKit
@testable import AudioWhisper

final class PressAndHoldKeyMonitorTests: XCTestCase {
    private var addedEvents: [(NSEvent.EventTypeMask, (NSEvent) -> Void)] = []
    private var removedEvents: [Any] = []

    override func tearDown() {
        addedEvents.removeAll()
        removedEvents.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeMonitor(
        configuration: PressAndHoldConfiguration,
        keyDownHandler: @escaping () -> Void = {},
        keyUpHandler: (() -> Void)? = nil
    ) -> PressAndHoldKeyMonitor {
        let addMonitor: PressAndHoldKeyMonitor.EventMonitorFactory = { [weak self] mask, handler in
            self?.addedEvents.append((mask, handler))
            return self?.addedEvents.count ?? 0
        }

        let removeMonitor: PressAndHoldKeyMonitor.EventMonitorRemoval = { [weak self] token in
            self?.removedEvents.append(token)
        }

        return PressAndHoldKeyMonitor(
            configuration: configuration,
            keyDownHandler: keyDownHandler,
            keyUpHandler: keyUpHandler,
            addGlobalMonitor: addMonitor,
            removeMonitor: removeMonitor
        )
    }

    // MARK: - start()

    func testStartRegistersFlagMonitorForModifierKey() {
        let config = PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold)
        let monitor = makeMonitor(configuration: config)

        monitor.start()

        XCTAssertEqual(addedEvents.count, 1)
        XCTAssertEqual(addedEvents.first?.0, .flagsChanged)
    }

    // MARK: - Transitions

    func testKeyDownInvokesHandlerOnlyOnceUntilReleased() {
        let expectationDown = expectation(description: "keyDown")
        expectationDown.expectedFulfillmentCount = 2

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {
                expectationDown.fulfill()
            }
        )

        monitor.processTransition(isKeyDownEvent: true)  // first press
        monitor.processTransition(isKeyDownEvent: true)  // repeat press ignored
        monitor.processTransition(isKeyDownEvent: false) // release
        monitor.processTransition(isKeyDownEvent: true)  // second press

        wait(for: [expectationDown], timeout: 1.0)
    }

    func testKeyUpInvokesHandlerWhenConfigured() {
        let expectationUp = expectation(description: "keyUp")

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {},
            keyUpHandler: {
                expectationUp.fulfill()
            }
        )

        monitor.processTransition(isKeyDownEvent: true)
        monitor.processTransition(isKeyDownEvent: false)

        wait(for: [expectationUp], timeout: 1.0)
    }

    func testKeyUpHandlerNotCalledWhenNeverPressed() {
        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {},
            keyUpHandler: {
                XCTFail("Key up should not fire without prior key down")
            }
        )

        monitor.processTransition(isKeyDownEvent: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    // MARK: - stop()

    func testStopRemovesRegisteredMonitors() {
        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold)
        )

        monitor.start()
        monitor.stop()

        XCTAssertEqual(removedEvents.count, 1)
    }
}
