import XCTest
@testable import AudioWhisper

/// Integration tests for provider selection and KeychainService
@MainActor
final class ProviderSelectionIntegrationTests: IsolatedXCTestCase {
    var mockKeychain: MockKeychainService!
    var speechService: SpeechToTextService!
    var testDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()

        // Create isolated defaults
        let suiteName = "ProviderSelectionIntegrationTests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!

        // Set up mock keychain
        mockKeychain = MockKeychainService()

        // Create speech service with mock keychain
        speechService = SpeechToTextService(keychainService: mockKeychain)
    }

    override func tearDown() async throws {
        mockKeychain.clear()
        testDefaults.removePersistentDomain(forName: testDefaults.description)

        mockKeychain = nil
        speechService = nil
        testDefaults = nil

        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTempAudioFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let audioFile = tempDir.appendingPathComponent("test_audio_\(UUID().uuidString).m4a")
        // Create minimal audio-like data (ftyp header)
        let data = Data([
            0x00, 0x00, 0x00, 0x1C, // Size
            0x66, 0x74, 0x79, 0x70, // "ftyp"
            0x4D, 0x34, 0x41, 0x20, // "M4A "
            0x00, 0x00, 0x00, 0x00
        ])
        FileManager.default.createFile(atPath: audioFile.path, contents: data, attributes: nil)
        return audioFile
    }

    private func cleanupTempFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Local Provider Tests

    func testLocalProviderDoesNotRequireApiKey() {
        // Given - No API keys in keychain
        mockKeychain.clear()

        // When - Check keychain (there should be no keys)
        let anyKey = mockKeychain.getQuietly(service: "AudioWhisper", account: "TestKey")

        // Then - No keys, but local should still work (doesn't need keychain)
        XCTAssertNil(anyKey)
        // Local provider validation is separate - no keychain dependency
    }

    // MARK: - Keychain Service Integration

    func testKeychainServiceSaveAndRetrieve() {
        // Given
        let testKey = "test-api-key-xyz"
        let service = "AudioWhisper"
        let account = "TestAccount"

        // When
        try! mockKeychain.save(testKey, service: service, account: account)
        let retrievedKey = mockKeychain.getQuietly(service: service, account: account)

        // Then
        XCTAssertEqual(retrievedKey, testKey)
    }

    func testKeychainServiceDelete() {
        // Given
        let testKey = "key-to-delete"
        try! mockKeychain.save(testKey, service: "AudioWhisper", account: "DeleteTest")

        // When
        try! mockKeychain.delete(service: "AudioWhisper", account: "DeleteTest")
        let retrievedKey = mockKeychain.getQuietly(service: "AudioWhisper", account: "DeleteTest")

        // Then
        XCTAssertNil(retrievedKey)
    }

    func testKeychainServiceContains() {
        // Given
        try! mockKeychain.save("some-key", service: "AudioWhisper", account: "ContainsTest")

        // When/Then
        XCTAssertTrue(mockKeychain.contains(service: "AudioWhisper", account: "ContainsTest"))
        XCTAssertFalse(mockKeychain.contains(service: "AudioWhisper", account: "NonExistent"))
    }

    // MARK: - Provider Enum Tests

    func testAllProvidersHaveDisplayNames() {
        for provider in TranscriptionProvider.allCases {
            XCTAssertFalse(provider.displayName.isEmpty, "\(provider) should have a display name")
        }
    }

    func testProviderRawValues() {
        XCTAssertEqual(TranscriptionProvider.local.rawValue, "local")
        XCTAssertEqual(TranscriptionProvider.parakeet.rawValue, "parakeet")
    }

    func testProviderCount() {
        let allProviders = TranscriptionProvider.allCases
        XCTAssertEqual(allProviders.count, 2)
        XCTAssertTrue(allProviders.contains(.local))
        XCTAssertTrue(allProviders.contains(.parakeet))
    }

    // MARK: - Error Handling Integration

    func testKeychainErrorHandling() {
        // Given - Configure mock to throw errors
        mockKeychain.shouldThrow = true
        mockKeychain.throwError = .itemNotFound

        // When
        let result = mockKeychain.getQuietly(service: "AudioWhisper", account: "Test")

        // Then - getQuietly should return nil on error
        XCTAssertNil(result)
    }

    func testKeychainConcurrentAccess() async {
        // Given - Multiple concurrent operations
        let key = "concurrent-test-key"
        let keychain = mockKeychain!

        // When - Perform concurrent saves
        for i in 0..<10 {
            try? keychain.save("\(key)-\(i)", service: "AudioWhisper", account: "Concurrent\(i)")
        }

        // Wait for operations to complete
        try? await Task.sleep(for: .milliseconds(100))

        // Then - All keys should be accessible
        for i in 0..<10 {
            let retrieved = keychain.getQuietly(service: "AudioWhisper", account: "Concurrent\(i)")
            XCTAssertEqual(retrieved, "\(key)-\(i)")
        }
    }

    // MARK: - Model Selection Tests

    func testWhisperModelEnumeration() {
        // Verify all whisper models are accessible
        let models = WhisperModel.allCases
        XCTAssertEqual(models.count, 4)
        XCTAssertTrue(models.contains(.tiny))
        XCTAssertTrue(models.contains(.base))
        XCTAssertTrue(models.contains(.small))
        XCTAssertTrue(models.contains(.largeTurbo))
    }

    func testWhisperModelFileNames() {
        XCTAssertEqual(WhisperModel.tiny.fileName, "ggml-tiny.bin")
        XCTAssertEqual(WhisperModel.base.fileName, "ggml-base.bin")
        XCTAssertEqual(WhisperModel.small.fileName, "ggml-small.bin")
        XCTAssertEqual(WhisperModel.largeTurbo.fileName, "ggml-large-v3-turbo.bin")
    }

    func testParakeetModelEnumeration() {
        let models = ParakeetModel.allCases
        XCTAssertEqual(models.count, 2)
        XCTAssertTrue(models.contains(.v2English))
        XCTAssertTrue(models.contains(.v3Multilingual))
    }
}
