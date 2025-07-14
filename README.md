# AudioWhisper 🎙️

A lightweight macOS menu bar app for quick audio transcription using OpenAI Whisper, Google Gemini, Local WhisperKit, or Nvidia Parakeet. Press a hotkey, record your thoughts, and get instant text that's automatically copied to your clipboard.

<p align="center">
  <img src="https://github.com/mazdak/AudioWhisper/blob/master/AudioWhisperIcon.png" width="128" height="128" alt="AudioWhisper Icon">
</p>

## Features ✨

- **🎯 Quick Access**: Global hotkey (⌘⇧Space) to start recording from anywhere
- **🎙️ Menu Bar App**: Lives quietly in your menu bar, no dock icon
- **🚀 Instant Transcription**: Powered by OpenAI Whisper, Google Gemini, Local WhisperKit with CoreML, or Parakeet-MLX
- **📋 Smart Paste**: Transcribed text is automatically copied and can be pasted
- **🔈 Visual and Sound Feedback**: Real-time audio level indicator while recording, chime when finished transcription
- **⌨️ Keyboard Shortcuts**: Space to start/stop recording, ESC to cancel
- **💬 User Guidance**: Clear on-screen instructions for all actions
- **🌓 Dark Mode**: Beautiful native macOS design that adapts to your system
- **🔐 Secure**: API keys stored in macOS Keychain
- **🔒 Privacy-First**: Local transcription option keeps audio on your device
- **⚡ Lightweight**: Minimal resource usage, starts with your Mac

## Requirements 📋

- macOS 14.0 (Sonoma) or later  
- OpenAI API key, Google Gemini API key, Local Whisper (no API key required), or Parakeet with Python
- Swift 5.9+ (for building from source)

## Installation 🛠️

### Option 1: Download Pre-built App
1. Download the latest release from [Releases](https://github.com/mazdak/AudioWhisper/releases)
2. Drag AudioWhisper.app to your Applications folder
3. Launch and configure your API key through the settings

### Option 2: Build from Source
```bash
# Clone the repository
git clone https://github.com/mazdak/AudioWhisper.git
cd AudioWhisper

# Build the app
./build.sh

# Copy to Applications
cp -r AudioWhisper.app /Applications/
```

## Setup 🔧

### Transcription Options

**Local WhisperKit (Privacy-First)**
- No API key required
- Audio never leaves your device
- CoreML hardware acceleration with Neural Engine support
- Choose from 6 different model sizes (39MB to 2.9GB)
- Models download automatically on first use

**Local Parakeet (VERY Fast, English only, Privacy-First)**
- No API key required
- Audio never leaves your device
- MLX hardware acceleration
- ADVANCED: Make sure you have a Python installation on your machine: [Parakeet MLX Instructions](https://github.com/senstella/parakeet-mlx).
- Pick Parakeet (Advanced) and enter the full path to your Python binary

**OpenAI (Recommended for Cloud)**
1. Visit https://platform.openai.com/api-keys
2. Create a new API key
3. Copy the key starting with `sk-`

**Google Gemini**
1. Visit https://makersuite.google.com/app/apikey
2. Create a new API key
3. Copy the key starting with `AIza`

**Parakeet (Advanced)**
- Local transcription using MLX framework for Apple Silicon optimization
- Requires Python with parakeet-mlx installed
- First use downloads ~600MB model from Hugging Face
- Setup instructions:
  ```bash
  
  # Install parakeet-mlx 
  uv add parakeet-mlx -U
  # or
  pip install parakeet-mlx
  ```
- Configure Python path in settings (usually `/usr/bin/python3`)

### First Run

1. Launch AudioWhisper from Applications
2. The app will detect no API keys and show a welcome dialog
3. Click OK to open Settings
4. Choose your preferred provider:
   - **Local WhisperKit**: Select model size (downloads automatically, no API key needed)
   - **OpenAI or Gemini**: Paste your API key and click "Save"
   - **Advanced: Parakeet 🦜**: You need a working Python 3 installation with `parakeet-mlx` installed.

5. Toggle "Start at Login" if you want the app to launch automatically

## Usage 🎯

1. **Quick Recording**: Press ⌘⇧Space anywhere to open the recording window
2. **Start Recording**: Click the blue microphone button or press Space
3. **Stop Recording**: Click the button again or press Space
4. **Cancel**: Press ESC at any time to dismiss the window
5. **Auto-Paste**: After transcription, text is automatically copied and pasted to the previous app

The app lives in your menu bar - click the microphone icon for quick access to recording or settings.

### On-Screen Instructions
The recording window shows helpful instructions at the bottom:
- **Ready**: "Press Space to record • Escape to close"
- **Recording**: "Press Space to stop • Escape to cancel"
- **Processing**: "Processing audio..."
- **Success**: "Text copied to clipboard"

## Building from Source 👨‍💻

### Prerequisites
- Xcode 15.0 or later
- Swift 5.9 or later

### Development Build
```bash
# Clone the repository
git clone https://github.com/mazdak/AudioWhisper.git
cd AudioWhisper

# Run in development mode
swift run

# Build for release
swift build -c release

# Create full app bundle with icon
./build.sh
```

## Privacy & Security 🔒

- **Local Transcription**: Choose Local WhisperKit to keep audio completely on your device
- **Third Party Processing**: OpenAI/Google options transmit audio for transcription
- **Keychain Storage**: API keys are securely stored in macOS Keychain
- **No Tracking**: We don't collect any usage data or analytics
- **Microphone Permission**: You'll be prompted once on first use
- **Open Source**: Audit the code yourself for peace of mind

## Keyboard Shortcuts ⌨️

| Action | Shortcut |
|--------|----------|
| Toggle Recording Window | ⌘⇧Space |
| Start/Stop Recording | Space |
| Cancel/Close Window | ESC |
| Open Settings | Click menu bar → Settings |

## Troubleshooting 🔧

**"Unidentified Developer" Warning**
- Right-click the app and select "Open" instead of double-clicking
- Click "Open" in the security dialog

**Microphone Permission**
- Go to System Settings → Privacy & Security → Microphone
- Ensure AudioWhisper is enabled

**API Key Issues**
- Verify your API key is correct in Settings
- Check your API quota/credits
- Try switching between OpenAI and Gemini

**Recording Window Issues**
- The window floats above all apps
- Click outside or press ESC to dismiss
- Use ⌘⇧Space to toggle visibility

**Parakeet Setup Issues**
- Ensure Python and parakeet-mlx are installed: `python3 -c "import parakeet_mlx; print('OK')"`
- Use "Test" button in settings to validate setup
- Check Python path is correct (usually `/usr/bin/python3`)
- For custom Python installations, specify full path to python executable

## Contributing 🤝

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License 📄

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Dependencies 📦

- [Alamofire](https://github.com/Alamofire/Alamofire) - MIT License
- [HotKey](https://github.com/soffes/HotKey) - MIT License
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - MIT License

## Acknowledgments 🙏

- Built with SwiftUI and AppKit
- Uses OpenAI Whisper API for cloud transcription
- Supports Google Gemini as an alternative
- Local transcription powered by WhisperKit with CoreML acceleration
- Parakeet-MLX library for providing an easy accelerated Python interface

---

Made with ❤️ for the macOS community. If you find this useful, please consider starring the repository!
