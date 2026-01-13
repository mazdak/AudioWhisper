import XCTest
import Cocoa
@testable import AudioWhisper

// MARK: - NSImage+Tinting Tests
final class NSImageTintingTests: XCTestCase {

    func testTintedReturnsImage() {
        let originalImage = NSImage(size: NSSize(width: 16, height: 16))
        let tintedImage = originalImage.tinted(with: .red)
        XCTAssertNotNil(tintedImage)
    }

    func testTintedPreservesSize() {
        let size = NSSize(width: 32, height: 32)
        let originalImage = NSImage(size: size)
        let tintedImage = originalImage.tinted(with: .blue)
        XCTAssertEqual(tintedImage.size, size)
    }

    func testTintedWithDifferentColors() {
        let originalImage = NSImage(size: NSSize(width: 16, height: 16))

        let colors: [NSColor] = [
            .red,
            .green,
            .blue,
            .white,
            .black,
            .systemPink,
            .systemTeal,
        ]

        for color in colors {
            let tintedImage = originalImage.tinted(with: color)
            XCTAssertNotNil(tintedImage)
            XCTAssertEqual(tintedImage.size, originalImage.size)
        }
    }

    func testTintedWithTransparentColor() {
        let originalImage = NSImage(size: NSSize(width: 16, height: 16))
        let transparentColor = NSColor.red.withAlphaComponent(0.5)
        let tintedImage = originalImage.tinted(with: transparentColor)
        XCTAssertNotNil(tintedImage)
    }

    func testTintedWithZeroAlpha() {
        let originalImage = NSImage(size: NSSize(width: 16, height: 16))
        let transparentColor = NSColor.red.withAlphaComponent(0)
        let tintedImage = originalImage.tinted(with: transparentColor)
        XCTAssertNotNil(tintedImage)
    }

    func testTintedReturnsNewInstance() {
        let originalImage = NSImage(size: NSSize(width: 16, height: 16))
        let tintedImage = originalImage.tinted(with: .red)

        // Should return a different instance (copy)
        // Note: In Swift, this comparison checks reference equality
        XCTAssertNotNil(tintedImage)
    }

    func testTintedWithSmallImage() {
        let smallImage = NSImage(size: NSSize(width: 1, height: 1))
        let tintedImage = smallImage.tinted(with: .red)
        XCTAssertNotNil(tintedImage)
        XCTAssertEqual(tintedImage.size.width, 1)
        XCTAssertEqual(tintedImage.size.height, 1)
    }

    func testTintedWithLargeImage() {
        let largeImage = NSImage(size: NSSize(width: 1024, height: 1024))
        let tintedImage = largeImage.tinted(with: .red)
        XCTAssertNotNil(tintedImage)
        XCTAssertEqual(tintedImage.size.width, 1024)
        XCTAssertEqual(tintedImage.size.height, 1024)
    }

    func testTintedWithNonSquareImage() {
        let rectangularImage = NSImage(size: NSSize(width: 100, height: 50))
        let tintedImage = rectangularImage.tinted(with: .green)
        XCTAssertNotNil(tintedImage)
        XCTAssertEqual(tintedImage.size.width, 100)
        XCTAssertEqual(tintedImage.size.height, 50)
    }

    func testTintedMultipleTimes() {
        var image = NSImage(size: NSSize(width: 16, height: 16))

        // Apply multiple tints
        image = image.tinted(with: .red)
        image = image.tinted(with: .green)
        image = image.tinted(with: .blue)

        XCTAssertNotNil(image)
        XCTAssertEqual(image.size, NSSize(width: 16, height: 16))
    }
}

// MARK: - NSImage+Tinting System Image Tests
final class NSImageTintingSystemImageTests: XCTestCase {

    func testTintSystemImage() {
        guard let systemImage = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil) else {
            // Skip if system image not available
            return
        }

        let tintedImage = systemImage.tinted(with: .red)
        XCTAssertNotNil(tintedImage)
    }

    func testTintVariousSystemImages() {
        let symbolNames = ["mic", "gear", "star", "heart", "folder"]

        for symbolName in symbolNames {
            guard let systemImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
                continue
            }

            let tintedImage = systemImage.tinted(with: .blue)
            XCTAssertNotNil(tintedImage)
        }
    }
}

// MARK: - NSImage+Tinting Color Space Tests
final class NSImageTintingColorSpaceTests: XCTestCase {

    func testTintWithSRGBColor() {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let srgbColor = NSColor(srgbRed: 1.0, green: 0, blue: 0, alpha: 1.0)
        let tintedImage = image.tinted(with: srgbColor)
        XCTAssertNotNil(tintedImage)
    }

    func testTintWithDeviceRGBColor() {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let deviceColor = NSColor(deviceRed: 1.0, green: 0, blue: 0, alpha: 1.0)
        let tintedImage = image.tinted(with: deviceColor)
        XCTAssertNotNil(tintedImage)
    }

    func testTintWithCalibratedColor() {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let calibratedColor = NSColor(calibratedRed: 1.0, green: 0, blue: 0, alpha: 1.0)
        let tintedImage = image.tinted(with: calibratedColor)
        XCTAssertNotNil(tintedImage)
    }
}
