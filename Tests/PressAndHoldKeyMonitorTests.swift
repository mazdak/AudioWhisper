import XCTest
import AppKit
@testable import AudioWhisper

final class PressAndHoldKeyMonitorTests: XCTestCase {
    private var addedGlobalEvents: [(NSEvent.EventTypeMask, (NSEvent) -> Void)] = []
    private var addedLocalEvents: [(NSEvent.EventTypeMask, (NSEvent) -> NSEvent?)] = []
    private var removedEvents: [Any] = []

    override func tearDown() {
        addedGlobalEvents.removeAll()
        addedLocalEvents.removeAll()
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
            self?.addedGlobalEvents.append((mask, handler))
            return self?.addedGlobalEvents.count ?? 0
        }

        let addLocalMonitor: PressAndHoldKeyMonitor.LocalEventMonitorFactory = { [weak self] mask, handler in
            self?.addedLocalEvents.append((mask, handler))
            return self?.addedLocalEvents.count ?? 0
        }

        let removeMonitor: PressAndHoldKeyMonitor.EventMonitorRemoval = { [weak self] token in
            self?.removedEvents.append(token)
        }

        return PressAndHoldKeyMonitor(
            configuration: configuration,
            keyDownHandler: keyDownHandler,
            keyUpHandler: keyUpHandler,
            addGlobalMonitor: addMonitor,
            addLocalMonitor: addLocalMonitor,
            removeMonitor: removeMonitor
        )
    }

    private func makeFlagsChangedEvent(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> NSEvent? {
        NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
    }

    // MARK: - start()

    func testStartRegistersFlagMonitorForModifierKey() {
        let config = PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold)
        let monitor = makeMonitor(configuration: config)

        monitor.start()

        XCTAssertEqual(addedGlobalEvents.count, 1)
        XCTAssertEqual(addedGlobalEvents.first?.0, .flagsChanged)
        XCTAssertEqual(addedLocalEvents.count, 1)
        XCTAssertEqual(addedLocalEvents.first?.0, .flagsChanged)
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

    func testModifierReleaseIsDetectedWhenOppositeSideRemainsHeld() {
        let keyDownExpectation = expectation(description: "keyDown")
        let keyUpExpectation = expectation(description: "keyUp")

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: { keyDownExpectation.fulfill() },
            keyUpHandler: { keyUpExpectation.fulfill() }
        )
        monitor.start()

        guard let flagsHandler = addedGlobalEvents.first?.1 else {
            XCTFail("Expected global flagsChanged handler")
            return
        }

        guard let keyDownEvent = makeFlagsChangedEvent(keyCode: 54, flags: [.command]),
              let keyUpEventWhileLeftHeld = makeFlagsChangedEvent(keyCode: 54, flags: [.command]) else {
            XCTFail("Failed to create synthetic modifier events")
            return
        }

        flagsHandler(keyDownEvent)
        flagsHandler(keyUpEventWhileLeftHeld)

        wait(for: [keyDownExpectation, keyUpExpectation], timeout: 1.0)
    }

    // MARK: - stop()

    func testStopRemovesRegisteredMonitors() {
        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold)
        )

        monitor.start()
        monitor.stop()

        XCTAssertEqual(removedEvents.count, 2)
    }
}
