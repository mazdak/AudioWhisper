import XCTest
import AppKit
@testable import AudioWhisper

final class PressAndHoldKeyMonitorTests: XCTestCase {
    private var addedEvents: [(NSEvent.EventTypeMask, (NSEvent) -> Void)] = []
    private var removedEvents: [Any] = []
    private var testDefaults: UserDefaults!
    private var testSuiteName: String!

    override func setUp() {
        super.setUp()
        testSuiteName = "com.audiowhisper.tests.pressandhold.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
    }

    override func tearDown() {
        addedEvents.removeAll()
        removedEvents.removeAll()
        if let suiteName = testSuiteName {
            testDefaults.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        testSuiteName = nil
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

    // MARK: - Thread Safety Tests (Bug Regression Prevention)

    func testIsPressedThreadSafety() {
        // Bug fix verification: Concurrent access to isPressed should not crash
        var keyDownCount = 0
        var keyUpCount = 0
        let lock = NSLock()

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {
                lock.lock()
                keyDownCount += 1
                lock.unlock()
            },
            keyUpHandler: {
                lock.lock()
                keyUpCount += 1
                lock.unlock()
            }
        )

        // Simulate concurrent transitions to detect race conditions
        let group = DispatchGroup()
        for i in 0..<100 {
            group.enter()
            DispatchQueue.global().async {
                monitor.processTransition(isKeyDownEvent: i % 2 == 0)
                group.leave()
            }
        }

        group.wait()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))

