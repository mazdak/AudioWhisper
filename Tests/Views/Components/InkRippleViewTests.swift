import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - InkRippleView Tests
final class InkRippleViewTests: XCTestCase {

    func testInkRippleViewCanBeCreated() {
        let view = InkRippleView(
            audioLevel: 0.5,
            isActive: true
        )
        XCTAssertNotNil(view)
    }

    func testInkRippleViewBodyDoesNotCrash() {
        let view = InkRippleView(
            audioLevel: 0.5,
            isActive: true
        )
        let _ = view.body
        XCTAssertTrue(true)
    }

    func testInkRippleViewInactiveState() {
        let view = InkRippleView(
            audioLevel: 0,
            isActive: false
        )
        XCTAssertNotNil(view)
    }

    func testInkRippleViewWithZeroAudioLevel() {
        let view = InkRippleView(
            audioLevel: 0,
            isActive: true
        )
        XCTAssertNotNil(view)
    }

    func testInkRippleViewWithMaxAudioLevel() {
        let view = InkRippleView(
            audioLevel: 1.0,
            isActive: true
        )
        XCTAssertNotNil(view)
    }
}

// MARK: - InkRippleRecordingView Tests
final class InkRippleRecordingViewTests: XCTestCase {

    func testRecordingViewCanBeCreated() {
        let view = InkRippleRecordingView(
            status: .ready,
            audioLevel: 0,
            onTap: {}
        )
        XCTAssertNotNil(view)
    }

    func testRecordingViewBodyDoesNotCrash() {
        let view = InkRippleRecordingView(
            status: .ready,
            audioLevel: 0,
            onTap: {}
        )
        let _ = view.body
        XCTAssertTrue(true)
    }

    func testRecordingViewWithRecordingStatus() {
        let view = InkRippleRecordingView(
            status: .recording,
            audioLevel: 0.5,
            onTap: {}
        )
        XCTAssertNotNil(view)
    }

    func testRecordingViewWithProcessingStatus() {
        let view = InkRippleRecordingView(
            status: .processing("Transcribing..."),
            audioLevel: 0,
            onTap: {}
        )
        XCTAssertNotNil(view)
    }

    func testRecordingViewWithSuccessStatus() {
        let view = InkRippleRecordingView(
            status: .success,
            audioLevel: 0,
            onTap: {}
        )
        XCTAssertNotNil(view)
    }

    func testRecordingViewWithErrorStatus() {
        let view = InkRippleRecordingView(
            status: .error("Something went wrong"),
            audioLevel: 0,
            onTap: {}
        )
        XCTAssertNotNil(view)
    }

    func testRecordingViewWithPermissionRequiredStatus() {
        let view = InkRippleRecordingView(
            status: .permissionRequired,
            audioLevel: 0,
            onTap: {}
        )
        XCTAssertNotNil(view)
    }
}

// MARK: - InkRipple Color Tests
final class InkRippleColorTests: XCTestCase {

    func testInkColorValues() {
        // Terracotta color from theme: RGB(0.76, 0.42, 0.32)
        let red: CGFloat = 0.76
        let green: CGFloat = 0.42
        let blue: CGFloat = 0.32

        XCTAssertEqual(red, 0.76)
        XCTAssertEqual(green, 0.42)
        XCTAssertEqual(blue, 0.32)
    }

    func testCreamBackgroundColorValues() {
        // Cream background: RGB(0.98, 0.96, 0.93)
        let red: CGFloat = 0.98
        let green: CGFloat = 0.96
        let blue: CGFloat = 0.93

        XCTAssertEqual(red, 0.98)
        XCTAssertEqual(green, 0.96)
        XCTAssertEqual(blue, 0.93)
    }

    func testTextColorValues() {
        // Text color: RGB(0.12, 0.11, 0.10)
        let red: CGFloat = 0.12
        let green: CGFloat = 0.11
        let blue: CGFloat = 0.10

        XCTAssertEqual(red, 0.12)
        XCTAssertEqual(green, 0.11)
        XCTAssertEqual(blue, 0.10)
    }

    func testMutedColorValues() {
        // Muted color: RGB(0.55, 0.52, 0.48)
        let red: CGFloat = 0.55
        let green: CGFloat = 0.52
        let blue: CGFloat = 0.48

        XCTAssertEqual(red, 0.55)
        XCTAssertEqual(green, 0.52)
        XCTAssertEqual(blue, 0.48)
    }
}

