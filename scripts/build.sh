#!/bin/bash

# AudioWhisper Release Build Script
# For development, use: swift build && swift run
# This script is for creating distributable releases

# Change to repo root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1

# Parse command line arguments
NOTARIZE=false
while [[ $# -gt 0 ]]; do
  case $1 in
  --notarize)
    NOTARIZE=true
    shift
    ;;
  *)
    echo "Unknown option: $1"
    echo "Usage: $0 [--notarize]"
    exit 1
    ;;
  esac
done

# Generate version info
GIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date '+%Y-%m-%d')

# Read version from VERSION file or use environment variable
DEFAULT_VERSION=$(cat VERSION | tr -d '[:space:]')
VERSION="${AUDIO_WHISPER_VERSION:-$DEFAULT_VERSION}"

echo "🎙️ Building AudioWhisper version $VERSION..."

# Update Info.plist with current version
if [ -f "Info.plist" ]; then
  echo "Updating Info.plist version to $VERSION..."
  # Update CFBundleShortVersionString
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Info.plist 2>/dev/null ||
    sed -i '' "s|<key>CFBundleShortVersionString</key>[[:space:]]*<string>[^<]*</string>|<key>CFBundleShortVersionString</key><string>$VERSION</string>|" Info.plist

  # Update CFBundleVersion (remove dots for build number)
  BUILD_NUMBER="${VERSION//./}"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" Info.plist 2>/dev/null ||
    sed -i '' "s|<key>CFBundleVersion</key>[[:space:]]*<string>[^<]*</string>|<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>|" Info.plist
fi

# Clean previous builds
rm -rf .build/release
rm -rf AudioWhisper.app
rm -f Sources/AudioProcessorCLI

# Create version file from template
if [ -f "Sources/VersionInfo.swift.template" ]; then
  sed -e "s/VERSION_PLACEHOLDER/$VERSION/g" \
    -e "s/GIT_HASH_PLACEHOLDER/$GIT_HASH/g" \
    -e "s/BUILD_DATE_PLACEHOLDER/$BUILD_DATE/g" \
    Sources/VersionInfo.swift.template >Sources/VersionInfo.swift
  echo "Generated VersionInfo.swift from template"
else
  echo "Warning: VersionInfo.swift.template not found, using fallback"
  cat >Sources/VersionInfo.swift <<EOF
import Foundation

struct VersionInfo {
    static let version = "$VERSION"
    static let gitHash = "$GIT_HASH"
    static let buildDate = "$BUILD_DATE"
    
    static var displayVersion: String {
        if gitHash != "unknown" && !gitHash.isEmpty {
            let shortHash = String(gitHash.prefix(7))
            return "\(version) (\(shortHash))"
        }
        return version
    }
    
    static var fullVersionInfo: String {
        var info = "AudioWhisper \(version)"
        if gitHash != "unknown" && !gitHash.isEmpty {
            let shortHash = String(gitHash.prefix(7))
            info += " • \(shortHash)"
        }
        if buildDate.count > 0 {
            info += " • \(buildDate)"
        }
        return info
    }
}
EOF
fi

# Build for release
echo "📦 Building for release..."
swift build -c release --arch arm64 --arch x86_64

if [ $? -ne 0 ]; then
  echo "❌ Build failed!"
  exit 1
fi

# Create app bundle
echo "Creating app bundle..."
mkdir -p AudioWhisper.app/Contents/MacOS
mkdir -p AudioWhisper.app/Contents/Resources
mkdir -p AudioWhisper.app/Contents/Resources/bin

# Set build number for Info.plist
BUILD_NUMBER="${VERSION//./}"

# Copy executable (universal binary)
cp .build/apple/Products/Release/AudioWhisper AudioWhisper.app/Contents/MacOS/

# Copy Python scripts for Parakeet and MLX support
if [ -f "Sources/parakeet_transcribe_pcm.py" ]; then
  cp Sources/parakeet_transcribe_pcm.py AudioWhisper.app/Contents/Resources/
  echo "Copied Parakeet PCM Python script"
else
  echo "⚠️ parakeet_transcribe_pcm.py not found, Parakeet functionality will not work"
