#!/usr/bin/env bash
# R07: genuine two-session proof that request_remote_session() serialises
# concurrent callers per child device.
#
# A single-session SQL test (60_remote_session_concurrency.sql) only proves the
# read-then-insert logic. Here session A opens a transaction, inserts a
# 'requested' session for one device and holds the transaction (and therefore
# pg_advisory_xact_lock) for ~4 s. Session B calls the same RPC for the same
# device ~0.7 s later: it can only proceed after A commits, and must then be
# rejected with session_in_progress instead of inserting a second open session.
#
# Run from the repository root:
#   bash supabase/tests/run_remote_session_race.sh
#   KEEP_DB=1 bash supabase/tests/run_remote_session_race.sh   # keep the DB
#   PGHOST=127.0.0.1 PGPORT=55432 PGUSER=postgres bash supabase/tests/run_remote_session_race.sh
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
DB="parentcontrol_session_race_${STAMP}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/session_race.XXXXXX")"
A_PID=""

# Fixture rows (supabase/tests/20_fixtures.sql): active device of family 1 with
# no pre-existing remote_session, and that family's parent.
DEVICE_ID="d0000000-0000-4000-8000-000000000007"
PARENT_ID="11111111-1111-4111-8111-111111111111"

ELAPSED_MS=""
B_ERR=""
A_ID=""
OPEN_ROWS=""
TOTAL_ROWS=""
OPEN_DEVICES=""

print_evidence() {
  cat <<EOF
=== R07 remote-session concurrency race evidence ===
database          : ${DB}
device            : ${DEVICE_ID}
session A         : request=${A_ID:-<none>} (held the lock ~4 s)
session B         : waited=${ELAPSED_MS:-<none>} ms, error=${B_ERR:-<none>}
open sessions     : ${OPEN_ROWS:-<none>} (for this device)
rows for device   : ${TOTAL_ROWS:-<none>}
open devices      : ${OPEN_DEVICES:-<none>} (whole table)
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

# ---------------------------------------------------------------------------
# Session A: hold the advisory lock inside one open transaction for ~4 s.
# ---------------------------------------------------------------------------
psql -X -q -A -t -v ON_ERROR_STOP=1 -d "$DB" \
  -c "begin;" \
  -c "select (public.request_remote_session('${DEVICE_ID}', '${PARENT_ID}', 'audio')).id;" \
  -c "select pg_sleep(4);" \
  -c "commit;" \
  >"$WORK/a.out" 2>>"$WORK/a.err" &
A_PID=$!

# ---------------------------------------------------------------------------
# Session B: same device, ~0.7 s later. It must queue on pg_advisory_xact_lock
# and then be rejected because A's session is open.
# ---------------------------------------------------------------------------
sleep 0.7
T0="$(date +%s%3N)"
psql -X -q -A -t -v ON_ERROR_STOP=1 -d "$DB" \
  -c "select (public.request_remote_session('${DEVICE_ID}', '${PARENT_ID}', 'audio')).id;" \
  >"$WORK/b.out" 2>>"$WORK/b.err" || true
T1="$(date +%s%3N)"
ELAPSED_MS=$((T1 - T0))

wait "$A_PID" || fail "session A failed"
A_PID=""

A_ID="$(grep -m1 -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$WORK/a.out" | head -n1 || true)"
B_ERR="$(grep -m1 -oE 'session_in_progress' "$WORK/b.err" || true)"

OPEN_ROWS="$(psql -X -A -t -v ON_ERROR_STOP=1 -d "$DB" -c \
  "select count(*) from public.remote_sessions
    where device_id = '${DEVICE_ID}'
      and status in ('requested', 'accepted', 'active');" 2>>"$WORK/b.err")" \
  || fail "could not count open sessions"
TOTAL_ROWS="$(psql -X -A -t -v ON_ERROR_STOP=1 -d "$DB" -c \
  "select count(*) from public.remote_sessions
    where device_id = '${DEVICE_ID}';" 2>>"$WORK/b.err")" \
  || fail "could not count session rows"
OPEN_DEVICES="$(psql -X -A -t -v ON_ERROR_STOP=1 -d "$DB" -c \
  "select count(*) from (
     select device_id from public.remote_sessions
      where status in ('requested', 'accepted', 'active')
      group by device_id having count(*) > 1
   ) d;" 2>>"$WORK/b.err")" \
  || fail "could not scan for devices with multiple open sessions"

[ -n "$A_ID" ] || fail "session A produced no session id"
[ "$ELAPSED_MS" -ge 2500 ] \
  || fail "session B returned after ${ELAPSED_MS} ms (<2500 ms): it did not block on the advisory lock"
[ "$B_ERR" = "session_in_progress" ] \
  || fail "session B must be rejected with session_in_progress, got '${B_ERR:-<none>}'"
[ "$OPEN_ROWS" = "1" ] || fail "expected exactly 1 open session, got ${OPEN_ROWS}"
[ "$TOTAL_ROWS" = "1" ] || fail "expected exactly 1 session row for the device, got ${TOTAL_ROWS}"
[ "$OPEN_DEVICES" = "0" ] \
  || fail "found ${OPEN_DEVICES} device(s) with more than one open session"

print_evidence
echo "result            : PASS (session B blocked on the lock, then got session_in_progress; one open session)"
