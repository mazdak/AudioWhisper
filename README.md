# AudioWhisper 🎙️

A lightweight macOS menu bar app for quick audio transcription using OpenAI Whisper, Google Gemini, Local WhisperKit, or Parakeet‑MLX. Press a hotkey, record your thoughts, and get instant text that's automatically copied to your clipboard.

<p align="center">
  <img src="https://github.com/mazdak/AudioWhisper/blob/master/AudioWhisperIcon.png" width="128" height="128" alt="AudioWhisper Icon">
</p>

## Features ✨

- **Global hotkey + push‑to‑talk**: Default ⌘⇧Space, optional press‑and‑hold on a modifier key, and an Express Mode that starts/stops with a single hotkey press
- **Multiple engines**: OpenAI Whisper, Google Gemini, offline WhisperKit (CoreML), and Parakeet‑MLX (Apple Silicon, multilingual) with built-in model download/verify tools
- **Semantic clean‑up**: Optional post-processing with local MLX (Apple Silicon) or the same cloud provider to fix typos, punctuation, and filler words — with app-aware categories (Terminal/Coding/Email/etc.)
- **Transcribe files**: Menu bar → “Transcribe Audio File...” to convert existing audio without recording
- **History & insights**: Opt‑in transcription history with search/clear/retention plus a Usage Dashboard (sessions, words, WPM, time/keystrokes saved, rebuild from history)
- **Smart paste & focus**: Clipboard copy plus optional auto‑⌘V; restores focus to the app you were in; plays gentle completion chime
- **Performance helpers**: Auto‑boost mic input while recording, live level meter, start-at-login toggle
- **Secure by default**: API keys in macOS Keychain, local modes keep audio on‑device, no analytics

## What’s New Since v1.5.1

- **Dashboard window** for providers, preferences, permissions, history, categories, and usage stats (Menu bar → **Dashboard...**)
- **On-device Parakeet‑MLX** with one-click dependency setup + model verification (no manual Python path setup)
- **Semantic Correction** (optional): local MLX or cloud, with per-app categories and editable prompts
- **New hotkey modes**: Press & Hold (push-to-talk) and Express Mode (tap to start/stop + paste)
- **Transcribe existing audio files** from the menu bar
- **History + Usage Dashboard** (optional): searchable transcripts, retention policies, and productivity insights

## Requirements 📋

- macOS 14.0 (Sonoma) or later
- Apple Silicon strongly recommended; **required** for Parakeet and local MLX semantic correction (local Whisper works on Intel but is slower)
- Disk space: up to ~1.5 GB for Whisper large‑turbo, ~2.5 GB for Parakeet model cache if enabled
- API keys: OpenAI or Google Gemini for cloud; none needed for Local Whisper/Parakeet/local MLX correction
- Swift 5.9+ (if building from source)

## Installation 🛠️

### Option 1: Homebrew (Recommended)
```bash
# Tap the repository (one-time setup)
brew tap mazdak/tap

# Install AudioWhisper
brew install audiowhisper

# Launch the app
open -a AudioWhisper
```

To update:
```bash
brew upgrade audiowhisper
```

