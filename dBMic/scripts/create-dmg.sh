#!/usr/bin/env bash
set -euo pipefail

# Create a DMG from dBMic.app with an Applications symlink.
#
# Usage:
#   ./scripts/create-dmg.sh                    # uses build/dBMic.app
#   ./scripts/create-dmg.sh path/to/dBMic.app  # custom path
#
# Output: build/dBMic.dmg

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

APP_PATH="${1:-$BUILD_DIR/dBMic.app}"
DMG_PATH="$BUILD_DIR/dBMic.dmg"
STAGING="$BUILD_DIR/dmg-staging"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: $APP_PATH not found. Run bundle-app.sh first."
    exit 1
fi

echo "==> Creating DMG..."

rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"

cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "dBMic" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo "==> DMG created at $DMG_PATH"
