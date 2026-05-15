#!/usr/bin/env bash
set -euo pipefail
# Update Homebrew Cask Formula with Latest Release
# This script fetches the latest release info from GitHub and updates the cask formula
# in the homebrew-tap repository.
#
# Prereqs:
#   - gh CLI authenticated with read access to mazdak/AudioWhisper releases
#   - jq for JSON parsing (brew install jq)
#   - ../homebrew-tap cloned alongside this repo (overridable via TAP_REPO env)
#   - shasum and curl (both built-in on macOS)
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n 's/^# //p' "$0" | head -n 20
  exit 0
fi

# Change to repo root (parent of scripts/)
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

# Verify required tools are present up-front
for cmd in gh jq curl shasum; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Required tool missing: $cmd"; exit 1; }
done

# Unset GITHUB_TOKEN if set, to avoid conflicts with gh CLI keyring auth
unset GITHUB_TOKEN

# Path to the homebrew-tap repository (sibling directory)
TAP_REPO="${TAP_REPO:-../homebrew-tap}"
CASK_FILE="$TAP_REPO/Casks/audiowhisper.rb"

echo "🍺 Updating AudioWhisper Homebrew Cask Formula..."

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) is not installed."
    echo "Install it with: brew install gh"
    exit 1
fi

# Check if tap repo exists
if [ ! -d "$TAP_REPO" ]; then
    echo "❌ Error: homebrew-tap repository not found at $TAP_REPO"
    echo "Clone it first: git clone https://github.com/mazdak/homebrew-tap.git $TAP_REPO"
    exit 1
fi

if [ ! -f "$CASK_FILE" ]; then
    echo "❌ Error: $CASK_FILE not found"
    exit 1
fi

# Get the latest release info from GitHub
echo "📡 Fetching latest release info..."
RELEASE_INFO=$(gh release view --json tagName,url,assets)

# Extract version (remove 'v' prefix if present)
VERSION=$(echo "$RELEASE_INFO" | jq -r '.tagName' | sed 's/^v//')
echo "✅ Latest version: $VERSION"

# Find the AudioWhisper.zip asset
DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r '.assets[] | select(.name == "AudioWhisper.zip") | .url')

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Error: AudioWhisper.zip not found in latest release"
    exit 1
fi

echo "📦 Download URL: $DOWNLOAD_URL"

# Download the zip file to calculate SHA256
TEMP_DIR=$(mktemp -d)
ZIP_FILE="$TEMP_DIR/AudioWhisper.zip"

echo "⬇️  Downloading release to calculate SHA256..."
curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL"

# Calculate SHA256
SHA256=$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')
echo "🔐 SHA256: $SHA256"

# Clean up temp file
rm -rf "$TEMP_DIR"

echo "✏️  Updating $CASK_FILE..."

# Update version
sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$CASK_FILE"

# Update SHA256
sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256\"/" "$CASK_FILE"

echo "✅ Cask formula updated successfully!"
echo ""
echo "📝 Changes made to $CASK_FILE:"
echo "   Version: $VERSION"
echo "   SHA256:  $SHA256"
echo ""
echo "Next steps:"
echo "1. Review the changes: cd $TAP_REPO && git diff Casks/audiowhisper.rb"
echo "2. Commit: cd $TAP_REPO && git add Casks/audiowhisper.rb && git commit -m 'Update AudioWhisper to v$VERSION'"
echo "3. Push: cd $TAP_REPO && git push"
echo ""
echo "Or run: make publish-brew-cask"
echo ""
echo "Users can install/update with:"
echo "   brew install mazdak/tap/audiowhisper"
echo "   brew upgrade audiowhisper"
