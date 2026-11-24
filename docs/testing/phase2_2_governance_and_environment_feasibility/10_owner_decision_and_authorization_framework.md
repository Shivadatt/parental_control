# Phase 2.2 — Owner Decision and Authorization Framework

**Document ID:** `HAVEN-GOV-PHASE2-2-DEC`  
**Phase:** Phase 2.2 — Owner Corrections, Governance Closure & Test Environment Feasibility Audit  
**Workspace:** `D:\parentcontrol_app`  
**Branch:** `main`  
**Starting HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Execution Posture:** STRICTLY READ-ONLY — NO AUTOMATIC APPROVALS  
**Framework Status:** PENDING OWNER DECISION  

---

## 1. Executive Intent & Framework Purpose

This document establishes the formal, un-preapproved **Owner Decision and Authorization Framework** for HAVEN Parent Control. 

Prior audit phases (Phase 2 and Phase 2.1) established the functional inventory (92 capabilities) and reconciled the comprehensive test suite (99 unique manual test cases). However, **no test execution, backend mutation, infrastructure provisioning, or runtime activation may occur without explicit, documented Owner approval**.

To prevent ambiguity, premature execution, or accidental compromise of production data, this framework partitions owner governance into **five distinct, independent Decision Gates (Decisions A through E)**. 

> [!IMPORTANT]
> The audit team has deliberately left all decisions **UNSELECTED** and **UNAPPROVED**. Neither Pathway A nor Pathway B has been pre-selected. Phase 3 test execution is **BLOCKED** and locked by default until the Owner signs off on Decisions A through D.

```
+--------------------------------------------------------------------------------------------------+
|                                    OWNER GOVERNANCE GATEWAY                                      |
+--------------------------------------------------------------------------------------------------+
                                                  |
           +--------------------------------------+--------------------------------------+
           |                                                                             |
           v                                                                             v
+-----------------------+                                                     +-----------------------+
|      DECISION A       |                                                     |      DECISION B       |
|  Baseline Acceptance  |                                                     | Environment Pathway   |
| (92 Funcs / 99 Tests) |                                                     | (Pathway A vs B vs C) |
+-----------------------+                                                     +-----------------------+
           |                                                                             |
           +--------------------------------------+--------------------------------------+
                                                  |
           +--------------------------------------+--------------------------------------+
           |                                                                             |
           v                                                                             v
+-----------------------+                                                     +-----------------------+
|      DECISION C       |                                                     |      DECISION D       |
| Destructive Operation |                                                     | Android System Perms  |
|      Quarantine       |                                                     | (7 Native Subsystems) |
+-----------------------+                                                     +-----------------------+
                                                  |
                                                  v
                               +-------------------------------------+
                               |             DECISION E              |
                               |    Phase 3 Execution Activation     |
                               |  [LOCKED UNTIL DECISIONS A-D PASS]  |
                               +-------------------------------------+
```

---

## 2. Decision A: Master Functional & Testing Baseline Acceptance

### 2.1 Context & Scope
The Owner is asked to review and accept the reconciled baseline of functionalities and manual test cases established across the Pre-Testing Audit, Phase 2 Gap Audit, and Phase 2.1 Independent Verification:
1. **Master Functionality Inventory**: 92 unique inventoried functionalities (`A01` through `SYS02`).
2. **Separately Tracked Absent Capabilities**: 10 documented absent capabilities (`M01` through `M10`), preventing false test expectations for unbuilt features.
3. **Master Test Suite Baseline**: Exactly 99 unique, non-redundant manual test cases:
   - 41 Baseline Test Cases (`TC-A01` through `TC-SYS02`, from Pre-Testing Audit Deliverable 08).
   - 58 Expansion Test Cases (`TC-EXP-01` through `TC-EXP-58`, from Phase 2 Deliverable 05).
4. **Specification Coverage**: 100.0% specification coverage across all 92 inventoried functionalities, with zero unmapped requirements.
5. **Safety Taxonomy**: Six-tier safety classification (`SAFE`, `SAFE_REVERSIBLE`, `REQUIRES_DISPOSABLE_ACCOUNT`, `REQUIRES_DISPOSABLE_DEVICE`, `REQUIRES_ISOLATED_BACKEND`, `SPECIALIST_TEST`).
6. **Execution Posture**: All 99 test cases currently have `Actual Result: NOT TESTED` and `Status: NOT TESTED`.

### 2.2 Owner Decision Options
- [ ] **OPTION A-1 (RECOMMENDED): ACCEPT RECONCILED BASELINE**  
  The Owner accepts the 92-functionality master inventory, 10 absent capability registers, 99-test case suite, 100.0% specification coverage, and 6-tier safety taxonomy as the authoritative governance baseline.
