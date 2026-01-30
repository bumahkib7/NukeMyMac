#!/bin/bash

# Create DMG Script for NukeMyMac
# Creates a beautiful DMG installer with background and app shortcut

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="NukeMyMac"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/$PROJECT_NAME.app"
VERSION=${1:-"1.0.0"}
DMG_NAME="$PROJECT_NAME-$VERSION"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
DMG_TEMP="$BUILD_DIR/dmg_temp"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    echo "Run build.sh first"
    exit 1
fi

# Clean up any existing temp directory
rm -rf "$DMG_TEMP"
rm -f "$DMG_PATH"

# Create temp directory structure
mkdir -p "$DMG_TEMP"

# Copy app to temp directory
cp -R "$APP_PATH" "$DMG_TEMP/"

# Create Applications symlink
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$PROJECT_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH"

# Clean up
rm -rf "$DMG_TEMP"

echo "DMG created: $DMG_PATH"

# Get DMG size
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo "Size: $DMG_SIZE"

# Calculate SHA256
SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)
echo "SHA256: $SHA256"

# Save checksum to file
echo "$SHA256  $DMG_NAME.dmg" > "$BUILD_DIR/$DMG_NAME.dmg.sha256"
