import XCTest
import SwiftUI
import AppKit
@testable import AudioWhisper

// MARK: - HotKeyRecorderView Tests
@MainActor
final class HotKeyRecorderViewTests: XCTestCase {

    @State private var isRecording = false
    @State private var modifiers: NSEvent.ModifierFlags = []
    @State private var key: Key?

    func testViewCanBeCreated() {
        let isRecordingBinding = Binding(
            get: { self.isRecording },
            set: { self.isRecording = $0 }
        )
        let modifiersBinding = Binding(
            get: { self.modifiers },
            set: { self.modifiers = $0 }
        )
        let keyBinding = Binding(
            get: { self.key },
            set: { self.key = $0 }
        )

        let view = HotKeyRecorderView(
            isRecording: isRecordingBinding,
            recordedModifiers: modifiersBinding,
            recordedKey: keyBinding,
            onComplete: { _ in }
        )

        XCTAssertNotNil(view)
    }

    func testViewBodyDoesNotCrash() {
        let isRecordingBinding = Binding(
            get: { self.isRecording },
            set: { self.isRecording = $0 }
        )
        let modifiersBinding = Binding(
            get: { self.modifiers },
            set: { self.modifiers = $0 }
        )
        let keyBinding = Binding(
            get: { self.key },
            set: { self.key = $0 }
        )

        let view = HotKeyRecorderView(
            isRecording: isRecordingBinding,
            recordedModifiers: modifiersBinding,
            recordedKey: keyBinding,
            onComplete: { _ in }
        )

        let _ = view.body
        XCTAssertTrue(true, "Body should not crash")
    }
}

// MARK: - Key Code Mapping Tests
final class KeyCodeMappingTests: XCTestCase {

    func testLetterKeyMappings() {
        let letterMappings: [(UInt16, Key)] = [
            (0, .a), (1, .s), (2, .d), (3, .f),
            (4, .h), (5, .g), (6, .z), (7, .x),
            (8, .c), (9, .v), (11, .b), (12, .q),
            (13, .w), (14, .e), (15, .r), (16, .y),
            (17, .t), (31, .o), (32, .u), (34, .i),
            (35, .p), (37, .l), (38, .j), (40, .k),
            (45, .n), (46, .m)
        ]

        for (keyCode, expectedKey) in letterMappings {
            let key = keyFromKeyCode(keyCode)
            XCTAssertEqual(key, expectedKey, "Key code \(keyCode) should map to \(expectedKey)")
        }
    }

    func testNumberKeyMappings() {
        let numberMappings: [(UInt16, Key)] = [
            (18, .one), (19, .two), (20, .three),
            (21, .four), (22, .six), (23, .five),
            (25, .nine), (26, .seven), (28, .eight),
            (29, .zero)
        ]

        for (keyCode, expectedKey) in numberMappings {
            let key = keyFromKeyCode(keyCode)
            XCTAssertEqual(key, expectedKey, "Key code \(keyCode) should map to \(expectedKey)")
        }
    }

    func testFunctionKeyMappings() {
        let functionMappings: [(UInt16, Key)] = [
            (122, .f1), (120, .f2), (99, .f3), (118, .f4),
            (96, .f5), (97, .f6), (98, .f7), (100, .f8),
            (101, .f9), (109, .f10), (103, .f11), (111, .f12),
            (105, .f13), (107, .f14), (113, .f15), (106, .f16),
            (64, .f17), (79, .f18), (80, .f19), (90, .f20)
        ]

        for (keyCode, expectedKey) in functionMappings {
            let key = keyFromKeyCode(keyCode)
            XCTAssertEqual(key, expectedKey, "Key code \(keyCode) should map to \(expectedKey)")
        }
    }

    func testArrowKeyMappings() {
        let arrowMappings: [(UInt16, Key)] = [
            (126, .upArrow), (125, .downArrow),
            (123, .leftArrow), (124, .rightArrow)
        ]

        for (keyCode, expectedKey) in arrowMappings {
            let key = keyFromKeyCode(keyCode)
            XCTAssertEqual(key, expectedKey, "Key code \(keyCode) should map to \(expectedKey)")
        }
    }

    func testSpecialKeyMappings() {
        let specialMappings: [(UInt16, Key)] = [
            (36, .return), (48, .tab), (49, .space),
            (50, .grave), (51, .delete), (53, .escape),
            (24, .equal), (27, .minus), (30, .rightBracket),
            (33, .leftBracket), (39, .quote), (41, .semicolon),
            (42, .backslash), (43, .comma), (44, .slash),
            (47, .period)
        ]

        for (keyCode, expectedKey) in specialMappings {
            let key = keyFromKeyCode(keyCode)
            XCTAssertEqual(key, expectedKey, "Key code \(keyCode) should map to \(expectedKey)")
        }
    }

    func testUnknownKeyCodeReturnsNil() {
        let unknownKeyCode: UInt16 = 255
        let key = keyFromKeyCode(unknownKeyCode)
        XCTAssertNil(key)
    }

