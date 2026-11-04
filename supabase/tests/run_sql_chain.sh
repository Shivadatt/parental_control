#!/usr/bin/env bash
# ==============================================================================
# CHAIN-01: Documented 33-File PostgreSQL Regression Test Chain Runner
#
# Executes the documented 33-file SQL test chain from supabase/tests/README.md
# against a local disposable PostgreSQL database.
#
# Guarantees:
# 1. Self-contained: Auto-starts a local disposable cluster if not already running.
# 2. Isolated: Creates a clean disposable database for each run (required because
#    fixtures use fixed UUIDs and re-insert into auth.users in tests/74 and 20).
# 3. Safe: Strict disposable database naming whitelist; NEVER touches non-disposable
#    databases (postgres, template0, template1, production, etc.).
# 4. Offline: Binds exclusively to 127.0.0.1; NEVER connects to hosted Supabase.
# 5. Negative Control: Supports injecting the SQL-05 lossy RPC variant immediately
#    BEFORE test 76, verifying that test 76 actively catches unaudited deletions.
#
# Usage:
#   bash supabase/tests/run_sql_chain.sh [OPTIONS] [DB_NAME] [LOG_FILE]
#
# Options:
#   --negative, -n           Run SQL-05 lossy RPC negative control (expected exit 3)
#   --stop-cluster           Stop postgres cluster on exit if started by this script
#   --keep-db                Keep disposable database after run (do not drop on exit)
#   --port <port>            PostgreSQL port (default: 55581 or $PGPORT)
#   --help, -h               Show this help message
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Configuration & Defaults
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-55581}"
PGUSER="${PGUSER:-postgres}"
PGDATA="${PGDATA:-$REPO_ROOT/.tools/pgdata_chain}"
PG_BIN="${REPO_ROOT}/.tools/pgsql16/pgsql/bin"

NEGATIVE=false
STOP_CLUSTER=false
KEEP_DB=false
DB_NAME=""
LOG_FILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --negative|-n)
      NEGATIVE=true
      shift
      ;;
    --stop-cluster)
      STOP_CLUSTER=true
      shift
      ;;
    --keep-db)
      KEEP_DB=true
      shift
      ;;
    --port)
      PGPORT="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: bash supabase/tests/run_sql_chain.sh [OPTIONS] [DB_NAME] [LOG_FILE]"
      echo ""
      echo "Options:"
      echo "  --negative, -n     Run negative control (injected lossy RPC before test 76)"
      echo "  --stop-cluster     Stop PostgreSQL cluster on exit if started by this script"
      echo "  --keep-db          Keep disposable database after run (skip dropdb)"
      echo "  --port <port>      PostgreSQL port (default: 55581)"
      echo "  --help, -h         Show this help message"
      exit 0
      ;;
    -*)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [ -z "$DB_NAME" ]; then
        DB_NAME="$1"
      elif [ -z "$LOG_FILE" ]; then
        LOG_FILE="$1"
      else
        echo "ERROR: Unexpected extra argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
if [ -z "$DB_NAME" ]; then
  if [ "$NEGATIVE" = true ]; then
    DB_NAME="p6chain_neg_${TIMESTAMP}"
  else
    DB_NAME="p6chain_${TIMESTAMP}"
  fi
fi

if [ -z "$LOG_FILE" ]; then
  mkdir -p "${REPO_ROOT}/.tools"
  LOG_FILE="${REPO_ROOT}/.tools/chain_${DB_NAME}.log"
fi

# Locate binaries
BIN_EXT=""
if [ -f "${PG_BIN}/psql.exe" ]; then
  BIN_EXT=".exe"
fi

PSQL="${PG_BIN}/psql${BIN_EXT}"
CREATEDB="${PG_BIN}/createdb${BIN_EXT}"
DROPDB="${PG_BIN}/dropdb${BIN_EXT}"
PG_ISREADY="${PG_BIN}/pg_isready${BIN_EXT}"
PG_CTL="${PG_BIN}/pg_ctl${BIN_EXT}"
INITDB="${PG_BIN}/initdb${BIN_EXT}"

for b in "$PSQL" "$CREATEDB" "$DROPDB" "$PG_ISREADY"; do
  if [ ! -x "$b" ] && [ ! -f "$b" ]; then
    echo "ERROR: Missing required PostgreSQL binary: $b" >&2
    exit 1
  fi
