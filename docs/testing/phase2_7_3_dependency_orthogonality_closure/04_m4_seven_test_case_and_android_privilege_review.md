# HAVEN PARENT CONTROL — PHASE 2.7.3 DELIVERABLE 04
# ADVERSARIAL EVIDENCE REVIEW: SEVEN M4 TEST CASES & TC-APP07 DEVICE OWNER TRUTH

**Document ID:** `HAVEN-GOV-PHASE2-7-3-M4-REVIEW`  
**Phase:** Phase 2.7.3 — Final Dependency Orthogonality & Governance Closure Audit  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Active HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Review Standard:** Independent Adversarial Technical Evidence Review  
**Execution Posture:** STRICTLY READ-ONLY  
**Runtime Execution:** PROHIBITED  
**Phase 3 Authorization:** STRICTLY NOT AUTHORIZED  

---

## 1. Executive Purpose & Scope

In Phase 2.7.2, seven test cases were classified as **`M4`** (*Runtime Schema Verification Required*). These tests involve dynamic database procedures, complex RPC pipelines, cascading delete triggers, or active Edge Functions that verify live runtime state.

This report independently audits:
1. Each of the seven M4 test cases against actual source implementation and database objects.
2. The exact native Android privilege boundaries of **`TC-APP07`**, proving that it is blocked by Android platform capabilities (`A4`) regardless of backend readiness.
3. The destructive quarantine requirements for **`TC-A09`** and **`TC-FAM10`**.
4. The exact scope and mechanism of **`TC-EXP-47`** (Audit Log Purge).

---

## 2. Granular Inspection of the Seven M4 Test Cases

### 2.1 TC-A08: Account Data Export (GDPR)
- **Objective**: Verify that invoking GDPR export streams a complete JSON document containing the caller's profile, owned families, child devices, and historical telemetry without data loss.
- **Backend Operation**: Invocations of `account` Edge Function with action `export`.
- **Source Reference**: `supabase/functions/account/index.ts:5–8` and `supabase/functions/account/export.ts`.
- **Runtime Schema Dependency**: Verifies live database serialization across multiple tables (`profiles`, `devices`, `telemetry`, `locations`, `usage_daily`).
- **Destructive Potential**: **No** (Read-only data extraction).
- **Minimum Environment**: `M4 + E2` (Isolated QA account fixture).
- **Governance Status**: Permitted under disposable QA account; currently **LOCKED**.

---

### 2.2 TC-A09: Account Deletion with Confirmation (`AUD03`)
- **Objective**: Verify that deleting a parent account cascades through `public.delete_user_account()`, purging family memberships, child links, and revoking GoTrue authentication credentials.
- **Backend Operation**: Calls `account` Edge Function (`action: 'delete'`) in `supabase/functions/account/deletion.ts:418`.
- **Schema & Trigger Objects**: Enforces caller JWT identity, deletes rows in `public.family_members`, sets `deleted_at` on `public.families`, deletes `public.profiles`, and invokes `auth.admin.deleteUser(userId)`.
- **Runtime Schema Dependency**: Verifies cascading delete triggers and auth token revocation.
- **Destructive Potential**: **CRITICAL (Tier S-5)**. Irreversibly purges account data.
- **Quarantine Requirement**: **MANDATORY DISPOSABLE FIXTURE**. Must strictly execute against disposable email fixtures (`qa-destroy-*@haven.internal`). **PROHIBITED on existing shared accounts.**
- **Minimum Environment**: `M4 + E2` (Disposable account quarantine).
- **Governance Status**: **LOCKED PENDING EXPLICIT OWNER APPROVAL**.

---

### 2.3 TC-FAM10: Unlink Child Account from Parent Dashboard
- **Objective**: Verify that unlinking a child device updates `devices.is_revoked`, triggers a push notification to the child device, purges local keystore secrets, and unbinds supervision.
- **Backend Operation**: Calls `device-command` edge function or `unlink_device` RPC.
- **Source Reference**: `supabase/migrations/20261030000200_phase1_authorization.sql`.
- **Runtime Schema Dependency**: Live verification of device state transition and command delivery.
- **Destructive Potential**: **HIGH (Tier S-4/S-5)**. Permanently disconnects the device.
- **Quarantine Requirement**: Dedicated lab device required (`E4`/`A8`).
- **Minimum Environment**: `M4 + E2 + A8`.
- **Governance Status**: **LOCKED PENDING EXPLICIT OWNER APPROVAL**.

---

### 2.4 TC-APP05: Policy Command Delivery & Acknowledgment Loop
- **Objective**: Verify the asynchronous command pipeline: Parent updates policy $\to$ server issues row in `commands` $\to$ child receives push/poll $\to$ child applies policy $\to$ child writes row in `command_acks`.
- **Backend Operation**: Invocations of `issue_command` RPC, database triggers, and `device-command` edge function.
- **Source Reference**: `supabase/migrations/20260101000000_core.sql:140` (`commands`), `core.sql:160` (`command_acks`).
- **Runtime Schema Dependency**: Verifies foreign key relations and asynchronous transaction state.
- **Destructive Potential**: **No** (Reversible policy update).
- **Minimum Environment**: `M4 + E5 + A8` (Isolated tenant + active child daemon).
- **Governance Status**: **LOCKED PENDING EXPLICIT OWNER APPROVAL**.

---

### 2.5 TC-APP07: Native OS App Suspension Under Device Owner
- **Objective**: Verify that when a restricted app is launched during bedtime or after quota exhaustion, the native Android OS suspends the package and displays the system lock dialogue.
- **Detailed Investigation**: See Section 3 below.

