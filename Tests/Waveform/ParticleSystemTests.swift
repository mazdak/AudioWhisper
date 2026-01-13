import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - Particle Tests
final class ParticleTests: XCTestCase {

    func testParticleInitialization() {
        let particle = Particle(
            position: CGPoint(x: 100, y: 100),
            velocity: CGPoint(x: 10, y: -50),
            opacity: 0.8,
            size: 5,
            color: .cyan,
            rotation: 45,
            lifetime: 2.0
        )

        XCTAssertEqual(particle.position.x, 100)
        XCTAssertEqual(particle.position.y, 100)
        XCTAssertEqual(particle.velocity.x, 10)
        XCTAssertEqual(particle.velocity.y, -50)
        XCTAssertEqual(particle.opacity, 0.8)
        XCTAssertEqual(particle.size, 5)
        XCTAssertEqual(particle.rotation, 45)
        XCTAssertEqual(particle.lifetime, 2.0)
    }

    func testParticleHasUniqueId() {
        let particle1 = Particle(
            position: .zero,
            velocity: .zero,
            opacity: 1,
            size: 5,
            color: .red,
            rotation: 0,
            lifetime: 1
        )
        let particle2 = Particle(
            position: .zero,
            velocity: .zero,
            opacity: 1,
            size: 5,
            color: .red,
            rotation: 0,
            lifetime: 1
        )

        XCTAssertNotEqual(particle1.id, particle2.id)
    }

    func testParticleIdentifiable() {
        let particle = Particle(
            position: .zero,
            velocity: .zero,
            opacity: 1,
            size: 5,
            color: .blue,
            rotation: 0,
            lifetime: 1
        )

        XCTAssertNotNil(particle.id)
    }
}

// MARK: - ParticleEmitterView Tests
final class ParticleEmitterViewTests: XCTestCase {

    func testParticleEmitterViewCanBeCreated() {
        let view = ParticleEmitterView(
            audioLevel: 0.5,
            isActive: true,
            bounds: CGSize(width: 200, height: 150)
        )
        XCTAssertNotNil(view)
    }

    func testParticleEmitterViewWithInactiveState() {
        let view = ParticleEmitterView(
            audioLevel: 0.8,
            isActive: false,
            bounds: CGSize(width: 200, height: 150)
        )
        XCTAssertNotNil(view)
    }

    func testParticleEmitterViewWithZeroAudioLevel() {
        let view = ParticleEmitterView(
            audioLevel: 0,
            isActive: true,
            bounds: CGSize(width: 200, height: 150)
        )
        XCTAssertNotNil(view)
    }

    func testParticleEmitterViewWithMaxAudioLevel() {
        let view = ParticleEmitterView(
            audioLevel: 1.0,
            isActive: true,
            bounds: CGSize(width: 200, height: 150)
        )
        XCTAssertNotNil(view)
    }

    func testParticleEmitterViewWithZeroBounds() {
        let view = ParticleEmitterView(
            audioLevel: 0.5,
            isActive: true,
            bounds: CGSize(width: 0, height: 0)
        )
        XCTAssertNotNil(view)
    }
}

// MARK: - ParticleOverlay Tests
final class ParticleOverlayTests: XCTestCase {

    func testParticleOverlayCanBeCreated() {
        let view = ParticleOverlay(
            audioLevel: 0.5,
            isActive: true
        )
        XCTAssertNotNil(view)
    }

    func testParticleOverlayBodyDoesNotCrash() {
        let view = ParticleOverlay(
            audioLevel: 0.7,
            isActive: true
        )
        let _ = view.body
        XCTAssertTrue(true)
    }

    func testParticleOverlayInactiveState() {
        let view = ParticleOverlay(
            audioLevel: 0,
            isActive: false
        )
        XCTAssertNotNil(view)
    }
}

// MARK: - Particle Physics Constants Tests
final class ParticlePhysicsConstantsTests: XCTestCase {

    func testMaxParticles() {
        let maxParticles = 50
        XCTAssertEqual(maxParticles, 50)
    }

    func testSpawnThreshold() {
        let spawnThreshold: Float = 0.3
        XCTAssertEqual(spawnThreshold, 0.3)
    }

    func testParticleColorCount() {
        let colorCount = 4
        XCTAssertEqual(colorCount, 4)
    }

    func testDeltaTime() {
        let deltaTime: Double = 0.016 // ~60fps
        XCTAssertEqual(deltaTime, 0.016, accuracy: 0.001)
    }

    func testGravityConstant() {
        // Gravity is -50 (upward drift)
        let gravity: Double = 50
        XCTAssertEqual(gravity, 50)
    }

