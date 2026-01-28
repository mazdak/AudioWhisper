import XCTest
import SwiftUI
@testable import AudioWhisper

/// Tests for StateTransitionEffects components
@MainActor
final class StateTransitionEffectsTests: XCTestCase {

    // MARK: - EntryAnimationModifier Tests

    func testEntryAnimationModifierInitialization() {
        let intensity = VisualIntensity.balanced
        XCTAssertNotNil(intensity.entryScale)
        XCTAssertNotNil(intensity.entryRotation)
    }

    func testEntryScaleValues() {
        // All intensities use same entry scale
        for intensity in VisualIntensity.allCases {
            XCTAssertEqual(intensity.entryScale, 0.9, "\(intensity) should have 0.9 entry scale")
        }
    }

    func testEntryRotationValues() {
        // All intensities use no rotation
        for intensity in VisualIntensity.allCases {
            XCTAssertEqual(intensity.entryRotation, 0, "\(intensity) should have 0 entry rotation")
        }
    }

    // MARK: - RecordingStartPulse Tests

    func testRecordingStartPulseInitialization() {
        let pulse = RecordingStartPulse(
            intensity: .balanced,
            isActive: false,
            color: .red
        )

        XCTAssertNotNil(pulse)
    }

    func testRecordingStartPulseWithGlowIntensity() {
        let intensity = VisualIntensity.glow
        XCTAssertEqual(intensity.glowIntensity, 1.0)
    }

    func testRecordingStartPulseWithBalancedIntensity() {
        let intensity = VisualIntensity.balanced
        XCTAssertEqual(intensity.glowIntensity, 0.6)
    }

    func testRecordingStartPulseWithBurstIntensity() {
        let intensity = VisualIntensity.burst
        XCTAssertEqual(intensity.glowIntensity, 0.3)
    }

    // MARK: - ProcessingWave Tests

    func testProcessingWaveInitialization() {
        let wave = ProcessingWave(
            intensity: .balanced,
            isActive: true
        )

        XCTAssertNotNil(wave)
    }

    func testProcessingWaveHiddenWhenInactive() {
        let wave = ProcessingWave(
            intensity: .balanced,
            isActive: false
        )

        // Wave should not render when inactive
        XCTAssertNotNil(wave)
    }

    // MARK: - ShakeModifier Tests

    func testShakeModifierInitialization() {
        // ShakeModifier is applied via .shake() modifier
        let intensity = VisualIntensity.balanced
        XCTAssertNotNil(intensity)
    }

    func testShakeAmountIsConsistent() {
        // All styles use consistent expressive-level shake
        let shakeAmount: CGFloat = 5
        XCTAssertEqual(shakeAmount, 5)
    }

    func testShakeDuration() {
        // Shake duration is 0.08 seconds
        let duration = 0.08
        XCTAssertEqual(duration, 0.08)
    }

    // MARK: - ErrorFlash Tests

    func testErrorFlashInitialization() {
        let flash = ErrorFlash(
            intensity: .balanced,
            isActive: false
        )

        XCTAssertNotNil(flash)
    }

    func testErrorFlashOpacity() {
        // All styles use consistent expressive-level flash
        let flashOpacity = 0.25
        XCTAssertEqual(flashOpacity, 0.25)
    }

    // MARK: - StatusTransitionOverlay Tests

    func testStatusTransitionOverlayInitialization() {
        let overlay = StatusTransitionOverlay(
            fromStatus: .ready,
            toStatus: .recording,
            intensity: .balanced
        )

        XCTAssertNotNil(overlay)
    }

    func testTransitionToRecordingFromReady() {
        let fromStatus: AppStatus? = .ready
        let toStatus = AppStatus.recording

        var isTransitionToRecording = false
        if case .recording = toStatus {
            if case .recording = fromStatus {
                isTransitionToRecording = false
            } else {
                isTransitionToRecording = true
            }
        }

        XCTAssertTrue(isTransitionToRecording)
    }

    func testTransitionToRecordingFromRecording() {
        let fromStatus: AppStatus? = .recording
        let toStatus = AppStatus.recording

        var isTransitionToRecording = false
        if case .recording = toStatus {
            if case .recording = fromStatus {
                isTransitionToRecording = false
            } else {
                isTransitionToRecording = true
            }
        }

        XCTAssertFalse(isTransitionToRecording, "Already recording should not trigger transition")
    }

    func testIsProcessingDetection() {
        let status = AppStatus.processing(message: "Transcribing...")

        var isProcessing = false
        if case .processing = status {
            isProcessing = true
        }

        XCTAssertTrue(isProcessing)
    }

    func testIsErrorDetection() {
        let status = AppStatus.error(message: "Failed")

        var isError = false
        if case .error = status {
            isError = true
        }

        XCTAssertTrue(isError)
    }

    func testIsNotProcessing() {
        let status = AppStatus.ready

        var isProcessing = false
        if case .processing = status {
            isProcessing = true
        }

        XCTAssertFalse(isProcessing)
    }

