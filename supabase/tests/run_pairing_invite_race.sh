#!/usr/bin/env bash
# BUG-033: genuine two-session proof that private.create_pairing_invite()
# serialises concurrent callers on the (child, family, parent) advisory lock.
#
# A single-session SQL test cannot show this: it only proves the read-then-insert
# logic. Here session A opens the request and holds the transaction (and thus
# pg_advisory_xact_lock) for ~4 s; session B calls the same triple ~0.7 s later
# and can only return after A commits. If B did not block it would either create
# a second row or return before A's row is visible.
#
# Run from the repository root:
#   bash supabase/tests/run_pairing_invite_race.sh
#   KEEP_DB=1 bash supabase/tests/run_pairing_invite_race.sh   # keep the DB
#   PGHOST=127.0.0.1 PGPORT=55432 PGUSER=postgres bash supabase/tests/run_pairing_invite_race.sh
#
# Connection defaults match the local PostgreSQL 16.9 cluster under .tools.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="$REPO_ROOT/.tools/pgsql16/pgsql/bin:$PATH"

PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-55432}"
PGUSER="${PGUSER:-postgres}"
export PGHOST PGPORT PGUSER

STAMP="$(date +%Y%m%d%H%M%S)"
DB="parentcontrol_race_${STAMP}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/pairing_race.XXXXXX")"
A_PID=""
A_JSON=""
B_JSON=""
A_ID=""
B_ID=""
A_CREATED=""
B_CREATED=""
ELAPSED_MS=""
LIVE_ROWS=""
TOTAL_ROWS=""

# Disposable rows, distinct from every fixture UUID.
CHILD_ID="bb000000-0000-4000-8000-0000000000c1"
FAMILY_ID="bb000000-0000-4000-8000-0000000000f1"
PARENT_ID="bb000000-0000-4000-8000-0000000000a1"
HASH_A="$(printf '%064d' 1)"
HASH_B="$(printf '%064d' 2)"

print_evidence() {
  cat <<EOF
=== BUG-033 advisory-lock race evidence ===
database          : ${DB}
session A         : created=${A_CREATED:-<none>} request=${A_ID:-<none>}
session B         : created=${B_CREATED:-<none>} request=${B_ID:-<none>} waited=${ELAPSED_MS:-<none>} ms
live requests     : ${LIVE_ROWS:-<none>}
rows for triple   : ${TOTAL_ROWS:-<none>}
EOF
}

fail() {
  echo "RACE FAILED: $*" >&2
  print_evidence
  if [ -s "$WORK/setup.log" ]; then
    echo "--- setup log (tail) ---" >&2
    tail -n 15 "$WORK/setup.log" >&2 || true
  fi
  if [ -s "$WORK/a.err" ]; then
    echo "--- session A stderr ---" >&2
    tail -n 10 "$WORK/a.err" >&2 || true
  fi
  if [ -s "$WORK/b.err" ]; then
    echo "--- session B stderr ---" >&2
    tail -n 10 "$WORK/b.err" >&2 || true
  fi
  exit 1
}

