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

`scripts/build.sh` signs with the first valid identity matching `SIGN_NAME`, or the first line of the untracked
`scripts/.sign-identity` (e.g. `echo "you@example.com" > scripts/.sign-identity`); `SIGN_ID=<sha1>` overrides both.
Without any of them the build is signed ad-hoc. A stable identity keeps the
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
3. `.github/workflows/release.yml` verifies that the existing `vMAJOR.MINOR.PATCH` tag points to a commit on `main`, builds the DMG with `scripts/make_dmg.sh`, and publishes a GitHub Release.

To retry a release manually, select that existing tag in **Run workflow**. Branch selections are rejected; the workflow never creates tags.

GitHub releases require these secrets in the protected `release` environment:
`DEVELOPER_ID_P12`, `DEVELOPER_ID_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`.
`DEVELOPER_ID_P12` must contain exactly one valid **Developer ID Application** identity and its private key
for the repository owner's `APPLE_TEAM_ID`. Apple Development certificates cannot notarize releases.
The P12 must be base64 encoded; its password and the Apple ID app-specific password remain secrets.
Missing credentials, a different team, rejected notarization or failed verification stop publication.

The workflow imports the identity into a temporary keychain and uses its exact SHA-1 for both app and DMG.
It verifies the app signature, hardened runtime and timestamp, notarizes a ZIP of the app with
`notarytool --wait`, requires `Accepted`, then staples and validates the app ticket. The stapled app
passes `syspolicy_check distribution` before it is copied into the DMG. The DMG is then signed,
notarized, stapled, validated and assessed by Gatekeeper. A final read-only mount verifies the signature,
stapled ticket and distribution assessment of the app inside the finished DMG before publication.
Submission results and logs are saved as `build/app-notarization-*.json` and `build/dmg-notarization-*.json`.
These JSON receipts are retained as a workflow artifact for 30 days, including failed submissions.
The temporary keychain is deleted on success or failure.
See Apple's [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

Local development remains available with `scripts/build.sh` and `scripts/make_dmg.sh`, including ad-hoc signing.
Distribution signing never picks another identity automatically. To notarize locally, explicitly set
`SIGN_ID=<certificate-sha1> SIGN_TEAM_ID=<team-id> NOTARY_PROFILE=<profile>`; create the profile first with
`xcrun notarytool store-credentials`. Set `SIGN_KEYCHAIN=<path>` if the certificate/profile uses a separate keychain.
