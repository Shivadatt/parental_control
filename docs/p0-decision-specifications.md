# P0 Product Decisions — DEC-12 through DEC-16 Specifications

**Document class:** decision preparation, not implementation.
**Status of decisions in this file:** **DEC-12 is APPROVED (Choices D1-B, B1-B, O1-C, P1-A, DEFER)**, **DEC-13 is APPROVED (Option B)**, **DEC-14 is APPROVED (Option B — Realtime + FCM Non-Authoritative Wake-Up Transport)**, **DEC-15 is APPROVED (Option D — Defer Website Filtering for the Current Release)**, and **DEC-16 is APPROVED (Option A — Screen Mirroring and Recording Excluded from Product Scope)** by explicit owner rulings on 2026-11-05 (Phases 9.2, 9.3, 9.5, 9.7 & 9.9). Nothing here authorizes implementation. Phase 10 is not started and is not authorised by this file.
**Authored:** 2026-11-05 (Phase 9 — Owner Decision Reconciliation & Release Readiness).
**Companion documents:** `docs/supabase-hosted-state-verification-2026-11-05.md` (live hosted state), `phase-9-owner-decision-register.md` (DEC-01…DEC-11 governance), `docs/stage7_hosted_migration_apply_2026-10-29.md` (historical hosted evidence), `audit/01_COMPLETE_FEATURE_INVENTORY.md` (canonical feature inventory).

---

## 0. Method, provenance and evidence discipline

### 0.1 How the evidence was gathered

Local evidence was gathered by direct read of the repository (Dart, Kotlin, TypeScript, SQL, manifest, documentation). Hosted evidence was gathered read-only through the authenticated dashboard for project `parent-control-prod` / `hhqgreaoqulmfwfwarhc` only. Every claim below carries an exact source location. Where a claim rests on a document rather than on code, it is labelled as such. Where a claim rests on a device run, it is labelled with the build and date of that run, or marked NOT TESTED.

### 0.2 Sub-agent attribution disclosure

Five investigation domains were dispatched to sub-agents in parallel during this pass. **One returned usable evidence** (the Stage 7 migration-file digest, whose DDL identifiers and file:line citations were re-confirmed against the repository and against the live catalogue). **Four failed to return** (`Sorry, something went wrong`): governance-register structure, microphone privacy requirement verification, the QA NOT-RUN ledger, and the feature-inventory provenance comparison. Those four domains were then investigated **directly in this session** by the primary agent, and the citations below are that direct work. **No sub-agent result has been invented, paraphrased as fact, or upgraded.**

### 0.3 Vocabulary used throughout

`VERIFIED` (directly inspected, with source) · `PARTIALLY VERIFIED` (partial evidence) · `HISTORICAL EVIDENCE` (older report, not re-confirmed) · `NOT IMPLEMENTED` (confirmed absent) · `NOT TESTED` (may exist, no valid evidence) · `BLOCKED` (governance/access gate) · `CONFLICTING` (sources disagree) · `NOT ACCESSIBLE`.

Documentation is never treated as proof of implementation. Unit tests are never treated as device-runtime proof. A proposed fix is never treated as a completed fix. A historical hosted report is never treated as current verification. The dashboard's empty migration history is never treated as proof that manual SQL was not applied.

### 0.4 Two feature-classification sources, kept separate

Both are preserved, neither merged:

| Source | Date in repo | Rows | Status vocabulary | "Not applicable"-class rows |
|---|---|---|---|---|
| `audit/01_COMPLETE_FEATURE_INVENTORY.md` (canonical) | files dated 2026-10-30 | 242 rows / 242 distinct IDs (re-counted this pass) | `MISSING 111`, `IMPLEMENTED — PARTIALLY VERIFIED 53`, `PARTIALLY IMPLEMENTED 30`, `FULLY IMPLEMENTED — VERIFIED 28`, `CODE EXISTS — NOT TESTED 13`, `NOT APPLICABLE 3`, `BROKEN 2`, `BACKEND ONLY 2` | **3** — `FB-027` (mirroring performance), `FC-080` (default-SMS-app restrictions), `FD-015` (AirDroid iOS-specific web time) |
| 2026-11-05 AirDroid parity reclassification | **not present in the repository** — delivered in conversation only | 242 rows | `PASS 0`, `IMPLEMENTED — RUNTIME UNVERIFIED 89`, `PARTIAL 47`, `BROKEN 3`, `MISSING 78`, `BACKEND ONLY 1`, `UI ONLY 0`, `BLOCKED 6`, `N/A 16`, `REQUIREMENT CLARIFICATION 2` | **16** |

**Why the N/A counts differ (3 vs 16) — explicit explanation, no silent merge.** The canonical inventory assigns `NOT APPLICABLE` only where a feature is inapplicable *as a product promise* (SMS-app privileges, an iOS-only vendor behaviour, mirroring performance). The 2026-11-05 reclassification additionally applied `N/A` to the screen-mirroring/recording family — `FB-015` through `FB-026` — because the owner excluded screen recording from scope on 2026-10-27 (`docs/screen-recording-plan.md`), and it applied `N/A` to vendor features that the product has explicitly promised never to offer. Those rows are labelled `MISSING` in the canonical inventory and were **not** re-labelled here. The discrepancy is therefore a **difference in classification rule, not a difference in the underlying facts**: canonical answers "does this exist?", the reclassification answers "is this something we will ever ship?". Both remain valid on their own terms. Reconciling them into one column would destroy information and is deliberately not done (see DEC-16, §5.4).

**Feature-ID correction applied.** `FA-052` is the screen-time feature row ("Additional — Screen-time controls (daily limit / bedtime)", `audit/01_COMPLETE_FEATURE_INVENTORY.md:78`, status `PARTIALLY IMPLEMENTED`). `FC-052` is the social-detection keyword-management row (`:180`, status `MISSING`, with the recorded probe that searching `keyword` returns zero hits across `lib`, `android`, `supabase` and tests). **`FC-052` is not a screen-time feature** and is not cited as one anywhere in this file.

### 0.5 Governance constraints in force while these decisions are open

DEC-01 approved (Choice B, logs stay local-only; DUR-01 stays OPEN). DEC-02 pending, historical Stage 7 pair reconciled separately (`docs/stage7_hosted_migration_apply_2026-10-29.md`), with all four DEC-02 migrations, preflights, and every Edge Function deployment still prohibited. DEC-03 pending: no APK, no ADB, no pairing, no device testing; all **75** rows of the controlled Android matrix remain `NOT RUN` (verified this pass by counting `phase-8-android-qa-report.md:229` onward — 75 rows, `Status = NOT RUN` in all 75). DEC-05 approved (Choice B, on-demand only; `pg_cron` remains absent hosted, confirmed 2026-11-05). Phase 10 requires explicit owner authorisation.

---

## 1. DEC-12 — Screen-time and bedtime enforcement

**1. Decision ID and title.** DEC-12 — Screen-time and bedtime enforcement on the child device.

