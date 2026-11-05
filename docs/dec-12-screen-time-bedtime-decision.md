# DEC-12 — Screen-Time & Bedtime Enforcement Decision Package

**Decision ID:** DEC-12  
**Status on 2026-11-05 (Phase 9.3):** **APPROVED — Explicit Owner Rulings (D1-B, B1-B, O1-C, P1-A, DEFER)**  
**Repository:** `D:\parentcontrol_app` (branch `main`, HEAD `b398ab8425b256f5991aed0dd55b8ccd1d71fbe6`)  
**Supabase Context:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Inherited Architectural Foundation:** **DEC-13 APPROVED (Option B — Managed Mode Required for Full Enforcement)**; Device Administrator retired; non-destructive safe exit is mandatory release blocker.  
**Related Governance:** DEC-01 APPROVED (Choice B) · DEC-02 PENDING/BLOCKED · DEC-03 PENDING/BLOCKED (75/75 QA rows NOT RUN) · DEC-05 APPROVED (Choice B) · DEC-12 APPROVED · DEC-13 APPROVED · DEC-14…DEC-16 PROPOSED · Phase 10 NOT AUTHORISED.  
**Related Documents:** [`docs/p0-decision-specifications.md:45-122`](file:///D:/parentcontrol_app/docs/p0-decision-specifications.md#L45), [`docs/dec-13-device-owner-decision.md`](file:///D:/parentcontrol_app/docs/dec-13-device-owner-decision.md), [`docs/supabase-hosted-state-verification-2026-11-05.md:176`](file:///D:/parentcontrol_app/docs/supabase-hosted-state-verification-2026-11-05.md#L176), [`phase-9-owner-decision-register.md`](file:///D:/parentcontrol_app/phase-9-owner-decision-register.md).

---

## 1. Owner Approval & Decision Summary

On 2026-11-05 (Phase 9.3), the project owner explicitly approved all five decision areas for **DEC-12 (Screen-Time & Bedtime Enforcement)**:

| Decision Area | Owner-Approved Choice | Governing Meaning & Scope | Governance Status |
|---|---|---|---|
| **Daily Screen-Time Limit** | **Choice D1-B (Mode-Split)** | Standard Mode = advisory notification only; Managed Mode = hard package suspension via `setPackagesSuspended` upon quota exhaustion. Limit must not be reported as `enforced` unless physical enforcement is verified. | **APPROVED** |
| **Bedtime Enforcement** | **Choice B1-B (Hard Suspension in Managed)** | Managed Mode = hard bedtime package suspension across scheduled overnight window; Standard Mode = advisory notification only. Bedtime must not be reported as `enforced` while evaluation is informational. | **APPROVED** |
| **Emergency Override** | **Choice O1-C (Child Emergency Pass, 10 Minutes)** | Child-initiated emergency pass lasting exactly 10 minutes. Dialers, emergency numbers, and safety-critical system access are strictly immune. Pass auto-expires, cannot be chained silently, and is audit-logged. | **APPROVED** |
| **Per-App Daily Limits** | **Choice P1-A (Deferred)** | Per-app duration quotas are deferred to Phase 10. Excluded from immediate DEC-12 scope to avoid premature schema changes. | **APPROVED (DEFERRED TO PHASE 10)** |
| **Production Row Remediation** | **Choice DEFER** | No update to hosted `device_policies` row `d4a05b68…` or historical command acks. Requires separate future hosted authorization under DEC-02. | **APPROVED (DEFERRED)** |

**Strict Authorization Boundary:** This approval authorizes the product specification and governance records only. It does **NOT** authorize code implementation, device testing, APK builds, ADB commands, hosted migrations, Edge Function deployments, or Phase 10 execution.

---

## 2. Problem Statement & Verified Code Baseline

In the HAVEN Parental Control parent UI, a guardian can configure a daily screen-time budget (e.g. 120 minutes) and a bedtime schedule (e.g. 21:00 to 07:00). The backend accepts, validates, and stores these fields on `public.device_policies`.

However, the verified code inspection across Phase 9.1 and 9.2 identified three critical defects:

1. **Daily limits are measurement-only on the device:** `daily_screen_time_limit_minutes` is parsed from policy JSON ([`PolicyJson.kt:16`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/PolicyJson.kt#L16)) and stored in memory ([`PolicyModels.kt:43`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/PolicyModels.kt#L43)), but **zero readers exist** in `PolicyApplier.kt` or `GuardianService.kt`. No code compares usage against the budget, and no action stops app use when the budget expires.
2. **Bedtime is evaluated only as an informational boolean:** [`PolicyApplier.kt:369-370`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt#L369) explicitly notes: `"bedtime is stored but app suspension follows app rules"`. Bedtime merely sets `result.put("bedtime_active", ...)` in the ack. No system-wide lock or bedtime enforcement action occurs.
3. **The backend falsely marks limits-only policies as `enforced`:** In [`supabase/functions/device-command/enforcement.ts:51-58, 122-129`](file:///D:/parentcontrol_app/supabase/functions/device-command/enforcement.ts#L51), `policyTargetsApps` checks only `blocked_packages`, `app_rules[].blocked`, and `block_all_except_allowed`. A policy specifying only a daily limit or bedtime evaluates `targetsApps = false`. With `desiredCount == appliedCount == 0`, `decideEnforcement` incorrectly returns `status: "enforced"` and advances `devices.policy_version`.
4. **Live production contamination:** Hosted row `d4a05b68-eff2-4dca-a794-86ced2565a48` (version 1) is stored as `enforced` with `last_error: null`, despite having empty `blocked_packages`, empty `app_rules`, and suspending zero apps.

---

## 3. Approved Product Behavior vs. Technical Open Questions

To maintain architectural rigor, the product requirements approved by the owner must be cleanly distinguished from the technical details that still require engineering design:

### 3.1 Approved Product Behavior (Owner-Decided)
1. **Standard Daily Screen-Time Limit:** Advisory notification only. Never promises app suspension; never marked `enforced`.
2. **Managed Daily Screen-Time Limit:** Hard package suspension of targeted/non-exempt apps via `setPackagesSuspended` once budget is exhausted.
3. **Standard Bedtime:** Advisory notification to child and parent. No suspension.
4. **Managed Bedtime:** Hard package suspension of targeted/non-exempt apps during scheduled bedtime window.
5. **Child Emergency Pass:** A 10-minute child-initiated safety window that temporarily unsuspends essential apps and alerts parents.
6. **Per-App Quotas:** Excluded from DEC-12; deferred to Phase 10.
7. **Hosted Data Remediation:** Stored row `d4a05b68…` remains untouched until separate hosted authorization.

### 3.2 Technical Open Questions Requiring Future Implementation Design
1. **Daily Usage Accounting:** Polling cadence of `UsageStatsManager.queryUsageStats()` versus battery drain. Reconciling foreground timestamps across apps.
2. **Local Midnight & Timezone Transitions:** Detecting device timezone changes or manual clock manipulation. Resetting daily usage counters accurately at local midnight (00:00).
3. **Offline Operation:** Preserving and enforcing accumulated usage when network connectivity is lost. Preventing clock rollback to gain screen time.
4. **Reboot Recovery:** Restoring suspended state immediately upon boot if the daily quota was already exceeded before shutdown.
5. **Foreground/Background Accounting:** Deciding whether split-screen, picture-in-picture (PiP), or background audio counts against screen time.
6. **Enforcement Counter Reconciliation:** Ensuring `desired_count`, `applied_count`, and `failed_count` accurately reflect both package suspension rules and limit states.
7. **Safe App Exclusions:** Guaranteeing emergency dialer (`PolicyGuard.CRITICAL_PACKAGES`), default home launcher, and active IME are immune to suspension.
8. **Device Owner Loss During Active Suspension:** Handling external removal of DO status while packages are suspended to prevent stranded packages.
9. **Emergency Pass Lifecycle:** Tracking the 10-minute pass countdown across device reboots or process termination.

---

## 4. Standard Mode vs. Managed Mode Architecture (Under Approved DEC-13)

Under the approved **DEC-13 (Option B)** architecture, Device Administrator mode is retired. Enforcement capabilities for DEC-12 divide cleanly into two operating tiers:

```
+----------------------------------------------------------------------------------------------------+
|                                    DEC-12 ENFORCEMENT HIERARCHY                                    |
+-------------------------------------------------+--------------------------------------------------+
| STANDARD MODE (Baseline Android)                | MANAGED MODE (Device Owner)                      |
+-------------------------------------------------+--------------------------------------------------+
| * Ordinary Android permissions (`PACKAGE_USAGE`) | * Full Device Owner authority.                   |
| * Usage measurement & aggregation active.       | * Usage measurement & threshold enforcement.     |
| * NO app suspension capability.                 | * Hard app suspension (`setPackagesSuspended`).  |
| * Quota exceeded -> Advisory notification only. | * Quota exceeded -> Suspend non-critical apps.   |
| * Bedtime -> Advisory notification only.        | * Bedtime -> Scheduled suspension of apps.       |
| * Backend reports: `unsupported` or             | * Backend reports: `enforced` (with valid        |
|   `partially_enforced` (never `enforced`).      |   proving counters and matched policy ID).       |
+-------------------------------------------------+--------------------------------------------------+
```

### 4.1 Standard Mode (Advisory Only)
- The application collects usage via `UsageStatsManager` and sends daily summaries (`usage_daily`) to the parent.
- When the daily budget expires or bedtime begins, the child device displays a local system notification ("Screen-time limit reached").
- Applications are **not** suspended.
- Telemetry acknowledges the policy with `enforcement_supported = false`.
- The parent UI displays the device status as "Advisory only" or "Unsupported on this device", never claiming apps are blocked.

### 4.2 Managed Mode (Device Owner Enforcement)
- The application evaluates usage against `daily_screen_time_limit_minutes` on every tick (60 seconds).
- When usage exceeds the budget or bedtime is active, `PolicyApplier` invokes `DevicePolicyManager.setPackagesSuspended(admin, packages, true)` for all non-critical candidate packages.
- Critical system components, emergency dialer, default launcher, and active IME are strictly excluded from suspension.
- Telemetry ack returns `enforcement_supported = true`, `desired_count > 0`, and `applied_count == desired_count`.
- Once verified by the OS via `dpm.isPackageSuspended()`, the backend updates `device_policies.enforcement_status = 'enforced'`.

---

## 5. Enforcement-Status Wire Contract & Reporting Truthfulness

A policy must **never** be marked `enforced` simply because it was accepted by the server or its version advanced. The status definitions on `public.device_policies.enforcement_status` must reflect physical device reality:

| Status Value | Strict Technical Definition | Proof Requirements | Advance Version? |
|---|---|---|---|
| **`pending`** | Policy has been written to database or sent to device, but no valid acknowledgement has returned. | Awaiting device ack; command not expired. | NO |
| **`enforced`** | All targeted app blocks and/or managed limits are physically confirmed active on device. | `enforcement_supported == true` AND `isMatched == true` AND `applied_count == desired_count` AND `desired_count > 0` AND `failed_count == 0`. | **YES** |
| **`partially_enforced`** *(Proposed Vocabulary)* | Policy is active in Standard Mode (monitoring/advisory active), OR some packages succeeded while others failed. | Explicit ack indicating advisory limits active without suspension, OR `applied_count > 0 && failed_count > 0`. | **YES** *(Advisory)* / **NO** *(Errors)* |
| **`unsupported`** | Policy requires capabilities absent on this device (e.g. app suspension on Standard device). | `enforcement_supported == false` OR device not Device Owner. | **YES** *(Prevents retry loop)* |
| **`failed`** | Device threw an unhandled exception, DPM call failed, or ack delivery was rejected. | `success == false` OR DPM `SecurityException`. | NO |

### Proof Counter Invariants
Every policy acknowledgement payload returned by `GuardianService` to `device-command` must carry:
1. `policy_id`: Exact UUID of the policy evaluated (prevents stale ack correlation).
2. `policy_version`: Version number matched to device.
3. `enforcement_mode`: Wire mode (`none` or `device_owner`).
4. `enforcement_supported`: Boolean flag (`true` only if Device Owner).
5. `desired_count`: Total candidate targets (including uninstalled and limit targets).
6. `applied_count`: Packages physically confirmed suspended via `dpm.isPackageSuspended`.
7. `failed_count`: Packages that failed suspension or could not be verified.
8. `failures`: Array of `{ package_name, reason }` entries.

---

## 6. Safety & Operational Requirements for Emergency Pass (Choice O1-C)

The approved Choice O1-C specifies a **child-initiated emergency pass lasting exactly 10 minutes**. To preserve physical safety and prevent abuse, future implementation must adhere to these 12 requirements:

1. **Explicit Child Initiation:** The pass is triggered exclusively by an intentional gesture in the Child UI (e.g. "I need an emergency pass" with confirmation).
2. **Unambiguous Duration Copy:** Child UI prominently states: "You have 10 minutes of emergency access. Your guardian will be notified."
3. **Accurate Timestamping:** Start timestamp and exact expiration timestamp (`start_time + 600s`) are recorded in encrypted local storage (`SecureStore`) and transmitted to backend.
4. **Anti-Chaining / Anti-Extension Protection:** A child cannot request a new pass while one is active, nor immediately re-trigger a pass upon expiration. The duration is strictly fixed at 10 minutes; no silent extension is permitted.
5. **No Privilege Escalation:** The pass temporarily unsuspends designated essential applications (e.g. transit, maps, communication); it does not grant administrative privileges, alter parent settings, or remove device management.
6. **Safety-Critical Immunity:** Emergency dialer (911/112/999) is permanently available regardless of pass state. The pass is intended for secondary safety needs (e.g. rideshare, messaging parents, navigation).
7. **Strict Scope:** Entertainment, social media, and gaming packages remain suspended during the emergency pass. Only pre-configured essential categories are temporarily restored.
8. **Crash & Reboot Recovery:** If the device reboots or `GuardianService` restarts during an active pass, the app checks the persisted expiration timestamp against current wall-clock time. If the 10 minutes have elapsed, restrictions re-apply immediately. If time remains, the pass continues until the original expiration.
9. **Honest Expiry Enforcement:** At `expiry_time`, `PolicyApplier` automatically re-suspends the packages via `dpm.setPackagesSuspended(admin, packages, true)` without waiting for parent action.
10. **Parent Audit & Immediate Notification:** An urgent alert is generated on `public.safety_alerts` with severity `high` and logged to `public.audit_logs`.
11. **Offline Operation:** The pass functions fully offline using monotonic device uptime checks to prevent device clock manipulation. The alert payload queues for upload upon next connection.
12. **Recorded Open Technical Questions:** Handling edge cases where device battery dies during the pass, or where GPS/network location is required during the transit pass.

---

## 7. Deferred Scope Disciplines

### 7.1 Per-App Daily Limits (Choice P1-A) — DEFERRED TO PHASE 10
- **Ruling:** Individual duration limits per application (e.g. "YouTube: 30 minutes/day") are deferred.
- **Rationale:** The current database schema (`public.device_policies`) and Kotlin parser support only total daily screen time and per-app boolean blocks/windows. Adding per-app daily duration quotas would require adding new JSON fields or database columns, gating deployment behind DEC-02, and complicating background usage tracking.
- **Governance:** Phase 10 remains unauthorized.

### 7.2 Production Row Remediation — DEFERRED
- **Ruling:** Hosted row `d4a05b68-eff2-4dca-a794-86ced2565a48` on `parent-control-prod` remains stored as `enforced`.
- **Rationale:** Direct manual database updates without audited migration procedures violate governance restrictions. Remediation will be included in a future authorized maintenance pass under DEC-02.

---

## 8. Release Dependencies & Governance Gates

The implementation and release of screen-time and bedtime enforcement are subject to the following dependency sequence:

```
+----------------------------------------------------------------------------------------------------+
|                                    DEC-12 / DEC-13 RELEASE DEPENDENCY MAP                          |
+----------------------------------------------------------------------------------------------------+
|                                                                                                    |
|    1. [DEC-13 APPROVED (Option B)]                                                                 |
|                 │                                                                                  |
|                 ▼                                                                                  |
|    2. [DEC-12 APPROVED (D1-B, B1-B, O1-C, P1-A, DEFER)]                                            |
|                 │                                                                                  |
|                 ▼                                                                                  |
|    3. [GATE-EXIT-01: In-App Safe Exit Implementation] (DEC-13 MANDATORY RELEASE BLOCKER)           |
|                 │                                                                                  |
|                 ▼                                                                                  |
|    4. [GATE-DEC12-01: Kotlin Limit Monitor & Emergency Pass Design]                                |
|                 │                                                                                  |
|                 ▼                                                                                  |
|    5. [GATE-HOST-01: DEC-02 Hosted Migrations & Edge Function Deployment] (P1 RELEASE BLOCKER)     |
|                 │                                                                                  |
|                 ▼                                                                                  |
|    6. [GATE-AND-01: DEC-03 Android QA Hardware Execution (75/75 Rows)] (P1 RELEASE BLOCKER)        |
|                 │                                                                                  |
|                 ▼                                                                                  |
|    7. [FINAL RELEASE REVIEW]                                                                       |
|                                                                                                    |
+----------------------------------------------------------------------------------------------------+
```

### Gate Classification Table
| Gate ID | Area | Status | Authority Requirement |
|---|---|---|---|
| **DEC-13** | Architecture: Option B | **APPROVED** | Established by owner ruling on 2026-11-05. |
| **DEC-12** | Screen-Time: D1-B, B1-B, O1-C, P1-A | **APPROVED** | Established by owner ruling on 2026-11-05. |
| **GATE-EXIT-01** | Safe In-App DO Teardown | **NOT DESIGNED / RELEASE BLOCKER** | Required before Managed Mode can ship. |
| **GATE-DEC12-01** | DEC-12 Native Implementation | **NOT IMPLEMENTED** | Requires future implementation authorization. |
| **DEC-02** | Hosted Migrations & Edge Functions | **PENDING / BLOCKED (P1)** | Requires separate hosted authorization. |
| **DEC-03** | Android QA Hardware Matrix (75 Rows) | **PENDING / BLOCKED (P1)** | Requires separate hardware authorization. |
| **GATE-KEY-01** | Release Signing Keystore | **DEFERRED** | Requires separate keystore authorization. |

---

## 9. Rollback & Failure Behavior

1. **Safety Fail-Open:** If the background service crashes or local policy evaluation fails while packages are suspended, `BootReceiver` or crash handlers must attempt differential restoration so the child is not left with a bricked device.
2. **Report Fail-Closed:** If an ack is lost or network drops, status remains `pending`. The parent UI must never infer enforcement without receiving a verified counter payload.
3. **Policy Rollback:** Reverting a policy sends a new incremental policy version. `PolicyApplier.restorePackages()` restores all packages removed from the candidate set.

---

## 10. Acceptance Criteria (Measurable Quality Gates)

| Criteria ID | Requirement | Verification Method | Governance Gate |
|---|---|---|---|
| **AC-12-1** | `daily_screen_time_limit_minutes` is read by Android enforcement loop and compared against `UsageStatsManager` daily total. | Kotlin unit test (`PolicyApplierTest`) | Implementation Gate |
| **AC-12-2** | A limits-only policy on a Standard device reports `unsupported` or `partially_enforced`; NEVER `enforced`. | Deno test (`enforcement_test.ts`) | Implementation Gate |
| **AC-12-3** | In Managed Mode, exhausting daily limit suspends non-critical packages; restoring quota restores packages. | Hardware device test | **BLOCKED (DEC-03)** |
| **AC-12-4** | Emergency calling (dialer, 911/112), default launcher, and keyboard are provably immune to limit suspension. | Automated test & Hardware test | **BLOCKED (DEC-03)** |
| **AC-12-5** | Bedtime crossing midnight correctly maintains suspension across 00:00 until end time. | JVM unit test (`PolicyWindowTest`) | Implementation Gate |
| **AC-12-6** | Uninstalled target packages do not silently vanish; they are reported in ack under `uninstalled_targets`. | Kotlin code & Edge Function test | Implementation Gate |
| **AC-12-7** | Child UI clearly displays remaining screen time and shows honest enforcement state. | Flutter widget test | Implementation Gate |
| **AC-12-8** | Emergency override (10 minutes) automatically expires after 600s, cannot be chained, and logs to `audit_logs`. | Edge Function & Flutter test | Implementation Gate |
| **AC-12-9** | All 75 QA hardware execution rows relevant to enforcement are completed. | Hardware QA execution | **BLOCKED (DEC-03)** |

---

**DEC-12 is APPROVED (Choices D1-B, B1-B, O1-C, P1-A, DEFER). DEC-13 is APPROVED (Option B). No implementation, device provisioning, APK build, ADB operation, hosted mutation or deployment was performed. Awaiting future owner authorization for implementation.**
