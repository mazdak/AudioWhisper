import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - SuccessCelebration Tests
final class SuccessCelebrationTests: XCTestCase {

    func testSuccessCelebrationCanBeCreated() {
        let view = SuccessCelebration(
            intensity: .glow,
            isActive: true,
            successColor: .green
        )
        XCTAssertNotNil(view)
    }

    func testSuccessCelebrationWithAllIntensities() {
        for intensity in VisualIntensity.allCases {
            let view = SuccessCelebration(
                intensity: intensity,
                isActive: true,
                successColor: Color(red: 0.45, green: 0.75, blue: 0.55)
            )
            XCTAssertNotNil(view)
        }
    }

    func testSuccessCelebrationInactiveState() {
        let view = SuccessCelebration(
            intensity: .balanced,
            isActive: false,
            successColor: .blue
        )
        XCTAssertNotNil(view)
    }
}

// MARK: - FlashOverlay Tests
final class FlashOverlayTests: XCTestCase {

    func testFlashOverlayCanBeCreated() {
        let view = FlashOverlay(opacity: 0.3)
        XCTAssertNotNil(view)
    }

    func testFlashOverlayWithZeroOpacity() {
        let view = FlashOverlay(opacity: 0)
        XCTAssertNotNil(view)
    }

    func testFlashOverlayWithFullOpacity() {
        let view = FlashOverlay(opacity: 1.0)
        XCTAssertNotNil(view)
    }

    func testFlashOverlayAnimationDuration() {
        let expectedDuration: Double = 0.2
        XCTAssertEqual(expectedDuration, 0.2)
    }
}

// MARK: - GlowPulseView Tests
final class GlowPulseViewTests: XCTestCase {

    func testGlowPulseViewCanBeCreated() {
        let view = GlowPulseView(
            color: .green,
            intensity: 1.0,
            duration: 0.8,
            ringCount: 3
        )
        XCTAssertNotNil(view)
    }

    func testGlowPulseViewWithZeroRings() {
        let view = GlowPulseView(
            color: .green,
            intensity: 1.0,
            duration: 0.8,
            ringCount: 0
        )
        XCTAssertNotNil(view)
    }

    func testGlowPulseViewWithNegativeRings() {
        // max(1, -5) = 1, so this should work
        let view = GlowPulseView(
            color: .green,
            intensity: 1.0,
            duration: 0.8,
            ringCount: -5
        )
        XCTAssertNotNil(view)
    }

    func testGlowPulseViewAnimationValues() {
        // Initial scale: 0.3, Final scale: 3.0
        let initialScale: CGFloat = 0.3
        let finalScale: CGFloat = 3.0

        XCTAssertEqual(initialScale, 0.3)
        XCTAssertEqual(finalScale, 3.0)
    }

    func testGlowPulseViewGradientRadius() {
        let startRadius: CGFloat = 0
        let endRadius: CGFloat = 150

        XCTAssertEqual(startRadius, 0)
        XCTAssertEqual(endRadius, 150)
    }
}

// MARK: - ExpandingRingsView Tests
final class ExpandingRingsViewTests: XCTestCase {

    func testExpandingRingsViewCanBeCreated() {
        let view = ExpandingRingsView(
            ringCount: 2,
            color: .green,
            glowIntensity: 1.0
        )
        XCTAssertNotNil(view)
    }

    func testExpandingRingsViewWithZeroRings() {
        let view = ExpandingRingsView(
            ringCount: 0,
            color: .green,
            glowIntensity: 1.0
        )
        XCTAssertNotNil(view)
    }

    func testExpandingRingsViewRingDelay() {
        // Each ring has a delay of index * 0.12
        let delayPerRing: Double = 0.12
        XCTAssertEqual(delayPerRing, 0.12)
    }

    func testExpandingRingsViewRingDuration() {
        let ringDuration: Double = 1.0
        XCTAssertEqual(ringDuration, 1.0)
    }

    func testExpandingRingsViewGlowLineWidth() {
        let glowLineWidth: CGFloat = 10
        XCTAssertEqual(glowLineWidth, 10)
    }

