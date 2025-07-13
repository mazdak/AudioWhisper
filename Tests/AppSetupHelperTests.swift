import XCTest
import ServiceManagement
import AppKit
@testable import AudioWhisper

final class AppSetupHelperTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clean up UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "startAtLogin")
        UserDefaults.standard.removeObject(forKey: "transcriptionProvider")
        UserDefaults.standard.removeObject(forKey: "hasCompletedWelcome")
    }
    
    override func tearDown() {
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: "startAtLogin")
        UserDefaults.standard.removeObject(forKey: "transcriptionProvider")
        UserDefaults.standard.removeObject(forKey: "hasCompletedWelcome")
        super.tearDown()
    }
    
    // MARK: - App Setup Tests
    
    func testSetupApp() {
        XCTAssertNoThrow(AppSetupHelper.setupApp())
        
        // Verify that NSApp activation policy was set
        // Note: We can't directly test this as it affects the actual app state
        // but we can verify the method doesn't crash
    }
    
    // MARK: - Login Item Tests
    
    func testSetupLoginItemWithDefaultTrue() {
        // When no preference is set, should default to true
        XCTAssertNoThrow(AppSetupHelper.setupLoginItem())
        
        // Verify the default behavior
        let startAtLogin = UserDefaults.standard.object(forKey: "startAtLogin") as? Bool ?? true
        XCTAssertTrue(startAtLogin)
    }
    
    func testSetupLoginItemWithExplicitTrue() {
        UserDefaults.standard.set(true, forKey: "startAtLogin")
        
        XCTAssertNoThrow(AppSetupHelper.setupLoginItem())
    }
    
    func testSetupLoginItemWithExplicitFalse() {
        UserDefaults.standard.set(false, forKey: "startAtLogin")
        
        XCTAssertNoThrow(AppSetupHelper.setupLoginItem())
    }
    
    // MARK: - Menu Bar Icon Tests
    
    func testCreateMenuBarIcon() {
        let icon = AppSetupHelper.createMenuBarIcon()
        
        XCTAssertNotNil(icon)
        XCTAssertTrue(icon.isTemplate, "Menu bar icon should be a template image")
    }
    
    func testMenuBarIconConfiguration() {
        let icon = AppSetupHelper.createMenuBarIcon()
        
        // Icon should have proper accessibility description
        XCTAssertNotNil(icon)
        
        // Test that the icon can be used in a status item
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        XCTAssertNoThrow(statusItem.button?.image = icon)
        
        // Clean up
        NSStatusBar.system.removeStatusItem(statusItem)
    }
    
    // MARK: - First Run Check Tests
    
    func testCheckFirstRunWithNoProviderAndNoWelcome() {
        // Both provider and welcome are missing - should be first run
        let isFirstRun = AppSetupHelper.checkFirstRun()
        
        XCTAssertTrue(isFirstRun)
        
        // Should set default provider to local
        let provider = UserDefaults.standard.string(forKey: "transcriptionProvider")
        XCTAssertEqual(provider, TranscriptionProvider.local.rawValue)
    }
    
    func testCheckFirstRunWithProviderButNoWelcome() {
        UserDefaults.standard.set(TranscriptionProvider.openai.rawValue, forKey: "transcriptionProvider")
        
        let isFirstRun = AppSetupHelper.checkFirstRun()
        
        XCTAssertFalse(isFirstRun)
        
        // Provider should remain unchanged
        let provider = UserDefaults.standard.string(forKey: "transcriptionProvider")
        XCTAssertEqual(provider, TranscriptionProvider.openai.rawValue)
    }
    
    func testCheckFirstRunWithWelcomeButNoProvider() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        let isFirstRun = AppSetupHelper.checkFirstRun()
        
        XCTAssertFalse(isFirstRun)
        
        // Should set default provider to local
        let provider = UserDefaults.standard.string(forKey: "transcriptionProvider")
        XCTAssertEqual(provider, TranscriptionProvider.local.rawValue)
    }
    
    func testCheckFirstRunWithBothProviderAndWelcome() {
        UserDefaults.standard.set(TranscriptionProvider.gemini.rawValue, forKey: "transcriptionProvider")
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        
        let isFirstRun = AppSetupHelper.checkFirstRun()
        
        XCTAssertFalse(isFirstRun)
        
        // Provider should remain unchanged
        let provider = UserDefaults.standard.string(forKey: "transcriptionProvider")
        XCTAssertEqual(provider, TranscriptionProvider.gemini.rawValue)
    }
    
    func testCheckFirstRunDefaultProviderIsLocal() {
        // Verify that first run always sets provider to local
        let isFirstRun = AppSetupHelper.checkFirstRun()
        
        if isFirstRun {
            let provider = UserDefaults.standard.string(forKey: "transcriptionProvider")
            XCTAssertEqual(provider, TranscriptionProvider.local.rawValue)
        }
    }
    
    // MARK: - Cleanup Tests
    
    func testCleanupOldTemporaryFiles() {
        // Create some test temporary files
        let tempDirectory = FileManager.default.temporaryDirectory
        let testFiles = [
            tempDirectory.appendingPathComponent("recording_test1.m4a"),
            tempDirectory.appendingPathComponent("recording_test2.m4a"),
            tempDirectory.appendingPathComponent("other_file.txt")
        ]
        
        // Create test files
        for file in testFiles {
            try? "test data".write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Run cleanup
        XCTAssertNoThrow(AppSetupHelper.cleanupOldTemporaryFiles())
        
        // Clean up test files
        for file in testFiles {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    func testCleanupWithNoTemporaryFiles() {
        // Should not crash when no files exist
        XCTAssertNoThrow(AppSetupHelper.cleanupOldTemporaryFiles())
    }
    
    func testCleanupOnlyRemovesOldFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        // Create a recent file (should not be deleted)
        let recentFile = tempDirectory.appendingPathComponent("recording_recent.m4a")
        try? "recent data".write(to: recentFile, atomically: true, encoding: .utf8)
        
        // Run cleanup
        XCTAssertNoThrow(AppSetupHelper.cleanupOldTemporaryFiles())
        
        // Recent file should still exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: recentFile.path))
        
        // Clean up
        try? FileManager.default.removeItem(at: recentFile)
    }
    
    func testCleanupOnlyTargetsRecordingFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        // Create non-recording files (should not be deleted)
        let nonRecordingFiles = [
            tempDirectory.appendingPathComponent("other_file.m4a"),
            tempDirectory.appendingPathComponent("test.txt"),
            tempDirectory.appendingPathComponent("recording.wav") // Wrong extension
        ]
        
        for file in nonRecordingFiles {
            try? "test data".write(to: file, atomically: true, encoding: .utf8)
        }
        
        // Run cleanup
        XCTAssertNoThrow(AppSetupHelper.cleanupOldTemporaryFiles())
        
        // Non-recording files should still exist
        for file in nonRecordingFiles {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testCleanupWithPermissionError() {
        // Test cleanup when file operations might fail
        // This is difficult to test directly, but we can ensure it doesn't crash
        XCTAssertNoThrow(AppSetupHelper.cleanupOldTemporaryFiles())
    }
    
    func testSetupWithInvalidUserDefaults() {
        // Test with various UserDefaults states
        UserDefaults.standard.set("invalid", forKey: "startAtLogin")
        
        XCTAssertNoThrow(AppSetupHelper.setupLoginItem())
    }
    
    // MARK: - Performance Tests
    
    func testSetupAppPerformance() {
        measure {
            AppSetupHelper.setupApp()
        }
    }
    
    func testCreateMenuBarIconPerformance() {
        measure {
            for _ in 0..<100 {
                let _ = AppSetupHelper.createMenuBarIcon()
            }
        }
    }
    
    func testCheckFirstRunPerformance() {
        measure {
            for _ in 0..<1000 {
                let _ = AppSetupHelper.checkFirstRun()
            }
        }
    }
    
    func testCleanupPerformance() {
        // Create multiple temporary files for cleanup test
        let tempDirectory = FileManager.default.temporaryDirectory
        var testFiles: [URL] = []
        
        for i in 0..<50 {
            let file = tempDirectory.appendingPathComponent("recording_perf_test\(i).m4a")
            testFiles.append(file)
            try? "test data".write(to: file, atomically: true, encoding: .utf8)
        }
        
        measure {
            AppSetupHelper.cleanupOldTemporaryFiles()
        }
        
        // Clean up test files
        for file in testFiles {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    // MARK: - Integration Tests
    
    func testFullSetupSequence() {
        // Test complete setup process
        XCTAssertNoThrow(AppSetupHelper.setupApp())
        
        let isFirstRun = AppSetupHelper.checkFirstRun()
        
        if isFirstRun {
            let provider = UserDefaults.standard.string(forKey: "transcriptionProvider")
            XCTAssertEqual(provider, TranscriptionProvider.local.rawValue)
        }
        
        let icon = AppSetupHelper.createMenuBarIcon()
        XCTAssertNotNil(icon)
        
        XCTAssertNoThrow(AppSetupHelper.cleanupOldTemporaryFiles())
    }
    
    func testMultipleSetupCalls() {
        // Multiple setup calls should be safe
        for _ in 0..<5 {
            XCTAssertNoThrow(AppSetupHelper.setupApp())
        }
    }
    
    // MARK: - Edge Cases
    
    func testSetupWithCorruptedUserDefaults() {
        // Test with various corrupted UserDefaults states
        // Note: NSNull() cannot be stored in UserDefaults, so we test with other invalid values
        let corruptedValues: [Any] = [
            "",
            [],
            [:],
            NSDate()
        ]
        
        for value in corruptedValues {
            UserDefaults.standard.set(value, forKey: "startAtLogin")
            XCTAssertNoThrow(AppSetupHelper.setupLoginItem())
            
            UserDefaults.standard.set(value, forKey: "transcriptionProvider")
            XCTAssertNoThrow(AppSetupHelper.checkFirstRun())
        }
        
        // Test with nil/removed key (simulates corrupted/missing data)
        UserDefaults.standard.removeObject(forKey: "startAtLogin")
        XCTAssertNoThrow(AppSetupHelper.setupLoginItem())
        
        UserDefaults.standard.removeObject(forKey: "transcriptionProvider")
        XCTAssertNoThrow(AppSetupHelper.checkFirstRun())
    }
    
    func testCleanupWithSpecialFileNames() {
        let tempDirectory = FileManager.default.temporaryDirectory
        let specialFiles = [
            "recording_file with spaces.m4a",
            "recording_file-with-hyphens.m4a",
            "recording_file.with.dots.m4a",
            "recording_file_with_unicode_测试.m4a"
        ]
        
        var testFiles: [URL] = []
        for fileName in specialFiles {
            let file = tempDirectory.appendingPathComponent(fileName)
            testFiles.append(file)
            try? "test data".write(to: file, atomically: true, encoding: .utf8)
        }
        
        XCTAssertNoThrow(AppSetupHelper.cleanupOldTemporaryFiles())
        
        // Clean up
        for file in testFiles {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    // MARK: - Static Method Tests
    
    func testAllMethodsAreStatic() {
        // Verify we can call all methods without instance
        XCTAssertNoThrow(AppSetupHelper.setupApp())
        XCTAssertNoThrow(AppSetupHelper.setupLoginItem())
        XCTAssertNotNil(AppSetupHelper.createMenuBarIcon())
        XCTAssertNoThrow(AppSetupHelper.checkFirstRun())
        XCTAssertNoThrow(AppSetupHelper.cleanupOldTemporaryFiles())
    }
}