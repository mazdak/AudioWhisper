import XCTest
@testable import AudioWhisper

final class WaveformStyleTests: XCTestCase {
    private let testDefaultsKey = "waveformStyle"

    override func setUp() {
        super.setUp()
        // Ensure clean state before each test
        UserDefaults.standard.removeObject(forKey: testDefaultsKey)
    }

    override func tearDown() {
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: testDefaultsKey)
        super.tearDown()
    }

    // MARK: - Enum Tests

    func testAllCasesExist() {
        let allCases = WaveformStyle.allCases
        XCTAssertEqual(allCases.count, 6)
        XCTAssertTrue(allCases.contains(.classic))
        XCTAssertTrue(allCases.contains(.neon))
        XCTAssertTrue(allCases.contains(.spectrum))
        XCTAssertTrue(allCases.contains(.circular))
        XCTAssertTrue(allCases.contains(.pulseRings))
        XCTAssertTrue(allCases.contains(.particles))
    }

    func testRawValues() {
        XCTAssertEqual(WaveformStyle.classic.rawValue, "Classic")
        XCTAssertEqual(WaveformStyle.neon.rawValue, "Neon")
        XCTAssertEqual(WaveformStyle.spectrum.rawValue, "Spectrum")
        XCTAssertEqual(WaveformStyle.circular.rawValue, "Circular")
        XCTAssertEqual(WaveformStyle.pulseRings.rawValue, "Pulse Rings")
        XCTAssertEqual(WaveformStyle.particles.rawValue, "Particles")
    }

    func testIdentifiable() {
        XCTAssertEqual(WaveformStyle.classic.id, "Classic")
        XCTAssertEqual(WaveformStyle.neon.id, "Neon")
        XCTAssertEqual(WaveformStyle.spectrum.id, "Spectrum")
        XCTAssertEqual(WaveformStyle.circular.id, "Circular")
        XCTAssertEqual(WaveformStyle.pulseRings.id, "Pulse Rings")
        XCTAssertEqual(WaveformStyle.particles.id, "Particles")
    }

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for style in WaveformStyle.allCases {
            let data = try encoder.encode(style)
            let decoded = try decoder.decode(WaveformStyle.self, from: data)
            XCTAssertEqual(decoded, style)
        }
    }

    // MARK: - Description Tests

    func testDescriptions() {
        XCTAssertFalse(WaveformStyle.classic.description.isEmpty)
        XCTAssertFalse(WaveformStyle.neon.description.isEmpty)
        XCTAssertFalse(WaveformStyle.spectrum.description.isEmpty)

        // Each style should have a unique description
        let descriptions = WaveformStyle.allCases.map { $0.description }
        let uniqueDescriptions = Set(descriptions)
        XCTAssertEqual(descriptions.count, uniqueDescriptions.count, "Each style should have a unique description")
    }

    // MARK: - RequiresEnhancedAudio Tests

    func testClassicDoesNotRequireEnhancedAudio() {
        XCTAssertFalse(WaveformStyle.classic.requiresEnhancedAudio)
    }

    func testNeonRequiresEnhancedAudio() {
        XCTAssertTrue(WaveformStyle.neon.requiresEnhancedAudio)
    }

    func testSpectrumRequiresEnhancedAudio() {
        XCTAssertTrue(WaveformStyle.spectrum.requiresEnhancedAudio)
    }

    func testCircularRequiresEnhancedAudio() {
        XCTAssertTrue(WaveformStyle.circular.requiresEnhancedAudio)
    }

    func testPulseRingsDoesNotRequireEnhancedAudio() {
        // PulseRings only needs audioLevel, not FFT data
        XCTAssertFalse(WaveformStyle.pulseRings.requiresEnhancedAudio)
    }

    func testParticlesRequiresEnhancedAudio() {
        XCTAssertTrue(WaveformStyle.particles.requiresEnhancedAudio)
    }

    // MARK: - UserDefaults Extension Tests

    func testDefaultStyleIsClassic() {
        // setUp already clears the value, so no need to remove it again
        let style = UserDefaults.standard.waveformStyle
        XCTAssertEqual(style, .classic, "Default style should be Classic")
    }

    func testSetAndGetStyle() {
        for style in WaveformStyle.allCases {
            UserDefaults.standard.waveformStyle = style
            XCTAssertEqual(UserDefaults.standard.waveformStyle, style)
        }
    }

    func testStyleReadbackConsistency() {
        // Verify that reading the same value multiple times returns consistent results
        // This tests that the getter doesn't have side effects
        let initialStyle = UserDefaults.standard.waveformStyle
        let secondRead = UserDefaults.standard.waveformStyle
        let thirdRead = UserDefaults.standard.waveformStyle

        XCTAssertEqual(initialStyle, secondRead, "Consecutive reads should return same value")
        XCTAssertEqual(secondRead, thirdRead, "Consecutive reads should return same value")
    }

    func testInvalidRawValueDefaultsToClassic() {
        // Manually set an invalid value
        UserDefaults.standard.set("InvalidStyle", forKey: testDefaultsKey)

        let style = UserDefaults.standard.waveformStyle
        XCTAssertEqual(style, .classic, "Invalid raw value should default to Classic")
    }

    func testNilValueDefaultsToClassic() {
        // setUp already clears the value, so we can just read
        let style = UserDefaults.standard.waveformStyle
        XCTAssertEqual(style, .classic, "Nil value should default to Classic")
    }

    // MARK: - Initialization from RawValue Tests

    func testInitFromValidRawValue() {
        XCTAssertEqual(WaveformStyle(rawValue: "Classic"), .classic)
        XCTAssertEqual(WaveformStyle(rawValue: "Neon"), .neon)
        XCTAssertEqual(WaveformStyle(rawValue: "Spectrum"), .spectrum)
        XCTAssertEqual(WaveformStyle(rawValue: "Circular"), .circular)
        XCTAssertEqual(WaveformStyle(rawValue: "Pulse Rings"), .pulseRings)
        XCTAssertEqual(WaveformStyle(rawValue: "Particles"), .particles)
    }

    func testInitFromInvalidRawValue() {
        XCTAssertNil(WaveformStyle(rawValue: "Invalid"))
        XCTAssertNil(WaveformStyle(rawValue: ""))
        XCTAssertNil(WaveformStyle(rawValue: "classic")) // Case sensitive
        XCTAssertNil(WaveformStyle(rawValue: "CLASSIC"))
    }

    // MARK: - Equality Tests

    func testEquality() {
        XCTAssertEqual(WaveformStyle.classic, WaveformStyle.classic)
        XCTAssertEqual(WaveformStyle.neon, WaveformStyle.neon)
        XCTAssertEqual(WaveformStyle.spectrum, WaveformStyle.spectrum)

        XCTAssertNotEqual(WaveformStyle.classic, WaveformStyle.neon)
        XCTAssertNotEqual(WaveformStyle.neon, WaveformStyle.spectrum)
        XCTAssertNotEqual(WaveformStyle.classic, WaveformStyle.spectrum)
    }

    // MARK: - Hashable Tests

    func testHashable() {
        var set = Set<WaveformStyle>()
        set.insert(.classic)
        set.insert(.neon)
        set.insert(.spectrum)
        set.insert(.circular)
        set.insert(.pulseRings)
        set.insert(.particles)

        XCTAssertEqual(set.count, 6)
        XCTAssertTrue(set.contains(.classic))
        XCTAssertTrue(set.contains(.neon))
        XCTAssertTrue(set.contains(.spectrum))
        XCTAssertTrue(set.contains(.circular))
        XCTAssertTrue(set.contains(.pulseRings))
        XCTAssertTrue(set.contains(.particles))
    }

    func testHashableNoDuplicates() {
        var set = Set<WaveformStyle>()
        set.insert(.classic)
        set.insert(.classic) // Duplicate

        XCTAssertEqual(set.count, 1)
    }
}
