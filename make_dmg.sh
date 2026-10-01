#!/bin/bash
# Packages build/Glimpshot.app into build/Glimpshot-<version>.dmg with a drag-to-Applications layout.
#   ./make_dmg.sh                      — build + package
#   ./make_dmg.sh --skip-build         — package the existing build/Glimpshot.app
#   NOTARY_PROFILE=<name> ./make_dmg.sh — also notarize + staple (needs a Developer ID Application cert;
#       create the profile once: xcrun notarytool store-credentials <name> --apple-id … --team-id …)
set -euo pipefail
cd "$(dirname "$0")"

NAME="Glimpshot"
APP="build/$NAME.app"

# Prefer Developer ID for distribution; fall back to whatever build.sh picks.
DEV_ID="$(security find-identity -v -p codesigning | grep -m1 'Developer ID Application' | awk '{print $2}' || true)"
if [ "${1:-}" != "--skip-build" ]; then
    if [ -n "$DEV_ID" ]; then SIGN_ID="$DEV_ID" ./build.sh; else ./build.sh; fi
fi
[ -d "$APP" ] || { echo "✗ $APP not found"; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
VOLNAME="$NAME $VERSION"
DMG="build/$NAME-$VERSION.dmg"
TMP="$(mktemp -d)"
STAGE="$TMP/stage"
RW="$TMP/rw.dmg"
trap 'hdiutil detach "/Volumes/$VOLNAME" -quiet 2>/dev/null || true; rm -rf "$TMP"' EXIT

echo "→ staging"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
swift scripts/make_dmg_background.swift "$STAGE/.background/bg.png"
cp Resources/AppIcon.icns "$STAGE/.VolumeIcon.icns"

echo "→ creating image"
hdiutil detach "/Volumes/$VOLNAME" -quiet 2>/dev/null || true
hdiutil create -quiet -srcfolder "$STAGE" -volname "$VOLNAME" -fs HFS+ -format UDRW -ov "$RW"
hdiutil attach -quiet -readwrite -noverify -noautoopen "$RW"
MOUNT="/Volumes/$VOLNAME"

# Custom volume icon.
if command -v SetFile >/dev/null; then SetFile -a C "$MOUNT"; fi

# Window layout via Finder. Needs Automation permission for Finder; if it fails the DMG still works.
echo "→ arranging window"
if ! osascript <<EOF
tell application "Finder"
    tell disk "$VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 548}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 128
        set text size of opts to 13
        set background picture of opts to file ".background:bg.png"
        set position of item "$NAME.app" of container window to {165, 190}
        set position of item "Applications" of container window to {495, 190}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
then
    echo "  (Finder layout skipped — allow Automation → Finder for your terminal to get the styled window)"
fi

sync
hdiutil detach -quiet "$MOUNT"

echo "→ compressing"
rm -f "$DMG"
hdiutil convert -quiet "$RW" -format ULFO -o "$DMG"

if [ -n "$DEV_ID" ]; then
    codesign --force --timestamp --sign "$DEV_ID" "$DMG"
    if [ -n "${NOTARY_PROFILE:-}" ]; then
        echo "→ notarizing"
        xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$DMG"
    else
        echo "  (set NOTARY_PROFILE to notarize)"
    fi
else
    echo "  ⚠ no Developer ID Application certificate: this DMG runs on your Mac,"
    echo "    but Gatekeeper will block the app on other Macs."
fi

echo "✓ $DMG ($(du -h "$DMG" | cut -f1))"
