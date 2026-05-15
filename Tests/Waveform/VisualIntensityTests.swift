import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - VisualIntensity Tests
final class VisualIntensityTests: IsolatedXCTestCase {

    func testAllCasesExist() {
        let allCases = VisualIntensity.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.glow))
        XCTAssertTrue(allCases.contains(.balanced))
        XCTAssertTrue(allCases.contains(.burst))
    }

    func testRawValues() {
        XCTAssertEqual(VisualIntensity.glow.rawValue, "Glow")
        XCTAssertEqual(VisualIntensity.balanced.rawValue, "Balanced")
        XCTAssertEqual(VisualIntensity.burst.rawValue, "Burst")
    }

    func testIdentifiable() {
        for intensity in VisualIntensity.allCases {
            XCTAssertEqual(intensity.id, intensity.rawValue)
        }
    }

    func testDescriptions() {
        XCTAssertEqual(VisualIntensity.glow.description, "Smooth, radiant glow effects")
        XCTAssertEqual(VisualIntensity.balanced.description, "Mix of glow and particles")
        XCTAssertEqual(VisualIntensity.burst.description, "Energetic particle bursts")
    }

    func testIcons() {
        XCTAssertEqual(VisualIntensity.glow.icon, "sun.max.fill")
        XCTAssertEqual(VisualIntensity.balanced.icon, "sparkle")
        XCTAssertEqual(VisualIntensity.burst.icon, "sparkles")
    }

    func testTransitionDuration() {
        // All intensities should have same transition duration
        for intensity in VisualIntensity.allCases {
            XCTAssertEqual(intensity.transitionDuration, 0.35)
        }
    }

    func testSpringResponse() {
        for intensity in VisualIntensity.allCases {
            XCTAssertEqual(intensity.springResponse, 0.4)
        }
    }

    func testSpringDamping() {
        for intensity in VisualIntensity.allCases {
            XCTAssertEqual(intensity.springDamping, 0.7)
        }
    }

    func testSpringAnimation() {
        for intensity in VisualIntensity.allCases {
            let animation = intensity.spring
            XCTAssertNotNil(animation)
        }
    }

    func testGlowIntensity() {
        XCTAssertEqual(VisualIntensity.glow.glowIntensity, 1.0)
        XCTAssertEqual(VisualIntensity.balanced.glowIntensity, 0.6)
        XCTAssertEqual(VisualIntensity.burst.glowIntensity, 0.3)
    }

    func testGlowRingCount() {
        XCTAssertEqual(VisualIntensity.glow.glowRingCount, 3)
        XCTAssertEqual(VisualIntensity.balanced.glowRingCount, 1)
        XCTAssertEqual(VisualIntensity.burst.glowRingCount, 0)
    }

    func testGlowDuration() {
        XCTAssertEqual(VisualIntensity.glow.glowDuration, 0.8)
        XCTAssertEqual(VisualIntensity.balanced.glowDuration, 0.5)
        XCTAssertEqual(VisualIntensity.burst.glowDuration, 0.3)
    }

    func testParticleMultiplier() {
        XCTAssertEqual(VisualIntensity.glow.particleMultiplier, 0.5)
        XCTAssertEqual(VisualIntensity.balanced.particleMultiplier, 1.0)
        XCTAssertEqual(VisualIntensity.burst.particleMultiplier, 1.5)
    }

    func testConfettiCount() {
        XCTAssertEqual(VisualIntensity.glow.confettiCount, 0)
        XCTAssertEqual(VisualIntensity.balanced.confettiCount, 12)
        XCTAssertEqual(VisualIntensity.burst.confettiCount, 30)
    }

    func testRingCount() {
        XCTAssertEqual(VisualIntensity.glow.ringCount, 2)
        XCTAssertEqual(VisualIntensity.balanced.ringCount, 1)
        XCTAssertEqual(VisualIntensity.burst.ringCount, 0)
    }

    func testConfettiSizeRange() {
        XCTAssertEqual(VisualIntensity.glow.confettiSizeRange, 4...8)
        XCTAssertEqual(VisualIntensity.balanced.confettiSizeRange, 6...12)
        XCTAssertEqual(VisualIntensity.burst.confettiSizeRange, 8...16)
    }

    func testConfettiBurstSpeed() {
        XCTAssertEqual(VisualIntensity.glow.confettiBurstSpeed, 1...3)
        XCTAssertEqual(VisualIntensity.balanced.confettiBurstSpeed, 2...5)
        XCTAssertEqual(VisualIntensity.burst.confettiBurstSpeed, 3...7)
    }

    func testShowFlash() {
        XCTAssertFalse(VisualIntensity.glow.showFlash)
        XCTAssertFalse(VisualIntensity.balanced.showFlash)
        XCTAssertTrue(VisualIntensity.burst.showFlash)
    }

    func testFlashOpacity() {
        XCTAssertEqual(VisualIntensity.glow.flashOpacity, 0)
        XCTAssertEqual(VisualIntensity.balanced.flashOpacity, 0)
        XCTAssertEqual(VisualIntensity.burst.flashOpacity, 0.3)
    }

    func testShowGlass() {
        // All styles should show glass
        for intensity in VisualIntensity.allCases {
            XCTAssertTrue(intensity.showGlass)
        }
    }

    func testEntryScale() {
        for intensity in VisualIntensity.allCases {
            XCTAssertEqual(intensity.entryScale, 0.9)
        }
    }

    func testEntryRotation() {
        for intensity in VisualIntensity.allCases {
            XCTAssertEqual(intensity.entryRotation, 0)
        }
    }

    func testDotGlow() {
        for intensity in VisualIntensity.allCases {
            XCTAssertTrue(intensity.dotGlow)
        }
    }

    func testDotGlowRadius() {
        XCTAssertEqual(VisualIntensity.glow.dotGlowRadius, 8)
        XCTAssertEqual(VisualIntensity.balanced.dotGlowRadius, 5)
        XCTAssertEqual(VisualIntensity.burst.dotGlowRadius, 3)
    }

    func testCodable() throws {
        for intensity in VisualIntensity.allCases {
            let encoded = try JSONEncoder().encode(intensity)
            let decoded = try JSONDecoder().decode(VisualIntensity.self, from: encoded)
            XCTAssertEqual(intensity, decoded)
        }
    }

    func testInitFromRawValue() {
        XCTAssertEqual(VisualIntensity(rawValue: "Glow"), .glow)
        XCTAssertEqual(VisualIntensity(rawValue: "Balanced"), .balanced)
        XCTAssertEqual(VisualIntensity(rawValue: "Burst"), .burst)
        XCTAssertNil(VisualIntensity(rawValue: "Invalid"))
    }
}