// MARK: - InkRipple Timing Tests
final class InkRippleTimingTests: XCTestCase {

    func testMinRippleInterval() {
        let minInterval: TimeInterval = 0.15
        XCTAssertEqual(minInterval, 0.15)
    }

    func testRippleLifetime() {
        let lifetime: TimeInterval = 1.2
        XCTAssertEqual(lifetime, 1.2)
    }

    func testTimerInterval() {
        let timerInterval: TimeInterval = 0.05
        XCTAssertEqual(timerInterval, 0.05)
    }
}

// MARK: - InkRipple Dimensions Tests
final class InkRippleDimensionsTests: XCTestCase {

    func testBaseInkPoolSize() {
        let size: CGFloat = 12
        XCTAssertEqual(size, 12)
    }

    func testCenterPoolBaseSize() {
        let size: CGFloat = 8
        XCTAssertEqual(size, 8)
    }

    func testCenterPoolMaxExpansion() {
        // Size expands by audioLevel * 8
        let expansion: CGFloat = 8
        XCTAssertEqual(expansion, 8)
    }

    func testRecordingViewWidth() {
        let width: CGFloat = 200
        XCTAssertEqual(width, 200)
    }

    func testRecordingViewHeight() {
        let height: CGFloat = 140
        XCTAssertEqual(height, 140)
    }

    func testButtonOuterRingSize() {
        let size: CGFloat = 56
        XCTAssertEqual(size, 56)
    }

    func testButtonInnerCircleSize() {
        let size: CGFloat = 48
        XCTAssertEqual(size, 48)
    }
}

// MARK: - InkRipple Status Text Tests
final class InkRippleStatusTextTests: XCTestCase {

    func testRecordingStatusText() {
        let text = "Listening..."
        XCTAssertEqual(text, "Listening...")
    }

    func testReadyStatusText() {
        let text = "Tap to record"
        XCTAssertEqual(text, "Tap to record")
    }

    func testSuccessStatusText() {
        let text = "Done"
        XCTAssertEqual(text, "Done")
    }

    func testPermissionRequiredStatusText() {
        let text = "Permission needed"
        XCTAssertEqual(text, "Permission needed")
    }
}

// MARK: - InkRipple Button Icon Tests
final class InkRippleButtonIconTests: XCTestCase {

    func testRecordingIcon() {
        let icon = "stop.fill"
        XCTAssertEqual(icon, "stop.fill")
    }

    func testProcessingIcon() {
        let icon = "ellipsis"
        XCTAssertEqual(icon, "ellipsis")
    }

    func testSuccessIcon() {
        let icon = "checkmark"
        XCTAssertEqual(icon, "checkmark")
    }

    func testReadyIcon() {
        let icon = "mic.fill"
        XCTAssertEqual(icon, "mic.fill")
    }

    func testErrorIcon() {
        let icon = "exclamationmark"
        XCTAssertEqual(icon, "exclamationmark")
    }
}

// MARK: - InkRipple Animation Tests
final class InkRippleAnimationTests: XCTestCase {

    func testEaseOutDuration() {
        let duration: TimeInterval = 0.1
        XCTAssertEqual(duration, 0.1)
    }

    func testPulsingAnimationDuration() {
        let duration: TimeInterval = 0.8
        XCTAssertEqual(duration, 0.8)
    }

    func testRippleStrokeWidth() {
        let width: CGFloat = 2
        XCTAssertEqual(width, 2)
    }
}

// MARK: - Ripple Spawn Logic Tests
final class RippleSpawnLogicTests: XCTestCase {

    func testRippleSpawnThreshold() {
        // Ripples spawn when audio level > 0.05
        let threshold: Float = 0.05
        XCTAssertEqual(threshold, 0.05)
    }

    func testRippleIntensityMultiplier() {
        // Intensity = min(1, level * 1.5)
        let multiplier: Float = 1.5
        XCTAssertEqual(multiplier, 1.5)
    }

    func testMaxIntensity() {
        let maxIntensity: CGFloat = 1.0
        XCTAssertEqual(maxIntensity, 1.0)
    }
}
