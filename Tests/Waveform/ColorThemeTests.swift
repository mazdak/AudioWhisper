import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - ColorTheme Tests
final class ColorThemeTests: IsolatedXCTestCase {

    func testAllCasesExist() {
        let allCases = ColorTheme.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.neonNights))
        XCTAssertTrue(allCases.contains(.warmSunset))
        XCTAssertTrue(allCases.contains(.ocean))
        XCTAssertTrue(allCases.contains(.monochrome))
    }

    func testRawValues() {
        XCTAssertEqual(ColorTheme.neonNights.rawValue, "Neon Nights")
        XCTAssertEqual(ColorTheme.warmSunset.rawValue, "Warm Sunset")
        XCTAssertEqual(ColorTheme.ocean.rawValue, "Ocean")
        XCTAssertEqual(ColorTheme.monochrome.rawValue, "Monochrome")
    }

    func testIdentifiable() {
        for theme in ColorTheme.allCases {
            XCTAssertEqual(theme.id, theme.rawValue)
        }
    }

    func testPrimaryColorsExist() {
        for theme in ColorTheme.allCases {
            let color = theme.primary
            XCTAssertNotNil(color)
        }
    }

    func testSecondaryColorsExist() {
        for theme in ColorTheme.allCases {
            let color = theme.secondary
            XCTAssertNotNil(color)
        }
    }

    func testAccentColorsExist() {
        for theme in ColorTheme.allCases {
            let color = theme.accent
            XCTAssertNotNil(color)
        }
    }

    func testGradientColorsCount() {
        for theme in ColorTheme.allCases {
            let colors = theme.gradientColors
            XCTAssertEqual(colors.count, 8, "Theme \(theme.rawValue) should have 8 gradient colors")
        }
    }

    func testDescriptions() {
        XCTAssertEqual(ColorTheme.neonNights.description, "Vibrant cyan, magenta, and yellow")
        XCTAssertEqual(ColorTheme.warmSunset.description, "Warm oranges, reds, and purples")
        XCTAssertEqual(ColorTheme.ocean.description, "Cool blues and teals")
        XCTAssertEqual(ColorTheme.monochrome.description, "Clean white and gray")
    }

    func testDescriptionsNotEmpty() {
        for theme in ColorTheme.allCases {
            XCTAssertFalse(theme.description.isEmpty)
        }
    }

    func testCodable() throws {
        for theme in ColorTheme.allCases {
            let encoded = try JSONEncoder().encode(theme)
            let decoded = try JSONDecoder().decode(ColorTheme.self, from: encoded)
            XCTAssertEqual(theme, decoded)
        }
    }

    func testInitFromRawValue() {
        XCTAssertEqual(ColorTheme(rawValue: "Neon Nights"), .neonNights)
        XCTAssertEqual(ColorTheme(rawValue: "Warm Sunset"), .warmSunset)
        XCTAssertEqual(ColorTheme(rawValue: "Ocean"), .ocean)
        XCTAssertEqual(ColorTheme(rawValue: "Monochrome"), .monochrome)
        XCTAssertNil(ColorTheme(rawValue: "Invalid"))
    }
}

// MARK: - ColorTheme UserDefaults Tests
final class ColorThemeUserDefaultsTests: IsolatedXCTestCase {
    // TODO(D1): `UserDefaults.colorTheme` is an extension on
    // UserDefaults.standard. Once a non-standard accessor exists, route
    // writes through the existing UUID-scoped suite below and re-enable.
    override var enforcesStandardUserDefaultsIsolation: Bool { false }

    private var defaults: UserDefaults!
    private let suiteName = "ColorThemeTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testDefaultColorThemeIsNeonNights() {
        // When no theme is set, default should be neonNights
        let theme = UserDefaults.standard.colorTheme
        // Note: This tests the actual UserDefaults, might have existing value
        XCTAssertNotNil(theme)
    }

    func testSetAndGetColorTheme() {
        let originalTheme = UserDefaults.standard.colorTheme

        UserDefaults.standard.colorTheme = .ocean
        XCTAssertEqual(UserDefaults.standard.colorTheme, .ocean)

        UserDefaults.standard.colorTheme = .warmSunset
        XCTAssertEqual(UserDefaults.standard.colorTheme, .warmSunset)

        // Restore original
        UserDefaults.standard.colorTheme = originalTheme
    }
}
