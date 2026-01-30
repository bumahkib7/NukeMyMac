#!/bin/bash

# Changelog Generator Script
# Prepends new version entry to CHANGELOG.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CHANGELOG_FILE="$PROJECT_DIR/CHANGELOG.md"

VERSION=${1:-"1.0.0"}
MESSAGE=${2:-"Bug fixes and improvements"}
DATE=$(date +%Y-%m-%d)

# Create changelog if it doesn't exist
if [ ! -f "$CHANGELOG_FILE" ]; then
    cat > "$CHANGELOG_FILE" << 'EOF'
# Changelog

All notable changes to NukeMyMac will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF
fi

# Create temp file with new entry
TEMP_FILE=$(mktemp)

# Write new entry
cat > "$TEMP_FILE" << EOF
# Changelog

All notable changes to NukeMyMac will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [$VERSION] - $DATE

### Changed
- $MESSAGE

EOF

# Append rest of existing changelog (skip header)
if [ -f "$CHANGELOG_FILE" ]; then
    tail -n +8 "$CHANGELOG_FILE" >> "$TEMP_FILE" 2>/dev/null || true
fi

# Replace changelog
mv "$TEMP_FILE" "$CHANGELOG_FILE"

echo "Changelog updated with v$VERSION"
