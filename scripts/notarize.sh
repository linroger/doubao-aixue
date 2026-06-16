#!/usr/bin/env bash
#
# notarize.sh — Developer-ID sign, notarize, and staple 豆包爱学.app, then rebuild
# a distributable .dmg. Run this once you have a paid Apple Developer account.
#
# Requirements (none of which can be provisioned automatically):
#   1. A "Developer ID Application" certificate in your login keychain
#      (Apple Developer Program, $99/yr). Check:  security find-identity -v -p codesigning
#   2. Notarization credentials stored once via:
#        xcrun notarytool store-credentials DBNOTARY \
#          --apple-id "you@example.com" --team-id X8AD8YC886 \
#          --password "app-specific-password"   # appleid.apple.com → App-Specific Passwords
#
# Usage:
#   DEVID="Developer ID Application: Your Name (TEAMID)" ./scripts/notarize.sh
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/豆包爱学.xcodeproj"
SCHEME="豆包爱学"
OUT_DIR="$PROJECT_DIR/dist"
DERIVED="$PROJECT_DIR/.build/release-dd"
APP_NAME="豆包爱学.app"
VOL_NAME="豆包爱学"
DMG_PATH="$OUT_DIR/豆包爱学.dmg"
KEYCHAIN_PROFILE="${NOTARY_PROFILE:-DBNOTARY}"
DEVID="${DEVID:?Set DEVID to your 'Developer ID Application: …' identity}"

echo "==> Building Release (macOS)…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination 'platform=macOS' \
  -configuration Release build CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath "$DERIVED" >/dev/null
APP="$DERIVED/Build/Products/Release/$APP_NAME"

echo "==> Signing with Developer ID + hardened runtime…"
codesign --force --deep --options runtime --timestamp --sign "$DEVID" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Packaging .dmg…"
mkdir -p "$OUT_DIR"
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH" >/dev/null
rm -rf "$STAGING"

echo "==> Submitting to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait

echo "==> Stapling the ticket…"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -t open --context context:primary-signature -v "$DMG_PATH" || true

echo "==> Notarized DMG ready: $DMG_PATH"
