# Code Signing Setup for Direct Distribution

This guide helps you sign AudioWhisper so friends can run it without Gatekeeper warnings.

## Step 1: Get Apple Developer ID

1. **Join Apple Developer Program** ($99/year)
   - Go to https://developer.apple.com/programs/
   - Sign up with your Apple ID

## Step 2: Create Developer ID Certificate

### Option A: Using Xcode (Easiest)
1. Open Xcode
2. Go to **Xcode → Settings → Accounts**
3. Click **+** and sign in with your Apple ID
4. Select your team and click **Manage Certificates**
5. Click **+** → **Developer ID Application**
6. Certificate is automatically downloaded to your Keychain

### Option B: Using Apple Developer Website
1. Sign in to https://developer.apple.com/account
2. Go to **Certificates, IDs & Profiles**
3. Click **+** to create new certificate
4. Select **Developer ID Application**
5. Upload your Certificate Signing Request (CSR)
6. Download and install the certificate

## Step 3: Find Your Signing Identity

```bash
# List all valid signing identities
security find-identity -v -p codesigning

# Look for something like:
# "Developer ID Application: Your Name (TEAM123456)"
```

Copy the exact text in quotes - that's your signing identity.

## Step 4: Sign Your App

```bash
# Set your signing identity
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM123456)"

# Build and sign the app
./build.sh
```

The build script will automatically sign your app if `CODE_SIGN_IDENTITY` is set.

## Step 5: Verify Signing

```bash
# Check if app is properly signed
codesign --verify --verbose AudioWhisper.app

# View signature details
codesign -dvv AudioWhisper.app

# Test Gatekeeper approval
spctl -a -v AudioWhisper.app
```

If the last command shows "accepted", your app will run without warnings!

## Step 6: Distribute

Your signed `AudioWhisper.app` can now be:
- Zipped and shared directly
- Uploaded to your website
- Distributed via any method

Recipients will be able to run it without "unidentified developer" warnings.

## Troubleshooting

**"No signing certificate found"**
- Make sure you completed Step 2
- Restart Xcode and check Accounts again

**"errSecInternalComponent"**
- Restart your Mac
- Try: `security unlock-keychain`

**Wrong identity name**
- Use the exact text from `security find-identity`
- Include quotes if the name has spaces

**Gatekeeper still blocks**
- Verify signing: `codesign -dvv AudioWhisper.app`
- Check if certificate is valid: `security find-identity -v -p codesigning`

## Optional: Add to Keychain Access

You can verify your certificate in **Keychain Access**:
1. Open **Keychain Access**
2. Look in **login** keychain
3. Find "Developer ID Application: Your Name"
4. Should show as valid and trusted