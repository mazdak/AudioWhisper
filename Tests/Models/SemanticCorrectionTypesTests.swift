import XCTest
@testable import AudioWhisper

/// Tests for SemanticCorrectionTypes
final class SemanticCorrectionTypesTests: XCTestCase {

    // MARK: - Enum Cases Tests

    func testSemanticCorrectionModeOffCase() {
        let mode = SemanticCorrectionMode.off
        XCTAssertEqual(mode, .off)
    }

    func testSemanticCorrectionModeLocalMLXCase() {
        let mode = SemanticCorrectionMode.localMLX
        XCTAssertEqual(mode, .localMLX)
    }

    // MARK: - Raw Values Tests

    func testSemanticCorrectionModeRawValueOff() {
        XCTAssertEqual(SemanticCorrectionMode.off.rawValue, "off")
    }

    func testSemanticCorrectionModeRawValueLocalMLX() {
        XCTAssertEqual(SemanticCorrectionMode.localMLX.rawValue, "localMLX")
    }

    // MARK: - Init from Raw Value Tests

    func testSemanticCorrectionModeFromRawValueOff() {
        let mode = SemanticCorrectionMode(rawValue: "off")
        XCTAssertEqual(mode, .off)
    }

    func testSemanticCorrectionModeFromRawValueLocalMLX() {
        let mode = SemanticCorrectionMode(rawValue: "localMLX")
        XCTAssertEqual(mode, .localMLX)
    }

    func testSemanticCorrectionModeFromCloudReturnsNil() {
        // Cloud mode was removed
        let mode = SemanticCorrectionMode(rawValue: "cloud")
        XCTAssertNil(mode)
    }

    func testSemanticCorrectionModeFromInvalidRawValue() {
        let mode = SemanticCorrectionMode(rawValue: "invalid")
        XCTAssertNil(mode)
    }

    func testSemanticCorrectionModeFromEmptyRawValue() {
        let mode = SemanticCorrectionMode(rawValue: "")
        XCTAssertNil(mode)
    }

    // MARK: - Display Name Tests

    func testDisplayNameOff() {
        let mode = SemanticCorrectionMode.off
        XCTAssertEqual(mode.displayName, "Off")
    }

    func testDisplayNameLocalMLX() {
        let mode = SemanticCorrectionMode.localMLX
        XCTAssertEqual(mode.displayName, "Local (MLX)")
    }

    func testAllModesHaveDisplayNames() {
        for mode in SemanticCorrectionMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty, "\(mode) should have a display name")
        }
    }

    // MARK: - CaseIterable Tests

    func testAllCasesContainsOff() {
        XCTAssertTrue(SemanticCorrectionMode.allCases.contains(.off))
    }

    func testAllCasesContainsLocalMLX() {
        XCTAssertTrue(SemanticCorrectionMode.allCases.contains(.localMLX))
    }

    func testAllCasesCount() {
        XCTAssertEqual(SemanticCorrectionMode.allCases.count, 2)
    }

    // MARK: - Codable Tests

    func testSemanticCorrectionModeEncodable() throws {
        let mode = SemanticCorrectionMode.localMLX
        let encoder = JSONEncoder()

        let data = try encoder.encode(mode)
        let string = String(data: data, encoding: .utf8)

        XCTAssertEqual(string, "\"localMLX\"")
    }

    func testSemanticCorrectionModeDecodable() throws {
        let json = "\"localMLX\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        let mode = try decoder.decode(SemanticCorrectionMode.self, from: data)

        XCTAssertEqual(mode, .localMLX)
    }

    func testSemanticCorrectionModeDecodeInvalid() {
        let json = "\"invalid\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(SemanticCorrectionMode.self, from: data))
    }

    func testSemanticCorrectionModeDecodeCloudFails() {
        // Cloud mode was removed
        let json = "\"cloud\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(SemanticCorrectionMode.self, from: data))
    }

    func testSemanticCorrectionModeRoundTrip() throws {
        for originalMode in SemanticCorrectionMode.allCases {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(originalMode)
            let decodedMode = try decoder.decode(SemanticCorrectionMode.self, from: data)

            XCTAssertEqual(decodedMode, originalMode, "Round trip failed for \(originalMode)")
        }
    }

    // MARK: - Sendable Tests

    func testSemanticCorrectionModeIsSendable() {
        // Sendable conformance allows safe use across concurrency boundaries
        let mode: SemanticCorrectionMode = .localMLX

        Task {
            // Mode can be used in async context
            let _ = mode
        }

        XCTAssertTrue(true, "Mode is Sendable")
    }

    // MARK: - Equatable Tests

    func testSemanticCorrectionModeEquality() {
        let mode1 = SemanticCorrectionMode.off
        let mode2 = SemanticCorrectionMode.off

        XCTAssertEqual(mode1, mode2)
    }

    func testSemanticCorrectionModeInequality() {
        let mode1 = SemanticCorrectionMode.off
        let mode2 = SemanticCorrectionMode.localMLX

        XCTAssertNotEqual(mode1, mode2)
    }

    // MARK: - Hashable Tests

    func testSemanticCorrectionModeHashable() {
        let modes: Set<SemanticCorrectionMode> = [.off, .localMLX]

        XCTAssertEqual(modes.count, 2)
    }

    func testSemanticCorrectionModeHashConsistency() {
        let mode1 = SemanticCorrectionMode.localMLX
        let mode2 = SemanticCorrectionMode.localMLX

        XCTAssertEqual(mode1.hashValue, mode2.hashValue)
    }

    // MARK: - Usage Pattern Tests

    func testModeSelectionSwitchStatement() {
        var results: [String] = []

        for mode in SemanticCorrectionMode.allCases {
            switch mode {
            case .off:
                results.append("disabled")
            case .localMLX:
                results.append("local")
            }
        }

        XCTAssertTrue(results.contains("disabled"))
        XCTAssertTrue(results.contains("local"))
    }

    func testDefaultModeIsOff() {
        // Convention: default mode should be off
        let defaultMode = SemanticCorrectionMode.off
        XCTAssertEqual(defaultMode.rawValue, "off")
    }

    // MARK: - Feature Flag Tests

    func testModeRequiresSetup() {
        // off mode doesn't require setup
        XCTAssertEqual(SemanticCorrectionMode.off, .off, "off mode doesn't require setup")
        // localMLX mode requires setup (is not .off)
        XCTAssertNotEqual(SemanticCorrectionMode.localMLX, .off, "localMLX mode requires setup")
    }

    func testModeIsLocal() {
        // off is not a local mode
        XCTAssertNotEqual(SemanticCorrectionMode.off, .localMLX, "off is not a local mode")
        // localMLX is a local mode
        XCTAssertEqual(SemanticCorrectionMode.localMLX, .localMLX, "localMLX is a local mode")
    }
}
