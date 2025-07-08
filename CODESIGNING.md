# Code Signing Guide for AudioWhisper

Code signing is required for:
- Distributing your app outside the Mac App Store
- Preventing "unidentified developer" warnings
- Enabling app notarization for macOS Gatekeeper

## Free Option: Ad-hoc Signing (Local Use Only)

For personal use, you can ad-hoc sign without a developer account:

```bash
# Ad-hoc sign (no developer account needed)
codesign --force --deep --sign - AudioWhisper.app
```

**Limitations:**
- Only works on your Mac
- Other users will still see security warnings

## Paid Option: Apple Developer Program ($99/year)

### 1. Join Apple Developer Program
- Go to https://developer.apple.com/programs/
- Sign up for $99/year membership

### 2. Create Developer ID Certificate

In Xcode:
1. Open Xcode → Settings → Accounts
2. Click "Manage Certificates"
3. Click "+" → "Developer ID Application"

Or via Apple Developer website:
1. Sign in to https://developer.apple.com/account
2. Go to Certificates, IDs & Profiles
3. Create a "Developer ID Application" certificate

### 3. Find Your Code Signing Identity

```bash
# List all valid signing identities
security find-identity -v -p codesigning

# You'll see something like:
# "Developer ID Application: Your Name (TEAMID)"
```

### 4. Sign Your App

```bash
# Set your identity
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"

# Build and sign
./build.sh
```

### 5. Verify Code Signature

```bash
# Check if app is properly signed
codesign --verify --verbose AudioWhisper.app

# Check signature details
codesign -dvv AudioWhisper.app
```

## Notarization (Recommended for Distribution)

After signing, notarize your app for Gatekeeper:

```bash
# Create a zip for notarization
ditto -c -k --keepParent AudioWhisper.app AudioWhisper.zip

# Submit for notarization
xcrun notarytool submit AudioWhisper.zip \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password" \
  --wait

# Staple the notarization ticket
xcrun stapler staple AudioWhisper.app
```

## Creating an App-Specific Password

1. Go to https://appleid.apple.com
2. Sign in and go to "App-Specific Passwords"
3. Generate a password for "AudioWhisper Notarization"
4. Save it securely (you'll need it for notarization)

## Entitlements

AudioWhisper needs these entitlements (already configured):
- Microphone access
- Keychain access

## Distribution Options

### Direct Download
- Sign and notarize the app
- Zip it: `ditto -c -k AudioWhisper.app AudioWhisper.zip`
- Users can download and run without warnings

### Homebrew Cask (Community)
- Submit to homebrew-cask for easy installation
- Requires signed and notarized app

### Mac App Store
- Requires additional entitlements and sandboxing
- Different certificate type (Mac App Distribution)

## Troubleshooting

**"errSecInternalComponent" error:**
- Restart your Mac
- Unlock your keychain: `security unlock-keychain`

**Certificate not found:**
- Make sure you're using exact name from `security find-identity`
- Include quotes if name has spaces

**Notarization fails:**
- Check for hardened runtime issues
- Ensure all embedded frameworks are signed

## Free Alternative: Distribute Unsigned

If you don't have a developer account, users can still run the app:

1. User downloads AudioWhisper.app
2. User right-clicks → Open (instead of double-clicking)
3. Click "Open" in the security dialog
4. macOS remembers the choice

This works but provides a poor user experience compared to proper signing.