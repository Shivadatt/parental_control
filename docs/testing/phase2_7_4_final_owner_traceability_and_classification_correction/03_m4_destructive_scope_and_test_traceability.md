# HAVEN PARENT CONTROL — PHASE 2.7.4 DELIVERABLE 03
# AUDIT B: M4 DESTRUCTIVE SCOPE & TEST TRACEABILITY AUDIT

**Document ID:** `HAVEN-GOV-PHASE2-7-4-M4-AUDIT`  
**Phase:** Phase 2.7.4 — Final Owner Decision Traceability & Test Classification Correction Audit  
**Audit Dimension:** Database Migration Dependency (M4) & Native Android Privilege Boundaries  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Active HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Review Standard:** Independent Adversarial Source Evidence Audit  
**Execution Posture:** STRICTLY READ-ONLY  
**Test Status:** ALL TESTS REMAIN NOT TESTED  

---

## 1. Executive Summary & Purpose

Phase 2.7.2 classified seven test cases under **`M4` (Runtime Schema Verification Required / Destructive Operations)**:
- `TC-A08` (Account Data Export / GDPR)
- `TC-A09` (Account Deletion with Confirmation)
- `TC-FAM10` (Unlink Child Account from Parent Dashboard)
- `TC-APP05` (Policy Command Delivery & Acknowledgment Loop)
- `TC-APP07` (Native OS App Suspension Under Device Owner)
- `TC-EXP-04` (GDPR Data Export Payload Schema Validation)
- `TC-EXP-47` (Manual Audit Log Purge with Confirmation)

The Phase 2.7.4 specification strictly directs:
> *"Do not classify a case as M4 merely because its title contains words such as deletion, purge, cleanup, revocation, or invalidation. Determine whether the test itself requires a destructive operation or merely verifies behavior using a controlled, reversible, or mocked condition."*

This Audit B performs an adversarial source-to-implementation inspection of all seven cases, evaluating their actual operations, destructive scopes, database mechanisms, fixture requirements, and Android OS dependencies.

---

## 2. In-Depth Adversarial Evidence Table for All Seven Historical M4 Tests

The table below catalogs the audited technical reality for each of the seven test cases:

| Field | TC-A08 | TC-A09 | TC-FAM10 | TC-APP05 | TC-APP07 | TC-EXP-04 | TC-EXP-47 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Test Case ID** | **`TC-A08`** | **`TC-A09`** | **`TC-FAM10`** | **`TC-APP05`** | **`TC-APP07`** | **`TC-EXP-04`** | **`TC-EXP-47`** |
| **Test Title** | Account Data Export (GDPR) | Account Deletion with Confirmation | Unlink Child Account from Parent Dashboard | Policy Command Delivery & ACK Loop | Native OS App Suspension Under Device Owner | GDPR Data Export Payload Schema Validation | Manual Audit Log Purge with Confirmation |
| **Target Functionality** | `A08` | `A09` | `FAM10` | `APP05` | `APP07` | `A08` | `AUD03` |
| **Test Objective** | Verify personal data export dialog generates JSON export preview | Verify permanent account deletion cascades across family & auth tables | Verify parent unlinking child revokes device and removes pairing | Verify full-circle command delivery and ACK from child daemon | Verify Android OS package suspension under Device Owner | Verify GDPR JSON export schema conforms to specification | Verify parent can purge historical audit logs with keyword "PURGE" |
| **Actual Operation** | Read-only data aggregation & JSON formatting | Calls `executeAccountDeletion` to permanently drop auth user & cascade | Updates device row status to `revoked` and removes membership | Inserts command, polls via daemon, updates status to `succeeded` | Invokes `setPackagesSuspended()` on native Android DPM | Validates JSON keys: `profile`, `devices`, `location_history`, `audit_events` | Deletes historical rows in `public.audit_logs` older than 60 days |
| **Source Evidence** | `supabase/functions/account/index.ts:35` | `supabase/functions/account/deletion.ts:418` | `supabase/migrations/20261030000200_phase1_authorization.sql` | `android/.../GuardianService.kt:180` | `android/.../PolicyApplier.kt:135` | `supabase/functions/account/index.ts:50` | `supabase/migrations/20261030000300_retention_sweep.sql:120` |
| **Database Objects** | Read query on `profiles`, `devices`, `telemetry` | `auth.users`, `public.profiles`, `public.families` (CASCADE) | `public.devices` (`status='revoked'`), `public.family_members` | `public.device_commands` (INSERT, UPDATE status) | Read query on `public.policies` (or cached local policy) | Read query on `profiles`, `devices`, `location_events` | `public.audit_logs` (`WHERE family_id=? AND created_at < ?`) |
| **Destructive Scope** | **NONE** (Pure Read-Only) | **ACCOUNT / FAMILY SCOPED** (Permanent Hard Delete) | **FAMILY-SCOPED ENTITY UNLINK** (Reversible / Scoped) | **NONE** (Operational DML Insert/Update) | **NONE IN DB** (OS package suspension is client state) | **NONE** (Explicitly marked: Destructive Potential: No) | **FAMILY-SCOPED PURGE** (Deletes historical logs > 60d) |
| **Fixture Requirement** | Existing QA Account with sample data | Dedicated Disposable Test Account (`qa-destroy-*`) | Disposable Paired Child Device Fixture | Standard Paired Parent + Child Test Accounts | Dedicated Test Handset with Device Owner (`A4`) | Populated Test Account with historical telemetry | Isolated Family Tenant with seeded >60d audit logs |
| **Historical Class (P2.7.2)**| **`M4`** | **`M4`** | **`M4`** | **`M4`** | **`M4`** | **`M4`** | **`M4`** |
| **Current Class (P2.7.4)** | **`M1`** | **`M4`** | **`M1`** | **`M1`** | **`M1`** | **`M1`** | **`M4`** |
| **Confidence** | **HIGH** | **HIGH** | **HIGH** | **HIGH** | **HIGH** | **HIGH** | **HIGH** |
| **Runtime Requirement** | HTTP execution of `account` edge function | Execution of hard deletion edge function | Unlinking RPC and child push notification receipt | Live network polling loop (up to 25s) between devices | Native Android OS execution on Device Owner hardware | HTTP response validation of JSON payload | Live execution of scoped audit purge RPC |
| **Owner Authorization Gate**| `P25-OWNER-01` (Baseline) | `P25-OWNER-03` (Destructive) + `P25-OWNER-04` (Disposable Acct) | `P25-OWNER-04` (Disposable Device Fixture) | `P25-OWNER-02` (Backend) | `P25-OWNER-05` (Option 5-A Device Owner Provisioning) | `P25-OWNER-01` (Baseline) | `P25-OWNER-03` (Option 3-A Scoped Purge Authorization) |
| **Execution Status** | **`NOT TESTED`** | **`NOT TESTED`** | **`NOT TESTED`** | **`NOT TESTED`** | **`NOT TESTED`** | **`NOT TESTED`** | **`NOT TESTED`** |

