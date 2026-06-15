#!/usr/bin/env bash
# init.sh — build & smoke-check harness for 豆包爱学 (Doubao Ai Xue) native app.
# Usage:
#   ./init.sh            # build macOS + iOS (Debug), no code signing
#   ./init.sh mac        # build macOS only
#   ./init.sh ios        # build iOS Simulator only
#   ./init.sh run-mac    # build + launch the macOS app
set -uo pipefail

PROJECT="豆包爱学.xcodeproj"
SCHEME="豆包爱学"
IOS_DEST='platform=iOS Simulator,name=iPhone 17 Pro'
MAC_DEST='platform=macOS'
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR" || exit 1

build() { # $1 = destination, $2 = label
  echo "==> Building $2 ..."
  if xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$1" \
       -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | \
       grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" | sort -u; then
    :
  fi
}

case "${1:-all}" in
  mac)     build "$MAC_DEST" "macOS" ;;
  ios)     build "$IOS_DEST" "iOS Simulator" ;;
  run-mac)
    build "$MAC_DEST" "macOS"
    APP="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$MAC_DEST" -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{d=$2} / FULL_PRODUCT_NAME /{n=$2} END{print d"/"n}')"
    echo "==> Launching $APP"
    open "$APP" ;;
  all|*)
    build "$MAC_DEST" "macOS"
    build "$IOS_DEST" "iOS Simulator" ;;
esac