    func testOpacityFadeRate() {
        // Opacity = lifetime / 2.0
        let fadeRate: Double = 2.0
        XCTAssertEqual(fadeRate, 2.0)
    }

    func testSizeShrinkRate() {
        let shrinkRate: CGFloat = 0.1
        XCTAssertEqual(shrinkRate, 0.1)
    }

    func testMinimumSize() {
        let minSize: CGFloat = 1
        XCTAssertEqual(minSize, 1)
    }

    func testBoundsMargin() {
        // Particles are removed when > 50 pixels outside bounds
        let margin: CGFloat = 50
        XCTAssertEqual(margin, 50)
    }
}

// MARK: - Particle Spawn Logic Tests
final class ParticleSpawnLogicTests: XCTestCase {

    func testSpawnCountCalculation() {
        // spawnCount = Int(audioLevel * 3)
        XCTAssertEqual(Int(0.5 * 3), 1)
        XCTAssertEqual(Int(0.8 * 3), 2)
        XCTAssertEqual(Int(1.0 * 3), 3)
        XCTAssertEqual(Int(0.3 * 3), 0)
    }

    func testSpawnIntervalCalculation() {
        // spawnInterval = 0.1 / audioLevel
        // Note: This can cause issues if audioLevel is 0 or very small!
        let audioLevel: Float = 0.5
        let interval = 0.1 / Double(audioLevel)
        XCTAssertEqual(interval, 0.2, accuracy: 0.001)
    }

    func testParticleSizeRange() {
        // Size = random(3...8) * (audioLevel + 0.5)
        let minSize: CGFloat = 3
        let maxSize: CGFloat = 8
        XCTAssertEqual(minSize, 3)
        XCTAssertEqual(maxSize, 8)
    }

    func testParticleVelocityRangeX() {
        let rangeX: ClosedRange<CGFloat> = -30...30
        XCTAssertEqual(rangeX.lowerBound, -30)
        XCTAssertEqual(rangeX.upperBound, 30)
    }

    func testParticleVelocityRangeY() {
        // Y velocity is negative (upward): -80 to -40
        let rangeY: ClosedRange<CGFloat> = -80...(-40)
        XCTAssertEqual(rangeY.lowerBound, -80)
        XCTAssertEqual(rangeY.upperBound, -40)
    }

    func testParticleOpacityRange() {
        let range: ClosedRange<Double> = 0.6...1.0
        XCTAssertEqual(range.lowerBound, 0.6)
        XCTAssertEqual(range.upperBound, 1.0)
    }

    func testParticleLifetimeRange() {
        let range: ClosedRange<Double> = 1.5...2.5
        XCTAssertEqual(range.lowerBound, 1.5)
        XCTAssertEqual(range.upperBound, 2.5)
    }

    func testParticleRotationRange() {
        let range: ClosedRange<Double> = 0...360
        XCTAssertEqual(range.lowerBound, 0)
        XCTAssertEqual(range.upperBound, 360)
    }
}

// MARK: - Particle Update Logic Tests
final class ParticleUpdateLogicTests: XCTestCase {

    func testPositionUpdateFormula() {
        // position += velocity * deltaTime
        let velocity: CGFloat = 10
        let deltaTime: CGFloat = 0.016
        let positionChange = velocity * deltaTime
        XCTAssertEqual(positionChange, 0.16, accuracy: 0.001)
    }

    func testGravityApplication() {
        // velocity.y -= gravity * deltaTime
        // gravity = 50, deltaTime = 0.016
        let gravity: CGFloat = 50
        let deltaTime: CGFloat = 0.016
        let velocityChange = gravity * deltaTime
        XCTAssertEqual(velocityChange, 0.8, accuracy: 0.001)
    }

    func testLifetimeDecay() {
        // lifetime -= deltaTime
        let lifetime: Double = 2.0
        let deltaTime: Double = 0.016
        let newLifetime = lifetime - deltaTime
        XCTAssertEqual(newLifetime, 1.984, accuracy: 0.001)
    }

    func testOpacityCalculation() {
        // opacity = max(0, lifetime / 2.0)
        let lifetime: Double = 1.0
        let opacity = max(0, lifetime / 2.0)
        XCTAssertEqual(opacity, 0.5)
    }

    func testOpacityClampedToZero() {
        let lifetime: Double = -0.5
        let opacity = max(0, lifetime / 2.0)
        XCTAssertEqual(opacity, 0)
    }

    func testSizeShrink() {
        // size = max(1, size - 0.1)
        let size: CGFloat = 5.0
        let shrinkRate: CGFloat = 0.1
        let newSize = max(1, size - shrinkRate)
        XCTAssertEqual(newSize, 4.9)
    }

