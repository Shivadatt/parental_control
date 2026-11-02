# Phase 3 / SQL-01 — rollback security of `20261030000200_phase1_authorization.sql`

Workstream P3-A1. Every number, ACL string and error message below was captured from a
disposable local cluster, not written from memory. Nothing in this file was applied to a
hosted database, and the Supabase CLI was never invoked.

## 1. What was inspected and what was found

`supabase/migrations/20261030000200_phase1_authorization.sql` closes four Phase 1
authorization exposures. Its `-- ROLLBACK` block was prose-only, and the statements it
listed were the literal inverse of the forward block. Applied as written, the rollback
**reopened the exposure it was rolling back**:

| Object | After the forward block | After the ORIGINAL rollback block |
|---|---|---|
| `private.remote_session_transition_guard()` | `proacl={postgres=X/postgres}` → PUBLIC has no EXECUTE | `proacl={postgres=X/postgres,=X/postgres}` → `PUBLIC=EXECUTE` restored |
| `private.request_device_recovery(uuid, uuid)` | same → `PUBLIC-none` | `PUBLIC=EXECUTE` restored |
| `public.safe_zones` table ACL | `authenticated=rd` → `authenticated=r` (DELETE revoked) | `authenticated=rd` → DELETE grant restored |
| `safe_zones_delete_parent` policy | ABSENT | `PRESENT … using=private.is_family_parent(family_id)` |
| `webrtc_signals_session_sequence_uniq` | PRESENT | ABSENT (signal replay protection dropped) |

The last two rows matter more than the first two: the Phase 1 contract removed client
`DELETE` on Safe Zones precisely because a policy using `is_family_parent()` was being
bypassed by the direct table grant, and dropping the unique index silently removes
`sequence` replay protection on `webrtc_signals`.

Captured evidence (raw `pg_proc.proacl` / `pg_class.relacl` / `pg_policies` rows, one line
per phase × object × role × privilege — not prose):

```
.tools/p3a-matrix-BEFORE.txt               (48 rows)
.tools/p3a-matrix-AFTER_FORWARD.txt        (50 rows)
.tools/p3a-matrix-AFTER_ROLLBACK_ORIG.txt  (48 rows)
.tools/p3a-matrix-AFTER_ROLLBACK_FIXED.txt (47 rows)
.tools/p3a-matrix-AFTER_ROLLBACK_SEDEXTRACT.txt (47 rows)
```

`.tools/p3a_matrix_capture.sql` generates them; the `phase` label is passed with
`-v phase=`. The 50 → 47 difference is `private.is_parent_of_family(uuid, uuid)`: the
forward state records 4 role rows, a dropped function records 1 `ABSENT_OBJECT` row.

## 2. Environment and reproduction

Disposable cluster, trust auth, repo-local binaries — the workstation's own Postgres and
the hosted project are untouched.

```bash
# cluster (port 55441, data dir is gitignored)
export PGD=/d/parentcontrol_app/.tools/pgsql16/pgsql/bin
$PGD/initdb -D /d/parentcontrol_app/.tools/pgdata_p3a -U postgres --auth=trust \
  -o .tools/p3a-initdb.log
$PGD/pg_ctl -D /d/parentcontrol_app/.tools/pgdata_p3a -o '-p 55441 -c listen_addresses=127.0.0.1' \
  -l .tools/p3a-pg.log start
export DATABASE_URL='postgresql://postgres@127.0.0.1:55441/<db>'

# fresh database per state (the suite carries fixed-UUID fixtures; it is not re-runnable)
$PGD/createdb -h 127.0.0.1 -p 55441 -T template0 <db>
```

The five captures, in order, against database `p3a_full1`/`p3a_full2`:

