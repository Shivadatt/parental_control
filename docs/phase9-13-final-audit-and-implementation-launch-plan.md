# Phase 9.13: Final Consolidated Audit, Owner Decision Sheet and Implementation Launch Plan

**Document class:** Final One-Pass Audit, Owner Decision Sheet and Implementation Launch Package (Governance, Audit, Planning).  
**Task Reference:** Phase 9.13 — the terminal audit pass of the Phase 9 series; no successor audit phase is created by this document.  
**Repository:** `D:\parentcontrol_app` (`main`, HEAD `a2faa5fb70f84638359154c68d19ce304fadab36`).  
**Backend Project:** Supabase `parent-control-prod` (`hhqgreaoqulmfwfwarhc`) — **NOT ACCESSED** in this phase (no dashboard, CLI, SQL or network operation performed).  
**Date:** 2026-11-06.  
**Predecessors:** [`docs/phase9-10-consolidated-release-readiness-governance-blocker-review.md`](phase9-10-consolidated-release-readiness-governance-blocker-review.md), [`docs/phase9-11-evidence-contradiction-and-decision-readiness-report.md`](phase9-11-evidence-contradiction-and-decision-readiness-report.md), [`docs/phase9-12-owner-decision-packet.md`](phase9-12-owner-decision-packet.md).  
**Release Verdict Inherited:** **NO-GO FOR GENERAL RELEASE** (unchanged from `phase-9-owner-decision-register.md:412`); GO for local read-only work and for the offline verification baseline.  
**Companion Documents:** canonical register [`phase-9-owner-decision-register.md`](../phase-9-owner-decision-register.md) and its byte-identical mirror [`docs/implementation/phase-9-owner-decision-register.md`](implementation/phase-9-owner-decision-register.md), both unmodified.  

**Strict Governance Invariant:** This pass authorizes nothing. Every "recommended" label below is a recommendation only; architecture approval is not implementation permission; no approval may be inferred from silence, from a recommendation, or from receiving this document. Hosted state, device state and the 75/75 QA matrix are reproduced from existing evidence, not freshly verified. Historical reports are not rewritten.

---

## A. Executive Decision Summary

1. **The project is not blocked by missing code as much as the Phase 9 documentation chain implies.** Read-only inspection at HEAD shows that several defects still recorded as "open" already have an implementation in the repository that has never been built, deployed or device-verified. The microphone foreground-service type exists in the manifest, the media-teardown-on-connection-loss path exists in the controller, and the hosted session-clock fix (F1) exists in the Edge Function source. These are **execution and deployment gaps**, not design gaps. That materially shortens the safe path to a working product.
2. **Three genuine product gaps remain, and all three are already fully specified by approved decisions.** DEC-12 (daily screen-time quota enforcement, bedtime hard suspension, 10-minute emergency pass) has **zero device-side implementation** — the quota field is parsed and stored but has no reader in the enforcement path; bedtime is explicitly informational-only; no emergency-pass code exists anywhere. DEC-13's mandatory Device Owner safe exit (GATE-EXIT-01) has **zero implementation**. DEC-14 (FCM wake-up) has **zero implementation and zero provisioning**. These are the shortest path to a real product, and they need one thing: the Phase 10 implementation grant.
3. **One security exposure is live and closable with a decision the owner has already been asked to make.** `public.safe_zones` retains direct-client `DELETE` on hosted because DEC-02's four migrations are demonstrably unapplied (`phase-9-owner-decision-register.md:317-320`). This is the single highest-value hosted action and it is gated only by J-1.
4. **The audit cycle has a defined end.** This document is the last audit artifact. The next owner action is a decision batch (Section C), not another review. Fourteen audit/governance documents now describe the same 11 open decisions; Section C consolidates them into one sheet so the owner can rule on all of them in a single pass.
5. **The first task that can start today, without any new authorization, is the local hermetic verification baseline** — offline test execution is expressly `PERMITTED (Green)` (`phase-9-owner-decision-register.md:97`) and all four suites plus a bundled local Postgres are present and runnable. It costs no approvals and produces the pass/fail floor every subsequent task is measured against. The first **product-code** task (T-B-01) requires the explicit Phase 10 grant; this prompt is not that grant.
6. **Version traceability is broken and will invalidate device evidence.** `pubspec.yaml:19` records `1.0.0+1` while all historical microphone evidence binds to build `4005`. Any DEC-03 QA execution must be preceded by a version-pinning decision (T-B-07), otherwise new evidence will be as unreconcilable as the old.

---

## B. Consolidated One-Pass Audit Results

Each subsection states what was inspected in this pass, what is true at HEAD, and what remains dependent on historical evidence that was **not** re-verified.

### B.1 Decision register coverage (DEC-01 … DEC-16)

| Decision | Registered status | Implementation state at HEAD (this pass) | Consequence for launch |
|---|---|---|---|
| DEC-01 Phase 5 evidence durability | APPROVED (Choice B) | Local-only evidence accepted; GAP DUR-01 open | Documentation consequence only |
| DEC-02 Hosted migration/deployment | **PENDING / BLOCKED (P1)** | 4 migrations absent on hosted; 3 registered functions undeployed | Gates Section E Category C |
| DEC-03 Android QA hardware testing | **PENDING / BLOCKED (P1)** | 75/75 QA rows `NOT RUN`; no APK built in this pass | Gates Category D |
| DEC-04 Preflight formulation | READY / CARRIED FORWARD | 5 preflights formulated; `NOT FOUND` as `.sql` artifacts (0 preflight files under `supabase/`) | Execution gated by DEC-02 |
| DEC-05 Retention sweep scheduler | APPROVED (Choice B, on-demand only) | `cron` function directory exists locally (`supabase/functions/cron/index.ts`); no scheduler enabled | On-demand invocation only |
| DEC-06 … DEC-11 | CARRIED FORWARD | Standby specifications, no independent ruling | J-8 |
| DEC-12 Screen time / bedtime | APPROVED (D1-B, B1-B, O1-C, P1-A, DEFER) | **Not implemented** — see B.8 | Primary product work |
| DEC-13 Device Owner / Managed Mode | APPROVED (Option B) + safe exit as RELEASE BLOCKER | **Safe exit not implemented** — see B.9 | Blocks Managed Mode release |
| DEC-14 Push / FCM | APPROVED (Option B) | **Not implemented, not provisioned** — see B.7 | New authorization needed (J-4 adjacent) |
| DEC-15 Website filtering | APPROVED (Option D — deferred) | Correctly absent | Excluded from launch scope |
| DEC-16 Screen mirroring / recording | APPROVED (Option A — excluded) | Correctly absent | Excluded from launch scope |

