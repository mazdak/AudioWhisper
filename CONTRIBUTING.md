# Contributing to AudioWhisper

Thank you for your interest in contributing to AudioWhisper! This guide will help you get started with development, testing, and distribution.

## Table of Contents
- [Development Setup](#development-setup)
- [Requirements](#requirements)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Building for Distribution](#building-for-distribution)
- [Code Signing](#code-signing)
- [Architecture Overview](#architecture-overview)
- [Coding Standards](#coding-standards)

## Development Setup

### Prerequisites

- **macOS 14.0 (Sonoma) or later** - Required for latest SwiftUI APIs
- **Xcode 15.0+** - For Swift development (optional, can use CLI tools)
- **Swift 5.9+** - Included with Xcode or via [swift.org](https://swift.org)
- **Git** - For version control

### Initial Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/AudioWhisper.git
cd AudioWhisper
```

2. Build the project to verify setup:
```bash
swift build
```

## Requirements

### System Requirements
- macOS 14.0+ (Sonoma and later)
- Apple Silicon (M1/M2/M3) or Intel Mac
- Microphone access permission
- Internet connection (for API-based transcription)

### Development Requirements
- Swift 5.9+
- SwiftUI with macOS 14+ APIs
- No warnings policy - code must compile cleanly

## Development Workflow

### Day-to-Day Development

For regular development, **always use Swift CLI tools** instead of the build script:

```bash
# Check for compilation errors and warnings
swift build

# Run the app directly (no app bundle needed)
swift run

# Run with verbose output
swift run --verbose
```

**Important**: The `build.sh` script is only for creating distributable releases. During development:
- Use `swift run` to avoid signing/entitlement issues
- Permissions are requested on each launch (normal for development)
- App gets new bundle signature each build

### Running Tests

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

### Code Quality Checks

Before committing:

1. Ensure no compiler warnings:
```bash
swift build 2>&1 | grep -i warning
```

2. Run all tests:
```bash
swift test
```

3. Verify the app runs:
```bash
swift run
```

## Building for Distribution

### When to Use build.sh

Only use `build.sh` when creating a release for distribution:
- Creating app bundles for users
- Preparing for code signing
- Building for notarization
- Creating distributable packages

### Basic Release Build

```bash
# Create unsigned app bundle
./build.sh
```

This creates:
- Universal binary (Apple Silicon + Intel)
- Proper app bundle structure
- App icon from AudioWhisperIcon.png
- Info.plist with required permissions

### Signed Release Build

```bash
# With explicit identity
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name"
./build.sh

# Auto-detect Developer ID (if available)
./build.sh
```

### Notarized Release Build

```bash
# Set required environment variables
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name"
export AUDIO_WHISPER_APPLE_ID='your-apple-id@example.com'
export AUDIO_WHISPER_APPLE_PASSWORD='app-specific-password'
export AUDIO_WHISPER_TEAM_ID='your-team-id'

# Build with notarization
./build.sh --notarize
```

## Code Signing

### Free Option: Ad-hoc Signing (Local Use Only)

For personal use without a developer account:

```bash
# Ad-hoc sign after building
codesign --force --deep --sign - AudioWhisper.app
```

**Limitations:**
- Only works on your Mac
- Other users will see security warnings
- Cannot be notarized

### Paid Option: Apple Developer Program ($99/year)

#### 1. Join Apple Developer Program
- Visit [developer.apple.com/programs/](https://developer.apple.com/programs/)
- Sign up for $99/year membership

#### 2. Create Developer ID Certificate

Via Xcode:
1. Open Xcode → Settings → Accounts
2. Click "Manage Certificates"
3. Click "+" → "Developer ID Application"

Via Apple Developer website:
1. Sign in to [developer.apple.com/account](https://developer.apple.com/account)
2. Go to Certificates, IDs & Profiles
3. Create a "Developer ID Application" certificate

#### 3. Find Your Code Signing Identity

```bash
# List all valid signing identities
security find-identity -v -p codesigning

# You'll see something like:
# "Developer ID Application: Your Name (TEAMID)"
```

#### 4. Sign Your App

The build script handles signing automatically if identity is available.

#### 5. Verify Code Signature

```bash
# Check if app is properly signed
codesign --verify --verbose AudioWhisper.app

# Check signature details
codesign -dvv AudioWhisper.app

# Check Gatekeeper approval
spctl -a -v AudioWhisper.app
```

### Notarization

Notarization is required for distribution outside the Mac App Store:

1. **Create App-Specific Password:**
   - Go to [appleid.apple.com](https://appleid.apple.com)
   - Sign in → Security → App-Specific Passwords
   - Generate password for "AudioWhisper Notarization"

2. **Submit for Notarization:**
   Use `./build.sh --notarize` or manually:
   ```bash
   # Create zip
   ditto -c -k --keepParent AudioWhisper.app AudioWhisper.zip
   
   # Submit
   xcrun notarytool submit AudioWhisper.zip \
     --apple-id "your@email.com" \
     --team-id "TEAMID" \
     --password "app-specific-password" \
     --wait
   
   # Staple ticket
   xcrun stapler staple AudioWhisper.app
   ```

### Distribution Options

1. **Direct Download**: Sign, notarize, and zip
2. **Homebrew Cask**: Submit to homebrew-cask repository
3. **Mac App Store**: Requires additional sandboxing (not currently supported)

## Architecture Overview

### Technology Stack
- **SwiftUI**: Modern UI framework for macOS
- **AppKit**: Menu bar integration
- **AVFoundation**: Audio recording
- **Alamofire**: Network requests and downloads
- **HotKey**: Global keyboard shortcuts
- **WhisperKit**: Local transcription with CoreML
- **Keychain**: Secure API key storage

### Key Components
- **Menu Bar App**: Persistent menu bar presence
- **Recording Window**: Chromeless floating window
- **Settings Window**: Traditional macOS preferences
- **Audio Pipeline**: Recording → Processing → Transcription
- **Model Management**: Download and storage of Whisper models

### Project Structure
```
AudioWhisper/
├── Sources/
│   └── AudioWhisper/
│       ├── main.swift              # Entry point
│       ├── AudioWhisperApp.swift   # Main app structure
│       ├── Views/                  # SwiftUI views
│       ├── Services/               # Core services
│       ├── Models/                 # Data models
│       └── Utils/                  # Utilities
├── Tests/                          # Unit tests
├── Package.swift                   # Swift package manifest
├── build.sh                        # Release build script
└── CLAUDE.md                       # AI assistant notes
```

## Coding Standards

### Swift Style
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Keep functions focused and small
- Document complex logic with comments

### SwiftUI Best Practices
- Use `@StateObject` for view-owned objects
- Prefer `@EnvironmentObject` for shared state
- Keep views small and composable
- Support both light and dark modes

### Error Handling
- Use Swift's error handling (`do-catch`)
- Provide meaningful error messages
- Log errors appropriately
- Handle edge cases gracefully

### Testing
- Write unit tests for business logic
- Test error conditions
- Mock external dependencies
- Aim for high code coverage

### Security
- Never hardcode API keys
- Use Keychain for sensitive data
- Validate all user inputs
- Follow principle of least privilege

## Common Issues

### Build Warnings
- **No warnings policy**: Fix all warnings before committing
- Check deployment target matches Package.swift (macOS 14.0)
- Ensure all APIs are available on target OS version

### Permission Issues
- Microphone access required for recording
- Keychain access for API keys
- Automation permission for auto-paste feature

### Known System Warnings
These warnings from Apple's frameworks can be safely ignored:
- `AddInstanceForFactory: No factory registered...`
- `LoudnessManager.mm: unknown value: Mac16,13`

## Getting Help

- **Issues**: Report bugs on GitHub Issues
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Check CLAUDE.md for implementation notes
- **Swift Forums**: [forums.swift.org](https://forums.swift.org) for Swift questions

## License

By contributing to AudioWhisper, you agree that your contributions will be licensed under the same license as the project.
