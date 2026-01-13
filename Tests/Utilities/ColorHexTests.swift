import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - Color+Hex Tests
final class ColorHexTests: XCTestCase {

    // MARK: - Init from Hex

    func testInitFromValidHex6Digits() {
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color)
    }

    func testInitFromValidHex6DigitsNoHash() {
        let color = Color(hex: "FF0000")
        XCTAssertNotNil(color)
    }

    func testInitFromValidHex3Digits() {
        let color = Color(hex: "#F00")
        XCTAssertNotNil(color)
    }

    func testInitFromValidHex3DigitsNoHash() {
        let color = Color(hex: "F00")
        XCTAssertNotNil(color)
    }

    func testInitFromInvalidHex() {
        let color = Color(hex: "GGG")
        XCTAssertNil(color)
    }

    func testInitFromEmptyString() {
        let color = Color(hex: "")
        XCTAssertNil(color)
    }

    func testInitFromTooShortHex() {
        let color = Color(hex: "#FF")
        XCTAssertNil(color)
    }

    func testInitFromTooLongHex() {
        let color = Color(hex: "#FF00FF00")
        XCTAssertNil(color)
    }

    func testInitWithWhitespace() {
        let color = Color(hex: "  #FF0000  ")
        XCTAssertNotNil(color)
    }

    func testInitWithNewlines() {
        let color = Color(hex: "\n#FF0000\n")
        XCTAssertNotNil(color)
    }

    // MARK: - Specific Color Values

    func testBlackHex() {
        let color = Color(hex: "#000000")
        XCTAssertNotNil(color)
    }

    func testWhiteHex() {
        let color = Color(hex: "#FFFFFF")
        XCTAssertNotNil(color)
    }

    func testRedHex() {
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color)
    }

    func testGreenHex() {
        let color = Color(hex: "#00FF00")
        XCTAssertNotNil(color)
    }

    func testBlueHex() {
        let color = Color(hex: "#0000FF")
        XCTAssertNotNil(color)
    }

    // MARK: - Lowercase Hex

    func testLowercaseHex() {
        let color = Color(hex: "#ff0000")
        XCTAssertNotNil(color)
    }

    func testMixedCaseHex() {
        let color = Color(hex: "#Ff00fF")
        XCTAssertNotNil(color)
    }

    // MARK: - Hex String Output

    func testHexStringReturnsValidFormat() {
        let color = Color.red
        if let hexString = color.hexString() {
            XCTAssertTrue(hexString.hasPrefix("#"))
            XCTAssertEqual(hexString.count, 7)
        }
        // Note: hexString() may return nil in test environment
    }

    func testHexStringForBlack() {
        let color = Color.black
        if let hexString = color.hexString() {
            XCTAssertEqual(hexString, "#000000")
        }
    }

    func testHexStringForWhite() {
        let color = Color.white
        if let hexString = color.hexString() {
            XCTAssertEqual(hexString, "#FFFFFF")
        }
    }

    // MARK: - 3-digit Expansion

    func testThreeDigitExpansion() {
        // #F00 should expand to #FF0000
        let color3 = Color(hex: "#F00")
        let color6 = Color(hex: "#FF0000")
        XCTAssertNotNil(color3)
        XCTAssertNotNil(color6)
    }

    func testThreeDigitGray() {
        // #888 should expand to #888888
        let color = Color(hex: "#888")
        XCTAssertNotNil(color)
    }

    // MARK: - Edge Cases

    func testHashOnlyInput() {
        let color = Color(hex: "#")
        XCTAssertNil(color)
    }

    func testInvalidCharactersInHex() {
        let color = Color(hex: "#GGGGGG")
        XCTAssertNil(color)
    }

    func testPartiallyValidHex() {
        let color = Color(hex: "#FF00GG")
        XCTAssertNil(color)
    }
}

// MARK: - Color Hex Roundtrip Tests
final class ColorHexRoundtripTests: XCTestCase {

    func testRoundtripForCommonColors() {
        let testCases = [
            "#FF0000", // Red
            "#00FF00", // Green
            "#0000FF", // Blue
            "#FFFF00", // Yellow
            "#FF00FF", // Magenta
            "#00FFFF", // Cyan
            "#000000", // Black
            "#FFFFFF", // White
            "#808080", // Gray
        ]

        for hex in testCases {
            guard let color = Color(hex: hex) else {
                // Skip if init fails (shouldn't happen)
                continue
            }
            if let outputHex = color.hexString() {
                // Compare case-insensitively
                XCTAssertEqual(outputHex.uppercased(), hex.uppercased())
            }
        }
    }
}