### B.2 Blockers and gates

P1 release blockers remain exactly two, unchanged from the register (`phase-9-owner-decision-register.md:412`): **GAP HOST-01** (hosted migration/deployment/executed-SQL state inconsistent — `safe_zones` direct `DELETE` exposure live) and **GAP AND-01 / GATE-B-01** (device functional verification never executed against a release candidate). GATE-EXIT-01 is an approved requirement and release blocker for Managed Mode specifically (`:455`). GATE-KEY-01 (release keystore) is `DEFERRED / NOT AUTHORIZED` (`:457`). Gate A is recorded `CLEARED (GO)` in `docs/implementation/phase-9-release-readiness.md:44` while every decision record simultaneously states "Phase 10 NOT AUTHORISED" and the operational matrix prohibits `flutter build` / `gradlew` / ADB (`phase-9-owner-decision-register.md:95-103`); source *editing* is not enumerated in that matrix at all. This is not a contradiction to exploit — it is the one governance ambiguity that must be resolved by an explicit ruling before any Category B task starts (J-2 / Section G).

### B.3 Flutter application architecture

`lib/` is organised as 17 feature directories under `lib/features/` (not 14; the "14 functional modules" phrasing in the project brief does not match the tree — `app_restrictions`, `audit_logs`, `auth`, `child`, `configuration`, `dashboard`, `devices`, `family`, `location`, `pairing`, `parent_shell`, `remote_assistance`, `role_selection`, `safe_zones`, `safety_alerts`, `screen_time`, `settings`). GetX bindings per feature, a route table in `lib/routes/`, and no route middleware or guards anywhere: unauthenticated navigation is prevented by redirect logic in controllers, not by a guard layer. There is no `darkTheme` in the theme configuration. `AppRoutes.parentSettings` (`lib/routes/app_routes.dart:25`, referenced once at `lib/routes/app_pages.dart:157`) is a dead route. Measured test inventory: 55 test files, 330 `test(` and 57 `testWidgets(` invocations, plus 4 `integration_test` entry points.

### B.4 Android native services, permissions, foreground services, lifecycle

`AndroidManifest.xml` declares `RECORD_AUDIO` (`:10`), `POST_NOTIFICATIONS` (`:11`) and `FOREGROUND_SERVICE_MICROPHONE` (`:15`); three foreground services, all `exported="false"` — `GuardianService` (`dataSync`, `:79-82`), `LocationTrackingService` (`location`, `:84-87`), `AudioAssistanceService` (`microphone` + `stopWithTask="false"`, `:89-93`); `ParentControlDeviceAdminReceiver` (`exported="true"`, BIND_DEVICE_ADMIN, `:95-105`); `BootReceiver` (`:107-115`); `MainActivity` exported with the `parentcontrol://auth-callback` deep link (`:49`, `:69-76`); `allowBackup="false"` (`:43`). `AudioAssistanceService.kt` (779 lines) implements a microphone-typed `startForeground` with pre-R fallback (`:623-629`), an `IMPORTANCE_LOW` ongoing notification with a Stop action (`:555-611`), a start gate that refuses capture without consent (`:249-261`) and a 15-second session watchdog (`:108`). **The MIC-01 foreground-service-type fix is therefore present in the source tree and is not present in build 4005 — the gap is build/install/verify, not code.**

### B.5 Pairing, authentication, sessions, authorization

Backend calls are envelope-wrapped through `lib/data/remote/edge_api.dart:19-57` and reach ten Edge Function directories. Verified call sites: `auth-bootstrap` (`supabase_auth_repository.dart:154-155`), `pairing` (`:219`, `:227`, `:243-255`), `device-register` and `family-admin` (`supabase_device_repository.dart:82-83`, `:108-109`, `:117-118`), `device-telemetry` (`:190-191`, `supabase_usage_repository.dart:74-75`, `supabase_location_repository.dart:78-79`), `device-policy` and `device-command` (`supabase_policy_repository.dart:41-42`, `:90-91`, `:126-127`), `remote-session` (`supabase_remote_session_repository.dart:36`, `:52`, `:111`, `:127`, `:143`, `:158`), `account` (`account_privacy_repository.dart:183`), zone delete (`supabase_location_repository.dart:148-149`). Four client-side repository methods have zero callers and duplicate live native paths (`device_admin_service.dart:87 applyPolicy`, `supabase_policy_repository.dart:111 acknowledgeCommand`, `supabase_usage_repository.dart:53 uploadUsage`, `supabase_location_repository.dart:71 uploadLocation`; live equivalents are reached from `GuardianService.kt:558`, `:610` and `NativeBridge.kt:132`).

### B.6 Supabase schema, RLS, RPCs, Edge Functions, migrations (verified locally this pass)

| Artifact | Measured |
|---|---|
| `supabase/migrations/*.sql` | 14 files, 3,903 lines |
| Tables created | 19, all in `public`: `profiles`, `families`, `family_members`, `devices`, `device_policies`, `device_commands`, `device_apps`, `device_pairing_tokens`, `pairing_requests`, `pairing_attempts`, `safe_zones`, `safe_zone_states`, `location_events`, `usage_daily`, `safety_alerts`, `audit_logs`, `remote_sessions`, `webrtc_signals`, `child_contact_ids` |
| `enable row level security` | 19 statements — one per table |
| `create policy` | 25 total (22 in `20260101000200_rls.sql`, 2 in `20261028000300_signaling_open_session.sql`, 1 in `20261030000200_phase1_authorization.sql`) |
| Authorization model | Private schema `private` with `revoke all … from anon, authenticated` and service-role usage only (`20260101000000_core.sql:7-13`); 24 `private.*` functions (RPC bodies + triggers) and 17 `public.*` functions (client-callable wrappers) |
| Realtime | `supabase_realtime` publication membership added guardedly for `device_commands`, `safety_alerts`, `remote_sessions`, `webrtc_signals` (`20260101000100_functions.sql:907-941`); access mediated by `private.realtime_topic_allowed` |
| Edge Functions | 10 deployable functions + `_shared` (17 modules) + `handler_wiring_test.ts`; `verify_jwt = true` for auth-bootstrap, pairing, device-register, device-policy, family-admin, remote-session, account; `verify_jwt = false` for device-command, device-telemetry (self-authenticating) and cron (`supabase/config.toml:61-95`) |
| Preflight `.sql` artifacts | **NOT FOUND** (0 files; the 5 preflight queries exist only as text in governance records) |
| CLI state | No `supabase/.branches`, no `.temp`, no migration lock — the repo carries configuration, not a linked project |
| Hosted truth | Reproduced, **not re-verified**: 9 functions hosted, newest deployment `2026-10-27T18:07:08Z`; DEC-02's 4 migrations `NOT APPLIED — VERIFIED`; 2 Stage-7 migrations verified in force 2026-11-05 (`phase-9-owner-decision-register.md:313-337`) |

