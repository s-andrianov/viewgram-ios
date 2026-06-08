#!/bin/bash
# Viewgram — rebuild a lightweight, self-distributable .ipa (no extensions, ad-hoc signed).
#
# Usage:
#   ./vg_rebuild.sh             # rebuild + copy ipa to ~/Desktop/Viewgram.ipa
#   ./vg_rebuild.sh --install   # also install onto a USB-connected iPhone via ios-deploy
#   ./vg_rebuild.sh --sim       # build & install to the booted Simulator instead (dev)
#
# The produced ~/Desktop/Viewgram.ipa is what you drop into AltStore/Sideloadly
# (yours, and your friends' — each signs it with their own Apple ID).

set -euo pipefail

REPO="/Users/sanaxis/ПРОЕКТЫ/telegram-ios"
BAZEL="$REPO/build-input/bazel-8.4.2-darwin-arm64"
CACHE="/Users/sanaxis/telegram-bazel-cache"
OUT="$HOME/Desktop/Viewgram.ipa"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

cd "$REPO"

# Viewgram: this app is sideloaded (AltStore / free Apple ID) and cannot carry the
# Siri or iCloud entitlements. If they get baked in, the app TRAPS on launch when the
# OS finds the entitlement missing at runtime (INPreferences Siri -> SIGABRT, CloudKit
# init -> SIGTRAP). Debug builds via Make.py regenerate variables.bzl from
# appstore-configuration.json (siri/icloud = true), so re-assert them OFF before every
# device build.
VARS="$REPO/build-input/configuration-repository/variables.bzl"
if [ -f "$VARS" ]; then
  /usr/bin/sed -i '' 's/^telegram_enable_siri = .*/telegram_enable_siri = False/' "$VARS"
  /usr/bin/sed -i '' 's/^telegram_enable_icloud = .*/telegram_enable_icloud = False/' "$VARS"
fi

MODE="device"
DO_INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --install) DO_INSTALL=1 ;;
    --sim) MODE="sim" ;;
  esac
done

if [ "$MODE" = "sim" ]; then
  echo "▶ Building for Simulator (debug_sim_arm64)…"
  python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir "$CACHE" \
    build --configurationPath build-system/appstore-configuration.json \
    --codesigningInformationPath build-system/fake-codesigning \
    --buildNumber=1 --configuration=debug_sim_arm64 --continueOnError
  APP_SRC="$REPO/bazel-bin/Telegram/Telegram.app"
  echo "▶ Installing to booted Simulator…"
  xcrun simctl install booted "$APP_SRC"
  xcrun simctl launch booted ph.telegra.Telegraph || true
  echo "✅ Installed to Simulator."
  exit 0
fi

echo "▶ Building lightweight device .ipa (RELEASE, no extensions, ad-hoc)…"
# IMPORTANT: use -c opt (release). Debug builds keep Swift assertionFailure/precondition
# active, which TRAP (SIGTRAP) on startup paths that are benign in release → app crashes.
"$BAZEL" build Telegram/Telegram \
  --keep_going --features=swift.use_global_module_cache --verbose_failures \
  --remote_cache_async --define=buildNumber=1 --disk_cache="$CACHE" \
  -c opt --ios_multi_cpus=arm64 --watchos_cpus=arm64_32 \
  --//Telegram:disableExtensions=True \
  --ios_signing_cert_name="-"

IPA="$REPO/bazel-bin/Telegram/Telegram.ipa"
if [ ! -f "$IPA" ]; then
  echo "✗ Build did not produce $IPA" >&2
  exit 1
fi

cp -f "$IPA" "$OUT"
echo "✅ Built: $OUT  ($(du -h "$OUT" | cut -f1))"
echo "   → Drop this file into AltStore/Sideloadly to install with your Apple ID."

if [ "$DO_INSTALL" = "1" ]; then
  if ! command -v ios-deploy >/dev/null 2>&1; then
    echo "✗ ios-deploy not found (brew install ios-deploy)" >&2
    exit 1
  fi
  echo "▶ Installing onto connected iPhone…"
  TMP=$(mktemp -d)
  ( cd "$TMP" && unzip -q "$OUT" )
  ios-deploy --bundle "$TMP/Payload/Telegram.app" --no-wifi || {
    echo "ℹ ios-deploy needs the app to be signed with a profile valid for your device." >&2
    echo "  For a free Apple ID, install $OUT through AltStore/Sideloadly instead." >&2
  }
  rm -rf "$TMP"
fi