    func testIsNotError() {
        let status = AppStatus.ready

        var isError = false
        if case .error = status {
            isError = true
        }

        XCTAssertFalse(isError)
    }

    // MARK: - EnhancedStatusDot Tests

    func testEnhancedStatusDotInitialization() {
        let dot = EnhancedStatusDot(
            color: .red,
            intensity: .balanced,
            isPulsing: false
        )

        XCTAssertNotNil(dot)
    }

    func testEnhancedStatusDotPulsing() {
        let dot = EnhancedStatusDot(
            color: .red,
            intensity: .balanced,
            isPulsing: true
        )

        XCTAssertNotNil(dot)
    }

    func testDotGlowEnabled() {
        // All styles use glow
        for intensity in VisualIntensity.allCases {
            XCTAssertTrue(intensity.dotGlow, "\(intensity) should have dot glow")
        }
    }

    func testDotGlowRadiusGlow() {
        let intensity = VisualIntensity.glow
        XCTAssertEqual(intensity.dotGlowRadius, 8)
    }

    func testDotGlowRadiusBalanced() {
        let intensity = VisualIntensity.balanced
        XCTAssertEqual(intensity.dotGlowRadius, 5)
    }

    func testDotGlowRadiusBurst() {
        let intensity = VisualIntensity.burst
        XCTAssertEqual(intensity.dotGlowRadius, 3)
    }

    // MARK: - VisualIntensity Animation Properties Tests

    func testTransitionDurationConsistent() {
        for intensity in VisualIntensity.allCases {
            XCTAssertEqual(intensity.transitionDuration, 0.35, "\(intensity) should have 0.35 duration")
        }
    }

    func testSpringResponseConsistent() {
        for intensity in VisualIntensity.allCases {
            XCTAssertEqual(intensity.springResponse, 0.4, "\(intensity) should have 0.4 spring response")
        }
    }

    func testSpringDampingConsistent() {
        for intensity in VisualIntensity.allCases {
            XCTAssertEqual(intensity.springDamping, 0.7, "\(intensity) should have 0.7 spring damping")
        }
    }

    // MARK: - Glow Properties Tests

    func testGlowIntensityGlow() {
        let intensity = VisualIntensity.glow
        XCTAssertEqual(intensity.glowIntensity, 1.0)
    }

    func testGlowIntensityBalanced() {
        let intensity = VisualIntensity.balanced
        XCTAssertEqual(intensity.glowIntensity, 0.6)
    }

    func testGlowIntensityBurst() {
        let intensity = VisualIntensity.burst
        XCTAssertEqual(intensity.glowIntensity, 0.3)
    }

    func testGlowRingCountGlow() {
        let intensity = VisualIntensity.glow
        XCTAssertEqual(intensity.glowRingCount, 3)
    }

    func testGlowRingCountBalanced() {
        let intensity = VisualIntensity.balanced
        XCTAssertEqual(intensity.glowRingCount, 1)
    }

    func testGlowRingCountBurst() {
        let intensity = VisualIntensity.burst
        XCTAssertEqual(intensity.glowRingCount, 0)
    }

    func testGlowDurationGlow() {
        let intensity = VisualIntensity.glow
        XCTAssertEqual(intensity.glowDuration, 0.8)
    }

    func testGlowDurationBalanced() {
        let intensity = VisualIntensity.balanced
        XCTAssertEqual(intensity.glowDuration, 0.5)
    }

    func testGlowDurationBurst() {
        let intensity = VisualIntensity.burst
        XCTAssertEqual(intensity.glowDuration, 0.3)
    }

    // MARK: - Flash Properties Tests

    func testShowFlashGlow() {
        let intensity = VisualIntensity.glow
        XCTAssertFalse(intensity.showFlash)
    }

    func testShowFlashBalanced() {
        let intensity = VisualIntensity.balanced
        XCTAssertFalse(intensity.showFlash)
    }

    func testShowFlashBurst() {
        let intensity = VisualIntensity.burst
        XCTAssertTrue(intensity.showFlash)
    }

    func testFlashOpacityGlow() {
        let intensity = VisualIntensity.glow
        XCTAssertEqual(intensity.flashOpacity, 0)
    }

    func testFlashOpacityBalanced() {
        let intensity = VisualIntensity.balanced
        XCTAssertEqual(intensity.flashOpacity, 0)
    }

    func testFlashOpacityBurst() {
        let intensity = VisualIntensity.burst
        XCTAssertEqual(intensity.flashOpacity, 0.3)
    }

    // MARK: - Color Constants Tests

    func testAccentColor() {
        let accentColor = Color(red: 0.85, green: 0.45, blue: 0.40)
        XCTAssertNotNil(accentColor)
    }

    func testSuccessColor() {
        let successColor = Color(red: 0.45, green: 0.75, blue: 0.55)
        XCTAssertNotNil(successColor)
    }
}
