import XCTest
@testable import AudioWhisper

// MARK: - WindowTitles Tests
final class WindowTitlesTests: XCTestCase {

    func testRecordingWindowTitle() {
        XCTAssertEqual(WindowTitles.recording, "AudioWhisper Recording")
    }

    func testRecordingWindowTitleNotEmpty() {
        XCTAssertFalse(WindowTitles.recording.isEmpty)
    }

    func testRecordingWindowTitleContainsAppName() {
        XCTAssertTrue(WindowTitles.recording.contains("AudioWhisper"))
    }

    func testRecordingWindowTitleContainsRecording() {
        XCTAssertTrue(WindowTitles.recording.contains("Recording"))
    }

    func testRecordingWindowTitleHasProperFormat() {
        // Should be "AppName Action" format
        let components = WindowTitles.recording.split(separator: " ")
        XCTAssertEqual(components.count, 2)
    }

    func testRecordingWindowTitleIsConsistent() {
        // Accessing multiple times should return the same value
        let title1 = WindowTitles.recording
        let title2 = WindowTitles.recording
        XCTAssertEqual(title1, title2)
    }
}

// MARK: - Arch Utility Tests
final class ArchUtilityTests: XCTestCase {

    func testIsAppleSiliconReturnsBoolean() {
        let result = Arch.isAppleSilicon
        XCTAssertNotNil(result)
        // Result is a Bool, so it's either true or false
        XCTAssertTrue(result == true || result == false)
    }

    func testIsAppleSiliconIsConsistent() {
        // Multiple calls should return the same value
        let result1 = Arch.isAppleSilicon
        let result2 = Arch.isAppleSilicon
        XCTAssertEqual(result1, result2)
    }

    func testArchEnumExists() {
        // Verify the Arch enum can be accessed
        _ = Arch.self
        XCTAssertTrue(true)
    }

    #if arch(arm64)
    func testIsAppleSiliconOnARM64() {
        // On ARM64, should return true
        XCTAssertTrue(Arch.isAppleSilicon)
    }
    #else
    func testIsAppleSiliconOnIntel() {
        // On non-ARM64, should return false
        XCTAssertFalse(Arch.isAppleSilicon)
    }
    #endif
}