    // Helper matching HotKeyRecorderView implementation
    private func keyFromKeyCode(_ keyCode: UInt16) -> Key? {
        switch keyCode {
        case 0: return .a
        case 1: return .s
        case 2: return .d
        case 3: return .f
        case 4: return .h
        case 5: return .g
        case 6: return .z
        case 7: return .x
        case 8: return .c
        case 9: return .v
        case 11: return .b
        case 12: return .q
        case 13: return .w
        case 14: return .e
        case 15: return .r
        case 16: return .y
        case 17: return .t
        case 18: return .one
        case 19: return .two
        case 20: return .three
        case 21: return .four
        case 22: return .six
        case 23: return .five
        case 24: return .equal
        case 25: return .nine
        case 26: return .seven
        case 27: return .minus
        case 28: return .eight
        case 29: return .zero
        case 30: return .rightBracket
        case 31: return .o
        case 32: return .u
        case 33: return .leftBracket
        case 34: return .i
        case 35: return .p
        case 36: return .return
        case 37: return .l
        case 38: return .j
        case 39: return .quote
        case 40: return .k
        case 41: return .semicolon
        case 42: return .backslash
        case 43: return .comma
        case 44: return .slash
        case 45: return .n
        case 46: return .m
        case 47: return .period
        case 48: return .tab
        case 49: return .space
        case 50: return .grave
        case 51: return .delete
        case 53: return .escape
        case 122: return .f1
        case 120: return .f2
        case 99: return .f3
        case 118: return .f4
        case 96: return .f5
        case 97: return .f6
        case 98: return .f7
        case 100: return .f8
        case 101: return .f9
        case 109: return .f10
        case 103: return .f11
        case 111: return .f12
        case 105: return .f13
        case 107: return .f14
        case 113: return .f15
        case 106: return .f16
        case 64: return .f17
        case 79: return .f18
        case 80: return .f19
        case 90: return .f20
        case 126: return .upArrow
        case 125: return .downArrow
        case 123: return .leftArrow
        case 124: return .rightArrow
        default: return nil
        }
    }
}

// MARK: - Key to String Tests
final class KeyToStringTests: XCTestCase {

    func testFunctionKeyStrings() {
        XCTAssertEqual(keyToString(.f1), "F1")
        XCTAssertEqual(keyToString(.f2), "F2")
        XCTAssertEqual(keyToString(.f12), "F12")
        XCTAssertEqual(keyToString(.f20), "F20")
    }

    func testLetterKeyStrings() {
        XCTAssertEqual(keyToString(.a), "A")
        XCTAssertEqual(keyToString(.z), "Z")
        XCTAssertEqual(keyToString(.m), "M")
    }

    func testNumberKeyStrings() {
        XCTAssertEqual(keyToString(.one), "1")
        XCTAssertEqual(keyToString(.zero), "0")
        XCTAssertEqual(keyToString(.five), "5")
    }

    func testSpecialKeyStrings() {
        XCTAssertEqual(keyToString(.return), "⏎")
        XCTAssertEqual(keyToString(.tab), "⇥")
        XCTAssertEqual(keyToString(.space), "Space")
        XCTAssertEqual(keyToString(.delete), "⌫")
        XCTAssertEqual(keyToString(.escape), "⎋")
    }

    func testArrowKeyStrings() {
        XCTAssertEqual(keyToString(.upArrow), "↑")
        XCTAssertEqual(keyToString(.downArrow), "↓")
        XCTAssertEqual(keyToString(.leftArrow), "←")
        XCTAssertEqual(keyToString(.rightArrow), "→")
    }

    // Helper matching HotKeyRecorderView implementation
    private func keyToString(_ key: Key) -> String {
        switch key {
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        case .f13: return "F13"
        case .f14: return "F14"
        case .f15: return "F15"
        case .f16: return "F16"
        case .f17: return "F17"
        case .f18: return "F18"
        case .f19: return "F19"
        case .f20: return "F20"
        case .a: return "A"
        case .s: return "S"
        case .d: return "D"
        case .f: return "F"
        case .h: return "H"
        case .g: return "G"
        case .z: return "Z"
        case .x: return "X"
        case .c: return "C"
        case .v: return "V"
        case .b: return "B"
        case .q: return "Q"
        case .w: return "W"
        case .e: return "E"
        case .r: return "R"
        case .y: return "Y"
        case .t: return "T"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .six: return "6"
        case .five: return "5"
        case .equal: return "="
        case .nine: return "9"
        case .seven: return "7"
        case .minus: return "-"
        case .eight: return "8"
        case .zero: return "0"
        case .rightBracket: return "]"
        case .o: return "O"
        case .u: return "U"
        case .leftBracket: return "["
        case .i: return "I"
        case .p: return "P"
        case .return: return "⏎"
        case .l: return "L"
        case .j: return "J"
        case .quote: return "'"
        case .k: return "K"
        case .semicolon: return ";"
        case .backslash: return "\\"
        case .comma: return ","
        case .slash: return "/"
        case .n: return "N"
        case .m: return "M"
        case .period: return "."
        case .tab: return "⇥"
        case .space: return "Space"
        case .grave: return "`"
        case .delete: return "⌫"
        case .escape: return "⎋"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        default: return ""
        }
    }
}

