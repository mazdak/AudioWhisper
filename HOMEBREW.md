# AudioWhisper Homebrew Tap Setup Guide

This guide explains how to maintain and use the AudioWhisper Homebrew tap.

## For Users

### Installation

```bash
# Add the tap
brew tap mazdak/tap

# Install AudioWhisper
brew install audiowhisper

# Launch the app
open -a AudioWhisper
```

### Updating

```bash
# Update Homebrew and upgrade AudioWhisper
brew update
brew upgrade audiowhisper
```

### Uninstallation

```bash
# Uninstall the app
brew uninstall audiowhisper

# Remove the tap (optional)
brew untap mazdak/tap
```

## For Maintainers

### Repository Structure

The tap repository at `mazdak/homebrew-tap` is organized as:

```
homebrew-tap/
├── Formula/          # CLI tools (e.g., lazyredis)
│   └── lazyredis.rb
└── Casks/           # GUI applications
    └── audiowhisper.rb
```

This single tap hosts all of your Homebrew packages (both CLI formulas and GUI casks).

### Updating the Cask Formula

Whenever you release a new version of AudioWhisper:

1. **Create a GitHub Release** with `AudioWhisper.zip` as an asset
   - Tag the release (e.g., `v1.5.0`)
   - Include `AudioWhisper.zip` as a release asset

2. **Run the publish command**:
   ```bash
   cd /path/to/AudioWhisper
   make publish-brew-cask
   ```

   This will:
   - Fetch the latest release from GitHub
   - Download the zip and calculate SHA256
   - Update the cask in `../homebrew-tap/Casks/audiowhisper.rb`
   - Commit and push to the tap repository

### Manual Update (Alternative)

If you prefer to update manually:

```bash
# Download the latest release
RELEASE_URL="https://github.com/mazdak/AudioWhisper/releases/download/v1.5.0/AudioWhisper.zip"
curl -L -o AudioWhisper.zip "$RELEASE_URL"

# Calculate SHA256
shasum -a 256 AudioWhisper.zip

# Edit ../homebrew-tap/Casks/audiowhisper.rb with:
# - New version number
# - New SHA256 hash

# Commit and push
cd ../homebrew-tap
git add Casks/audiowhisper.rb
git commit -m "Update AudioWhisper to v1.5.0"
git push

# Clean up
rm AudioWhisper.zip
```

### Testing the Cask

Before pushing updates, test the cask locally:

```bash
# Test installation from tap repo
brew install --cask --force ../homebrew-tap/Casks/audiowhisper.rb

# Verify it works
open -a AudioWhisper

# Uninstall test
brew uninstall audiowhisper
```

### Makefile Targets

The AudioWhisper repo includes these Makefile targets:

```bash
make update-brew-cask   # Update the cask formula (doesn't push)
make publish-brew-cask  # Update and push to tap repository
make release            # Create a new GitHub release
```

## Requirements

- **GitHub CLI** (`gh`): Required for the update script
  ```bash
  brew install gh
  gh auth login
  ```

- **jq**: Required for JSON parsing in the update script
  ```bash
  brew install jq
  ```

- **homebrew-tap repository**: Must be cloned as a sibling directory
  ```bash
  cd /path/to/Code
  git clone https://github.com/mazdak/homebrew-tap.git
  ```

## Troubleshooting

### "Error: Checksum mismatch"

If users see checksum errors:
1. Re-download the release zip
2. Recalculate the SHA256
3. Update the cask formula in `homebrew-tap`
4. Verify the download URL is correct

### "Error: No available formula with the name"

Users need to tap the repository first:
```bash
brew tap mazdak/tap
```

### "homebrew-tap repository not found"

Clone the tap repository as a sibling directory:
```bash
cd ..
git clone https://github.com/mazdak/homebrew-tap.git
```

## Best Practices

1. **Always test locally** before pushing to the tap repository
2. **Keep versions in sync** between VERSION file, git tags, and cask formula
3. **Verify SHA256** matches the actual release zip
4. **Use semantic versioning** for releases (MAJOR.MINOR.PATCH)
5. **Tag releases** properly in GitHub (e.g., `v1.5.0`)
6. **Include release notes** in GitHub releases

## Resources

- [Homebrew Cask Documentation](https://docs.brew.sh/Cask-Cookbook)
- [Homebrew Tap Documentation](https://docs.brew.sh/Taps)
- [Creating a Homebrew Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
