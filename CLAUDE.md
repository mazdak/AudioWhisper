# AudioWhisper - Claude Development Notes

## Project Overview
AudioWhisper is a macOS menu bar app for quick audio recording and transcription using OpenAI Whisper or Google Gemini.

## Important Requirements
- **Target Platform**: macOS 14+ (Sonoma and later)
- **No Warnings Policy**: The code must compile without any warnings
- **Deployment Target**: Set in Package.swift to macOS(.v14)

## Development vs Release Builds

### Development (Recommended for testing)
Use these commands for day-to-day development and testing:
```bash
# Check for compilation errors and warnings
swift build

# Run the app directly (no app bundle needed)
swift run
```

### Release Builds (For distribution)
Only use `build.sh` when creating a release for distribution:
```bash
# Create distributable app bundle with icon and proper signing
./build.sh

# Create notarized release (requires Apple Developer account)
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name"
export AUDIO_WHISPER_APPLE_ID='your-apple-id@example.com'
export AUDIO_WHISPER_APPLE_PASSWORD='your-app-specific-password'
export AUDIO_WHISPER_TEAM_ID='your-team-id'
./build.sh --notarize
```

**Important**: The build script creates a hardened runtime app with proper entitlements for distribution. For development, always use `swift run` to avoid signing/entitlement issues.

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
7. **SmartPaste** - Intelligently pastes transcribed text to the previously active app
8. **API Key Management** - UI for setting OpenAI/Gemini keys in Keychain
9. **Start at Login** - Defaults to enabled, configurable in settings
10. **First-Run Experience** - Welcome dialog and automatic settings on first launch
11. **App Bundle Creation** - Proper macOS app with real icon from MicrophoneIcon.jpg
12. **Local Transcription** - Fully offline whisper.cpp integration with model management
13. **Immediate Recording** - Option to start recording immediately on hotkey
14. **Auto-Boost Microphone Volume** - Temporarily increases mic volume to 100% during recording
15. **Enhanced Model Management** - Real-time model detection, visual progress feedback, smart download estimates
16. **Parakeet Support (Advanced)** - MLX-based local transcription for Apple Silicon with custom Python integration and native Swift audio processing

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

### SmartPaste Testing
- [ ] Target app detection works before recording
- [ ] Automatic app switching after transcription
- [ ] Accessibility permissions properly requested
- [ ] Fallback to manual paste when automatic fails
- [ ] SmartPaste disabled when setting is off
- [ ] Proper handling of terminated target apps
- [ ] Security validation (blocked system apps)
- [ ] Multiple rapid hotkey presses handled gracefully
- [ ] Memory cleanup after extended usage sessions

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

## Advanced Audio Features

### Auto-Boost Microphone Volume
- **Purpose**: Automatically maximizes microphone input volume during recording
- **Setting**: Enable/disable in Settings > General > "Auto-Boost Microphone Volume"
- **Behavior**: 
  - Temporarily sets mic volume to 100% when recording starts
  - Restores original volume when recording stops, is cancelled, or fails
  - Uses Core Audio APIs for precise volume control
  - Works with built-in and many external microphones
- **Benefits**: Ensures optimal audio levels without manual adjustment
- **Compatibility**: May not work with all USB/external microphones due to driver limitations

### Immediate Recording
- **Purpose**: Skip the "press space to record" step
- **Setting**: Enable/disable in Settings > General > "Start Recording Immediately"
- **Behavior**: Recording begins instantly when hotkey is pressed
- **Use Case**: Faster workflow for frequent users

### Enhanced Model Management
- **Real-time Detection**: File system monitoring detects downloaded models automatically
- **Visual Progress**: Download stages shown with estimated time remaining
- **Smart Estimates**: Download time calculated based on model size and connection speed
- **Storage Monitoring**: Prevents downloads if insufficient disk space
- **Background Downloads**: Continue even when settings window is closed
- **System Notifications**: Alerts when model downloads complete

### Parakeet (Advanced Users Only)
- **MLX-Optimized**: Uses parakeet-mlx for Apple Silicon optimization
- **Custom Python**: Requires user to configure Python path with parakeet-mlx installed
- **Native Audio Processing**: Uses integrated Swift AudioProcessor for optimal performance
- **Fast Processing**: Leverages Apple's Metal Performance Shaders via MLX
- **Advanced Setup**: Not recommended for casual users due to Python dependencies