### B.7 Realtime, FCM and notification architecture

Android-side notifications are local, channel-based and present: `audio_assistance_channel` (`AudioAssistanceService.kt:76`, id `4303`). **FCM does not exist in the product.** A source-level search of `lib/`, `android/` (excluding the Gradle build cache `android/.gradle/9.1.0/executionHistory/executionHistory.bin`) and `pubspec.yaml` yields zero Firebase/FCM references — no plugin dependency, no `google-services.json`, no messaging service. DEC-14 Option B is therefore approved architecture with 0 % implementation and, per its own record, `NOT PROVISIONED` for the Firebase project and the service-account secret (`docs/dec-14-fcm-owner-decision.md:60`, `:63`, `:9`). Out-of-band alert delivery currently depends on Realtime subscriptions holding an open app; hosted Realtime subscribe/deny behaviour is recorded `NOT TESTED` in `docs/api-contract.md:524` and remains unverified.

### B.8 Audio lifecycle, microphone privacy, background survival, endurance

Implemented and present at HEAD: consent-gated start, capture flag control, media teardown on exhausted ICE recovery (`remote_session_controller.dart:2040-2064` — `_exhaustIceRecovery` sets `media_connection_failed`, then `_pauseMediaAfterConnectionLoss` clears `_serviceConfirmed`, calls `_setCaptureActive(false)`, sets `sharingStopped` for the child role and tears the peer down), ICE restart with credential reissue before each attempt (`:1992`), permission watchdog timer (`:2108`), capture heartbeat and stats samplers (`:2248`, `:2273`), and `withdrawConsent()` (`:2194-2232`). **This directly contradicts the standing documentation** `docs/mic_only_test_report.md:167`, which states that on connection loss "neither the peer-state nor the ICE-state failure branch tears down capture or ends the session — they only set a warning." That statement is accurate for the build it observed and stale for HEAD. Two real gaps survive anyway: (a) nothing in this chain has ever run in an installed APK, so MIC-01/MIC-02 stay `NOT TESTED` and the four-state ladder stops at "source present"; (b) TURN credential refresh fires **only** on the failure path (`_refreshIceServers` call site is `:1992`; there is no periodic or pre-emptive refresh timer), so a long healthy session with a 600-second TTL (`supabase/functions/_shared/turn.ts:25-28`) would negotiate with stale credentials — moot today because `turn_configured:false` without relay env (`_shared/turn.ts:84-93`, relay `ABSENT`), relevant the moment J-4 is approved. Human audibility, 5-minute and 15-minute locked-screen endurance, and the microphone privacy indicator on ColorOS remain `NOT TESTED` / `NOT VERIFIED` and cannot be closed by any local means.

### B.9 TURN, STUN, WebRTC, cross-network

Offer constraints are receive-only on the parent (`OfferToReceiveAudio: true`, no sendonly, `remote_session_controller.dart:1283-1290`, `:1993-2000`), which matches the approved one-way architecture. STUN-only is the shipped default; ephemeral HMAC-SHA1 TURN credentials are generated correctly but never populated because the environment is unset. `docs/turn_configuration.md:317-318` carries the cost/operational framing. There is no repository artifact that provisions a relay, and no decision record covers TURN ownership (J-4). Cross-network assistance is therefore **unprovable, not merely unproven**: F4 is an infrastructure absence.

### B.10 Managed Mode, Device Owner, safe exit, enforcement

`EnforcementMode.kt` reports `none` / `device_admin` / `device_owner` and the client degrades honestly (`device.dart:415 isFullyManaged`). Suspension is applied through `DevicePolicyManager` in `PolicyApplier.kt` (`suspendPackages` `:299`, guard against suspending default home/IME `:323-337`, verification against DPM rather than trusting the request `:144`) with a critical-package immunity set (`PolicyEvaluator.kt` `PolicyGuard.CRITICAL_PACKAGES`, including `com.android.dialer`, `com.android.emergency`, launcher and IME families). **Safe exit is absent**: `clearDeviceOwnerApp` has zero occurrences in the repository and no in-app exit UI exists. GATE-EXIT-01 ("factory reset must not be the only supported consumer exit mechanism") is therefore an approved, mandatory, unimplemented release blocker. The Device Administrator tier DEC-13 ordered retired is still declared and still surfaces as an enforcement mode.

### B.11 Screen time, bedtime, emergency pass

DEC-12's three rulings have no device-side implementation: `dailyScreenTimeLimitMinutes` is parsed (`policy/PolicyJson.kt:16`) and modelled (`policy/PolicyModels.kt:43`) but has **zero readers** in `PolicyApplier.kt` or `GuardianService.kt` (verified by exhaustive grep; the only consumers are `lib/` UI controllers and the policy summary card); bedtime merely sets an informational flag with the applier's own comment "bedtime is stored but app suspension follows app rules" (`PolicyApplier.kt:369-370`); and no emergency-pass identifier of any kind exists (`emergency_pass`, `override_until` → 0 hits). Usage measurement data does exist (`UsageReporter.kt` uses `UsageStatsManager.queryUsageStats` with `INTERVAL_DAILY` and refuses to fabricate values), so the quota work has a real input to compare against. A fourth defect is hosted-adjacent but locally visible: `policyTargetsApps` (`supabase/functions/device-command/enforcement.ts:51-58`) recognises only `blocked_packages`, `app_rules[].blocked` and `block_all_except_allowed`, so a limits-only policy yields `desiredCount == appliedCount == 0` and `decideEnforcement` reports `enforced` falsely — this must be fixed in the same pass as the quota work, or correct enforcement will be reported as unenforced and vice versa.

