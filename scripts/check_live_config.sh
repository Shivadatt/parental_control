#!/usr/bin/env bash
# Validates the local client config file consumed by
# `flutter build apk --dart-define-from-file=<file>`.
#
# Standalone:  bash scripts/check_live_config.sh
# Sourced:     source scripts/check_live_config.sh
#              check_live_config || exit $?
#
# The file is NEVER printed, sourced as shell code or evaluated. Only key names
# and PASS/FAIL verdicts are emitted. Values are never echoed, not even masked.
#
# Config path: $LIVE_CONFIG_FILE, default <repo-root>/.tools/live_config.env
#
# Exit / return codes:
#   0  valid
#   1  required key missing or empty
#   2  config file not found
#   3  privileged (server-only) key present
#   4  SUPABASE_URL does not start with https://
#   5  internal error (unreadable file)
#
# On success LIVE_CONFIG_RESOLVED holds the absolute path of the config file
# (a path, not a secret) so callers can pass it to --dart-define-from-file.
set -euo pipefail

# Keys the client build requires.
_LVC_REQUIRED_KEYS="SUPABASE_URL SUPABASE_ANON_KEY"
# Keys that must never ship inside a client build.
_LVC_FORBIDDEN_KEYS="SUPABASE_SERVICE_ROLE_KEY SUPABASE_DB_PASSWORD DB_PASSWORD SERVICE_ROLE_KEY"

_lvc_repo_root() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  cd "$dir/.." >/dev/null 2>&1 && pwd
}

# Trim leading/trailing whitespace (including CR already removed by caller).
_lvc_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Remove one pair of matching surrounding quotes, if present.
_lvc_unquote() {
  local s="$1"
  if [ "${#s}" -ge 2 ]; then
    case "$s" in
      \"*\") s="${s#\"}"; s="${s%\"}" ;;
      \'*\') s="${s#\'}"; s="${s%\'}" ;;
    esac
  fi
  printf '%s' "$s"
}

# Returns 0/1/2/3/4/5 as documented above.
check_live_config() {
  local root cfg cfg_abs line key val
  local url="" anon="" forbidden="" lineno=0 rc=0

  root="$(_lvc_repo_root)" || {
    printf '[check_live_config] FAIL: cannot resolve repo root (5)\n' >&2
    return 5
  }
  cfg="${LIVE_CONFIG_FILE:-$root/.tools/live_config.env}"
  LIVE_CONFIG_RESOLVED=""

  printf '[check_live_config] repo root: %s\n' "$root"

  if [ ! -f "$cfg" ]; then
    printf '[check_live_config] FAIL: config file not found: %s\n' "$cfg" >&2
    printf '[check_live_config] hint: create it with SUPABASE_URL and SUPABASE_ANON_KEY only\n' >&2
    printf '[check_live_config] hint: set LIVE_CONFIG_FILE to override the path\n' >&2
    return 2
  fi

  cfg_abs="$(cd "$(dirname "$cfg")" >/dev/null 2>&1 && pwd)/$(basename "$cfg")"
  if [ ! -r "$cfg_abs" ]; then
    printf '[check_live_config] FAIL: config file not readable: %s\n' "$cfg_abs" >&2
    return 5
  fi
  printf '[check_live_config] config: %s\n' "$cfg_abs"

  # Parse line by line: no sourcing, no eval, no value echo.
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    line="${line%$'\r'}"                      # Windows CRLF
    if [ "$lineno" -eq 1 ]; then
      line="${line#$'\xEF\xBB\xBF'}"          # UTF-8 BOM
    fi
    line="$(_lvc_trim "$line")"
    case "$line" in
      '' | '#'*) continue ;;
    esac
    case "$line" in
      export\ *) line="$(_lvc_trim "${line#export }")" ;;
    esac
    case "$line" in
      *=*) ;;
      *) continue ;;
    esac
    key="$(_lvc_trim "${line%%=*}")"
    val="$(_lvc_trim "${line#*=}")"
    val="$(_lvc_unquote "$val")"
    case "$key" in
      SUPABASE_URL) url="$val" ;;
      SUPABASE_ANON_KEY) anon="$val" ;;
      SUPABASE_SERVICE_ROLE_KEY | SUPABASE_DB_PASSWORD | DB_PASSWORD | SERVICE_ROLE_KEY)
        case " $forbidden " in
          *" $key "*) ;;
          *) forbidden="$forbidden $key" ;;
        esac
        ;;
    esac
  done <"$cfg_abs"

  # Security gate first: a privileged key is disqualifying regardless of the rest.
  if [ -n "$forbidden" ]; then
    printf '[check_live_config] FAIL: privileged key(s) present in a client config:\n' >&2
    for key in $forbidden; do
      printf '[check_live_config]   - %s  (server-side only; remove it, never ship it)\n' "$key" >&2
    done
    printf '[check_live_config] RESULT: FAIL (privileged key, exit 3)\n' >&2
    return 3
  fi

  if [ -n "$url" ]; then
    printf '[check_live_config] SUPABASE_URL: PASS (present, non-empty)\n'
  else
    printf '[check_live_config] SUPABASE_URL: FAIL (missing or empty)\n' >&2
    rc=1
  fi

  if [ -n "$url" ]; then
    case "$url" in
      https://*)
        printf '[check_live_config] SUPABASE_URL scheme: PASS (https://)\n'
        ;;
      *)
        printf '[check_live_config] SUPABASE_URL scheme: FAIL (must start with https://; value not shown)\n' >&2
        rc=4
        ;;
    esac
  else
    printf '[check_live_config] SUPABASE_URL scheme: SKIP (no value)\n' >&2
  fi

  if [ -n "$anon" ]; then
    printf '[check_live_config] SUPABASE_ANON_KEY: PASS (present, non-empty)\n'
  else
    printf '[check_live_config] SUPABASE_ANON_KEY: FAIL (missing or empty)\n' >&2
    rc=1
  fi

  printf '[check_live_config] forbidden keys: PASS (no privileged key found)\n'

  if [ "$rc" -ne 0 ]; then
    printf '[check_live_config] RESULT: FAIL (exit %d)\n' "$rc" >&2
    return "$rc"
  fi

  LIVE_CONFIG_RESOLVED="$cfg_abs"
  printf '[check_live_config] RESULT: PASS\n'
  return 0
}

# Run as a command (not sourced)?
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _lvc_rc=0
  check_live_config || _lvc_rc=$?
  exit "$_lvc_rc"
fi