**2. Current registered status.** **APPROVED — Choices D1-B, B1-B, O1-C, P1-A, DEFER** on 2026-11-05 (Phase 9.3).
- Daily screen-time limit: **Choice D1-B** (Standard Mode = advisory notification; Managed Mode = hard package suspension via `setPackagesSuspended`).
- Bedtime: **Choice B1-B** (Managed Mode = hard bedtime package suspension across scheduled overnight window; Standard Mode = advisory notification).
- Emergency override: **Choice O1-C** (Child-initiated emergency pass lasting exactly 10 minutes; emergency calling/dialer strictly immune; auto-expiring; audit-logged).
- Per-app daily limits: **Choice P1-A** (Deferred to Phase 10; excluded from immediate DEC-12 scope).
- Production row remediation: **Choice DEFER** (No update to hosted `device_policies` row `d4a05b68…` without separate future hosted authorization).
- Implementation boundary: Documentation and specification only. No implementation, device testing, APK builds, or hosted migrations authorized.

**3. Problem statement.** The parent UI lets a guardian set a daily screen-time budget and a bedtime window, and the server accepts and stores those fields. The child device parses the budget but never enforces it, and evaluates bedtime only to echo a boolean back. Meanwhile the enforcement-status mapping can report a limits-only policy as `enforced`, and production data already contains such a row. A parent can therefore be told that a restriction is in force when nothing on the phone changes.

**4. Verified current implementation.**

| Mechanism | Source | Status |
|---|---|---|
| `UsageStatsManager.queryUsageStats(INTERVAL_DAILY)` foreground/background usage totals | `android/app/src/main/kotlin/com/parentcontrol/parent_control/UsageReporter.kt:21-86` (interval at `:43`) | VERIFIED (code) |
| Daily usage exposed to Dart and persisted | `NativeBridge.kt:146`, `:558-588`; `device_admin_service.dart:244 queryDailyUsage` | VERIFIED (code) |
| `queryDailyUsage` has **no production caller** — only `integration_test/device_capabilities_test.dart:51` | grep of call sites | VERIFIED |
| Policy fields parsed on device | `PolicyJson.kt:11-18` (full accepted field list) | VERIFIED |
| `daily_screen_time_limit_minutes` parsed with **no reader** | `PolicyJson.kt:16`; no Kotlin read of the value anywhere | VERIFIED |
| Bedtime window modelled (`PolicyWindow.isActiveAt`, `isWithinBedtime`) | `PolicyModels.kt:11-21`, `:51` | VERIFIED |
| Bedtime used **only** to set an informational ack field | `PolicyApplier.kt:370` under the comment at `:369` ("Informational only…") | VERIFIED |
| Per-app block rules evaluated and applied | `PolicyModels.kt:67-76 isPackageBlockedNow`, applied at `PolicyApplier.kt:63` and `:103` | VERIFIED (code) |
| Re-evaluation cadence | `GuardianService.kt:40 POLICY_TICK_MS = 60_000`, driven at `:249-258`, ack at `:485-497` | VERIFIED (code) |
| Parent screen-time editing surface | `lib/features/screen_time/screen_time_controller.dart:268,276,286,291,296,302,307-320,322→342`; page `screen_time_page.dart:332,347,356,404,455,457`; second writer `app_restrictions_controller.dart:283,313` | VERIFIED (code) |
| Honest counter-based enforcement mapping | `supabase/functions/device-command/enforcement.ts:60-130`, with `advancePolicyVersion` only for `enforced`/`unsupported` | VERIFIED (code) |
| Parent-side mirror of that honesty | `lib/data/models/policy_enforcement.dart` — `provesEnforcement` requires matched `policy_id` **and** proving counts | VERIFIED (code) |

**5. Missing or incomplete implementation.**
- **Hard daily limit enforcement: NOT IMPLEMENTED.** No code path stops app use when the budget is exhausted. Canonical inventory records the same defect at `audit/01_COMPLETE_FEATURE_INVENTORY.md:78` ("the child device never enforces it… the most serious functional gap").
- **Bedtime enforcement: NOT IMPLEMENTED.** Informational only (`PolicyApplier.kt:369-370`).
- **Per-app daily limits: NOT IMPLEMENTED** (no schema field, no reader, no UI).
- **Emergency override (child-side "break for a call", PIN-gated parent release): NOT IMPLEMENTED.**
- **Usage write-back: incomplete.** `UsageReporter` collects data; nothing compares it against the stored limit.
- **Enforcement-status reporting is wrong for limits-only policies.** `policyTargetsApps()` (`enforcement.ts:51-57`) inspects only `blocked_packages`, `app_rules[].blocked` and `block_all_except_allowed`. A policy containing only a daily limit and a bedtime window is "not targeting apps", so with Device Owner confirmed and `desired == applied == 0` the mapping returns `enforced` and advances `devices.policy_version` (`enforcement.ts:122-129`). `supabase/tests/enforcement_test.ts:126-138` asserts exactly that behaviour, so the defect is currently codified as expected.
- **Live confirmation:** hosted `device_policies` row `d4a05b68-…` (device `9dcadadc…`, version 1) is stored `enforced` with `last_error NULL` while its policy suspends nothing and carries `daily_screen_time_limit_minutes = 120`. Hosted `device_commands` contains **zero** acks with `desired_count`/`enforcement_supported`, so the current mapping has never been exercised against real device counters. (See hosted report §9.3–9.4.)
- **JVM coverage:** no test exists for `PolicyApplier.apply/tick`, `UsageReporter`, or `GuardianService`. Device-level behaviour: **NOT TESTED** (DEC-03).

**6. Hosted Supabase dependencies.** Policy JSON is validated against a closed whitelist (`supabase/functions/device-policy/policy.ts:27-36`, `:108`, `:122-123`, unknown key ⇒ `400`), so any new field — per-app limit, override window, enforcement mode for limits — requires a schema/migration change, which is **blocked by DEC-02**. `device_policies.enforcement_status` is constrained to `pending|enforced|failed|unsupported` (verified live 2026-11-05); expressing "limit accepted but not enforceable on this device" needs either a new value (migration) or honest use of `unsupported` + `last_error`. `device_commands.expires_at` is NOT NULL live, so command delivery semantics cannot be relaxed without a migration.

**7. Android/device dependencies.** `UsageStatsManager` needs `PACKAGE_USAGE_STATS` (user-granted in Settings, not a normal runtime grant). Suspension needs Device Owner (`PolicyApplier.kt:284-289 isDeviceOwner`, `:299-311` suspend, `:313-321` restore) — see DEC-13. Android 15 (`VANILLA_ICE_CREAM`) refuses `dataSync` foreground-service starts from `BOOT_COMPLETED`, which affects whether the tick loop is alive after reboot. Battery-optimisation exemption is **not requested anywhere** in the repo (no `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`), so OEM process death can stop the loop. Fleet maximum API is 31; API 35 behaviour is untested (`audit_work/s3-android-native.md:315`).

**8. Security and privacy implications.** Hard-locking a phone is a physical-safety action: it can block emergency calls, maps, and a child's ability to contact a guardian. Enforcement that fails silently is a trust and safety defect in the other direction — a guardian who believes a limit exists. Usage-stats access reveals installed-app inventory and usage patterns; it must stay on-device, aggregated (`usage_daily` is the only uploaded shape), and never forwarded raw. Any override must be auditable (`audit_logs`) and must not become a covert backdoor in either direction.

**9. Owner decision options.**

