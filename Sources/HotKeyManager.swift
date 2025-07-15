import Foundation
import AppKit
import HotKey

class HotKeyManager {
    private var hotKey: HotKey?
    private let onHotKeyPressed: () -> Void
    
    init(onHotKeyPressed: @escaping () -> Void) {
        self.onHotKeyPressed = onHotKeyPressed
        setupObservers()
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
    
    private func setupInitialHotKey() {
        let savedHotkey = UserDefaults.standard.string(forKey: "globalHotkey") ?? "⌘⇧Space"
        setupHotKeyFromString(savedHotkey)
    }
    
    @objc private func updateHotKey(_ notification: Notification) {
        if let newHotkeyString = notification.object as? String {
            setupHotKeyFromString(newHotkeyString)
        }
    }
    
    private func setupHotKeyFromString(_ hotkeyString: String) {
        // Clear existing hotkey
        hotKey = nil
        
        // Parse the hotkey string and set up new hotkey
        let (key, modifiers) = parseHotkeyString(hotkeyString)
        
        if let key = key {
            hotKey = HotKey(key: key, modifiers: modifiers)
            hotKey?.keyDownHandler = { [weak self] in
                self?.onHotKeyPressed()
            }
        }
    }
    
    private func parseHotkeyString(_ hotkeyString: String) -> (Key?, NSEvent.ModifierFlags) {
        var modifiers: NSEvent.ModifierFlags = []
        var keyString = hotkeyString
        
        // Parse modifiers
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
        
        // Parse key
        let key = stringToKey(keyString)
        
        return (key, modifiers)
    }
    
    private func stringToKey(_ keyString: String) -> Key? {
        switch keyString.uppercased() {
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
        hotKey = nil
        NotificationCenter.default.removeObserver(self)
    }
}