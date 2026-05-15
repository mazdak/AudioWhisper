import SwiftUI

/// Color theme presets for waveform visualizers
enum ColorTheme: String, CaseIterable, Identifiable, Codable {
    case neonNights = "Neon Nights"
    case warmSunset = "Warm Sunset"
    case ocean = "Ocean"
    case monochrome = "Monochrome"

    var id: String { rawValue }

    /// Primary color for the theme
    var primary: Color {
        switch self {
        case .neonNights:
            return Color(red: 0.0, green: 0.9, blue: 0.95)  // Cyan
        case .warmSunset:
            return Color(red: 1.0, green: 0.5, blue: 0.2)   // Orange
        case .ocean:
            return Color(red: 0.2, green: 0.6, blue: 0.9)   // Blue
        case .monochrome:
            return Color(red: 0.9, green: 0.9, blue: 0.9)   // White
        }
    }

    /// Secondary color for the theme
    var secondary: Color {
        switch self {
        case .neonNights:
            return Color(red: 0.95, green: 0.2, blue: 0.8)  // Magenta
        case .warmSunset:
            return Color(red: 0.95, green: 0.3, blue: 0.3)  // Red
        case .ocean:
            return Color(red: 0.0, green: 0.8, blue: 0.8)   // Teal
        case .monochrome:
            return Color(red: 0.6, green: 0.6, blue: 0.6)   // Gray
        }
    }

    /// Accent color for the theme
    var accent: Color {
        switch self {
        case .neonNights:
            return Color(red: 1.0, green: 0.85, blue: 0.0)  // Yellow
        case .warmSunset:
            return Color(red: 1.0, green: 0.8, blue: 0.2)   // Yellow
        case .ocean:
            return Color(red: 0.4, green: 0.9, blue: 0.7)   // Aqua
        case .monochrome:
            return Color(red: 1.0, green: 1.0, blue: 1.0)   // White
        }
    }

    /// Array of gradient colors for spectrum/bars
    var gradientColors: [Color] {
        switch self {
        case .neonNights:
            return [
                Color(red: 0.0, green: 0.9, blue: 0.95),    // Cyan
                Color(red: 0.2, green: 0.9, blue: 0.6),     // Teal
                Color(red: 0.4, green: 0.9, blue: 0.3),     // Green
                Color(red: 0.8, green: 0.9, blue: 0.2),     // Yellow-green
                Color(red: 1.0, green: 0.8, blue: 0.2),     // Yellow
                Color(red: 1.0, green: 0.5, blue: 0.2),     // Orange
                Color(red: 0.95, green: 0.2, blue: 0.4),    // Red-pink
                Color(red: 0.95, green: 0.2, blue: 0.8),    // Magenta
            ]
        case .warmSunset:
            return [
                Color(red: 1.0, green: 0.9, blue: 0.4),     // Light yellow
                Color(red: 1.0, green: 0.7, blue: 0.3),     // Yellow-orange
                Color(red: 1.0, green: 0.5, blue: 0.2),     // Orange
                Color(red: 0.95, green: 0.35, blue: 0.25),  // Red-orange
                Color(red: 0.9, green: 0.2, blue: 0.3),     // Red
                Color(red: 0.8, green: 0.15, blue: 0.4),    // Deep red
                Color(red: 0.6, green: 0.1, blue: 0.5),     // Purple
                Color(red: 0.4, green: 0.1, blue: 0.5),     // Deep purple
            ]
        case .ocean:
            return [
                Color(red: 0.7, green: 0.95, blue: 0.95),   // Light cyan
                Color(red: 0.4, green: 0.9, blue: 0.9),     // Cyan
                Color(red: 0.2, green: 0.8, blue: 0.9),     // Light blue
                Color(red: 0.2, green: 0.6, blue: 0.9),     // Blue
                Color(red: 0.2, green: 0.4, blue: 0.8),     // Medium blue
                Color(red: 0.15, green: 0.3, blue: 0.7),    // Deep blue
                Color(red: 0.1, green: 0.2, blue: 0.5),     // Navy
                Color(red: 0.05, green: 0.1, blue: 0.3),    // Deep navy
            ]
        case .monochrome:
            return [
                Color(red: 1.0, green: 1.0, blue: 1.0),     // White
                Color(red: 0.9, green: 0.9, blue: 0.9),     // Light gray
                Color(red: 0.8, green: 0.8, blue: 0.8),     // Gray
                Color(red: 0.7, green: 0.7, blue: 0.7),     // Medium gray
                Color(red: 0.6, green: 0.6, blue: 0.6),     // Gray
                Color(red: 0.5, green: 0.5, blue: 0.5),     // Dark gray
                Color(red: 0.4, green: 0.4, blue: 0.4),     // Darker gray
                Color(red: 0.3, green: 0.3, blue: 0.3),     // Very dark gray
            ]
        }
    }

    /// Human-readable description
    var description: String {
        switch self {
        case .neonNights:
            return "Vibrant cyan, magenta, and yellow"
        case .warmSunset:
            return "Warm oranges, reds, and purples"
        case .ocean:
            return "Cool blues and teals"
        case .monochrome:
            return "Clean white and gray"
        }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    private static let colorThemeKey = "colorTheme"

    var colorTheme: ColorTheme {
        get {
            guard let rawValue = string(forKey: Self.colorThemeKey),
                  let theme = ColorTheme(rawValue: rawValue) else {
                return .neonNights
            }
            return theme
        }
        set {
            set(newValue.rawValue, forKey: Self.colorThemeKey)
        }
    }
}

// MARK: - Waveform Palette
/// Foreground/background colors used by the WaveformContainer chrome.
/// Kept separate from per-style `ColorTheme` gradients (which apply *inside* each visualizer).
enum WaveformPalette {
    /// Classic monochrome chrome (background, primary bar, muted state, success, accent/error).
    static let classic: [Color] = [
        Color(red: 0.04, green: 0.04, blue: 0.04),
        Color(red: 0.85, green: 0.83, blue: 0.80),
        Color(red: 0.35, green: 0.34, blue: 0.33),
        Color(red: 0.45, green: 0.75, blue: 0.55),
        Color(red: 0.85, green: 0.45, blue: 0.40)
    ]

    static var background: Color { classic[0] }
    static var bar: Color { classic[1] }
    static var muted: Color { classic[2] }
    static var success: Color { classic[3] }
    static var accent: Color { classic[4] }
}

// MARK: - Particle Palette
/// Default colors used by the neon-style particle overlay.
enum ParticlePalette {
    static let defaults: [Color] = [
        Color(red: 0.0, green: 0.9, blue: 0.95),   // Cyan
        Color(red: 0.95, green: 0.2, blue: 0.8),   // Magenta
        Color(red: 1.0, green: 0.85, blue: 0.0),   // Yellow
        Color(red: 0.4, green: 0.9, blue: 0.5)     // Green
    ]
}
