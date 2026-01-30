# NukeMyMac Release Scripts

Scripts for building and releasing NukeMyMac.

## Quick Start

### Create a Release

```bash
# Patch release (1.0.0 -> 1.0.1) - Bug fixes
./scripts/release.sh patch "Fixed memory cleanup issue"

# Minor release (1.0.0 -> 1.1.0) - New features
./scripts/release.sh minor "Added duplicate finder feature"

# Major release (1.0.0 -> 2.0.0) - Breaking changes
./scripts/release.sh major "Completely redesigned UI"
```

### Push to GitHub

After creating a release:

```bash
# Push commits and tags
git push origin main --tags

# Create GitHub release with DMG
./scripts/github-release.sh
```

## Scripts

| Script | Description |
|--------|-------------|
| `release.sh` | Main release script - bumps version, updates changelog, builds, creates DMG |
| `bump-version.sh` | Updates version in Xcode project |
| `build.sh` | Builds and archives the app |
| `create-dmg.sh` | Creates DMG installer |
| `changelog.sh` | Updates CHANGELOG.md |
| `github-release.sh` | Creates GitHub release and uploads DMG |

## GitHub Actions

The `.github/workflows/release.yml` workflow automatically:

1. Builds the app when a tag is pushed
2. Creates a DMG
3. Creates a GitHub release with the DMG attached

To trigger:
```bash
git tag v1.0.1
git push origin v1.0.1
```

## Code Signing & Notarization

For production releases, you need to:

1. Sign with a Developer ID Application certificate
2. Notarize with Apple
3. Staple the notarization ticket

Update `build.sh` with your credentials:

```bash
APPLE_ID="your@email.com"
TEAM_ID="YOURTEAMID"
APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

## Auto-Update

The app includes an UpdateManager that:

- Checks for updates on launch (every 24 hours)
- Shows update available alert with changelog
- Shows "What's New" after updating
- Manual check via menu: NukeMyMac > Check for Updates

Updates are fetched from GitHub Releases API.