---

### 2.6 TC-EXP-04: GDPR Data Export Payload Schema Validation
- **Objective**: Perform strict JSON schema validation on the export payload generated by `TC-A08`, verifying that field names, ISO timestamps, and privacy redactions match technical specifications.
- **Backend Operation**: Edge Function invocation `account?action=export`.
- **Runtime Schema Dependency**: Validates data serialization and edge function schema formatting.
- **Destructive Potential**: **No**.
- **Minimum Environment**: `M4 + E2`.
- **Governance Status**: **LOCKED PENDING EXPLICIT OWNER APPROVAL**.

---

### 2.7 TC-EXP-47: Manual Audit Log Purge with Confirmation (`AUD03`)
- **Objective**: Verify that a parent can manually trigger a purge of historical audit logs older than the family's configured retention threshold with explicit confirmation keyword "PURGE".
- **Backend Operation**: Calls `delete_audit_logs()` RPC or `account` Edge Function action `purge_logs`.
- **Operational Scope Verification**:
  - Inspected `supabase/functions/account/deletion.ts` and `supabase/migrations/20261030000300_retention_sweep.sql:120`.
  - **Critical Finding**: Unlike the global retention sweep (`AUD04`), manual log purges triggered by a parent are **strictly scoped to the caller's `family_id`**:
    ```sql
    delete from public.audit_logs
    where family_id = v_family_id
      and created_at < now() - make_interval(days => v_retention_days);
    ```
  - **Verdict**: `TC-EXP-47` is a **family-scoped operation (AUD03)**, NOT a global multi-tenant sweep. It is safe to execute within a dedicated disposable QA tenant without risking other families' audit history.
- **Destructive Potential**: **HIGH (Tier S-5)** for the target family's historical logs.
- **Minimum Environment**: `M4 + E2` (Isolated QA tenant with seeded mock audit logs).
- **Governance Status**: **LOCKED PENDING EXPLICIT OWNER APPROVAL**.

---

## 3. Special Technical Focus: TC-APP07 & Android Device Owner Truth

### 3.1 Source Evidence & Call-Site Analysis
An independent AST inspection of `android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt` proves the exact native execution sequence:

```kotlin
// PolicyApplier.kt lines 60, 135-144:
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
    if (toSuspend.isNotEmpty()) {
        suspendCallSucceeded = suspendPackages(toSuspend, errors)
    }
}
```

And in `PolicyApplier.kt:348–360`:
```kotlin
private fun suspendPackages(packages: Set<String>, errors: MutableSet<String>): Boolean {
    if (packages.isEmpty()) return false
    return try {
        devicePolicyManager.setPackagesSuspended(admin, packages.toTypedArray(), true)
        true
    } catch (error: SecurityException) {
        errors.add("The system refused to suspend apps: Device Owner access is missing.")
        false
    }
}
```

### 3.2 The Device Admin vs Device Owner Capability Divide
1. **Device Admin Receiver (`ParentControlDeviceAdminReceiver`)**:
   - `res/xml/device_admin.xml` requests `<uses-policies />` = **EMPTY**.
   - Ordinary Device Admin activation via `Settings` or `ACTION_ADD_DEVICE_ADMIN` enables `isAdminActive() == true`, but grants **zero application management privileges**.
   - When only Device Admin is active, `isDeviceOwner()` returns `false`, `setPackagesSuspended()` is **never called**, and the app logs an error and reports `enforcement_supported = false`.
2. **Device Owner Requirement (`A4`)**:
   - `DevicePolicyManager.setPackagesSuspended()` is a privileged API restricted exclusively to the **Device Owner** component of a fully managed device (or Profile Owner of an enterprise work profile).
   - Android explicitly throws `SecurityException` if a standard app or ordinary Device Admin calls `setPackagesSuspended()`.
   - Device Owner **CANNOT be activated programmatically, in-app, or via user prompts**. It strictly requires out-of-band provisioning:
     ```bash
     adb shell dpm set-device-owner com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver
     ```
     which only succeeds on a factory-reset device before any user accounts are added.

### 3.3 TC-APP07 Blocking Status Declaration

```
========================================================================================
                   TC-APP07 CAPABILITY BLOCKING DECLARATION
========================================================================================

  TEST CASE: TC-APP07 (Native OS App Suspension Under Device Owner)
  DATABASE STATUS: M4 (Runtime policy command & ACK recording supported)
  ANDROID STATUS:  A4 (STRICTLY REQUIRES PROVISIONED DEVICE OWNER)

  OPERATIONAL TRUTH:
  TC-APP07 is BLOCKED BY ANDROID PLATFORM CAPABILITY on any normal, un-provisioned
  Android device. Activating Device Admin in settings is completely INSUFFICIENT.
  
  Unless dedicated lab hardware is factory-reset and provisioned via workstation ADB
  under explicit Owner authorization (Gate P25-OWNER-05 Option 5-A), TC-APP07
  CANNOT BE EXECUTED as a passing suspension test. 
  
  On standard devices, running TC-APP07 will verify only the graceful fallback:
  it will report enforcement_supported = false and "Device Owner access is missing".

========================================================================================
```

---

## 4. Audit Conclusion

1. All seven M4 test cases represent valid dynamic runtime verifications.
2. `TC-APP07` is constrained by mobile operating system architecture (`A4` Device Owner), not by database availability.
3. `TC-A09` and `TC-FAM10` must strictly execute under disposable accounts.
4. `TC-EXP-47` is confirmed to be family-scoped (`AUD03`), completely distinct from global retention sweeps (`AUD04`).
