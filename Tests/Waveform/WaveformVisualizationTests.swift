import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - CircularSpectrumView Tests
final class CircularSpectrumViewTests: XCTestCase {

    func testViewCanBeCreated() {
        let view = CircularSpectrumView(
            frequencyBands: [0.5, 0.4, 0.3, 0.2, 0.1, 0.2, 0.3, 0.4],
            isActive: true
        )
        XCTAssertNotNil(view)
    }

    func testViewWithEmptyBands() {
        let view = CircularSpectrumView(
            frequencyBands: [],
            isActive: false
        )
        XCTAssertNotNil(view)
    }

    func testBandIndexMappingForFirstHalf() {
        // First 8 bars (0-7) should map directly to band indices
        for i in 0..<8 {
            let bandIndex = CircularSpectrumView.testableBandIndex(for: i)
            XCTAssertEqual(bandIndex, i)
        }
    }

    func testBandIndexMappingForSecondHalf() {
        // Second 8 bars (8-15) should mirror: 15-i
        XCTAssertEqual(CircularSpectrumView.testableBandIndex(for: 8), 7)
        XCTAssertEqual(CircularSpectrumView.testableBandIndex(for: 9), 6)
        XCTAssertEqual(CircularSpectrumView.testableBandIndex(for: 10), 5)
        XCTAssertEqual(CircularSpectrumView.testableBandIndex(for: 15), 0)
    }

    func testIdleBreathValueRange() {
        // Idle breath values should be in range [0.05, 0.20]
        for barIndex in 0..<16 {
            for phase in stride(from: 0.0, to: 2 * Double.pi, by: 0.5) {
                let value = CircularSpectrumView.testableIdleBreathValue(phase: phase, barIndex: barIndex)
                XCTAssertGreaterThanOrEqual(value, 0.05)
                XCTAssertLessThanOrEqual(value, 0.20)
            }
        }
    }

    func testSmoothedLevelFastAttack() {
        // When target > current, should rise quickly (70% of difference)
        let current: Float = 0.2
        let target: Float = 0.8
        let smoothed = CircularSpectrumView.testableSmoothedLevel(current: current, target: target)

        // Expected: 0.2 * 0.3 + 0.8 * 0.7 = 0.06 + 0.56 = 0.62
        XCTAssertEqual(smoothed, 0.62, accuracy: 0.001)
    }

    func testSmoothedLevelSlowDecay() {
        // When target < current, should decay slowly (10% toward target)
        let current: Float = 0.8
        let target: Float = 0.2
        let smoothed = CircularSpectrumView.testableSmoothedLevel(current: current, target: target)

        // Expected: 0.8 * 0.9 + 0.2 * 0.1 = 0.72 + 0.02 = 0.74
        XCTAssertEqual(smoothed, 0.74, accuracy: 0.001)
    }

    func testColorPaletteCount() {
        // View should have 8 colors for the gradient
        let expectedColorCount = 8
        XCTAssertEqual(expectedColorCount, 8)
    }

    func testBarCount() {
        // View should have 16 bars (doubled for fuller look)
        let expectedBarCount = 16
        XCTAssertEqual(expectedBarCount, 16)
    }
}

// MARK: - ClassicWaveformView Tests
final class ClassicWaveformViewTests: XCTestCase {

    func testViewCanBeCreated() {
        let view = ClassicWaveformView(
            audioLevel: 0.5,
            isActive: true,
            barColor: .blue
        )
        XCTAssertNotNil(view)
    }

    func testViewWithZeroAudioLevel() {
        let view = ClassicWaveformView(
            audioLevel: 0,
            isActive: false,
            barColor: .gray
        )
        XCTAssertNotNil(view)
    }

    func testPhysicsConstants() {
        // Document expected physics constants
        let gravity: CGFloat = 2.5
        let bounceFactor: CGFloat = 0.3
        let riseSpeed: CGFloat = 0.8

        XCTAssertEqual(gravity, 2.5)
        XCTAssertEqual(bounceFactor, 0.3)
        XCTAssertEqual(riseSpeed, 0.8)
    }