*Suspend-all versus device-lock:* **(A)** suspend all non-essential packages via `setPackagesSuspended` (needs Device Owner; preserves dialer/emergency via `PolicyGuard.CRITICAL_PACKAGES` + dynamic default-home/default-IME protection, `PolicyModels.kt:27-76`); **(B)** a dedicated "device locked" full-screen block Activity driven by the tick loop (works without Device Owner, weaker: the child can often work around it); **(C)** limits are advisory-only and the UI must say so.

*Emergency override:* **(A)** none; **(B)** fixed short allowance that self-terminates; **(C)** guardian-granted temporary extension with an expiry, audit row and visible child-side countdown.

*Bedtime behaviour:* **(A)** warning window then enforcement; **(B)** hard enforcement at the boundary; **(C)** informational only, with honest "not enforced" reporting.

*Per-app versus total:* **(A)** total daily limit only; **(B)** total plus per-app daily limits (needs schema, UI, device reader, tests); **(C)** per-app only.

*Standard versus managed mode:* Inherited from approved **DEC-13 (Option B)**. In Standard Mode, screen-time monitoring is active but app suspension is unsupported; limits are advisory or notification-based. In Managed Mode (Device Owner), hard package suspension enforces quotas and bedtime. Device Administrator mode is retired and excluded.

**10. Recommended option — recommendation only, not approval.** Aligned with approved DEC-13 Option B: **Managed-Mode suspend-all for hard limits (Option A) combined with honest standard-mode reporting (Option C)**; **(C) guardian-authorized temporary override** with audit logging and auto-expiry; **(A) bedtime warning window then enforcement** in Managed Mode; and **(A) total daily limit only** (deferring per-app limits). This strictly enforces limits on Managed devices, reports honestly on Standard devices, avoids false-`enforced` claims, and defers schema changes for per-app limits. DEC-12 remains strictly **PROPOSED** awaiting explicit owner decision.

**11. Acceptance criteria.**
- AC-12-1 `daily_screen_time_limit_minutes` is read by the device and enforced by a code path that has a test.
- AC-12-2 Enforcement outcome is observable: ack carries `desired_count`, `applied_count`, `failed_count`, `enforcement_supported`, `enforcement_mode` and the enforced `policy_id`.
- AC-12-3 A limit-exceeded state is demonstrably produced on a device or emulator (currently blocked by DEC-03).
- AC-12-4 Bedtime produces an action, not only a boolean, or the UI states "informational".
- AC-12-5 Parent UI shows `enforced` only for matched-policy proving counts (already the model contract; must be re-verified against new states).
- AC-12-6 Emergency override, if chosen, expires automatically, is audit-logged, and is visible on both ends.
- AC-12-7 Per-app limits (if chosen) are validated server-side against the whitelist and rejected cleanly when over limits.
- AC-12-8 Android 15 boot behaviour and OEM battery settings documented; degraded mode stated honestly.
- AC-12-9 Re-verification: `enforcement.ts` unit tests updated so that a limits-only policy with zero counters can **no longer** be reported as `enforced`.
- AC-12-10 `usage_daily` upload path is called by the reporter (currently `queryDailyUsage` has no production caller).
- AC-12-11 **Status vocabulary fix:** introduce an explicit outcome that means "policy accepted, enforcement not applicable/unavailable on this device" — either a new `enforcement_status` value (hosted migration, DEC-02 gated) or reuse of `unsupported` with a specific `last_error`. No limits-only policy may map to `enforced` while `desired_count` is absent.
- AC-12-12 Existing hosted rows mislabelled `enforced` are re-derived, not silently edited; any backfill requires separate written owner authorisation.

**12. Out of scope.** Screen recording/mirroring (DEC-16). Website/DNS filtering (DEC-15). Push delivery (DEC-14). Device Owner provisioning mechanics (DEC-13). Any hosted migration or deployment while DEC-02 is pending. Any device run while DEC-03 is pending.

**13. Dependencies.** Ordered after DEC-13 only if suspend-all is chosen; independent of DEC-14/15/16. Requires a policy-schema decision (AC-12-11) whose hosted execution is gated by DEC-02, and device verification gated by DEC-03.

**14. Required verification evidence.** Kotlin unit/Robolectric tests for `PolicyApplier` limit and bedtime paths; Deno tests for the new status mapping including the limits-only case; a device or emulator run recording the enforced state with counters; a read-only hosted query proving the stored `enforcement_status` matches the ack counters; screenshots of both parent and child surfaces at the boundary. None of the device evidence exists today (DEC-03).

**15. Rollback / failure considerations.** Enforcement must fail **open** for safety-critical surfaces (dialer, emergency, default IME/home) and fail **closed** for the report (never claim enforced without proof). Suspend state is restorable (`PolicyApplier.kt:313-321`, diff at `:126-133`, re-confirmation at `:144-160`); a lock-screen style block must have a guaranteed escape (ADB-reachable or auto-expiring) because a stuck lock is a device-brick from the family's point of view. Removing Device Owner restores suspension; a lock overlay has no such dependency. Rollback of a bad policy must be a single new version, not an in-place edit — `apply_policy_version` already writes policy and command atomically.

---

## 2. DEC-13 — Device Owner and managed mode

**1. Decision ID and title.** DEC-13 — Device Owner / managed-device product mode.

**2. Current registered status.** **APPROVED — OPTION B (Managed Mode Required for Full Enforcement)**. Approved by the project owner on 2026-11-05 (Phase 9.2).
- Architecture: **Option B** (Standard Mode provides monitoring and non-DO features; Managed Mode via Device Owner required for app suspension; fallback to Standard Mode if provisioning fails).
- Exit Policy: **Non-destructive in-app exit is mandatory (Release Blocker).** Factory reset must not be the only supported consumer exit.
- Device Administrator: **Retired.** Mode and label removed from product hierarchy.
- Release Signing Keystore: **Deferred** (requires separate owner authorization).
- Implementation boundary: Documentation and decision-preparation only. No implementation, provisioning, build, device test, or hosted change authorized.

**3. Problem statement.** The strongest enforcement primitives already in the code (`setPackagesSuspended`, restore-diff-verify) only work when the app is Device Owner. Production has no Device Owner device. The only provisioning procedure in the repository is a lab ADB ceremony, which no ordinary guardian can reproduce and which cannot be undone without a factory reset. The product must choose: ship a weaker promise that works everywhere, or ship a managed mode with a real provisioning and unprovisioning story.

**4. Verified current implementation.**

