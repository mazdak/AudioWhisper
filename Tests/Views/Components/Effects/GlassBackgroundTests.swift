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

    func testGlassBackgroundStoresBalancedIntensity() {
        let glass = GlassBackground(intensity: .balanced)
        XCTAssertEqual(glass.intensity, .balanced)
    }

    func testGlassBackgroundStoresBurstIntensity() {
        let glass = GlassBackground(intensity: .burst)
        XCTAssertEqual(glass.intensity, .burst)
    }

    // MARK: - Corner Radius Property Tests

    func testZeroCornerRadius() {
        let glass = GlassBackground(intensity: .balanced, cornerRadius: 0)
        XCTAssertEqual(glass.cornerRadius, 0)
    }

    func testLargeCornerRadius() {
        let glass = GlassBackground(intensity: .balanced, cornerRadius: 100)
        XCTAssertEqual(glass.cornerRadius, 100)
    }

    func testNegativeCornerRadius() {
        // While unusual, the view should accept any CGFloat
        let glass = GlassBackground(intensity: .balanced, cornerRadius: -5)
        XCTAssertEqual(glass.cornerRadius, -5)
    }

    // MARK: - Visual Intensity Tests

    func testVisualIntensityGlowProperties() {
        let intensity = VisualIntensity.glow
        XCTAssertTrue(intensity.showGlass)
        XCTAssertGreaterThan(intensity.glowIntensity, 0)
    }

    func testVisualIntensityBalancedProperties() {
        let intensity = VisualIntensity.balanced
        XCTAssertTrue(intensity.showGlass)
        XCTAssertGreaterThan(intensity.glowIntensity, 0)
    }

    func testVisualIntensityBurstProperties() {
        let intensity = VisualIntensity.burst
        XCTAssertTrue(intensity.showGlass)
        XCTAssertGreaterThan(intensity.glowIntensity, 0)
    }

    // MARK: - NSVisualEffectView Direct Tests
    // Test the expected configuration of NSVisualEffectView directly

    func testNSVisualEffectViewCanBeCreated() {
        let effectView = NSVisualEffectView()
        XCTAssertNotNil(effectView)
    }

    func testNSVisualEffectViewStateCanBeSetToActive() {
        let effectView = NSVisualEffectView()
        effectView.state = .active
        XCTAssertEqual(effectView.state, .active)
    }

    func testNSVisualEffectViewMaterialCanBeSetToHudWindow() {
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        XCTAssertEqual(effectView.material, .hudWindow)
    }

    func testNSVisualEffectViewBlendingModeCanBeSetToBehindWindow() {
        let effectView = NSVisualEffectView()
        effectView.blendingMode = .behindWindow
        XCTAssertEqual(effectView.blendingMode, .behindWindow)
    }

    func testNSVisualEffectViewAlphaCanBeSet() {
        let effectView = NSVisualEffectView()
        effectView.alphaValue = 0.85
        XCTAssertEqual(effectView.alphaValue, 0.85, accuracy: 0.01)
    }

    func testNSVisualEffectViewWantsLayerCanBeSet() {
        let effectView = NSVisualEffectView()
        effectView.wantsLayer = true
        XCTAssertTrue(effectView.wantsLayer)
    }

    func testNSVisualEffectViewLayerCornerRadiusCanBeSet() {
        let effectView = NSVisualEffectView()
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 16
        XCTAssertEqual(effectView.layer?.cornerRadius, 16)
    }

    func testNSVisualEffectViewLayerMasksToBoundsCanBeSet() {
        let effectView = NSVisualEffectView()
        effectView.wantsLayer = true
        effectView.layer?.masksToBounds = true
        XCTAssertEqual(effectView.layer?.masksToBounds, true)
    }
}
