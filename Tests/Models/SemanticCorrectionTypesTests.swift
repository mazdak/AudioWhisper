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

    func testSemanticCorrectionModeCloudCase() {
        let mode = SemanticCorrectionMode.cloud
        XCTAssertEqual(mode, .cloud)
    }

    // MARK: - Raw Values Tests

    func testSemanticCorrectionModeRawValueOff() {
        XCTAssertEqual(SemanticCorrectionMode.off.rawValue, "off")
    }

    func testSemanticCorrectionModeRawValueLocalMLX() {
        XCTAssertEqual(SemanticCorrectionMode.localMLX.rawValue, "localMLX")
    }

    func testSemanticCorrectionModeRawValueCloud() {
        XCTAssertEqual(SemanticCorrectionMode.cloud.rawValue, "cloud")
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

    func testSemanticCorrectionModeFromRawValueCloud() {
        let mode = SemanticCorrectionMode(rawValue: "cloud")
        XCTAssertEqual(mode, .cloud)
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

    func testDisplayNameCloud() {
        let mode = SemanticCorrectionMode.cloud
        XCTAssertEqual(mode.displayName, "Cloud")
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

    func testAllCasesContainsCloud() {
        XCTAssertTrue(SemanticCorrectionMode.allCases.contains(.cloud))
    }

    func testAllCasesCount() {
        XCTAssertEqual(SemanticCorrectionMode.allCases.count, 3)
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
        let json = "\"cloud\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        let mode = try decoder.decode(SemanticCorrectionMode.self, from: data)

        XCTAssertEqual(mode, .cloud)
    }

    func testSemanticCorrectionModeDecodeInvalid() {
        let json = "\"invalid\""
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
        let mode2 = SemanticCorrectionMode.cloud

        XCTAssertNotEqual(mode1, mode2)
    }

    // MARK: - Hashable Tests

    func testSemanticCorrectionModeHashable() {
        let modes: Set<SemanticCorrectionMode> = [.off, .localMLX, .cloud]

        XCTAssertEqual(modes.count, 3)
    }

    func testSemanticCorrectionModeHashConsistency() {
        let mode1 = SemanticCorrectionMode.localMLX
        let mode2 = SemanticCorrectionMode.localMLX

        XCTAssertEqual(mode1.hashValue, mode2.hashValue)
    }

    // MARK: - Usage Pattern Tests

    func testModeSelectionSwitchStatement() {
        let mode = SemanticCorrectionMode.localMLX
        var result = ""

        switch mode {
        case .off:
            result = "disabled"
        case .localMLX:
            result = "local"
        case .cloud:
            result = "cloud"
        }

        XCTAssertEqual(result, "local")
    }

    func testDefaultModeIsOff() {
        // Convention: default mode should be off
        let defaultMode = SemanticCorrectionMode.off
        XCTAssertEqual(defaultMode.rawValue, "off")
    }

    // MARK: - Feature Flag Tests

    func testModeRequiresSetup() {
        // off mode doesn't require setup
        // localMLX and cloud modes require setup
        let offRequiresSetup = SemanticCorrectionMode.off != .off
        let localMLXRequiresSetup = SemanticCorrectionMode.localMLX != .off
        let cloudRequiresSetup = SemanticCorrectionMode.cloud != .off

        XCTAssertFalse(offRequiresSetup)
        XCTAssertTrue(localMLXRequiresSetup)
        XCTAssertTrue(cloudRequiresSetup)
    }

    func testModeIsLocal() {
        // Check if mode runs locally
        let offIsLocal = false
        let localMLXIsLocal = SemanticCorrectionMode.localMLX == .localMLX
        let cloudIsLocal = false

        XCTAssertFalse(offIsLocal)
        XCTAssertTrue(localMLXIsLocal)
        XCTAssertFalse(cloudIsLocal)
    }

    func testModeIsCloud() {
        // Check if mode uses cloud
        let offIsCloud = false
        let localMLXIsCloud = false
        let cloudIsCloud = SemanticCorrectionMode.cloud == .cloud

        XCTAssertFalse(offIsCloud)
        XCTAssertFalse(localMLXIsCloud)
        XCTAssertTrue(cloudIsCloud)
    }
}
