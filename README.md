# Glimpshot

Lightshot-style screenshot tool for macOS 14+ (Apple Silicon). Local only: no backend, no sync.

## Build
```
./build.sh            # → build/Glimpshot.app
./build.sh --install  # → /Applications/Glimpshot.app
```
Signed with the "Apple Development: a.a.ustinoff@gmail.com" identity (override with `SIGN_ID=<sha1>` or `SIGN_NAME=…`), so the
Screen Recording permission survives rebuilds.

## DMG
```
./make_dmg.sh                          # → build/Glimpshot-<version>.dmg (drag-to-Applications window)
NOTARY_PROFILE=<profile> ./make_dmg.sh # sign with Developer ID + notarize + staple
```
Without a *Developer ID Application* certificate the DMG works on this Mac only — Gatekeeper blocks it elsewhere.
One-time notary setup: `xcrun notarytool store-credentials <profile> --apple-id … --team-id …`.

## Releases (GitHub Actions)
Push a tag → `.github/workflows/release.yml` builds the DMG and publishes a GitHub Release:
```
git tag v0.2.0 && git push origin v0.2.0
```
Add secrets `DEVELOPER_ID_P12`, `DEVELOPER_ID_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`
for a signed + notarized build; without them the DMG is ad-hoc signed. `ci.yml` builds every push/PR.

## Use
- ⌘⇧2 — capture area (click a window to select it), ⌘⇧1 — capture the whole screen under the cursor
- In the editor: ↩/⌘C copy, ⌘S save, ⇧⌘S save as, ⌘P pin, ⌘Z/⇧⌘Z undo/redo, Esc cancel
- Tools: V move · P pen · L line · A arrow · R rect · O ellipse · M marker · T text · B pixelate · N counter; 1–9 colors; ⇧ constrains
- Pinned image: drag, scroll/pinch to zoom, double-click/Esc to close, right-click menu

## Dev
UI strings live in `scripts/strings.py` (11 languages) — edit there, then run `python3 scripts/strings.py`.

`swift run Glimpshot --selftest /tmp/st` drives the editor on a fake desktop and writes PNGs (no permission needed).
