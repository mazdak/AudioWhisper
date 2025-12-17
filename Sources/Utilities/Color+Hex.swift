import SwiftUI
#if os(macOS)
import AppKit
#endif

internal extension Color {
    init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        var string = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        if string.count == 3 {
            string = string.map { "\($0)\($0)" }.joined()
        }
        guard string.count == 6,
              let value = Int(string, radix: 16) else {
            return nil
        }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }

    func hexString() -> String? {
        #if os(macOS)
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else {
            return nil
        }
        let red = Int(round(nsColor.redComponent * 255))
        let green = Int(round(nsColor.greenComponent * 255))
        let blue = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
        #else
        return nil
        #endif
    }
}