### B.12 Automated tests and QA coverage

| Suite | Measured this pass | Runnable here |
|---|---|---|
| Deno (Edge Functions) | 15 `*_test.ts` files, 150 `Deno.test` | Yes — `deno 2.9.4` present |
| Flutter unit/widget | 55 files, 330 `test(` + 57 `testWidgets(` | Yes — Flutter 3.38.8 / Dart 3.10.7 |
| Kotlin JVM | 6 files, 39 `@Test` | Yes — JDK 17.0.16 (but `gradlew` execution is prohibited, see G) |
| Local SQL chain | `supabase/tests/`: 19 `.sql` test files + fixtures + 3 runners; bundled Postgres at `.tools/pgsql16` | Yes — runner auto-starts a disposable cluster, binds `127.0.0.1` only |
| `integration_test` | 4 entry points | Requires device/emulator → DEC-03 |
| CI | No `.github/workflows` (**NOT FOUND**); `scripts/local-ci.ps1` has 5 stages but machine-specific absolute paths at `:104-106` | Partial |

Coverage gaps that matter for launch: no test asserts quota/bedtime/emergency-pass behaviour (the features do not exist), no test asserts safe-exit behaviour, no offline test can prove APK inclusion or runtime audio, and `docs/implementation/phase-9-regression-matrix.md:35` still claims a "33-File SQL Chain" that is not reconcilable against the 19 `.sql` files actually present.

### B.13 Build configuration, signing, deployment, release

`android/app/build.gradle.kts:13-22` reads `key.properties` — **NOT FOUND** (only `key.properties.example`; `android/.gitignore:12` excludes it), with a debug-key warning path at `:24-33`; `minSdk`/`targetSdk`/`versionCode`/`versionName` are inherited from Flutter (`:50-53`) and `pubspec.yaml:19` says `1.0.0+1`. `android/settings.gradle.kts:5-8` requires `local.properties` — **NOT FOUND**; AGP 9.0.1, Kotlin 2.3.20; no product flavors. Consequences: a release artifact cannot currently be produced reproducibly, evidence-to-build traceability is broken (A.6), and GATE-KEY-01 stays deferred pending J-3/J-10 scope rulings.

### B.14 Git working-tree state (preserved exactly as found)

HEAD `a2faa5fb…` on `main`; 752 tracked files; `docs/evidence/` 154 tracked files, not ignored. `git status --porcelain` measured at 2026-11-06 11:4x: `A  docs/phase9-9-2-2-documentation-completion-acceptance-record.md`, `A  docs/phase9-10-…`, `A  docs/phase9-11-…`, `A  docs/phase9-12-owner-decision-packet.md`, `?? docs/phase9-13-final-audit-and-implementation-launch-plan.md`. **Index observation, recorded not corrected:** the Phase 9.10/9.11/9.12 reports were measured as untracked (`??`) earlier on 2026-11-06 and the 9.9.2.2 record as `AM`; they now read `A ` with `git diff --cached --stat` reporting 4 files / 1,438 insertions, and `.git/index` mtime `2026-11-06T11:13:20+0530`. No `git add`, `reset`, `commit`, `stash` or any other write command was issued by this pass, and no repository hook exists (`core.hooksPath` unset, no non-sample files in `.git/hooks`). The staging is therefore external to this audit pass — most plausibly the owner or a parallel session. It has been **left exactly as measured**: nothing was unstaged, committed or reverted. J-10 now concerns staged-but-uncommitted files rather than untracked ones; the underlying question (commit authorization) is unchanged. Both register copies remain byte-identical at SHA-256 `3a5d136b0f03331a41a465962841f88651e43a10fe37d435d9ce46865122bf0f`. Stash list empty (0 entries). `.gitignore:22 *.log`, `:53-54 build/`; `android/.gitignore:12 key.properties`; `core.autocrlf=true`; `.tools/` untracked (40,741 files / 5.4 GB) and holding the local Postgres used by the SQL chain. No file content was altered by this pass except the creation of this document.

---

## C. Consolidated Owner Decision Sheet (all eleven, single pass)

Rulings below are **recommendations only**. Each item is an independent decision; approving one does not authorize another.

