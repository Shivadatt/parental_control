# P4-D — PERF-01: retention-sweep batch shape, equivalence measured (nothing adopted)

Phase: 4 · Workstream: D (coordinator-completed; the delegated agent died mid-run)
Executed: 2026-11-03 · Verdict: **PASS (SCOPED) — equivalence demonstrated, adoption STOPPED (owner decision)**
Rule honoured: brief §6 "Do not adopt a faster query if it changes batch semantics or correctness cannot be demonstrated."

---

## 1. The exact question Phase 3 left open

`_work/p3-sql-performance.md:215` closed with: *"The `webrtc_signals` target-side Seq Scan is
characterised, not fixed: no evidence yet that the `= any(array(...))` shape is safe to adopt, only
that it measures faster at these two volumes."* and §2 line 145-147 recorded that the shape was not
adopted **because changing it alters delete ordering** — an assumption, never measured.

Phase 4 measured it. Two shapes, batch = 10 000 (`v_batch := 10000`,
`supabase/migrations/20261030000300_retention_sweep.sql:119-135`):

| arm | statement |
|---|---|
| SHIPPED | `delete from t s using (select id from t where created_at < cut limit 10000) doomed where s.id = doomed.id` |
| ALTERNATIVE | `delete from t s where s.id = any (array(select id from t where created_at < cut limit 10000))` |

## 2. Method (and why the earlier draft of the probe was wrong)

My first probe drafted `BEGIN … DELETE … ROLLBACK` per arm and captured the deleted ids into a
temp table. That cannot work and is discarded, not merely inconvenient:

- `create temp table` inside the same transaction is destroyed by the `ROLLBACK` that protects the
  dataset — the capture vanishes with the delete;
- a rolled-back `EXPLAIN ANALYZE DELETE` still leaves dead tuples, so the second arm would run on a
  physically dirtier relation than the first (Phase 3 hit this and worked around it with
  `vacuum analyze` between arms, `_work/p3-sql-performance.md`);
- both tables key on `id uuid` (`webrtc_signals`, `audit_logs`), not `bigint`, so the draft's
  capture column type was wrong too.

**Executed method** — `.tools/p4d_equiv.sql`, log `.tools/p4d-equiv.log` (318 lines, `psql` exit 0,
zero `ERROR`/`FATAL`; the only notices are `drop table if exists` on first creation):

- `p4d_snapshot(tbl, src)` (`:47-55`) rebuilds one **unlogged copy per arm** from the real table with
  `create unlogged table … as select * from …`, then `index(id)`, `index(created_at)`, `analyze`.
  All arms therefore start from byte-identical relations in identical heap order; the real tables are
  never written.
- Cutoffs are frozen once into psql literals (`:39-40`) — webrtc `2026-10-27 11:21:32.154155+05:30`,
  audit `2025-11-03 11:21:32.157157+05:30` — so no arm sees a moving `now()` boundary. Within one
  sweep pass `now() - interval` is a single constant, so this matches shipped behaviour.
- Each arm deletes for real from **its own copy** and `returning s.id, s.ctid` is captured into
  `p4d_cap(ord serial, tag, id, tid)`; `ord` preserves the executor's delivery order.
- 2 reps per arm per table (4 arms × 2 tables = 8 batches, 80 000 captured rows).

Dataset: `.tools/pgdata_p4d`, port 55461, DB `p4d_perf`, PostgreSQL 16.9, seeded by the dead agent's
scripts (`.tools/p4d_seed.sql`, `.tools/p4d_backlog.sql`) — `webrtc_signals` 140 006 rows / 60 000
backlog (42.86 %), `audit_logs` 200 026 / 25 000 (12.50 %). Torn down after the probe; see §7.

## 3. Observed result — same rows, same order, repeatable

`.tools/p4d-equiv.log:108-118` (per-arm summary) and `:121-126`:

| table | distinct set digests (4 arms) | distinct returning-order digests | rows deleted |
|---|---|---|---|
| `webrtc_signals` | **1** (`e1f191b6…`) | **1** (`2f34ec5b…`) | 10 000 every arm |
| `audit_logs` | **1** (`3cedf66f…`) | **1** (`34c0de5b…`) | 10 000 every arm |

`ctid` visit-order digests match too (`:108-117`, fourth column) — first/last deleted physical
location identical per table (`:155-166`: webrtc `(1269,60)`→`(1429,21)`, audit `(0,26)`→`(3530,3)`).

All 12 pairwise set differences in both directions: **0 / 0** (`:129-146`).

Order was re-checked positionally in `.tools/p4d_equiv_order.sql` (log `:p4d-equiv-order.log`),
because section 7 of the first run compared raw `ord` values across arms and `ord` is one session-wide
serial — shipped holds 1..10 000, alternative 10 001..20 000, so `s.ord = a.ord` could never fire and
the printed `same_position_pairs = 0` was a broken assertion, not a finding. Corrected with
`row_number() over (partition by tag order by ord)` over 8 arm-pairs × 10 000 positions:
**`same_position_pairs = 10000`, `position_mismatches = 0` for every pair, including
SHIPPED↔ALTERNATIVE.** The first and last id of every batch is the same string in all four webrtc
arms and all four audit arms.

Why the order matches is structural, not luck: both shapes select the doomed set with the *same*
inner query, and both then visit the target in tid order — the shipped arm via `Seq Scan`, the
alternative via `Bitmap Heap Scan`, and a bitmap scan delivers blocks in `(block, offset)` order.
That reasoning is recorded as reasoning; the claim rests on the measurement above.

**Batch semantics that are NOT identical (disclosed):** the two shapes touch different amounts of the
table. Fresh-copy plans (`:169-234`, `:237-308`):

| table / arm | plan of the target side | execution | buffers |
|---|---|---|---|
| webrtc SHIPPED | `Hash Join` over `Seq Scan on copy (rows=140006)` | 75.534 ms | hit 13 670, dirtied 191 |
| webrtc ALT | `Bitmap Heap Scan` via `…_id` index, `Heap Blocks: exact=161` | **48.429 ms** | hit 41 050 + read 541, dirtied 192 |
| audit SHIPPED | `Hash Join` over `Seq Scan on copy (rows=200026)` | 83.229 ms | hit 13 945 + read 24, **dirtied 1 726** |
| audit ALT | `Bitmap Heap Scan` via `…_id`, `Heap Blocks: exact=169` | **38.112 ms** | hit 39 566 + read 796, **dirtied 4** |

So the alternative is faster but *reads more pages* (one btree descent per doomed id) while dirtying
far fewer (it never full-scans the heap, so it does not set hint bits across the whole table). Neither
arm lets the planner use a parallel node on the doomed side — measured directly on the real table by
the agent's probe: `Limit → Seq Scan … Filter: (created_at < now() - '7 days')`
(`.tools/p4d-ab-backlog.log:10-18`), which is also why selection order is stable.

Cross-agent corroboration, same machine, real tables, `vacuum analyze` between arms and rolled-back
`EXPLAIN ANALYZE`, 3 interleaved reps (`.tools/p4d-ab-backlog.log:20-436`):

| table | SHIPPED reps | ALT reps |
|---|---|---|
| `webrtc_signals` | 89.368 / 89.435 / 87.710 ms | 65.357 / 59.242 / 67.648 ms |
| `audit_logs` | 143.513 / 140.435 / 136.782 ms | 92.779 / 87.561 / 85.904 ms |

