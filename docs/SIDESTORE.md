# Build, install with SideStore, and refresh every 7 days

## What you need

- An iPhone on **iOS 16 or later** with **SideStore already installed and
  refreshing** (pairing file and VPN set up as in SideStore's own guide).
- A way to build the `.ipa`, either of:
  - a **Mac with Xcode 15 or later**, or
  - **GitHub Actions** (no Mac needed; see step 2B).
- Optional: an NFC tag (any NTAG213/215/216 sticker, key fob or card). Tags
  only work if the NFC entitlement survives signing, which it doesn't on a free
  Apple ID. See [ENTITLEMENTS.md](ENTITLEMENTS.md).

> **What to expect on a free Apple ID:** the app installs and runs, but Apple
> doesn't give free accounts the Family Controls or NFC Tag Reading
> capabilities, so SideStore signs without them. The app detects this and
> shows it under **Needs attention**. App blocking and tag scanning stay off,
> and everything else works. A paid account signing from Xcode gets everything.

## 1. Pick your bundle ID prefix (once)

Open `Config/Identity.xcconfig` and set `BUNDLE_ID_PREFIX` to something unique
to you:

```
BUNDLE_ID_PREFIX = com.yourname
```

Every bundle ID and the App Group derive from it:

| | Result |
|---|---|
| App | `com.yourname.nvviewer` |
| Activity Monitor extension | `com.yourname.nvviewer.activitymonitor` |
| Shield Configuration extension | `com.yourname.nvviewer.shieldconfig` |
| App Group | `group.com.yourname.nvviewer` |

SideStore usually appends your Team ID when it signs
(`com.yourname.nvviewer.ABCDE12345`). The app handles that.

To try a different prefix without editing the file, pass
`--bundle-prefix com.other` to the build script. A new prefix means new App
IDs, so don't change it often (see *Limits* below).

## 2A. Build the .ipa on a Mac

```sh
git clone https://github.com/cemur949-hub/Nintendo-Video-Viewer.git
cd Nintendo-Video-Viewer
./scripts/build-ipa.sh
```

The script:

1. runs `scripts/check-sideload-compat.sh` (no paid-only APIs or
   entitlements, at most 2 extensions, identity only in `Identity.xcconfig`,
   icons bundled);
2. builds the app and both extensions with code signing turned off;
3. embeds each target's requested entitlements with an ad-hoc signature (no
   certificate), so SideStore knows to register the App Group;
4. checks the result (bundle IDs, entitlements, 2 extensions, alternate icons
   in Info.plist, no provisioning profile) and zips it.

Output: `build/NintendoVideoViewer-1.0.0.ipa`.

Options: `--configuration Debug`, `--bundle-prefix com.yourname`,
`--output DIR`, `--help`. If you have several Xcodes, pick one with
`DEVELOPER_DIR=/Applications/Xcode_16.app/Contents/Developer ./scripts/build-ipa.sh`.

## 2B. Or build it with GitHub Actions (no Mac)

1. On GitHub, open the repo's **Actions** tab and choose **Build unsigned IPA**.
2. Click **Run workflow** (it also runs on every push).
3. When it finishes, download **unsigned-ipa** from the run's **Artifacts**.
   It's a `.zip` with the `.ipa` inside.

## 3. Get the .ipa onto your iPhone

Any of these:

- **AirDrop** it from your Mac. It lands in Files → Downloads.
- Put it in **iCloud Drive** and open the Files app.
- Download the Actions artifact in Safari on the iPhone, then tap the `.zip`
  in Files to unzip it.

## 4. Install with SideStore

1. Be on Wi-Fi and turn on the VPN SideStore uses for refreshing, as in its
   setup guide.
2. Open **SideStore → My Apps** and tap **+** (top left).
3. Pick `NintendoVideoViewer-1.0.0.ipa` in the file picker.
4. If SideStore asks whether to **keep or remove app extensions**:
   - **Keep** (recommended): uses 3 App IDs and gives you schedules and the
     custom block screen.
   - **Remove**: uses 1 App ID. Scheduled locks and the custom block screen
     won't work, and the app says so.