| ID | Decision to make | Exact current state | Repository-supported choices | Consequence of approving | Consequence of refusing | Blocks | Recommendation (NOT approval) |
|---|---|---|---|---|---|---|---|
| J-1 / DEC-02 | Authorize hosted preflights, 4 migrations, 3 function deployments | `PENDING / BLOCKED`, 0 % executed; `safe_zones` direct `DELETE` live | Approve all / approve scoped (migrations 2+4 only) / refuse | GAP HOST-01 closes after verified post-application evidence | Exposure persists; NO-GO stands | Category C, and honest `enforced` reporting | **Approve with a scope limit**: preflights + migrations `20261030000200`/`20261103000100` first (they close the DELETE exposure), functions after |
| J-2 / DEC-03 | Authorize physical Android QA | `PENDING / BLOCKED`, 75/75 `NOT RUN` | Approve full matrix / approve audio-acceptance subset / refuse | GAP AND-01 closeable; MIC-01/MIC-02 verifiable | All functional claims stay `NOT TESTED` | Category D, Gates B and D | **Approve a staged subset**: install + indicator + audibility + 5/15-min endurance first |
| J-3 | Normalize severity lexicon (P0 vs P1) and the release-blocking set | Register carries "39 vs 38" P1 prose conflict (`:355`) | Adopt the two-P1 set as canonical / redefine | Unambiguous "ready" definition | Release criteria stay arguable | Section I | **Adopt exactly GAP HOST-01 + GAP AND-01 as P1**; make GATE-EXIT-01 P1-for-Managed-Mode; GATE-KEY-01 release-only |
| J-4 | Open a decision for TURN/relay infrastructure | No DEC covers it; `turn_configured:false`; relay `ABSENT` | Approve managed relay / self-hosted / defer STUN-only | Cross-network assistance becomes testable | Feature stays unprovable; scope it out of the promise | Category E | **Open a scoped decision document**; do not silently inherit it from DEC-02 |
| J-5 | Order/design the safe exit (GATE-EXIT-01) | Approved requirement, **zero implementation** | Approve design then implement / implement with review / defer | Managed Mode release becomes reachable | Managed Mode must stay off the release path | T-B-05, T-D-05 | **Order it in the first implementation wave** — it is the only release blocker that is pure local code |
| J-6 | Approve a scoped audio-acceptance test plan | 16 gaps recorded; no approved plan | Approve as drafted / amend / refuse | Device QA gets a defined, bounded pass criterion | DEC-03 approval would be open-ended | Category D quality | **Approve before DEC-03 execution**, else the QA grant has no acceptance shape |
| J-7 | Authorize 4 documentation-only staleness corrections | Present-tense stale statuses in circulation (C-30, C-31, C-32) and the MIC-02 branch claim (`docs/mic_only_test_report.md:167`) | Approve annotations / refuse | Implementers read accurate status | New work planned against stale facts | Nothing technical | **Approve annotation-only** (add "as of 2026-11-06, HEAD implements X; still NOT TESTED"), never rewrite history |
| J-8 | Rule on DEC-04 and DEC-06–DEC-11 | Register `:371-375` says PROPOSED; `:668-672` says APPROVED/CARRIED | Reaffirm / reclassify as non-decisions | Register self-consistency | Contradiction persists | Nothing technical | **Reclassify as records, not decisions** |
| J-9 | Choose the DEC-02 apply mechanism | `supabase_migrations` ledger absent (`42P01`); `20261028000200` non-idempotent (`:40-42`) | Dashboard SQL editor with manual ledger note / CLI `db push` / dry-run-then-apply | Double-apply risk becomes controlled | Migrations could re-apply undetected | Safety of J-1 execution | **Apply via dashboard editor with a written per-statement preflight/postflight record**; do not replay `20261028000200` |
| J-10 | Decide the fate of the staged governance files | 4 records now staged `A ` (1,438 insertions in the index, staged at 11:13 by an actor outside this pass — see B.14); this 9.13 report `??` | Commit / leave staged / commit and document the staging | Dates and contents acquire commit provenance | Staged-but-uncommitted state has no commit backing | Evidence durability | **Commit the governance series** as one record-keeping commit, and record who staged them |
| J-11 | Adjudicate two irreconcilable hosted-scope statements | `docs/api-contract.md:524` Realtime `NOT TESTED` vs 2026-10-26 subscribe/deny probe; preflights not `.sql` artifacts | Amend contract doc / re-probe under DEC-02 / mark both historical | One authoritative statement survives | Contradiction stays in force | Category C clarity | **Mark the 2026-10-26 probe historical and author preflight `.sql` artifacts as part of J-1 execution** |

**Independence preserved:** J-1 (hosted) and J-2 (device) remain separate and neither implies the other. J-4 (relay infrastructure) and the FCM provisioning decision in Section E are additional authorizations that no existing DEC grants. DEC-05 stays on-demand only. Silence, receipt of this document, or agreement with a recommendation grants nothing.

---

## D. Authoritative Blocker and Dependency Matrix

| Blocker / gap | Severity (per J-3 proposal) | Closed by | Also requires | Currently blocked by |
|---|---|---|---|---|
| GAP HOST-01 | P1 | T-C-02, T-C-03 | T-C-01 preflights, J-9 mechanism | J-1 / DEC-02 |
| GAP AND-01 / GATE-B-01 | P1 | T-D-01, T-D-02, T-D-03 | J-6 acceptance plan, T-B-07 version pin | J-2 / DEC-03 |
| MIC-01 (FGS type absent in 4005) | P1 | T-D-01, T-D-03 | Fix already in source (`AndroidManifest.xml:15`, `:89-93`) | J-2 |
| MIC-02 (teardown on media loss) | P1 | T-D-03 | Fix already in source (`remote_session_controller.dart:2040-2064`) — status stale, see J-7 | J-2, J-7 |
| F1 (hosted session clock expiry) | P1 (functional) | T-C-03 | `expires_at: null` already in `remote-session/guard.ts:158-178`, undeployed | J-1 |
| F4 (no TURN relay) | Product scope | T-E-01 | Then T-B-08, then T-D-03 | J-4 |
| GATE-EXIT-01 (safe exit) | P1 for Managed Mode | T-B-05 + T-D-05 | DEC-13 design already approved | Phase 10 grant |
| GATE-DEC12-01 (screen time/bedtime/pass integrity) | P1 for feature claim | T-B-01…T-B-04 + T-D-04 | DEC-12 rulings | Phase 10 grant |
| GATE-KEY-01 (release keystore) | Release-only | T-F-01 | Owner-provided keystore | Explicit deferral |
| GATE-PROV-01 / GATE-DA-01 | P2 | T-B-06, T-D-02 | DEC-13 DA retirement | Phase 10 grant |
| DEC-14 FCM delivery | P2 (feature claim) | T-E-02 + code task after | Firebase provisioning authorization (new) | No DEC grants it |
| Version traceability | P2 → blocks P1 evidence | T-B-07 | — | Phase 10 grant |

**Critical path to a defensible release:** J-3 (define "ready") → J-1 and J-2 in parallel → T-C-02/03 closes HOST-01 and T-D-01/03 closes AND-01. Nothing on the governance layer can shorten that path; the only way to shorten it technically is to discover, as this pass did, that much of the device-side code already exists and needs verification rather than authoring.

---

## E. Implementation Task Inventory

Category key: **A** local, proceeds under existing authorization · **B** local, needs explicit owner (Phase 10) approval · **C** hosted, needs DEC-02 · **D** APK/ADB/device, needs DEC-03 · **E** infrastructure, needs a separate decision · **F** release-only gate. Complexity S/M/L. "Tests" are the tests that must exist and pass for acceptance.

### E.1 Category A — start now, no new approval

| ID | Feature/module | Exact files/components | Depends on | Cx | Tests | Acceptance criteria | Recommended order |
|---|---|---|---|---|---|---|---|
| T-A-01 | Verification baseline (all suites) | `deno test supabase/functions`, `bash supabase/tests/run_sql_chain.sh`, `flutter test`, Kotlin JVM compile-only review | none | S | the suites themselves | A recorded pass/fail count per suite with exit codes, no source changed, no hosted contact | **1** |
| T-A-02 | Audio-acceptance plan content for J-6 | `docs/` plan draft listing the 16 gaps, legs, evidence artifacts | none | S | n/a | Every gap has a leg, an artifact and a pass criterion the owner can sign | 2 |
| T-A-03 | Safe-exit design ordering input for J-5 | `docs/`, `PolicyApplier.kt` capability notes | T-A-01 | S | n/a | Exit sequence, failure modes and confirmation UX specified | 3 |
| T-A-04 | Release-criteria wording per J-3 | governance docs | none | S | n/a | One P0/P1 list, no numeric prose conflicts | 4 |

