#!/bin/bash
# https://github.com/ziqq/Glimpshot
# Copyright (C) 2026 Anton Ustinoff
# https://github.com/ziqq/Glimpshot/blob/main/LICENSE

# Builds Glimpshot.app (arm64) into ./build
#   scripts/build.sh            — build
#   scripts/build.sh --install  — build and copy to /Applications
#   SIGN_ID=<sha1 or name> scripts/build.sh — override the signing identity
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Glimpshot.app"
ICON="Resources/AppIcon.icns"

swift build -c release --arch arm64

if [ ! -f "$ICON" ]; then
    echo "→ generating icon"
    TMP=$(mktemp -d)
    swift scripts/make_icon.swift "$TMP/icon.png"
    SET="$TMP/AppIcon.iconset"
    mkdir -p "$SET"
    for s in 16 32 128 256 512; do
        sips -z $s $s "$TMP/icon.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
        sips -z $((s * 2)) $((s * 2)) "$TMP/icon.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$SET" -o "$ICON"
    rm -rf "$TMP"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/arm64-apple-macosx/release/Glimpshot" "$APP/Contents/MacOS/Glimpshot"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

# A stable identity keeps the Screen Recording permission across rebuilds; ad-hoc resets it every time.
# The identity name comes from SIGN_NAME or the untracked scripts/.sign-identity (e.g. your Apple ID email),
# and is resolved to a SHA-1 (an expired twin may share its name). Without either, the build is signed ad-hoc.
SIGN_FILE="scripts/.sign-identity"
if [ -z "${SIGN_NAME:-}" ] && [ -f "$SIGN_FILE" ]; then SIGN_NAME="$(head -n1 "$SIGN_FILE")"; fi
if [ -z "${SIGN_ID:-}" ] && [ -n "${SIGN_NAME:-}" ]; then
    SIGN_ID="$(security find-identity -v -p codesigning | grep -m1 -F "$SIGN_NAME" | awk '{print $2}' || true)"
fi
SIGN_ID="${SIGN_ID:-}"
if [ -n "$SIGN_ID" ]; then
    echo "→ signing with: $SIGN_ID"
    # Developer ID builds get a secure timestamp (required for notarization).
    TS=""
    if security find-identity -v -p codesigning | grep -F "$SIGN_ID" | grep -q "Developer ID"; then TS="--timestamp"; fi
    codesign --force --options runtime $TS --sign "$SIGN_ID" "$APP"
else
    echo "→ no signing identity (set SIGN_NAME or scripts/.sign-identity), signing ad-hoc"
    codesign --force --sign - "$APP"
fi

if [ "${1:-}" = "--install" ]; then
    pkill -x Glimpshot 2>/dev/null || true
    rm -rf /Applications/Glimpshot.app
    cp -R "$APP" /Applications/
    echo "✓ installed to /Applications/Glimpshot.app"
else
    echo "✓ $APP"
fi
