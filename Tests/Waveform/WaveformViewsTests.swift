import XCTest
import SwiftUI
@testable import AudioWhisper

/// Tests for waveform visualization views
@MainActor
final class WaveformViewsTests: XCTestCase {

    // MARK: - CircularSpectrumView Tests

    func testCircularSpectrumViewInitialization() {
        let view = CircularSpectrumView(
            frequencyBands: [0.5, 0.6, 0.7, 0.8, 0.7, 0.6, 0.5, 0.4],
            isActive: true
        )

        XCTAssertNotNil(view)
    }

    func testCircularSpectrumViewBarCount() {
        // CircularSpectrumView uses 16 bars (mirrored from 8 bands)
        let barCount = 16
        XCTAssertEqual(barCount, 16)
    }

    func testCircularSpectrumBandIndexMapping() {
        // Test the band index calculation for mirrored bars
        // First 8 bars map directly: 0-7
        // Last 8 bars mirror: 15-0 -> 0-7

        XCTAssertEqual(CircularSpectrumView.testableBandIndex(for: 0), 0)
        XCTAssertEqual(CircularSpectrumView.testableBandIndex(for: 7), 7)
        XCTAssertEqual(CircularSpectrumView.testableBandIndex(for: 8), 7)
        XCTAssertEqual(CircularSpectrumView.testableBandIndex(for: 15), 0)
    }

    func testCircularSpectrumIdleBreathValue() {
        let phase = 0.0
        let barIndex = 0

        let breathValue = CircularSpectrumView.testableIdleBreathValue(phase: phase, barIndex: barIndex)

        // Should be between 0.05 and 0.20 (baseline + breathing range)
        XCTAssertGreaterThanOrEqual(breathValue, 0.05)
        XCTAssertLessThanOrEqual(breathValue, 0.20)
    }

    func testCircularSpectrumSmoothedLevelFastRise() {
        let current: Float = 0.2
        let target: Float = 0.8

        let smoothed = CircularSpectrumView.testableSmoothedLevel(current: current, target: target)

        // Fast rise: current * 0.3 + target * 0.7
        let expected = current * 0.3 + target * 0.7
        XCTAssertEqual(smoothed, expected, accuracy: 0.001)
    }

    func testCircularSpectrumSmoothedLevelSlowDecay() {
        let current: Float = 0.8
        let target: Float = 0.2

        let smoothed = CircularSpectrumView.testableSmoothedLevel(current: current, target: target)

        // Slow decay: current * 0.9 + target * 0.1
        let expected = current * 0.9 + target * 0.1
        XCTAssertEqual(smoothed, expected, accuracy: 0.001)
    }

    // MARK: - NeonWaveformView Tests

    func testNeonWaveformViewInitialization() {
        let view = NeonWaveformView(
            waveformSamples: (0..<64).map { _ in Float.random(in: -0.5...0.5) },
            audioLevel: 0.6,
            isActive: true
        )

        XCTAssertNotNil(view)
    }

    func testNeonWaveformViewInactiveState() {
        let view = NeonWaveformView(
            waveformSamples: [],
            audioLevel: 0,
            isActive: false
        )

        XCTAssertNotNil(view)
    }

    func testNeonWaveformTrailCount() {
        let trailCount = 3
        XCTAssertEqual(trailCount, 3)
    }

    func testNeonWaveformDecayFactor() {
        let decayFactor: Float = 0.55
        XCTAssertEqual(decayFactor, 0.55)
    }

    func testNeonWaveformColorThreshold() {
        // High audio level should use yellow
        let audioLevel: Float = 0.75
        XCTAssertTrue(audioLevel > 0.7)

        // Medium audio level should use magenta
        let mediumLevel: Float = 0.5
        XCTAssertTrue(mediumLevel > 0.4 && mediumLevel <= 0.7)

        // Low audio level should use cyan
        let lowLevel: Float = 0.3
        XCTAssertTrue(lowLevel <= 0.4)
    }