- [ ] **OPTION A-2: REJECT OR AMEND BASELINE**  
  The Owner requests specific adjustments to the inventory, test suite, or safety classifications before proceeding.

### 2.3 Consequences & Safeguards
- **If Approved (A-1)**: Reconciles all historical counting discrepancies (`DISC-01` through `DISC-06`) and locks the test catalog at exactly 99 test cases.
- **If Rejected (A-2)**: Work halts; Phase 3 execution remains blocked until amendments are drafted and verified.

---

## 3. Decision B: Backend Environment Pathway Selection

### 3.1 Context & Architecture Overview
Testing requires interaction with Supabase backend services (PostgreSQL, Auth, Realtime WebRTC signaling, Edge Functions). The Owner previously directed on 2026-10-27 (`docs/backend.md:327–332`) that only production project `hhqgreaoqulmfwfwarhc` be utilized and no second project be created. 

The audit team conducted an objective feasibility study comparing **Pathway A** (provisioning a dedicated Staging Supabase project) and **Pathway B** (implementing an isolated QA organization fixture within the existing production project).

```
+--------------------------------------------------------------------------------------------------+
|                                  BACKEND SELECTION PATHWAYS                                      |
+--------------------------------------------------------------------------------------------------+
|  PATHWAY A: DEDICATED STAGING PROJECT               PATHWAY B: ISOLATED QA IN PRODUCTION PROJECT |
|  - Completely isolated infrastructure               - Existing project `hhqgreaoqulmfwfwarhc`    |
|  - Zero risk to production customer data            - RLS tenant isolation (`family_id` partition)|
|  - Permits destructive retention sweeps (TC-EXP-48) - Zero cloud provisioning overhead/cost     |
|  - Requires cloud provisioning, secrets & config    - TC-EXP-47 and TC-EXP-48 MUST BE PROHIBITED |
+--------------------------------------------------------------------------------------------------+
```

### 3.2 Side-by-Side Architectural Tradeoffs Summary

| Evaluation Dimension | Pathway A (Dedicated Staging Project) | Pathway B (In-Project QA Tenant) |
| :--- | :--- | :--- |
| **Data Isolation** | Complete (Physical / Cloud project separation) | Logical (Row-Level Security family tenancy) |
| **Production Risk** | Absolute Zero risk to production tables | Non-zero residual risk if RLS bypassed |
| **Sweep Safety (`AUD04`)** | Full execution of `TC-EXP-48` permitted | **STRICTLY PROHIBITED** (would delete prod data) |
| **Purge Safety (`AUD03`)** | Full execution of `TC-EXP-47` permitted | **STRICTLY PROHIBITED** (deletes active unassigned) |
| **Cloud Infrastructure Cost** | Requires additional Supabase tier / quota | Zero additional cloud cost |
| **Setup & Provisioning Time** | 4–8 hours (project creation, 14 migrations, 10 edge funcs) | Immediate (zero provisioning required) |
| **App Build Complexity** | Requires `--dart-define=SUPABASE_URL=staging` | Uses standard project configuration |
| **Auth Rate Limit Collision** | Independent quota (no risk of locking prod users) | Shared IP/email quota on GoTrue auth |
| **WebRTC Signaling Load** | Independent realtime channels | Shared realtime channel capacity |
| **Test Coverage Achievable** | **100.0% (99/99 test cases)** | **97.9% (97/99 test cases; 2 prohibited)** |

### 3.3 Owner Decision Options
- [ ] **OPTION B-1: AUTHORIZE PATHWAY A (DEDICATED STAGING SUPABASE PROJECT)**  
  The Owner overrides the 2026-10-27 single-project directive and authorizes the creation and provisioning of an independent Supabase staging project. 
  - *Conditions*: Staging project must be provisioned with all 14 database migrations and 10 Edge Functions. Dedicated `--dart-define` parameters must be provided for builds. All 99 test cases (including `TC-EXP-47` and `TC-EXP-48`) are eligible for execution.
- [ ] **OPTION B-2: AUTHORIZE PATHWAY B (ISOLATED QA FIXTURE IN EXISTING PROJECT `hhqgreaoqulmfwfwarhc`)**  
  The Owner reaffirms the 2026-10-27 directive that no second project be created and authorizes testing within the existing production project using dedicated test fixtures.
  - *Strict Mandatory Conditions*:
    1. Dedicated test family fixtures (`qa-parent-test@haven.internal`, `qa-child-test@haven.internal`) strictly partitioned by RLS `family_id`.
    2. Real customer accounts and live child profiles are completely excluded.
    3. `TC-EXP-47` (Unpaired Device Purge) and `TC-EXP-48` (Retention Sweep) are **STRICTLY PROHIBITED** and permanently quarantined.
    4. Auth operations must be throttled to prevent triggering Supabase GoTrue rate limits on production.
