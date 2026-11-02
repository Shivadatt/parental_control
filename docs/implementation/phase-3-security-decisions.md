# PHASE 3 — security decisions

One place that records **every security-relevant decision taken in Phase 3**, who was allowed to take it, and what is
still the owner's to take. Read with `phase-3-report.md` (execution evidence) and `phase-3-open-gaps.md` (register).

Decision labels: **SHIPPED** = implemented in the working tree and regression-covered · **MITIGATED** = exposure
reduced, full fix blocked on an approval · **DEFERRED** = analysed, deliberately not implemented · **OWNER-ONLY** =
Phase 3 had no authority to decide and did not.

---

## D-1 · SQL-01 — rollback must not restore an authorization exposure (**SHIPPED**, with an **OWNER-ONLY** remnant)

**Measured privilege matrix.** Each cell was read from `pg_proc.proacl`, `pg_class.relacl` and `pg_policies` on a
disposable PostgreSQL 16.9 database (forward = with `20261030000200` applied; rollback = after the supported steps).
Raw captures: `.tools/p3a-matrix-{BEFORE,AFTER_FORWARD,AFTER_ROLLBACK_ORIG,AFTER_ROLLBACK_FIXED,AFTER_ROLLBACK_SEDEXTRACT}.txt`
(48 / 50 / 48 / 47 / 47 rows). The first four columns are reproduced in-comment at
`20261030000200_phase1_authorization.sql:36-47`; the **Original (unsafe) rollback** column is **not** in that
comment — it comes from `AFTER_ROLLBACK_ORIG.txt` and the five quoted NOT-RUN statements at `:115-131`:

| Object | Grantee | Before | Forward | **Supported rollback** | Original (unsafe) rollback |
|---|---|---|---|---|---|
| `private.remote_session_transition_guard()` | anon / authenticated / **PUBLIC** | EXECUTE (via default `proacl IS NULL`) | **REVOKED** | **REVOKED** | `=X/postgres` **restored** |
| `private.remote_session_transition_guard()` | service_role | via PUBLIC | REVOKED | REVOKED | restored |
| `private.request_device_recovery(uuid, uuid)` | anon / authenticated / PUBLIC | EXECUTE | **REVOKED** | **REVOKED** | **restored** |
| `public.safe_zones` DELETE | authenticated | GRANTED | **REVOKED** (`authenticated=r`) | **REVOKED** | **DELETE restored** (`authenticated=rd`) |
| `public.safe_zones` DELETE | anon | (none) | (none) | (none) | (none) |
| policy `safe_zones_delete_parent` | authenticated | PRESENT | **ABSENT** | **ABSENT** | **PRESENT** (`using (private.is_family_parent(family_id))`) |
| index `webrtc_signals_session_sequence_uniq` | — | ABSENT | PRESENT | **PRESENT** | **DROPPED** |
| `public.{request_remote_session, revoke_device, unlink_child, apply_policy_version}` | anon / authenticated | REVOKED | REVOKED | REVOKED | REVOKED |
| same four | service_role | EXECUTE | EXECUTE | EXECUTE | EXECUTE |

**The two facts that decided the shape** (both measured, not argued):

* **A.** The four public wrappers were *already* service-role-only before Phase 1 (`20260101000100_functions.sql:876-904`,
  `20261028000200…sql:183-187`) — Phase 1 changed their **bodies**, not their grants. So rolling the bodies back is
  privilege-neutral (`create or replace` leaves `proacl` and `reloptions` alone; `prosecdef` and the pinned
  `search_path` survive).
* **B.** The two private functions held EXECUTE only through PostgreSQL's **default PUBLIC grant**. Re-granting PUBLIC
  hands it back to `anon` and `authenticated` over PostgREST. And `grant … to public` is even *wider* than the true
  pre-Phase-1 baseline, because PUBLIC subsumes `service_role`.

**Decision shipped.** Rollback = **R1 → R2 → R4** only:

