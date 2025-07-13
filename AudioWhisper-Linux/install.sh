#!/bin/bash

# AudioWhisper Linux Installation Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    print_error "This installer is only for Linux systems."
    exit 1
fi

print_info "Welcome to AudioWhisper Linux installer!"
echo

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    print_error "Cannot detect Linux distribution"
    exit 1
fi

print_info "Detected OS: $OS $VER"

# Install system dependencies based on distribution
install_dependencies() {
    print_info "Installing system dependencies..."
    
    case $OS in
        arch|manjaro|endeavouros)
            print_info "Installing dependencies for Arch Linux..."
            sudo pacman -S --needed python python-pip gtk4 libadwaita python-gobject portaudio wl-clipboard ffmpeg python-pyaudio
            ;;
        ubuntu|debian|pop)
            print_info "Installing dependencies for Ubuntu/Debian..."
            sudo apt update
            sudo apt install -y python3 python3-pip python3-venv libgtk-4-1 libadwaita-1-0 python3-gi python3-gi-cairo gir1.2-gtk-4.0 portaudio19-dev wl-clipboard ffmpeg libgirepository1.0-dev
            ;;
        fedora|rhel|centos)
            print_info "Installing dependencies for Fedora/RHEL..."
            sudo dnf install -y python3 python3-pip gtk4 libadwaita python3-gobject portaudio-devel wl-clipboard ffmpeg
            ;;
        opensuse|suse)
            print_info "Installing dependencies for openSUSE..."
            sudo zypper install -y python3 python3-pip gtk4 libadwaita python3-gobject3 portaudio-devel wl-clipboard ffmpeg
            ;;
        *)
            print_warning "Unknown distribution. Please install dependencies manually:"
            echo "  - Python 3.8+"
            echo "  - GTK4 and libadwaita"
            echo "  - Python GObject bindings"
            echo "  - PortAudio"
            echo "  - wl-clipboard"
            echo "  - FFmpeg"
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
}

# Create virtual environment
setup_venv() {
    print_info "Setting up Python virtual environment..."
    
    if [ -d "venv" ]; then
        print_warning "Virtual environment already exists. Skipping..."
    else
        python3 -m venv venv
        print_success "Virtual environment created"
    fi
    
    # Activate venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
}

# Install Python dependencies
install_python_deps() {
    print_info "Installing Python dependencies..."
    
    # Install requirements
    pip install -r requirements.txt
    
    print_success "Python dependencies installed"
}

# Create desktop entry
create_desktop_entry() {
    print_info "Creating desktop entry..."
    
    INSTALL_DIR=$(pwd)
    DESKTOP_FILE="$HOME/.local/share/applications/audiowhisper.desktop"
    
    mkdir -p "$HOME/.local/share/applications"
    
    cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=AudioWhisper
Comment=Quick audio transcription for Linux
Exec=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/src/main.py
Icon=audio-input-microphone-symbolic
Type=Application
Categories=AudioVideo;Audio;Utility;
StartupNotify=false
Terminal=false
EOF
    
    chmod +x "$DESKTOP_FILE"
    print_success "Desktop entry created"
}

# Create launch script
create_launch_script() {
    print_info "Creating launch script..."
    
    cat > "audiowhisper" << 'EOF'
#!/bin/bash
# AudioWhisper launcher script

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/venv/bin/activate"
python "$SCRIPT_DIR/src/main.py" "$@"
EOF
    
    chmod +x audiowhisper
    print_success "Launch script created"
}

# Check Hyprland
check_hyprland() {
    if command -v hyprctl &> /dev/null; then
        print_info "Hyprland detected! AudioWhisper will configure keybindings automatically on first run."
    fi
}

# Main installation process
main() {
    echo "This will install AudioWhisper Linux and its dependencies."
    read -p "Continue? [Y/n] " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    # Install dependencies
    install_dependencies
    
    # Setup Python environment
    setup_venv
    
    # Install Python packages
    install_python_deps
    
    # Create desktop entry
    create_desktop_entry
    
    # Create launch script
    create_launch_script
    
    # Check for Hyprland
    check_hyprland
    
    print_success "Installation complete!"
    echo
    print_info "You can now run AudioWhisper with:"
    echo "  ./audiowhisper"
    echo
    print_info "Or launch it from your application menu"
    echo
    print_info "First run will create a config file at: ~/.config/audiowhisper/config.toml"
    print_info "Configure your preferred transcription provider and API keys in the settings."
}

# Run main installation
main