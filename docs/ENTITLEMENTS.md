# Entitlements and Info.plist keys

This page lists every entitlement and Info.plist key the app uses, why it's
there, and what happens with a **free Apple ID** vs. a **paid Apple Developer
Program** account.

Short version: with a free Apple ID, **Family Controls and NFC Tag Reading are
removed at signing**. The app launches anyway, detects the loss, and explains it
on screen. App Groups, local notifications and alternate icons all work on a
free account.

## Entitlements

Requested in `App/App.entitlements` and `Extensions/*/*.entitlements`.
`$(APP_GROUP_ID)` comes from `Config/Identity.xcconfig`.

| Entitlement | Targets | What it's for | Free Apple ID | Paid account |
|---|---|---|---|---|
| `com.apple.developer.family-controls` = `true` | App, Activity Monitor, Shield Configuration | Screen Time API: authorization, shielding apps, DeviceActivity schedules, the extensions themselves | ❌ **Not available** to free (Personal Team) accounts. SideStore signs without it. | ✅ The *development* variant works in development-signed builds (Xcode, or any development profile) without asking Apple. App Store/TestFlight distribution needs Apple's approval. |
| `com.apple.developer.nfc.readersession.formats` = `[TAG]` | App | `NFCTagReaderSession`, to read tag UIDs | ❌ **Not available** to free accounts. SideStore signs without it. | ✅ |
| `com.apple.security.application-groups` = `[$(APP_GROUP_ID)]` | App, Activity Monitor, Shield Configuration | Shares the block list, schedule and block-screen text with the extensions | ✅ SideStore registers the group under your team, usually as `group.<APP_BUNDLE_ID>.<TEAMID>`. The app finds the real name at runtime. | ✅ |
| `application-identifier`, `com.apple.developer.team-identifier`, `get-task-allow`, `keychain-access-groups` | All | Added by the signer; not in the project | ✅ | ✅ |

Only `TAG` is requested for NFC, not `NDEF`: `TAG` covers what the app needs,
and Xcode 15+ rejects `NDEF` in some configurations.

### SideStore on a paid account

SideStore only turns on a few capabilities (such as App Groups) when it
registers App IDs. Even with a paid account, expect Family Controls and NFC to
be stripped when you install through SideStore. To get them, install from Xcode
with your paid team:

1. In `Config/Identity.xcconfig`, set `DEVELOPMENT_TEAM` to your Team ID.
2. Open `NintendoVideoViewer.xcodeproj`, plug in your iPhone and press Run.
   Automatic signing registers the App IDs with Family Controls (Development),
   NFC Tag Reading and the App Group.
3. Paid development profiles last a year, so there's no weekly refresh.

Either way, **Settings → Signing diagnostics** in the app shows what the
installed copy actually got.

### Not used, on purpose

Each of these would either stop a free account from signing the app or be
stripped anyway:

| Capability | Why not |
|---|---|
| Push Notifications (`aps-environment`) | Paid only. The app uses **local** notifications (`UNUserNotificationCenter`), which need no entitlement. |
| iCloud / CloudKit (`com.apple.developer.icloud-*`, `ubiquity-kvstore-identifier`) | Paid only. All data stays in the App Group's `UserDefaults`. |
| In-App Purchase / StoreKit | Doesn't work outside the App Store. The project doesn't link StoreKit. |
| Time Sensitive Notifications, Associated Domains, Sign in with Apple, Network Extensions, Keychain Sharing | Not needed. |
| Extra app extensions | Every extension is another App ID, and free accounts get 10 per 7 days. The project has exactly 2. |

`scripts/check-sideload-compat.sh` enforces this list (entitlement allow-list,
banned frameworks and APIs, extension count), and `build-ipa.sh` runs it before
every build.

## How stripped entitlements are detected

Nothing that needs a missing entitlement is ever called. Detection happens
before any Family Controls or Core NFC API is touched:

1. **Code signature** (`App/Sources/Capabilities/CodeSignature.swift`) parses
   the running executable's `LC_CODE_SIGNATURE` and reads the entitlements blob.
   These are the entitlements iOS actually enforces.
2. **Provisioning profile** (`Shared/ProvisioningProfile.swift`) reads
   `embedded.mobileprovision` if the signature can't be read. Anything missing
   from the profile can't be in the binary.
3. **Runtime errors**: NFC's "security violation" error and Family Controls
   authorization errors are caught and shown as messages, as a last resort.

`CapabilityInspector` builds a report, and `AppModel` checks it before every
Screen Time or NFC action. Status per capability:

| Status | Meaning | What the user sees |
|---|---|---|
| Stripped at signing | Entitlement, App Group or extension missing from this signed copy | A red "Needs attention" card saying what was removed, why (free Apple ID / SideStore), what still works and how to fix it. Related buttons are disabled with a footnote. |
| Needs permission | Entitlement present, user hasn't decided yet | "Allow Screen Time access" / "Allow notifications" button |
| Turned off | User declined | "Open Settings" button |
| Unsupported | No NFC hardware, or the Simulator | Explanation. Emergency unlock stays available. |

What each loss affects:

| Missing | Still works | Doesn't work |
|---|---|---|
| Family Controls | Launching, tags, notifications, icons, diagnostics | Choosing apps, Lock now, schedules, custom block screen |
| NFC Tag Reading | Locking, schedules, **Emergency unlock** (timed) | Registering or scanning tags |
| App Group | Lock now / unlock (settings fall back to local storage) | Schedules, custom block-screen text |
| Extensions (removed by SideStore) | Lock now / unlock | Schedules (Activity Monitor), custom block screen (Shield Configuration) |

## Info.plist keys

### App (`App/Info.plist`)

| Key | Value | Why |
|---|---|---|
| `CFBundleIdentifier` | `$(PRODUCT_BUNDLE_IDENTIFIER)` → `$(APP_BUNDLE_ID)` | Set in `Config/Identity.xcconfig` |
| `CFBundleDisplayName` | `$(APP_DISPLAY_NAME)` | Home Screen name, from `Config/Identity.xcconfig` |
| `CFBundleShortVersionString` / `CFBundleVersion` | `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` | Shared with both extensions, which must match the app |
| `NFCReaderUsageDescription` | Text | **Required.** Without it iOS kills the app when an NFC session starts. |
| `com.apple.developer.nfc.readersession.iso7816.select-identifiers` | `D2760000850101` (NDEF application AID) | Lets ISO 7816 (Type 4) tags be detected. MIFARE/NTAG and ISO 15693 tags don't need it. |
| `AppGroupIdentifier` | `$(APP_GROUP_ID)` | Custom key: the group asked for at build time. Used as a fallback and to pick the right group from SideStore's list. |
| `UILaunchScreen`, `UIApplicationSceneManifest`, `LSRequiresIPhoneOS`, `UISupportedInterfaceOrientations`, `UIRequiredDeviceCapabilities` (`arm64`) | Standard | NFC is **not** listed as a required capability, so the app installs on any iPhone and explains when NFC is missing. |
| `ITSAppUsesNonExemptEncryption` | `false` | Harmless. Stops export-compliance prompts if you ever upload a build. |

**Generated at build time. Don't add these by hand:**

| Key | Source |
|---|---|
| `CFBundleIcons` → `CFBundlePrimaryIcon`, `CFBundleAlternateIcons` (`AppIcon-Midnight`, `AppIcon-Sunrise`, `AppIcon-Mono`) | `actool`, from `Assets.xcassets` and `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in `Config/App.xcconfig`. The icons are compiled into the app; nothing is downloaded. |

**Written by SideStore when it signs:**

| Key | Meaning | Used by the app |
|---|---|---|
| `ALTBundleIdentifier` | The bundle ID before SideStore changed it | Shown in Diagnostics |
| `ALTAppGroups` | The App Group IDs actually registered for your team | `Shared/AppGroup.swift` picks the group from this list |

No usage-description key is needed for Family Controls (the system prompt text
is fixed) or for local notifications.

### Extensions (`Extensions/*/Info.plist`)

| Key | Activity Monitor | Shield Configuration |
|---|---|---|
| `NSExtension` → `NSExtensionPointIdentifier` | `com.apple.deviceactivity.monitor-extension` | `com.apple.ManagedSettingsUI.shield-configuration-service` |
| `NSExtension` → `NSExtensionPrincipalClass` | `$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension` | `$(PRODUCT_MODULE_NAME).ShieldConfigurationExtension` |
| `CFBundleIdentifier` | `$(MONITOR_BUNDLE_ID)` = `$(APP_BUNDLE_ID).activitymonitor` | `$(SHIELD_BUNDLE_ID)` = `$(APP_BUNDLE_ID).shieldconfig` |
| `AppGroupIdentifier` | `$(APP_GROUP_ID)` | `$(APP_GROUP_ID)` |

Extension bundle IDs must start with the app's bundle ID. Deriving them from
`APP_BUNDLE_ID` keeps that true when you change the prefix, and when SideStore
rewrites the prefix.
