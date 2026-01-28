import XCTest
import SwiftUI
import AppKit
@testable import AudioWhisper

/// Tests for GlassBackground visual effect component
@MainActor
final class GlassBackgroundTests: XCTestCase {

    // MARK: - Initialization Tests

    func testGlassBackgroundInitializationWithGlow() {
        let glass = GlassBackground(intensity: .glow)

        XCTAssertNotNil(glass)
    }

    func testGlassBackgroundInitializationWithBalanced() {
        let glass = GlassBackground(intensity: .balanced)

        XCTAssertNotNil(glass)
    }

    func testGlassBackgroundInitializationWithBurst() {
        let glass = GlassBackground(intensity: .burst)

        XCTAssertNotNil(glass)
    }

    func testGlassBackgroundDefaultCornerRadius() {
        let glass = GlassBackground(intensity: .balanced)

        XCTAssertEqual(glass.cornerRadius, 12)
    }

    func testGlassBackgroundCustomCornerRadius() {
        let glass = GlassBackground(intensity: .balanced, cornerRadius: 20)

        XCTAssertEqual(glass.cornerRadius, 20)
    }

    // MARK: - NSViewRepresentable Tests

    func testMakeNSViewCreatesVisualEffectView() {
        let glass = GlassBackground(intensity: .balanced)
        let context = MockContext()

        let effectView = glass.makeNSView(context: context)

        XCTAssertTrue(effectView is NSVisualEffectView)
    }

    func testMakeNSViewSetsStateToActive() {
        let glass = GlassBackground(intensity: .balanced)
        let context = MockContext()

        let effectView = glass.makeNSView(context: context)

        XCTAssertEqual(effectView.state, .active)
    }

    func testMakeNSViewSetsWantsLayer() {
        let glass = GlassBackground(intensity: .balanced)
        let context = MockContext()

        let effectView = glass.makeNSView(context: context)

        XCTAssertTrue(effectView.wantsLayer)
    }

    func testMakeNSViewSetsCornerRadius() {
        let glass = GlassBackground(intensity: .balanced, cornerRadius: 16)
        let context = MockContext()

        let effectView = glass.makeNSView(context: context)

        XCTAssertEqual(effectView.layer?.cornerRadius, 16)
    }

    func testMakeNSViewSetsMasksToBounds() {
        let glass = GlassBackground(intensity: .balanced)
        let context = MockContext()

        let effectView = glass.makeNSView(context: context)

        XCTAssertEqual(effectView.layer?.masksToBounds, true)
    }

    func testMakeNSViewSetsMaterial() {
        let glass = GlassBackground(intensity: .balanced)
        let context = MockContext()

        let effectView = glass.makeNSView(context: context)

        XCTAssertEqual(effectView.material, .hudWindow)
    }

    func testMakeNSViewSetsBlendingMode() {
        let glass = GlassBackground(intensity: .balanced)
        let context = MockContext()

        let effectView = glass.makeNSView(context: context)

        XCTAssertEqual(effectView.blendingMode, .behindWindow)
    }

    func testMakeNSViewSetsAlphaValue() {
        let glass = GlassBackground(intensity: .balanced)
        let context = MockContext()

        let effectView = glass.makeNSView(context: context)

        XCTAssertEqual(effectView.alphaValue, 0.85, accuracy: 0.01)
    }

    // MARK: - Update NSView Tests

    func testUpdateNSViewUpdatesCornerRadius() {
        let glass = GlassBackground(intensity: .balanced, cornerRadius: 20)
        let context = MockContext()

        let effectView = glass.makeNSView(context: context)
        effectView.layer?.cornerRadius = 10 // Set different value

        glass.updateNSView(effectView, context: context)

        XCTAssertEqual(effectView.layer?.cornerRadius, 20)
    }

    // MARK: - View Modifier Tests

    func testGlassBackgroundModifierWithGlow() {
        let intensity = VisualIntensity.glow
        XCTAssertTrue(intensity.showGlass)
    }

    func testGlassBackgroundModifierWithBalanced() {
        let intensity = VisualIntensity.balanced
        XCTAssertTrue(intensity.showGlass)
    }

    func testGlassBackgroundModifierWithBurst() {
        let intensity = VisualIntensity.burst
        XCTAssertTrue(intensity.showGlass)
    }

    func testAllIntensitiesShowGlass() {
        for intensity in VisualIntensity.allCases {
            XCTAssertTrue(intensity.showGlass, "\(intensity) should show glass")
        }
    }

    // MARK: - Intensity Property Tests

    func testGlassBackgroundStoresIntensity() {
        let glass = GlassBackground(intensity: .glow)
        XCTAssertEqual(glass.intensity, .glow)
    }

    // MARK: - Effect Configuration Consistency Tests

    func testAllIntensitiesUseSameMaterial() {
        // All styles use consistent frosted glass
        let intensities: [VisualIntensity] = [.glow, .balanced, .burst]

        for intensity in intensities {
            let glass = GlassBackground(intensity: intensity)
            let context = MockContext()
            let effectView = glass.makeNSView(context: context)

            XCTAssertEqual(effectView.material, .hudWindow, "\(intensity) should use .hudWindow")
        }
    }

    func testAllIntensitiesUseSameBlendingMode() {
        let intensities: [VisualIntensity] = [.glow, .balanced, .burst]

        for intensity in intensities {
            let glass = GlassBackground(intensity: intensity)
            let context = MockContext()
            let effectView = glass.makeNSView(context: context)

            XCTAssertEqual(effectView.blendingMode, .behindWindow, "\(intensity) should use .behindWindow")
        }
    }

    func testAllIntensitiesUseSameAlpha() {
        let intensities: [VisualIntensity] = [.glow, .balanced, .burst]

        for intensity in intensities {
            let glass = GlassBackground(intensity: intensity)
            let context = MockContext()
            let effectView = glass.makeNSView(context: context)

            XCTAssertEqual(effectView.alphaValue, 0.85, accuracy: 0.01, "\(intensity) should use 0.85 alpha")
        }
    }

    // MARK: - Corner Radius Variations Tests

    func testZeroCornerRadius() {
        let glass = GlassBackground(intensity: .balanced, cornerRadius: 0)
        let context = MockContext()

        let effectView = glass.makeNSView(context: context)

        XCTAssertEqual(effectView.layer?.cornerRadius, 0)
    }

    func testLargeCornerRadius() {
        let glass = GlassBackground(intensity: .balanced, cornerRadius: 100)
        let context = MockContext()

        let effectView = glass.makeNSView(context: context)

        XCTAssertEqual(effectView.layer?.cornerRadius, 100)
    }
}

// MARK: - Mock Context

private struct MockContext: NSViewRepresentableContext {
    typealias NSViewType = NSVisualEffectView
    typealias Coordinator = Void

    var coordinator: Void { () }
    var transaction: Transaction { Transaction() }
    var environment: EnvironmentValues { EnvironmentValues() }
}

extension GlassBackgroundTests {
    /// Extension to create a mock context for testing
    struct MockContext: NSViewRepresentableContext {
        typealias NSViewType = NSVisualEffectView
        typealias Coordinator = Void

        var coordinator: Void { () }
        var transaction: Transaction { Transaction() }
        var environment: EnvironmentValues { EnvironmentValues() }
    }
}