#### Parakeet Setup Instructions
1. Install Python 3 (if not already installed)
2. Install parakeet-mlx: `uv add parakeet-mlx -U` or `pip install parakeet-mlx`
3. In AudioWhisper Settings, select "Parakeet (Advanced)" as provider
4. Configure Python path (default: /usr/bin/python3)
5. Click "Test" to verify setup
6. Model downloads automatically on first use from Hugging Face

#### Native Audio Processing
- **No FFmpeg Required**: Uses integrated Swift AudioProcessor for optimal performance
- **Direct Integration**: Audio processing logic built directly into ParakeetService
- **Native Performance**: Direct use of macOS AudioToolbox APIs
- **Optimized Pipeline**: Swift audio processing → raw PCM → Python MLX processing

## SmartPaste Technology

### Intelligent Target App Detection
- **Smart Context Awareness**: Automatically detects and remembers the app you were using before activating AudioWhisper
- **Seamless Workflow**: Returns focus and pastes transcribed text to the correct application
- **Multi-App Support**: Handles various text input applications (editors, browsers, messaging apps)
- **Fallback Mechanism**: Gracefully handles edge cases when target app detection fails

### How SmartPaste Works
1. **Pre-Recording Detection**: Captures the frontmost application before showing recording window
2. **Context Preservation**: Stores target app reference during recording session  
3. **Post-Transcription Return**: Automatically switches back to original app
4. **Intelligent Pasting**: Uses system-level paste events for reliable text insertion

### SmartPaste Behavior
- **Automatic Activation**: Target app is brought to foreground automatically
- **Accessibility Integration**: Uses macOS Accessibility APIs for reliable app switching
- **Permission-Based**: Requires Accessibility permissions for full functionality
- **User Control**: Can be disabled in settings if automatic pasting is unwanted

### Supported Applications
SmartPaste works with most standard macOS applications that accept text input:
- **Text Editors**: TextEdit, VS Code, Xcode, Sublime Text, etc.
- **Browsers**: Safari, Chrome, Firefox (text fields, content-editable areas)
- **Communication**: Messages, Slack, Discord, Mail, etc.
- **Productivity**: Notes, Pages, Word, Google Docs, etc.
- **Development**: Terminal, iTerm2, and other command-line interfaces

### Accessibility Requirements
SmartPaste requires specific macOS permissions to function properly:

#### Required Permissions
- **Accessibility Access**: Allows AudioWhisper to detect active applications and send paste events
- **Microphone Access**: Standard permission for audio recording functionality

#### Permission Setup
1. **First Launch**: AudioWhisper automatically requests necessary permissions
2. **Manual Setup**: If needed, permissions can be granted in System Settings > Privacy & Security
3. **Accessibility**: Add AudioWhisper to "Accessibility" in Privacy settings
4. **Verification**: App provides clear feedback about permission status

#### Permission Troubleshooting
**If SmartPaste isn't working:**
1. Check System Settings > Privacy & Security > Accessibility
2. Ensure AudioWhisper is listed and enabled
3. Remove and re-add AudioWhisper if permission seems granted but not working
4. Restart AudioWhisper after permission changes

**Alternative Methods:**
- Manual paste: If automatic pasting fails, text is copied to clipboard for manual pasting
- Settings toggle: SmartPaste can be disabled in app settings if not desired

## Troubleshooting SmartPaste Issues

### Common SmartPaste Problems

#### Problem: Text doesn't paste automatically
**Possible Causes:**
- Missing Accessibility permissions
- Target app doesn't accept programmatic paste events
- App was terminated or became unresponsive

**Solutions:**
1. Verify Accessibility permissions in System Settings
2. Check if target app is still running and responsive
3. Try manual paste using Cmd+V (text is always copied to clipboard)
4. Restart both apps if issue persists

#### Problem: Wrong app receives the pasted text
**Possible Causes:**
- User switched apps during recording
- Multiple windows of same app open
- Target app detection race condition

**Solutions:**
1. Avoid switching apps while recording
2. Ensure target app window is visible and focused before recording
3. Use manual paste to control destination precisely