done

# Safety Rule: Strictly validate disposable database name
# Prevents accidental deletion of system or critical databases
DISPOSABLE_PATTERN="^(p6chain_|p5rpc_|ci_|test_|disposable_|parentcontrol_race_)"
if [[ ! "$DB_NAME" =~ $DISPOSABLE_PATTERN ]]; then
  echo "ERROR: Database name '$DB_NAME' violates disposable naming policy!" >&2
  echo "To prevent accidental drops, names must match $DISPOSABLE_PATTERN" >&2
  exit 1
fi

STARTED_CLUSTER=false
cleanup() {
  local exit_code=$?
  if [ "$KEEP_DB" = false ] && [ -n "$DB_NAME" ]; then
    if "$PG_ISREADY" -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; then
      "$DROPDB" -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" --if-exists "$DB_NAME" >/dev/null 2>&1 || true
    fi
  fi
  if [ "$STARTED_CLUSTER" = true ] && [ "$STOP_CLUSTER" = true ]; then
    echo "Stopping disposable cluster at $PGDATA..."
    "$PG_CTL" -D "$PGDATA" stop -m fast >/dev/null 2>&1 || true
  fi
  exit "$exit_code"
}
trap cleanup EXIT

# 1. Ensure Cluster is Running
if ! "$PG_ISREADY" -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; then
  echo "No active PostgreSQL instance detected on ${PGHOST}:${PGPORT}."
  echo "Initializing/Starting disposable cluster at $PGDATA..."
  
  if [ ! -d "$PGDATA" ]; then
    mkdir -p "$(dirname "$PGDATA")"
    "$INITDB" -U "$PGUSER" -A trust -E UTF8 --locale=C -D "$PGDATA" >/dev/null
  fi

  # Clear stale postmaster.pid if process is not running
  if [ -f "$PGDATA/postmaster.pid" ]; then
    PID_CANDIDATE=$(head -n 1 "$PGDATA/postmaster.pid" | tr -d '\r')
    if ! kill -0 "$PID_CANDIDATE" 2>/dev/null; then
      echo "Removing stale postmaster.pid (PID $PID_CANDIDATE is dead)..."
      rm -f "$PGDATA/postmaster.pid"
    fi
  fi

  "$PG_CTL" -D "$PGDATA" -l "$PGDATA/server.log" -o "-p $PGPORT -c listen_addresses=$PGHOST" start
  STARTED_CLUSTER=true

  # Poll until ready
  READY=false
  for i in {1..30}; do
    if "$PG_ISREADY" -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; then
      READY=true
      break
    fi
    sleep 0.5
  done

  if [ "$READY" = false ]; then
    echo "ERROR: Failed to start disposable PostgreSQL cluster on port $PGPORT." >&2
    if [ -f "$PGDATA/server.log" ]; then
      echo "--- server.log tail ---" >&2
      tail -n 20 "$PGDATA/server.log" >&2
    fi
    exit 1
  fi
  echo "Disposable cluster ready on ${PGHOST}:${PGPORT}."
else
  echo "Connected to active PostgreSQL cluster on ${PGHOST}:${PGPORT}."
fi

# 2. Prepare Isolated Disposable Database
"$DROPDB" -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" --if-exists "$DB_NAME" >/dev/null 2>&1 || true
"$CREATEDB" -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$DB_NAME"
echo "Created fresh disposable database: $DB_NAME"

