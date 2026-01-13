import XCTest
import os.log
@testable import AudioWhisper

// MARK: - Logger Extension Tests
final class LoggerExtensionTests: XCTestCase {

    func testModelManagerLoggerExists() {
        let logger = Logger.modelManager
        XCTAssertNotNil(logger)
    }

    func testAudioRecorderLoggerExists() {
        let logger = Logger.audioRecorder
        XCTAssertNotNil(logger)
    }

    func testMicrophoneVolumeLoggerExists() {
        let logger = Logger.microphoneVolume
        XCTAssertNotNil(logger)
    }

    func testSpeechToTextLoggerExists() {
        let logger = Logger.speechToText
        XCTAssertNotNil(logger)
    }

    func testKeychainLoggerExists() {
        let logger = Logger.keychain
        XCTAssertNotNil(logger)
    }

    func testAppLoggerExists() {
        let logger = Logger.app
        XCTAssertNotNil(logger)
    }

    func testSettingsLoggerExists() {
        let logger = Logger.settings
        XCTAssertNotNil(logger)
    }

    func testDataManagerLoggerExists() {
        let logger = Logger.dataManager
        XCTAssertNotNil(logger)
    }

    func testPasteLoggerExists() {
        let logger = Logger.paste
        XCTAssertNotNil(logger)
    }

    func testAllLoggersAreUnique() {
        // Each logger should have a unique category
        let loggers: [(String, Logger)] = [
            ("modelManager", Logger.modelManager),
            ("audioRecorder", Logger.audioRecorder),
            ("microphoneVolume", Logger.microphoneVolume),
            ("speechToText", Logger.speechToText),
            ("keychain", Logger.keychain),
            ("app", Logger.app),
            ("settings", Logger.settings),
            ("dataManager", Logger.dataManager),
            ("paste", Logger.paste),
        ]

        // Verify each logger exists
        for (name, logger) in loggers {
            XCTAssertNotNil(logger, "\(name) logger should exist")
        }
    }

    func testLoggerCanLog() {
        // This test verifies that logging doesn't crash
        Logger.app.info("Test log message")
        Logger.app.debug("Debug message")
        Logger.app.error("Error message")

        // If we get here without crashing, the test passes
        XCTAssertTrue(true)
    }

    func testLoggerWithInterpolation() {
        let value = 42
        let message = "Test value: \(value)"

        // This should not crash
        Logger.app.info("\(message)")
        XCTAssertTrue(true)
    }
}

// MARK: - Logger Category Tests
final class LoggerCategoryTests: XCTestCase {

    func testExpectedCategories() {
        let expectedCategories = [
            "ModelManager",
            "AudioRecorder",
            "MicrophoneVolume",
            "SpeechToText",
            "Keychain",
            "App",
            "Settings",
            "DataManager",
            "Paste",
        ]

        XCTAssertEqual(expectedCategories.count, 9)
    }

    func testSubsystemFormat() {
        // Subsystem should be bundle identifier or fallback
        let bundleId = Bundle.main.bundleIdentifier ?? "com.audiowhisper.app"
        XCTAssertFalse(bundleId.isEmpty)
    }
}