| Mechanism | Source | Status |
|---|---|---|
| Device Owner / admin detection | `PolicyApplier.kt:284-289 isDeviceOwner`, `:291-296 isAdminActive`; acked at `:234`; heartbeat `GuardianService.kt:669-670` | VERIFIED (code) |
| Capability report incl. `canSuspendPackages` | `NativeBridge.kt:183-204` (`:190`), exposed via `getCapabilities` (`:121`) | VERIFIED (code) |
| Dart model of the distinction | `lib/data/models/device.dart:710,726,735` (`isFullyManaged => isDeviceOwner && canSuspendPackages`), `:415` | VERIFIED (code) |
| Suspend / restore / diff / re-confirm | `PolicyApplier.kt:299-311`, `:313-321`, `:126-133`, `:144-160`; `isSuspended` `:271-282` | VERIFIED (code) |
| `enforcementSupported` persisted | `PolicyApplier.kt:171-173` → stored `:161` → `SecureStore.kt:176-179` | VERIFIED (code) |
| Guard list + dynamic home/IME protection | `PolicyModels.kt:27-76 PolicyGuard`, restore list `PolicyEvaluator.kt:14-15` | VERIFIED (code) |
| Add-admin (device admin, not owner) flow | `NativeBridge.kt:398-410` (`ACTION_ADD_DEVICE_ADMIN`) | VERIFIED (code) |
| Honest "unsupported" wire vocabulary | `EnforcementMode` `device_owner|device_admin|none`; `DeviceRow.enforcement_mode` in `supabase/functions/_shared/auth.ts:49-58`; UI string `policy_enforcement.dart:81-82` | VERIFIED (code) |
| Live hosted distribution | 14 devices: 10 `none`, 2 `device_owner` (**both revoked**), 2 `device_admin` (**the only active**) | VERIFIED (hosted, 2026-11-05) |

**5. Missing or incomplete implementation.**
- **Production provisioning: NOT IMPLEMENTED.** No `ACTION_PROVISION_MANAGED_DEVICE`, no `ACTION_PROVISION_MANAGED_PROFILE`, no QR provisioning, no NFC beam, no zero-touch, no EMDM/EMM client. Only `ACTION_ADD_DEVICE_ADMIN` exists. `ParentControlDeviceAdminReceiver.kt:16` states "This app never attempts the provisioning command programmatically" (`:18` empty subclass).
- **Teardown support: NOT IMPLEMENTED.** No `clearDeviceOwnerApp`, no `getActiveAdmins`, no `removeActiveAdmin`. The documented consequence: `docs/device-owner-provisioning.md:709-724` "Factory reset is the only reliable teardown for the current build".
- **The existing procedure is lab-only.** `docs/device-owner-provisioning.md:3` "PROCEDURE ONLY — NOT EXECUTED, NOT VERIFIED"; `:119-132` lab ADB versus production QR/NFC/zero-touch/EMM (unsupported); `:70-76` "Never the RMX2161 or a personal phone"; `:156-159` refuses serial `5HXWRGQ4IFU8WS4T`; `:264-265` "QR and NFC provisioning are NOT SUPPORTED".
- **Signing identity unresolved — a hard prerequisite.** `android/app/build.gradle.kts:13-22` `hasReleaseSigning` needs `android/key.properties`, which exists only as `.example`; `:56-65` conditional release config; `:71-75` debug fallback; `:30-32` "release build signed with DEBUG key - not shippable". `docs/verification-report.md:39` and `docs/release-build.md:29` record `CN=Android Debug`. Device Owner is bound to the signing key: re-signing with a different key orphans the owner claim.
- **Documentation staleness:** `docs/device-owner-provisioning.md` cites `build.gradle.kts:28-34` and PolicyApplier line numbers that no longer match (`:36-51` region now) — flagged so nobody treats those quotes as current.
- **Test surface:** `EnforcementModeTest.kt:22-54`, `PolicyEvaluatorTest.kt:122-133,155-181`, `child_shell_controller_test.dart:256,288,306`, `app_restrictions_page_test.dart:21,94,189,205,226,270`, `enforcement_test.ts:44-178`, `handler_wiring_test.ts:98-118`. There is **no `androidTest` directory** — nothing instrumented has ever run. Device Owner behaviour on a real device: **NOT TESTED** under DEC-03.
- **Terminology note:** "Mode A / Mode B" does not exist anywhere in the repository; it is introduced here as a decision label only.

**6. Hosted Supabase dependencies.** None for detection/reporting — `devices.enforcement_mode` and the four `enforcement_status` values already exist (verified live). Adding a per-device "managed mode" contract, or a provisioning-state column, requires a migration and is therefore **blocked by DEC-02**. The `device_policies` unique `(device_id, version)` shape and `apply_policy_version` atomicity already support rollback of a bad managed policy.

**7. Android/device dependencies.** A stable release signing identity (currently debug). A device that permits owner provisioning (OEM-dependent; `docs/device-owner-provisioning.md:424-436`, `:635-639`, `:528-529` record OEM and Android 15 caveats). Provisioning requires a factory-reset device, so the owner can never provision their own phone (`:70-76`; the personal Realme `RMX2161` is explicitly out of bounds). Android 15 boot-time `dataSync` FGS restriction interacts with keeping the enforcing service alive. Battery-optimisation exemption is still unrequested.

**8. Security and privacy implications.** Device Owner is the most powerful non-root position an app can hold on Android: it can suspend packages, wipe the device, and control keyguard. That power must be visibly declared, revocable (today: only by factory reset — an unacceptable support risk), and never installed by stealth. The parent-facing promise must change with the mode: "we can block apps on this device" is false unless the mode is managed. Conversely, `clearDeviceOwnerApp` absence means a family cannot cleanly un-manage a device, which is itself a safety issue.

**9. Owner decision options.**
- **(A) Standard mode only.** Ordinary Android permissions. Available: monitoring, usage reports, alerts, safe zones, consented audio, remote assist, command/ack machinery, informational limits. Not available: app suspension, hard limits, keyguard, install restrictions.
- **(B) Dual mode.** Ship standard mode, and expose a clearly labelled "Managed device (advanced)" tier for families who provision through QR/NFC/zero-touch/EMM; every feature card states which tier it needs.
- **(C) Managed mode as the primary product.** Requires real provisioning support plus a supported un-provision path before any sale.
- **Failure/removal semantics:** (i) detect loss of ownership and re-label every dependent feature as `unsupported` with `device_owner_required` (already implemented); (ii) require explicit re-provisioning; (iii) auto-fallback to standard-mode behaviour.
- **Provisioning channels to support:** QR-only; QR + zero-touch; EMM/MDM integration; or none (self-service ADB is not a support option).

**10. Recommended option — recommendation only, not approval.** **(B) Dual mode**, with **(C) un-provision semantics deferred but documented**, and QR as the first supported channel. Rationale: today's live fleet has zero active Device Owner devices and an unresolved signing identity, so a managed-primary product would ship a promise the current build cannot keep; the code already reports `unsupported` honestly, so dual mode mostly means surfacing state the system already computes.

**11. Acceptance criteria.**
- AC-13-1 Product mode is chosen and named in user-facing copy, not inferred by the code.
- AC-13-2 A supported provisioning path exists and is reproducible by a non-engineer, or the managed tier is not offered.
- AC-13-3 A supported removal path exists (owner release, or documented factory reset) before any device is shipped managed.
- AC-13-4 Release signing is durable and recorded; no release artefact is debug-signed.
- AC-13-5 The parent UI states, per device, which capabilities are unavailable and why, using the existing `enforcement_supported`/`unsupported` path.
- AC-13-6 Loss of Device Owner at runtime is detected, reported and never silently degrades into "enforced".
- AC-13-7 `docs/device-owner-provisioning.md` staleness fixed and its lab/production distinction preserved verbatim.

**12. Out of scope.** Implementing provisioning code, provisioning any device, using the personal Realme as a test device, ADB runs, APK builds, hosted schema changes, per-app screen-time enforcement (DEC-12).