- [ ] **OPTION B-3: DEFER ENVIRONMENT SELECTION**  
  The Owner requests further infrastructure analysis, budget verification, or security review before choosing an environment. Phase 3 execution remains blocked.

---

## 4. Decision C: Destructive Operations Authorization & Quarantine

### 4.1 Context & Hazard Identification
Eight specific test cases involve destructive operations that permanently alter backend state, delete database records via foreign key cascades, or terminate device pairings:
1. `TC-A09`: Parent Account Deletion (deletes `profiles`, cascades to `family_members`, deletes children, orphans telemetry).
2. `TC-FAM10`: Revoke Family Access / Remove Member (permanent role revocation).
3. `TC-FAM12`: Force Device Logout (invalidates push tokens and active sessions).
4. `TC-FAM13`: Emergency Remote Device Lock (locks child UI, restricts OS controls).
5. `TC-EXP-17`: Parent Account Permanent Deletion Verification (verifies cascading hard delete).
6. `TC-EXP-18`: Child Profile Hard Deletion & Cascade Verification.
7. `TC-EXP-47`: Unpaired Device Sweep (`device_enrollments` older than 7 days).
8. `TC-EXP-48`: Global Retention Sweep (`public.run_retention_sweep()` deletes telemetry across ALL families).

### 4.2 Quarantine & Execution Protocols
- **Strict Protocol 1 (Disposable Test Accounts Only)**: Destructive tests `TC-A09`, `TC-FAM10`, `TC-EXP-17`, and `TC-EXP-18` must ONLY be executed against disposable QA accounts (`test-destroy-*@haven.internal`). Execution against any primary test account or live account is grounds for immediate audit failure.
- **Strict Protocol 2 (Terminal Ordering)**: Destructive account and profile tests must be scheduled at the absolute end of their respective test cycles to avoid invalidating upstream dependencies.
- **Strict Protocol 3 (Pathway B Prohibition)**: `TC-EXP-47` and `TC-EXP-48` are **PERMANENTLY FORBIDDEN** if Pathway B is selected.

### 4.3 Owner Decision Options
- [ ] **OPTION C-1: APPROVE CONTROLLED DESTRUCTIVE TESTING (DISPOSABLE FIXTURES ONLY)**  
  The Owner authorizes controlled execution of `TC-A09`, `TC-FAM10`, `TC-FAM12`, `TC-FAM13`, `TC-EXP-17`, and `TC-EXP-18` exclusively on disposable test fixtures. If Pathway B is selected, `TC-EXP-47` and `TC-EXP-48` remain prohibited.
- [ ] **OPTION C-2: RESTRICT ALL DESTRUCTIVE TESTING**  
  The Owner prohibits all account and profile deletion tests. These test cases will be marked `BLOCKED BY OWNER DIRECTIVE` during Phase 3.

---

## 5. Decision D: Android Native System Permissions Authorization

### 5.1 Context & Operating System Privileges
HAVEN Parent Control Child Mode operates as a privileged device management application on Android. Complete execution of the test suite requires granting seven high-privilege Android operating system permissions on the test hardware:

| Native Subsystem | Android API / Component | Test Cases | Risk on Personal Hardware |
| :--- | :--- | :--- | :--- |
| **Accessibility Service** | `HavenAccessibilityService` | `TC-C02`, `TC-EXP-19`, `TC-EXP-20`, `TC-EXP-21`, `TC-EXP-22` | Can inspect screen content and intercept app launches. |
| **Device Administrator** | `HavenDeviceAdminReceiver` | `TC-C01`, `TC-C07`, `TC-EXP-25`, `TC-EXP-26` | Prevents unauthorized app uninstall; can lock device. |
| **Usage Statistics** | `PACKAGE_USAGE_STATS` | `TC-C03`, `TC-EXP-23`, `TC-EXP-24` | Monitors running foreground apps and screen time. |
| **Background Location** | `ACCESS_BACKGROUND_LOCATION` | `TC-C04`, `TC-P03`, `TC-EXP-07`, `TC-EXP-27` | Periodic background GPS tracking and geofencing. |
| **Notification Listener** | `HavenNotificationListenerService` | `TC-C06`, `TC-EXP-29`, `TC-EXP-30` | Intercepts incoming notifications on child device. |
| **Battery Optimization** | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | `TC-C05`, `TC-EXP-28` | Keeps background telemetry daemon alive. |
| **System Overlay Window** | `SYSTEM_ALERT_WINDOW` | `TC-C08`, `TC-EXP-31` | Displays blocking overlay screen over restricted apps. |