cleanup() {
  if [ -n "$A_PID" ]; then
    kill "$A_PID" 2>/dev/null || true
    wait "$A_PID" 2>/dev/null || true
  fi
  if [ "${KEEP_DB:-0}" = "1" ]; then
    echo "KEEP_DB=1: left disposable database ${DB} in place"
  else
    dropdb --if-exists --force "$DB" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

: >"$WORK/setup.log"
: >"$WORK/a.err"
: >"$WORK/b.err"

echo "race: ${PGUSER}@${PGHOST}:${PGPORT} db=${DB}"

createdb "$DB" >>"$WORK/setup.log" 2>&1 \
  || fail "could not create database ${DB}"

run_file() {
  local label="$1"
  local file="$2"
  psql -X -q -v ON_ERROR_STOP=1 -f "$file" -d "$DB" >>"$WORK/setup.log" 2>&1 \
    || fail "${label} failed (${file})"
}

run_file "auth stub" "$REPO_ROOT/supabase/tests/00_auth_stub.sql"
run_file "realtime stub" "$REPO_ROOT/supabase/tests/05_realtime_stub.sql"

shopt -s nullglob
migrations=("$REPO_ROOT"/supabase/migrations/*.sql)
shopt -u nullglob
[ "${#migrations[@]}" -gt 0 ] || fail "no migrations found"
# The glob sorts by filename, i.e. timestamp order.
for migration in "${migrations[@]}"; do
  run_file "migration $(basename "$migration")" "$migration"
done

run_file "fixtures" "$REPO_ROOT/supabase/tests/20_fixtures.sql"

psql -X -q -v ON_ERROR_STOP=1 -d "$DB" >>"$WORK/setup.log" 2>&1 <<SQL \
  || fail "race fixture rows failed"
insert into auth.users (id, email, email_confirmed_at) values
  ('${PARENT_ID}', 'race-parent@example.test', now()),
  ('${CHILD_ID}', 'race-child@example.test', now());
update public.profiles set role = 'parent' where id = '${PARENT_ID}';
update public.profiles set role = 'child' where id = '${CHILD_ID}';
insert into public.families (id, name, owner_id)
  values ('${FAMILY_ID}', 'Race Family', '${PARENT_ID}');
SQL

# ---------------------------------------------------------------------------
# Session A: hold the advisory lock inside one open transaction for ~4 s.
# ---------------------------------------------------------------------------
psql -X -q -A -t -v ON_ERROR_STOP=1 -d "$DB" \
  -c "begin;" \
  -c "select private.create_pairing_invite('${CHILD_ID}', '${FAMILY_ID}', '${PARENT_ID}', '${HASH_A}', now() + interval '10 minutes');" \
  -c "select pg_sleep(4);" \
  -c "commit;" \
  >"$WORK/a.out" 2>>"$WORK/a.err" &
A_PID=$!

# ---------------------------------------------------------------------------
# Session B: same triple, ~0.7 s later. It must queue on pg_advisory_xact_lock.
# ---------------------------------------------------------------------------
sleep 0.7
T0="$(date +%s%3N)"
psql -X -q -A -t -v ON_ERROR_STOP=1 -d "$DB" \
  -c "select private.create_pairing_invite('${CHILD_ID}', '${FAMILY_ID}', '${PARENT_ID}', '${HASH_B}', now() + interval '10 minutes');" \
  >"$WORK/b.out" 2>>"$WORK/b.err" \
  || fail "session B failed"
T1="$(date +%s%3N)"
ELAPSED_MS=$((T1 - T0))

wait "$A_PID" || fail "session A failed"
A_PID=""

json_line() {
  grep -m1 '^{' "$1" 2>/dev/null || true
}

A_JSON="$(json_line "$WORK/a.out")"
B_JSON="$(json_line "$WORK/b.out")"
[ -n "$A_JSON" ] || fail "session A produced no JSON result"
[ -n "$B_JSON" ] || fail "session B produced no JSON result"

A_CREATED="$(printf '%s' "$A_JSON" | sed -n 's/.*"created": \(true\|false\).*/\1/p')"
B_CREATED="$(printf '%s' "$B_JSON" | sed -n 's/.*"created": \(true\|false\).*/\1/p')"
A_ID="$(printf '%s' "$A_JSON" | grep -oE '"id": "[0-9a-f-]{36}"' | head -n1 | cut -d'"' -f4)"
B_ID="$(printf '%s' "$B_JSON" | grep -oE '"id": "[0-9a-f-]{36}"' | head -n1 | cut -d'"' -f4)"

LIVE_ROWS="$(psql -X -A -t -v ON_ERROR_STOP=1 -d "$DB" -c \
  "select count(*) from public.pairing_requests
    where child_user_id = '${CHILD_ID}'
      and family_id = '${FAMILY_ID}'
      and parent_user_id = '${PARENT_ID}'
      and status = 'pending_child'
      and expires_at > now();" 2>>"$WORK/b.err")" \
  || fail "could not count live requests"
TOTAL_ROWS="$(psql -X -A -t -v ON_ERROR_STOP=1 -d "$DB" -c \
  "select count(*) from public.pairing_requests
    where child_user_id = '${CHILD_ID}'
      and family_id = '${FAMILY_ID}'
      and parent_user_id = '${PARENT_ID}';" 2>>"$WORK/b.err")" \
  || fail "could not count request rows"

[ "$ELAPSED_MS" -ge 2500 ] \
  || fail "session B returned after ${ELAPSED_MS} ms (<2500 ms): it did not block on the advisory lock"
[ "$A_CREATED" = "true" ] || fail "session A must be created=true, got ${A_CREATED:-<none>}"
[ "$B_CREATED" = "false" ] || fail "session B must be created=false, got ${B_CREATED:-<none>}"
[ -n "$A_ID" ] && [ -n "$B_ID" ] || fail "could not parse a request id from both sessions"
[ "$A_ID" = "$B_ID" ] || fail "sessions returned different request ids (${A_ID} vs ${B_ID})"
[ "$LIVE_ROWS" = "1" ] || fail "expected exactly 1 live request, got ${LIVE_ROWS}"
[ "$TOTAL_ROWS" = "1" ] || fail "expected exactly 1 request row for the triple, got ${TOTAL_ROWS}"

print_evidence
echo "result            : PASS (session B blocked on the advisory lock and joined A's request)"