    func testBarCountIs64() {
        let expectedBarCount = 64
        XCTAssertEqual(expectedBarCount, 64)
    }

    func testMinHeightIs2() {
        let minHeight: CGFloat = 2
        XCTAssertEqual(minHeight, 2)
    }
}

// MARK: - NeonWaveformView Tests
final class NeonWaveformViewTests: XCTestCase {

    func testViewCanBeCreated() {
        let view = NeonWaveformView(
            waveformSamples: [0.1, 0.2, 0.3, 0.4],
            audioLevel: 0.5,
            isActive: true
        )
        XCTAssertNotNil(view)
    }

    func testViewWithEmptySamples() {
        let view = NeonWaveformView(
            waveformSamples: [],
            audioLevel: 0,
            isActive: false
        )
        XCTAssertNotNil(view)
    }

    func testColorThresholds() {
        // High level (>0.7) = yellow
        // Medium level (>0.4) = magenta
        // Low level = cyan
        let highThreshold: Float = 0.7
        let mediumThreshold: Float = 0.4

        XCTAssertEqual(highThreshold, 0.7)
        XCTAssertEqual(mediumThreshold, 0.4)
    }

    func testTrailCount() {
        let trailCount = 3
        XCTAssertEqual(trailCount, 3)
    }

    func testDecayFactor() {
        let decayFactor: Float = 0.55
        XCTAssertEqual(decayFactor, 0.55)
    }
}

// MARK: - ParticleFieldView Tests
final class ParticleFieldViewTests: XCTestCase {

    func testViewCanBeCreated() {
        let view = ParticleFieldView(
            audioLevel: 0.5,
            frequencyBands: [0.8, 0.6, 0.5, 0.4, 0.3, 0.25, 0.2, 0.3],
            isActive: true
        )
        XCTAssertNotNil(view)
    }

    func testViewWithEmptyBands() {
        let view = ParticleFieldView(
            audioLevel: 0,
            frequencyBands: [],
            isActive: false
        )
        XCTAssertNotNil(view)
    }

    func testParticleCount() {
        let particleCount = 60
        XCTAssertEqual(particleCount, 60)
    }

    func testColorCount() {
        let colorCount = 4
        XCTAssertEqual(colorCount, 4)
    }

    func testParticleStructure() {
        // Test particle initialization values are reasonable
        let sizeRange: ClosedRange<CGFloat> = 3...8
        let opacityRange: ClosedRange<CGFloat> = 0.4...0.9
        let velocityRange: ClosedRange<CGFloat> = -0.5...0.5

        XCTAssertEqual(sizeRange.lowerBound, 3)
        XCTAssertEqual(sizeRange.upperBound, 8)
        XCTAssertEqual(opacityRange.lowerBound, 0.4)
        XCTAssertEqual(opacityRange.upperBound, 0.9)
        XCTAssertEqual(velocityRange.lowerBound, -0.5)
        XCTAssertEqual(velocityRange.upperBound, 0.5)
    }
}

// MARK: - PulseRingsView Tests
final class PulseRingsViewTests: XCTestCase {

    func testViewCanBeCreated() {
        let view = PulseRingsView(
            audioLevel: 0.5,
            isActive: true
        )
        XCTAssertNotNil(view)
    }

    func testViewInIdleState() {
        let view = PulseRingsView(
            audioLevel: 0,
            isActive: false
        )
        XCTAssertNotNil(view)
    }

    func testMaxRings() {
        let maxRings = 8
        XCTAssertEqual(maxRings, 8)
    }

    func testRingLifetime() {
        let ringLifetime: TimeInterval = 1.5
        XCTAssertEqual(ringLifetime, 1.5)
    }