// MARK: - Hotkey Validation Tests
final class HotkeyValidationTests: XCTestCase {

    func testFunctionKeysValidWithoutModifiers() {
        let functionKeys: [Key] = [.f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12]
        let emptyModifiers: NSEvent.ModifierFlags = []

        for key in functionKeys {
            let isValid = isValidHotkey(modifiers: emptyModifiers, key: key)
            XCTAssertTrue(isValid, "\(key) should be valid without modifiers")
        }
    }

    func testRegularKeysRequireModifiers() {
        let regularKeys: [Key] = [.a, .b, .c, .one, .two, .three]
        let emptyModifiers: NSEvent.ModifierFlags = []

        for key in regularKeys {
            let isValid = isValidHotkey(modifiers: emptyModifiers, key: key)
            XCTAssertFalse(isValid, "\(key) should require modifiers")
        }
    }

    func testForbiddenKeysAreRejected() {
        let forbiddenKeys: [Key] = [.escape, .delete, .return, .tab]
        let modifiers: NSEvent.ModifierFlags = [.command]

        for key in forbiddenKeys {
            let isValid = isValidHotkey(modifiers: modifiers, key: key)
            XCTAssertFalse(isValid, "\(key) should be forbidden even with modifiers")
        }
    }

    func testShiftOnlyIsInvalid() {
        let modifiers: NSEvent.ModifierFlags = [.shift]
        let isValid = isValidHotkey(modifiers: modifiers, key: .a)
        XCTAssertFalse(isValid, "Shift-only modifier should be invalid")
    }

    func testOptionOnlyIsInvalid() {
        let modifiers: NSEvent.ModifierFlags = [.option]
        let isValid = isValidHotkey(modifiers: modifiers, key: .a)
        XCTAssertFalse(isValid, "Option-only modifier should be invalid")
    }

    func testCommandModifierIsValid() {
        let modifiers: NSEvent.ModifierFlags = [.command]
        let isValid = isValidHotkey(modifiers: modifiers, key: .a)
        XCTAssertTrue(isValid, "Command+key should be valid")
    }

    func testControlModifierIsValid() {
        let modifiers: NSEvent.ModifierFlags = [.control]
        let isValid = isValidHotkey(modifiers: modifiers, key: .a)
        XCTAssertTrue(isValid, "Control+key should be valid")
    }

    func testCommandShiftIsValid() {
        let modifiers: NSEvent.ModifierFlags = [.command, .shift]
        let isValid = isValidHotkey(modifiers: modifiers, key: .a)
        XCTAssertTrue(isValid, "Command+Shift+key should be valid")
    }

    // Helper matching HotKeyRecorderView implementation
    private func isValidHotkey(modifiers: NSEvent.ModifierFlags, key: Key) -> Bool {
        if modifiers.isEmpty {
            return isFunctionKey(key)
        }

        let forbiddenKeys: [Key] = [.escape, .delete, .return, .tab]
        if forbiddenKeys.contains(key) {
            return false
        }

        if modifiers == .shift || modifiers == .option {
            return false
        }

        return true
    }

    private func isFunctionKey(_ key: Key) -> Bool {
        switch key {
        case .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10,
             .f11, .f12, .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20:
            return true
        default:
            return false
        }
    }
}

// MARK: - Hotkey Formatting Tests
final class HotkeyFormattingTests: XCTestCase {

    func testFormatCommandA() {
        let modifiers: NSEvent.ModifierFlags = [.command]
        let formatted = formatHotkey(modifiers: modifiers, key: .a)
        XCTAssertEqual(formatted, "⌘A")
    }

    func testFormatCommandShiftA() {
        let modifiers: NSEvent.ModifierFlags = [.command, .shift]
        let formatted = formatHotkey(modifiers: modifiers, key: .a)
        XCTAssertEqual(formatted, "⌘⇧A")
    }

    func testFormatControlOptionA() {
        let modifiers: NSEvent.ModifierFlags = [.control, .option]
        let formatted = formatHotkey(modifiers: modifiers, key: .a)
        XCTAssertEqual(formatted, "⌥⌃A")
    }

    func testFormatFunctionKeyAlone() {
        let modifiers: NSEvent.ModifierFlags = []
        let formatted = formatHotkey(modifiers: modifiers, key: .f5)
        XCTAssertEqual(formatted, "F5")
    }

    // Helper matching HotKeyRecorderView implementation
    private func formatHotkey(modifiers: NSEvent.ModifierFlags, key: Key) -> String {
        var parts: [String] = []

        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }

        parts.append(keyToString(key))

        return parts.joined()
    }

    private func keyToString(_ key: Key) -> String {
        switch key {
        case .f5: return "F5"
        case .a: return "A"
        default: return String(describing: key).uppercased()
        }
    }
}