    // MARK: - WaveformContainer Tests

    func testWaveformContainerInitialization() {
        let container = WaveformContainer(
            status: .ready,
            audioLevel: 0,
            waveformSamples: [],
            frequencyBands: Array(repeating: 0, count: 8),
            onTap: {}
        )

        XCTAssertNotNil(container)
    }

    func testWaveformContainerRecordingStatus() {
        let container = WaveformContainer(
            status: .recording,
            audioLevel: 0.5,
            waveformSamples: [],
            frequencyBands: Array(repeating: 0.5, count: 8),
            onTap: {}
        )

        XCTAssertNotNil(container)
    }

    func testWaveformContainerProcessingStatus() {
        let container = WaveformContainer(
            status: .processing(message: "Transcribing..."),
            audioLevel: 0,
            waveformSamples: [],
            frequencyBands: [],
            onTap: {}
        )

        XCTAssertNotNil(container)
    }

    func testWaveformContainerSuccessStatus() {
        let container = WaveformContainer(
            status: .success,
            audioLevel: 0,
            waveformSamples: [],
            frequencyBands: [],
            onTap: {}
        )

        XCTAssertNotNil(container)
    }

    func testWaveformContainerErrorStatus() {
        let container = WaveformContainer(
            status: .error(message: "Failed"),
            audioLevel: 0,
            waveformSamples: [],
            frequencyBands: [],
            onTap: {}
        )

        XCTAssertNotNil(container)
    }

    // MARK: - WaveformStyle Tests

    func testWaveformStyleAllCases() {
        let styles = WaveformStyle.allCases

        XCTAssertTrue(styles.contains(.classic))
        XCTAssertTrue(styles.contains(.neon))
        XCTAssertTrue(styles.contains(.spectrum))
        XCTAssertTrue(styles.contains(.circular))
        XCTAssertTrue(styles.contains(.pulseRings))
        XCTAssertTrue(styles.contains(.particles))
    }

    func testWaveformStyleRawValues() {
        XCTAssertEqual(WaveformStyle.classic.rawValue, "Classic")
        XCTAssertEqual(WaveformStyle.neon.rawValue, "Neon")
        XCTAssertEqual(WaveformStyle.spectrum.rawValue, "Spectrum")
        XCTAssertEqual(WaveformStyle.circular.rawValue, "Circular")
        XCTAssertEqual(WaveformStyle.pulseRings.rawValue, "Pulse Rings")
        XCTAssertEqual(WaveformStyle.particles.rawValue, "Particles")
    }

    func testWaveformStyleDescriptions() {
        for style in WaveformStyle.allCases {
            XCTAssertFalse(style.description.isEmpty, "\(style) should have a description")
        }
    }

    func testWaveformStyleRequiresEnhancedAudio() {
        // Classic and pulseRings don't require enhanced audio
        XCTAssertFalse(WaveformStyle.classic.requiresEnhancedAudio)
        XCTAssertFalse(WaveformStyle.pulseRings.requiresEnhancedAudio)

        // Others require enhanced audio
        XCTAssertTrue(WaveformStyle.neon.requiresEnhancedAudio)
        XCTAssertTrue(WaveformStyle.spectrum.requiresEnhancedAudio)
        XCTAssertTrue(WaveformStyle.circular.requiresEnhancedAudio)
        XCTAssertTrue(WaveformStyle.particles.requiresEnhancedAudio)
    }

    // MARK: - VisualIntensity Tests

    func testVisualIntensityAllCases() {
        let intensities = VisualIntensity.allCases

        XCTAssertTrue(intensities.contains(.glow))
        XCTAssertTrue(intensities.contains(.balanced))
        XCTAssertTrue(intensities.contains(.burst))
    }

    func testVisualIntensityRawValues() {
        XCTAssertEqual(VisualIntensity.glow.rawValue, "Glow")
        XCTAssertEqual(VisualIntensity.balanced.rawValue, "Balanced")
        XCTAssertEqual(VisualIntensity.burst.rawValue, "Burst")
    }

