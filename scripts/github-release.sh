#!/bin/bash

# GitHub Release Script
# Creates a GitHub release and uploads the DMG

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="NukeMyMac"
RELEASE_DIR="$PROJECT_DIR/release"

# Get version from argument or latest tag
VERSION=${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}

if [ -z "$VERSION" ]; then
    echo "Error: No version specified and no tags found"
    echo "Usage: $0 <version>"
    exit 1
fi

DMG_FILE="$RELEASE_DIR/$PROJECT_NAME-$VERSION.dmg"
TAG="v$VERSION"

# Check if DMG exists
if [ ! -f "$DMG_FILE" ]; then
    echo "Error: DMG not found at $DMG_FILE"
    echo "Run release.sh first"
    exit 1
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed"
    echo "Install with: brew install gh"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub"
    echo "Run: gh auth login"
    exit 1
fi

# Push commits and tags
echo "Pushing to GitHub..."
git push origin main --tags

# Extract changelog for this version
CHANGELOG_ENTRY=$(awk "/## \[$VERSION\]/,/## \[/" "$PROJECT_DIR/CHANGELOG.md" | head -n -1)

if [ -z "$CHANGELOG_ENTRY" ]; then
    CHANGELOG_ENTRY="Release v$VERSION"
fi

# Create GitHub release
echo "Creating GitHub release..."
gh release create "$TAG" \
    --title "NukeMyMac v$VERSION" \
    --notes "$CHANGELOG_ENTRY" \
    "$DMG_FILE" \
    "$DMG_FILE.sha256"

echo ""
echo "✓ GitHub release created: $TAG"
echo ""
echo "Release URL: $(gh release view $TAG --json url -q '.url')"