**13. Dependencies.** Signing identity must be resolved before any managed-mode commitment. DEC-12 suspend-all depends on this decision. Hosted mode contract changes depend on DEC-02. Device evidence depends on DEC-03.

**14. Required verification evidence.** Instrumented `androidTest` (none exists) on a dedicated, factory-reset lab device showing `isDeviceOwner()`, `setPackagesSuspended` round-trip, restore after ownership loss; a signed release artefact with a recorded non-debug certificate digest; a provisioning walkthrough performed by someone other than the author.

**15. Rollback / failure considerations.** Ownership cannot be removed cleanly today — that is the dominant risk and must be stated before selling managed mode. A failed provisioning attempt leaves the device owner-less, which is safe but breaks dependent features. Suspension state is restorable in code (`PolicyApplier.kt:313-321`) but only survives a crash if persisted state (`SecureStore.kt:176-179`) is reconciled on restart; that reconciliation is untested. A factory reset is the only guaranteed full rollback.

---

## 3. DEC-14 — Push notifications / FCM

**1. Decision ID and title.** DEC-14 — Out-of-band delivery of safety alerts (Firebase Cloud Messaging).

**2. Current registered status.** **APPROVED — Option B (Realtime + FCM Non-Authoritative Wake-Up Transport)** by explicit owner ruling on 2026-11-05 (Phase 9.5). Detailed decision document: [`docs/dec-14-fcm-owner-decision.md`](dec-14-fcm-owner-decision.md). Implementation boundary in force: architecture approval only; implementation, provisioning, and hosted changes gated by DEC-02 and DEC-03.

**3. Problem statement.** Safety alerts are only visible when the parent app is open. The delivery path is a Supabase Realtime Postgres change channel (`supabase_alert_repository.dart:55-124`, private channel `safety-alerts:<familyId>:…`, insert/update filtered on `family_id`, error copy "Live alert updates disconnected. Refresh to reload alerts."). If the app is closed, backgrounded beyond socket life, or the socket is silent, the guardian sees nothing until they open the app. There is no push transport at all.

**4. Verified current implementation.**

| Item | Source | Status |
|---|---|---|
| Realtime-only alert streaming, with explicit degradation copy | `lib/data/repositories/supabase_alert_repository.dart:55-124` | VERIFIED (code) |
| Realtime subscriptions exist at exactly three call sites (alerts + remote session ×2) | `supabase_alert_repository.dart:100`, `supabase_remote_session_repository.dart:249,358` | VERIFIED (code) |
| Alert surface, ack, list | `lib/features/alerts/safety_alerts_controller.dart:41-45,47-76,78-93,95-98,121-134` | VERIFIED (code) |
| Alert row shape and CHECK constraints (`type`, `severity`, `message` 1–300) | `supabase/migrations/20260101000000_core.sql:297-316` | VERIFIED (repo); live table present with 4 rows |
| Alert RLS: parent-or-child select | `20260101000200_rls.sql:173-180`, grant `:272` | VERIFIED (repo) + policy `safety_alerts_select_parent_or_child` VERIFIED live |
| Server-side alert producers | `20260101000100_functions.sql:531-573 detect_offline_devices` (15-min stale, 6-hour suppression) | VERIFIED (repo) |
| Notification permission plumbing exists (child side only) | `NativeBridge.kt:471-474,492,160-161,336-341,548`; `NativePermissions.kt:29-32`; callers `child_settings_tab.dart:192`, `child_shell_controller.dart:867,935-937`, `child_restrictions_page.dart:229`, `remote_session_controller.dart:1649` | VERIFIED (code); **no parent-side request** |
| "Show local notifications" is a local preference only | `lib/features/settings/settings_body.dart:118-135`; `local_settings_service.dart:54-57` | VERIFIED (code) |
| No deep-link routing | `lib/app/app.dart:18` sets `initialRoute` only | VERIFIED (code) |

**5. Missing or incomplete implementation.**
- **Firebase/FCM: NOT IMPLEMENTED, repo-wide.** Zero hits for `firebase|fcm|cloud_messaging|push_token` in code; only `.gitignore:10-11` (which ignores `google-services.json` and `firebase_options.dart`) and prose in `docs/`.
- **`push_tokens` table: absent hosted** (verified 2026-11-05 — 19 tables, none of them token storage).
- **No send path:** zero `pg_notify`, `net.http_post` or outbound `fetch(` in `supabase/`; no Edge Function dispatches to a third party.
- **No token registration anywhere** — `docs/integrations-setup.md:305` "There is no token registration anywhere."
- **No Firebase project, no `google-services.json`, no service-account secret** — hosted secret list (names only, 2026-11-05) contains no Firebase entry. `docs/backend.md:23` records "FCM | **NOT CONFIGURED**".
- **Fresh-clone build hazard:** because `google-services.json` is git-ignored, the first `flutterfire_configure`/plugin addition makes a clean clone unbuildable (`docs/integrations-setup.md:219-224`).
- **`docs/integrations-setup.md §2` is a written plan, not evidence.** It documents the console steps, the gradle state ("Not applied today", `:226-239`), the Dart additions it explicitly says not to add (`:241-258`), the service-account-as-Edge-secret design (`:264-272`), the ~55-minute OAuth cache (`:275-279`) and the HTTP v1 send (`:282-285`), and closes with `:351` "Do not claim FCM works until a real message is observed." Treated as **documentation, not implementation proof**.
- Alert dedupe: `safety_alerts` has two non-unique indexes and no dedup constraint, so a push fan-out would need idempotency in the sender.

**6. Hosted Supabase dependencies.** New `push_tokens` table + RLS, a migration (DEC-02 gated), a new or extended Edge Function for send (deployment gated), a Firebase service-account secret added to project secrets, and audit rows for delivery attempts. None of these can be executed while DEC-02 stands.

**7. Android/device dependencies.** Play-services-capable device for FCM (a ColourOS device without Play services may never receive — the tested child device is a realme `RMX2161`). Runtime `POST_NOTIFICATIONS` on Android 13+ (plumbing exists, parent-side request missing). OEM background restrictions. A stable installation identity for token rotation.

**8. Security and privacy implications.** A push token is a bearer capability to make a child's phone light up. Token storage must be RLS-scoped to the owning family, never client-readable by the other role beyond necessity, and revocable. Payloads must be metadata-free (no alert text, no location, no app names) because Google and the OEM see the payload. The child's phone must never be made to announce surveillance in a way that endangers the child. **FCM must remain non-authoritative: notification delivery must never determine security state, session state, or an enforcement claim.** `docs/backend.md:19` already records which functions have verify-JWT off; a push sender must be service-role-only.

**9. Owner decision options.**
- **(A) Realtime Only (in-app delivery / decline push):** safety alerts delivered strictly via Supabase Realtime WebSockets to active, foregrounded parent applications; make the product promise "alerts appear when the app is open", strengthen in-app polling plus a visible staleness indicator; zero third-party push dependencies.
- **(B) FCM as Non-Authoritative Wake-Up Transport (approved architecture):** dual-transport architecture with Realtime for live in-app delivery and FCM HTTP v1 for background wake-up; dedicated Firebase project, tokens stored hosted, service account as an Edge secret, opaque payloads (`alert_id`, `family_id`) only, Realtime retained as authoritative in-app path, delivery failures logged and never surfaced as security facts.
- **(C) Defer**, keeping DEC-14 open and shipping Option A's honest in-app only copy now.
- Sub-decisions: token lifecycle (per-installation vs per-device, revocation on unlink, cleanup of stale tokens); notification permission UX on the parent app (currently never requested); quiet hours and child-visible notification styling; deep-link vs blind-open; which alert types are push-worthy (`low_battery`, `offline`, `geofence_enter/exit`, `app_blocked`, `permission_missing`).