Same direction as the copy-based plans, different absolute numbers — as expected, because the real
`audit_logs` carries `audit_logs_append_only` (`CREATE TRIGGER … BEFORE DELETE OR UPDATE … FOR EACH
ROW`, confirmed via `pg_trigger`) which fires 10 000 times per batch (`Trigger
audit_logs_append_only: time=40.115 calls=10000`, `:435`). `CREATE TABLE AS` does not copy triggers,
so my copies exclude it. It is shape-neutral — one call per deleted row in both arms — so it inflates
both absolutes equally and does not affect the comparison; the trigger exemption for
`service_role/postgres/supabase_auth_admin` (`20260101000000_core.sql:543-566`, recorded at
`_work/p3-sql-performance.md:202-206`) is a separate matter.

## 4. Verdict

- **Equivalence: DEMONSTRATED** for the two shapes as written, at these volumes, on these two tables:
  identical selected-and-deleted row set, identical batch order, identical batch size, repeatable
  across 2 reps per arm. The Phase 3 caveat at `p3-sql-performance.md:215` is closed.
- **Adoption: NOT DONE.** The sweep statements live inside
  `supabase/migrations/20261030000300_retention_sweep.sql:119-135`, an already-authored migration
  file. Rewriting it changes what would be applied to hosted Postgres, and brief §6 forbids procedural,
  cron, RPC-signature or migration changes without owner approval; §2 forbids deployment outright.
  **No migration file was modified in this workstream** (`git status` in §7).
- **What is still NOT proven, and is not closed by this probe:**
  1. Nothing ran on Supabase hosted Postgres (version, storage, autovacuum differ) — plan *shape*
     findings transfer, absolute milliseconds do not.
  2. Equivalence was measured on copies of a *static* relation. In production the sweep is a loop
     over a table other writers are changing, so per-batch membership legitimately differs between
     runs; what is proven is that the shapes have no *systematic* difference in selection or ordering
     semantics, not that consecutive batches are equal.
  3. The crossover volume is unmeasured: the alternative costs one btree descent per doomed id
     (≈3.1 × 10⁴ buffer hits for 10 000 ids here). At a batch size approaching table size, or with a
     cold and much larger heap, the shipped single seq scan could win. Not extrapolated.
  4. `location_events` and `usage_daily` (also swept) were not probed.
  5. Bounded execution (per-batch `COMMIT`) is untouched and still OWNER-ONLY decision #4.

## 5. Deliverable for owner review

`docs/implementation/proposals/phase4-retention-sweep-batch-shape.sql` — the exact two statements,
the evidence pointers above, the test that would have to move with them, and the approval required.
Proposals are inert files: no migration added, no index added, no function or cron change, nothing
deployed.

## 6. Commands (executed, exit codes)

```
.tools/pgsql16/pgsql/bin/psql -h 127.0.0.1 -p 55461 -U postgres -d p4d_perf -f .tools/p4d_equiv.sql > .tools/p4d-equiv.log 2>&1
  -> EXIT=0, 318 lines, 0 ERROR
.tools/pgsql16/pgsql/bin/psql -h 127.0.0.1 -p 55461 -U postgres -d p4d_perf -f .tools/p4d_equiv_order.sql > .tools/p4d-equiv-order.log 2>&1
  -> EXIT=0
.tools/pgsql16/pgsql/bin/psql -h 127.0.0.1 -p 55461 -U postgres -d p4d_perf -c "\d public.webrtc_signals" -c "\d public.audit_logs"
  -> id uuid / pkey(id) / created_idx / FKs / RLS policies listed
psql -At -c "select tgname, pg_get_triggerdef(oid) from pg_trigger where tgrelid='public.audit_logs'::regclass and not tgisinternal"
  -> audit_logs_append_only BEFORE DELETE OR UPDATE FOR EACH ROW
```

## 7. Cleanup disclosure

`.tools/pgdata_p4d` (port 55461, pid 8932) held only synthetic data created for this phase. It is
stopped and its data directory removed after these logs were captured, together with the per-arm
copies (`w_*`, `a_*`) and `p4d_cap`. The other clusters (`pgdata_p2`, `pgdata_p3a`, `pgdata_p3b`) are
Phase 2/3 artifacts and were not touched. **No hosted system was contacted by this workstream.**
