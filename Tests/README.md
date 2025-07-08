# AudioWhisper Test Suite

A comprehensive test suite for the AudioWhisper macOS application covering all major components and functionality.

## Overview

This test suite provides thorough coverage of the AudioWhisper application including:
- Audio recording and processing
- Speech-to-text API integration
- Settings and preferences management
- Keychain security operations
- UI components and user interactions
- Utility functions and helpers

## Test Structure

```
Tests/
├── README.md                      # This documentation
├── Mocks/                         # Mock objects for external dependencies
│   ├── MockAVAudioEngine.swift    # AVFoundation audio engine mock
│   ├── MockAVAudioRecorder.swift  # Audio recorder mock
│   ├── MockKeychain.swift         # Keychain operations mock
│   └── MockURLSession.swift       # Network session mock
├── AudioRecorderTests.swift       # Audio recording functionality tests
├── SpeechToTextServiceTests.swift # API integration and transcription tests
├── SettingsViewTests.swift        # Settings and preferences tests
└── UtilityTests.swift             # Utility functions and helpers tests
```

## Running Tests

### Prerequisites

- macOS 14.0 or later
- Swift 5.9 or later
- Xcode 15.0 or later (for UI tests)

### Command Line

```bash
# Run all tests
swift test

# Run specific test file
swift test --filter AudioRecorderTests

# Run specific test case
swift test --filter AudioRecorderTests.testStartRecordingUpdatesState

# Run tests with verbose output
swift test --verbose

# Run tests in parallel (faster)
swift test --parallel
```

### Xcode

1. Open the project in Xcode
2. Select the test target
3. Use `⌘+U` to run all tests
4. Use `⌘+Ctrl+U` to run tests in the current file

## Test Categories

### 1. AudioRecorderTests
**Focus**: Audio recording functionality, state management, and audio level monitoring

**Key Test Areas**:
- Recording state transitions (`isRecording` property)
- Audio level monitoring and normalization
- File URL generation and uniqueness
- Timer-based level updates
- Performance of recording operations
- Error handling for recording failures

**Critical Tests**:
- `testStartRecordingUpdatesState()` - Ensures recording state updates correctly
- `testAudioLevelUpdatesWhileRecording()` - Verifies audio level monitoring
- `testNormalizeLevelWithValidInput()` - Tests dB to linear conversion
- `testRecordingURLGeneration()` - Validates file naming and path generation

### 2. SpeechToTextServiceTests
**Focus**: API integration, provider selection, and transcription workflows

**Key Test Areas**:
- OpenAI Whisper API integration
- Google Gemini API integration
- Provider selection logic
- Error handling for API failures
- Keychain API key management
- Response parsing and validation

**Critical Tests**:
- `testProviderSelectionDefaultsToOpenAI()` - Verifies default provider logic
- `testWhisperResponseDecoding()` - Tests JSON response parsing
- `testGeminiResponseDecoding()` - Tests Gemini response structure
- `testAPIKeyFromKeychain()` - Validates secure key retrieval

### 3. SettingsViewTests
**Focus**: User preferences, microphone discovery, and system integration

**Key Test Areas**:
- UserDefaults persistence
- Microphone device discovery
- API key storage and retrieval
- Provider selection preferences
- Global hotkey configuration
- Start-at-login functionality

**Critical Tests**:
- `testMicrophoneDiscovery()` - Ensures audio device enumeration works
- `testAPIKeyKeychain()` - Validates secure key storage
- `testProviderSelectionPersistence()` - Tests preference persistence
- `testConcurrentAPIKeyOperations()` - Verifies thread safety

### 4. UtilityTests
**Focus**: Helper functions, data conversion, and system utilities

**Key Test Areas**:
- File system operations
- Data encoding/decoding
- URL validation
- Timer operations
- String manipulation
- Memory management

**Critical Tests**:
- `testTemporaryFileCreation()` - Validates file handling
- `testBase64AudioEncoding()` - Tests audio data conversion
- `testTimerCreation()` - Ensures timer functionality
- `testMemoryLeakPrevention()` - Prevents memory leaks

## Mock Objects

### MockAVAudioRecorder
Simulates `AVAudioRecorder` behavior without requiring actual audio hardware:
- Controllable recording states
- Configurable audio levels
- Simulate recording failures
- Test delegate callbacks

### MockURLSession
Provides network request mocking for API tests:
- Configurable responses
- Error simulation
- Request validation
- Async operation testing

