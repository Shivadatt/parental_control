# PHASE 5 — owner decision log

Every ruling below was obtained by an explicit answer. None is inferred from
silence, from a previous recommendation, or from an approval given to a different
workstream (brief §3). Where a ruling conflicts with another, the conflict is
recorded rather than resolved by the coordinator, and the stricter prohibition wins.

Date of intake: 2026-11-03. Owner: the project owner in this session. Recorder:
coordinator.

---

## 1. PRIV-01 — child retention-report scope · **decided: A**

| Field | Content |
|---|---|
| **Question put** | Should the retention/privacy report be (A) scoped to what the caller is actually allowed to see — family counts for a parent, device-only counts for a child, with project-wide sweep totals withheld from non-owners — or (B) something else? |
| **Ruling** | **A.** Implement child/device-scoped retention counts with an explicit `scope`; no global sweep totals in non-owner responses; WORD-02 uses the same three-state scope; server tests for parent / child / wrong-family / unauthenticated; UI tests for the disclosure; keep service-role access server-side. |
| **Implemented** | `supabase/functions/account/retention.ts` + `index.ts` emit `scope` ∈ {`family`, `device`, `not_reported`} and gate `last_sweep` totals to the family-owner parent; `lib/features/settings/*` renders the three states. |
| **Tested** | Deno S3 — `account/scope_test.ts`, 17 cases; Flutter S2 — `retention_scope_disclosure_test.dart` 11 cases, `account_privacy_controller_test.dart` 7 cases. |
| **Not done** | nothing deployed; no hosted read of any count. |
| **Status** | **IMPLEMENTED + TESTED — UNAPPLIED.** |

## 2. SQL-05 — atomic audited zone delete · **decided: approve the atomic RPC**

| Field | Content |
|---|---|
| **Question put** | Approve converting the Phase 3 proposal into a `service_role`-only `SECURITY DEFINER` RPC so the zone DELETE and its `zone_deleted` audit row commit or roll back together? |
| **Ruling** | **Approve**, with the brief's constraints: preserve trusted actor attribution, keep `family-admin` behaviour, and add executable tests for success / audit failure / authorization failure / zero-row, plus handler wiring tests. |
| **Implemented** | `supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql` → `public.delete_safe_zone_audited(uuid, uuid) → jsonb`; `family-admin/index.ts` switched to the single RPC call. |
| **Tested** | `supabase/tests/76_zone_delete_atomic_rpc.sql` (773 lines) inside the 33-file chain, green on three fresh databases (run5/run6/run9) plus the closing run10; negative control N2 measured red; Deno S4 (17 cases) for the handler and wiring. |
| **Deliberately not done** | not applied anywhere hosted; the Phase 3 stopgap module was **kept** in the tree rather than deleted, so the fallback remains reviewable. |
| **Status** | **IMPLEMENTED + TESTED — UNAPPLIED.** |

Note for whoever deploys: the handler now **depends** on this function. Deploying
the Edge Function without the migration turns every `delete_zone` into a 500
(fail-closed, no unaudited delete) rather than restoring the old two-write
behaviour. Ordering is in `deployment/manifest.md` §4.

## 3. SQL-04 / PERF-01a — retention sweep · **decided: faster shape only; bounded execution REFUSED**

| Field | Content |
|---|---|
| **Question put** | (a) adopt the `id = any (array(select … limit v_batch))` DELETE shape? (b) adopt bounded execution so a large backlog can commit partial progress? (c) keep or drop the function? |
| **Ruling** | **(a) yes, (b) no, (c) keep the function.** The owner approved the faster shape only and explicitly refused bounded execution. |
| **Implemented** | shape adopted for `webrtc_signals` and `audit_logs` in `20261030000300`; SWP-01's over-claiming comment corrected in place and given provenance. |
| **Tested** | `tests/74` §5 — behavioural row-set, batch-order and repeatability assertions comparing shipped vs previous shape, now actually executing (NOTICE `:934`; previously `:440` of a 934-line file, i.e. never run). |
| **STOPPED** | bounded execution / partial-commit: **not implemented**, by ruling. One call remains one transaction over the whole backlog, and the migration comment says so. **No cron installed** locally or hosted. |
| **Status** | **IMPLEMENTED + TESTED — UNAPPLIED** (shape); **STOPPED** (bounded execution, scheduling). |

## 4. TEST-01 — handler export + dependency injection · **decided: approve, device-command first**

| Field | Content |
|---|---|
| **Question put** | Approve the six-step refactor in `_work/p4-test01.md`, starting with the `device-command` handler? |
| **Ruling** | **Approve, device-command first.** Explicit DI (fake RPC / audit / clock / UUID), real handler tests, no environment-flag shortcuts, authorization and response-envelope behaviour preserved. |
| **Implemented** | `supabase/functions/device-command/handler.ts` (449 lines) with injected deps; `index.ts` reduced to an adapter; `_shared/fake_postgrest.ts` (643 lines) as the fake. |
| **Tested** | S3 — `handler_test.ts` 24 cases green; negative control N1 red exactly on the two authorization cases; `handler_wiring_test.ts` 5 cases pin the adapter. |
| **Status** | **IMPLEMENTED + TESTED.** |

