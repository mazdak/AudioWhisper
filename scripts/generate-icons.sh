#!/bin/bash

# Change to repo root (parent of scripts/)
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

# Generate app icons from source image
SOURCE_IMAGE="AudioWhisperIcon.png"
ICONSET_DIR="AudioWhisper.iconset"

if [ ! -f "$SOURCE_IMAGE" ]; then
  echo "Error: $SOURCE_IMAGE not found!"
  exit 1
fi

# Create iconset directory
mkdir -p "$ICONSET_DIR"

# Generate all required sizes
echo "Generating app icons..."

# 16x16
sips -z 16 16 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_16x16.png" --setProperty format png >/dev/null 2>&1
sips -z 32 32 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_16x16@2x.png" --setProperty format png >/dev/null 2>&1

# 32x32
sips -z 32 32 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_32x32.png" --setProperty format png >/dev/null 2>&1
sips -z 64 64 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_32x32@2x.png" --setProperty format png >/dev/null 2>&1

# 128x128
sips -z 128 128 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_128x128.png" --setProperty format png >/dev/null 2>&1
sips -z 256 256 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_128x128@2x.png" --setProperty format png >/dev/null 2>&1

# 256x256
sips -z 256 256 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_256x256.png" --setProperty format png >/dev/null 2>&1
sips -z 512 512 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_256x256@2x.png" --setProperty format png >/dev/null 2>&1

# 512x512
sips -z 512 512 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_512x512.png" --setProperty format png >/dev/null 2>&1
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_512x512@2x.png" --setProperty format png >/dev/null 2>&1

# Don't create icns file here - build.sh will handle it

# Copy to Assets if they exist
if [ -d "Assets.xcassets/AppIcon.appiconset" ]; then
  echo "Copying icons to Assets..."
  cp "$ICONSET_DIR"/*.png Assets.xcassets/AppIcon.appiconset/
fi

# Don't clean up iconset - build.sh needs it
# rm -rf "$ICONSET_DIR"

echo "Done!"