```bash
# 1 baseline = every migration up to and including 20261028000300, no 000200
psql -v ON_ERROR_STOP=1 -v phase=BEFORE_000200 -f .tools/p3a_matrix_capture.sql \
     -o .tools/p3a-matrix-BEFORE.txt          "$DATABASE_URL"   # .tools/p3a-m1-baseline.log
# 2 apply 20261030000200 → AFTER_FORWARD
# 3 run .tools/p3a_rollback_original.sql → AFTER_ROLLBACK_ORIG   (the reopen, proven)
# 4 re-apply forward, run .tools/p3a_rollback_fixed.sql → AFTER_ROLLBACK_FIXED
# 5 re-apply forward, run the R1 text extracted by the documented sed commands
#   (.tools/p3a_r1_extracted.sql) + R2 → AFTER_ROLLBACK_SEDEXTRACT
```

`AFTER_ROLLBACK_FIXED` and `AFTER_ROLLBACK_SEDEXTRACT` are byte-comparable in the four
sensitive rows: the `sed` extraction quoted in the migration header actually produces the
bodies that were proven, so the documented R1 recipe is executable rather than
aspirational.

## 3. The rollback as shipped (steps R1–R4 in the migration header)

- **R1 — restore the four public wrapper bodies** to their pre-Phase 1 definitions before
  anything is dropped, from the repository source:
  `sed -n '106,181p' supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql`
  and `sed -n '721,733p;748,759p;761,771p' supabase/migrations/20260101000100_functions.sql`.
  These four RPCs are the only clients of the new helper; restoring them first is what
  makes step R2 safe.
- **R2 — guarded drop** of `private.is_parent_of_family(uuid, uuid)`. The guard reads the
  catalog for *other* live callers and halts rather than leaving them broken:
  ```
  ERROR:  rollback halted: apply_policy_version(uuid,jsonb,uuid,text),
          request_remote_session(uuid,uuid,text), revoke_device(uuid,uuid),
          unlink_child(uuid,uuid,uuid) still reference private.is_parent_of_family(uuid, uuid);
          run step R1 first, otherwise these RPCs fail at runtime with 42883
  ```
  Captured in `.tools/p3a-m3-guard.log` — this is the guard actually firing, on a DB where
  R1 had deliberately been skipped. Re-running it after R1 emits
  `NOTICE: rollback: private.is_parent_of_family(uuid, uuid) dropped, no referencing
  function remains` (`.tools/p3a-m4-r2.log`). Without the guard, dropping the helper first
  is the failure mode that leaves four production RPCs erroring at call time.
- **R3 — the five unsafe statements are listed but NOT RUN.** They are exactly the
  `grant execute … to public` / `grant delete on safe_zones to authenticated` /
  `create policy safe_zones_delete_parent …` / `drop index webrtc_signals_session_sequence_uniq`
  lines that the ORIGINAL block executed. A rollback of this migration is now a
  *de-hardening* operation and requires an explicit owner decision; it is no longer
  something an operator can perform by pasting the trailing comment.
- **R4 — verification query** re-reading `pg_proc.proacl`, `pg_class.relacl` and
  `pg_policies`, the same catalog views the capture script uses, so the operator checks
  the same source of truth as the tests.

## 4. Reversibility (what a rollback genuinely cannot undo)

Recorded because it changes the owner's decision, not just the operator's script:

- Function **bodies** are unrecoverable from the database after `create or replace` —
  the pre-Phase 1 text survives only in the migration files, hence R1 reads them from
  source. A repository without those files cannot roll back this migration correctly.
- The migration is **schema-only**; it deletes no rows, so no data restore is needed.
- **Asymmetric residue:** the forward block revokes EXECUTE from `service_role` on the two
  private functions, and R3 (not run by default) does not restore it. Post-"safe rollback"
  the ACLs stay at the forward state — *stricter* than pre-Phase 1. That divergence is
  deliberate: a rollback that silently re-widens access is the defect SQL-01 was opened
  for. Anyone who needs the original pre-Phase 1 grants must run R3 explicitly and own
  the consequence.

## 5. Regression coverage

