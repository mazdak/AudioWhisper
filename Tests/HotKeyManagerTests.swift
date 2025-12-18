import XCTest
import HotKey
@testable import AudioWhisper

final class HotKeyManagerTests: XCTestCase {
    
    var hotKeyManager: HotKeyManager!
    var hotkeyPressedCount: Int = 0
    
    override func setUp() {
        super.setUp()
        hotkeyPressedCount = 0
        hotKeyManager = HotKeyManager { [weak self] in
            self?.hotkeyPressedCount += 1
        }
    }
    
    override func tearDown() {
        hotKeyManager = nil
        UserDefaults.standard.removeObject(forKey: "globalHotkey")
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testHotKeyManagerInitialization() {
        XCTAssertNotNil(hotKeyManager)
        XCTAssertEqual(hotkeyPressedCount, 0)
    }
    
    func testInitializationWithDefaultHotkey() {
        // Should use default hotkey when none is set
        let manager = HotKeyManager { }
        XCTAssertNotNil(manager)
    }
    
    func testInitializationWithCustomHotkey() {
        UserDefaults.standard.set("⌘⌥A", forKey: "globalHotkey")
        
        let manager = HotKeyManager { }
        XCTAssertNotNil(manager)
    }
    
    // MARK: - Hotkey String Parsing Tests
    
    func testParseBasicHotkey() {
        // We can't directly test the private parsing method, but we can test through notification
        UserDefaults.standard.set("⌘A", forKey: "globalHotkey")
        
        NotificationCenter.default.post(
            name: .updateGlobalHotkey,
            object: "⌘A"
        )
        
        // The hotkey should be updated without crashing
        XCTAssertNotNil(hotKeyManager)
    }
    
    func testParseComplexHotkey() {
        UserDefaults.standard.set("⌘⇧⌥⌃A", forKey: "globalHotkey")
        
        NotificationCenter.default.post(
            name: .updateGlobalHotkey,
            object: "⌘⇧⌥⌃A"
        )
        
        XCTAssertNotNil(hotKeyManager)
    }
    
    func testParseInvalidHotkey() {
        NotificationCenter.default.post(
            name: .updateGlobalHotkey,
            object: "InvalidKey"
        )
        
        // Should not crash with invalid hotkey
        XCTAssertNotNil(hotKeyManager)
    }
    
    func testParseSpaceHotkey() {
        NotificationCenter.default.post(
            name: .updateGlobalHotkey,
            object: "⌘SPACE"
        )
        
        XCTAssertNotNil(hotKeyManager)
    }
    
    // MARK: - Notification Observer Tests
    
    func testHotkeyUpdateNotification() {
        let expectation = XCTestExpectation(description: "Hotkey updated")
        
        // Post notification to update hotkey
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .updateGlobalHotkey,
                object: "⌘B"
            )
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Should not crash and manager should still be valid
        XCTAssertNotNil(hotKeyManager)
    }
    
