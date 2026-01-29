import XCTest
@testable import AudioWhisper

final class DashboardRecordingViewTests: XCTestCase {

    // MARK: - Press and Hold Mode Parsing

    func testPressAndHoldModeFromValidValues() {
        for mode in PressAndHoldMode.allCases {
            XCTAssertEqual(
                DashboardRecordingView.testablePressAndHoldMode(from: mode.rawValue),
                mode
            )
        }
    }

    func testPressAndHoldModeFromInvalidValue() {
        let defaultMode = PressAndHoldConfiguration.defaults.mode
        XCTAssertEqual(DashboardRecordingView.testablePressAndHoldMode(from: "invalid"), defaultMode)
        XCTAssertEqual(DashboardRecordingView.testablePressAndHoldMode(from: ""), defaultMode)
    }

    // MARK: - Press and Hold Key Parsing

    func testPressAndHoldKeyFromValidValues() {
        for key in PressAndHoldKey.allCases {
            XCTAssertEqual(
                DashboardRecordingView.testablePressAndHoldKey(from: key.rawValue),
                key
            )
        }
    }

    func testPressAndHoldKeyFromInvalidValue() {
        let defaultKey = PressAndHoldConfiguration.defaults.key
        XCTAssertEqual(DashboardRecordingView.testablePressAndHoldKey(from: "invalid"), defaultKey)
        XCTAssertEqual(DashboardRecordingView.testablePressAndHoldKey(from: ""), defaultKey)
    }

    // MARK: - Press and Hold Properties

    func testAllPressAndHoldModesHaveDisplayNames() {
        for mode in PressAndHoldMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty, "Press and hold mode \(mode) should have a display name")
        }
    }

    func testAllPressAndHoldKeysHaveDisplayNames() {
        for key in PressAndHoldKey.allCases {
            XCTAssertFalse(key.displayName.isEmpty, "Press and hold key \(key) should have a display name")
        }
    }
}