---

## 3. Special Investigation: TC-APP05 Implementation Reality

### 3.1 Objective & Architecture
`TC-APP05` validates the asynchronous policy synchronization loop between parent and child devices:
1. Parent saves a policy change (e.g. daily screen time limit).
2. Backend creates a command row in `public.device_commands` with `status = 'pending'`.
3. Child background daemon (`GuardianService`) polls the backend command endpoint.
4. Child daemon receives the command, invokes `PolicyApplier`, and posts an ACK back to `public.device_commands` updating `status = 'succeeded'`.
5. Parent UI receives the ACK and transitions the device protection badge to "Active Protection".

### 3.2 Native Android Capability Inspection
Inspection of `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt` reveals:
- **Device Admin (`A3`)**: NOT required for command delivery or polling. Polling runs via standard Android background execution threads with HTTPS requests.
- **Device Owner (`A4`)**: NOT required for command ACK delivery. The command status transitions to `succeeded` as long as `PolicyApplier.applyPolicy()` processes the payload. Even if app suspension is unsupported on a consumer phone, `PolicyApplier` catches the absence of Device Owner and generates an ACK with `enforcement_supported = false`, completing the command loop.
- **Usage Access (`A2`)**: Checked only if quota evaluation is enabled, but not required to deliver or acknowledge commands.
- **Overlay Permission (`SYSTEM_ALERT_WINDOW`)**: NOT used in `TC-APP05`. Haven uses native package suspension via DevicePolicyManager, not window overlays.

### 3.3 Database Dependency Conclusion
- `TC-APP05` performs standard DML operations: `INSERT` into `device_commands` and `UPDATE` on `device_commands.status`.
- It executes zero destructive schema purges or table drops.
- **Verdict for TC-APP05:** Reclassified from `M4` to **`M1`** (Existing Compatible Schema).

---

## 4. Special Investigation: TC-APP07 Native Device Owner Verification

### 4.1 Source Evidence in PolicyApplier.kt
Inspection of `android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt` establishes the exact native platform dependency:

```kotlin
// PolicyApplier.kt lines 60, 135-144, 255-260
val isOwner = isDeviceOwner()
...
if (desiredCount > 0 && !isOwner) {
    // Never clear the target set: the ack has to say desired=N,
    // applied=0, supported=false so the server can record
    // "unsupported" instead of a false "enforced".
    errors.add(
        "Device Owner provisioning is required to suspend apps on this device. " +
            "No apps were suspended."
    )
    unsupported.addAll(appDesired)
} else if (isOwner) {
    val toSuspend = desired - previous
    val toRestore = PolicyEvaluator.restoreList(previous, desired)
    if (toSuspend.isNotEmpty()) {
        suspendCallSucceeded = suspendPackages(toSuspend, errors)
    }
}
...
fun isDeviceOwner(): Boolean =
    try {
        devicePolicyManager.isDeviceOwnerApp(context.packageName)
    } catch (_: Exception) {
        false
    }
```

### 4.2 Tripartite Android Privilege Disambiguation
The source code conclusively demonstrates three distinct operational tiers:

```
+----------------------------------------------------------------------------------------------------+
|                               ANDROID ADMINISTRATIVE PRIVILEGE SPECTRUM                            |
+------------------------------------+----------------------------------+----------------------------+
| 1. Device Admin (A3)               | 2. Device Owner Provisioning (A4)| 3. Package Suspension API  |
+------------------------------------+----------------------------------+----------------------------+
| Component:                         | Setup Requirement:               | Native Call:               |
| ParentControlDeviceAdminReceiver   | Factory reset + ADB CLI:         | dpm.setPackagesSuspended() |
|                                    | "adb shell dpm set-device-owner" |                            |
| Activated via in-app Intent dialog.| Cannot be activated in-app.      | Supported ONLY under A4.   |
| Capabilities:                      | Capabilities:                    | Result under A3:           |
| Lock screen, wipe, disable camera. | Silent package suspension,       | SecurityException caught,  |
| CANNOT suspend other packages!     | kiosk mode, block uninstall.     | enforcement_supported=false|
+------------------------------------+----------------------------------+----------------------------+
```

### 4.3 Governance & Classification Findings for TC-APP07
1. **Zero Database Destructive Operation**: `TC-APP07` tests whether Android OS displays "App is paused by IT admin" when tapping a suspended icon. The database merely stores the policy rule. `M4` is completely inapplicable.
2. **Android Capability Block (`A4`)**: Standard consumer Android handsets with Device Admin activated will gracefully fail and report `unsupported`. Testing the successful path is **`BLOCKED BY ANDROID CAPABILITY`** unless executed on a dedicated test handset provisioned as Device Owner via ADB under Gate 5 Option 5-A.
3. **Verdict for TC-APP07:** Reclassified from `M4` to **`M1`** (Database) and mapped to **`A4`** (Android Capability).

---

## 5. Audit B Summary of Reclassifications

The adversarial inspection establishes that **5 of the 7 historical M4 test cases do NOT perform destructive database operations**:

| Test ID | Test Title | Historical Class | Corrected Class | Reason for Correction |
| :---: | :--- | :---: | :---: | :--- |
| **`TC-A08`** | Account Data Export (GDPR) | `M4` | **`M1`** | Read-only JSON export; zero destructive DB operations. |
| **`TC-APP05`**| Policy Command Delivery & ACK Loop | `M4` | **`M1`** | Operational DML (`device_commands`); zero destructive purges. |
| **`TC-APP07`**| Native OS App Suspension Under Device Owner | `M4` | **`M1`** | Native OS state test (`A4`); zero destructive DB operations. |
| **`TC-EXP-04`**| GDPR Data Export Payload Schema Validation | `M4` | **`M1`** | Read-only JSON validation; explicitly non-destructive. |
| **`TC-FAM10`**| Unlink Child Account from Parent Dashboard | `M4` | **`M1`** | Localized status update (`devices.status='revoked'`) on disposable fixture. |
| **`TC-A09`** | Account Deletion with Confirmation | `M4` | **`M4`** | **CONFIRMED M4**: Cascading permanent account hard delete (`AUD03`). |
| **`TC-EXP-47`**| Manual Audit Log Purge with Confirmation | `M4` | **`M4`** | **CONFIRMED M4**: Destructive deletion of historical audit logs (`AUD03`). |

### 5.1 Net Impact on Database Dimension (M-Class)
- **M4 Count Reduction:** Decreases from **7 to 2** (`TC-A09`, `TC-EXP-47`).
- **M1 Count Increase:** Receives **+5** tests from M4 (bringing M1 from 61 + 4 from M3 = 65, + 5 from M4 = **70 tests**).
- **Destructive Quarantine:** Confines destructive testing risks to exactly two well-defined, family-scoped operations under `AUD03`.
