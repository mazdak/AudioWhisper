#!/bin/bash

# AudioWhisper Build Script

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

echo "🎙️ Building AudioWhisper..."

# Clean previous builds
rm -rf .build/release
rm -rf AudioWhisper.app

# Build for release
echo "📦 Building for release..."
swift build -c release --arch arm64 --arch x86_64

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

# Create app bundle
echo "📱 Creating app bundle..."
mkdir -p AudioWhisper.app/Contents/MacOS
mkdir -p AudioWhisper.app/Contents/Resources

# Copy executable (universal binary)
cp .build/apple/Products/Release/AudioWhisper AudioWhisper.app/Contents/MacOS/

# Create proper Info.plist
echo "📝 Creating Info.plist..."
cat > AudioWhisper.app/Contents/Info.plist << 'EOF'
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
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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
echo "🎨 Generating app icon..."
if [ -f "AudioWhisperIcon.png" ]; then
    ./generate-icons.sh
    
    # Create proper icns file directly in app bundle
    if command -v iconutil >/dev/null 2>&1; then
        iconutil -c icns AudioWhisper.iconset -o AudioWhisper.app/Contents/Resources/AppIcon.icns 2>/dev/null || echo "Note: iconutil failed, app will use default icon"
    fi
    
    # Clean up temporary files
    rm -rf AudioWhisper.iconset
    rm -f AppIcon.icns  # Remove any stray icns file from root
else
    echo "⚠️  AudioWhisperIcon.png not found, app will use default icon"
fi

# Make executable
chmod +x AudioWhisper.app/Contents/MacOS/AudioWhisper

# Create entitlements file for hardened runtime
echo "🔐 Creating entitlements for hardened runtime..."
cat > AudioWhisper.entitlements << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.audiowhisper.app</string>
    </array>
</dict>
</plist>
EOF

# Optional: Code sign the app (requires Apple Developer account)
if [ -n "$CODE_SIGN_IDENTITY" ]; then
    echo "🔏 Code signing app with: $CODE_SIGN_IDENTITY"
    codesign --force --deep --sign "$CODE_SIGN_IDENTITY" --options runtime --entitlements AudioWhisper.entitlements AudioWhisper.app
    if [ $? -eq 0 ]; then
        echo "✅ App signed successfully"
        echo "🔍 Verifying signature..."
        codesign --verify --verbose AudioWhisper.app
        spctl -a -v AudioWhisper.app 2>/dev/null && echo "✅ Gatekeeper approved" || echo "⚠️  Gatekeeper check failed"
    else
        echo "❌ Code signing failed"
    fi
    
    # Clean up entitlements file
    rm -f AudioWhisper.entitlements
else
    # Try to auto-detect Developer ID (use the first one found)
    DETECTED_HASH=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $2}')
    DETECTED_NAME=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $3}' | tr -d '"')
    if [ -n "$DETECTED_HASH" ]; then
        echo "🔍 Auto-detected signing identity: $DETECTED_NAME"
        echo "🔏 Code signing app with: $DETECTED_HASH"
        
        # Create entitlements file
        cat > AudioWhisper.entitlements << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.hardened-runtime</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>\$(AppIdentifierPrefix)com.audiowhisper.app</string>
    </array>
</dict>
</plist>
EOF
        
        codesign --force --deep --sign "$DETECTED_HASH" --options runtime --entitlements AudioWhisper.entitlements AudioWhisper.app
        if [ $? -eq 0 ]; then
            echo "✅ App signed successfully"
            echo "🔍 Verifying signature..."
            codesign --verify --verbose AudioWhisper.app
            spctl -a -v AudioWhisper.app 2>/dev/null && echo "✅ Gatekeeper approved" || echo "⚠️  Gatekeeper check failed"
        else
            echo "❌ Code signing failed"
        fi
    else
        echo "💡 No Developer ID found. App will be unsigned."
        echo "💡 To sign the app, get a Developer ID certificate from Apple Developer Portal."
    fi
    
    # Clean up entitlements file
    rm -f AudioWhisper.entitlements
fi

# Notarization (requires code signing first)
if [ "$NOTARIZE" = true ]; then
    echo ""
    echo "🔔 Starting notarization process..."
    
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
    if ! codesign -dvvv AudioWhisper.app 2>&1 | grep -q "Signature=adhoc"; then
        echo "✅ App is properly signed, proceeding with notarization..."
    else
        echo "❌ App must be properly signed before notarization (not adhoc signed)"
        echo "Please ensure CODE_SIGN_IDENTITY is set or a Developer ID is available"
        exit 1
    fi
    
    # Create a zip file for notarization
    echo "📦 Creating zip for notarization..."
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
        echo "✅ Notarization successful!"
        
        # Staple the notarization ticket to the app
        echo "📎 Stapling notarization ticket..."
        xcrun stapler staple AudioWhisper.app
        
        if [ $? -eq 0 ]; then
            echo "✅ Notarization ticket stapled successfully!"
        else
            echo "⚠️  Failed to staple notarization ticket, but app is notarized"
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
echo "📦 App bundle created: AudioWhisper.app"
if [ "$NOTARIZE" = true ]; then
    echo "✅ App has been notarized and can be distributed!"
fi
echo ""
echo "To install:"
echo "  cp -r AudioWhisper.app /Applications/"
echo ""
echo "To run immediately:"
echo "  open AudioWhisper.app"
echo ""
echo "The app will guide you through API key setup on first launch."
echo ""
echo "For notarization (required for distribution):"
echo "  export AUDIO_WHISPER_APPLE_ID='your-apple-id@example.com'"
echo "  export AUDIO_WHISPER_APPLE_PASSWORD='your-app-specific-password'"
echo "  export AUDIO_WHISPER_TEAM_ID='your-team-id'"
echo "  ./build.sh --notarize"

# Open Finder to show the built app
echo ""
echo "📂 Opening Finder..."
open -R AudioWhisper.app