#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -f "$PROJECT_DIR/.env" ]]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

cd "$PROJECT_DIR"

echo "==> Building and signing..."
./scripts/bundle-app.sh --sign "$SIGNING_IDENTITY"

echo "==> Notarizing..."
cd build
zip -r dBMic-notarize.zip dBMic.app
xcrun notarytool submit dBMic-notarize.zip \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_ID_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
rm dBMic-notarize.zip

echo "==> Stapling..."
xcrun stapler staple dBMic.app
cd "$PROJECT_DIR"

echo "==> Creating DMG..."
./scripts/create-dmg.sh

echo "==> Done: build/dBMic.dmg"