### 5.2 Test Device Safeguards
- All high-privilege permissions must ONLY be granted on dedicated physical test devices or Android emulators (AVDs).
- Testing on personal, everyday-use hardware is strictly prohibited.
- Device Admin removal procedures must be verified prior to device wipe.

### 5.3 Owner Decision Options
- [ ] **OPTION D-1: AUTHORIZE PERMISSIONS ON DEDICATED TEST HARDWARE**  
  The Owner authorizes granting all 7 Android system permissions exclusively on dedicated test hardware/emulators.
- [ ] **OPTION D-2: RESTRICT SPECIFIC PERMISSIONS**  
  The Owner restricts specific permissions (e.g., Device Admin). Affected test cases will be classified as `BLOCKED BY PERMISSION RESTRICTION`.

---

## 6. Decision E: Phase 3 Manual Testing Execution Authorization

### 6.1 Gate Preconditions (Prerequisites Check)
Phase 3 execution involves human or automated test execution against the test catalog. Phase 3 cannot begin until:
1. Decision A (Baseline Acceptance) is signed and approved.
2. Decision B (Environment Pathway) is selected (Pathway A or Pathway B).
3. Decision C (Destructive Testing Protocol) is approved with safeguards.
4. Decision D (Android Permissions) is authorized for test devices.
5. Physical or emulated test hardware (Parent device, Child device) is provisioned and paired.
6. The selected backend environment is verified for connectivity.

### 6.2 Owner Decision Options
- [ ] **OPTION E-1: AUTHORIZE COMMENCEMENT OF PHASE 3 MANUAL TESTING**  
  The Owner grants full authorization to begin Phase 3 manual test execution under the terms of Decisions A, B, C, and D.
- [ ] **OPTION E-2 (CURRENT DEFAULT): MAINTAIN PHASE 3 EXECUTION LOCK (NOT AUTHORIZED)**  
  Phase 3 execution remains blocked. All 99 test cases remain `NOT TESTED`. No tests may be run.

---

## 7. Master Owner Governance Signature Block

This section must be completed, signed, and dated by the Project Owner.

```
====================================================================================================
                        HAVEN PARENT CONTROL — OWNER AUTHORIZATION SIGN-OFF
====================================================================================================

DOCUMENT ID:       HAVEN-GOV-PHASE2-2-DEC
WORKSPACE COMMIT:  0101c16d161824fd726018f1188e1a2b17c653d3

----------------------------------------------------------------------------------------------------
GOVERNANCE GATE                                DECISION SELECTED                     INITIALS / DATE
----------------------------------------------------------------------------------------------------
DECISION A: Master Baseline Acceptance          [ ] OPTION A-1 (Accept 92/99 Suite)   _______________
                                               [ ] OPTION A-2 (Amend Baseline)

DECISION B: Backend Environment Pathway        [ ] OPTION B-1 (Pathway A: Staging)   _______________
                                               [ ] OPTION B-2 (Pathway B: QA Tenant)
                                               [ ] OPTION B-3 (Defer Selection)

DECISION C: Destructive Operations             [ ] OPTION C-1 (Controlled Quarant.)  _______________
                                               [ ] OPTION C-2 (Prohibit All)

DECISION D: Android System Permissions         [ ] OPTION D-1 (Authorize Test HW)    _______________
                                               [ ] OPTION D-2 (Restrict Subsystems)

DECISION E: Phase 3 Execution Activation       [ ] OPTION E-1 (Commence Phase 3)     _______________
                                               [ ] OPTION E-2 (Keep Locked / Default)
----------------------------------------------------------------------------------------------------

OWNER PRINTED NAME:  __________________________________________________

OWNER SIGNATURE:     __________________________________________________

EXECUTION DATE:      __________________________________________________

GOVERNANCE VERDICT:  [ ] FORMALLY APPROVED FOR EXECUTION
                     [X] PENDING OWNER DECISION (CURRENT STATUS)
                     [ ] REJECTED / RETURNED FOR AMENDMENT
====================================================================================================
```

---

## 8. Summary of Reversal and Rollback Governance

Should the Owner or QA lead detect any unexpected behavior during future execution, the following immediate rollback protocols take effect:

1. **Immediate Execution Halt**: If a test case exhibits unintended data propagation (e.g. cross-family visibility on Pathway B), all testing halts immediately.
2. **Quarantine Enforcement**: Any test case causing unhandled crashes or un-resettable state is moved to `QUARANTINED` status and excluded from subsequent runs.
3. **Hardware De-provisioning**: Child test devices can be cleanly de-provisioned by disabling Device Administrator via Android Settings (`Settings -> Security -> Device Admin Apps -> Haven -> Deactivate`), followed by app uninstall.
4. **Fixture Purging**: Test accounts created on either pathway can be purged via `delete_user` admin RPC or SQL purge scripts without touching production users.