#### Problem: App activation takes too long
**Possible Causes:**
- Target app is memory-intensive or slow to respond
- System under heavy load
- App requires user interaction to activate

**Solutions:**
1. Close unnecessary applications to free system resources
2. Ensure target app is not blocked by modal dialogs
3. Use manual paste workflow for better control

#### Problem: Paste events don't work in specific apps
**Possible Causes:**
- Some apps block programmatic paste for security
- App uses custom text input methods
- Sandbox restrictions prevent paste events

**Known Affected Apps:**
- Password managers (security restriction)
- Some terminal emulators with paste protection
- Certain web-based applications in browsers

**Workarounds:**
1. Use manual paste (Cmd+V) for affected applications
2. Disable SmartPaste in settings if frequently using incompatible apps
3. Text is always available in clipboard as fallback

### Security Considerations

#### SmartPaste Security Model
- **Principle of Least Privilege**: Only requests minimal permissions needed for functionality
- **User Consent**: All permissions require explicit user approval through macOS dialogs
- **Transparency**: Clear indication when permissions are missing or insufficient
- **Audit Trail**: System logs record permission grants and accessibility usage

#### Privacy Protection
- **No Content Analysis**: AudioWhisper never analyzes or stores pasted content
- **Local Processing**: All transcription and paste operations happen locally on device
- **App Boundary Respect**: Only interacts with user-specified target applications
- **Session Isolation**: Target app selection is temporary and session-specific

#### Security Best Practices
- **Blocked System Apps**: Prevents pasting into security-sensitive system applications
- **Bundle ID Validation**: Verifies target app identity before pasting
- **Graceful Degradation**: Falls back to manual paste when automatic paste poses risks
- **User Override**: Settings allow disabling automatic paste for security-conscious users

#### Potential Security Implications
**Positive Security Aspects:**
- Reduces clipboard exposure time (immediate paste vs. lingering clipboard content)
- Eliminates accidental pasting in wrong applications
- Provides clear audit trail of where text was pasted

**Security Considerations:**
- Requires Accessibility permissions (standard for automation tools)
- Could potentially paste sensitive content if misused (user controls transcription)
- Target app detection relies on system APIs (standard macOS behavior)

**Mitigation Strategies:**
- Always copy text to clipboard as backup/verification method
- User retains full control over recording trigger and target app
- Automatic paste can be completely disabled in settings
- Clear visual feedback shows where text will be pasted

## Test Coverage Areas

### Current Test Coverage
- Audio recording functionality
- Speech-to-text service integration
- Settings persistence and validation
- Model management and downloads
- Basic UI component rendering

### Missing Test Coverage (High Priority)
- **SmartPaste Integration Tests**
  - Target app detection during recording
  - App termination scenarios during recording session
  - Permission denial handling and fallback behavior
  - CGEvent paste failure recovery
  - Multiple rapid hotkey activation handling

- **Memory Management Tests**
  - Static property cleanup when apps terminate
  - Observer lifecycle management in ContentView
  - Race condition testing for concurrent app switching
  - Memory leak detection for long-running sessions

- **Security & Edge Case Tests**
  - Accessibility permission revocation during use
  - Invalid target app handling (terminated, blocked apps)
  - Paste event security validation
  - App activation timeout scenarios
  - System app blocking validation

### Recommended Test Structure
```swift
class SmartPasteTests: XCTestCase {
    func testTargetAppStorageWhenAppTerminates() {
        // Verify cleanup when stored app terminates
    }
    
    func testFallbackBehaviorWhenActivationFails() {
        // Test graceful fallback mechanisms
    }
    
    func testPermissionDenialHandling() {
        // Test UX when permissions are denied
    }
    
    func testRapidHotkeyPresses() {
        // Test system stability under rapid activation
    }
    
    func testMemoryLeakPrevention() {
        // Verify proper cleanup of observers and references
    }
}

class AccessibilityTests: XCTestCase {
    func testPermissionRequestFlow() {
        // Test permission request and denial scenarios
    }
    
    func testPasteEventSecurity() {
        // Verify paste events only reach intended apps
    }
}
```

## Future Enhancements
- Streaming transcription for real-time feedback
- Multiple language support
- Custom hotkey configuration UI
- Audio file history
- Core ML model optimization
- Batch transcription support
- SmartPaste memory management improvements
- Enhanced target app validation and security