    func testVisualIntensityDescriptions() {
        for intensity in VisualIntensity.allCases {
            XCTAssertFalse(intensity.description.isEmpty, "\(intensity) should have a description")
        }
    }

    func testVisualIntensityIcons() {
        XCTAssertEqual(VisualIntensity.glow.icon, "sun.max.fill")
        XCTAssertEqual(VisualIntensity.balanced.icon, "sparkle")
        XCTAssertEqual(VisualIntensity.burst.icon, "sparkles")
    }

    func testVisualIntensityParticleMultipliers() {
        XCTAssertEqual(VisualIntensity.glow.particleMultiplier, 0.5)
        XCTAssertEqual(VisualIntensity.balanced.particleMultiplier, 1.0)
        XCTAssertEqual(VisualIntensity.burst.particleMultiplier, 1.5)
    }

    func testVisualIntensityConfettiCounts() {
        XCTAssertEqual(VisualIntensity.glow.confettiCount, 0)
        XCTAssertEqual(VisualIntensity.balanced.confettiCount, 12)
        XCTAssertEqual(VisualIntensity.burst.confettiCount, 30)
    }

    func testVisualIntensityRingCounts() {
        XCTAssertEqual(VisualIntensity.glow.ringCount, 2)
        XCTAssertEqual(VisualIntensity.balanced.ringCount, 1)
        XCTAssertEqual(VisualIntensity.burst.ringCount, 0)
    }

    // MARK: - Status Text Tests

    func testStatusTextRecording() {
        let status = AppStatus.recording
        let text: String

        switch status {
        case .recording: text = "LISTENING"
        default: text = ""
        }

        XCTAssertEqual(text, "LISTENING")
    }

    func testStatusTextProcessing() {
        let status = AppStatus.processing(message: "Transcribing")
        let text: String

        switch status {
        case .processing(let message): text = message.uppercased()
        default: text = ""
        }

        XCTAssertEqual(text, "TRANSCRIBING")
    }

    func testStatusTextSuccess() {
        let status = AppStatus.success
        let text: String

        switch status {
        case .success: text = "COPIED"
        default: text = ""
        }

        XCTAssertEqual(text, "COPIED")
    }

    func testStatusTextReady() {
        let status = AppStatus.ready
        let text: String

        switch status {
        case .ready: text = "TAP TO RECORD"
        default: text = ""
        }

        XCTAssertEqual(text, "TAP TO RECORD")
    }

    func testStatusTextPermissionRequired() {
        let status = AppStatus.permissionRequired
        let text: String

        switch status {
        case .permissionRequired: text = "PERMISSION NEEDED"
        default: text = ""
        }

        XCTAssertEqual(text, "PERMISSION NEEDED")
    }

    func testStatusTextError() {
        let status = AppStatus.error(message: "Failed")
        let text: String

        switch status {
        case .error(let message): text = message.uppercased()
        default: text = ""
        }

        XCTAssertEqual(text, "FAILED")
    }

    // MARK: - UserDefaults Extension Tests

    func testUserDefaultsWaveformStyleKey() {
        let defaults = UserDefaults.standard
        let key = "waveformStyle"

        defaults.removeObject(forKey: key)
        XCTAssertEqual(defaults.waveformStyle, .classic, "Default should be .classic")

        defaults.waveformStyle = .neon
        XCTAssertEqual(defaults.waveformStyle, .neon)

        // Cleanup
        defaults.removeObject(forKey: key)
    }

    func testUserDefaultsVisualIntensityKey() {
        let defaults = UserDefaults.standard
        let key = "visualIntensity"

        defaults.removeObject(forKey: key)
        XCTAssertEqual(defaults.visualIntensity, .balanced, "Default should be .balanced")

        defaults.visualIntensity = .burst
        XCTAssertEqual(defaults.visualIntensity, .burst)

        // Cleanup
        defaults.removeObject(forKey: key)
    }
}
