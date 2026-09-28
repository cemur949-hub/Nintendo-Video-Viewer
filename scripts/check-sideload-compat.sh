#!/usr/bin/env bash
#
# check-sideload-compat.sh: fail if the project uses something that breaks
# sideloading with SideStore and a free Apple ID.
#
# Checks:
#   - no paid-only frameworks or APIs (StoreKit, CloudKit/iCloud, push, Sign in with Apple)
#   - entitlements use only an allow-list of keys
#   - no more than 2 app extensions (free accounts get 10 App IDs per 7 days)
#   - bundle IDs and the App Group come only from Config/Identity.xcconfig
#   - every alternate app icon is bundled in Assets.xcassets
#
# Runs anywhere with bash, grep and sed (macOS or Linux). build-ipa.sh runs it first.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

failures=0
pass() { printf '  ok    %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; failures=$((failures + 1)); }

SOURCES="App Shared Extensions"

# 1. Paid-only or forbidden APIs --------------------------------------------
forbidden='import StoreKit|import CloudKit|import PushKit|SKPaymentQueue|SKStoreReviewController|registerForRemoteNotifications|NSUbiquitousKeyValueStore|forUbiquityContainerIdentifier|ubiquityIdentityToken|CKContainer|ASAuthorizationAppleIDProvider|\.timeSensitive'
if hits="$(grep -rnE "$forbidden" $SOURCES --include='*.swift' 2>/dev/null)"; then
  fail "paid-only / forbidden API used:"
  printf '%s\n' "$hits" | sed 's/^/          /'
else
  pass "no StoreKit, CloudKit/iCloud, push, Sign in with Apple or time-sensitive notifications"
fi

if grep -rq 'remote-notification' App/Info.plist; then
  fail "Info.plist enables the remote-notification background mode"
else
  pass "no remote-notification background mode"
fi

# 2. Entitlement allow-list --------------------------------------------------
allowed='com.apple.developer.family-controls|com.apple.developer.nfc.readersession.formats|com.apple.security.application-groups'
while IFS= read -r file; do
  bad="$(sed -n -E 's/.*<key>([^<]+)<\/key>.*/\1/p' "$file" | grep -vE "^($allowed)$" || true)"
  if [ -n "$bad" ]; then
    fail "$file requests entitlements outside the allow-list: $(echo "$bad" | tr '\n' ' ')"
  else
    pass "$file uses only allowed entitlements"
  fi
done < <(find App Extensions -name '*.entitlements' | sort)

# 3. Extension budget ---------------------------------------------------------
ext_count="$(grep -c 'com.apple.product-type.app-extension' NintendoVideoViewer.xcodeproj/project.pbxproj || true)"
if [ "$ext_count" -le 2 ]; then
  pass "$ext_count app extensions (limit 2: DeviceActivityMonitor + ShieldConfiguration)"
else
  fail "$ext_count app extensions; each one uses a free-account App ID"
fi

# 4. Identity lives in one place ---------------------------------------------
if grep -q 'PRODUCT_BUNDLE_IDENTIFIER' NintendoVideoViewer.xcodeproj/project.pbxproj; then
  fail "project.pbxproj sets PRODUCT_BUNDLE_IDENTIFIER; set it in Config/*.xcconfig from Identity.xcconfig"
else
  pass "project.pbxproj has no hard-coded bundle IDs"
fi

bad_ids="$(grep -hE '^PRODUCT_BUNDLE_IDENTIFIER *=' Config/*.xcconfig | grep -vE '= *\$\((APP|MONITOR|SHIELD)_BUNDLE_ID\) *$' || true)"
if [ -n "$bad_ids" ]; then
  fail "xcconfig bundle IDs must use \$(APP_BUNDLE_ID)/\$(MONITOR_BUNDLE_ID)/\$(SHIELD_BUNDLE_ID): $bad_ids"
else
  pass "every target's bundle ID derives from Config/Identity.xcconfig"
fi

prefix="$(sed -n -E 's/^BUNDLE_ID_PREFIX *= *([^ ]+).*/\1/p' Config/Identity.xcconfig)"
if [ -n "$prefix" ] && hits="$(grep -rnF "$prefix" $SOURCES 2>/dev/null)"; then
  fail "bundle prefix '$prefix' is hard-coded outside Config/:"
  printf '%s\n' "$hits" | sed 's/^/          /'
else
  pass "no bundle prefix or App Group hard-coded in sources or plists"
fi

# 5. Alternate icons are bundled ---------------------------------------------
icons="$(sed -n -E 's/^ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES *= *(.*)$/\1/p' Config/App.xcconfig)"
for icon in $icons; do
  if ls "App/Assets.xcassets/$icon.appiconset/"*.png >/dev/null 2>&1; then
    pass "alternate icon $icon is bundled"
  else
    fail "alternate icon $icon has no PNG in App/Assets.xcassets/$icon.appiconset"
  fi
done

echo
if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All sideloading checks passed."
