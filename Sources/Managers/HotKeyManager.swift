import Foundation
import AppKit
import KeyboardShortcuts

// MARK: - Key Enum (drop-in replacement for HotKey.Key)
//
// We replaced the soffes/HotKey library with sindresorhus/KeyboardShortcuts.
// HotKey exposed a `Key` enum that several files (HotKeyRecorderView,
// DashboardRecordingView, tests) consume directly. To keep the public surface
// of those files unchanged, we re-publish the same enum here. It bridges to
// `KeyboardShortcuts.Key` via `keyboardShortcutsKey`.
internal enum Key: Hashable {
    // Letters
    case a, b, c, d, e, f, g, h, i, j, k, l, m
    case n, o, p, q, r, s, t, u, v, w, x, y, z

    // Numbers (HotKey naming)
    case zero, one, two, three, four, five, six, seven, eight, nine

    // Function
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10
    case f11, f12, f13, f14, f15, f16, f17, f18, f19, f20

    // Punctuation / misc
    case `return`, tab, space, delete, escape
    case equal, minus, leftBracket, rightBracket, quote, semicolon
    case backslash, comma, slash, period, grave

    // Arrows
    case upArrow, downArrow, leftArrow, rightArrow

    /// Bridge to KeyboardShortcuts.Key.
    var keyboardShortcutsKey: KeyboardShortcuts.Key {
        switch self {
        case .a: return .a
        case .b: return .b
        case .c: return .c
        case .d: return .d
        case .e: return .e
        case .f: return .f
        case .g: return .g
        case .h: return .h
        case .i: return .i
        case .j: return .j
        case .k: return .k
        case .l: return .l
        case .m: return .m
        case .n: return .n
        case .o: return .o
        case .p: return .p
        case .q: return .q
        case .r: return .r
        case .s: return .s
        case .t: return .t
        case .u: return .u
        case .v: return .v
        case .w: return .w
        case .x: return .x
        case .y: return .y
        case .z: return .z
        case .zero: return .zero
        case .one: return .one
        case .two: return .two
        case .three: return .three
        case .four: return .four
        case .five: return .five
        case .six: return .six
        case .seven: return .seven
        case .eight: return .eight
        case .nine: return .nine
        case .f1: return .f1
        case .f2: return .f2
        case .f3: return .f3
        case .f4: return .f4
        case .f5: return .f5
        case .f6: return .f6
        case .f7: return .f7
        case .f8: return .f8
        case .f9: return .f9
        case .f10: return .f10
        case .f11: return .f11
        case .f12: return .f12
        case .f13: return .f13
        case .f14: return .f14
        case .f15: return .f15
        case .f16: return .f16
        case .f17: return .f17
        case .f18: return .f18
        case .f19: return .f19
        case .f20: return .f20
        case .return: return .return
        case .tab: return .tab
        case .space: return .space
        case .delete: return .delete
        case .escape: return .escape
        case .equal: return .equal
        case .minus: return .minus
        case .leftBracket: return .leftBracket
        case .rightBracket: return .rightBracket
        case .quote: return .quote
        case .semicolon: return .semicolon
        case .backslash: return .backslash
        case .comma: return .comma
        case .slash: return .slash
        case .period: return .period
        case .grave: return .backtick
        case .upArrow: return .upArrow
        case .downArrow: return .downArrow
        case .leftArrow: return .leftArrow
        case .rightArrow: return .rightArrow
        }
    }
}

// MARK: - KeyboardShortcuts Name
extension KeyboardShortcuts.Name {
    /// Global toggle-recording shortcut. The default value is set the first
    /// time `HotKeyManager` boots from `AppDefaults.globalHotkey` so that the
    /// user's stored preference always wins.
    static let toggleRecording = Self("audioWhisper.toggleRecording")
}

// MARK: - HotKeyManager
//
// Preserves the public surface of the original HotKey-backed manager:
//   - `init(onHotKeyPressed:)`
//   - listens for `.updateGlobalHotkey` notifications carrying a string
//   - reads `AppDefaults.globalHotkey` on initialization
//
// Internally, the manager parses the string ("⌘⇧Space" etc.) into a
// `KeyboardShortcuts.Shortcut` and registers a key-down handler with the
// KeyboardShortcuts library. AppDefaults remains the canonical store; the
// KeyboardShortcuts UserDefaults entry is a runtime mirror.
internal class HotKeyManager {
    private let onHotKeyPressed: () -> Void

