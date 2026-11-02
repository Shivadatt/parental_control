# Phase 3 / SQL-02 + SQL-04 — sweep indexes and retention-sweep performance

Workstream P3-A2, evidence re-derived by the coordinator. Every figure below is a captured
`EXPLAIN (ANALYZE, BUFFERS)` or `\timing` line from a disposable local cluster; none is
estimated, and none was run against the hosted project. The Supabase CLI was never invoked.

Environment: repo-local PostgreSQL 16.9, cluster on **port 55442**, data dir
`.tools/pgdata_p3b` (gitignored), database `p3b_perf`, trust auth:

```bash
export PATH=/d/parentcontrol_app/.tools/pgsql16/pgsql/bin:$PATH
psql -h 127.0.0.1 -p 55442 -U postgres -d p3b_perf -v ON_ERROR_STOP=1 -f .tools/<script>.sql
```

Seed (`.tools/p3b_seed.sql`, log `.tools/p3b-seed.log`, all rows `ANALYZE`d):

| table | rows | out-of-window at probe time |
|---|---|---|
| `remote_sessions` | 200,000 (later 200,400) | 1,512 abandoned > 24 h (411 of them with `accepted_at IS NULL`) |
| `webrtc_signals` | 140,000 | 60,000 older than 7 d → **43 %** |
| `audit_logs` | 200,800 | 25,000 older than 365 d → **12.4 %** |
| `location_events` | 100,000 | 40,000 older than 30 d |
| `usage_daily` | 40,000 | 9,600 older than 90 d |
| `families` / `devices` | 20 / 20 | per-family sweep loops 20 times |

Heap sizes before the change: `webrtc_signals` 17 MB + 16 MB indexes, `audit_logs` 30 MB + 23 MB
indexes, `remote_sessions` 32 MB + 15 MB.

## 1. SQL-02 — the abandoned-session index did not match its own predicate

`supabase/migrations/20261030000100_abandoned_session_sweep.sql` shipped with a comment
claiming the index "Matches the WHERE clause exactly". It did not:

```
BEFORE  CREATE INDEX … ON remote_sessions USING btree (accepted_at)
        WHERE status = ANY (ARRAY['accepted','active'])       -- indkey = 9, indexprs NULL
AFTER   CREATE INDEX … ON remote_sessions USING btree (COALESCE(accepted_at, requested_at))
        WHERE status = ANY (ARRAY['accepted','active'])       -- indexprs = COALESCE(...)
```

The sweep filters on `COALESCE(accepted_at, requested_at)`, so the age test could never be an
`Index Cond`; the index only supplied the status predicate and every qualifying TID was then
re-tested on the heap. `pg_index.indexprs IS NOT NULL` is what distinguishes the two builds —
that, not `pg_indexes.indexdef` string matching, is what `tests/74` asserts.

The migration now drops a pre-existing plain build before creating the expression one
(`raise notice 'remote_sessions_abandoned_idx: dropped the plain accepted_at build (SQL-02)'`,
captured in `.tools/p3b-sql02-apply.log`), because `create index if not exists` would otherwise
silently keep the wrong shape on a database that already has it.

### Controlled A/B on identical data

`.tools/p3b_sql02_ab.sql` was run twice against the *same* `p3b_perf` dataset — the index build
swapped between runs, then restored — so the two logs
(`.tools/p3b-sql02-ab-PLAIN.log`, `.tools/p3b-sql02-ab-EXPR.log`) are directly comparable.
Cohort in both runs: `in_index=19,600  abandoned_24h=1,512  abandoned_null_accepted=411
total_rows=200,400`.

| query | PLAIN build (pre-fix) | EXPR build (shipped) |
|---|---|---|
| Q1 sweep cursor `for update`, 1,512 hits | **15.134 ms** — index returns 19,600 TIDs, `Rows Removed by Filter: 18,088`, heap `Buffers: shared hit=2,314 read=17` | **7.377 ms** — index returns 1,912 TIDs, no filter removal, heap `Buffers: shared hit=317` |
| Q2 same shape, no row lock | 8.741 ms, `Buffers: shared hit=2,331` | 1.901 ms, `Buffers: shared hit=317` |
| Q3 **idle sweep** (window so wide nothing qualifies) | 11.732 ms — still walks all 19,600 entries | **0.039 ms** — `Bitmap Index Scan … rows=0`, `Buffers: shared hit=2` |
| Q4 `expire_abandoned_sessions()` executed then rolled back (1,512 rows closed) | 588.249 ms | 661.169 ms |

Q3 is the case that matters operationally: `expire_abandoned_sessions` runs **on every parent
`request_remote_session` call**, and almost always finds nothing. Pre-fix that "nothing" cost a
full walk of the partial index (11.732 ms of work on the request path, 2,331 buffers); post-fix
it costs 0.039 ms on 2 buffers.