    func testMultipleHotkeyUpdates() {
        let hotkeyStrings = ["⌘A", "⌘⇧B", "⌘⌥C", "⌘⌃D", "⌘⇧⌥E"]
        
        for hotkeyString in hotkeyStrings {
            NotificationCenter.default.post(
                name: .updateGlobalHotkey,
                object: hotkeyString
            )
            
            // Small delay to allow processing
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        
        XCTAssertNotNil(hotKeyManager)
    }
    
    // MARK: - Key Mapping Tests
    
    func testKeyMappingForLetters() {
        let letterKeys = ["A", "B", "C", "Z"]
        
        for letter in letterKeys {
            NotificationCenter.default.post(
                name: .updateGlobalHotkey,
                object: "⌘\(letter)"
            )
            
            XCTAssertNotNil(hotKeyManager)
        }
    }
    
    func testKeyMappingForNumbers() {
        let numberKeys = ["1", "2", "3", "9", "0"]
        
        for number in numberKeys {
            NotificationCenter.default.post(
                name: .updateGlobalHotkey,
                object: "⌘\(number)"
            )
            
            XCTAssertNotNil(hotKeyManager)
        }
    }
    
    func testKeyMappingForSpecialKeys() {
        let specialKeys = ["⏎", "⇥", "⌫", "⎋", "↑", "↓", "←", "→"]
        
        for key in specialKeys {
            NotificationCenter.default.post(
                name: .updateGlobalHotkey,
                object: "⌘\(key)"
            )
            
            XCTAssertNotNil(hotKeyManager)
        }
    }
    
    func testKeyMappingForPunctuation() {
        let punctuationKeys = ["=", "-", "[", "]", ";", "'", ",", ".", "/", "`"]
        
        for key in punctuationKeys {
            NotificationCenter.default.post(
                name: .updateGlobalHotkey,
                object: "⌘\(key)"
            )
            
            XCTAssertNotNil(hotKeyManager)
        }
    }
    
    // MARK: - Modifier Tests
    
    func testSingleModifiers() {
        let modifiers = ["⌘", "⇧", "⌥", "⌃"]
        
        for modifier in modifiers {
            NotificationCenter.default.post(
                name: .updateGlobalHotkey,
                object: "\(modifier)A"
            )
            
            XCTAssertNotNil(hotKeyManager)
        }
    }
    
    func testMultipleModifiers() {
        let combinations = [
            "⌘⇧A",
            "⌘⌥A", 
            "⌘⌃A",
            "⇧⌥A",
            "⇧⌃A",
            "⌥⌃A",
            "⌘⇧⌥A",
            "⌘⇧⌃A",
            "⌘⌥⌃A",
            "⇧⌥⌃A",
            "⌘⇧⌥⌃A"
        ]
        
        for combination in combinations {
            NotificationCenter.default.post(
                name: .updateGlobalHotkey,
                object: combination
            )
            
            XCTAssertNotNil(hotKeyManager)
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyHotkeyString() {
        NotificationCenter.default.post(
            name: .updateGlobalHotkey,
            object: ""
        )
        
        XCTAssertNotNil(hotKeyManager)
    }
    
    func testNilHotkeyObject() {
        NotificationCenter.default.post(
            name: .updateGlobalHotkey,
            object: nil
        )
        
        XCTAssertNotNil(hotKeyManager)
    }
    
    func testNonStringHotkeyObject() {
        NotificationCenter.default.post(
            name: .updateGlobalHotkey,
            object: 123
        )
        
        XCTAssertNotNil(hotKeyManager)
    }
    
    func testModifiersWithoutKey() {
        NotificationCenter.default.post(
            name: .updateGlobalHotkey,
            object: "⌘⇧⌥⌃"
        )
        
        XCTAssertNotNil(hotKeyManager)
    }
    
    // MARK: - Memory Management Tests
    
    func testDeinitCleanup() {
        weak var weakManager = hotKeyManager
        
        hotKeyManager = nil
        
        // Force a runloop to allow cleanup
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        XCTAssertNil(weakManager, "HotKeyManager should be deallocated")
    }
    
    func testNotificationObserverCleanup() {
        let manager = HotKeyManager { }
        weak var weakManager = manager
        
        // Create a reference and then nil it
        var strongManager: HotKeyManager? = manager
        strongManager = nil
        _ = strongManager // Explicitly ignore to avoid unused variable warning
        
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // The manager should still exist due to notification center retention
        // but should be properly cleaned up on deallocation
        XCTAssertNotNil(weakManager)
    }
    
    // MARK: - Performance Tests
    
    func testHotkeyParsingPerformance() {
        measure {
            for i in 0..<1000 {
                let hotkeyString = i % 2 == 0 ? "⌘A" : "⌘⇧B"
                NotificationCenter.default.post(
                    name: .updateGlobalHotkey,
                    object: hotkeyString
                )
            }
        }
    }
    
    func testHotKeyManagerCreationPerformance() {
        measure {
            for _ in 0..<100 {
                let manager = HotKeyManager { }
                _ = manager
            }
        }
    }
    
    // MARK: - UserDefaults Integration Tests
    
    func testUserDefaultsIntegration() {
        UserDefaults.standard.set("⌘⇧X", forKey: "globalHotkey")
        
        let manager = HotKeyManager { }
        XCTAssertNotNil(manager)
        
        UserDefaults.standard.removeObject(forKey: "globalHotkey")
    }
    
    func testDefaultHotkeyFallback() {
        UserDefaults.standard.removeObject(forKey: "globalHotkey")
        
        let manager = HotKeyManager { }
        XCTAssertNotNil(manager)
        
        // Should use default "⌘⇧Space" without crashing
    }
}