* **R1** restore the four pre-Phase-1 wrapper bodies verbatim from their source migrations (`sed` ranges
  `20261028000200:106-181` and `20260101000100:721-733;748-759;761-771`); verified to yield byte-identical ACLs and
  policies to an inline body restore.
* **R2** drop `private.is_parent_of_family(uuid, uuid)` **only if nothing references it**, else
  `raise exception … using errcode='P0001'`. This guard is load-bearing: the previous text dropped the helper while all
  four wrappers still called it, psql exited **0**, and every later RPC call failed with `42883` — a P0 outage behind a
  "successful" undo.
* **R4** verify: no `=X/` PUBLIC entry in `proacl`, and `calls_helper = false`.
* In-chain enforcement: `supabase/tests/71_phase1_rollback_privileges.sql`, phases `1_forward`,
  `2a_after_unsafe_rollback`, `3_rollback`, `4_reforward` + the R2 GUARD, run inside the documented chain (it must leave
  the state forward again before `72_retention_sweep.sql`). Chain exit 0.

**Not decided by Phase 3 (OWNER-ONLY).** **R3** — the five statements that produce a true revert (re-grant PUBLIC
EXECUTE ×2, re-grant DELETE, re-create the policy, drop the unique index) — is written into the migration **as a
labelled, deliberately unexecuted de-hardening**. Running it re-opens exactly what Phase 1 closed. Approve, forbid, or
name who may run it.

**Reversibility, stated plainly:** privileges/policies/index are reversible in the hardening direction; bodies are
**git-only** after apply; rollback is **schema-only** (zones already deleted stay deleted; requests rejected by
`not_family_parent` were never written). `service_role` loses EXECUTE on the two private functions in *all three*
columns — it held it only via PUBLIC — verified harmless (only the SECURITY DEFINER public wrappers touch them) and
disclosed as a divergence **in the safe direction**.

---

## D-2 · SQL-02 — index keyed on the expression the predicate compares (**SHIPPED, scoped claim**)

`remote_sessions_abandoned_idx` now indexes `COALESCE(accepted_at, requested_at)` for the same status set the sweep
cursor scans, plus a rebuild guard that drops only a *plain-column* build (`pg_index.indexprs IS NULL`) so re-running
the file is a no-op.

Proven, not asserted (identical cohort `in_index=19600 / abandoned_24h=1512 / total_rows=200400`):

| Query | PLAIN build | EXPR build |
|---|---|---|
| sweep cursor (`for update`), 1 512 hits | 15.134 ms · 19 600 index TIDs · `Rows Removed by Filter: 18 088` · Buffers hit 2 314 | **7.377 ms** · 1 912 TIDs · no filter removal · Buffers hit 317 |
| same, no row lock | 8.741 ms | **1.901 ms** |
| idle sweep (nothing qualifies) | 11.732 ms — still walks 19 600 entries | **0.039 ms** — Buffers hit 2 |
| real RPC (1 512 closed), rolled back | 588.249 ms | 661.169 ms |

**Deliberate limit:** the last row is **not** a claim of an end-to-end speedup. Three repeats — PLAIN 595/625/674 ms,
EXPR 597/609/602 ms — showed that single-run delta to be noise. The proven win is on the read/idle path, which is what
runs on every cron tick against a mostly-empty result set.

---

## D-3 · SQL-04 — indexes shipped, bounded execution **not** (**MITIGATED**; **OWNER-ONLY** for the rest)

