#!/usr/bin/env bash
# One-command hosted setup for Parent Control.
#
#   ./scripts/complete_hosted_setup.sh --create
#   PROJECT_REF=abcdefghijklmnop ./scripts/complete_hosted_setup.sh
#
# The database password is read from .tools/supabase-db-password.txt
# (gitignored) and is never echoed. The Supabase CLI must already be logged
# into the account that owns the target organization.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ORG_ID="${ORG_ID:-sbaufgeojlessannmnke}"
PROJECT_NAME="${PROJECT_NAME:-parent-control-prod}"
REGION="${REGION:-ap-south-1}"
PASSWORD_FILE="${SUPABASE_DB_PASSWORD_FILE:-.tools/supabase-db-password.txt}"
SERIAL="${ANDROID_SERIAL:-5HXWRGQ4IFU8WS4T}"

command -v supabase >/dev/null || { echo "Missing supabase CLI." >&2; exit 1; }
command -v node >/dev/null || { echo "Missing node." >&2; exit 1; }

if [ ! -s "$PASSWORD_FILE" ]; then
  echo "Missing $PASSWORD_FILE. Create it locally with a strong database password." >&2
  exit 1
fi
chmod 600 "$PASSWORD_FILE" 2>/dev/null || true
export SUPABASE_DB_PASSWORD="$(cat "$PASSWORD_FILE")"

PROJECT_REF="${PROJECT_REF:-${1:-}}"
if [ "${1:-}" = "--create" ] || [ -z "$PROJECT_REF" ]; then
  echo "Creating $PROJECT_NAME in $ORG_ID ($REGION)..."
  PROJECT_REF="$(supabase projects create "$PROJECT_NAME" \
    --org-id "$ORG_ID" --region "$REGION" \
    --db-password "$SUPABASE_DB_PASSWORD" --output json \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const p=JSON.parse(s);const ref=p.ref||p.id;if(!ref)process.exit(2);process.stdout.write(ref)})')"
  echo "Created project ref: $PROJECT_REF"
fi

echo "Linking $PROJECT_REF..."
supabase link --project-ref "$PROJECT_REF" --yes

echo "Applying migrations..."
supabase db push --yes

echo "Pushing auth/API/function configuration..."
if ! supabase config push --project-ref "$PROJECT_REF" --yes; then
  echo "config push failed; add parentcontrol://auth-callback manually under" >&2
  echo "Authentication -> URL Configuration -> Redirect URLs." >&2
fi

if [ ! -f secrets.env ]; then
  umask 077
  CRON="$(head -c 32 /dev/urandom | base64 | tr -d '\n/+=')"
  printf 'CRON_SECRET=%s\n' "$CRON" > secrets.env
  echo "Generated secrets.env with CRON_SECRET (gitignored)."
  echo "Add TURN_URL, TURN_SECRET, TURN_TTL_SECONDS and STUN_URL there to enable TURN."
fi
supabase secrets set --env-file secrets.env --project-ref "$PROJECT_REF" --yes

echo "Deploying nine functions..."
supabase functions deploy \
  auth-bootstrap pairing device-register device-policy family-admin \
  remote-session \
  --project-ref "$PROJECT_REF" --use-api
supabase functions deploy \
  device-command device-telemetry cron \
  --no-verify-jwt --project-ref "$PROJECT_REF" --use-api

KEYS_JSON="$(supabase projects api-keys --project-ref "$PROJECT_REF" --output json)"
ANON_KEY="$(printf '%s' "$KEYS_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const a=JSON.parse(s);const key=x=>x.api_key||x.key||"";const k=a.find(x=>x.name==="anon")||a.find(x=>x.name==="publishable")||a.find(x=>x.type==="publishable")||a.find(x=>String(key(x)).startsWith("sb_publishable_"));if(!k)process.exit(3);process.stdout.write(key(k))})')"
PROJECT_URL="https://${PROJECT_REF}.supabase.co"

umask 077
printf 'SUPABASE_URL=%s\nSUPABASE_ANON_KEY=%s\n' "$PROJECT_URL" "$ANON_KEY" > .tools/live_config.env
echo "Wrote publishable connection values to .tools/live_config.env (gitignored)."

echo "Smoke checks:"
curl -fsS "$PROJECT_URL/auth/v1/health" -H "apikey: $ANON_KEY" >/dev/null && echo "  auth health: ok"
REST_CODE="$(curl -s -o /dev/null -w '%{http_code}' "$PROJECT_URL/rest/v1/profiles?select=id&limit=1" -H "apikey: $ANON_KEY")"
echo "  anonymous profiles select: HTTP $REST_CODE (denied or empty is expected)"
FN_CODE="$(curl -s -o /dev/null -w '%{http_code}' "$PROJECT_URL/functions/v1/auth-bootstrap" -H "apikey: $ANON_KEY")"
echo "  auth-bootstrap without JWT: HTTP $FN_CODE (401 expected)"

echo "Building the debug APK with the hosted project..."
fvm flutter build apk --debug \
  --dart-define=SUPABASE_URL="$PROJECT_URL" \
  --dart-define=SUPABASE_ANON_KEY="$ANON_KEY"

if adb devices | grep -q "$SERIAL"; then
  echo "Installing and launching on $SERIAL..."
  adb -s "$SERIAL" install -r build/app/outputs/flutter-apk/app-debug.apk
  adb -s "$SERIAL" shell am start -W -n com.parentcontrol.parent_control/.MainActivity
else
  echo "Device $SERIAL not connected; skipping install."
fi

echo "Done. Confirm a test account's email in Dashboard -> Authentication -> Users,"
echo "then run the live matrix in docs/backend.md."
