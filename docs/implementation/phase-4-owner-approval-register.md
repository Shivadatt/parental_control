# PHASE 4 — owner approval register

**Nothing in this file is approved.** Every row below is a decision that belongs to the owner and was left
open on purpose. The brief is explicit that Phase 4 must not assume approvals ("Any decision marked OWNER-ONLY
must remain blocked until explicit written approval is provided", "If approval is missing, STOP that workstream
without changing behavior"), and that is exactly what happened in each case.

Status vocabulary for this file — the four tokens the brief allows, and only these:
**AWAITING OWNER** · **APPROVED** · **REJECTED** · **NOT IN SCOPE**.
Nothing here is APPROVED or REJECTED; the owner has not ruled on any of them. "NOT IN SCOPE" is used only where
the brief itself excluded the item from Phase 4 (rows 11–12), so that an empty approval column is never
mistaken for an oversight.

How to read a row: **Decision** is the question. **Options** are the actual alternatives, with what each one
changes. **Consequence of not deciding** is the state the project stays in. **Recommendation** is the
coordinator's opinion, which carries **no** authority. **Files affected** is the edit surface an approval would
open — it is a *description of future work*, not a list of things already touched.

---

## Part 1 — the eight items the brief names as OWNER-ONLY

### 1. PRIV-01 — child retention-report scope

| Field | Content |
|---|---|
| **Decision** | What may a **Child** caller learn from the `account` Edge Function's `retention_report` action? Today the action answers any verified caller — child included — with **whole-family** `location_events` / `usage_daily` counts **and** the global sweep totals, using the service-role client, so RLS never constrains it. |
| **Options** | **A (scoped)** — child/device-scoped counts + an explicit `scope` field in the response + redact the project-wide `last_sweep` totals from non-owners. **B (family-wide, disclosed)** — keep the family counts and make the child UI state what it shows. **C (gate)** — parent/owner-only caller check, no payload change. |
| **Consequence of not deciding** | The endpoint keeps a privacy-relevant answer for a caller class that arguably should not receive it. The exposure is *callable*, not *rendered*: no child UI reaches this action today, so the risk is "P2, would be P1 if rendered". Also blocks WORD-02, which needs the same `scope` vocabulary. |
| **Recommendation** | **A, scoped** — it is the only option that makes the response self-describing, and WORD-02's three-state `scope` falls out of it for free. |
| **Files an approval would open** | `supabase/functions/account/index.ts:401-410`, `:434-435`, `:462/466/473-474`; `supabase/functions/account/retention.ts:75-104`; `20261030000300_retention_sweep.sql:232-247` (the `last_sweep` surface); `lib/features/settings/settings_body.dart:162-167`; `account_privacy_repository.dart:41-42` → `export_result_dialog.dart:79-82` (WORD-02). New Deno tests + a widget test pinning the disclosure. |
| **Phase 4 action** | **None — STOPPED.** Handler untouched; the function is still undeployed (0 deployments, re-confirmed 2026-11-03). |
| **Status** | **AWAITING OWNER** |

### 2. GOV-02 / D1 — abandoned-session representation

| Field | Content |
|---|---|
| **Decision** | Ratify (or reject) the system-close representation for an abandoned remote session: `ended_by IS NULL` **together with** `ended_reason = 'abandoned'`. The `uuid` column type forces this encoding, and consumers must key on the **pair** — `ended_by IS NULL` alone is ambiguous because four other `expired` writers never touch `ended_by`. |
| **Options** | **Ratify the pair** (as-is, contract wording at `api-contract.md:231`). **Reject**, using one of 4 alternatives in `_work/p3-privacy-decisions.md` §2 — of which only Alternative 4 (a CHECK constraint / trigger enforcing the pair) closes drift without a column type change. |
| **Consequence of not deciding** | Coordinator-ratified but owner-unsigned governance continues to be the de facto rule, and the next consumer of `ended_by` may key on the wrong half of the pair. Cost of rejection rises sharply **after** deployment (data migration) versus before. |
| **Recommendation** | Ratify the pair **and** add Alternative 4's constraint at the same time, since the pre-deploy window is still open (hosted is entirely pre-Phase-1). |
| **Files an approval would open** | `20261030000100_abandoned_session_sweep.sql:28-29`; a new constraint would be a further migration; `supabase/functions/remote-session/guard.ts:140`, `:150`; `supabase/tests/63_abandoned_session_sweep.sql`; `api-contract.md:231`; `_work/coordinator-contract.md:41-43`. §2.4 of the memo is the consumer checklist. |
| **Phase 4 action** | **None — memo only.** Chain re-verified green with the current representation (banner at `.tools/p4f-chain.log:484`). |
| **Status** | **AWAITING OWNER** |

### 3. SQL-01 / R3 — the de-hardening rollback statements

| Field | Content |
|---|---|
| **Decision** | Whether a rollback of `20261030000200_phase1_authorization.sql` is ever permitted to **remove** security, and who may run it. The five quarantined statements restore `PUBLIC = EXECUTE` on two private functions, `authenticated` DELETE on `safe_zones`, the old `safe_zones_delete_parent` policy, and drop the unique index. |
| **Options** | **Sanction R3 as-is** (full revert available). **Sanction only R1/R2/R4** (the shipped safe path: keep every hardening, schema-only revert). **Never sanction** — delete the quarantined block and make reversion a forward-fix only. Note the historical detail that argues against "restore the baseline": `grant … to public` was **wider** than the true pre-Phase-1 state, so R3 is not even an accurate revert. |
| **Consequence of not deciding** | The safe path stays asserted in-chain and usable; the unsafe statements sit in the file as a copy-paste hazard. An operator under pressure at 3 a.m. can still run them. |
| **Recommendation** | **Never sanction R3.** If a revert is ever needed, it should be a *new* migration that removes exactly the object in question, reviewed on its own. |
| **Files an approval would open** | `20261030000200_phase1_authorization.sql:115-131` (quarantined range) and the rollback section of that migration; `supabase/tests/71_phase1_rollback_privileges.sql`. |
| **Phase 4 action** | **None — R3 NOT RUN.** Its supported counterpart is re-verified: `71_phase1_rollback_privileges.sql` passes inside the 31-file chain (`.tools/p4f-chain.log:550`). |
| **Status** | **AWAITING OWNER** (the statements remain quarantined until ruled) |

### 4. SQL-04 — bounded execution of the retention sweep

| Field | Content |
|---|---|
| **Decision** | Whether `run_retention_sweep()` may stop being one all-or-nothing RPC call. Measured: a 134 600-row backlog runs **1 150.966 ms** inside a single transaction with no committed partial progress; a PL/pgSQL function cannot COMMIT, so "batched" bounds a *statement*, not the *call*. |
| **Options** | **A** — `create procedure public.run_retention_sweep(p_max_rows)` + `COMMIT` per batch, changing the RPC surface (an Edge Function or a scheduler calls it, not `select run_retention_sweep()`). **B** — keep the function and accept "one call must fit the whole backlog". **C** — keep the function and *schedule it often enough* that the backlog never exceeds one call, which is a cron decision, not a code one. |
| **Consequence of not deciding** | A first real sweep after a long gap can fail wholly and retry wholly. No cron exists, so today the sweep only runs when a parent triggers retention settings — the risk is latent, not active. |
| **Recommendation** | **B now, C at deploy time, A only if measured backlog growth argues for it.** Decide alongside PERF-01a and the cron decision (row 9), since all three edit the same migration. |
| **Files an approval would open** | `20261030000300_retention_sweep.sql` (procedure + signature), `supabase/functions/**` caller of the sweep, `supabase/tests/72_retention_sweep.sql`, `supabase/tests/74_sweep_indexes_and_repeatability.sql:408-417` (the tripwire that already fires if a `commit` appears without approval), plus a Supabase **scheduled job** (dashboard, owner-created). |
| **Phase 4 action** | **None.** No procedure, no `COMMIT`, no cron, no RPC change; no schedule installed. |
| **Status** | **AWAITING OWNER** |

### 5. SQL-05 — true atomicity for zone deletion + audit

| Field | Content |
|---|---|
| **Decision** | Whether the delete/audit pair must become atomic, or whether the shipped compensation is the accepted guarantee. Today `family-admin delete_zone` commits the DELETE, then writes the audit row in a **second** transaction; if the audit fails, the mitigation retries ×3, restores the exact row, and otherwise fails loudly with `zone_delete_unaudited:<code>:<zone id>`. |
| **Options** | **Approve the atomic RPC** — `proposals/phase3-safe-zone-audit-atomicity.sql`, a service-role-only `public.delete_safe_zone_audited()` doing delete + audit in one transaction, adding a 4th migration. **Accept the mitigation** as the guarantee and close the item. **Trigger alternative — already rejected**, recorded with the reason (a trigger cannot carry a trustworthy actor identity and would enable forged audit rows). |
| **Consequence of not deciding** | Mitigation stays in force: an audit failure is loud and *usually* self-healing by restore, but over-recording is possible (SQL-05a) and cascade-dropped `safe_zone_states` latches are not restored. |
| **Recommendation** | **Approve the atomic RPC before the first deployment**, while the migration still has no hosted state to reconcile; after deploy, mitigation + a forward-fix is the only sane path. |
| **Files an approval would open** | A new migration (4th) applying `proposals/phase3-safe-zone-audit-atomicity.sql`; `supabase/functions/family-admin/index.ts` (replace the compensation block with one `rpc()` call); `supabase/functions/family-admin/delete_zone_atomicity_test.ts` + `handler_wiring_test.ts:106-172` (its pins would be retired); `supabase/tests/70_phase1_authorization.sql` (grant/RLS for the new function). |
| **Phase 4 action** | **None — untouched.** `git diff HEAD -- supabase/functions` is empty; the 12 `family-admin` Deno tests are inside the green 109. |
| **Status** | **AWAITING OWNER** |

### 6. SQL-06 — contract wording for the signaling replay index

| Field | Content |
|---|---|
| **Decision** | Approve (or reject) the re-wording of `api-contract.md:222-224`, which currently calls the unique `(session_id, sequence)` index "Signal replay protection". It cannot be that: a replay is a **new** insert carrying a **new** sequence, and the write path cannot produce duplicates at all (`sequence` is `ALWAYS IDENTITY`, the client never supplies it, no Edge Function inserts into `webrtc_signals`). |
| **Options** | **Approve the drafted text** (proposed verbatim in `_work/p4-docs-sql06.md` §3): the index is a *duplicate-row integrity guard against a non-identity write path*, with replay mitigation attributed to client-side dedupe by row `id` (`remote_session_controller.dart:911-914`). **Reject and keep the wording**, accepting that the contract over-claims. **Delete the claim** without a replacement. |
| **Consequence of not deciding** | A reader of the contract keeps believing a database constraint stops replay, and a deployer keeps believing the pre-apply duplicate check is optional. It is documentation, but it is documentation people act on at 3 a.m. |
| **Recommendation** | **Approve the drafted text** and keep the pre-apply duplicate check mandatory in the same breath. |
| **Files an approval would open** | `docs/implementation/api-contract.md:222-224` only. The guard work is already done and needs no approval (row SQL-06a below). |
| **Phase 4 action** | **Not applied.** The brief authorized the *docs* scope for the migration/test disagreement and the accurate guard; it did not authorize a contract wording change, so the wording was drafted and left. |
| **Status** | **AWAITING OWNER** |

### 7. TEST-01 — handler export + dependency injection

| Field | Content |
|---|---|
| **Decision** | Whether to refactor the Edge Function handlers so tests can **execute** them. Today 4 handlers are bare top-level `Deno.serve(...)` with no export and build a module-global memoised service-role client (`_shared/auth.ts:45 let cachedClient`, `:47-65 getServiceClient()` from `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY`), so the suite pins **source text** instead of running code. |
| **Options** | **Approve the sequenced 6-step proposal** in `_work/p4-test01.md`: extract each `case` body into a `handler.ts` module (explicitly *not* an env-flag guard around `Deno.serve`), inject `HandlerDeps { db, audit, now, uuid }` with a `defaultDeps()` production implementation, add a ~150-line `fake_postgrest.ts` sized to the measured builder/await surface, write executed tests per risk, then retire each source pin **only** when its executed equivalent exists. Cost 4–6 engineer-days; `device-command` first. **Keep the pins** and accept the label "source-level pinning, not handler execution". **Do neither**, i.e. leave it open indefinitely. |
| **Consequence of not deciding** | The class of bug the pins cannot catch — "right module, wrong variable", "predicate called but result ignored", "correct order with wrong argument" — remains untested. The 5 pins will still fail if a refactor *drops* a call, which is real protection, just not the protection the file's name suggests. |
| **Recommendation** | **Approve, sequenced**: start with `device-command` (highest-risk decision site, already has the cleanest seam via `decideEnforcement`), and never delete a pin before its executed replacement is green. |
| **Files an approval would open** | `supabase/functions/device-command/index.ts` → `…/device-command/handler.ts`; then `family-admin`, `remote-session`, `account`; `_shared/auth.ts` (`getServiceClient()` → injectable); new `supabase/functions/_shared/fake_postgrest.ts`; `supabase/functions/handler_wiring_test.ts` (pins retired one at a time). |
| **Phase 4 action** | **Handlers left unchanged** — implementation was not authorized, so this deliverable is a proposal, exactly as the brief's fallback clause directs. |
| **Status** | **AWAITING OWNER** (approval for implementation; the *proposal* itself is delivered) |

### 8. Commit / branch / push / migration apply

| Field | Content |
|---|---|
| **Decision** | Whether and how the Phase 4 tree becomes a commit, and when the pending migrations are applied to the hosted project. |
| **Options** | **Commit as-is** (25 entries: 15 already staged by the IDE, 2 worktree-only, 8 untracked — see `phase-4-report.md` §2). **Commit after selective unstaging** (the 2 unstaged files are the controller fix and the chain README; they are the substance of the phase). **Split commits by workstream.** **Push** as a separate act. **Apply migrations** as a third, distinct act, only after rows 1–7 are decided. |
| **Consequence of not deciding** | The work stays uncommitted and therefore unrecoverable-by-clone (which is also EVD-01). Nothing is applied, so HOST-01 stays open. |
| **Recommendation** | Commit the phase as one commit, **before** any Phase 5 edits, then keep deploy and apply as separate owner acts. Re-measure the digest immediately before committing: `b39d63a5…` pins on-disk bytes and two files carry an `LF → CRLF` warning (GIT-EOL-01). |
| **Files affected** | All 25 Phase 4 paths; the digest and `.tools/p4-end-status.txt` are the reconciliation record. |
| **Phase 4 action** | **None.** No `git add`, commit, branch, tag or push by the coordinator; HEAD is `953b337…` at start and at end. The Supabase CLI was never invoked; hosted inspection was `SELECT`-only through the dashboard. |
| **Status** | **AWAITING OWNER** |

---

## Part 2 — additional decisions Phase 4 surfaced (beyond the brief's eight)

### 9. PERF-01a — adopt the faster sweep batch shape? *(new)*

| Field | Content |
|---|---|
| **Decision** | Whether to replace the two `delete … using (select … limit)` statements in `20261030000300_retention_sweep.sql:119-130` and `:134-143` with the `id = any(array(select …))` shape. Phase 4 proved the two shapes delete **identical row sets in identical order** (one distinct set digest, returning-order digest and ctid-visit digest per table across 4 arms × 2 reps; 12/12 pairwise diffs 0/0; 10000/10000 positional agreement), and measured the speed-up at 10 000-row batches: `webrtc_signals` 75.534 → 48.429 ms, `audit_logs` 83.229 → 38.112 ms. |
| **Options** | **Approve as a pre-first-apply edit** to the migration (recommended — hosted is entirely pre-Phase-1, so no second migration and no extra provenance entry). **Approve as a new follow-up migration.** **Reject and keep the shipped shape.** **Approve only together with the `tests/74` companion assertion** that pins the *behavioural* invariant (same deleted-id set across shapes) instead of the `%10000%` text. |
| **Consequence of not deciding** | Nothing breaks — the shipped shape is correct and linear; it is simply slower on a large cold heap. The unresolved comment at `:62` (SWP-01, "at most 10 000 rows looked up and deleted per DELETE" is false for the target side, which full-scans 140 006 / 200 026 rows) also stays unresolved. |
| **Recommendation** | **Approve as a pre-first-apply edit, bundled with the test assertion and the `:62` comment correction**, and re-measure on a staging copy of the hosted instance before scheduling anything. Buffers get worse (webrtc 13 670 → 41 050, audit 13 945 → 39 566) while dirty pages get much better (audit 1 724 → 4) — that trade is worth a decision, not an assumption. |
| **Files an approval would open** | `supabase/migrations/20261030000300_retention_sweep.sql:119-130`, `:134-143`, `:62` (comment); `supabase/tests/74_sweep_indexes_and_repeatability.sql`; `supabase/tests/72_retention_sweep.sql` (counts unchanged — same rows). Proposal: `docs/implementation/proposals/phase4-retention-sweep-batch-shape.sql`. |
| **Phase 4 action** | **Nothing adopted.** The migration is byte-identical to HEAD. |
| **Status** | **AWAITING OWNER** |

### 10. KOT-02 — how to fix the duplicated `enforcementMode()` *(new framing)*

| Field | Content |
|---|---|
| **Decision** | The two copies (`PolicyApplier.kt:229-233`, `GuardianService.kt:668-674`) cannot currently disagree, but they also cannot be tested: Phase 4 established that this is **not** a missing test file, it is an unreachable prerequisite — `android/app/build.gradle.kts:93` gives the JVM test source set `junit:4.13.2` and nothing else (no Robolectric, no Mockito, no `testOptions`), and both helpers read `DevicePolicyManager` / `isAdminActive`. |
| **Options** | **A — extract a pure function** `EnforcementMode.of(isDeviceOwner, isAdminActive)` and unit-test that; both call sites pass their own booleans. No new dependency. **B — add Robolectric/Mockito** to the test stack and test the helpers in place (a dependency change, and a bigger blast radius). **C — leave the duplication** and document the invariant. **D — delete one copy** and have `GuardianService.kt:503` call `applier.enforcementMode()` (no test at all — strictly worse than C unless A is done). |
| **Consequence of not deciding** | A drift hazard that is currently benign stays benign-but-unpinned, and the Phase 2/3 docs keep describing the blocker as "needs a Gradle-capable workstation", which KOT-01 has now refuted. |
| **Recommendation** | **A.** It makes the rule testable *because* it is pure, which is also the pattern Phase 2/3 established for `decideEnforcement` and `canDeleteZone`/`canPurge`. |
| **Files an approval would open** | `android/app/src/main/java/com/parentcontrol/parent_control/PolicyApplier.kt:229-233`; `…/GuardianService.kt:668-674` and its call site `:503`; a new `…/policy/EnforcementModeTest.kt`; `android/app/build.gradle.kts` **only** if option B is chosen. Plus the stale citation corrections in `phase-2-governance.md:104-106`, `:114-116` and `phase-2-open-gaps.md:53`. *(2026-11-03 correction: the source directory is `android/app/src/main/kotlin/com/parentcontrol/parent_control/`, not `java/` — measured with `find android/app/src -name 'PolicyApplier.kt'`. The prospective line numbers were approximately right: after option A the rules sit at `PolicyApplier.kt:228-234` and `GuardianService.kt:668-670`, and the test landed at `android/app/src/test/kotlin/com/parentcontrol/parent_control/EnforcementModeTest.kt` (no `policy/` package).)* |
| **Phase 4 action** | **Code left unchanged**, with the reason recorded (brief §4's own fallback clause). `git diff HEAD --stat -- android/` is empty. *(2026-11-03: that sentence described the Phase 4 tree and is no longer true of this tree — option A was approved and implemented in Phase 5, so `android/` now has changes.)* |
| **Status** | **AWAITING OWNER** *(2026-11-03: DECIDED — owner approved option A; implemented and tested this phase, see `phase-5-owner-decision-log.md`.)* |

### 11. Device execution authorization (AND-01)

| Field | Content |
|---|---|
| **Decision** | Whether, when, and on which hardware the 75-row Android validation plan may be executed. |
| **Options** | **Authorize the full matrix.** **Authorize §7's advisory high-risk subset first** (parent/child pairing → consent + visible-mic FGS → parent End → force-stop recovery). **Authorize nothing yet**, noting that some rows are blocked regardless until migrations/deploys land (NET-07, ZONE-06/07) or a second physical device / relay exists. |
| **Consequence of not deciding** | The plan stays 100 % `NOT RUN` with blank *Actual* columns, so no device behaviour is verified for this release; the deployment gate keeps an unvalidated side. |
| **Recommendation** | Authorize the §7 subset on the existing parent emulator + child device **after** row 8 (commit) and **before** any apply, and treat the migration-dependent rows as explicitly deferred. |
| **Files affected** | None — this is an execution authorization. Evidence would be added into the plan's own *Actual* and *Status* columns, which are intentionally blank now. |
| **Phase 4 action** | **NOT IN SCOPE** by the brief's own words ("Do not install an APK or begin physical-device execution without explicit authorization. Do not create a build"). No APK installed, no device run, no build created; builds remain the build owner's. |
| **Status** | **NOT IN SCOPE** (Phase 4) → **AWAITING OWNER** for any future phase |

### 12. EVD-01 — commit the evidence, or accept workstation-only artifacts? *(new)*

| Field | Content |
|---|---|
| **Decision** | Phase 4 cites `.tools/*` logs and `build/app/test-results/*.xml` as its primary evidence, and **both paths are gitignored** (`.gitignore:54` `**/build/`; `.tools/` ignored) — verified: zero tracked files under `build/`. Should selected evidence be copied into the repository so the claims survive a clone? |
| **Options** | **Commit a `docs/implementation/evidence/phase4/` folder** with the log tails and the 5 XML files. **Keep evidence workstation-local** and accept the durability gap (which is the mechanism behind the Phase 1 "missing test artifacts" defect). **Publish digests only** (sha256 of each log in the report, so tampering is detectable even though content is not preserved). |
| **Consequence of not deciding** | Every Phase 4 PASS number is unverifiable by anyone who does not have this machine — which is exactly the defect class Phase 1 was criticised for. |
| **Recommendation** | **Digests now, selected logs at commit time** (row 8), so the numbers are checkable without turning the repo into a log store. |
| **Files affected** | `docs/implementation/evidence/phase4/**` (new) or `phase-4-regression-matrix.md` (digest column). |
| **Phase 4 action** | **NOT IN SCOPE** — copying logs into the tree is a repo-content change outside the brief; the gap is recorded instead. |
| **Status** | **AWAITING OWNER** |

---

## 3. Register summary

| # | Item | Brief says OWNER-ONLY? | Status after Phase 4 |
|---|---|---|---|
| 1 | PRIV-01 child retention scope | yes | **AWAITING OWNER** |
| 2 | GOV-02 / D1 abandoned-session pair | yes | **AWAITING OWNER** |
| 3 | SQL-01 / R3 de-hardening rollback | yes | **AWAITING OWNER** (quarantined, NOT RUN) |
| 4 | SQL-04 bounded execution / procedure / cron | yes | **AWAITING OWNER** |
| 5 | SQL-05 atomic delete+audit RPC | yes | **AWAITING OWNER** (mitigation in force) |
| 6 | SQL-06 contract wording | yes | **AWAITING OWNER** (text drafted) |
| 7 | TEST-01 handler export + DI | yes | **AWAITING OWNER** (proposal delivered) |
| 8 | Commit / branch / push / migration apply | yes | **AWAITING OWNER** |
| 9 | PERF-01a batch shape adoption | new (same migration surface as 4) | **AWAITING OWNER** |
| 10 | KOT-02 duplicate-helper resolution route | new framing | **AWAITING OWNER** |
| 11 | Device execution | no — excluded by the brief | **NOT IN SCOPE** (Phase 4), awaiting owner later |
| 12 | EVD-01 evidence durability | new | **AWAITING OWNER** |

**APPROVED: 0. REJECTED: 0.** No item was self-approved, no behaviour was changed to pre-empt a decision, and no
workstream was left silently half-done: rows 1–10 were stopped or delivered-as-proposal, and rows 11–12 are
labelled with the reason.

Order of dependency, for whoever picks this up: 3 → 1 → 2 → 6 → 5 → 4 + 9 (one migration edit, decided together)
→ 10 → 7 → **8 (commit)** → **11 (device run)** → **apply** → the read-only re-check that closes HOST-01.