### E.2 Category B — local product code, requires the Phase 10 grant

| ID | Feature/module | Exact files/components | Depends on | Cx | Tests | Acceptance criteria | Order |
|---|---|---|---|---|---|---|---|
| T-B-01 | Enforcement status truthfulness | `supabase/functions/device-command/enforcement.ts:51-58`, `enforcement_test.ts` | T-A-01 | S | Deno | Limits-only policy no longer reported `enforced`; negative test proves it | 5 |
| T-B-02 | Daily screen-time quota enforcement (D1-B) | `policy/PolicyModels.kt:43`, `PolicyApplier.kt` (`:36-129`, `:237 tick`), `UsageReporter.kt`, `GuardianService.kt` | T-B-01 | M | JVM + Flutter | Managed Mode suspends on exhaustion; Standard Mode advisory only; never reports `enforced` without device-side proof | 6 |
| T-B-03 | Bedtime hard suspension (B1-B) | `PolicyApplier.kt:369-370` (replaces informational branch), `policy/PolicyModels.kt:47-56` | T-B-02 | M | JVM | Overnight window suspends in Managed Mode, advisory in Standard; DST/cross-midnight tested | 7 |
| T-B-04 | 10-minute emergency pass (O1-C) | `PolicyEvaluator.kt` `PolicyGuard`, `PolicyApplier.kt`, child UI under `lib/features/child/`, `public.record_audit` | T-B-02, T-B-03 | L | JVM + Flutter | Pass grants exactly 10 minutes, is immune for dialer/emergency/critical packages, cannot silently chain, is audit-logged, auto-expires | 8 |
| T-B-05 | Device Owner safe exit (GATE-EXIT-01) | new native exit path + `AndroidManifest.xml:95-105`, `PolicyApplier.kt:284-291`, child UI | T-A-03, DEC-13 | L | JVM + Flutter | Non-destructive in-app exit restores all suspended packages, requires confirmation, never leaves orphan DPC state | 9 |
| T-B-06 | Device Administrator tier retirement | `AndroidManifest.xml:95-105`, `EnforcementMode.kt:14-23`, `lib/features/devices/device_presentation.dart:9` | T-B-05 | M | JVM + Flutter | DA no longer presented as a management tier; migration path for existing DA devices documented | 12 |
| T-B-07 | Deterministic versioning | `pubspec.yaml:19`, `android/app/build.gradle.kts:50-53` | T-A-01 | S | build-config review | One documented versionCode scheme; every future QA record names its build | **first in wave 2 (before any build)** |
| T-B-08 | Pre-emptive TURN credential refresh | `remote_session_controller.dart` (add timer beside `:2108`/`:2248` patterns), `_shared/turn.ts:25-28` | T-E-01 | S-M | Dart | Credentials refresh before TTL expiry on healthy sessions; no refresh storm | 14 |
| T-B-09 | Honest routing + dead code | `lib/routes/app_routes.dart:25`, `app_pages.dart:157`, 4 uncalled repository methods | none | S | Flutter | No dead routes; no duplicated client/native policy paths that can drift | 15 (lowest priority — hygiene, not function) |

### E.3 Category C — hosted, requires DEC-02 (J-1)

| ID | Scope | Exact artifacts | Depends on | Cx | Acceptance criteria | Order |
|---|---|---|---|---|---|---|
| T-C-01 | Preflight queries 1–5 executed read-only, then authored as `.sql` | governance text; new `supabase/tests/preflight_*.sql` (J-11) | J-1, J-9 | S | Each query has a recorded result and an artifact | 10a |
| T-C-02 | Apply migrations `20261030000200`, `20261103000100` (then `000100`, `000300`) | `supabase/migrations/…` | T-C-01, J-9 | M | `safe_zones` direct-client `DELETE` closed; post-state probe proves it; no replay of `20261028000200` | 10b |
| T-C-03 | Deploy `account`, `family-admin`, `device-command` and the F1-bearing `remote-session` | `supabase/functions/…` | T-B-01 (deploy after fix), T-C-02 | M | Deployed timestamps > `2026-10-27T18:07:08Z`; F1 verified by a hosted session surviving past the old clock without expiry | 11 |

### E.4 Category D — APK/ADB/device, requires DEC-03 (J-2)

| ID | Scope | Depends on | Cx | Acceptance criteria | Order |
|---|---|---|---|---|---|
| T-D-01 | Build + install a release-candidate APK, record four-state ladder | T-B-07, `key.properties` decision | M | Installed build id recorded; MIC-01 FGS type proven present in the artifact | 13 |
| T-D-02 | Execute the 75-row QA matrix (staged subset per J-2) | T-D-01, J-6 | L | Rows move from `NOT RUN` to evidenced verdicts; no row closed without an artifact | 16 |
| T-D-03 | Audio acceptance legs: audibility, screen-off, 5/15-min endurance, indicator, child stop | T-D-01, J-6 | L | MIC-01/MIC-02 closed with runtime evidence; human audibility confirmed by a listener | 17 |
| T-D-04 | Screen-time/bedtime/emergency-pass device verification | T-B-02…T-B-04, T-D-01 | M | Each DEC-12 ruling observed on-device, not inferred from acks | 18 |
| T-D-05 | Safe-exit device verification | T-B-05, T-D-01 | M | Exit observed on a real managed device; no factory reset required | 19 |

### E.5 Category E — infrastructure, each needs its own decision

| ID | Scope | Gate | Cx | Consequence if deferred | Order |
|---|---|---|---|---|---|
| T-E-01 | TURN/STUN relay provider selection, credentials, secrets | **J-4** (no DEC covers it) | M | Cross-network assistance stays unprovable; market the feature honestly | 20 |
| T-E-02 | Firebase project, `google-services.json`, FCM plugin, service-account secret | **New authorization** — DEC-14 grants architecture only (`docs/dec-14-fcm-owner-decision.md:9`) | L | Alerts remain foreground/Realtime-dependent only | 21 |
| T-E-03 | Secret-handling policy (keystore, TURN keys, FCM JSON) | owner ruling | S | Ad-hoc secret placement risk grows with E-01/E-02 | 22 |