**10. Owner decision ruling.** **APPROVED — Option B (Realtime + FCM Non-Authoritative Wake-Up Transport)** on 2026-11-05 (Phase 9.5). Realtime remains authoritative and primary for in-app delivery; FCM acts as out-of-band wake-up transport with strictly opaque payloads (`alert_id`, `family_id`) and zero child PII. Push to child devices remains excluded. Implementation remains gated by DEC-02 and DEC-03.

**11. Acceptance criteria.**
- AC-14-1 A dedicated Firebase project exists with a recorded project id; `google-services.json` handling documented for fresh clones.
- AC-14-2 `push_tokens` schema + RLS + revocation path reviewed and (when DEC-02 allows) applied; registration, refresh and unlink covered by tests.
- AC-14-3 Credentials exist only as an Edge Function secret; no service-account JSON in the app, repository, or client-readable storage.
- AC-14-4 Payload carries no PII, no alert text, no location, no package name; verified by test.
- AC-14-5 Delivery outcome never feeds `enforcement_status`, session state, or any security decision (explicit non-authoritativeness test).
- AC-14-6 Realtime remains the authoritative in-app path; push is additive and degrades silently.
- AC-14-7 Invalid-token cleanup is bounded, logged and does not delete live devices.
- AC-14-8 A real message observed on both an FCM-capable device and on the realme device (record the negative result if it fails). Until then the status stays `NOT TESTED` (`docs/integrations-setup.md:351`).

**12. Out of scope.** Creating the Firebase project, adding credentials, changing schema, deploying functions, marketing/analytics SDKs, in-app purchase/ads SDKs, push to the child device (unless explicitly approved), and any covert notification behaviour.

**13. Dependencies.** Ranked after DEC-13/12/15 because it delivers events whose existence requires those features to be real. Hosted work is gated by DEC-02; device evidence by DEC-03.

**14. Required verification evidence.** Integration test with a stub transport proving the non-authoritative rule; a Deno test for the sender's error paths; on-device proof of one delivered alert; token-revocation demonstration after unlink; hosted read-only confirmation that anon/authenticated have no execute on the sender.

**15. Rollback / failure considerations.** Push is transport-only, so rollback is "stop sending": drop the secret, leave the table, and the product reverts to Realtime. Risk of orphaned tokens after reinstall must be handled by installation-scoped rows. A mis-scoped RLS policy on `push_tokens` would be a family-boundary breach, so that table needs the strictest review of the three decisions. A delivery failure must never be presented as "your child is safe" or "not safe" — it is only a missed notification.

---

## 4. DEC-15 — Website filtering

**1. Decision ID and title.** DEC-15 — Website filtering scope and mechanism.

**2. Current registered status.** **APPROVED — Option D (Website Filtering Deferred for Current Release)** by explicit owner ruling on 2026-11-05 (Phase 9.7). Detailed decision document: [`docs/dec-15-website-filtering-owner-decision.md`](dec-15-website-filtering-owner-decision.md). Implementation boundary in force: scope exclusion confirmed; website filtering excluded from current release; no implementation, provisioning, or hosted changes authorized.

**3. Problem statement.** The canonical inventory records the whole web-filtering family as absent: `FD-001`–`FD-014` and `FD-016`–`FD-026` are `MISSING` (`audit/01_COMPLETE_FEATURE_INVENTORY.md`; only `FD-015` is `NOT APPLICABLE`). Competing products offer URL-level filtering. Android cannot deliver that without either a VPN-transport app or a controlled browser, and neither exists here. The decision is which promise to make, not how to write code.

**4. Verified current implementation.**
- **Nothing is implemented for web filtering.** No `VpnService` subclass, no `BIND_VPN_SERVICE` permission, no `FOREGROUND_SERVICE_SPECIAL_USE` declaration, no DNS primitives, no proxy, no controlled WebView — all **NOT IMPLEMENTED** (manifest service blocks at `android/app/src/main/AndroidManifest.xml:79-82`, `:85-87`, `:90-93` declare only the three existing foreground services; the permission block at `:4-29` contains no VPN permission).
- **Reusable infrastructure that does exist** (each VERIFIED in code): offline policy cache `SecureStore.kt:73-83,106-128,148-160` (note: **no TTL**, `:162,171,176,182,199`); versioned apply/ack with policy-id correlation (`enforcement.ts` + `policy_enforcement.dart`, DEC-12 §4); whitelist validation of the policy document (`policy.ts:27-36,49-58,67-77,108,122-123,202`, caps at `:62-63,65,231`, ≤200 rules / ≤100 windows / ≤256 KB at `:38-45`); visible foreground-service conventions with ongoing notifications (`GuardianService.kt:38-45,267-273,519-522`; channels 4303 audio / 4202 location / 4101 guardian status, `:195-209`); telemetry/status plumbing (`device-telemetry/index.ts:68,157,239,357,429-430`); explicit consent language already used across child-facing surfaces (`remote_assistance_page.dart:24-28`, `child_requests_page.dart:118-119`, `child_home_tab.dart:393`, `child_enrollment_page.dart:329`) and denials (`child_settings_tab.dart:67`, `remote_session_page.dart:139`).

**5. Missing or incomplete implementation.** Everything required for filtering: transport, DNS/hostname policy engine, allowlist/blocklist storage in the policy schema (the schema is a closed whitelist and rejects unknown keys today, so `allowed_urls`/`blocked_hosts` cannot even be stored without a migration), a visible VPN state in the child UI, offline behaviour, and an escape hatch for the family.

**6. Hosted Supabase dependencies.** A policy-schema extension (blocked by DEC-02), likely new tables for host lists and filter events (web histories are a new data class with a new retention profile), and a rule-count/size re-evaluation of `policy.ts` caps.

**7. Android/device dependencies.** `VpnService` consent dialog on every connect, `FOREGROUND_SERVICE_SPECIAL_USE` for Android 14+, `INTERNET`/network state handling, IPv6 and Private DNS (DoT) bypass surfaces, OEM battery management, and the impossibility of silently starting a VPN. A managed-browser alternative needs `WebView` policy control or a custom browser, which is a different product surface entirely.

**8. Security and privacy implications.** **A VPN-transport filter sees traffic.** Even with a hostname-only design, claiming otherwise would be a privacy misrepresentation, and holding that pipeline is a responsibility the product must be able to refuse: no content inspection, no logging of page bodies, short retention, on-device rule evaluation. Conversely, domain filtering **cannot** see full URLs or HTTPS page content: SNI/hostname is the ceiling. Any filter can be defeated by another browser, Private DNS, a VPN, or Tailscale — which must be stated to guardians rather than implied away. `PolicyGuard.CRITICAL_PACKAGES` must never be overridden and banking-app protections must not be interfered with.