Q4 must be reported honestly: the single-run delta there is **negative** (588 → 661 ms), so it was
re-measured three times per build with the index swapped back and forth —

```
PLAIN  595.490  624.785  673.929 ms
EXPR   596.925  608.586  601.730 ms   (ranges overlap)
```

— and the conclusion is that the 73 ms single-run gap was noise. End-to-end the RPC is dominated
by 1,512 `UPDATE`s plus 1,512 audit inserts (~0.4 ms per closed row); the index build makes no
measurable difference to the write path. **The win is entirely on the read side, and it is
concentrated in the idle case.** No claim of an end-to-end RPC speedup is made.

## 2. SQL-04 — global purge predicates had no usable index

Catalog capture (`.tools/p3b-sql04-before.log`, `=== existing indexes ===`): `audit_logs` had
`audit_logs_actor_idx (actor_user_id, created_at DESC)` and `audit_logs_family_created_idx
(family_id, created_at DESC)`; `webrtc_signals` had only `webrtc_signals_pkey` and the two
`(session_id, sequence)` indexes. A `created_at` predicate that is not scoped by family or actor
cannot use either composite index — `created_at` is not the leading column — so the two global
purges were unindexed full scans:

```
Seq Scan on webrtc_signals  Filter: (created_at < now() - '7 days')  rows=10000  5.733 ms
Seq Scan on audit_logs      Filter: (created_at < now() - '365 days') rows=10000
                                              Rows Removed by Filter: 175,801   6.054 ms
```

Fix shipped in `20261030000300_retention_sweep.sql`:

```sql
create index if not exists webrtc_signals_created_idx on public.webrtc_signals (created_at);
create index if not exists audit_logs_created_idx    on public.audit_logs    (created_at);
```

plus the matching two `drop index` lines in that migration's rollback block. They are plain,
non-partial, single-column btree indexes led by `created_at` — which is exactly what
`supabase/tests/74_sweep_indexes_and_repeatability.sql` §2 asserts from `pg_index`, alongside a
check that the pre-existing per-family indexes still exist (the fix must not have replaced them).

### Measured effect — and its honest scope

Backlog case (`.tools/p3b-sql04-probe.log`, 60,000/140,000 = 43 % and 25,000/200,800 = 12.4 %):

| shape | before index | after index | planner behaviour |
|---|---|---|---|
| `audit_logs` batch SELECT (`limit 10000`) | 69.670 ms Seq Scan, `Rows Removed by Filter: 175,801` | **4.639 ms** `Bitmap Index Scan on audit_logs_created_idx … rows=25000` | index adopted |
| `audit_logs` shipped DELETE | 169.262 ms | 149.615 ms | doomed side indexed; **target side still `Seq Scan on audit_logs a (rows=200,801)`** |
| `webrtc_signals` batch SELECT | 5.401 ms Seq Scan | 5.836 ms Seq Scan | **index not adopted** |
| `webrtc_signals` shipped DELETE | 66.346 ms | 67.434 ms | unchanged; still Seq Scan |

So at a 43 % backlog the new `webrtc_signals` index is not used at all, and at 12 % only the
doomed-row lookup benefits while the delete target is still scanned wholesale. Claiming a speedup
from those numbers would be false.

Steady-state case (`.tools/p3b-sql04-steady.log`, after clearing the backlog with one real
`run_retention_sweep()` call and injecting 1,200 old signals + 400 old audit rows). The measured
population block in that log is `webrtc_signals 81,200 total / 1,200 backlog / 1.48 %` and
`audit_logs 176,202 / 400 / 0.23 %`; the `\echo` section labels printed *above* those rows in the
same log carry a stale hand-written "0.86 %"/"0.2 %" — the measured figures govern, and the script
label has since been corrected.

| shape | result |
|---|---|
| `webrtc_signals` DELETE, 1.48 % backlog | 26.285 ms — doomed side now `Bitmap Index Scan on webrtc_signals_created_idx … rows=1200`, `Buffers: shared hit=18`; **target side still `Seq Scan on webrtc_signals w (rows=81,200)`** because the planner prefers a Hash Join at that volume |
| `audit_logs` DELETE, 0.23 % backlog | **6.936 ms** — the plan *flips*: `Index Scan using audit_logs_pkey on audit_logs a … loops=400` replaces the full-table Seq Scan |
| full `run_retention_sweep()` on that dataset | 46.380 ms for 1,600 rows, executed inside a transaction and rolled back; the follow-up count confirms `signals_old_still=1200, audit_old_still=400`, i.e. nothing was consumed |

