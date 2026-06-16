#!/usr/bin/env bash
#
# package_dmg.sh — build a Release 豆包爱学.app and wrap it in a drag-to-install .dmg.
#
# This produces a *locally runnable* build. It is ad-hoc signed (signature "-"),
# which is enough to run on the machine that built it (and on others via
# right-click → Open). For frictionless distribution to other Macs, run
# scripts/notarize.sh afterwards with a Developer ID certificate (see RELEASE.md).
#
# Usage:  ./scripts/package_dmg.sh [output_dir]
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/豆包爱学.xcodeproj"
SCHEME="豆包爱学"
OUT_DIR="${1:-$PROJECT_DIR/dist}"
DERIVED="$PROJECT_DIR/.build/release-dd"
APP_NAME="豆包爱学.app"
VOL_NAME="豆包爱学"
DMG_PATH="$OUT_DIR/豆包爱学.dmg"

echo "==> Building Release (macOS)…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination 'platform=macOS' \
  -configuration Release build CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath "$DERIVED" >/dev/null

APP="$DERIVED/Build/Products/Release/$APP_NAME"
[ -d "$APP" ] || { echo "error: built app not found at $APP"; exit 1; }

echo "==> Ad-hoc signing (deep)…"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP" && echo "    signature OK"

echo "==> Building .dmg…"
mkdir -p "$OUT_DIR"
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH" >/dev/null
rm -rf "$STAGING"

echo "==> Done: $DMG_PATH"
ls -lh "$DMG_PATH"