**9. Owner decision options.**
- **(A) VPN + DNS filtering (on-device).** Real coverage across all apps on the device, honest ceiling = hostname/SNI level, requires visible VPN consent, battery/connectivity cost, and one-VPN-slot conflict with a family's own VPN.
- **(B) Managed browser only.** Only what the child reads inside our browser is filtered; other browsers are unfiltered; cheap, no VPN, honest but narrow.
- **(C) Decline web filtering** and remove it from the roadmap (reclassifying the `FD-*` rows as deliberately out of scope, with the provenance note, rather than leaving them silently `MISSING`).
- Cross-cutting sub-decisions: allowlist versus blocklist default; whether the child sees the block reason; manual override by the child, by the guardian, or never; retention of filter events; which categories ship in v1; consent text; and what happens offline.

**10. Owner decision ruling.** **APPROVED — Option D (Defer Website Filtering for the Current Release)** on 2026-11-05 (Phase 9.7). Website filtering is formally excluded from the current release scope. Options A, B, and C were not selected and are retained as unselected historical evaluations. Product claims must accurately disclose that website filtering is not implemented. Future reconsideration requires a separate explicit owner decision. Implementation remains unauthorized.

**11. Acceptance criteria.**
- AC-15-1 Mechanism chosen and its ceiling written into user-facing copy: hostname-level only, no full-URL or HTTPS-content visibility, no claim of full website filtering.
- AC-15-2 Policy schema extended deliberately (new keys validated, caps re-derived, unknown keys still rejected) — hosted execution requires DEC-02.
- AC-15-3 Explicit, per-session, non-bypassable `VpnService` consent; no silent start; indicator visible in the OS and in-app.
- AC-15-4 Offline behaviour specified: cached rules apply (`SecureStore` has no TTL today — a filtering feature forces that decision).
- AC-15-5 Allowlist/blocklist semantics tested for edge cases: SNI-less connections, IP literals, DoT/DoH clients, IPv6, captive portals.
- AC-15-6 Bypass surface documented for guardians (other browsers, Private DNS, user-installed VPN).
- AC-15-7 Battery/connectivity impact measured and reported; a filter that kills the connection is a safety problem.
- AC-15-8 No content capture, no body logging, no interference with banking apps or system surfaces.

