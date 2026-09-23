# Snaply

Lightshot-style screenshot tool for macOS 14+ (Apple Silicon). Local only: no backend, no sync.

## Build
```
./build.sh            # → build/Snaply.app
./build.sh --install  # → /Applications/Snaply.app
```
Signed with the "Apple Development: a.a.ustinoff@gmail.com" identity (override with `SIGN_ID=<sha1>` or `SIGN_NAME=…`), so the
Screen Recording permission survives rebuilds.

## Use
- ⌘⇧2 — capture area (click a window to select it), ⌘⇧1 — capture the whole screen under the cursor
- In the editor: ↩/⌘C copy, ⌘S save, ⇧⌘S save as, ⌘P pin, ⌘Z/⇧⌘Z undo/redo, Esc cancel
- Tools: V move · P pen · L line · A arrow · R rect · O ellipse · M marker · T text · B pixelate · N counter; 1–9 colors; ⇧ constrains
- Pinned image: drag, scroll/pinch to zoom, double-click/Esc to close, right-click menu

## Dev
`swift run Snaply --selftest /tmp/st` drives the editor on a fake desktop and writes PNGs (no permission needed).