5. If SideStore warns that some entitlements aren't supported by your account,
   continue. That's Family Controls and NFC being stripped on a free account,
   and the app handles it.
6. The app shows up on your Home Screen as **NV Viewer** (change it with
   `APP_DISPLAY_NAME`).

## 5. First launch

- **Needs attention** at the top lists anything missing and why. Typical free
  account: *Screen Time* and *NFC tag reading* show **Stripped at signing**;
  *App Group* and *App extensions* are fine.
- Tap **Allow notifications** to get a reminder before the app expires.
- **Settings → Signing diagnostics** shows the real bundle ID, Team ID,
  profile expiry, account type (free = 7-day profile), each entitlement, the
  App Group in use and the installed extensions. **Copy diagnostics** puts it
  all on the clipboard for bug reports.

## 6. Refresh every 7 days

Apps signed with a free Apple ID stop opening 7 days after they were signed.
Refreshing re-signs them in place, and your data isn't touched.

1. Be on Wi-Fi with SideStore's VPN on.
2. Open **SideStore → My Apps**.
3. Tap **Refresh All**, or tap the **N DAYS** button next to this app to
   refresh only it. Refresh All also refreshes SideStore, which expires on the
   same 7-day cycle.

Reminders: with notifications allowed, the app schedules local notifications
**24 hours** and **3 hours** before its signature expires. It reads the expiry
from its own embedded provisioning profile and updates the reminders each time
you open it. **Settings → Refresh in SideStore by** shows the date.

Automating it (optional): SideStore can refresh in the background, and recent
versions add a Shortcuts action. A daily Shortcuts automation that runs
SideStore's refresh keeps you ahead of the deadline. Check your SideStore
version for what it supports.

If you missed it:

- **The app won't open** ("no longer available" / "unable to verify"): open
  SideStore and refresh it. Your data is still there.
- **SideStore itself expired**: reinstall SideStore with its install guide,
  then refresh this app. Apps you don't delete keep their data.

## 7. Updating

1. Bump `MARKETING_VERSION` (and/or `CURRENT_PROJECT_VERSION`) in
   `Config/Identity.xcconfig`.
2. Rebuild with `./scripts/build-ipa.sh`.
3. In SideStore, tap **+** and pick the new `.ipa`. The bundle ID is the same,
   so it replaces the installed app and keeps your data. A different
   `BUNDLE_ID_PREFIX` would install a separate app with empty data.

## Free-account limits

| Limit | What it means here |
|---|---|
| Apps expire after **7 days** | Refresh weekly (step 6) |
| **3** sideloaded apps active at once, SideStore included | This app plus SideStore uses 2 |
| **10 App IDs per rolling 7 days** | This app uses 3 (app + 2 extensions), or 1 if you remove the extensions. Refreshing reuses existing App IDs. Changing `BUNDLE_ID_PREFIX` uses new ones. |
| No Family Controls, NFC, push or iCloud | Detected and explained in the app (see [ENTITLEMENTS.md](ENTITLEMENTS.md)) |

## Troubleshooting

| Symptom | Fix |
|---|---|
| SideStore: *"maximum App ID limit reached"* | Wait for older App IDs to age out (7 days), or reinstall and remove the extensions. Don't keep changing the bundle prefix. |
| SideStore: *"maximum number of apps"* | Free accounts allow 3 active apps. Remove or deactivate another sideloaded app. |
| SideStore: *"App ID … is not available"* | Someone else registered that bundle ID. Change `BUNDLE_ID_PREFIX` and rebuild. |
| App says **App Group: Stripped at signing** | The `.ipa` was built with `--no-entitlements`, or SideStore couldn't create the group. Rebuild without the flag and reinstall. |
| App says **App extensions: Stripped at signing** | You removed extensions at install. Reinstall and keep them. |
| **Screen Time / NFC: Stripped at signing** | Expected on a free Apple ID. Use a paid account and Xcode to get them ([ENTITLEMENTS.md](ENTITLEMENTS.md#sidestore-on-a-paid-account)). |
| Build fails in `check-sideload-compat.sh` | A change added a paid-only API, an entitlement or an extension. The output names the file. |