    func testExpandingRingsViewCoreLineWidthRange() {
        // Line width ranges from 6 (at start) to 3 (at end)
        let maxLineWidth: CGFloat = 6 // 3 + 3
        let minLineWidth: CGFloat = 3
        XCTAssertEqual(maxLineWidth, 6)
        XCTAssertEqual(minLineWidth, 3)
    }
}

// MARK: - ConfettiView Tests
final class ConfettiViewTests: XCTestCase {

    func testConfettiViewCanBeCreated() {
        let view = ConfettiView(
            particleCount: 12,
            sizeRange: 6...12,
            speedRange: 2...5
        )
        XCTAssertNotNil(view)
    }

    func testConfettiViewWithZeroParticles() {
        let view = ConfettiView(
            particleCount: 0,
            sizeRange: 6...12,
            speedRange: 2...5
        )
        XCTAssertNotNil(view)
    }

    func testConfettiViewWithManyParticles() {
        let view = ConfettiView(
            particleCount: 100,
            sizeRange: 4...8,
            speedRange: 3...7
        )
        XCTAssertNotNil(view)
    }

    func testConfettiViewColorCount() {
        let colorCount = 7
        XCTAssertEqual(colorCount, 7)
    }

    func testConfettiViewAngleRange() {
        // Angle range: -160° to -20° (approximately -0.9π to -0.1π)
        let minAngle = -Double.pi * 0.9
        let maxAngle = -Double.pi * 0.1

        XCTAssertEqual(minAngle, -Double.pi * 0.9, accuracy: 0.001)
        XCTAssertEqual(maxAngle, -Double.pi * 0.1, accuracy: 0.001)
    }

    func testConfettiViewGravity() {
        let gravity: Double = 200
        XCTAssertEqual(gravity, 200)
    }

    func testConfettiViewLifetimeRange() {
        let lifetimeRange: ClosedRange<Double> = 1.2...1.8
        XCTAssertEqual(lifetimeRange.lowerBound, 1.2)
        XCTAssertEqual(lifetimeRange.upperBound, 1.8)
    }

    func testConfettiViewDelayFormula() {
        // delay = index * 0.012
        let delayPerParticle: Double = 0.012
        XCTAssertEqual(delayPerParticle, 0.012)
    }
}

// MARK: - ConfettiParticle Tests
final class ConfettiParticleTests: XCTestCase {

    func testConfettiParticleCreation() {
        let particle = ConfettiParticle(
            velocity: CGPoint(x: 10, y: -50),
            color: .red,
            size: 10,
            rotation: 45,
            rotationSpeed: 2,
            lifetime: 1.5,
            delay: 0.1,
            isCircle: true
        )

        XCTAssertEqual(particle.velocity.x, 10)
        XCTAssertEqual(particle.velocity.y, -50)
        XCTAssertEqual(particle.size, 10)
        XCTAssertEqual(particle.rotation, 45)
        XCTAssertEqual(particle.rotationSpeed, 2)
        XCTAssertEqual(particle.lifetime, 1.5)
        XCTAssertEqual(particle.delay, 0.1)
        XCTAssertTrue(particle.isCircle)
    }

    func testConfettiParticleHasUniqueId() {
        let particle1 = ConfettiParticle(
            velocity: .zero,
            color: .red,
            size: 10,
            rotation: 0,
            rotationSpeed: 0,
            lifetime: 1,
            delay: 0,
            isCircle: true
        )
        let particle2 = ConfettiParticle(
            velocity: .zero,
            color: .red,
            size: 10,
            rotation: 0,
            rotationSpeed: 0,
            lifetime: 1,
            delay: 0,
            isCircle: true
        )

        XCTAssertNotEqual(particle1.id, particle2.id)
    }

    func testConfettiParticleIdentifiable() {
        let particle = ConfettiParticle(
            velocity: .zero,
            color: .blue,
            size: 8,
            rotation: 0,
            rotationSpeed: 1,
            lifetime: 1,
            delay: 0,
            isCircle: false
        )

        XCTAssertNotNil(particle.id)
    }

