# AudioWhisper - Claude Development Notes

## Project Overview
AudioWhisper is a macOS menu bar app for quick audio recording and transcription using OpenAI Whisper or Google Gemini.

## Important Requirements
- **Target Platform**: macOS 14+ (Sonoma and later)
- **No Warnings Policy**: The code must compile without any warnings
- **Deployment Target**: Set in Package.swift to macOS(.v14)

## Build Commands
Always run these commands to check your work:
```bash
# Check for compilation errors and warnings
swift build

# Build release version
swift build -c release

# Run the app
swift run

# Create distributable app bundle with icon
./build.sh
```

## Test Commands
Run these commands to verify code quality and functionality:
```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter AudioRecorderTests
swift test --filter SpeechToTextServiceTests
swift test --filter SettingsViewTests

# Run tests with verbose output
swift test --verbose

# Run tests in parallel (faster)
swift test --parallel

# Run tests with code coverage
swift test --enable-code-coverage
```

## Distributable App Bundle
The `build.sh` script creates a proper macOS app bundle:
- Generates app icon from MicrophoneIcon.jpg
- Creates Info.plist with proper permissions
- Bundles everything into AudioWhisper.app
- Ready to copy to /Applications/

### Development vs. Production Permissions
**During Development (Xcode/swift run):**
- Microphone and Keychain permissions requested every launch
- App gets new bundle signature each build
- Normal development behavior

**Production App Bundle:**
- Permissions remembered after first grant
- Stable bundle identifier (com.audiowhisper.app)
- Keychain access persists between launches

**Code Signing (Optional):**
```bash
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name"
./build.sh
```

## Key Features Implemented
1. **Menu Bar App** - Lives in menu bar with microphone.circle SF Symbol
2. **Global Hotkey** - Cmd+Shift+Space to toggle recording window
3. **Chromeless Recording Window** - Spotlight-style floating window
4. **Proper Settings Window** - Traditional macOS window with close button
5. **Visual Audio Levels** - Real-time audio level indicator while recording
6. **Keyboard Shortcuts** - Space to start/stop, ESC to cancel/dismiss
7. **Auto-paste** - Automatically pastes transcribed text to previous app
8. **API Key Management** - UI for setting OpenAI/Gemini keys in Keychain
9. **Start at Login** - Defaults to enabled, configurable in settings
10. **First-Run Experience** - Welcome dialog and automatic settings on first launch
11. **App Bundle Creation** - Proper macOS app with real icon from MicrophoneIcon.jpg
12. **Local Transcription** - Fully offline whisper.cpp integration with model management

## Architecture Notes
- SwiftUI app with AppKit integration for menu bar
- Uses AVFoundation for audio recording
- Alamofire for API requests and model downloads
- HotKey library for global keyboard shortcuts
- Keychain for secure API key storage
- WhisperKit for local transcription with CoreML acceleration
- ModelManager for whisper model download and storage management

## Common Issues to Avoid
1. **No iOS APIs** - This is macOS only, avoid AVAudioSession and similar iOS-only APIs
2. **Use Modern APIs** - Target macOS 14+, use latest SwiftUI APIs
3. **Dark Mode Support** - All UI elements must work in both light and dark mode
4. **Keychain Access** - API keys stored securely, not in UserDefaults

## Known System Warnings (Harmless)
These warnings appear when recording starts but don't affect functionality:
- `AddInstanceForFactory: No factory registered for id...` - AVFoundation audio component initialization
- `LoudnessManager.mm: PlatformUtilities::CopyHardwareModelFullName() returns unknown value: Mac16,13` - Your Mac model isn't recognized by older audio framework code

These are from Apple's frameworks, not our code. They can be safely ignored.

## Testing Checklist
- [x] Build without warnings
- [x] Menu bar icon appears correctly
- [x] Global hotkey works
- [x] Audio levels display during recording
- [x] Transcription works with all providers (OpenAI, Gemini, Local)
- [x] Settings save correctly
- [x] Dark mode looks good
- [x] Local model download and management works
- [x] Local transcription processes audio correctly
- [x] Model storage management functions properly

## Local Transcription Features (WhisperKit)
- **Privacy-First**: Audio never leaves your device
- **Offline Operation**: Works without internet connection
- **Multiple Models**: 6 whisper models from Tiny (39MB) to Large (2.9GB)
- **Apple Silicon Optimized**: CoreML acceleration with Neural Engine support
- **Automatic Model Management**: Models downloaded and cached automatically
- **Modern Swift Integration**: Built with WhisperKit for optimal performance
- **Native CoreML**: Uses Apple's CoreML framework for hardware acceleration

### Available Whisper Models
- **Tiny (39MB)**: Fastest, basic accuracy (`openai_whisper-tiny`)
- **Base (142MB)**: Good balance of speed and accuracy (recommended) (`openai_whisper-base`)
- **Small (466MB)**: Better accuracy, reasonable speed (`openai_whisper-small`)
- **Medium (1.5GB)**: High accuracy, slower processing (`openai_whisper-medium`)
- **Large v3 (2.9GB)**: Highest accuracy, slowest (`openai_whisper-large-v3`)
- **Large Turbo (1.5GB)**: High accuracy with optimized speed (`openai_whisper-large-v3-turbo`)

### Local Transcription Usage
1. Open Settings (Cmd+Comma)
2. Select "Local Whisper" as transcription provider
3. Choose desired model size
4. Models download automatically on first use
5. Record audio as normal - processing happens locally with CoreML acceleration

### Model Storage
- Models managed automatically by WhisperKit
- Stored in WhisperKit's internal cache
- Models persist between app launches
- Model deletion managed by WhisperKit (not user-controllable)
- Storage usage estimated based on model types

## Future Enhancements
- Streaming transcription for real-time feedback
- Multiple language support
- Custom hotkey configuration UI
- Audio file history
- Core ML model optimization
- Batch transcription support