fi

if [ -f "Sources/mlx_semantic_correct.py" ]; then
  cp Sources/mlx_semantic_correct.py AudioWhisper.app/Contents/Resources/
  echo "Copied MLX semantic correction Python script"
else
  echo "⚠️ mlx_semantic_correct.py not found, MLX semantic correction will not work"
fi

# Copy verify scripts
if [ -f "Sources/verify_parakeet.py" ]; then
  cp Sources/verify_parakeet.py AudioWhisper.app/Contents/Resources/
fi
if [ -f "Sources/verify_mlx.py" ]; then
  cp Sources/verify_mlx.py AudioWhisper.app/Contents/Resources/
fi

# Bundle uv (Apple Silicon). Prefer repo copy; else fall back to system uv if available
if [ -f "Sources/Resources/bin/uv" ]; then
  cp Sources/Resources/bin/uv AudioWhisper.app/Contents/Resources/bin/uv
  chmod +x AudioWhisper.app/Contents/Resources/bin/uv
  echo "Bundled uv binary (from repo)"
else
  if command -v uv >/dev/null 2>&1; then
    UV_PATH=$(command -v uv)
    cp "$UV_PATH" AudioWhisper.app/Contents/Resources/bin/uv
    chmod +x AudioWhisper.app/Contents/Resources/bin/uv
    echo "Bundled uv binary (from system: $UV_PATH)"
  else
    echo "ℹ️ No bundled uv found and no system uv available; runtime will try PATH"
  fi
fi

# Bundle pyproject.toml and uv.lock if present
if [ -f "Sources/Resources/pyproject.toml" ]; then
  cp Sources/Resources/pyproject.toml AudioWhisper.app/Contents/Resources/pyproject.toml
  echo "Bundled pyproject.toml"
else
  echo "ℹ️ No pyproject.toml found in Sources/Resources"
fi

# Note: AudioProcessorCLI binary no longer needed - using direct Swift audio processing

# Create proper Info.plist
echo "Creating Info.plist..."
cat >AudioWhisper.app/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>AudioWhisper</string>
    <key>CFBundleIdentifier</key>
    <string>com.audiowhisper.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AudioWhisper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>AudioWhisper needs access to your microphone to record audio for transcription.</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSExceptionDomains</key>
        <dict>
            <key>api.openai.com</key>
            <dict>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
            <key>generativelanguage.googleapis.com</key>
            <dict>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
            <key>huggingface.co</key>
            <dict>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
        </dict>
    </dict>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# Generate app icon from our source image
if [ -f "AudioWhisperIcon.png" ]; then
  "$SCRIPT_DIR/generate-icons.sh"

  # Create proper icns file directly in app bundle
  if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns AudioWhisper.iconset -o AudioWhisper.app/Contents/Resources/AppIcon.icns 2>/dev/null || echo "Note: iconutil failed, app will use default icon"
  fi

  # Clean up temporary files
  rm -rf AudioWhisper.iconset
  rm -f AppIcon.icns # Remove any stray icns file from root
else
  echo "⚠️ AudioWhisperIcon.png not found, app will use default icon"
fi

# Make executable
chmod +x AudioWhisper.app/Contents/MacOS/AudioWhisper

# Create entitlements file for hardened runtime
echo "Creating entitlements for hardened runtime..."
cat >AudioWhisper.entitlements <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
EOF

# Function to sign the app with a given identity
sign_app() {
  local identity="$1"
  local identity_name="$2"

  if [ -n "$identity_name" ]; then
    echo "🔏 Code signing app with: $identity_name ($identity)"
  else
    echo "🔏 Code signing app with: $identity"
  fi

  # Sign uv binary if present (nested executable)
  if [ -f "AudioWhisper.app/Contents/Resources/bin/uv" ]; then
    codesign --force --sign "$identity" --options runtime --entitlements AudioWhisper.entitlements AudioWhisper.app/Contents/Resources/bin/uv
  fi

  codesign --force --deep --sign "$identity" --options runtime --entitlements AudioWhisper.entitlements AudioWhisper.app
  if [ $? -eq 0 ]; then
    echo "🔍 Verifying signature..."
    codesign --verify --verbose AudioWhisper.app
    echo "✅ App signed successfully"
    return 0
  else
    echo "❌ Code signing failed"
    return 1
  fi
}