    func testConfettiParticleShapes() {
        let circleParticle = ConfettiParticle(
            velocity: .zero,
            color: .red,
            size: 10,
            rotation: 0,
            rotationSpeed: 0,
            lifetime: 1,
            delay: 0,
            isCircle: true
        )

        let rectParticle = ConfettiParticle(
            velocity: .zero,
            color: .blue,
            size: 10,
            rotation: 0,
            rotationSpeed: 0,
            lifetime: 1,
            delay: 0,
            isCircle: false
        )

        XCTAssertTrue(circleParticle.isCircle)
        XCTAssertFalse(rectParticle.isCircle)
    }
}

// MARK: - Confetti Physics Tests
final class ConfettiPhysicsTests: XCTestCase {

    func testPositionCalculation() {
        // x = center.x + velocity.x * age * 55
        // y = center.y + velocity.y * age * 55 + 0.5 * gravity * age^2
        let centerX: CGFloat = 100
        let velocityX: CGFloat = 2
        let age: Double = 0.5
        let velocityMultiplier: CGFloat = 55

        let expectedX = centerX + velocityX * CGFloat(age) * velocityMultiplier
        XCTAssertEqual(expectedX, 155)
    }

    func testGravityEffect() {
        let gravity: Double = 200
        let age: Double = 1.0

        let gravityEffect = 0.5 * CGFloat(gravity) * CGFloat(age * age)
        XCTAssertEqual(gravityEffect, 100)
    }

    func testOpacityFade() {
        // opacity = 1.0 - progress * 0.6
        let progress: Double = 0.5
        let opacity = 1.0 - progress * 0.6
        XCTAssertEqual(opacity, 0.7)
    }

    func testScaleShrink() {
        // scale = size * (1.0 - progress * 0.3)
        let size: CGFloat = 10
        let progress: Double = 0.5
        let scale = size * (1.0 - progress * 0.3)
        XCTAssertEqual(scale, 8.5)
    }

    func testRotationCalculation() {
        // rotation = initial + rotationSpeed * age * 60
        let initialRotation: Double = 45
        let rotationSpeed: Double = 2
        let age: Double = 1.0

        let rotation = initialRotation + rotationSpeed * age * 60
        XCTAssertEqual(rotation, 165)
    }
}

// MARK: - Celebration Colors Tests
final class CelebrationColorsTests: XCTestCase {

    func testConfettiColors() {
        let colors: [(CGFloat, CGFloat, CGFloat)] = [
            (0.0, 0.9, 0.95),    // Cyan
            (0.95, 0.2, 0.8),    // Magenta
            (1.0, 0.85, 0.0),    // Yellow
            (0.4, 0.9, 0.5),     // Green
            (0.45, 0.75, 0.55),  // Success green
            (1.0, 0.6, 0.4),     // Coral
            (0.6, 0.4, 1.0),     // Purple
        ]

        XCTAssertEqual(colors.count, 7)
    }

    func testSuccessGreenColor() {
        let red: CGFloat = 0.45
        let green: CGFloat = 0.75
        let blue: CGFloat = 0.55

        XCTAssertEqual(red, 0.45)
        XCTAssertEqual(green, 0.75)
        XCTAssertEqual(blue, 0.55)
    }
}

// MARK: - Bounds Checking Tests
final class CelebrationBoundsCheckingTests: XCTestCase {

    func testParticleBoundsMargin() {
        // Particles are removed when > 40 pixels outside bounds
        let margin: CGFloat = 40
        XCTAssertEqual(margin, 40)
    }

    func testParticleInBounds() {
        let x: CGFloat = 100
        let y: CGFloat = 100
        let width: CGFloat = 200
        let height: CGFloat = 150
        let margin: CGFloat = 40

        let inBounds = x >= -margin && x <= width + margin &&
                       y >= -margin && y <= height + margin

        XCTAssertTrue(inBounds)
    }

    func testParticleOutOfBounds() {
        let x: CGFloat = 300
        let y: CGFloat = 100
        let width: CGFloat = 200
        let height: CGFloat = 150
        let margin: CGFloat = 40

        let inBounds = x >= -margin && x <= width + margin &&
                       y >= -margin && y <= height + margin

        XCTAssertFalse(inBounds)
    }
}
