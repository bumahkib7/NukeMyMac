#!/bin/bash

# NukeMyMac Release Script
# Usage: ./scripts/release.sh [major|minor|patch] "Changelog message"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="NukeMyMac"
SCHEME="NukeMyMac"
CONFIGURATION="Release"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check arguments
VERSION_TYPE=${1:-patch}
CHANGELOG_MESSAGE=${2:-"Bug fixes and improvements"}

if [[ ! "$VERSION_TYPE" =~ ^(major|minor|patch)$ ]]; then
    echo "Usage: $0 [major|minor|patch] \"Changelog message\""
    echo "  major - Breaking changes (1.0.0 -> 2.0.0)"
    echo "  minor - New features (1.0.0 -> 1.1.0)"
    echo "  patch - Bug fixes (1.0.0 -> 1.0.1)"
    exit 1
fi

# Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
    print_warning "You have uncommitted changes. Commit them first or they will be included in this release."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get current version
CURRENT_VERSION=$(grep -m1 "MARKETING_VERSION" "$PROJECT_DIR/$PROJECT_NAME.xcodeproj/project.pbxproj" | sed 's/.*= \([0-9.]*\);/\1/')
print_step "Current version: $CURRENT_VERSION"

# Bump version
print_step "Bumping $VERSION_TYPE version..."
source "$SCRIPT_DIR/bump-version.sh" "$VERSION_TYPE"

NEW_VERSION=$(grep -m1 "MARKETING_VERSION" "$PROJECT_DIR/$PROJECT_NAME.xcodeproj/project.pbxproj" | sed 's/.*= \([0-9.]*\);/\1/')
print_success "New version: $NEW_VERSION"

# Update changelog
print_step "Updating changelog..."
source "$SCRIPT_DIR/changelog.sh" "$NEW_VERSION" "$CHANGELOG_MESSAGE"
print_success "Changelog updated"

# Build the app
print_step "Building $PROJECT_NAME v$NEW_VERSION..."
source "$SCRIPT_DIR/build.sh"
print_success "Build complete"

# Create DMG
print_step "Creating DMG..."
source "$SCRIPT_DIR/create-dmg.sh" "$NEW_VERSION"
print_success "DMG created"

# Create release directory
RELEASE_DIR="$PROJECT_DIR/release"
mkdir -p "$RELEASE_DIR"

# Move artifacts to release
mv "$PROJECT_DIR/build/$PROJECT_NAME-$NEW_VERSION.dmg" "$RELEASE_DIR/"
print_success "Release artifacts ready in $RELEASE_DIR"

# Git operations
print_step "Committing changes..."
git add -A
git commit -m "Release v$NEW_VERSION

$CHANGELOG_MESSAGE"

# Create tag
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION

$CHANGELOG_MESSAGE"

print_success "Created tag v$NEW_VERSION"

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Release v$NEW_VERSION Ready!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Artifacts:"
echo "  - $RELEASE_DIR/$PROJECT_NAME-$NEW_VERSION.dmg"
echo ""
echo "Next steps:"
echo "  1. Push to GitHub: git push origin main --tags"
echo "  2. Create GitHub Release with the DMG"
echo "  3. Or run: ./scripts/github-release.sh $NEW_VERSION"
echo ""
