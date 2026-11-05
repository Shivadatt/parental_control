# Phase 9.2 DEC-13 Approval Recording & DEC-12 Decision Readiness Report

**Document ID:** PHASE-9-2-READINESS-REPORT  
**Date:** 2026-11-05  
**Status:** **DEC-13 APPROVED (Option B) · DEC-12 PROPOSED (Decision-Ready)**  
**Repository:** `D:\parentcontrol_app` (branch `main`, HEAD `b398ab8425b256f5991aed0dd55b8ccd1d71fbe6`)  
**Supabase Context:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Canonical Governance Registers:** [`phase-9-owner-decision-register.md`](file:///D:/parentcontrol_app/phase-9-owner-decision-register.md) and [`docs/implementation/phase-9-owner-decision-register.md`](file:///D:/parentcontrol_app/docs/implementation/phase-9-owner-decision-register.md)  
**Deliverables Prepared:**
- [`docs/dec-13-device-owner-decision.md`](file:///D:/parentcontrol_app/docs/dec-13-device-owner-decision.md) (Updated with owner rulings & safe-exit architecture)
- [`docs/dec-12-screen-time-bedtime-decision.md`](file:///D:/parentcontrol_app/docs/dec-12-screen-time-bedtime-decision.md) (Canonical DEC-12 decision package)
- [`docs/p0-decision-specifications.md`](file:///D:/parentcontrol_app/docs/p0-decision-specifications.md) (Updated with DEC-13 approval & DEC-12 alignment)

---

## 1. DEC-13 Owner Ruling Recorded

The project owner has explicitly approved **DEC-13** under the Phase 9.2 review cycle. The explicit rulings and governance statuses have been canonically recorded across both decision registers:

| Decision Dimension | Owner Ruling | Governance Status | Scope & Authority Limits |
|---|---|---|---|
| **Product Architecture** | **OPTION B — Managed Mode Required for Full Enforcement** | **APPROVED** | Authorizes Option B as the architectural standard. Standard Android permissions serve as the baseline; Device Owner is required for full app suspension. |
| **Safe Exit Mechanism** | **Non-destructive in-app Device Owner exit is mandatory** | **APPROVED REQUIREMENT / RELEASE BLOCKER** | Factory reset must NOT be the only consumer teardown mechanism. Managed Mode cannot be released until this capability is verified. |
| **Device Administrator Mode** | **Retire Device Administrator mode and label completely** | **APPROVED REQUIREMENT** | Device Administrator is removed from the product ladder, UI, and telemetry. |
| **Release Signing Keystore** | **Deferred** | **DEFERRED / NOT AUTHORIZED** | Creation of `android/key.properties` and release keystore generation requires separate future authorization. |
| **Implementation Scope** | **Documentation and decision-preparation only** | **STRICT BOUNDARY IN FORCE** | Zero code modification, zero APK compilation, zero ADB execution, zero device provisioning, zero hosted Supabase changes. |

---

## 2. Decision Register Integrity Verification

In accordance with strict governance rules, both decision register files were updated additively and verified for byte-for-byte equality:
- **Canonical Register:** `phase-9-owner-decision-register.md`
- **Companion Mirror:** `docs/implementation/phase-9-owner-decision-register.md`
- **Verification Method:** PowerShell `Get-FileHash -Algorithm SHA256`
- **Result:**
  - `docs/implementation/phase-9-owner-decision-register.md`: `8F9636668E192E32B3CCA8B0E5AFBD5EC087C2A43C1E05402059D8D7439AD3C9`
  - `phase-9-owner-decision-register.md`: `8F9636668E192E32B3CCA8B0E5AFBD5EC087C2A43C1E05402059D8D7439AD3C9`
  - **Status:** **100% BYTE-IDENTICAL (MATCH)**.

No historical entries were modified, reordered, or deleted.

---

## 3. Standard Mode vs. Managed Mode Architecture

Under approved DEC-13 Option B, the product eliminates the ambiguous Device Administrator tier and establishes a clear binary protection model:

```
+----------------------------------------------------------------------------------------------------+
|                                    HAVEN ARCHITECTURAL TIERS                                       |
+-------------------------------------------------+--------------------------------------------------+
| STANDARD PROTECTION TIER                        | FULLY MANAGED PROTECTION TIER                    |
+-------------------------------------------------+--------------------------------------------------+
| * Ordinary Android permissions (`PACKAGE_USAGE`,| * Android Enterprise Device Owner status.        |
|   location, microphone, notifications).         | * Full hardware/OS authority.                    |
| * Usage measurement & aggregation.              | * Hard app suspension (`setPackagesSuspended`).  |
| * Real-time location tracking & safe zones.     | * Hard daily screen-time quota enforcement.      |
| * Remote audio assistance (consented).          | * Automated bedtime app locking.                 |
| * Advisory screen-time & bedtime notifications. | * Non-destructive in-app safe exit mechanism     |
| * App suspension strictly marked `unsupported`. |   (Mandatory Release Blocker).                   |
+-------------------------------------------------+--------------------------------------------------+
```

### Invariant Rules
1. **Fallback on Failure:** If Device Owner provisioning fails or is interrupted, the device remains in Standard Mode. The UI never assumes or claims full enforcement.
2. **Honest Downgrade on Ownership Loss:** If Device Owner authority is revoked or removed externally, the application immediately downgrades its reported mode to `none`, and the backend returns `unsupported` (`device_owner_required`).

---

## 4. Safe Device Owner Exit Feasibility Findings

Android's platform architecture imposes strict constraints on Device Owner teardown that define the feasibility of a non-destructive exit:

### 4.1 Technical Realities of Android Device Owner Teardown
1. **The Programmatic API (`clearDeviceOwnerApp`):** AOSP provides `DevicePolicyManager.clearDeviceOwnerApp(String packageName)`. It is callable only by the active Device Owner.
2. **The Orphaned Suspensions Hazard:** If `clearDeviceOwnerApp()` is invoked while packages remain suspended via `setPackagesSuspended()`, the application loses owner authority instantly. It cannot subsequently unsuspend them. The suspended applications become permanently disabled on the child's device until a factory reset.
3. **The Active Admin Detachment:** Clearing Device Owner does not automatically remove the active admin component; `dpm.removeActiveAdmin(adminComponent)` must also be executed.
4. **Permanent Disassociation on User Builds:** On production devices with accounts present, Android strictly prevents setting a new Device Owner programmatically. Once cleared, the device cannot be re-managed without account deletion or a factory reset.

### 4.2 The 12-Step Safe Exit Protocol
To satisfy the owner's mandatory release blocker, future implementation must execute this sequence:
1. **Parent Authentication:** Parent triggers exit via Parent UI or provides a one-time parent authorization token.
2. **Child Transparency:** Child UI displays unenrollment progress.
3. **Server Validation:** Backend validates parent authorization via secure RPC and revokes pending commands.
4. **Command Cancellation:** Active sync tasks and polling loops are suspended.
5. **Restriction Restoration:** `PolicyApplier.restoreAll()` unsuspends all tracked packages.
6. **OS Verification:** App loops through `dpm.isPackageSuspended()` to physically confirm 100% of apps are restored.
7. **Policy Neutralization:** Local encrypted policy store is cleared.
8. **Owner Removal:** App calls `dpm.clearDeviceOwnerApp()` followed by `dpm.removeActiveAdmin()`.
9. **Credential Wipe:** Local device installation secrets are wiped.
10. **Backend Deregistration:** Device notifies backend; backend marks device `enforcement_mode = 'none'`.
11. **Interruption Recovery:** Idempotent recovery state ensures partial failure leaves the app in an exit-continuation mode.
12. **Honest Failure Notification:** If OEM restrictions block teardown, the system clearly advises the family rather than falsely claiming success.

---

## 5. Device Administrator Retirement Implications

The owner's decision to retire Device Administrator mode resolves a significant source of user confusion and technical debt:
- **Zero Capability Loss:** Code inspection confirmed that `device_admin.xml` requested `<uses-policies />` with zero policies, and `ParentControlDeviceAdminReceiver.kt` was an empty stub. Granting Device Admin conferred zero app-blocking power.
- **Simplified Wire Protocol:** The wire contract will simplify from `('none', 'device_admin', 'device_owner')` to `('none', 'device_owner')`.
- **UI Streamlining:** Warning banners explaining "Device admin only — app blocking is not available" ([`child_shell_controller.dart:131-133`](file:///D:/parentcontrol_app/lib/features/child/controllers/child_shell_controller.dart#L131)) will be eliminated in favor of clean Standard Mode vs. Managed Mode copy.

---

## 6. Release Signing Keystore Deferral

- **Status:** **DEFERRED / NOT AUTHORIZED**.
- **Context:** `android/key.properties` does not exist in the repository; builds currently fall back to the Android debug key ([`build.gradle.kts:67-77`](file:///D:/parentcontrol_app/android/app/build.gradle.kts#L67)).
- **Governance:** Because Device Owner binds to the signing key certificate digest, production provisioning cannot occur with a debug key. The owner has explicitly deferred keystore creation to a separate authorized build preparation phase.

---

## 7. DEC-12 Technical Findings & Decision Preparation

DEC-12 (Screen-Time & Bedtime Enforcement) has been structured as a comprehensive decision package in [`docs/dec-12-screen-time-bedtime-decision.md`](file:///D:/parentcontrol_app/docs/dec-12-screen-time-bedtime-decision.md):

### 7.1 Verified Baseline
1. `UsageStatsManager` measures foreground daily usage correctly ([`UsageReporter.kt:21-86`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/UsageReporter.kt#L21)).
2. `daily_screen_time_limit_minutes` is parsed from JSON ([`PolicyJson.kt:16`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/PolicyJson.kt#L16)), but has **zero readers** in Kotlin enforcement code.
3. Bedtime window is evaluated ([`PolicyModels.kt:51`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/PolicyModels.kt#L51)), but only sets an informational boolean in telemetry ack ([`PolicyApplier.kt:370`](file:///D:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt#L370)).
4. `queryDailyUsage` has zero production callers in Dart.
5. In [`enforcement.ts:122-129`](file:///D:/parentcontrol_app/supabase/functions/device-command/enforcement.ts#L122), limits-only policies with 0 suspended apps incorrectly evaluate to `status: "enforced"`.
6. Live hosted row `d4a05b68-eff2-4dca-a794-86ced2565a48` is falsely stored as `enforced`.

### 7.2 Decision Choices Prepared for the Owner
- **A. Daily Limit Action:**
  - *Choice D1-A:* Advisory notifications only across all devices.
  - *Choice D1-B (Recommended):* Mode-split — Advisory notification in Standard Mode; hard suspension of non-critical apps in Managed Mode.
  - *Choice D1-C:* Overlay lock screen in Standard Mode (vulnerable to child bypass).
- **B. Bedtime Execution:**
  - *Choice B1-A:* Warning window then suspension.
  - *Choice B1-B (Recommended):* Hard boundary suspension in Managed Mode; advisory alerts in Standard Mode.
  - *Choice B1-C:* Informational schedule only.
- **C. Emergency Override:**
  - *Choice O1-A:* None (parent must modify policy).
  - *Choice O1-B:* Parent remote extension grant.
  - *Choice O1-C (Recommended):* Child emergency safety pass (10 minutes, parent alerted, auto-expiring).
- **D. Per-App Limits Scope:**
  - *Choice P1-A (Recommended):* Defer per-app duration limits to Phase 10 to avoid immediate schema migrations.
  - *Choice P1-B:* Include per-app limits in immediate scope (requires schema change).
- **E. Production Data Remediation:**
  - Authorize future one-time migration to correct row `d4a05b68…` (gated by DEC-02).

---

## 8. Remaining Blockers & Next Actions

1. **Owner Ruling on DEC-12:** Awaiting explicit owner choice on Daily Limit Action, Bedtime Execution, Emergency Override, and Scope.
2. **DEC-02 (P1 Release Blocker):** Four Supabase migrations, preflights, and Edge Function deployments remain unapplied hosted.
3. **DEC-03 (P1 Release Blocker):** 75/75 physical Android QA hardware matrix rows remain `NOT RUN`.
4. **Safe Exit Implementation:** Design and test the 12-step non-destructive exit protocol prior to release.
5. **Release Keystore Generation:** Create durable signing keystore when authorized.

---

## 9. Confirmation of Governance Boundaries

I explicitly confirm that throughout Phase 9.2:
- **Zero** application source code files in `android/`, `lib/`, or `supabase/` were altered.
- **Zero** APK builds, Gradle commands, or ADB executions were performed.
- **Zero** device provisioning, pairing, or un-provisioning operations occurred.
- **Zero** hosted Supabase SQL migrations, mutations, or Edge Function deployments were initiated.
- **Zero** Git state-changing commands (`git add`, `commit`, `checkout`, `reset`, etc.) were executed.
- The user's personal Realme `RMX2161` device was not accessed or targeted.

---

**DEC-13 is APPROVED (Option B). DEC-12 remains PROPOSED. No implementation, device provisioning, APK build, ADB operation, hosted mutation or deployment was performed. Awaiting explicit owner decision on DEC-12.**

