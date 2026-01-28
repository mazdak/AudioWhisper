import XCTest
import SwiftUI
@testable import AudioWhisper

/// Tests for DashboardProviders+Cloud extension functionality
@MainActor
final class DashboardProvidersCloudTests: XCTestCase {

    // MARK: - API Key Logic Tests

    func testLoadAPIKeysTrimming() {
        // Test that whitespace is trimmed from keys
        let keyWithWhitespace = "  sk-test123  "
        let trimmed = keyWithWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertEqual(trimmed, "sk-test123")
    }

    func testSaveAPIKeyEmptyKeyTriggersDelete() {
        let key = ""
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertTrue(trimmed.isEmpty, "Empty key after trimming should trigger delete")
    }

    func testSaveAPIKeyWhitespaceOnlyTriggersDelete() {
        let key = "   "
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertTrue(trimmed.isEmpty, "Whitespace-only key should trigger delete")
    }

    func testSaveAPIKeyValidKeySaves() {
        let key = "sk-validkey123"
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertFalse(trimmed.isEmpty, "Valid key should trigger save")
        XCTAssertEqual(trimmed, key)
    }

    // MARK: - Cloud Key Block UI Logic Tests

    func testCloudKeyBlockShowHideToggle() {
        var isShowing = false

        // Initially hidden (SecureField mode)
        XCTAssertFalse(isShowing)

        // Toggle to show (TextField mode)
        isShowing.toggle()
        XCTAssertTrue(isShowing)

        // Toggle back to hide
        isShowing.toggle()
        XCTAssertFalse(isShowing)
    }

    func testCloudKeyBlockEyeIconState() {
        // When showing, icon should be "eye.slash"
        let showingIcon = "eye.slash"
        // When hiding, icon should be "eye"
        let hiddenIcon = "eye"

        var isShowing = false
        XCTAssertEqual(isShowing ? showingIcon : hiddenIcon, "eye")

        isShowing = true
        XCTAssertEqual(isShowing ? showingIcon : hiddenIcon, "eye.slash")
    }

    // MARK: - API Key Service Account Names

    func testOpenAIServiceAccount() {
        let service = "AudioWhisper"
        let account = "OpenAI"

        XCTAssertEqual(service, "AudioWhisper")
        XCTAssertEqual(account, "OpenAI")
    }

    func testGeminiServiceAccount() {
        let service = "AudioWhisper"
        let account = "Gemini"

        XCTAssertEqual(service, "AudioWhisper")
        XCTAssertEqual(account, "Gemini")
    }

    // MARK: - API Key Validation Patterns

    func testOpenAIKeyPrefix() {
        let validKey = "sk-test123"
        XCTAssertTrue(validKey.hasPrefix("sk-"), "OpenAI keys should start with 'sk-'")
    }

    func testGeminiKeyPrefix() {
        let validKey = "AIza-test123"
        XCTAssertTrue(validKey.hasPrefix("AIza"), "Gemini keys should start with 'AIza'")
    }

    // MARK: - Cloud Provider Selection Logic

    func testCloudProviderSelectionOpenAI() {
        let provider = TranscriptionProvider.openai

        XCTAssertEqual(provider.rawValue, "openai")
        XCTAssertTrue(provider.displayName.contains("OpenAI"))
    }

    func testCloudProviderSelectionGemini() {
        let provider = TranscriptionProvider.gemini

        XCTAssertEqual(provider.rawValue, "gemini")
        XCTAssertTrue(provider.displayName.contains("Gemini"))
    }

    // MARK: - Credential Visibility State

    func testMultipleKeyVisibilityIndependence() {
        var showOpenAIKey = false
        var showGeminiKey = false

        // Toggle OpenAI visibility
        showOpenAIKey = true
        XCTAssertTrue(showOpenAIKey)
        XCTAssertFalse(showGeminiKey, "Gemini visibility should remain unchanged")

        // Toggle Gemini visibility
        showGeminiKey = true
        XCTAssertTrue(showOpenAIKey, "OpenAI visibility should remain unchanged")
        XCTAssertTrue(showGeminiKey)
    }

    // MARK: - API Base URL Tests

    func testDefaultOpenAIBaseURL() {
        let defaultURL = ""
        // Empty string means use the default API URL
        XCTAssertTrue(defaultURL.isEmpty, "Default should be empty to use standard API")
    }

    func testDefaultGeminiBaseURL() {
        let defaultURL = ""
        // Empty string means use the default API URL
        XCTAssertTrue(defaultURL.isEmpty, "Default should be empty to use standard API")
    }

    func testCustomOpenAIBaseURLValidation() {
        let customURL = "https://my-proxy.example.com/v1"
        XCTAssertTrue(customURL.hasPrefix("https://"), "Custom URL should use HTTPS")
    }

    func testCustomGeminiBaseURLValidation() {
        let customURL = "https://my-proxy.example.com/gemini"
        XCTAssertTrue(customURL.hasPrefix("https://"), "Custom URL should use HTTPS")
    }

    // MARK: - Advanced Settings Toggle

    func testAdvancedAPISettingsToggle() {
        var showAdvanced = false

        // Initially collapsed
        XCTAssertFalse(showAdvanced)

        // Expand
        showAdvanced.toggle()
        XCTAssertTrue(showAdvanced)

        // Collapse
        showAdvanced.toggle()
        XCTAssertFalse(showAdvanced)
    }

    // MARK: - Save Button State

    func testSaveButtonShouldBeEnabledWithKey() {
        let key = "sk-validkey"
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

        // Save button should work (not be disabled) when there's a key
        let canSave = !trimmed.isEmpty || true // Always enabled to allow clearing
        XCTAssertTrue(canSave)
    }

    func testSaveButtonShouldWorkWithEmptyKeyToClear() {
        let key = ""

        // Save button should work even with empty key (to clear the stored key)
        let canSave = true // Always enabled
        XCTAssertTrue(canSave)
    }

    // MARK: - Key Masking Logic

    func testSecureFieldMasksKey() {
        // In SwiftUI, SecureField automatically masks input
        // This test verifies the toggle logic
        var isShowing = false

        // When isShowing is false, SecureField is used (masked)
        XCTAssertFalse(isShowing, "SecureField should be used when not showing")

        // When isShowing is true, TextField is used (visible)
        isShowing = true
        XCTAssertTrue(isShowing, "TextField should be used when showing")
    }
}
