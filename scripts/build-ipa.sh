#!/usr/bin/env bash
#
# build-ipa.sh: build an unsigned .ipa to import into SideStore.
#
# The .ipa contains no certificate and no provisioning profile. Each binary is
# only ad-hoc "signed" so it can carry the entitlements it asks for. SideStore
# reads those to decide which App Group and capabilities to register, then
# re-signs everything with your Apple ID. Capabilities your account can't
# have are dropped, and the app detects that at runtime.
#
# Usage: scripts/build-ipa.sh [options]
#
#   -c, --configuration NAME     Release (default) or Debug
#   -p, --bundle-prefix PREFIX   Override BUNDLE_ID_PREFIX from Config/Identity.xcconfig
#   -o, --output DIR             Where to write the .ipa (default: build/)
#       --no-entitlements        Leave binaries completely unsigned. SideStore then
#                                won't register the App Group; not recommended.
#   -h, --help                   Show this help
#
# Requires macOS with Xcode 15 or later (select one with xcode-select or DEVELOPER_DIR).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/NintendoVideoViewer.xcodeproj"
SCHEME="NintendoVideoViewer"
APP_TARGET="NintendoVideoViewer"

CONFIGURATION="Release"
OUTPUT_DIR="$ROOT/build"
BUNDLE_PREFIX=""
EMBED_ENTITLEMENTS=1

die() { echo "error: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -c|--configuration) CONFIGURATION="${2:?missing value for $1}"; shift 2 ;;
    -p|--bundle-prefix) BUNDLE_PREFIX="${2:?missing value for $1}"; shift 2 ;;
    -o|--output)        OUTPUT_DIR="${2:?missing value for $1}"; shift 2 ;;
    --no-entitlements)  EMBED_ENTITLEMENTS=0; shift ;;
    -h|--help)          sed -n '3,/^$/p' "$0" | sed -E 's/^# ?//'; exit 0 ;;
    *)                  die "unknown option: $1 (see --help)" ;;
  esac
done

for tool in xcodebuild codesign plutil ditto zip /usr/libexec/PlistBuddy; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool not found. Run this on macOS with Xcode installed."
done
[ -d "$PROJECT" ] || die "project not found at $PROJECT"

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
DERIVED_DATA="$ROOT/build/DerivedData"

# Build-setting overrides passed to every xcodebuild call, so the build and
# the entitlement expansion below agree on the identity.
OVERRIDES=()
if [ -n "$BUNDLE_PREFIX" ]; then
  OVERRIDES+=("BUNDLE_ID_PREFIX=$BUNDLE_PREFIX")
fi

settings_for() { # $1 = target name → prints `xcodebuild -showBuildSettings` output
  xcodebuild -project "$PROJECT" -target "$1" -configuration "$CONFIGURATION" -sdk iphoneos \
    ${OVERRIDES[@]+"${OVERRIDES[@]}"} -showBuildSettings 2>/dev/null
}

setting() { # $1 = settings dump, $2 = setting name → prints its value
  printf '%s\n' "$1" | sed -n "s/^ *$2 = //p" | head -n 1
}

# Copy a target's .entitlements file and replace $(VARIABLES) with that
# target's build settings. Xcode does this itself only when it signs.
expand_entitlements() { # $1 = target name, $2 = output path
  local dump source var value escaped
  dump="$(settings_for "$1")"
  source="$(setting "$dump" CODE_SIGN_ENTITLEMENTS)"
  [ -n "$source" ] || die "target $1 has no CODE_SIGN_ENTITLEMENTS"
  cp "$ROOT/$source" "$2"
  for var in $(grep -oE '\$\([A-Za-z0-9_]+\)' "$2" | sort -u | sed -E 's/^\$\((.*)\)$/\1/'); do
    value="$(setting "$dump" "$var")"
    [ -n "$value" ] || die "$source uses \$($var), but it has no value for target $1"
    escaped="$(printf '%s' "$value" | sed -e 's/[\/&|\\]/\\&/g')"
    sed "s|\$($var)|$escaped|g" "$2" > "$2.tmp" && mv "$2.tmp" "$2"
  done
  plutil -lint -s "$2" >/dev/null || die "expanded entitlements for $1 aren't a valid plist"
}

adhoc_sign() { # $1 = bundle or binary, $2 = entitlements file (optional)
  if [ -n "${2:-}" ]; then
    codesign --force --sign - --timestamp=none --entitlements "$2" "$1"
  else
    codesign --force --sign - --timestamp=none "$1"
  fi
}

