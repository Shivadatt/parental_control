#!/usr/bin/env bash
# Debug APK build with validated client config (--dart-define-from-file).
#
# Why: `flutter build apk` without dart-defines produces a client that has no
# Supabase URL/anon key, so it starts in the "backend not configured" state.
#
# Usage:
#   bash scripts/build_debug_apk.sh [extra flutter build args...]
#   bash scripts/build_debug_apk.sh --split-per-abi
#   LIVE_CONFIG_FILE=/path/to/other.env bash scripts/build_debug_apk.sh
#
# The config file is validated by scripts/check_live_config.sh; no value is
# ever printed. Extra arguments are forwarded to `flutter build apk`.
set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root="$(cd "$_script_dir/.." && pwd)"
cd "$_root"

# shellcheck source=scripts/check_live_config.sh
source "$_root/scripts/check_live_config.sh"

printf '[build_debug_apk] repo root: %s\n' "$_root"

_rc=0
check_live_config || _rc=$?
if [ "$_rc" -ne 0 ]; then
  printf '[build_debug_apk] ABORT: config validation failed (exit %d); no build started\n' "$_rc" >&2
  exit "$_rc"
fi

# --- SDK selection: fvm if available, else the pinned FVM SDK, else fail -----
FLUTTER_CMD=()
if command -v fvm >/dev/null 2>&1; then
  FLUTTER_CMD=(fvm flutter)
  printf '[build_debug_apk] SDK: fvm flutter (fvm on PATH)\n'
elif [ -f "$_root/.fvm/flutter_sdk/bin/flutter" ]; then
  FLUTTER_CMD=("$_root/.fvm/flutter_sdk/bin/flutter")
  printf '[build_debug_apk] SDK: %s\n' "$_root/.fvm/flutter_sdk/bin/flutter"
else
  {
    printf '[build_debug_apk] FAIL: no Flutter SDK found.\n'
    printf '[build_debug_apk]   - `fvm` is not on PATH, and\n'
    printf '[build_debug_apk]   - %s does not exist.\n' "$_root/.fvm/flutter_sdk/bin/flutter"
    printf '[build_debug_apk] hint: run `fvm install` (pinned 3.44.6, see .fvmrc) or add fvm to PATH.\n'
  } >&2
  exit 5
fi

# --- pub get only when the package config is missing -------------------------
if [ ! -f "$_root/.dart_tool/package_config.json" ]; then
  printf '[build_debug_apk] .dart_tool/package_config.json missing -> running pub get\n'
  "${FLUTTER_CMD[@]}" pub get
else
  printf '[build_debug_apk] .dart_tool/package_config.json present -> skipping pub get\n'
fi

# --- build -------------------------------------------------------------------
BUILD_CMD=("${FLUTTER_CMD[@]}" build apk --debug "--dart-define-from-file=$LIVE_CONFIG_RESOLVED")
if [ "$#" -gt 0 ]; then
  BUILD_CMD+=("$@")
fi

printf '[build_debug_apk] exact command:\n'
printf '  %s\n' "${BUILD_CMD[*]}"
printf '[build_debug_apk] (dart-define file: %s; contents not printed)\n' "$LIVE_CONFIG_RESOLVED"

"${BUILD_CMD[@]}"

APK="$_root/build/app/outputs/flutter-apk/app-debug.apk"
printf '\n[build_debug_apk] build succeeded\n'
if [ -f "$APK" ]; then
  ls -l "$APK"
  sha256sum "$APK"
else
  printf '[build_debug_apk] note: %s not found (expected when --split-per-abi splits the APK); artifacts:\n' "$APK"
  for _f in "$_root"/build/app/outputs/flutter-apk/app-*-debug.apk; do
    if [ -f "$_f" ]; then
      ls -l "$_f"
      sha256sum "$_f"
    fi
  done
fi
