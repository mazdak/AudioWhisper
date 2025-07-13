# AudioWhisper Linux 🎙️

A lightweight audio transcription app for Linux with Wayland/Hyprland support. This is a Linux port of the original macOS AudioWhisper application, providing quick audio transcription using OpenAI Whisper, Google Gemini, local Whisper, or Parakeet.

<p align="center">
  <img src="../AudioWhisperIcon.png" width="128" height="128" alt="AudioWhisper Icon">
</p>

## Features ✨

- **🎯 Quick Access**: Global hotkey (Super+Shift+Space) to start recording from anywhere
- **🎙️ System Tray App**: Lives quietly in your system tray
- **🚀 Multiple Transcription Options**: 
  - OpenAI Whisper API (cloud)
  - Google Gemini API (cloud)
  - Local Whisper (privacy-focused)
  - Parakeet MLX (fast, English-only)
- **📋 Auto-Copy**: Transcribed text is automatically copied to clipboard
- **🔈 Visual Feedback**: Real-time audio level indicator while recording
- **⌨️ Keyboard Shortcuts**: Space to start/stop recording, ESC to cancel
- **💬 User Guidance**: Clear on-screen instructions for all actions
- **🌓 Dark Mode**: Beautiful native GTK4 design that adapts to your system
- **🔐 Secure**: API keys stored in system keyring
- **🔒 Privacy-First**: Local transcription options keep audio on your device
- **🏃 Wayland Native**: Built specifically for modern Linux desktops
- **🪟 Hyprland Integration**: Special window rules and keybindings for Hyprland users

## Requirements 📋

### System Requirements
- Linux with GTK4 support
- Python 3.8 or later
- PulseAudio or PipeWire for audio
- Wayland compositor (optimized for Hyprland)

### Dependencies
- GTK4 and libadwaita
- PyGObject
- PortAudio (for PyAudio)
- wl-clipboard (for Wayland clipboard support)
- FFmpeg (for Parakeet support)

## Installation 🛠️

### Arch Linux (AUR)
```bash
# Coming soon
yay -S audiowhisper-linux
```

### Manual Installation

1. **Install system dependencies**:

   **Arch Linux**:
   ```bash
   sudo pacman -S python python-pip gtk4 libadwaita python-gobject portaudio wl-clipboard ffmpeg
   ```

   **Ubuntu/Debian**:
   ```bash
   sudo apt install python3 python3-pip libgtk-4-1 libadwaita-1-0 python3-gi portaudio19-dev wl-clipboard ffmpeg
   ```

   **Fedora**:
   ```bash
   sudo dnf install python3 python3-pip gtk4 libadwaita python3-gobject portaudio wl-clipboard ffmpeg
   ```

2. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/audiowhisper-linux.git
   cd audiowhisper-linux/AudioWhisper-Linux
   ```

3. **Create virtual environment** (recommended):
   ```bash
   python -m venv venv
   source venv/bin/activate
   ```

4. **Install Python dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

5. **Make the main script executable**:
   ```bash
   chmod +x src/main.py
   ```

## Setup 🔧

### First Run
```bash
# Run from the source directory
python src/main.py

# Or if you made it executable
./src/main.py
```

The app will create a config file at `~/.config/audiowhisper/config.toml` on first run.

### Configure Transcription Provider

**Local Whisper (Recommended for Privacy)**
- No API key required
- Models download automatically on first use
- Choose from tiny (39MB) to large (1.5GB) models

**OpenAI Whisper**
1. Visit https://platform.openai.com/api-keys
2. Create a new API key
3. Add to AudioWhisper settings

**Google Gemini**
1. Visit https://makersuite.google.com/app/apikey
2. Create a new API key
3. Add to AudioWhisper settings

**Parakeet (Advanced)**
```bash
# Install Parakeet
pip install parakeet-mlx

# Verify installation
python -c "import parakeet_mlx; print('OK')"
```

### Hyprland Setup

AudioWhisper automatically configures Hyprland when it detects it's running. The following will be added to your `~/.config/hypr/hyprland.conf`:

```
# AudioWhisper keybinds
bind = SUPER SHIFT, space, exec, ~/.config/audiowhisper/hotkey_handler.sh

# AudioWhisper window rules
windowrule = float, class:^(audiowhisper)$
windowrule = center, class:^(audiowhisper)$
windowrule = pin, class:^(audiowhisper)$
windowrule = noborder, class:^(audiowhisper)$
```

### Desktop Entry (Optional)

Create `~/.local/share/applications/audiowhisper.desktop`:

```desktop
[Desktop Entry]
Name=AudioWhisper
Comment=Quick audio transcription
Exec=/path/to/audiowhisper-linux/src/main.py
Icon=audio-input-microphone-symbolic
Type=Application
Categories=AudioVideo;Audio;Utility;
StartupNotify=false
```

## Usage 🎯

1. **Quick Recording**: Press Super+Shift+Space anywhere to open the recording window
2. **Start Recording**: Click the blue microphone button or press Space
3. **Stop Recording**: Click the button again or press Space
4. **Cancel**: Press ESC at any time to dismiss the window
5. **Auto-Copy**: After transcription, text is automatically copied to clipboard

The app lives in your system tray - click the microphone icon for quick access to recording or settings.

## Configuration 📝

Edit `~/.config/audiowhisper/config.toml`:

```toml
[general]
start_at_login = false
show_tray_icon = true
play_sounds = true
immediate_recording = false

[hotkeys]
toggle_recording = "SUPER SHIFT, space"

[transcription]
provider = "openai"  # or "gemini", "local", "parakeet"
openai_model = "whisper-1"
local_model = "base"  # tiny, base, small, large-v3-turbo
language = "auto"

[audio]
sample_rate = 16000
channels = 1
chunk_size = 1024

[ui]
theme = "auto"  # auto, light, dark
window_opacity = 0.95
```

## Building from Source 👨‍💻

### Create Executable Bundle
```bash
# Install PyInstaller
pip install pyinstaller

# Create bundle
pyinstaller --onefile --windowed \
  --add-data "src/parakeet_transcribe.py:." \
  --name audiowhisper \
  src/main.py
```

## Troubleshooting 🔧

**"No module named 'gi'" Error**
- Install python-gobject: `sudo pacman -S python-gobject`

**Audio Recording Issues**
- Check microphone permissions
- Verify PulseAudio/PipeWire is running: `pactl info`
- Try different audio devices in settings

**Hyprland Hotkey Not Working**
- Check if the keybind was added: `cat ~/.config/hypr/hyprland.conf | grep AudioWhisper`
- Reload Hyprland config: `hyprctl reload`
- Check the hotkey handler script exists: `ls ~/.config/audiowhisper/hotkey_handler.sh`

**Clipboard Not Working**
- Install wl-clipboard: `sudo pacman -S wl-clipboard`
- For X11 fallback, install xclip: `sudo pacman -S xclip`

## Contributing 🤝

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Differences from macOS Version

This Linux port maintains feature parity with the original macOS version while adapting to Linux conventions:

- Uses GTK4/libadwaita instead of SwiftUI
- Hyprland keybindings instead of macOS global hotkeys
- System keyring instead of macOS Keychain
- wl-clipboard for Wayland clipboard support
- D-Bus/named pipes for IPC instead of macOS notifications

## License 📄

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments 🙏

- Original AudioWhisper macOS app developers
- Built with GTK4 and Python
- Uses OpenAI Whisper API for cloud transcription
- Local transcription powered by openai-whisper
- Hyprland window manager for excellent Wayland support

---

Made with ❤️ for the Linux community. If you find this useful, please consider starring the repository!