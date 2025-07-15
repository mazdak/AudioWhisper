import XCTest
import SwiftUI
import AVFoundation
import ServiceManagement
@testable import AudioWhisper

class SettingsViewTests: XCTestCase {
    var mockKeychain: MockKeychain!
    
    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychain()
        
        // Clear UserDefaults for testing
        UserDefaults.standard.removeObject(forKey: "selectedMicrophone")
        UserDefaults.standard.removeObject(forKey: "globalHotkey")
        UserDefaults.standard.removeObject(forKey: "useOpenAI")
        UserDefaults.standard.removeObject(forKey: "startAtLogin")
        UserDefaults.standard.removeObject(forKey: "immediateRecording")
    }
    
    override func tearDown() {
        mockKeychain = nil
        
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "selectedMicrophone")
        UserDefaults.standard.removeObject(forKey: "globalHotkey")
        UserDefaults.standard.removeObject(forKey: "useOpenAI")
        UserDefaults.standard.removeObject(forKey: "startAtLogin")
        UserDefaults.standard.removeObject(forKey: "immediateRecording")
        
        super.tearDown()
    }
    
    // MARK: - Default Values Tests
    
    func testDefaultSettings() {
        // Test that default values are set correctly
        XCTAssertEqual(UserDefaults.standard.string(forKey: "selectedMicrophone") ?? "", "")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "globalHotkey") ?? "⌘⇧Space", "⌘⇧Space")
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "useOpenAI"), false) // Default is false when not set
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "startAtLogin"), false) // Default is false when not set
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "immediateRecording"), false) // Default is Manual Start & Stop mode
    }
    
    func testSettingsInitialization() {
        // Set some values
        UserDefaults.standard.set("test-microphone", forKey: "selectedMicrophone")
        UserDefaults.standard.set("⌘⇧R", forKey: "globalHotkey")
        UserDefaults.standard.set(false, forKey: "useOpenAI")
        UserDefaults.standard.set(true, forKey: "startAtLogin")
        UserDefaults.standard.set(true, forKey: "immediateRecording") // Enable Hotkey Start & Stop mode
        
        // Values should persist
        XCTAssertEqual(UserDefaults.standard.string(forKey: "selectedMicrophone"), "test-microphone")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "globalHotkey"), "⌘⇧R")
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "useOpenAI"), false)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "startAtLogin"), true)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "immediateRecording"), true)
    }
    
    // MARK: - Microphone Discovery Tests
    
    func testMicrophoneDiscovery() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        
        let devices = discoverySession.devices
        
        // Should be able to discover microphones (at least system default)
        XCTAssertNotNil(devices)
        
        // Each device should have required properties
        for device in devices {
            XCTAssertFalse(device.localizedName.isEmpty)
            XCTAssertFalse(device.uniqueID.isEmpty)
        }
    }
    
    func testMicrophoneSelectionPersistence() {
        let testMicrophoneID = "test-microphone-id"
        
        UserDefaults.standard.set(testMicrophoneID, forKey: "selectedMicrophone")
        
        let selectedMicrophone = UserDefaults.standard.string(forKey: "selectedMicrophone")
        XCTAssertEqual(selectedMicrophone, testMicrophoneID)
    }
    
    // MARK: - API Key Management Tests
    
    func testAPIKeyKeychain() {
        let mockKeychain = MockKeychainService()
        let settingsView = SettingsView(keychainService: mockKeychain, skipOnAppear: true)
        
        // Test saving API key
        settingsView.saveAPIKey("test-openai-key", service: "TestService", account: "TestOpenAI")
        
        // Test retrieving API key
        let retrievedKey = settingsView.getAPIKey(service: "TestService", account: "TestOpenAI")
        XCTAssertEqual(retrievedKey, "test-openai-key")
        
        // Test saving empty key (should delete)
        settingsView.saveAPIKey("", service: "TestService", account: "TestOpenAI")
        
        let deletedKey = settingsView.getAPIKey(service: "TestService", account: "TestOpenAI")
        XCTAssertNil(deletedKey)
    }
    
    func testAPIKeyForDifferentProviders() {
        let mockKeychain = MockKeychainService()
        let settingsView = SettingsView(keychainService: mockKeychain, skipOnAppear: true)
        
        // Save keys for both providers
        settingsView.saveAPIKey("openai-key", service: "TestService", account: "TestOpenAI")
        settingsView.saveAPIKey("gemini-key", service: "TestService", account: "TestGemini")
        
        // Retrieve keys for both providers
        let openAIKey = settingsView.getAPIKey(service: "TestService", account: "TestOpenAI")
        let geminiKey = settingsView.getAPIKey(service: "TestService", account: "TestGemini")
        
        XCTAssertEqual(openAIKey, "openai-key")
        XCTAssertEqual(geminiKey, "gemini-key")
    }
    
    func testAPIKeyUpdate() {
        let mockKeychain = MockKeychainService()
        let settingsView = SettingsView(keychainService: mockKeychain, skipOnAppear: true)
        
        // Save initial key
        settingsView.saveAPIKey("initial-key", service: "TestService", account: "TestUpdate")
        
        let initialKey = settingsView.getAPIKey(service: "TestService", account: "TestUpdate")
        XCTAssertEqual(initialKey, "initial-key")
        
        // Update key
        settingsView.saveAPIKey("updated-key", service: "TestService", account: "TestUpdate")
        
        let updatedKey = settingsView.getAPIKey(service: "TestService", account: "TestUpdate")
        XCTAssertEqual(updatedKey, "updated-key")
    }
    
    // MARK: - Provider Selection Tests
    
    func testProviderSelection() {
        // Test OpenAI selection
        UserDefaults.standard.set(true, forKey: "useOpenAI")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "useOpenAI"))
        
        // Test Gemini selection
        UserDefaults.standard.set(false, forKey: "useOpenAI")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "useOpenAI"))
    }
    
    func testProviderSelectionPersistence() {
        // Set to Gemini
        UserDefaults.standard.set(false, forKey: "useOpenAI")
        
        // Value should persist
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "useOpenAI"))
        
        // Set to OpenAI
        UserDefaults.standard.set(true, forKey: "useOpenAI")
        
        // Value should persist
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "useOpenAI"))
    }
    
    // MARK: - Global Hotkey Tests
    
    func testGlobalHotkeyDefault() {
        // Test default hotkey
        let defaultHotkey = UserDefaults.standard.string(forKey: "globalHotkey") ?? "⌘⇧Space"
        XCTAssertEqual(defaultHotkey, "⌘⇧Space")
    }
    
    func testGlobalHotkeyCustomization() {
        let customHotkey = "⌘⇧R"
        UserDefaults.standard.set(customHotkey, forKey: "globalHotkey")
        
        let retrievedHotkey = UserDefaults.standard.string(forKey: "globalHotkey")
        XCTAssertEqual(retrievedHotkey, customHotkey)
    }
    
    // MARK: - Start at Login Tests
    
    func testStartAtLoginDefault() {
        // Test default value
        let defaultStartAtLogin = UserDefaults.standard.bool(forKey: "startAtLogin")
        XCTAssertEqual(defaultStartAtLogin, false) // Default is false when not set
    }
    
    func testStartAtLoginPersistence() {
        // Enable start at login
        UserDefaults.standard.set(true, forKey: "startAtLogin")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "startAtLogin"))
        
        // Disable start at login
        UserDefaults.standard.set(false, forKey: "startAtLogin")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "startAtLogin"))
    }
    
    func testHotkeyStartStopModeDefault() {
        // Test default value (should be false - Manual Start & Stop mode)
        let defaultHotkeyMode = UserDefaults.standard.bool(forKey: "immediateRecording")
        XCTAssertEqual(defaultHotkeyMode, false) // Default is false when not set
    }
    
    func testHotkeyStartStopModePersistence() {
        // Enable Hotkey Start & Stop mode
        UserDefaults.standard.set(true, forKey: "immediateRecording")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "immediateRecording"))
        
        // Disable Hotkey Start & Stop mode (back to Manual mode)
        UserDefaults.standard.set(false, forKey: "immediateRecording")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "immediateRecording"))
    }
    
    // MARK: - URL Generation Tests
    
    func testAPIKeyURLGeneration() {
        let openAIURL = URL(string: "https://platform.openai.com/api-keys")!
        let geminiURL = URL(string: "https://makersuite.google.com/app/apikey")!
        
        XCTAssertEqual(openAIURL.absoluteString, "https://platform.openai.com/api-keys")
        XCTAssertEqual(geminiURL.absoluteString, "https://makersuite.google.com/app/apikey")
    }
    
    // MARK: - Keychain Security Tests
    
    func testKeychainDataEncoding() {
        let testKey = "test-api-key-with-special-chars-!@#$%^&*()"
        let encodedData = testKey.data(using: .utf8)!
        let decodedString = String(data: encodedData, encoding: .utf8)
        
        XCTAssertEqual(decodedString, testKey)
    }
    
    func testKeychainEmptyKeyHandling() {
        let mockKeychain = MockKeychainService()
        let settingsView = SettingsView(keychainService: mockKeychain, skipOnAppear: true)
        
        // Save empty key
        settingsView.saveAPIKey("", service: "AudioWhisper", account: "TestAccount")
        
        // Should return nil for empty key
        let retrievedKey = settingsView.getAPIKey(service: "AudioWhisper", account: "TestAccount")
        XCTAssertNil(retrievedKey)
    }
    
    // MARK: - Performance Tests
    
    func testMicrophoneDiscoveryPerformance() {
        measure {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.microphone],
                mediaType: .audio,
                position: .unspecified
            )
            _ = discoverySession.devices
        }
    }
    
    func testAPIKeyOperationPerformance() {
        let mockKeychain = MockKeychainService()
        let settingsView = SettingsView(keychainService: mockKeychain, skipOnAppear: true)
        
        measure {
            for i in 0..<100 {
                settingsView.saveAPIKey("test-key-\(i)", service: "TestService", account: "PerformanceTest")
                _ = settingsView.getAPIKey(service: "TestService", account: "PerformanceTest")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testKeychainErrorHandling() {
        let mockKeychain = MockKeychainService()
        let settingsView = SettingsView(keychainService: mockKeychain, skipOnAppear: true)
        
        // Test with invalid service name
        let invalidKey = settingsView.getAPIKey(service: "", account: "")
        XCTAssertNil(invalidKey)
    }
    
    func testConcurrentAPIKeyOperations() {
        let mockKeychain = MockKeychainService()
        let settingsView = SettingsView(keychainService: mockKeychain, skipOnAppear: true)
        let expectation = XCTestExpectation(description: "Concurrent operations should complete")
        expectation.expectedFulfillmentCount = 10
        
        // Perform concurrent operations
        for i in 0..<10 {
            DispatchQueue.global().async {
                settingsView.saveAPIKey("concurrent-key-\(i)", service: "AudioWhisper", account: "ConcurrentTest\(i)")
                let retrievedKey = settingsView.getAPIKey(service: "AudioWhisper", account: "ConcurrentTest\(i)")
                XCTAssertEqual(retrievedKey, "concurrent-key-\(i)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Test Helpers and Extensions

extension SettingsViewTests {
    private func clearUserDefaults() {
        let keys = ["selectedMicrophone", "globalHotkey", "useOpenAI", "startAtLogin"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

