#!/usr/bin/env bash
# Release APK build with validated client config (--dart-define-from-file).
#
# Why: `flutter build apk --release` without dart-defines produces a
# config-less client. This wrapper refuses to build until the config file is
# validated by scripts/check_live_config.sh.
#
# Usage:
#   bash scripts/build_release_apk.sh [extra flutter build args...]
#   bash scripts/build_release_apk.sh --split-per-abi
#   LIVE_CONFIG_FILE=/path/to/other.env bash scripts/build_release_apk.sh
#
# No key/URL value is ever printed. If release signing is not configured the
# Gradle build may still succeed with debug signing; the output below reports
# exactly what happened, it does not claim a properly signed artefact.
set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root="$(cd "$_script_dir/.." && pwd)"
cd "$_root"

# shellcheck source=scripts/check_live_config.sh
source "$_root/scripts/check_live_config.sh"

printf '[build_release_apk] repo root: %s\n' "$_root"

_rc=0
check_live_config || _rc=$?
if [ "$_rc" -ne 0 ]; then
  printf '[build_release_apk] ABORT: config validation failed (exit %d); no build started\n' "$_rc" >&2
  exit "$_rc"
fi

# --- signing configuration (reported, never validated for secrets) -----------
if [ -f "$_root/android/key.properties" ]; then
  printf '[build_release_apk] signing: android/key.properties present (Gradle decides which key is used)\n'
else
  printf '[build_release_apk] signing: android/key.properties absent -> Gradle likely falls back to debug signing\n'
fi

# --- SDK selection: fvm if available, else the pinned FVM SDK, else fail -----
FLUTTER_CMD=()
if command -v fvm >/dev/null 2>&1; then
  FLUTTER_CMD=(fvm flutter)
  printf '[build_release_apk] SDK: fvm flutter (fvm on PATH)\n'
elif [ -f "$_root/.fvm/flutter_sdk/bin/flutter" ]; then
  FLUTTER_CMD=("$_root/.fvm/flutter_sdk/bin/flutter")
  printf '[build_release_apk] SDK: %s\n' "$_root/.fvm/flutter_sdk/bin/flutter"
else
  {
    printf '[build_release_apk] FAIL: no Flutter SDK found.\n'
    printf '[build_release_apk]   - `fvm` is not on PATH, and\n'
    printf '[build_release_apk]   - %s does not exist.\n' "$_root/.fvm/flutter_sdk/bin/flutter"
    printf '[build_release_apk] hint: run `fvm install` (pinned 3.44.6, see .fvmrc) or add fvm to PATH.\n'
  } >&2
  exit 5
fi

# --- pub get only when the package config is missing -------------------------
if [ ! -f "$_root/.dart_tool/package_config.json" ]; then
  printf '[build_release_apk] .dart_tool/package_config.json missing -> running pub get\n'
  "${FLUTTER_CMD[@]}" pub get
else
  printf '[build_release_apk] .dart_tool/package_config.json present -> skipping pub get\n'
fi

# --- build -------------------------------------------------------------------
BUILD_CMD=("${FLUTTER_CMD[@]}" build apk --release "--dart-define-from-file=$LIVE_CONFIG_RESOLVED")
if [ "$#" -gt 0 ]; then
  BUILD_CMD+=("$@")
fi

printf '[build_release_apk] exact command:\n'
printf '  %s\n' "${BUILD_CMD[*]}"
printf '[build_release_apk] (dart-define file: %s; contents not printed)\n' "$LIVE_CONFIG_RESOLVED"

"${BUILD_CMD[@]}"

# --- post-build evidence: size, hash, and what signing actually happened -----
APK="$_root/build/app/outputs/flutter-apk/app-release.apk"
printf '\n[build_release_apk] build succeeded\n'

if [ -f "$APK" ]; then
  ls -l "$APK"
  sha256sum "$APK"
else
  printf '[build_release_apk] note: %s not found (expected with --split-per-abi)\n' "$APK"
  for _f in "$_root"/build/app/outputs/flutter-apk/app-*-release.apk; do
    if [ -f "$_f" ]; then
      ls -l "$_f"
      sha256sum "$_f"
    fi
  done
fi

printf '[build_release_apk] signing check: run\n'
printf '  "$LOCALAPPDATA/Android/Sdk/build-tools/36.0.0/apksigner.bat" verify --print-certs <apk>\n'
printf '  certificate "Android Debug" means the APK is NOT release-signed.\n'