Five sections, four snapshots. The snapshot table `p3a_snap` is loaded from the temp view
`p3a_capture` (one capture definition, reused at every checkpoint; `p3a_phase` labels the
row), reading `pg_proc.proacl`, `pg_class.relacl` and `pg_policies`:

1. **`1_forward`** — helper exists, PUBLIC holds no EXECUTE on either private function,
   `authenticated` holds no DELETE on `safe_zones`, `safe_zones_delete_parent` absent, the
   `(session_id, sequence)` unique index present, helper service-role-only, and exactly the
   four wrappers reference it.
2. **`2a_after_unsafe_rollback` (NEGATIVE CONTROL)** — the original five statements are
   executed inside a transaction, and *while still inside it* the test asserts the reopen
   is real: `has_function_privilege` / `has_table_privilege` must report **5 leaked cells**
   back, `safe_zones_delete_parent` must exist, `safe_zones` must be back to four policies.
   Then `ROLLBACK`, and a symmetric-difference query asserts the post-rollback snapshot
   equals the forward snapshot with **zero privilege delta**. So the exposure is proven
   observable and discarded, and the test file itself is left non-destructive.
3. **GUARD** — step R2 alone, with the Phase 1 bodies still in place, must raise; asserted
   as SQLSTATE `P0001` plus the message substring `rollback halted`, not as a stack trace.
4. **`3_rollback`** — R1+R2 as shipped: helper gone, grants *not* re-widened, the index
   retained, all four wrappers still `SECURITY DEFINER` with a pinned `search_path`, and
   `unlink_child` reaches `private.unlink_child` again (no `42883`).
5. **`4_reforward`** — re-applying `000200` must reproduce the checkpoint-1 snapshot
   (asserted by delta against `1_forward`), which is what lets the chain continue to
   `72_retention_sweep.sql`.

Two defects found in the test itself during this phase, both fixed:

- A `'<sig>'::regprocedure` **literal inside a view** records a `pg_depend` edge and pins
  the function, so checkpoint 3 failed with
  `cannot drop function private.is_parent_of_family(uuid,uuid) because other objects
  depend on it … view p3a_capture depends on it` (`.tools/p3a-it71.log`). Replaced with a
  name/namespace exclusion; the comment in the file records why the regprocedure cast is
  unsafe in a view.
- Nothing else. The `missing FROM-clause entry for table "ph"` reported at 15:23 was a
  stale log against a file later edited at 15:54; re-running produced no such error, so it
  was not "fixed".

## 6. Chain verification (observed, not expected)

`supabase/tests/README.md` now lists 30 `-f` files (2 stubs + 13 migrations + 15 test
files); `71_…` runs after `70_phase1_authorization.sql` and before `72_retention_sweep.sql`
because it rolls the authorization migration back and re-applies it, so it must leave the
database in the forward state.

Final authoritative run on fresh database `p3a_final2`
(`.tools/p3a-final2-chain.log`): **`psql EXIT=0`**, 0 `ASSERTION FAILED`, 19 public tables,
and these banners in order — CONCURRENCY, PARENT-CONTROLLED LIFETIME, CONSENTED-SESSION
SIGNALING, ABANDONED SESSION SWEEP, PHASE 1 AUTHORIZATION, **PHASE 1 ROLLBACK PRIVILEGE**,
**SWEEP INDEX AND REPEATABILITY**.

## 7. Not proven here / residual risk

- Real Supabase grants the hosted project may carry beyond these migrations (e.g. a
  dashboard "make executable to public" click) are outside a local build. The dashboard
  read-only inspection recorded separately is the only hosted observation, and it is
  point-in-time.
- `pg_dump --schema-only` of a *hosted* database would be the definitive pre-Phase 1 body
  record; not run, because it needs hosted credentials and is a hosted operation.
- The `UNSAFE-PATH` checkpoint executes then rolls back within one transaction. It proves
  the statements *do* what the original comment said; it does not prove how a partially
  applied rollback file would behave in a client that autocommits per statement — which is
  exactly why the unsafe statements were moved behind an owner decision instead of being
  left in a pasteable block.