The defensible claim: the indexes move the **selection** side from a filter over the whole table to
an index range scan in every measured case (2,331 → 317 buffers class of change), and at low
selectivity they additionally let the planner drop the target-table scan on the larger table
(149.6 ms → 6.9 ms for `audit_logs`). The **limit** of the claim: on `webrtc_signals` the shipped
`delete … using (select … limit)` shape keeps a Seq Scan of the target at both 43 % and 0.86 %
backlog, so the index alone does not bound that statement's work. An alternative shape
(`where id = any(array(select …))`) measured 40.392 → 36.256 ms in the same probe — better than
the shipped 66–67 ms, but it was **not adopted in Phase 3**, because changing it alters delete
ordering and is a separate decision (recorded in `p3-followups.md`, not silently shipped).

## 3. Bounded execution: what the loop does and does not achieve

`run_retention_sweep()` loops `delete … limit 10000` until a pass removes fewer than the batch.
Analysis written into the migration header, and the measurements behind it:

- A `limit` bounds a **statement**, not a **transaction**. One call on the seeded backlog
  (134,600 rows: 60,000 + 25,000 + 40,000 + 9,600) completed in **1,150.966 ms** as a single
  function transaction — `pg_stat_user_tables` after that run: `webrtc_signals.n_tup_del=70,000`,
  `audit_logs.n_tup_del=35,000`, `location_events.n_tup_del=40,000`, `usage_daily.n_tup_del=9,600`.
  (Those counters also include the 10,000-row `EXPLAIN ANALYZE` deletes that were executed inside
  rolled-back transactions, which is why they exceed the swept totals.)
- Cost is **linear, not quadratic** in the backlog: the loop is not `delete 10000` from an
  ever-shrinking scan, because the `created_at` index makes each pass an index range scan. 134,600
  rows → 1,151 ms; 1,600 rows → 46 ms.
- **What is still not true: there is no committed partial progress.** If the call is cancelled or
  the transaction aborts, every pass is rolled back and the next call starts from zero. Making
  progress durable requires a `PROCEDURE` with `COMMIT`, which changes the callable signature and
  the `cron` Edge Function that invokes it.

Options considered and recorded rather than quietly chosen:

- **A — `procedure` + per-batch `COMMIT`**: real bounded transactions, but it is no longer a
  `returns jsonb` function, so `supabase/functions/cron` and any `select run_retention_sweep()`
  caller must change. Needs owner approval; not implemented. No cron schedule was created and
  nothing was deployed.
- **B — a capped/overloaded signature**: rejected. A default argument on a new overload removes
  the existing 0-argument call, and a second overload makes
  `rpc('run_retention_sweep')` ambiguous to PostgREST, which surfaces it as `PGRST202` — a
  client-visible break for a performance-only change.
- **C — indexes only, keep one transaction**: shipped. Idempotent, safe on an empty dataset,
  linear rather than quadratic.

## 4. Regression coverage

`supabase/tests/74_sweep_indexes_and_repeatability.sql` (new; runs after
`72_retention_sweep.sql` because both invoke the global sweep):

- §1 SQL-02 catalog shape: `pg_get_expr(indexprs)` matches `coalesce(accepted_at, requested_at)`
  (whitespace-tolerant regex), the predicate still covers `accepted`/`active` and does **not**
  mention `requested` as a status, the index stays partial, no second plain `(accepted_at)` build
  survives; then `\i`s the migration and re-asserts, so the rebuild guard is proven idempotent.
- §2 SQL-04 indexes: both are valid 1-column btree indexes led by `created_at`, and the
  pre-existing per-family indexes are still present.
- §3 behaviour: a NULL-`accepted_at` consented row is closed by the age rule → `status='expired'`,
  `ended_reason='abandoned'` with `ended_by IS NULL` (the D1 representation, asserted as shipped,
  pending owner ratification), young and still-pending rows untouched, `v_closed >= 2`, and family
  scoping holds.
- §4 repeatability: first sweep removes only out-of-window rows; the second returns zero counters
  but still appends its marker row; a third on an emptied dataset is safe. Plus the two tripwires
  that keep the honesty of §3 above — `prosrc not like '%commit%'` (one call is still one
  transaction) and `prosrc like '%10000%'` (the statement bound is still there) — and
  `service_role`-only + `SECURITY DEFINER` on `run_retention_sweep`.

One test that was **removed before running**: an audit append-only assertion. The suite executes as
the `postgres` superuser, and `20260101000000_core.sql:543-566` exempts
`service_role/postgres/supabase_admin/supabase_auth_admin` from that trigger, so a "refusal" could
not be observed — and under RLS a zero-row update would masquerade as a pass. A comment in the file
records this instead of a fake green.

## 5. Not proven

- Nothing here was measured on Supabase's hosted Postgres (different version, storage, and
  autovacuum behaviour), so absolute timings are not transferable — only the plan *shape* findings.
- No `cron` schedule was created, no migration applied, and no Edge Function deployed. The
  hosted project remains pre-Phase-1 as of this phase; see the dashboard inspection record.
- The `webrtc_signals` target-side Seq Scan is characterised, not fixed: no evidence yet that the
  `= any(array(...))` shape is safe to adopt, only that it measures faster at these two volumes.
