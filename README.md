# NV Viewer: an NFC-key app lock you sideload with SideStore

An iOS app that blocks the apps you choose with Screen Time (Family Controls)
and unlocks them when you scan a registered NFC tag. It can also lock on a
daily schedule, and it shows a custom block screen.

It's built to be **sideloaded with SideStore, not installed from the App
Store**, and to keep working when it's signed with a **free Apple ID**:

- **No paid-only capabilities.** No StoreKit/in-app purchases, no push
  notifications (local notifications only), no iCloud/CloudKit.
- **Only two app extensions**: one DeviceActivityMonitor and one
  ShieldConfiguration. Every extension costs a free-account App ID.
- **All identity settings in one file**: `Config/Identity.xcconfig`. Every
  bundle ID and the App Group derive from `BUNDLE_ID_PREFIX`, and the app
  finds whatever SideStore renamed them to at runtime.
- **Stripped entitlements are detected, not crashed on.** If Family Controls or
  NFC Tag Reading is removed during signing, the app reads its own code
  signature, sees it's gone, disables the affected features and explains why.
- **Alternate app icons are bundled** in the asset catalog. Nothing is
  downloaded.

## Quick start

```sh
./scripts/build-ipa.sh          # → build/NintendoVideoViewer-1.0.0.ipa  (macOS + Xcode 15+)
```

No Mac? Run the **Build unsigned IPA** workflow on the Actions tab and download
the artifact.

Then in SideStore: **My Apps → + →** pick the `.ipa`. Refresh at least every 7
days. The app reminds you a day ahead.

Full steps: **[docs/SIDESTORE.md](docs/SIDESTORE.md)**.
Entitlements, Info.plist keys and free vs. paid: **[docs/ENTITLEMENTS.md](docs/ENTITLEMENTS.md)**.

## Free vs. paid at a glance

| Feature | Free Apple ID + SideStore | Paid account + Xcode |
|---|---|---|
| Install, run, diagnostics, local notifications, alternate icons | ✅ | ✅ |
| App Group (extensions share settings) | ✅ | ✅ |
| Block apps / schedules (Family Controls) | ❌ stripped; the app explains | ✅ |
| NFC tag unlock (NFC Tag Reading) | ❌ stripped; Emergency unlock instead | ✅ |
| Re-sign interval | 7 days | 1 year |

## Project layout

```
Config/
  Identity.xcconfig          ← display name, BUNDLE_ID_PREFIX, bundle IDs, App Group, version
  Base / Debug / Release     project-wide build settings
  App / ActivityMonitor / ShieldConfiguration.xcconfig   per-target settings
NintendoVideoViewer.xcodeproj   3 targets and a shared scheme; build settings live in the xcconfigs
App/
  Info.plist, App.entitlements, Assets.xcassets (AppIcon + 3 alternates + previews)
  Sources/
    MainApp.swift, AppModel.swift
    Capabilities/   CodeSignature (reads signed entitlements), Entitlements,
                    CapabilityInspector, ExtensionInventory, DiagnosticsReport
    Services/       NFCTagScanner, ScreenTimeService, NotificationService, AppIcon, TagFingerprint
    Views/          SwiftUI screens
Extensions/
  ActivityMonitor/          DeviceActivityMonitor: adds/removes the scheduled shield
  ShieldConfiguration/      ShieldConfigurationDataSource: custom block screen
Shared/                     Compiled into all targets: AppGroup resolution,
                            ProvisioningProfile parsing, SharedStore, models, ScreenTime helpers
scripts/
  build-ipa.sh              unsigned .ipa for SideStore
  check-sideload-compat.sh  fails the build if something breaks free-account sideloading
.github/workflows/build-ipa.yml   builds the .ipa on a GitHub macOS runner
```

## How the sideloading pieces fit

**Identity.** The xcconfigs set `PRODUCT_BUNDLE_IDENTIFIER` to
`$(APP_BUNDLE_ID)`, `$(MONITOR_BUNDLE_ID)` and `$(SHIELD_BUNDLE_ID)`. The
entitlements use `$(APP_GROUP_ID)`. No Swift file contains a bundle ID or group
name. `check-sideload-compat.sh` fails if one gets hard-coded.

**App Group at runtime.** SideStore re-registers the App Group under your
team, usually by appending your Team ID, and writes the real IDs into
`ALTAppGroups` in each bundle's Info.plist. `Shared/AppGroup.swift` picks the
group from there, from the embedded profile, or from the build-time ID, in
that order, and falls back to local storage if none is usable.

**Unsigned .ipa.** `build-ipa.sh` builds with code signing off, then gives each
binary an ad-hoc signature that only carries its requested entitlements (no
certificate, no profile). SideStore reads those entitlements to know what to
register, then signs everything with your Apple ID.

**Entitlement detection.** `CodeSignature.swift` parses the running binary's
`LC_CODE_SIGNATURE` and reads the entitlements iOS enforces. If it can't, it
falls back to `embedded.mobileprovision`. `CapabilityInspector` turns the result
into a status per capability. `AppModel` checks that status before every Family
Controls or Core NFC call, so a stripped entitlement means a message, not a
crash. **Settings → Signing diagnostics** shows everything.

## Requirements

- iOS 16.0+ (Family Controls individual authorization). iPhone only.
- Xcode 15+ to build.
- NFC tag reading needs an iPhone 7 or later.

## Customising

- **Name / bundle IDs:** `Config/Identity.xcconfig`
- **Icons:** replace the PNGs in `App/Assets.xcassets/AppIcon*.appiconset` and
  `IconPreview-*.imageset`. To add one, create the asset, add its name to
  `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in `Config/App.xcconfig`, and
  add a case to `App/Sources/Services/AppIcon.swift`.