### E.6 Category F — release-only gates

| ID | Scope | Gate | Note | Order |
|---|---|---|---|---|
| T-F-01 | Release signing keystore (GATE-KEY-01, `key.properties` **NOT FOUND**) | owner-provided material + J-3 | Blocks store upload only, not QA | 23 |
| T-F-02 | Store-facing claims audit (no mirroring per DEC-16, no website filtering per DEC-15, no unfunded `enforced` claims) | release checklist | Cheap; prevents over-promising | 24 |
| T-F-03 | Privacy/data export-deletion verification against `account` function | release checklist | Depends on T-C-03 deployment | 25 |

---

## F. First Authorized Implementation Task and the Gate Behind It

**Task that can legally and safely start now, with no additional authorization: T-A-01 — the local hermetic verification baseline.**

- Why it is authorized: `phase-9-owner-decision-register.md:97` records **Offline Test Execution (Deno, local SQL, JVM, Flutter) — `PERMITTED (Green)`** in all three columns of the operational boundaries matrix. Nothing else in this plan is Green without a ruling.
- What it is: run the four local suites and record actual output — `deno test` over `supabase/functions` (15 files / 150 tests), `bash supabase/tests/run_sql_chain.sh` against the bundled disposable Postgres at `.tools/pgsql16` (binds `127.0.0.1` only, per the runner's own guarantees at `supabase/tests/run_sql_chain.sh:1-25`), `flutter test` (55 files / 387 cases), and a JVM compile review.
- What it produces: the pass/fail floor every Category B task is measured against, and an honest answer to "do the 150 Deno tests and the SQL chain still pass at HEAD?" — a question no existing document can currently answer.
- Boundary of the task: no source edit, no `gradlew` execution (prohibited at `:98`), no hosted contact, no device contact, no commit.

**First product-code task and its gate: T-B-01** (enforcement-status truthfulness in `supabase/functions/device-command/enforcement.ts`). It is small, fully specified, has a direct test, and unblocks the correct reporting that T-B-02/T-B-03 depend on. It is **not startable today**: the repository has never been granted a Phase 10 implementation authorization, the operational matrix (`:95-103`) enumerates git writes, builds, ADB and schedulers but leaves *source editing* unlisted, and Gate A is labelled `CLEARED (GO)` while every decision record says "Phase 10 NOT AUTHORISED". **Exact approval required before T-B-01: an explicit owner grant of Phase 10 local implementation authority — its scope, its prohibition list, and the ruling that resolves the Gate-A ambiguity.** This master prompt is not that grant, and nothing in this document should be read as assuming it was given.

---

## G. Approvals Still Required — Exact Wording

| # | Approval the owner must issue | Unblocks |
|---|---|---|
| 1 | **Phase 10 local implementation grant** — permission to modify Flutter/Kotlin/TypeScript source in this repository, with builds, ADB, hosted access and commits still excluded | T-B-01 … T-B-09 |
| 2 | **DEC-02 ruling (J-1)** — preflights + 4 migrations + function deployments, applied by the mechanism chosen in J-9 | T-C-01 … T-C-03, GAP HOST-01 |
| 3 | **DEC-03 ruling (J-2)** — build/install/QA on the physical child device and parent emulator | T-D-01 … T-D-05, GAP AND-01 |
| 4 | **J-6 audio-acceptance plan approval** (before, not after, DEC-03 execution) | Meaningful QA verdicts |
| 5 | **J-4 TURN infrastructure decision** | T-E-01 → T-B-08 |
| 6 | **Firebase/FCM provisioning authorization** — not covered by any DEC; DEC-14 records architecture only | T-E-02 |
| 7 | **J-3 severity/blocker normalization ruling** | Section I release criteria |
| 8 | **J-7 documentation annotation approval** (including the stale MIC-02 branch claim at `docs/mic_only_test_report.md:167`) | Accurate status for implementers |
| 9 | **J-10 commit authorization** for the uncommitted governance series | Provenance of 2026-11-06 records |
| 10 | **GATE-KEY-01 release keystore provision** (may stay deferred until store submission) | T-F-01, store upload |

Items 1, 2 and 3 are independent of one another. Item 1 authorizes no build; item 3 authorizes no hosted change; item 2 authorizes neither.

---

## H. Testing and Acceptance Strategy

1. **Baseline first (T-A-01).** Record actual current results for Deno, the local SQL chain, Flutter and JVM. Any regression after Phase 10 is measured against that recorded number, not against a claim in a report.
2. **Unit and property coverage for every new enforcement rule.** T-B-01 gets a negative Deno test (limits-only policy must not yield `enforced`). T-B-02/T-B-03 get JVM tests over frozen clocks — cross-midnight bedtime, DST day, quota exactly at limit, zero-usage day. T-B-04 gets tests for immunity, expiry at exactly 10 minutes, and chaining refusal. T-B-05 gets tests for restore-before-exit ordering and failure paths.
3. **Offline suites cannot close a device claim.** The four-state ladder governs: source present → compiled into the APK → installed → runtime-verified. Only the last supports a `PASSED` verdict, and only DEC-03 can reach it.
4. **Device acceptance is evidence-bound.** Every QA row that moves off `NOT RUN` names an artifact (screenshot, `uiautomator` dump, logcat excerpt, session id, build id) and a timezone-explicit timestamp. Audio legs require a human listener confirmation; RTP flow alone is not audibility.
5. **Endurance is designed, not assumed.** 5-minute and 15-minute locked-screen legs are separate, repeatable runs; a single surviving two-minute interval does not close them.
6. **Cross-network is a distinct suite.** No relay claim may be recorded before T-E-01 exists; once it does, add the pre-emptive credential-refresh test (T-B-08) to prove stale-credentials negotiation cannot occur.
7. **Honest defaults.** Until an item is verified, its status stays `NOT TESTED` / `NOT VERIFIED`. `enforced` must remain a capability claim the device can prove, and must never be inferred from a zero-count ack.

---

## I. Release Criteria (proposed, pending J-3)

A release is defensible when all of the following hold; each is currently unmet.

1. GAP HOST-01 closed by evidence: post-application probe shows the four DEC-02 objects live and direct-client `DELETE` on `public.safe_zones` denied.
2. GAP AND-01 closed by a staged QA run whose rows are named, artifact-backed, and executed against a build identified by a recorded versionCode (post T-B-07).
3. MIC-01 and MIC-02 recorded `PASSED` or `FAILED` from runtime evidence — never from worktree inspection.
4. Human audibility observed, plus 5-minute and 15-minute locked-screen endurance legs each run and recorded.
5. DEC-12's three rulings observed on-device (T-D-04) and enforcement status no longer misreported (T-B-01, deployed via T-C-03).
6. GATE-EXIT-01 satisfied: a real non-destructive safe exit observed on a managed device before any Managed Mode feature is promised.
7. Either T-E-01 exists with cross-network evidence, or cross-network assistance is explicitly excluded from the shipped claim. Same rule for FCM (T-E-02) and for mirroring/recording (DEC-16) and website filtering (DEC-15), which are excluded by ruling.
8. GATE-KEY-01 closed by an owner-provided release keystore, or the release remains unsigned/internal.
9. No P1 remains in `NOT TESTED`, `NOT VERIFIED`, `NOT APPLIED` or `BLOCKED` state.
10. Governance registers self-consistent after J-3, J-7 and J-8, and the governance series committed under J-10.

---

## J. Actions Explicitly Not Performed

No source file was created or modified. No migration, preflight or function deployment was applied or executed; no Supabase dashboard, CLI, SQL or network access occurred; no Firebase/FCM provisioning or secret change; no RLS, Auth, Realtime or Storage modification. No APK was built, installed or uninstalled; no Gradle or ADB command was executed; no device or emulator was paired or operated; no microphone, camera, audio, screen-capture or network test was run. No TURN or WebRTC configuration; no Device Owner or Device Administrator state change; no scheduler enabled (DEC-05 remains on-demand only). No historical report was rewritten; no governance register was modified; nothing was committed, pushed, reset, cleaned, checked out, restored or stashed. Website filtering (DEC-15), screen mirroring, recording and screenshots (DEC-16) were not implemented. Phase 10 was not started. No implementation authorization is inferred from this prompt.

---

## K. Verification and Change Statement

**Created:** [`docs/phase9-13-final-audit-and-implementation-launch-plan.md`](file:///d:/parentcontrol_app/docs/phase9-13-final-audit-and-implementation-launch-plan.md) — this document, and nothing else.

**Modified:** none. **Deleted:** none.

**Freshly verified locally in this pass (read-only commands, output reproduced):** migration inventory 14 files / 3,903 lines; 19 tables; 19 `enable row level security`; 25 `create policy`; 24 `private.*` and 17 `public.*` functions; 10 deployable Edge Function directories plus `_shared` (17 modules) and `handler_wiring_test.ts`; `verify_jwt` per function at `supabase/config.toml:61-95`; Realtime publication targets at `20260101000100_functions.sql:907-941`; 0 preflight `.sql` artifacts; no `supabase/.branches`, `.temp` or migration lock; test counts Deno 15 files/150 tests, Flutter 55 files/330 `test(` + 57 `testWidgets(`, Kotlin JVM 6 files/39 `@Test`, `integration_test` 4 entry points, `supabase/tests` 19 `.sql` + fixtures + 3 runners; 17 `lib/features/` modules; zero source-level Firebase/FCM references (single match is the binary Gradle cache `android/.gradle/9.1.0/executionHistory/executionHistory.bin`); zero `clearDeviceOwnerApp` occurrences; zero emergency-pass identifiers; `dailyScreenTimeLimitMinutes` readers = none in `PolicyApplier.kt`/`GuardianService.kt`; `pubspec.yaml:19` `1.0.0+1`; `key.properties` and `local.properties` **NOT FOUND**; no `.github/workflows` (**NOT FOUND**); toolchain present (Flutter 3.38.8, Dart 3.10.7, Deno 2.9.4, JDK 17.0.16, ADB 1.0.41, Supabase CLI 2.109.0, bundled Postgres under `.tools/pgsql16`); MIC-02 teardown present at `remote_session_controller.dart:2040-2064`; F1 fix present at `supabase/functions/remote-session/guard.ts:158-178`; `policyTargetsApps` at `supabase/functions/device-command/enforcement.ts:51-58`; bedtime informational-only at `PolicyApplier.kt:369-370`.

**Reproduced from historical evidence, not re-verified:** all hosted-state facts (9 hosted functions, newest deployment `2026-10-27T18:07:08Z`, 4 migrations `NOT APPLIED`, `safe_zones` exposure live), all device/runtime facts (build 4005 results, `NOT TESTED` / `NOT VERIFIED` endurance and audibility, indicator failure on ColorOS), and the 75/75 `NOT RUN` QA matrix.

**Registers re-verified unmodified:** `phase-9-owner-decision-register.md` and `docs/implementation/phase-9-owner-decision-register.md` both SHA-256 `3a5d136b0f03331a41a465962841f88651e43a10fe37d435d9ce46865122bf0f`, `cmp` reports identical, `git diff` on both empty. The Phase 9.9.2.2, 9.10, 9.11 and 9.12 reports were left untouched; they are observed staged in the index (see B.14 for the timestamp and the fact that this pass issued no Git write command), and nothing was unstaged, committed, reverted or cleaned by this pass.

**STOPPED. This is the terminal audit pass of the Phase 9 series; no Phase 9.14 or further audit cycle has been created, no restricted operation was performed, and no authorization was assumed.**

**Owner action list (one batch):** rule on J-1, J-2, J-3, J-4, J-5, J-6, J-7, J-8, J-9, J-10, J-11 (Section C) · issue the Phase 10 local implementation grant and resolve the Gate-A / "Phase 10 NOT AUTHORISED" ambiguity (Section G item 1) · grant Firebase/FCM provisioning or formally defer DEC-14 out of the release (Section G item 6). **First ready implementation task: T-A-01 — run the local hermetic verification baseline (Deno 150 / SQL chain / Flutter 387 / JVM 39) and record actual output; permitted today under `PERMITTED (Green)` at `phase-9-owner-decision-register.md:97`, requiring no new approval.**