## 5. GOV-02 / D1 — abandoned-session representation · **decided: ratify the pair as-is**

| Field | Content |
|---|---|
| **Question put** | Ratify the existing `ended_by` / `ended_reason` representation, or change it? |
| **Ruling** | **Ratify as-is.** Implement only an approved representation — and since the approval was "keep it", no code change was authorised. |
| **Action** | Documentation and consumer verification only. The pair convention (`ended_reason = 'abandoned'` with `ended_by = null` meaning "the server did it") is stated at `supabase/migrations/20261030000100_abandoned_session_sweep.sql:26-29` and written at `:126-127` (its audit detail carries the same reason at `:148`); read server-side at `supabase/functions/remote-session/guard.ts:133,150,153`. **Dart side, measured by grep rather than inherited:** `ended_reason` is parsed into `RemoteSession.endedReason` (`lib/data/models/remote_session.dart:88,110,189,209`), displayed at `lib/features/child/child_session_page.dart:737-738` and `lib/features/remote_assistance/remote_session_page.dart:656`, forwarded into state at `lib/features/remote_assistance/remote_session_controller.dart:715`, and locally written as `'ended_by_parent'` at `:2440` / `:2474`. **`ended_by` has no Dart field at all** — `grep -rn 'endedBy' lib` returns nothing — so it is read by no client and branches on nothing. Ratifying the pair therefore changes no behaviour, which is the whole point of a ratification. |
| **Status** | **RATIFIED — no implementation required, none performed.** |

## 6. SQL-01 / R3 — de-hardening rollback statements · **decided: never sanction R3**

| Field | Content |
|---|---|
| **Question put** | Should the de-hardening rollback statements (which re-grant client DELETE / re-add the delete policy) ever be sanctioned for execution? |
| **Ruling** | **Never.** R3 is not sanctioned. |
| **Action** | The statements remain quarantined in the proposals/notes layer. None was executed. None was executed "as a test" against hosted data — brief §5 forbids that outright, and this ruling closes the residual possibility of it being proposed again as a dry run. |
| **Related honest note** | `tests/71_phase1_rollback_privileges.sql` tests the *safe* rollback path's privilege consequences. It was **extended** for the SQL-05 chain integration, not weakened; the brief's "do not weaken `tests/71`" constraint is satisfied and the body-count pin got stricter (4 → 5). |
| **Status** | **STOPPED / permanently refused.** |

## 7. SQL-06 — contract wording for the replay index · **decided: approve the drafted wording**

| Field | Content |
|---|---|
| **Question put** | Approve the wording drafted in `_work/p4-docs-sql06.md` §3, which describes replay protection as conditional on the `(session_id, sequence)` unique index actually existing? |
| **Ruling** | **Approve the drafted wording**, and preserve the mandatory duplicate pre-check; keep `tests/75`. |
| **Implemented** | `docs/implementation/api-contract.md` §5 carries it with a dated note that every citation was re-verified against the named files rather than copied from the draft: pre-check `20261030000200:478-486`, skip NOTICE `:492`, "reported, never deleted" contract `:474`. |
| **Follow-through the approval implies** | `deployment/manifest.md` §2 gained the **pre-apply** duplicate-count query, because the wording is only honest if the operator can know the index's status before applying — previously the manifest only checked afterwards. |
| **Kept** | `tests/75_signaling_replay_index_duplicate_guard.sql` (218 lines) unchanged in the chain; its two NOTICEs (`:185`, `:216`) appear in every green run. |
| **Status** | **IMPLEMENTED (documentation) + citation-reverified. The hosted duplicate count has still never been run — that is HOST-01's remaining half.** |

## 8. KOT-02 — duplicated `enforcementMode()` · **decided: A, extract a pure function**

