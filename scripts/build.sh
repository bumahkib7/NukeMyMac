#!/bin/bash

# Build Script for NukeMyMac
# Builds, signs, and notarizes the app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="NukeMyMac"
SCHEME="NukeMyMac"
CONFIGURATION="Release"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
APP_PATH="$BUILD_DIR/$PROJECT_NAME.app"

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Building $PROJECT_NAME..."

# Build the app
xcodebuild -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | xcpretty || xcodebuild -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Export the app from archive
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$BUILD_DIR" \
    -exportOptionsPlist "$SCRIPT_DIR/ExportOptions.plist" \
    2>&1 | xcpretty || xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$BUILD_DIR" \
    -exportOptionsPlist "$SCRIPT_DIR/ExportOptions.plist"

echo "Build complete: $APP_PATH"

# Note: For production releases, you should:
# 1. Sign with Developer ID Application certificate
# 2. Notarize with Apple
# 3. Staple the notarization ticket
#
# Uncomment and configure the following for notarization:
#
# APPLE_ID="your@email.com"
# TEAM_ID="YOURTEAMID"
# APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
#
# # Create zip for notarization
# ditto -c -k --keepParent "$APP_PATH" "$BUILD_DIR/$PROJECT_NAME.zip"
#
# # Submit for notarization
# xcrun notarytool submit "$BUILD_DIR/$PROJECT_NAME.zip" \
#     --apple-id "$APPLE_ID" \
#     --team-id "$TEAM_ID" \
#     --password "$APP_SPECIFIC_PASSWORD" \
#     --wait
#
# # Staple the ticket
# xcrun stapler staple "$APP_PATH"
