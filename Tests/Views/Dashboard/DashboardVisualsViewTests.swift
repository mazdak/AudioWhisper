import XCTest
@testable import AudioWhisper

final class DashboardVisualsViewTests: XCTestCase {

    // MARK: - Waveform Style Icons

    func testStyleIconForAllStyles() {
        XCTAssertEqual(DashboardVisualsView.testableStyleIcon(for: .classic), "waveform")
        XCTAssertEqual(DashboardVisualsView.testableStyleIcon(for: .neon), "sparkles")
        XCTAssertEqual(DashboardVisualsView.testableStyleIcon(for: .spectrum), "chart.bar.fill")
        XCTAssertEqual(DashboardVisualsView.testableStyleIcon(for: .circular), "sun.max.fill")
        XCTAssertEqual(DashboardVisualsView.testableStyleIcon(for: .pulseRings), "dot.radiowaves.left.and.right")
        XCTAssertEqual(DashboardVisualsView.testableStyleIcon(for: .particles), "sparkle")
    }

    func testAllStylesHaveUniqueIcons() {
        let icons = WaveformStyle.allCases.map { DashboardVisualsView.testableStyleIcon(for: $0) }
        let uniqueIcons = Set(icons)

        XCTAssertEqual(icons.count, uniqueIcons.count, "Each waveform style should have a unique icon")
    }

    // MARK: - Waveform Style Parsing

    func testWaveformStyleFromValidValues() {
        XCTAssertEqual(DashboardVisualsView.testableWaveformStyle(from: "Classic"), .classic)
        XCTAssertEqual(DashboardVisualsView.testableWaveformStyle(from: "Neon"), .neon)
        XCTAssertEqual(DashboardVisualsView.testableWaveformStyle(from: "Spectrum"), .spectrum)
        XCTAssertEqual(DashboardVisualsView.testableWaveformStyle(from: "Circular"), .circular)
        XCTAssertEqual(DashboardVisualsView.testableWaveformStyle(from: "Pulse Rings"), .pulseRings)
        XCTAssertEqual(DashboardVisualsView.testableWaveformStyle(from: "Particles"), .particles)
    }

    func testWaveformStyleFromInvalidValue() {
        // Should default to classic
        XCTAssertEqual(DashboardVisualsView.testableWaveformStyle(from: "invalid"), .classic)
        XCTAssertEqual(DashboardVisualsView.testableWaveformStyle(from: ""), .classic)
    }

    // MARK: - Visual Intensity Parsing

    func testVisualIntensityFromValidValues() {
        for intensity in VisualIntensity.allCases {
            XCTAssertEqual(
                DashboardVisualsView.testableVisualIntensity(from: intensity.rawValue),
                intensity
            )
        }
    }

    func testVisualIntensityFromInvalidValue() {
        // Should default to balanced
        XCTAssertEqual(DashboardVisualsView.testableVisualIntensity(from: "invalid"), .balanced)
        XCTAssertEqual(DashboardVisualsView.testableVisualIntensity(from: ""), .balanced)
    }

    // MARK: - Waveform Style Properties

    func testAllWaveformStylesHaveDescriptions() {
        for style in WaveformStyle.allCases {
            XCTAssertFalse(style.description.isEmpty, "Waveform style \(style) should have a description")
        }
    }

    // MARK: - Visual Intensity Properties

    func testAllVisualIntensitiesHaveIcons() {
        for intensity in VisualIntensity.allCases {
            XCTAssertFalse(intensity.icon.isEmpty, "Visual intensity \(intensity) should have an icon")
        }
    }

    func testAllVisualIntensitiesHaveDescriptions() {
        for intensity in VisualIntensity.allCases {
            XCTAssertFalse(intensity.description.isEmpty, "Visual intensity \(intensity) should have a description")
        }
    }
}
