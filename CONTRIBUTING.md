# Contributing to Glimpshot

## Principles

- **Local only.** No backend, accounts, analytics or sync. The only network call is the optional update check against GitHub Releases.
- **Native and dependency-free.** Swift + AppKit/SwiftUI + ScreenCaptureKit. No third-party packages.
- **Fast and small.** The capture overlay must open instantly; avoid work on the hot path.

## Requirements

- macOS 14+ on Apple Silicon
- Xcode 16+ (Swift 5.9+ toolchain)

## Build and run

```bash
swift build                    # debug build
scripts/build.sh               # release build → build/Glimpshot.app
scripts/build.sh --install     # build and install to /Applications
```

`scripts/build.sh` signs with the first valid `Apple Development` identity matching `SIGN_NAME`
(override with `SIGN_ID=<sha1>`), falling back to ad-hoc. A stable identity keeps the
Screen Recording permission across rebuilds; ad-hoc signing resets it every time.

## Project layout

```
Sources/Glimpshot/   app sources (one type per file, roughly)
Resources/           Info.plist, app icon, *.lproj (generated)
scripts/             build, packaging, icon and localization generators
.github/workflows/   CI and releases
```

## Code style

- Match the surrounding code: naming, comment density, file organisation with `// MARK:`.
- UI types are `@MainActor`. The package builds in Swift 5 language mode with zero warnings — keep it that way.
- Keep comments for the *why*, not the *what*.
- No force-unwraps on user data or file system results.

## Localization

All UI strings go through `L("key")`. Never hard-code user-visible text.

1. Add the key with all 11 translations to `scripts/strings.py`
   (`en, ru, uk, de, fr, es, it, pt-BR, ja, ko, zh-Hans`).
2. Run `python3 scripts/strings.py` and commit the regenerated `Resources/*.lproj`.

CI fails if the generated files are out of sync.

## App icon

The icon is drawn in code: edit `scripts/make_icon.swift`, delete `Resources/AppIcon.icns`
and run `scripts/build.sh` to regenerate it.

## Commits and pull requests

- One logical change per commit; subject in the imperative mood, ≤ 72 characters
  (e.g. `Fix selection reset when a stroke starts outside`).
- Explain *why* in the body when it isn't obvious.
- Before opening a PR: `swift build` is clean, strings are regenerated, and you checked the
  change in the running app (`scripts/build.sh --install`).

## Releases

1. Bump `CFBundleShortVersionString` in `Resources/Info.plist` if needed (CI also stamps it from the tag).
2. Tag and push: `git tag v0.2.0 && git push origin v0.2.0`.
3. `.github/workflows/release.yml` builds the DMG with `scripts/make_dmg.sh` and publishes a GitHub Release.

For a signed and notarized build set these repository secrets:
`DEVELOPER_ID_P12`, `DEVELOPER_ID_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`.
Without them the DMG is ad-hoc signed and Gatekeeper blocks it on other Macs.

Local DMG: `scripts/make_dmg.sh` (add `NOTARY_PROFILE=<profile>` to notarize; create the profile once
with `xcrun notarytool store-credentials`).
