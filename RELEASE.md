# 豆包爱学 — Release & Distribution

Native iOS 26 + macOS 26 SwiftUI app. This document covers building a shippable
macOS `.dmg` and the (account-gated) notarization step.

## Quick build

```bash
./scripts/package_dmg.sh          # → dist/豆包爱学.dmg  (ad-hoc signed, locally runnable)
```

`scripts/package_dmg.sh` builds the Release configuration, ad-hoc signs the app,
and wraps it in a drag-to-install disk image with an `/Applications` shortcut.

## Installing the (un-notarized) DMG

The DMG attached to the GitHub release is **ad-hoc signed, not notarized** (see
"Notarization" below for why). macOS Gatekeeper will warn on first launch. To open it:

1. Open `豆包爱学.dmg` and drag **豆包爱学** to **Applications**.
2. In Applications, **right-click → Open** (don't double-click the first time), then
   confirm **Open** in the dialog. macOS remembers the choice for future launches.
   - If macOS still refuses: `xattr -dr com.apple.quarantine "/Applications/豆包爱学.app"`

## Notarization (requires a paid Apple Developer account)

Apple notarization — which removes the Gatekeeper warning entirely — **cannot be
produced in CI or by an assistant**. It requires two things tied to a paid
($99/yr) Apple Developer Program membership:

1. A **Developer ID Application** certificate in your keychain. This machine
   currently has only an *Apple Development* certificate (for local runs), not a
   Developer ID one. Verify with:
   ```bash
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```
2. **Notary credentials** stored once:
   ```bash
   xcrun notarytool store-credentials DBNOTARY \
     --apple-id "you@example.com" --team-id X8AD8YC886 \
     --password "<app-specific-password>"   # create at appleid.apple.com
   ```

With both in place, one command does the rest (Developer-ID sign with hardened
runtime → build DMG → submit → staple → verify):

```bash
DEVID="Developer ID Application: Your Name (X8AD8YC886)" ./scripts/notarize.sh
```

The team ID baked into the project is `X8AD8YC886`; bundle id `linroger022.DoubaoAiXue`.

## iOS

The iOS app builds for the Simulator with no signing
(`./init.sh ios`). Shipping to a device / TestFlight requires the same Apple
Developer account and an iOS distribution profile via Xcode → Archive.