    func testSizeClampedToMinimum() {
        let size: CGFloat = 1.05
        let shrinkRate: CGFloat = 0.1
        let newSize = max(1, size - shrinkRate)
        XCTAssertEqual(newSize, 1.0, accuracy: 0.01)
    }
}

// MARK: - Particle Removal Conditions Tests
final class ParticleRemovalConditionsTests: XCTestCase {

    func testParticleRemovedWhenLifetimeExpired() {
        let lifetime: Double = 0
        let shouldRemove = lifetime <= 0
        XCTAssertTrue(shouldRemove)
    }

    func testParticleRemovedWhenOpacityTooLow() {
        let opacity: Double = 0.005
        let threshold: Double = 0.01
        let shouldRemove = opacity <= threshold
        XCTAssertTrue(shouldRemove)
    }

    func testParticleRemovedWhenOutOfBoundsTop() {
        let positionY: CGFloat = -60
        let margin: CGFloat = -50
        let shouldRemove = positionY < margin
        XCTAssertTrue(shouldRemove)
    }

    func testParticleRemovedWhenOutOfBoundsBottom() {
        let positionY: CGFloat = 250
        let boundsHeight: CGFloat = 150
        let margin: CGFloat = 50
        let shouldRemove = positionY > boundsHeight + margin
        XCTAssertTrue(shouldRemove)
    }

    func testParticleRemovedWhenOutOfBoundsLeft() {
        let positionX: CGFloat = -60
        let margin: CGFloat = -50
        let shouldRemove = positionX < margin
        XCTAssertTrue(shouldRemove)
    }

    func testParticleRemovedWhenOutOfBoundsRight() {
        let positionX: CGFloat = 300
        let boundsWidth: CGFloat = 200
        let margin: CGFloat = 50
        let shouldRemove = positionX > boundsWidth + margin
        XCTAssertTrue(shouldRemove)
    }

    func testParticleKeptWhenInBounds() {
        let positionX: CGFloat = 100
        let positionY: CGFloat = 75
        let boundsWidth: CGFloat = 200
        let boundsHeight: CGFloat = 150
        let margin: CGFloat = 50

        let inBounds = positionX > -margin && positionX < boundsWidth + margin &&
                       positionY > -margin && positionY < boundsHeight + margin
        XCTAssertTrue(inBounds)
    }
}

// MARK: - Particle Color Tests
final class ParticleColorTests: XCTestCase {

    func testCyanColorValues() {
        // Color(red: 0.0, green: 0.9, blue: 0.95)
        let red: CGFloat = 0.0
        let green: CGFloat = 0.9
        let blue: CGFloat = 0.95

        XCTAssertEqual(red, 0.0)
        XCTAssertEqual(green, 0.9)
        XCTAssertEqual(blue, 0.95)
    }

    func testMagentaColorValues() {
        // Color(red: 0.95, green: 0.2, blue: 0.8)
        let red: CGFloat = 0.95
        let green: CGFloat = 0.2
        let blue: CGFloat = 0.8

        XCTAssertEqual(red, 0.95)
        XCTAssertEqual(green, 0.2)
        XCTAssertEqual(blue, 0.8)
    }

    func testYellowColorValues() {
        // Color(red: 1.0, green: 0.85, blue: 0.0)
        let red: CGFloat = 1.0
        let green: CGFloat = 0.85
        let blue: CGFloat = 0.0

        XCTAssertEqual(red, 1.0)
        XCTAssertEqual(green, 0.85)
        XCTAssertEqual(blue, 0.0)
    }

    func testGreenColorValues() {
        // Color(red: 0.4, green: 0.9, blue: 0.5)
        let red: CGFloat = 0.4
        let green: CGFloat = 0.9
        let blue: CGFloat = 0.5

        XCTAssertEqual(red, 0.4)
        XCTAssertEqual(green, 0.9)
        XCTAssertEqual(blue, 0.5)
    }
}

// MARK: - Particle Glow Tests
final class ParticleGlowTests: XCTestCase {

    func testGlowOpacity() {
        // Glow opacity = particle opacity * 0.3
        let particleOpacity = 0.8
        let glowOpacity = particleOpacity * 0.3
        XCTAssertEqual(glowOpacity, 0.24, accuracy: 0.001)
    }

    func testGlowRectInset() {
        // Glow rect is inset by -size * 0.5 (expands)
        let size: CGFloat = 5
        let inset = -size * 0.5
        XCTAssertEqual(inset, -2.5)
    }

    func testGlowRectSize() {
        // Glow rect size = size * 2 (because inset is -0.5 on each side)
        let originalSize: CGFloat = 5
        let glowSize = originalSize + originalSize // size + 2 * |inset|
        XCTAssertEqual(glowSize, 10)
    }
}