# Optional: Code sign the app (requires Apple Developer account)
SIGNING_IDENTITY=""
SIGNING_NAME=""

if [ -n "$CODE_SIGN_IDENTITY" ]; then
  SIGNING_IDENTITY="$CODE_SIGN_IDENTITY"
else
  # Try to auto-detect Developer ID (use the first one found)
  DETECTED_HASH=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $2}')
  DETECTED_NAME=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $3}' | tr -d '"')
  if [ -n "$DETECTED_HASH" ]; then
    echo "🔍 Auto-detected signing identity: $DETECTED_NAME"
    SIGNING_IDENTITY="$DETECTED_HASH"
    SIGNING_NAME="$DETECTED_NAME"
  fi
fi

if [ -n "$SIGNING_IDENTITY" ]; then
  sign_app "$SIGNING_IDENTITY" "$SIGNING_NAME"
else
  echo "💡 No Developer ID found. App will be unsigned."
  echo "💡 To sign the app, get a Developer ID certificate from Apple Developer Portal."
fi

# Clean up entitlements file
rm -f AudioWhisper.entitlements

# Notarization (requires code signing first)
if [ "$NOTARIZE" = true ]; then
  echo ""
  echo "🔐 Starting notarization process..."

  # Check for required environment variables
  if [ -z "$AUDIO_WHISPER_APPLE_ID" ] || [ -z "$AUDIO_WHISPER_APPLE_PASSWORD" ] || [ -z "$AUDIO_WHISPER_TEAM_ID" ]; then
    echo "❌ Notarization requires the following environment variables:"
    echo "   AUDIO_WHISPER_APPLE_ID - Your Apple ID email"
    echo "   AUDIO_WHISPER_APPLE_PASSWORD - App-specific password for notarization"
    echo "   AUDIO_WHISPER_TEAM_ID - Your Apple Developer Team ID"
    echo ""
    echo "To create an app-specific password:"
    echo "1. Go to https://appleid.apple.com/account/manage"
    echo "2. Sign in and go to Security > App-Specific Passwords"
    echo "3. Generate a new password for AudioWhisper notarization"
    echo ""
    exit 1
  fi

  # Check if app is signed
  if codesign -dvvv AudioWhisper.app 2>&1 | grep -q "Signature=adhoc"; then
    echo "❌ App must be properly signed before notarization (not adhoc signed)"
    echo "Please ensure CODE_SIGN_IDENTITY is set or a Developer ID is available"
    exit 1
  fi

  # Create a zip file for notarization
  echo "Creating zip for notarization..."
  ditto -c -k --keepParent AudioWhisper.app AudioWhisper.zip

  # Submit for notarization
  echo "📤 Submitting to Apple for notarization..."
  xcrun notarytool submit AudioWhisper.zip \
    --apple-id "$AUDIO_WHISPER_APPLE_ID" \
    --password "$AUDIO_WHISPER_APPLE_PASSWORD" \
    --team-id "$AUDIO_WHISPER_TEAM_ID" \
    --wait 2>&1 | tee notarization.log

  # Check if notarization was successful
  if grep -q "status: Accepted" notarization.log; then
    # Staple the notarization ticket to the app
    echo "📎 Stapling notarization ticket..."
    xcrun stapler staple AudioWhisper.app

    if [ $? -eq 0 ]; then
      echo "✅ Notarization ticket stapled successfully!"
    else
      echo "⚠️ Failed to staple notarization ticket, but app is notarized"
    fi
  else
    echo "❌ Notarization failed. Check notarization.log for details"
    echo ""
    echo "Common issues:"
    echo "- Ensure your Apple ID has accepted all developer agreements"
    echo "- Check that your app-specific password is correct"
    echo "- Verify your Team ID is correct"
    exit 1
  fi

  # Clean up
  rm -f AudioWhisper.zip
  rm -f notarization.log
fi

echo "✅ Build complete!"
echo ""
open -R AudioWhisper.app