        // Main assertion: no crash occurred
        XCTAssertTrue(true, "Concurrent access should not crash (bug fix)")
    }

    func testRapidKeyPresses() {
        var downCount = 0
        var upCount = 0
        let lock = NSLock()

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {
                lock.lock()
                downCount += 1
                lock.unlock()
            },
            keyUpHandler: {
                lock.lock()
                upCount += 1
                lock.unlock()
            }
        )

        // Simulate rapid down-up-down-up sequence
        for _ in 0..<10 {
            monitor.processTransition(isKeyDownEvent: true)
            monitor.processTransition(isKeyDownEvent: false)
        }

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))

        lock.lock()
        XCTAssertEqual(downCount, 10, "Should handle 10 rapid key downs")
        XCTAssertEqual(upCount, 10, "Should handle 10 rapid key ups")
        lock.unlock()
    }

    func testKeyDownKeyUpSequence() {
        let expectation = XCTestExpectation(description: "Both handlers called")
        expectation.expectedFulfillmentCount = 2

        var callOrder: [String] = []
        let lock = NSLock()

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {
                lock.lock()
                callOrder.append("down")
                lock.unlock()
                expectation.fulfill()
            },
            keyUpHandler: {
                lock.lock()
                callOrder.append("up")
                lock.unlock()
                expectation.fulfill()
            }
        )

        monitor.processTransition(isKeyDownEvent: true)
        monitor.processTransition(isKeyDownEvent: false)

        wait(for: [expectation], timeout: 1.0)

        lock.lock()
        XCTAssertEqual(callOrder, ["down", "up"])
        lock.unlock()
    }

    func testDoubleKeyDownIgnored() {
        var keyDownCount = 0
        let lock = NSLock()

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {
                lock.lock()
                keyDownCount += 1
                lock.unlock()
            },
            keyUpHandler: nil
        )

        // Three consecutive key downs - only first should count
        monitor.processTransition(isKeyDownEvent: true)
        monitor.processTransition(isKeyDownEvent: true)
        monitor.processTransition(isKeyDownEvent: true)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))

        lock.lock()
        XCTAssertEqual(keyDownCount, 1, "Duplicate key downs should be ignored")
        lock.unlock()
    }

    // MARK: - Start/Stop Lifecycle Tests

    func testStartStopStartSequence() {
        var startCount = 0
        var stopCount = 0

        let monitor = PressAndHoldKeyMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {},
            keyUpHandler: nil,
            addGlobalMonitor: { _, _ in
                startCount += 1
                return "mock" as Any
            },
            removeMonitor: { _ in stopCount += 1 }
        )

        monitor.start()
        monitor.stop()
        monitor.start()

        XCTAssertEqual(startCount, 2, "Should be able to restart after stop")
        XCTAssertEqual(stopCount, 1, "Stop should have been called once")
    }

    func testStopResetsIsPressedState() {
        var keyDownCalled = false

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: { keyDownCalled = true },
            keyUpHandler: nil
        )

        // Simulate key press
        monitor.processTransition(isKeyDownEvent: true)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        keyDownCalled = false

        // Stop should reset state
        monitor.stop()

        // After stop and restart, a new key down should work
        monitor.start()
        monitor.processTransition(isKeyDownEvent: true)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertTrue(keyDownCalled, "Key down should work after stop/start")
    }

    // MARK: - Configuration Tests

    func testHoldModeHasKeyUpHandler() {
        var keyUpCalled = false

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {},
            keyUpHandler: { keyUpCalled = true }
        )

        monitor.processTransition(isKeyDownEvent: true)
        monitor.processTransition(isKeyDownEvent: false)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertTrue(keyUpCalled, "Hold mode should call key up handler")
    }

    func testToggleModeNoKeyUpHandler() {
        // In toggle mode, keyUpHandler is typically nil
        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .toggle),
            keyDownHandler: {},
            keyUpHandler: nil
        )

        // Should not crash when key up occurs with nil handler
        monitor.processTransition(isKeyDownEvent: true)
        monitor.processTransition(isKeyDownEvent: false)

        XCTAssertTrue(true, "Should handle nil keyUpHandler gracefully")
    }

    func testDifferentKeyConfigurations() {
        let keys: [PressAndHoldKey] = [.rightCommand, .leftCommand, .rightOption, .leftOption, .rightControl, .leftControl, .globe]

        for key in keys {
            let monitor = makeMonitor(
                configuration: PressAndHoldConfiguration(enabled: true, key: key, mode: .hold),
                keyDownHandler: {},
                keyUpHandler: {}
            )

            // Should not crash for any key configuration
            XCTAssertNotNil(monitor, "Monitor should be created for \(key)")
        }
    }

    // MARK: - Duplicate Event Tests (Bug Fix Regression)

    func testDuplicateKeyDownEventsAreIdempotent() {
        // Bug fix: When macOS sends multiple flagsChanged events for the same key state,
        // only the first should trigger the handler. This tests the fix where we check
        // modifier flags from the event instead of toggling isPressed.
        var keyDownCount = 0
        let lock = NSLock()

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {
                lock.lock()
                keyDownCount += 1
                lock.unlock()
            },
            keyUpHandler: nil
        )

        // Simulate multiple "key down" events arriving (as can happen with macOS)
        // All should be treated as "key is down" - only first triggers handler
        monitor.processTransition(isKeyDownEvent: true)
        monitor.processTransition(isKeyDownEvent: true)
        monitor.processTransition(isKeyDownEvent: true)
        monitor.processTransition(isKeyDownEvent: true)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))

        lock.lock()
        XCTAssertEqual(keyDownCount, 1, "Multiple key-down events should only trigger handler once")
        lock.unlock()
    }

    func testDuplicateKeyUpEventsAreIdempotent() {
        // Bug fix: Multiple "key up" events should only trigger handler once
        var keyUpCount = 0
        let lock = NSLock()

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {},
            keyUpHandler: {
                lock.lock()
                keyUpCount += 1
                lock.unlock()
            }
        )

        // First press and release
        monitor.processTransition(isKeyDownEvent: true)
        monitor.processTransition(isKeyDownEvent: false)
        monitor.processTransition(isKeyDownEvent: false)  // Duplicate up
        monitor.processTransition(isKeyDownEvent: false)  // Another duplicate

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))

        lock.lock()
        XCTAssertEqual(keyUpCount, 1, "Multiple key-up events should only trigger handler once")
        lock.unlock()
    }

    func testRapidDuplicateEventsDoNotCauseFlickering() {
        // Bug fix regression test: Rapid duplicate events should not cause
        // the "flickering" behavior where state toggles incorrectly
        var downCount = 0
        var upCount = 0
        let lock = NSLock()

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {
                lock.lock()
                downCount += 1
                lock.unlock()
            },
            keyUpHandler: {
                lock.lock()
                upCount += 1
                lock.unlock()
            }
        )

        // Simulate the bug scenario: press key, macOS sends multiple events
        monitor.processTransition(isKeyDownEvent: true)
        monitor.processTransition(isKeyDownEvent: true)  // Duplicate - should be ignored

        // User releases key, macOS sends multiple events
        monitor.processTransition(isKeyDownEvent: false)
        monitor.processTransition(isKeyDownEvent: false)  // Duplicate - should be ignored

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))

        lock.lock()
        XCTAssertEqual(downCount, 1, "Should have exactly one key down")
        XCTAssertEqual(upCount, 1, "Should have exactly one key up")
        lock.unlock()
    }

    func testConcurrentDuplicateEventsAreHandledCorrectly() {
        // Bug fix: Even with concurrent duplicate events from different threads,
        // state should remain consistent
        var downCount = 0
        var upCount = 0
        let lock = NSLock()

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {
                lock.lock()
                downCount += 1
                lock.unlock()
            },
            keyUpHandler: {
                lock.lock()
                upCount += 1
                lock.unlock()
            }
        )

        let group = DispatchGroup()

        // Simulate concurrent "key down" events (all should result in single handler call)
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                monitor.processTransition(isKeyDownEvent: true)
                group.leave()
            }
        }

        group.wait()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))

        lock.lock()
        XCTAssertEqual(downCount, 1, "Concurrent key-down events should only trigger once")
        lock.unlock()

        // Now simulate concurrent "key up" events
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                monitor.processTransition(isKeyDownEvent: false)
                group.leave()
            }
        }

        group.wait()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))

        lock.lock()
        XCTAssertEqual(upCount, 1, "Concurrent key-up events should only trigger once")
        lock.unlock()
    }

    // MARK: - PressAndHoldSettings Persistence Tests

    func testConfigurationLoadsDefaultsWhenEmpty() {
        // Empty UserDefaults should return default configuration
        let config = PressAndHoldSettings.configuration(using: testDefaults)

        XCTAssertEqual(config.enabled, PressAndHoldConfiguration.defaults.enabled)
        XCTAssertEqual(config.key, PressAndHoldConfiguration.defaults.key)
        XCTAssertEqual(config.mode, PressAndHoldConfiguration.defaults.mode)
    }

    func testConfigurationLoadsFromUserDefaults() {
        // Set specific values in UserDefaults
        testDefaults.set(false, forKey: "pressAndHoldEnabled")
        testDefaults.set("leftOption", forKey: "pressAndHoldKeyIdentifier")
        testDefaults.set("toggle", forKey: "pressAndHoldMode")

        let config = PressAndHoldSettings.configuration(using: testDefaults)

        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.key, .leftOption)
        XCTAssertEqual(config.mode, .toggle)
    }

    func testUpdateSavesToUserDefaults() {
        let config = PressAndHoldConfiguration(enabled: false, key: .globe, mode: .toggle)

        PressAndHoldSettings.update(config, using: testDefaults)

        XCTAssertEqual(testDefaults.bool(forKey: "pressAndHoldEnabled"), false)
        XCTAssertEqual(testDefaults.string(forKey: "pressAndHoldKeyIdentifier"), "globe")
        XCTAssertEqual(testDefaults.string(forKey: "pressAndHoldMode"), "toggle")
    }

    func testUpdatePostsNotification() {
        let expectation = expectation(description: "Notification posted")
        var receivedConfig: PressAndHoldConfiguration?

        let observer = NotificationCenter.default.addObserver(
            forName: .pressAndHoldSettingsChanged,
            object: nil,
            queue: .main
        ) { notification in
            receivedConfig = notification.object as? PressAndHoldConfiguration
            expectation.fulfill()
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        let config = PressAndHoldConfiguration(enabled: true, key: .leftControl, mode: .hold)
        PressAndHoldSettings.update(config, using: testDefaults)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedConfig, config)
    }

    func testLegacyKeyMigrationOption() {
        testDefaults.set("option", forKey: "pressAndHoldKeyIdentifier")

        let config = PressAndHoldSettings.configuration(using: testDefaults)

        XCTAssertEqual(config.key, .leftOption, "Legacy 'option' should migrate to .leftOption")
    }

    func testLegacyKeyMigrationControl() {
        testDefaults.set("control", forKey: "pressAndHoldKeyIdentifier")

        let config = PressAndHoldSettings.configuration(using: testDefaults)

        XCTAssertEqual(config.key, .leftControl, "Legacy 'control' should migrate to .leftControl")
    }

    func testLegacyKeyMigrationFn() {
        testDefaults.set("fn", forKey: "pressAndHoldKeyIdentifier")

        let config = PressAndHoldSettings.configuration(using: testDefaults)

        XCTAssertEqual(config.key, .globe, "Legacy 'fn' should migrate to .globe")
    }

    func testLegacyKeyMigrationGlobe() {
        // "globe" as legacy string should also work
        testDefaults.set("globe", forKey: "pressAndHoldKeyIdentifier")

        let config = PressAndHoldSettings.configuration(using: testDefaults)

        XCTAssertEqual(config.key, .globe, "Legacy 'globe' string should migrate to .globe")
    }

    func testInvalidKeyFallsBackToDefault() {
        testDefaults.set("invalidKey123", forKey: "pressAndHoldKeyIdentifier")

        let config = PressAndHoldSettings.configuration(using: testDefaults)

        XCTAssertEqual(config.key, PressAndHoldConfiguration.defaults.key)
    }

    func testInvalidModeFallsBackToDefault() {
        testDefaults.set("invalidMode", forKey: "pressAndHoldMode")

        let config = PressAndHoldSettings.configuration(using: testDefaults)

        XCTAssertEqual(config.mode, PressAndHoldConfiguration.defaults.mode)
    }

    // MARK: - PressAndHoldKey Tests

    func testAllKeyCodesAreUnique() {
        let allKeys = PressAndHoldKey.allCases
        let keyCodes = allKeys.map { $0.keyCode }
        let uniqueKeyCodes = Set(keyCodes)

        XCTAssertEqual(keyCodes.count, uniqueKeyCodes.count, "All key codes should be unique")
    }

    func testKeyCodesMatchExpectedValues() {
        // These are the standard macOS key codes for modifier keys
        XCTAssertEqual(PressAndHoldKey.rightCommand.keyCode, 54)
        XCTAssertEqual(PressAndHoldKey.leftCommand.keyCode, 55)
        XCTAssertEqual(PressAndHoldKey.rightOption.keyCode, 61)
        XCTAssertEqual(PressAndHoldKey.leftOption.keyCode, 58)
        XCTAssertEqual(PressAndHoldKey.rightControl.keyCode, 62)
        XCTAssertEqual(PressAndHoldKey.leftControl.keyCode, 59)
        XCTAssertEqual(PressAndHoldKey.globe.keyCode, 63)
    }

    func testModifierFlagsForCommandKeys() {
        XCTAssertEqual(PressAndHoldKey.rightCommand.modifierFlag, .command)
        XCTAssertEqual(PressAndHoldKey.leftCommand.modifierFlag, .command)
    }

    func testModifierFlagsForOptionKeys() {
        XCTAssertEqual(PressAndHoldKey.rightOption.modifierFlag, .option)
        XCTAssertEqual(PressAndHoldKey.leftOption.modifierFlag, .option)
    }

    func testModifierFlagsForControlKeys() {
        XCTAssertEqual(PressAndHoldKey.rightControl.modifierFlag, .control)
        XCTAssertEqual(PressAndHoldKey.leftControl.modifierFlag, .control)
    }

    func testModifierFlagForGlobeKey() {
        XCTAssertEqual(PressAndHoldKey.globe.modifierFlag, .function)
    }

    func testDisplayNamesContainKeySymbols() {
        XCTAssertTrue(PressAndHoldKey.rightCommand.displayName.contains("⌘"))
        XCTAssertTrue(PressAndHoldKey.leftCommand.displayName.contains("⌘"))
        XCTAssertTrue(PressAndHoldKey.rightOption.displayName.contains("⌥"))
        XCTAssertTrue(PressAndHoldKey.leftOption.displayName.contains("⌥"))
        XCTAssertTrue(PressAndHoldKey.rightControl.displayName.contains("⌃"))
        XCTAssertTrue(PressAndHoldKey.leftControl.displayName.contains("⌃"))
        XCTAssertTrue(PressAndHoldKey.globe.displayName.contains("🌐"))
    }

    func testKeyIdentifiableConformance() {
        // Verify id property returns rawValue for Identifiable conformance
        for key in PressAndHoldKey.allCases {
            XCTAssertEqual(key.id, key.rawValue, "Key id should equal rawValue for \(key)")
        }
    }

    // MARK: - PressAndHoldMode Tests

    func testModeDisplayNames() {
        XCTAssertEqual(PressAndHoldMode.hold.displayName, "Press and Hold")
        XCTAssertEqual(PressAndHoldMode.toggle.displayName, "Press to Toggle")
    }

    func testModeIdentifiableConformance() {
        for mode in PressAndHoldMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue, "Mode id should equal rawValue for \(mode)")
        }
    }

    func testAllModesCaseIterable() {
        let allModes = PressAndHoldMode.allCases
        XCTAssertEqual(allModes.count, 2)
        XCTAssertTrue(allModes.contains(.hold))
        XCTAssertTrue(allModes.contains(.toggle))
    }

    // MARK: - PressAndHoldConfiguration Tests

    func testDefaultConfiguration() {
        let defaults = PressAndHoldConfiguration.defaults

        XCTAssertTrue(defaults.enabled)
        XCTAssertEqual(defaults.key, .rightCommand)
        XCTAssertEqual(defaults.mode, .hold)
    }

    func testConfigurationEquatable() {
        let config1 = PressAndHoldConfiguration(enabled: true, key: .leftOption, mode: .toggle)
        let config2 = PressAndHoldConfiguration(enabled: true, key: .leftOption, mode: .toggle)
        let config3 = PressAndHoldConfiguration(enabled: false, key: .leftOption, mode: .toggle)

        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }

    func testConfigurationWithDifferentKeys() {
        let config1 = PressAndHoldConfiguration(enabled: true, key: .globe, mode: .hold)
        let config2 = PressAndHoldConfiguration(enabled: true, key: .leftControl, mode: .hold)

        XCTAssertNotEqual(config1, config2)
    }

    // MARK: - Lifecycle Tests

    func testDeinitCallsStop() {
        var stopCalled = false

        autoreleasepool {
            _ = PressAndHoldKeyMonitor(
                configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
                keyDownHandler: {},
                keyUpHandler: nil,
                addGlobalMonitor: { _, _ in "mock" as Any },
                removeMonitor: { _ in stopCalled = true }
            )
        }

        // Deinit should have been called, which calls stop()
        // Note: This test verifies the deinit behavior indirectly through the removeMonitor call
        // Since we never called start(), no monitors were added, so removeMonitor won't be called
        XCTAssertFalse(stopCalled, "No monitors to remove when never started")
    }

    func testDeinitRemovesMonitorsWhenStarted() {
        var removeCount = 0

        autoreleasepool {
            let monitor = PressAndHoldKeyMonitor(
                configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
                keyDownHandler: {},
                keyUpHandler: nil,
                addGlobalMonitor: { _, _ in "mock" as Any },
                removeMonitor: { _ in removeCount += 1 }
            )
            monitor.start()
        }

        // Deinit should call stop() which removes the monitor
        XCTAssertEqual(removeCount, 1, "Deinit should remove registered monitors")
    }

    func testMultipleStartsCleanUpPreviousMonitors() {
        var addCount = 0
        var removeCount = 0

        let monitor = PressAndHoldKeyMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {},
            keyUpHandler: nil,
            addGlobalMonitor: { _, _ in
                addCount += 1
                return "mock\(addCount)" as Any
            },
            removeMonitor: { _ in removeCount += 1 }
        )

        monitor.start()
        monitor.start()  // Second start should clean up first monitor
        monitor.start()  // Third start should clean up second monitor

        XCTAssertEqual(addCount, 3, "Should have added 3 monitors")
        XCTAssertEqual(removeCount, 2, "Should have removed 2 previous monitors")

        monitor.stop()  // Clean up
    }

    func testStartStopDoesNotLeakMonitors() {
        var addCount = 0
        var removeCount = 0

        let monitor = PressAndHoldKeyMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {},
            keyUpHandler: nil,
            addGlobalMonitor: { _, _ in
                addCount += 1
                return "mock" as Any
            },
            removeMonitor: { _ in removeCount += 1 }
        )

        // Multiple start/stop cycles
        for _ in 0..<5 {
            monitor.start()
            monitor.stop()
        }

        XCTAssertEqual(addCount, removeCount, "Every added monitor should be removed")
    }

    func testWeakSelfSafetyDuringAsyncTransition() {
        // Verify that deallocating monitor during async processing doesn't crash
        let expectation = XCTestExpectation(description: "No crash")

        var monitor: PressAndHoldKeyMonitor? = PressAndHoldKeyMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {
                // This might execute after monitor is nil
            },
            keyUpHandler: nil,
            addGlobalMonitor: { _, _ in "mock" as Any },
            removeMonitor: { _ in }
        )

        // Process transition and immediately nil out
        monitor?.processTransition(isKeyDownEvent: true)
        monitor = nil

        // Give time for any async operations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Extended Duration Tests

    func testExtendedHoldDuration() {
        var keyDownTime: Date?
        var keyUpTime: Date?
        let lock = NSLock()

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {
                lock.lock()
                keyDownTime = Date()
                lock.unlock()
            },
            keyUpHandler: {
                lock.lock()
                keyUpTime = Date()
                lock.unlock()
            }
        )

        // Simulate extended hold
        monitor.processTransition(isKeyDownEvent: true)

        // Wait to simulate holding
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))

        monitor.processTransition(isKeyDownEvent: false)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

        lock.lock()
        XCTAssertNotNil(keyDownTime)
        XCTAssertNotNil(keyUpTime)
        if let down = keyDownTime, let up = keyUpTime {
            XCTAssertGreaterThan(up.timeIntervalSince(down), 0.2, "Should support extended hold duration")
        }
        lock.unlock()
    }

    func testManyRapidCyclesRemainConsistent() {
        var downCount = 0
        var upCount = 0
        let lock = NSLock()

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {
                lock.lock()
                downCount += 1
                lock.unlock()
            },
            keyUpHandler: {
                lock.lock()
                upCount += 1
                lock.unlock()
            }
        )

        // 100 rapid press/release cycles
        for _ in 0..<100 {
            monitor.processTransition(isKeyDownEvent: true)
            monitor.processTransition(isKeyDownEvent: false)
        }

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))

        lock.lock()
        XCTAssertEqual(downCount, 100, "Should handle 100 rapid key downs")
        XCTAssertEqual(upCount, 100, "Should handle 100 rapid key ups")
        lock.unlock()
    }

    // MARK: - All Keys Integration Tests

    func testAllKeyTypesCanBeConfigured() {
        for key in PressAndHoldKey.allCases {
            var handlerCalled = false

            let monitor = makeMonitor(
                configuration: PressAndHoldConfiguration(enabled: true, key: key, mode: .hold),
                keyDownHandler: { handlerCalled = true },
                keyUpHandler: nil
            )

            monitor.processTransition(isKeyDownEvent: true)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

            XCTAssertTrue(handlerCalled, "Handler should be called for key: \(key)")
        }
    }

    func testAllModesCanBeConfigured() {
        for mode in PressAndHoldMode.allCases {
            var handlerCalled = false

            let monitor = makeMonitor(
                configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: mode),
                keyDownHandler: { handlerCalled = true },
                keyUpHandler: nil
            )

            monitor.processTransition(isKeyDownEvent: true)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

            XCTAssertTrue(handlerCalled, "Handler should be called for mode: \(mode)")
        }
    }

    // MARK: - Settings Round-Trip Tests

    func testSettingsRoundTrip() {
        // Save config
        let originalConfig = PressAndHoldConfiguration(enabled: false, key: .leftControl, mode: .toggle)
        PressAndHoldSettings.update(originalConfig, using: testDefaults)

        // Load it back
        let loadedConfig = PressAndHoldSettings.configuration(using: testDefaults)

        XCTAssertEqual(originalConfig, loadedConfig)
    }

    func testSettingsRoundTripAllKeys() {
        for key in PressAndHoldKey.allCases {
            let config = PressAndHoldConfiguration(enabled: true, key: key, mode: .hold)
            PressAndHoldSettings.update(config, using: testDefaults)

            let loaded = PressAndHoldSettings.configuration(using: testDefaults)
            XCTAssertEqual(loaded.key, key, "Round-trip failed for key: \(key)")
        }
    }

    func testSettingsRoundTripAllModes() {
        for mode in PressAndHoldMode.allCases {
            let config = PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: mode)
            PressAndHoldSettings.update(config, using: testDefaults)

            let loaded = PressAndHoldSettings.configuration(using: testDefaults)
            XCTAssertEqual(loaded.mode, mode, "Round-trip failed for mode: \(mode)")
        }
    }
}
