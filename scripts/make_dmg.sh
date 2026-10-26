#!/bin/bash
# https://github.com/ziqq/Glimpshot
# Copyright (C) 2026 Anton Ustinoff
# https://github.com/ziqq/Glimpshot/blob/main/LICENSE

# Packages build/Glimpshot.app into build/Glimpshot-<version>.dmg with a drag-to-Applications layout.
#   scripts/make_dmg.sh                      — build + package
#   scripts/make_dmg.sh --skip-build         — package the existing build/Glimpshot.app
#   SIGN_ID=<sha1> SIGN_TEAM_ID=<team> NOTARY_PROFILE=<name> scripts/make_dmg.sh
#       — sign with that Developer ID Application identity, notarize, staple and verify.
#       Create the profile once: xcrun notarytool store-credentials <name> --apple-id … --team-id …
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="Glimpshot"
APP="build/$NAME.app"

# Distribution signing must use an explicitly selected identity, never the first certificate on the Mac.
DEV_ID=""
if [ -n "${SIGN_ID:-}" ]; then
    [[ "$SIGN_ID" =~ ^[A-Fa-f0-9]{40}$ ]] || { echo "✗ SIGN_ID must be a certificate SHA-1"; exit 1; }
    DEV_ID="$(security find-identity -v -p codesigning ${SIGN_KEYCHAIN:+"$SIGN_KEYCHAIN"} | awk -v id="$SIGN_ID" \
        '$2 == id && /"Developer ID Application: / { print $2 }')"
fi
if [ -n "${NOTARY_PROFILE:-}" ]; then
    [ -n "$DEV_ID" ] || { echo "✗ notarization requires an explicit Developer ID Application identity"; exit 1; }
    [[ "${SIGN_TEAM_ID:-}" =~ ^[A-Z0-9]{10}$ ]] || { echo "✗ SIGN_TEAM_ID is required for notarization"; exit 1; }
    security find-identity -v -p codesigning ${SIGN_KEYCHAIN:+"$SIGN_KEYCHAIN"} | awk -v id="$DEV_ID" -v team="$SIGN_TEAM_ID" \
        '$2 == id && index($0, "(" team ")\"") { found=1 } END { exit !found }'
fi
if [ "${1:-}" != "--skip-build" ]; then scripts/build.sh; fi
[ -d "$APP" ] || { echo "✗ $APP not found"; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
VOLNAME="$NAME $VERSION"
DMG="build/$NAME-$VERSION.dmg"
TMP="$(mktemp -d)"
STAGE="$TMP/stage"
RW="$TMP/rw.dmg"
VERIFY_MOUNT="$TMP/verify"
trap 'hdiutil detach "$VERIFY_MOUNT" -quiet 2>/dev/null || true; hdiutil detach "/Volumes/$VOLNAME" -quiet 2>/dev/null || true; rm -rf "$TMP"' EXIT

# App and DMG each need their own accepted submission and saved log.
notarize() {
    local package="$1" receipt="$2" submit_result=0 submission_id status
    local notary_args=(--keychain-profile "$NOTARY_PROFILE")
    if [ -n "${SIGN_KEYCHAIN:-}" ]; then notary_args+=(--keychain "$SIGN_KEYCHAIN"); fi
    xcrun notarytool submit "$package" "${notary_args[@]}" --wait --output-format json > "$receipt-result.json" || submit_result=$?
    submission_id="$(plutil -extract id raw -o - "$receipt-result.json")"
    xcrun notarytool log "$submission_id" "${notary_args[@]}" "$receipt-log.json"
    status="$(plutil -extract status raw -o - "$receipt-result.json")"
    if [ "$submit_result" -ne 0 ] || [ "$status" != Accepted ]; then
        echo "✗ notarization status: $status; see $receipt-log.json"
        exit 1
    fi
}

codesign --verify --strict --verbose=2 "$APP"
if [ -n "$DEV_ID" ]; then
    codesign -d --extract-certificates "$TMP/signer" "$APP"
    APP_SIGNER="$(shasum -a 1 "$TMP/signer0" | awk '{ print toupper($1) }')"
    [ "$APP_SIGNER" = "$(printf '%s' "$DEV_ID" | tr '[:lower:]' '[:upper:]')" ]
    SIGNATURE="$(codesign -dv --verbose=4 "$APP" 2>&1)"
    [[ "$SIGNATURE" == *"(runtime)"* ]] || { echo "✗ Developer ID app signature requires hardened runtime"; exit 1; }
    TIMESTAMP="$(printf '%s\n' "$SIGNATURE" | awk '/^Timestamp=/ { sub(/^Timestamp=/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print tolower($0) }')"
    case "$TIMESTAMP" in
        ''|none|'(none)') echo "✗ Developer ID app signature requires a secure timestamp"; exit 1 ;;
    esac
    if [ -n "${SIGN_TEAM_ID:-}" ]; then
        printf '%s\n' "$SIGNATURE" | grep -Fx "TeamIdentifier=$SIGN_TEAM_ID" >/dev/null
    fi
fi

if [ -n "${NOTARY_PROFILE:-}" ]; then
    echo "→ notarizing app"
    ditto -c -k --keepParent "$APP" "$TMP/$NAME.zip"
    notarize "$TMP/$NAME.zip" "build/app-notarization"
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
    codesign --verify --strict --verbose=2 "$APP"
    syspolicy_check distribution "$APP"
fi

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

hdiutil verify "$DMG"
if [ -n "$DEV_ID" ]; then
    SIGN_ARGS=(--force --timestamp --sign "$DEV_ID")
    if [ -n "${SIGN_KEYCHAIN:-}" ]; then
        SIGN_ARGS+=(--keychain "$SIGN_KEYCHAIN")
    fi
    codesign "${SIGN_ARGS[@]}" "$DMG"
    codesign --verify --strict --verbose=2 "$DMG"
    if [ -n "${NOTARY_PROFILE:-}" ]; then
        echo "→ notarizing DMG"
        notarize "$DMG" "build/dmg-notarization"
        xcrun stapler staple "$DMG"
        xcrun stapler validate "$DMG"
        codesign --verify --strict --verbose=2 "$DMG"
        spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
        mkdir -p "$VERIFY_MOUNT"
        hdiutil attach -nobrowse -readonly -mountpoint "$VERIFY_MOUNT" "$DMG"
        codesign --verify --strict --verbose=2 "$VERIFY_MOUNT/$NAME.app"
        xcrun stapler validate "$VERIFY_MOUNT/$NAME.app"
        syspolicy_check distribution "$VERIFY_MOUNT/$NAME.app"
        hdiutil detach -quiet "$VERIFY_MOUNT"
    else
        echo "  (set NOTARY_PROFILE to notarize)"
    fi
else
    echo "  ⚠ no Developer ID Application certificate: this DMG runs on your Mac,"
    echo "    but Gatekeeper will block the app on other Macs."
fi

echo "✓ $DMG ($(du -h "$DMG" | cut -f1))"