### MockKeychain
Simulates keychain operations without system keychain access:
- In-memory storage
- Error condition simulation
- Thread-safe operations
- Cleanup utilities

### MockAVAudioEngine
Mocks audio engine functionality:
- Input node simulation
- Running state control
- Audio processing pipeline

## Test Data Management

### Temporary Files
Tests that require file operations use temporary files that are automatically cleaned up:
```swift
let tempDir = FileManager.default.temporaryDirectory
let testFile = tempDir.appendingPathComponent("test_audio.m4a")
// File automatically cleaned up in tearDown()
```

### UserDefaults Isolation
Each test clears relevant UserDefaults keys to ensure test isolation:
```swift
override func tearDown() {
    UserDefaults.standard.removeObject(forKey: "selectedMicrophone")
    UserDefaults.standard.removeObject(forKey: "useOpenAI")
    super.tearDown()
}
```

### API Key Testing
Tests that require API keys use mock keychain service for secure testing:
```swift
let mockKeychain = MockKeychainService()
mockKeychain.saveQuietly("test-key", service: "AudioWhisper", account: "OpenAI")
// Test code
// Cleanup handled automatically by test teardown
```

## Performance Testing

Performance tests are included to ensure the application remains responsive:

### Audio Processing Performance
- Recording start/stop operations
- Audio level normalization
- File I/O operations

### API Response Processing
- JSON parsing performance
- Large response handling
- Concurrent request processing

### UI Responsiveness
- Settings loading time
- Microphone discovery performance
- Keychain operations

## Test Coverage Goals

- **Functionality**: All major features tested
- **Edge Cases**: Error conditions and boundary values
- **Integration**: Component interactions
- **Performance**: Response time requirements
- **Security**: Keychain and API key handling
- **Concurrency**: Thread safety and race conditions

## Common Test Patterns

### Async Testing
```swift
func testAsyncOperation() async {
    do {
        let result = try await service.transcribe(audioURL: testURL)
        XCTAssertFalse(result.isEmpty)
    } catch {
        XCTFail("Unexpected error: \(error)")
    }
}
```

### Publisher Testing (Combine)
```swift
func testPublisher() {
    let expectation = XCTestExpectation(description: "Publisher should emit")
    
    audioRecorder.$isRecording
        .sink { isRecording in
            XCTAssertTrue(isRecording)
            expectation.fulfill()
        }
        .store(in: &cancellables)
    
    audioRecorder.startRecording()
    wait(for: [expectation], timeout: 1.0)
}
```

### Error Testing
```swift
func testErrorHandling() {
    do {
        _ = try await service.transcribe(audioURL: invalidURL)
        XCTFail("Expected error")
    } catch let error as SpeechToTextError {
        XCTAssertEqual(error, .invalidURL)
    } catch {
        XCTFail("Unexpected error type")
    }
}
```

## Troubleshooting

### Common Issues

1. **Permission Dialogs**: Some tests may trigger system permission dialogs
   - Run tests in a clean environment
   - Grant microphone permissions when prompted

2. **Network Tests**: API tests may fail without internet connection
   - Tests are designed to work offline by testing error conditions
   - Mock objects prevent actual network calls

3. **Keychain Access**: Keychain tests may fail in sandboxed environments
   - Tests use isolated keychain items
   - Cleanup ensures no interference between tests

4. **Audio Device Tests**: May fail in virtual environments
   - Tests detect available audio devices
   - Fallback to system defaults when no devices available

### Test Isolation

Each test is designed to be independent:
- No shared state between tests
- Clean setup and teardown
- Mock objects reset between tests
- Temporary files automatically cleaned up

## Contributing

When adding new tests:

1. **Follow naming conventions**: `test[ComponentName][Behavior]()`
2. **Include setup/teardown**: Clean state for each test
3. **Use descriptive assertions**: Clear error messages
4. **Add performance tests**: For new functionality
5. **Document complex tests**: Add comments for complex test logic
6. **Test edge cases**: Include boundary conditions and error cases

## Continuous Integration

The test suite is designed to run in CI environments:
- No external dependencies required
- Mock objects prevent flaky tests
- Performance tests have reasonable timeouts
- Clean shutdown and resource cleanup

## Future Enhancements

Potential test suite improvements:
- UI testing with XCTest UI framework
- Integration tests with real API endpoints
- Stress testing with large audio files
- Accessibility testing
- Localization testing for multiple languages