**SHIPPED:** `webrtc_signals_created_idx (created_at)` and `audit_logs_created_idx (created_at)`, neither of which
existed before (captured: `webrtc_signals` had only `(session_id, sequence)`; `audit_logs` only
`(family_id, created_at desc)` and `(actor_user_id, created_at desc)` — the sweep's predicates are bare `created_at`),
plus matching `drop index` rollback lines.

Measured: audit backlog SELECT 69.670 → **4.639 ms**; audit DELETE at 0.23 % backlog 149.615 → **6.936 ms** (plan flips
to `Index Scan using audit_logs_pkey … loops=400`); webrtc SELECT 5.401 → 5.836 ms — **the index was not adopted** there,
reported as measured; webrtc DELETE unchanged (66.346 → 67.434 ms) — the residual **PERF-01**.

**Rejected Option B** (capped `run_retention_sweep(p_max_rows)` overload): removing the 0-arg signature makes
`rpc('run_retention_sweep')` ambiguous → PostgREST `PGRST202`. That is an API-contract break disguised as a tuning knob.

**OWNER-ONLY, Option A:** `create procedure public.run_retention_sweep(p_max_rows integer)` with `COMMIT` inside the
loop. Evidence for why it matters: one call over a 134 600-row backlog = **1 150.966 ms in a single transaction**, and a
failure/rollback leaves **no committed partial progress**. The retention cost profile is **linear, not quadratic**, once
the index exists. `tests/74` §4 contains two tripwires — `prosrc not like '%commit%'` at `:410` and `prosrc like '%10000%'`
at `:422` — so an
unapproved change to either cannot land quietly.

**Not done, as instructed:** no cron schedule created, no sweep deployed. Hosted `/integrations/cron/jobs` still reads
**"Cron is not installed."**

---

## D-4 · SQL-03 — authorization is never a 5xx and never a success (**SHIPPED**)

**Rule adopted:** a Postgres error is an authorization failure when **SQLSTATE `42501`** matches, or when the message
carries an authorization marker (`not_family_parent`, `forbidden`, `parent_required`, `owner_required`,
`permission denied`, `row-level security`, `insufficient privilege`, `insufficient_privilege` — eight markers at
`error_mapping.ts:62-71`). Message markers are the fallback for transports
that drop the code — `code` is checked first because text can change without meaning changing.

**Carve-out that prevents a worse bug:** `42501` raised by an **integrity** rule (`append-only`, `is immutable` —
`audit_logs_append_only`, `profiles_before_update`, `families_before_update`) is a **server fault** and keeps the
handler's existing 500. Relabelling a broken deploy as "you lack permission" would hide it behind a permission message.

**Shape of the answer:** code `forbidden`, HTTP **403**, fixed text `"You do not have permission to perform this
action."` — never the SQL message, constraint name, table or payload. Server-side, exactly one line is logged:
`<context>_denied:<sqlstate>:<whitelisted reason token>` (same convention as `ensureNoError`/`recordAudit`).
Anything not authorization-shaped returns `null` so each handler keeps its own 401/404/409/410/422/500 mapping —
**preservation was the requirement, not convenience**.

**Wired at:** `device-policy` (`mapPolicyRpcError` at `:21`, used at `:76`), `device-command` (`mapApplyPolicyRpcError`
at `:57`, used at `:143` inside `case "create"` — the **enqueue** path where `apply_policy_version` runs; the `ack`
path at `:250` never called an authorization-raising RPC, so it gained no mapping), `pairing`
(`respond_pairing_request`, `create_pairing_invite`, `create_pairing_request`, `unlink_child` + the shared mapper).
`family-admin` already mapped it and was left semantically unchanged.

**Why this was a real defect:** the device guardian (`GuardianService.kt`) grows poll backoff from *any*
`DeviceHttpException` and never stops retrying, so a permanent permission failure became an **endless retry loop**; the
Dart repositories already treat `42501` as `AppErrorCodes.forbidden`, so client and server disagreed about the same
event. Covered by 13 tests, including a cross-handler agreement test that asserts all four reply with the same code and
envelope shape.

---

## D-5 · SQL-05 — audit atomicity (**MITIGATED**; full atomicity **OWNER-ONLY**)

**Decision:** Phase 3 could not create the fourth migration or a new RPC (the frozen chain is three files;
`api-contract.md` §6 is a closed list), so the guarantee was rewritten to something provable **inside `family-admin`
alone**, and the atomic implementation was delivered as `proposals/phase3-safe-zone-audit-atomicity.sql` — **a proposal,
not applied, not in the chain, not in the README run order.**

**Guarantee now shipped:** *no silent unaudited deletion.* Retry the audit insert 3 times → on total failure restore the
exact pre-delete row and answer `audit_failed`/500 "the safe zone was kept" → if the restore also fails, answer 500
stating the zone **was** deleted but **not recorded**, log `zone_delete_unaudited:<code>:<zone id>`, and never return
`{deleted:true}`.

**Invariants kept:** audit only on an actual removal (zero-row delete still writes nothing); `audit_logs` stays
append-only (insert-only code; the immutability trigger untouched; row shape byte-identical to `recordAudit`); error
codes unchanged; `details` on `fail()` additive-only; no `lib/` change needed because the client already renders
`error.message` verbatim.

**Rejected alternative — a DB trigger:** the handler uses the service-role key without forwarding the per-request JWT,
so a trigger could not attribute `actor_user_id` without trusting a client-settable GUC — precisely the forged-actor
hole `20261030000200` closed for `revoke_device` — and it would fire on every future service-role delete.

**Accepted residuals (documented in the module header):** duplicate `zone_deleted` rows are possible in the
commit-then-lost-response window (over-recording, append-only-safe); the restore does not resurrect cascade-deleted
`safe_zone_states` latches (they rebuild on the next `location_upload`).

---

## D-6 · ENF-01 — what may prove enforcement (**SHIPPED**)

**The key.** `payload.policy_id` — written only by `apply_policy_version` (`20260101000100_functions.sql:160-171`) — is
the **one and only** correlation key. Explicitly rejected as keys: `payload.version` (a hand-made row can set it
arbitrarily), ack counters (`result.*` says nothing about which policy), timestamps (age-based promotion *is* the bug
being removed), and `installation_id` (not in any payload, revoked from `authenticated`, unreadable by the parent
client). The server side was already safe (`device-command/index.ts:327-328` gates on `isUuid(policyId)`); the defect
was purely parent-side attribution.

**Three-way rule:** `matched` (id equals the displayed policy) may prove; `mismatched` is never shown for the policy on
screen, but remains visible for the policy it *does* name; `uncorrelated` (absent/empty/whitespace id) stays **visible
with its counts and per-app failures** under an explicit banner and `provesEnforcement == false`.
**Refused:** dropping uncorrelated reports (would erase real device history and make a parent think the device never
reported) and timestamp/version inference (would silently re-create ENF-01).

**Green badge / success banner** require `matched` **and** the frozen counters (`enforcement_supported == true`,
`failed_count == 0`, `applied == desired`). `provesFullEnforcement` remains the counts-only predicate but is documented
as necessary-and-not-sufficient. **WORD-01** folded in: the header now reads "could not confirm as suspended", matching
the device's own reason text.

**Race:** after a save, the newest ack normally names the previous policy → mismatched → "Pending device
acknowledgement", no counts, no badge, until the device acks the **new** command. Independently, `_reportRequest`
generation-guarding means a slow superseded response cannot assign — including on its error path — and `refreshPolicy()`
with no policy on file clears the report.

---

## D-7 · PRIV-01 — child retention scope (**OWNER-ONLY**, deliberately unchanged)

**Status: no behaviour, contract or UI changed.** The brief required it, and the finding is worse than filed: besides
whole-family `location_events` / `usage_daily` counts, the same response returns the **project-wide** deletion totals
from the sweep marker (`account/index.ts:434-435` + `20261030000300_retention_sweep.sql:232-247`, stored with
`family_id = NULL`), which cross the family boundary entirely.

Severities stated separately: family-wide counts to a child caller = **P2**; project-wide totals = **P2 alone**, rising
to **P1** if any UI ever renders `last_sweep` per family, because the number is not that family's. Mitigating context,
also stated: there is **no child-facing retention UI today** (`child_settings_tab.dart:29-77`; role routing sends a
child to the child shell), and the parent UI already discloses "Counts cover the whole family, not just this account."
So the exposure is the endpoint's answer, not a rendered screen.

Options are fully specified in `_work/p3-privacy-decisions.md` §1.2/§1.3 (privacy implications, exact targets, contract
delta, backward compatibility, required tests, cost, residual risk), with the middle path (parent-only gate) recorded
and explicitly *not* recommended by this workstream because it removes the child's transparency answer — a privacy
trade only the owner should weigh. **Recommendation, as advice: Option A, scoped** (mirrors the already-shipped
`export` predicate; makes the two actions agree; leaks nothing RLS grants).

---

## D-8 · GOV-02 / D1 — abandoned-session representation (**OWNER-ONLY**)

`ended_by = NULL` + `ended_reason = 'abandoned'` is what the `uuid` column type forces; it is coordinator-ratified and
**owner-unsigned**. Phase 3's contribution is the memo the owner signs or rejects, plus the two facts that survive
whatever is signed: the marker is **never surfaced in either session UI**, and because four other `expired` writers
leave `ended_by` untouched, **`ended_by IS NULL` alone is ambiguous** — consumers must key on the pair
(`20261030000100…sql:28-29`). Alternative 4 (a CHECK or trigger forbidding the pair to be half-set) is the only
rejection path that closes the drift risk without changing columns.

---

## D-9 · Privacy / data handling notes from the phase

* No production data was read. Every SQL execution was on a disposable cluster with synthetic fixtures, and every
  destructive probe ran inside `BEGIN … ROLLBACK` (re-counted afterwards to prove the dataset was unchanged).
* The only hosted reads were **catalog** `SELECT`s (`pg_proc`, `pg_class`, `pg_policies`, `pg_indexes`, `pg_trigger`,
  `information_schema.columns`) — no application rows were queried.
* No new PII field is emitted by any Phase 3 change. SQL-03 *reduces* information flow (internal SQL text no longer
  reaches the caller); SQL-05 adds only an operation-specific sentence; ENF-01 only *removes* an unjustified claim.
* `docs/` and `.tools/` evidence contains UUIDs of synthetic fixtures only; no tokens, secrets, hashes or real user ids
  were copied into any Phase 3 document.

## D-10 · Confirmation required by §10 of the brief

**Nothing was deployed or applied to hosted Supabase.** No migration applied, no Edge Function uploaded, no secret or
Auth setting changed, no row written, no index created, no cron job installed. The Supabase CLI was never invoked from
this phase (the binary's presence on the workstation is recorded, and its use is prohibited by the phase rules and by
the project memory rule [[supabase-browser-only]]). All hosted statements in this document are read-only dashboard
observations dated 2026-11-02.

## D-11 · Approval queue (the only things standing between this tree and a deployment)

| # | Approval | Decision ID | Blocking? |
|---|---|---|---|
| 1 | PRIV-01 Option A / B / parent-only gate | D-7 | **Yes** — product/privacy |
| 2 | GOV-02 / D1 ratification | D-8 | **Yes** — contract wording |
| 3 | SQL-05 atomic RPC (4th migration) | D-5 | **Yes** — frozen chain |
| 4 | SQL-04 `PROCEDURE` + `COMMIT` bounded sweep | D-3 | Yes for cron; no for the indexes as shipped |
| 5 | SQL-01 R3 de-hardening policy | D-1 | Only if a true revert is ever wanted |
| 6 | `api-contract.md:223` replay-wording correction | `_work/p3-followups.md` §3 | Yes — the doc currently over-claims a control |
| 7 | TEST-01 export-first handler refactor (ownership) | `_work/p3-followups.md` §2 | No — test-strength debt |
| 8 | Commit / push of the uncommitted Phase 2 + Phase 3 work | `phase-3-report.md` §2 | **Yes** — nothing is committed |