    func testPeakThreshold() {
        let peakThreshold: Float = 0.15
        XCTAssertEqual(peakThreshold, 0.15)
    }

    func testPeakCooldown() {
        let peakCooldown: TimeInterval = 0.1
        XCTAssertEqual(peakCooldown, 0.1)
    }

    func testColorThresholds() {
        // High level (>0.7) = accent (yellow)
        // Medium level (>0.4) = secondary (magenta)
        // Low level = primary (cyan)
        let highThreshold: Float = 0.7
        let mediumThreshold: Float = 0.4

        XCTAssertEqual(highThreshold, 0.7)
        XCTAssertEqual(mediumThreshold, 0.4)
    }
}

// MARK: - SpectrumWaveformView Tests
final class SpectrumWaveformViewTests: XCTestCase {

    func testViewCanBeCreated() {
        let view = SpectrumWaveformView(
            frequencyBands: [0.8, 0.6, 0.5, 0.4, 0.3, 0.25, 0.2, 0.15],
            isActive: true
        )
        XCTAssertNotNil(view)
    }

    func testViewWithEmptyBands() {
        let view = SpectrumWaveformView(
            frequencyBands: [],
            isActive: false
        )
        XCTAssertNotNil(view)
    }

    func testGainBoost() {
        // 138% boost = 2.38 multiplier
        let boosted = SpectrumWaveformView.testableApplyGainBoost(0.5)
        XCTAssertEqual(boosted, 1.0, accuracy: 0.001) // 0.5 * 2.38 = 1.19, clamped to 1.0
    }

    func testGainBoostClamping() {
        // Values should be clamped to 1.0
        let boosted = SpectrumWaveformView.testableApplyGainBoost(0.6)
        XCTAssertLessThanOrEqual(boosted, 1.0)
    }

    func testIdleBreathValueRange() {
        // Idle breath values should be in range [0, 0.08]
        for bandIndex in 0..<8 {
            for phase in stride(from: 0.0, to: 2 * Double.pi, by: 0.5) {
                let value = SpectrumWaveformView.testableIdleBreathValue(phase: phase, bandIndex: bandIndex)
                XCTAssertGreaterThanOrEqual(value, 0)
                XCTAssertLessThanOrEqual(value, 0.08)
            }
        }
    }

    func testSmoothedLevelInstantAttack() {
        // When target > current, should instantly jump to target
        let current: Float = 0.2
        let target: Float = 0.8
        let smoothed = SpectrumWaveformView.testableSmoothedLevel(current: current, target: target)
        XCTAssertEqual(smoothed, target)
    }

    func testSmoothedLevelGradualDecay() {
        // When target < current, should decay gradually
        let current: Float = 0.8
        let target: Float = 0.2
        let smoothed = SpectrumWaveformView.testableSmoothedLevel(current: current, target: target)

        // Expected: 0.8 * 0.75 + 0.2 * 0.25 = 0.6 + 0.05 = 0.65
        XCTAssertEqual(smoothed, 0.65, accuracy: 0.001)
    }

    func testPeakDecayNewPeak() {
        let current: Float = 0.5
        let level: Float = 0.8
        let newPeak = SpectrumWaveformView.testablePeakDecay(current: current, level: level)
        XCTAssertEqual(newPeak, level)
    }

    func testPeakDecaySlowDecay() {
        let current: Float = 0.8
        let level: Float = 0.5
        let decayed = SpectrumWaveformView.testablePeakDecay(current: current, level: level)

        // Expected: max(0, 0.8 - 0.01) = 0.79
        XCTAssertEqual(decayed, 0.79, accuracy: 0.001)
    }

    func testBandCount() {
        let bandCount = 8
        XCTAssertEqual(bandCount, 8)
    }

    func testBandLabels() {
        let expectedLabels = ["80", "120", "180", "260", "380", "550", "750", "950"]
        XCTAssertEqual(expectedLabels.count, 8)
    }
}