> **Note**: The `mazdak/tap` repository also includes other tools like [LazyRedis](https://github.com/mazdak/lazyredis)

### Option 2: Download Pre-built App
1. Download the latest release from [Releases](https://github.com/mazdak/AudioWhisper/releases)
2. Drag AudioWhisper.app to your Applications folder
3. Launch and configure your API key through the Dashboard

### Option 3: Build from Source
```bash
# Clone the repository
git clone https://github.com/mazdak/AudioWhisper.git
cd AudioWhisper

# Build the app
make build

# Copy to Applications
cp -r AudioWhisper.app /Applications/
```

## Setup 🔧

### Transcription Options

**Local WhisperKit (Offline CoreML)**
- No API key; audio stays on-device
- Four models: Tiny (39 MB), Base (142 MB), Small (466 MB), Large Turbo (1.5 GB)
- Downloads in Dashboard → Providers; uses Neural Engine; storage cap slider + per-model verify/delete

**Parakeet‑MLX (Offline, very fast, multilingual)**
- Apple Silicon only; no API key; audio stays local
- Choose v2 English or v3 Multilingual (~2.5 GB)
- Click “Install Dependencies” to bootstrap the bundled uv/MLX environment, then “Verify Parakeet Model”
- Models cache under `~/.cache/huggingface/hub`

**OpenAI (Cloud)**
1. Get an API key: https://platform.openai.com/api-keys (starts with `sk-`)
2. Optional: set a custom endpoint (Azure/OpenAI-compatible proxy) in Dashboard → Providers → Advanced

**Google Gemini (Cloud)**
1. Get an API key: https://makersuite.google.com/app/apikey (starts with `AIza`)
2. Optional: override the base URL for proxies/self-hosted gateways
3. Large files automatically use the Gemini Files API

**Semantic Correction (Optional)**
- Modes: Off, Local MLX, or Cloud (uses the active provider)
- Local MLX runs fully offline on Apple Silicon; choose a correction model in the Dashboard (models cache under `~/.cache/huggingface/hub`)
- App-aware categories (Terminal/Coding/Chat/Writing/Email/General) can be edited in Dashboard → Categories
- You can override prompts by placing `*_prompt.txt` files in `~/Library/Application Support/AudioWhisper/prompts/` (e.g. `terminal_prompt.txt`)

**History & Usage Stats (Optional)**
- Enable “Save Transcription History” in Dashboard → Preferences; pick retention: 1 week / 1 month / 3 months / forever
- “View History” offers search, expand, delete, or clear-all (all stored locally)
- Usage Dashboard shows sessions, words, WPM, time saved, keystrokes saved; rebuild counters from history or reset with one click

**Productivity Toggles**
- Express Mode: the hotkey starts/stops recording and pastes without opening the window
- Press & Hold: choose a modifier key (⌘/⌥/⌃/Fn) and hold to record; requires Accessibility permission
- Smart Paste: auto ⌘V after transcription; requires Input Monitoring permission
- Auto-boost microphone input while recording, start at login, completion sound toggle

### First Run

1. Launch AudioWhisper from Applications
2. The app will detect no API keys and show a welcome dialog
3. Click OK to open the Dashboard
4. Choose your provider:
   - **Local WhisperKit**: pick a model; download starts automatically
   - **OpenAI or Gemini**: paste your key, optionally set a custom endpoint/base URL
   - **Parakeet‑MLX**: click Install Dependencies → Verify Parakeet Model (Apple Silicon)
   - **Semantic Correction**: pick Off / Local MLX / Cloud

5. (Optional) Enable History + retention, Usage stats, Smart Paste, Express Mode, or Press & Hold
6. Toggle "Start at Login" if you want the app to launch automatically

## Usage 🎯

1. **Quick or Express**: Press ⌘⇧Space. If Express Mode is on, the first press starts recording and the next press stops and pastes without showing the window.
2. **Start Recording**: Click the mic or press Space. If Press & Hold is enabled, hold your chosen modifier key to record.
3. **Stop Recording**: Click/Space again (or release the modifier in Press & Hold). Press ESC anytime to cancel.
4. **Paste**: Text is copied to the clipboard; if Smart Paste is on we auto‑⌘V into the last app and then return focus.
5. **Transcribe a file**: Menu bar → **Transcribe Audio File...** and pick any audio file.

The app lives in your menu bar - click the microphone icon for quick access to recording or the Dashboard.

### On-Screen Instructions
The recording window shows helpful instructions at the bottom:
- **Ready**: "Press Space to record • Escape to close"
- **Recording**: "Press Space to stop • Escape to cancel"
- **Processing**: "Processing audio..."
- **Success**: "Text copied to clipboard"

## History & Usage Stats 📚

- Turn on **Save Transcription History** in the Dashboard to store transcripts locally with retention options (1 week, 1 month, 3 months, forever).
- Open **History** from the menu bar or the Dashboard to search, expand details, delete individual entries, or clear all.
- The **Usage Dashboard** aggregates sessions, words, words per minute, estimated time saved, and keystrokes saved; you can rebuild stats from history or reset counters anytime.

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
make build
```

## Privacy & Security 🔒

- **Local Transcription**: Choose Local WhisperKit to keep audio completely on your device
- **Third Party Processing**: OpenAI/Google options transmit audio for transcription
- **Keychain Storage**: API keys are securely stored in macOS Keychain
- **History**: If enabled, transcripts stay local and respect your chosen retention window
- **Permissions**: Smart Paste needs Input Monitoring; Press & Hold needs Accessibility; both are only used for the stated features
- **No Tracking**: We don't collect any usage data or analytics
- **Microphone Permission**: You'll be prompted once on first use
- **Open Source**: Audit the code yourself for peace of mind

## Keyboard Shortcuts ⌨️

| Action | Shortcut |
|--------|----------|
| Toggle window / Express hotkey | ⌘⇧Space (default, configurable) |
| Press & Hold (optional) | Hold chosen modifier (⌘ / ⌥ / ⌃ / Fn) |
| Start/Stop in window | Space |
| Cancel/Close Window | ESC |
| Open Dashboard | ⌘, or Menu bar → Dashboard... |

## Troubleshooting 🔧

**"Unidentified Developer" warning**
- Right‑click the app → Open → confirm the dialog once

**Smart Paste or Press & Hold not working**
- Grant permissions in System Settings → Privacy & Security → Input Monitoring (Smart Paste) and Accessibility (Press & Hold)

**Microphone not detected**
- System Settings → Privacy & Security → Microphone → enable AudioWhisper

**API key problems**
- Re‑enter the key in the Dashboard; check quota; verify any custom base URL/endpoint is correct

**Local models missing or failing**
- Dashboard → Providers → Local Whisper: download/verify the selected model; ensure storage cap isn’t too low

**Parakeet/MLX not ready**
- Apple Silicon only; open Dashboard → Providers → Parakeet → Install Dependencies → Verify Parakeet Model

**Semantic correction issues**
- For Local MLX, click Install Dependencies then Verify MLX Model; for Cloud, ensure the same provider has a valid API key

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
- [MLX](https://github.com/ml-explore/mlx) & [parakeet-mlx](https://github.com/senstella/parakeet-mlx) (Python, bundled) - MIT License

## Acknowledgments 🙏

- Built with SwiftUI and AppKit
- Uses OpenAI Whisper API for cloud transcription
- Supports Google Gemini as an alternative
- Local transcription powered by WhisperKit with CoreML acceleration
- Parakeet-MLX library for providing an easy accelerated Python interface
- MLX LLM stack for optional on-device semantic correction

---

Made with ❤️ for the macOS community. If you find this useful, please consider starring the repository!