**12. Out of scope.** Implementing the VPN service, writing the filter engine, hosted schema changes while DEC-02 is pending, HTTPS inspection (technically out of the product's stated privacy posture), app-level content moderation, and screen recording (DEC-16).

**13. Dependencies.** Ranked second among features because it reuses the existing policy/ack/cache machinery but needs its own schema change; independent of DEC-14, gated by DEC-02 and by the owner's VPN-consent acceptance. Ordering versus DEC-13 is a judgement: filtering does not need Device Owner, so it is not blocked by it.

**14. Required verification evidence.** A prototype showing the VPN consent handshake, a rule-engine test matrix (allow/deny/unknown/IP-literal/DoH), a negative test proving no request body is ever read, on-device measurement of battery and reconnect behaviour, and hosted read-only proof that the new policy keys round-trip through `device-policy` validation.

**15. Rollback / failure considerations.** A VPN that starts but cannot route correctly makes the device offline — the worst possible failure for a child. The service must fail open (traffic flows, filtering disabled, guardian alerted) rather than closed. Rollback is: stop the tunnel, remove the notification, drop the policy keys; nothing hosted needs reversing if no rows were ever written. Filter-event retention creates a new privacy liability that must be deleted-on-unlink.

---

## 5. DEC-16 — Screen mirroring / screen recording scope

**1. Decision ID and title.** DEC-16 — Screen mirroring / screen recording: scope exclusion and provenance reconciliation.

**2. Current registered status.** **APPROVED — Option A (Screen Mirroring and Recording Excluded from Product Scope)** by explicit owner ruling on 2026-11-05 (Phase 9.9). Detailed decision document: [`docs/dec-16-screen-mirroring-recording-owner-decision.md`](dec-16-screen-mirroring-recording-owner-decision.md). Implementation boundary in force: formal product scope exclusion; screen mirroring, screen recording, and screenshots excluded from product scope; no implementation, provisioning, or hosted changes authorized. This confirms the original **2026-10-27** owner scope exclusion recorded in `docs/screen-recording-plan.md:1-15` ("Status: NOT IMPLEMENTED, and the owner decided on 2026-10-27 to keep it that way"). Registered in `phase-9-owner-decision-register.md` as APPROVED (Option A).

**3. Problem statement.** An external audit brief (§5.7) reportedly asks for screen mirroring. That document is not in the repository and cannot be treated as owner authorisation. At the same time two internal classifications disagree about how many rows are "not applicable" (3 vs 16). The reconciliation must prevent either fact from being used to re-open scope by implication.

**4. Verified current implementation.**
- **No capture of any kind.** `MediaProjection`, `VirtualDisplay`, screenshot APIs: **NOT IMPLEMENTED**, confirmed by repo-wide search in this pass (the only `screenshot` matches are QA evidence columns and product-promise strings; there is no capture code in `lib/` or `android/`).
- **The product promise is already shipped in the UI.** `docs/screen-recording-plan.md` lists the user-facing statements and `docs/api-contract.md:545-546`; live strings verified this pass at `child_settings_tab.dart:67` ("This app never records audio or video, takes screenshots, reads…"), `remote_session_page.dart:139` ("…does not record audio or video, take screenshots, or…"), `remote_assistance_page.dart:89-90`, `child_session_page.dart:146-147`. The plan states plainly that shipping capture while that copy stands would be a false statement to a minor.

**5. Missing or incomplete implementation.** Nothing to build — this is an exclusion. What is incomplete is **provenance hygiene**: the two classification sources are not cross-referenced, and the external brief's expectation is not reconciled anywhere in the repository.

**6. Hosted Supabase dependencies.** None. (A mirroring feature would imply media relay/storage; `webrtc_signals` exists for signalling, and no Storage bucket exists at all — verified live 2026-11-05 — so there is no hosted substrate for recorded media.)

**7. Android/device dependencies.** Not applicable while out of scope. If ever revisited: `MediaProjection` requires a per-session system dialog that cannot be suppressed, a visible recording indicator, and Android 14+ re-consent per session; `FOREGROUND_SERVICE_SPECIAL_USE` would be needed.

**8. Security and privacy implications.** Screen mirroring of a child's device shows banking apps, private messages, other people's chats and photos, and defeats every "we never record" promise currently displayed in the child's own UI. Keeping it out of scope is the privacy-preserving choice, and the existing UI copy makes that promise checkable by the child.

**9. Owner decision options.** Strictly confirmatory: **(A)** confirm the 2026-10-27 exclusion (recommended); **(B)** narrow the exclusion to live-viewing-with-explicit-child-consent only, which would require re-wording every promise listed in §4 and is a product reversal, not a feature; **(C)** commission a written scope re-evaluation with the external audit brief supplied to the repository so it can be evaluated as evidence.

**10. Owner decision ruling.** **APPROVED — Option A (Exclude Both Screen Mirroring and Recording from Product Scope)** on 2026-11-05 (Phase 9.9). Parent-to-child mirroring, child-to-parent mirroring, live display viewing, screen recording, screenshot capture, and MediaProjection integration are formally excluded from HAVEN product scope. Existing audio-only assistance and front-camera assistance remain separately governed. Existing privacy promises are preserved. Future reconsideration requires a formal product re-charter and a separate explicit owner decision. Implementation remains unauthorized.

**11. Acceptance criteria.**
- AC-16-1 The 2026-10-27 exclusion remains in force, with its date and document cited.
- AC-16-2 No capture code is added, and no capture-capable dependency is introduced.
- AC-16-3 The N/A discrepancy is documented rather than merged (§0.4), with both sources preserved and their dates and vocabularies intact.
- AC-16-4 The canonical `NOT APPLICABLE` rows stay exactly three — `FB-027`, `FC-080`, `FD-015` — re-counted 2026-11-05; `FB-015`–`FB-026` remain `MISSING` in the canonical inventory.
- AC-16-5 The external brief is marked not-authoritative-until-supplied and is not paraphrased as a requirement.

**12. Out of scope.** Any implementation of mirroring, screenshots, screen recording, content capture, remote viewing of the screen, or keylogging; and re-labelling either classification source's original statuses.

**13. Dependencies.** None — DEC-16 must not block the roadmap. It interacts with DEC-15 only in that both concern what the app is permitted to see.

**14. Required verification evidence.** A read-only re-count of the inventory (§0.4 — done this pass) and a repo-wide capture-API search (§4 — done this pass, negative).

**15. Rollback / failure considerations.** Not applicable while nothing is implemented. The failure mode here is documentary: a future reader treats the 16 N/A rows, or the external brief, as authorisation. That is precisely why both are preserved with provenance instead of being reconciled into a single number.

---

## 6. Roadmap proposal (proposal, not authorisation)

| Order | Step | Why this position | Verified or inferred |
|---|---|---|---|
| 1 | **DEC-13** mode decision | It determines which promises are physically possible on the shipped fleet (both active devices are `device_admin`; zero active `device_owner` — VERIFIED hosted 2026-11-05) and it needs a durable signing identity first | **VERIFIED dependency** for suspend-all; the signing prerequisite is VERIFIED in `build.gradle.kts:13-22,71-75` |
| 2 | **DEC-12** enforcement semantics | The false-`enforced` path exists in code, in tests and in production data (VERIFIED); the status-vocabulary fix (AC-12-11) can be made before any new enforcement primitive ships | **VERIFIED** |
| 3 | **DEC-15** website filtering | Largest new privacy surface; needs a policy-schema migration, so it must be sequenced against DEC-02 rather than assumed free | **INFERRED** — filtering does not require Device Owner, so this ordering is a product judgement, not a verified technical dependency |
| 4 | **DEC-14** push / FCM | Transport for events that only become meaningful once DEC-12/15 produce real state changes; needs both a new table and a new secret | **INFERRED** from the alert-type inventory, though "no tokens table" and "no Firebase secret" are VERIFIED hosted facts |
| 5 | **Runtime validation** | 75 QA rows are 100% `NOT RUN` (VERIFIED by count this pass); microphone items failed on build 4005 (later 2-min lock survival observed; 5m/15m locked endurance NOT TESTED; long-duration reliability NOT VERIFIED) | **BLOCKED by DEC-03** — cannot start without explicit owner authorisation |
| 6 | **Deployment readiness** | Four repository migrations are demonstrably not applied and no Edge Function has been deployed since 2026-10-27 (VERIFIED live) | **BLOCKED by DEC-02** |
| — | **DEC-16** | Scope exclusion; explicitly **not** a blocker for any row above | VERIFIED as a 2026-10-27 owner decision |

**Cross-cutting prerequisites, in order of hard dependency:** durable release signing → DEC-02 (hosted migrations) for any schema change → DEC-03 (device access) for any runtime claim. None of the three can be inferred from a DEC-12…DEC-16 ruling; each needs its own written owner authorisation. **Phase 10 remains unauthorised** (`phase-9-owner-decision-register.md:262` "NO initiation of Phase 10"; `:277` "No approval or closure should be inferred").

## 7. Open questions requiring owner input

1. Does "standard mode" remain the shipping promise, or is managed mode a sellable tier in this release? (DEC-13)
2. Is a hard screen-time lock allowed to block communication apps, and which surfaces are permanently exempt? (DEC-12)
3. Is a guardian-granted emergency override acceptable, given it weakens the limit's credibility by design? (DEC-12)
4. Will the owner accept the Device Owner teardown problem — factory reset as the only reliable removal — for real families? (DEC-13, `docs/device-owner-provisioning.md:709-724`)
5. Push to the **child** device: approved or prohibited outright? (DEC-14 §9)
6. Is a per-connection VPN consent dialog acceptable to the target user, knowing it consumes the device's single VPN slot? (DEC-15)
7. Which `enforcement_status` expression is wanted for "limit accepted, not enforceable here": a new value (needs DEC-02) or `unsupported` + a specific `last_error`? (DEC-12 AC-12-11)
8. Should the hosted production account with `enforced` and zero-app-target policy `d4a05b68-…` be re-derived by code, or left as historical data with a documented note? (DEC-12 AC-12-12)
9. Sign-up on production is currently open ("Allow new users to sign up" checked; read 2026-11-05, current-state observation only — this pass changed no Auth setting). Is that intended for a closed beta, or does it need a DEC-02-gated settings change? (hosted report §7)
10. Should the external audit brief §5.7 be supplied to the repository so DEC-16 can be formally closed rather than left reconciled-by-inference? (DEC-16 §9 option C)
11. SMTP remains documented as blocked/not tested and was not re-verified read-only this pass — is e-mail alerting abandoned in favour of DEC-14, or does it need its own decision? (DEC-14)

## 8. Compliance statement

No feature was implemented. No Dart, Kotlin, TypeScript or SQL source file was modified. No migration was created or applied. No Edge Function was deployed. No Firebase project was created and no credential was added, read or printed. No hosted state was mutated in any way; hosted inspection was SELECT-only and confined to project `hhqgreaoqulmfwfwarhc`. No APK was built, no ADB command was issued, no device was paired, provisioned or tested, and the personal Realme `RMX2161` was not used. No scheduler, cron job, webhook or sweep was created or run. No Git state-changing operation was performed — no `add`, `reset`, `clean`, `checkout`, `restore`, `stash`, branch change, commit, push, rebase, merge or cherry-pick; the staged index as found (1 staged addition and 16 staged modifications) was left exactly as found and is re-verified at the end of this pass. The files written by this task are documentation only: this file, `docs/supabase-hosted-state-verification-2026-11-05.md`, `docs/phase9-owner-decision-reconciliation-report.md`, and a dated additive section in `phase-9-owner-decision-register.md` with its byte-identical mirror `docs/implementation/phase-9-owner-decision-register.md`. No historical decision record or decision date was rewritten. DEC-12 through DEC-16 are **APPROVED** (by explicit owner decisions recorded on 2026-11-05 in Phases 9.2, 9.3, 9.5, 9.7, and 9.9); DEC-01, DEC-03, DEC-05 and DEC-04/DEC-06…DEC-11 retain their registered statuses; **Phase 10 was not started.**