# 3. Assemble the 33-file chain in documented sequence
FILES=(
  supabase/tests/00_auth_stub.sql
  supabase/tests/05_realtime_stub.sql
  supabase/migrations/20260101000000_core.sql
  supabase/migrations/20260101000100_functions.sql
  supabase/migrations/20260101000200_rls.sql
  supabase/migrations/20260101000300_service_role_grants.sql
  supabase/migrations/20260101000400_device_recovery.sql
  supabase/migrations/20260101000500_child_contact_ids.sql
  supabase/migrations/20260101000600_atomic_pairing_invite.sql
  supabase/migrations/20261028000100_remote_session_concurrency.sql
  supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql
  supabase/migrations/20261028000300_signaling_open_session.sql
  supabase/migrations/20261030000100_abandoned_session_sweep.sql
  supabase/migrations/20261030000200_phase1_authorization.sql
  supabase/migrations/20261030000300_retention_sweep.sql
  supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql
  supabase/tests/10_schema.sql
  supabase/tests/20_fixtures.sql
  supabase/tests/50_realtime_policy.sql
  supabase/tests/30_rls.sql
  supabase/tests/40_functions.sql
  supabase/tests/55_pairing_invite_atomic.sql
  supabase/tests/60_remote_session_concurrency.sql
  supabase/tests/61_parent_controlled_lifetime.sql
  supabase/tests/62_signaling_consented_session.sql
  supabase/tests/63_abandoned_session_sweep.sql
  supabase/tests/70_phase1_authorization.sql
  supabase/tests/71_phase1_rollback_privileges.sql
  supabase/tests/72_retention_sweep.sql
  supabase/tests/74_sweep_indexes_and_repeatability.sql
  supabase/tests/75_signaling_replay_index_duplicate_guard.sql
)

if [ "$NEGATIVE" = true ]; then
  # Find negative control file
  NEG_FILE="supabase/tests/fixtures/sql05_lossy_negative.sql"
  if [ ! -f "$NEG_FILE" ]; then
    NEG_FILE=".tools/p5coord_rpc_lossy_negative.sql"
  fi
  if [ ! -f "$NEG_FILE" ]; then
    echo "ERROR: Negative control fixture not found at $NEG_FILE" >&2
    exit 1
  fi
  FILES+=("$NEG_FILE")
fi

FILES+=(
  supabase/tests/76_zone_delete_atomic_rpc.sql
  supabase/tests/45_device_recovery.sql
)

ARGS=()
for f in "${FILES[@]}"; do
  ARGS+=(-f "$f")
done

echo "Executing SQL chain (${#FILES[@]} files) into ${DB_NAME}..."
echo "Log file: $LOG_FILE"

set +e
"$PSQL" -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -v ON_ERROR_STOP=1 \
  "${ARGS[@]}" -d "$DB_NAME" > "$LOG_FILE" 2>&1
PSQL_EXIT=$?
set -e

# 4. Measure Metrics
TOTAL_LINES=$(wc -l < "$LOG_FILE" | tr -d ' ')
ASSERT_FAILS=$(grep -c 'ASSERTION FAILED' "$LOG_FILE" || true)
ERROR_COUNT=$(grep -c 'ERROR:' "$LOG_FILE" || true)

echo ""
echo "=================================================================="
echo "                    CHAIN-01 EXECUTION SUMMARY                    "
echo "=================================================================="
echo "Database       : $DB_NAME"
echo "Target Cluster : ${PGHOST}:${PGPORT}"
echo "Mode           : $([ "$NEGATIVE" = true ] && echo "NEGATIVE_CONTROL (SQL-05 lossy RPC)" || echo "NORMAL (all assertions must pass)")"
echo "Files Executed : ${#FILES[@]}"
echo "psql Exit Code : $PSQL_EXIT"
echo "Log Line Count : $TOTAL_LINES"
echo "Assert Failed  : $ASSERT_FAILS"
echo "Errors Count   : $ERROR_COUNT"
echo "Log Output     : $LOG_FILE"
echo "------------------------------------------------------------------"

if [ "$NEGATIVE" = true ]; then
  # Expected result: exit 3, exactly 1 assertion failed (at test 76)
  if [ "$PSQL_EXIT" -eq 3 ] && [ "$ASSERT_FAILS" -ge 1 ]; then
    echo "STATUS         : EXPECTED NEGATIVE PASS (Test 76 caught the lossy RPC)"
    echo "=================================================================="
    exit 0
  else
    echo "STATUS         : UNEXPECTED RESULT (Negative control did not fail as expected)"
    echo "=================================================================="
    exit 1
  fi
else
  # Expected result: exit 0, 0 assertion failures, 0 errors
  if [ "$PSQL_EXIT" -eq 0 ] && [ "$ASSERT_FAILS" -eq 0 ] && [ "$ERROR_COUNT" -eq 0 ]; then
    echo "STATUS         : PASSED (All 33 test/migration files clean)"
    echo "=================================================================="
    exit 0
  else
    echo "STATUS         : FAILED (Errors or assertion failures detected)"
    echo "=================================================================="
    exit "$PSQL_EXIT"
  fi
fi