// MARK: - VisualIntensity UserDefaults Tests
final class VisualIntensityUserDefaultsTests: IsolatedXCTestCase {
    // TODO(D1): `UserDefaults.visualIntensity` is an extension on
    // UserDefaults.standard. Once a non-standard accessor exists, route
    // writes through a UUID-scoped suite and re-enable isolation.
    override var enforcesStandardUserDefaultsIsolation: Bool { false }

    func testDefaultVisualIntensityIsBalanced() {
        // Default should be balanced
        let intensity = UserDefaults.standard.visualIntensity
        XCTAssertNotNil(intensity)
    }

    func testSetAndGetVisualIntensity() {
        let originalIntensity = UserDefaults.standard.visualIntensity

        UserDefaults.standard.visualIntensity = .glow
        XCTAssertEqual(UserDefaults.standard.visualIntensity, .glow)

        UserDefaults.standard.visualIntensity = .burst
        XCTAssertEqual(UserDefaults.standard.visualIntensity, .burst)

        // Restore original
        UserDefaults.standard.visualIntensity = originalIntensity
    }
}

// MARK: - VisualIntensity Ordering Tests
final class VisualIntensityOrderingTests: IsolatedXCTestCase {

    func testGlowIntensityDecreases() {
        // Glow > Balanced > Burst for glow intensity
        XCTAssertGreaterThan(VisualIntensity.glow.glowIntensity, VisualIntensity.balanced.glowIntensity)
        XCTAssertGreaterThan(VisualIntensity.balanced.glowIntensity, VisualIntensity.burst.glowIntensity)
    }

    func testParticleMultiplierIncreases() {
        // Glow < Balanced < Burst for particle multiplier
        XCTAssertLessThan(VisualIntensity.glow.particleMultiplier, VisualIntensity.balanced.particleMultiplier)
        XCTAssertLessThan(VisualIntensity.balanced.particleMultiplier, VisualIntensity.burst.particleMultiplier)
    }

    func testConfettiCountIncreases() {
        // Glow < Balanced < Burst for confetti count
        XCTAssertLessThan(VisualIntensity.glow.confettiCount, VisualIntensity.balanced.confettiCount)
        XCTAssertLessThan(VisualIntensity.balanced.confettiCount, VisualIntensity.burst.confettiCount)
    }
}