print_entitlements() { # $1 = bundle
  local tmp
  tmp="$(mktemp)"
  if codesign -d --entitlements - --xml "$1" >"$tmp" 2>/dev/null || codesign -d --entitlements :- "$1" >"$tmp" 2>/dev/null; then
    if [ -s "$tmp" ]; then
      /usr/libexec/PlistBuddy -c Print "$tmp" | sed 's/^/      /'
    else
      echo "      (none)"
    fi
  fi
  rm -f "$tmp"
}

plist_value() { # $1 = plist, $2 = key path
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true
}

step "Checking free-account compatibility"
"$ROOT/scripts/check-sideload-compat.sh"

step "Building $SCHEME ($CONFIGURATION) without code signing"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -quiet \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  ${OVERRIDES[@]+"${OVERRIDES[@]}"} \
  clean build

APP="$DERIVED_DATA/Build/Products/$CONFIGURATION-iphoneos/$APP_TARGET.app"
[ -d "$APP" ] || die "build succeeded but $APP is missing"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/Payload"
ditto "$APP" "$WORK/Payload/$APP_TARGET.app"
STAGED_APP="$WORK/Payload/$APP_TARGET.app"

if [ "$EMBED_ENTITLEMENTS" = 1 ]; then
  step "Embedding requested entitlements (ad-hoc signature, no certificate)"
  # Nested code first, the app last, because its signature seals the rest.
  while IFS= read -r -d '' nested; do
    adhoc_sign "$nested"
  done < <(find "$STAGED_APP" -depth \( -name '*.framework' -o -name '*.dylib' \) -print0)

  for appex in "$STAGED_APP"/PlugIns/*.appex; do
    [ -d "$appex" ] || continue
    target="$(basename "$appex" .appex)"
    expand_entitlements "$target" "$WORK/$target.entitlements"
    adhoc_sign "$appex" "$WORK/$target.entitlements"
  done
  expand_entitlements "$APP_TARGET" "$WORK/$APP_TARGET.entitlements"
  adhoc_sign "$STAGED_APP" "$WORK/$APP_TARGET.entitlements"
else
  step "Leaving binaries unsigned (--no-entitlements)"
fi

step "Verifying"
INFO="$STAGED_APP/Info.plist"
VERSION="$(plist_value "$INFO" CFBundleShortVersionString)"
BUILD="$(plist_value "$INFO" CFBundleVersion)"
echo "  App        $(plist_value "$INFO" CFBundleIdentifier)  $VERSION ($BUILD)"
[ "$EMBED_ENTITLEMENTS" = 1 ] && print_entitlements "$STAGED_APP"

EXTENSION_COUNT=0
for appex in "$STAGED_APP"/PlugIns/*.appex; do
  [ -d "$appex" ] || continue
  EXTENSION_COUNT=$((EXTENSION_COUNT + 1))
  echo "  Extension  $(plist_value "$appex/Info.plist" CFBundleIdentifier)"
  [ "$EMBED_ENTITLEMENTS" = 1 ] && print_entitlements "$appex"
done
[ "$EXTENSION_COUNT" -eq 2 ] || die "expected 2 app extensions in PlugIns/, found $EXTENSION_COUNT"

ALT_ICONS="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons:CFBundleAlternateIcons' "$INFO" 2>/dev/null \
  | sed -n -E 's/^    ([^ ]+) = Dict \{$/\1/p' | tr '\n' ' ')"
[ -n "$ALT_ICONS" ] || die "no alternate icons in the built Info.plist (check ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES)"
echo "  Icons      AppIcon (primary), $ALT_ICONS(bundled)"

if [ -e "$STAGED_APP/embedded.mobileprovision" ]; then
  die "the app contains a provisioning profile; the SideStore .ipa should have none"
fi

step "Packaging"
IPA="$OUTPUT_DIR/$APP_TARGET-$VERSION.ipa"
rm -f "$IPA"
(cd "$WORK" && zip -qry -X "$IPA" Payload)

echo
echo "Done: $IPA ($(du -h "$IPA" | cut -f1 | tr -d ' '))"
echo "Next: copy it to your iPhone, open SideStore > My Apps > + and choose the file."
echo "See docs/SIDESTORE.md for install and weekly refresh steps."