| Field | Content |
|---|---|
| **Question put** | A — extract a pure `EnforcementMode.of(isDeviceOwner, isAdminActive)` and unit-test it; B — add Robolectric/Mockito; C — leave the duplication; D — delete one copy without a test. |
| **Ruling** | **A**, with the explicit constraint "do not add Robolectric or Mockito unless Option B is explicitly approved". |
| **Implemented** | `android/app/src/main/kotlin/com/parentcontrol/parent_control/EnforcementMode.kt` (new); both call sites delegate — `PolicyApplier.kt:228-234` and `GuardianService.kt:668-670` (heartbeat object at `:503`). `android/app/build.gradle.kts` **unchanged**. |
| **Tested** | S5 — `EnforcementModeTest.kt` 4 JVM cases; full `:app:testDebugUnitTest` green (6 classes / 39 tests / 0 failures). |
| **Status** | **IMPLEMENTED + TESTED** (JVM only; no device execution — see #9). |

## 9. AND-01 / Gate B — device execution · **decided: no device execution**

| Field | Content |
|---|---|
| **Question put** | Authorise Gate B — building and running the app on the QA devices for the Phase 4 validation plan? |
| **Ruling** | **No device execution yet.** |
| **Action** | **STOPPED.** No APK built for validation, no emulator/device driven, no `adb` run against QA hardware. No device row is marked PASS in any Phase 5 artifact. Nothing was bypassed because nothing was attempted: force-stop, permission revocation, notification visibility and child-consent legs all remain unverified by execution. |
| **Consequence** | The Kotlin change in #8 is *unverified on hardware*. It is verified by JVM tests only. `phase-4-android-validation-plan.md` stays the ready-to-execute plan for a future Gate B. |
| **Status** | **STOPPED — awaiting owner authorization.** |

## 10. Gate A git action · **decided: NO COMMIT — leave everything uncommitted**

| Field | Content |
|---|---|
| **Question put** | Commit the Gate A changes, or leave them uncommitted for review? |
| **Ruling** | **No commit.** |
| **Action** | HEAD is still `953b337bb8e24a46dd5ddfdf7b281b2159d73c2d` at the end of the phase, exactly as at the start. No push, no branch, no tag. The coordinator ran no `git add`; two previously-untracked files entered the index mid-session through the editing environment, recorded as observed in `phase-5-report.md` §2. No `reset`, `clean`, `stash`, destructive `checkout` or `restore` was used at any point. |
| **Status** | **OBEYED.** |

## 11. Hosted deployment · **decided: none**

| Field | Content |
|---|---|
| **Question put** | Deploy anything to the hosted Supabase project? |
| **Ruling** | **None.** |
| **Action** | Zero hosted operations in this phase — no migration applied, no Edge Function deployed, no setting changed, no cron scheduled, no production read or write. The Supabase CLI binary exists on this machine and was **never invoked**; there was not even a read-only dashboard inspection this phase (so the last hosted observation remains the 2026-10-30 read-only audit in `_work/p4-hosted.md`, which found production entirely pre-Phase-1). **HOST-01 is therefore not fixed and is not reported as fixed.** |
| **Status** | **OBEYED; HOST-01 remains an open P1 blocker.** |

## 12. EVD-01 — evidence durability · **decided: commit selected evidence — CONFLICTS WITH #10**

| Field | Content |
|---|---|
| **Question put** | Should the selected evidence (Gradle JUnit XML, logs, digests, exact commands) be committed, or accepted as workstation-only artifacts? |
| **Ruling** | **Commit selected evidence.** |
| **Conflict** | Ruling #10 forbids any commit. Both cannot be obeyed. |
| **Resolution used** | The stricter prohibition was obeyed: **the evidence pack was prepared but not committed.** The coordinator did not treat #12 as an override of #10, because #10 is explicitly about the commit action and #3 of the brief forbids inferring approval. The pack is complete and commit-ready so that a single owner action closes it: `git add docs/evidence/phase5 && git commit`. |
| **What "selected" excluded** | no `.env`/token/key/JWT/service-role value (pattern scan across every log: `eyJ…`, `service_role_key`, `SUPABASE_KEY`, `password`, long `Bearer` — zero matches); not the whole `.tools/` tree (it holds the ~200 MB PostgreSQL binary and data dirs); no build outputs beyond the six JUnit XML files; no APK. |
| **Status** | **PREPARED — NOT COMMITTED; conflict escalated to the owner for a tie-break.** |

---

## 13. Decisions that were *not* taken in this phase (and must not be inferred)

| Item | Why it stays open |
|---|---|
| Applying `20261030000100`, `20261030000200`, `20261030000300`, `20261103000100` | owner ruled no deployment (#11); HOST-01 blocker stays |
| Deploying the `account`, `family-admin`, `device-command` Edge Functions | same |
| Installing a scheduled retention/abandoned sweep (pg_cron or dashboard job) | brief §6 requires separate authorization; not requested, not given |
| Dropping the redundant non-unique `webrtc_signals_session_sequence_idx` | the migration leaves it deliberately; needs an owner-approved cleanup decision |
| Deleting `delete_zone_atomicity.ts` now that it is unwired | it is the reviewed quarantined fallback; deletion is a scope change nobody approved |
| Any device/Gate B execution | #9 |
| Committing anything | #10 |
| Starting Phase 6 | brief §15 — the phase stops and waits |

## 14. Register summary

| Ruling | Obeyed by | Outcome |
|---|---|---|
| 7 approvals (#1, #2, #3-partial, #4, #7, #8, #12) | implementation + tests | 6 items IMPLEMENTED-TESTED-UNAPPLIED, 1 (EVD-01) prepared but blocked |
| 3 refusals (#3-bounded execution, #6, #9) | deliberate non-action | STOPPED, documented so they cannot be silently re-proposed |
| 2 prohibitions (#10, #11) | zero git actions, zero hosted calls | OBEYED |
| 1 ratification (#5) | consumer evidence instead of code | RATIFIED, no change |
| 1 unresolved conflict (#12 vs #10) | disclosed, escalated | owner tie-break needed |