    init(onHotKeyPressed: @escaping () -> Void) {
        self.onHotKeyPressed = onHotKeyPressed
        setupObservers()
        registerKeyDownHandler()
        setupInitialHotKey()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateHotKey),
            name: .updateGlobalHotkey,
            object: nil
        )
    }

    private func registerKeyDownHandler() {
        // Remove any handler previously installed by another instance so we
        // don't accumulate them when multiple managers are created (e.g. in
        // tests). The handler we install below is the only one for the
        // `.toggleRecording` name afterwards.
        KeyboardShortcuts.removeHandler(for: .toggleRecording)
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            self?.onHotKeyPressed()
        }
    }

    private func setupInitialHotKey() {
        setupHotKeyFromString(AppDefaults.globalHotkey)
    }

    @objc private func updateHotKey(_ notification: Notification) {
        if let newHotkeyString = notification.object as? String {
            setupHotKeyFromString(newHotkeyString)
        }
    }

    private func setupHotKeyFromString(_ hotkeyString: String) {
        let (key, modifiers) = Self.parseHotkeyString(hotkeyString)

        guard let key = key else {
            // Invalid / empty: clear the active shortcut so nothing fires.
            KeyboardShortcuts.setShortcut(nil, for: .toggleRecording)
            return
        }

        let shortcut = KeyboardShortcuts.Shortcut(
            key.keyboardShortcutsKey,
            modifiers: modifiers
        )
        KeyboardShortcuts.setShortcut(shortcut, for: .toggleRecording)
    }

    // MARK: - Parsing
    //
    // Same string format as before ("⌘⇧Space", "⌘A", "F5", etc.). Extracted
    // as a static helper so callers (e.g. tests, future migrations) can use
    // it without instantiating the manager.
    internal static func parseHotkeyString(_ hotkeyString: String) -> (Key?, NSEvent.ModifierFlags) {
        var modifiers: NSEvent.ModifierFlags = []
        var keyString = hotkeyString

        if keyString.contains("⌘") {
            modifiers.insert(.command)
            keyString = keyString.replacingOccurrences(of: "⌘", with: "")
        }
        if keyString.contains("⇧") {
            modifiers.insert(.shift)
            keyString = keyString.replacingOccurrences(of: "⇧", with: "")
        }
        if keyString.contains("⌥") {
            modifiers.insert(.option)
            keyString = keyString.replacingOccurrences(of: "⌥", with: "")
        }
        if keyString.contains("⌃") {
            modifiers.insert(.control)
            keyString = keyString.replacingOccurrences(of: "⌃", with: "")
        }

        return (stringToKey(keyString), modifiers)
    }

    private static func stringToKey(_ keyString: String) -> Key? {
        switch keyString.uppercased() {
        // Function keys
        case "F1": return .f1
        case "F2": return .f2
        case "F3": return .f3
        case "F4": return .f4
        case "F5": return .f5
        case "F6": return .f6
        case "F7": return .f7
        case "F8": return .f8
        case "F9": return .f9
        case "F10": return .f10
        case "F11": return .f11
        case "F12": return .f12
        case "F13": return .f13
        case "F14": return .f14
        case "F15": return .f15
        case "F16": return .f16
        case "F17": return .f17
        case "F18": return .f18
        case "F19": return .f19
        case "F20": return .f20
        case "A": return .a
        case "S": return .s
        case "D": return .d
        case "F": return .f
        case "H": return .h
        case "G": return .g
        case "Z": return .z
        case "X": return .x
        case "C": return .c
        case "V": return .v
        case "B": return .b
        case "Q": return .q
        case "W": return .w
        case "E": return .e
        case "R": return .r
        case "Y": return .y
        case "T": return .t
        case "1": return .one
        case "2": return .two
        case "3": return .three
        case "4": return .four
        case "6": return .six
        case "5": return .five
        case "=": return .equal
        case "9": return .nine
        case "7": return .seven
        case "-": return .minus
        case "8": return .eight
        case "0": return .zero
        case "]": return .rightBracket
        case "O": return .o
        case "U": return .u
        case "[": return .leftBracket
        case "I": return .i
        case "P": return .p
        case "⏎": return .return
        case "L": return .l
        case "J": return .j
        case "'": return .quote
        case "K": return .k
        case ";": return .semicolon
        case "\\": return .backslash
        case ",": return .comma
        case "/": return .slash
        case "N": return .n
        case "M": return .m
        case ".": return .period
        case "⇥": return .tab
        case "SPACE": return .space
        case "`": return .grave
        case "⌫": return .delete
        case "⎋": return .escape
        case "↑": return .upArrow
        case "↓": return .downArrow
        case "←": return .leftArrow
        case "→": return .rightArrow
        default: return nil
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // Note: we intentionally do NOT call removeHandler here. The handler
        // captures `self` weakly, so it will no-op after deallocation. Tests
        // create many managers in sequence and the next instance's
        // `registerKeyDownHandler` will overwrite the slot.
    }
}
