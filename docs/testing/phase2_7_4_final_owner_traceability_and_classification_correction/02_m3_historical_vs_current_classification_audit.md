# HAVEN PARENT CONTROL — PHASE 2.7.4 DELIVERABLE 02
# AUDIT A: M3 HISTORICAL VS CURRENT CLASSIFICATION AUDIT

**Document ID:** `HAVEN-GOV-PHASE2-7-4-M3-AUDIT`  
**Phase:** Phase 2.7.4 — Final Owner Decision Traceability & Test Classification Correction Audit  
**Audit Dimension:** Database Migration Dependency Classification (M-Class)  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Active HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Review Standard:** Independent Adversarial Source Evidence Audit  
**Execution Posture:** STRICTLY READ-ONLY  
**Test Status:** ALL TESTS REMAIN NOT TESTED  

---

## 1. Executive Summary & Purpose

Phase 2.7.2 classified four test cases as **`M3` (Fresh Database / Clean Migration Replay Required)**:
- `TC-SEC01` (Cross-Family Unauthorized Data Access Boundary)
- `TC-SEC02` (Replay of Staged Credential Redemption)
- `TC-EXP-17` (Parent Device Revocation and Child Session Invalidation)
- `TC-EXP-18` (Device Re-Credentialing Recovery Challenge Flow)

Phase 2.7.3 suggested that an existing compatible schema plus disposable fixtures or isolated tenant data might be sufficient, making `M1` more appropriate than `M3`. However, Phase 2.7.3 retained `M3` in its primary tables to preserve historical continuity with Phase 2.7.2, assigning a Medium/Low confidence notation.

This Phase 2.7.4 Audit A conducts an exhaustive, source-to-SQL adversarial analysis to definitively determine whether a clean database replay is genuinely required for each test objective, or whether an existing compatible schema (`M1`) with isolated disposable fixtures (`E2`) is technically sufficient.

---

## 2. Classification Definitions & Standards

In accordance with Section 4 of the Phase 2.7.4 specification, the database dependency categories are defined as:

| Classification | Canonical Definition | Technical Scope |
| :---: | :--- | :--- |
| **`M0`** | **No Database or Migration Dependency** | Pure client UI, in-memory logic, local preferences, offline listeners, or local hardware abstractions. Zero database interaction. |
| **`M1`** | **Existing Compatible Database Schema Sufficient** | Test performs standard read, write, update, or RPC operations against an already-migrated, operational database schema. Fresh migration replay is not inherently required. |
| **`M2`** | **Static Migration Inspection Required** | Migration DDL, table constraints, triggers, indexes, or SQL procedures are the direct object of static code review; no runtime database execution occurs. |
| **`M3`** | **Fresh Migration Replay Genuinely Required** | The test objective specifically verifies clean schema initialization, zero-state database behavior, or migration pipeline execution that cannot be proven on an already-migrated schema. |
| **`M4`** | **Destructive Database Lifecycle or Purge Operation** | A destructive database lifecycle or purge operation is intrinsic to the test objective and requires specialized tenant isolation and explicit owner authorization controls. |

---

## 3. In-Depth Adversarial Audit of the Four Historical M3 Tests

### 3.1 TC-SEC01: Cross-Family Unauthorized Data Access Boundary

```
+----------------------------------------------------------------------------------------------------+
| Test ID: TC-SEC01                                                                                 |
| Historical Classification: M3 (Phase 2.7.2)                                                        |
| Current Evidence-Based Classification: M1 (Phase 2.7.4)                                           |
| Primary Functionality: A01 / RLS                                                                   |
| Authoritative Spec: docs/testing/pre_manual_testing_audit/08_manual_test_case_master_list.md:792   |
+----------------------------------------------------------------------------------------------------+
```

#### A. Exact Test Objective, Steps & Expected Result
- **Objective:** Verify multi-tenant Row-Level Security (RLS) tenant isolation between families. Ensure that a parent user belonging to Family A cannot read or access device telemetry, commands, or location history belonging to Family B.
- **Steps:**
  1. Authenticate to the backend as Parent A (obtaining valid JWT for Tenant A).
  2. Attempt to query `public.devices` or `public.location_events` using a `device_id` belonging exclusively to Family B.
- **Expected Result:** PostgreSQL RLS engine evaluates the caller session context and returns exactly 0 rows (empty result set) or HTTP 403 Forbidden. Zero cross-family data leakage occurs.

#### B. Source Evidence & SQL Architecture
- **Schema & Policy Source:** `supabase/migrations/20260101000200_rls.sql` and `supabase/migrations/20261024000000_schema.sql`.
- **Database Objects Involved:**
  - Tables: `public.devices`, `public.location_events`, `public.families`, `public.family_members`.
  - Enforcing Policy:
    ```sql
    CREATE POLICY devices_family_isolation ON public.devices
      FOR ALL
      USING (family_id IN (
        SELECT fm.family_id FROM public.family_members fm WHERE fm.user_id = auth.uid()
      ));
    ```

#### C. Replay vs Existing-Schema Dependency Analysis
- **PostgreSQL RLS Mechanism:** PostgreSQL evaluates RLS policies dynamically on every executed SQL query using session configuration variables (`auth.uid()`). The policy filter is completely state-independent of migration history; it depends solely on the rows present in `family_members` matching the authenticated caller.
- **Replay Necessity Assessment:** Replaying migrations from scratch (`db reset`) creates an empty database. However, testing RLS requires *populating* two distinct families (Family A and Family B) with distinct records. Executing this test against an existing compatible database containing two disposable test families (`E2`) validates the exact same SQL engine behavior as executing it against a newly replayed database.
- **Adversarial Conclusion:** A clean migration replay is NOT an intrinsic requirement of the RLS engine or the test objective.

> **MANDATORY DECLARATION FOR TC-SEC01:**  
> **Fresh migration replay is not required for this test case when an existing compatible schema and authorized isolated fixtures are available.**

---

### 3.2 TC-SEC02: Replay of Staged Credential Redemption

```
+----------------------------------------------------------------------------------------------------+
| Test ID: TC-SEC02                                                                                 |
| Historical Classification: M3 (Phase 2.7.2)                                                        |
| Current Evidence-Based Classification: M1 (Phase 2.7.4)                                           |
| Primary Functionality: FAM13 / Wave 3 Re-credentialing                                             |
| Authoritative Spec: docs/testing/pre_manual_testing_audit/08_manual_test_case_master_list.md:812   |
+----------------------------------------------------------------------------------------------------+
```

#### A. Exact Test Objective, Steps & Expected Result
- **Objective:** Verify that single-use pairing codes or re-credentialing challenge tokens cannot be redeemed more than once (prevention of replay / double-spend attacks).
- **Steps:**
  1. Generate and redeem a recovery challenge token with a valid 6-character code.
  2. Capture the raw HTTP POST payload sent to `redeem_recredential_challenge` (or `redeem_pairing_code`).
  3. Replay the exact same HTTP POST payload 1 second later.
- **Expected Result:** The server rejects the second request with HTTP 400 Bad Request or HTTP 409 Conflict (`challenge_already_redeemed`); database credentials remain intact.

#### B. Source Evidence & SQL Architecture
- **Schema & Stored Procedure Source:** `supabase/migrations/20260101000600_atomic_pairing_invite.sql:45` and `supabase/migrations/20261030000200_phase1_authorization.sql`.
- **Database Objects Involved:**
  - Table: `public.pairing_codes` / `device_pairing_challenges` (`is_redeemed`, `redeemed_at`, `expires_at`).
  - RPC: `public.redeem_pairing_code()` executing an atomic conditional update:
    ```sql
    UPDATE public.pairing_codes
    SET is_redeemed = TRUE, redeemed_at = now()
    WHERE code = p_code AND is_redeemed = FALSE AND expires_at > now();
    ```

#### C. Replay vs Existing-Schema Dependency Analysis
- **Concurrency & State Mechanism:** Atomic redemption relies on PostgreSQL row locks and the `WHERE is_redeemed = FALSE` predicate.
- **Replay Necessity Assessment:** The atomic redemption logic is tested by inserting a single test challenge row, redeeming it once (setting `is_redeemed = TRUE`), and attempting to redeem it a second time. This can be performed repeatedly on any compatible schema using disposable challenge tokens. Replaying migrations does not alter how PostgreSQL executes atomic conditional `UPDATE` statements.
- **Adversarial Conclusion:** Replaying migrations provides zero incremental security assurance over testing against an existing compatible schema with a fresh, disposable challenge token fixture.

> **MANDATORY DECLARATION FOR TC-SEC02:**  
> **Fresh migration replay is not required for this test case when an existing compatible schema and authorized isolated fixtures are available.**

---

### 3.3 TC-EXP-17: Parent Device Revocation and Child Session Invalidation

```
+----------------------------------------------------------------------------------------------------+
| Test ID: TC-EXP-17                                                                                |
| Historical Classification: M3 (Phase 2.7.2)                                                        |
| Current Evidence-Based Classification: M1 (Phase 2.7.4)                                           |
| Primary Functionality: FAM12 / Device Revocation                                                   |
| Authoritative Spec: docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md:550  |
+----------------------------------------------------------------------------------------------------+
```

#### A. Exact Test Objective, Steps & Expected Result
- **Objective:** Verify that revoking a child device from the Parent Dashboard updates the device record in Supabase to `revoked`, terminates child background synchronization, and invalidates child local Keystore credentials.
- **Steps:**
  1. On the Parent app, open Device Details for a paired child phone.
  2. Tap "Revoke Device Access" in the danger zone.
  3. Enter confirmation phrase "REVOKE" and confirm.
  4. Observe Parent UI status transitions to "Revoked".
  5. Inspect Child phone: receives revocation push, wipes local keys, displays "Device Access Revoked by Parent", and halts daemons.
- **Expected Result:** Backend transitions device record to `revoked` and rejects subsequent heartbeat attempts; child daemon halts.

#### B. Source Evidence & Architecture
- **Source Files:**
  - Flutter UI: `lib/features/parent/presentation/screens/device_details_screen.dart`
  - Backend Handler: `supabase/functions/device-command/index.ts`
  - Android Daemon: `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt`
- **Database Objects Involved:**
  - Tables: `public.devices` (`status`, `is_revoked`, `updated_at`), `public.device_commands`.

#### C. Replay vs Existing-Schema Dependency Analysis
- **Data Lifecycle Mechanism:** Device revocation is a localized status transition (`UPDATE public.devices SET status = 'revoked' WHERE id = ?`). It affects only the target device record.
- **Replay Necessity Assessment:** Phase 2.7.2 placed this in M3 under the theory that testing device revocation requires an "unpolluted baseline." However, in software testing governance, an unpolluted baseline for a device record is achieved simply by enrolling a dedicated disposable test device fixture (`E2`/`E4`). It does not require dropping the PostgreSQL schema or executing migration replay.
- **Adversarial Conclusion:** `TC-EXP-17` tests device row state transitions and push notifications, which function identically on an existing compatible schema.

> **MANDATORY DECLARATION FOR TC-EXP-17:**  
> **Fresh migration replay is not required for this test case when an existing compatible schema and authorized isolated fixtures are available.**

---

### 3.4 TC-EXP-18: Device Re-Credentialing Recovery Challenge Flow

```
+----------------------------------------------------------------------------------------------------+
| Test ID: TC-EXP-18                                                                                |
| Historical Classification: M3 (Phase 2.7.2)                                                        |
| Current Evidence-Based Classification: M1 (Phase 2.7.4)                                           |
| Primary Functionality: FAM13 / Cryptographic Re-credentialing                                     |
| Authoritative Spec: docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md:580  |
+----------------------------------------------------------------------------------------------------+
```

#### A. Exact Test Objective, Steps & Expected Result
- **Objective:** Verify that a paired child device that lost local Keystore credentials (e.g. app reinstalled) can restore its cryptographic connection via a parent recovery challenge without registering as a duplicate device.
- **Steps:**
  1. On Parent app, open Device Details -> "Generate Recovery Code".
  2. Note 6-character recovery challenge code.
  3. Reinstall app on child device and launch in Child Mode.
  4. Select "Recover Connection" and enter the 6-character code.
- **Expected Result:** Child device re-authenticates, receives existing device credentials, re-links to the existing `devices` row, and resumes telemetry without creating an orphaned record.

#### B. Source Evidence & Architecture
- **Source Files:**
  - Schema: `supabase/migrations/20260101000600_atomic_pairing_invite.sql`
  - Edge Function: `supabase/functions/device-register/index.ts`
  - Native Keystore: `android/app/src/main/kotlin/com/parentcontrol/parent_control/KeystoreManager.kt`
- **Database Objects Involved:**
  - Tables: `public.devices`, `public.pairing_codes` / `device_pairing_challenges`.

#### C. Replay vs Existing-Schema Dependency Analysis
- **Data Lifecycle Mechanism:** Re-credentialing explicitly requires an *already-existing* device row in the `devices` table to verify that re-linking updates the existing record rather than generating a new ID.
- **Replay Necessity Assessment:** Replaying migrations from scratch creates an empty schema with no devices. A tester would still have to create a parent, create a child device, simulate key loss, and then test recovery. Running this against an existing compatible database using an isolated test family (`E2`) is not only valid—it is the natural test workflow.
- **Adversarial Conclusion:** A fresh migration replay is not required.

> **MANDATORY DECLARATION FOR TC-EXP-18:**  
> **Fresh migration replay is not required for this test case when an existing compatible schema and authorized isolated fixtures are available.**

---

## 4. Reconciled Audit A Master Matrix

The following table provides the formal reconciliation between historical and current evidence-based classifications:

| Test Case ID | Test Case Title | Historical Class (P2.7.2) | Current Class (P2.7.4) | Replay Required? | Minimum Required Environment | Isolation Control | Source Confidence |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **`TC-SEC01`** | Cross-Family Unauthorized Data Access Boundary | **`M3`** | **`M1`** | **NO** | `E2` (Isolated Tenant) | Disposable Family Fixture | **HIGH** |
| **`TC-SEC02`** | Replay of Staged Credential Redemption | **`M3`** | **`M1`** | **NO** | `E2` (Isolated Tenant) | Disposable Pairing Code | **HIGH** |
| **`TC-EXP-17`**| Parent Device Revocation and Child Session Invalidate | **`M3`** | **`M1`** | **NO** | `E2` (Isolated Tenant) | Disposable Device Record | **HIGH** |
| **`TC-EXP-18`**| Device Re-Credentialing Recovery Challenge Flow | **`M3`** | **`M1`** | **NO** | `E2` (Isolated Tenant) | Existing Device Record | **HIGH** |

---

## 5. Architectural & Governance Impact on M-Class Totals

The reclassification of all four historical `M3` test cases to `M1` resolves the artificial conflation between **Environment Provisioning (E-Class)** and **Database Migration Dependency (M-Class)**:
1. **Zero Tests Genuinely Require `M3`**: None of the 99 test cases require a fresh migration replay as part of their test procedure.
2. **Migration Replay Belongs to Environment Provisioning (`E3`)**: If the Project Owner authorizes Pathway A (Dedicated Cloud) or Pathway C (Local Docker), running `supabase db reset` or executing migrations is an **infrastructure setup step**, not a per-test execution dependency.
3. **Audit A Shift**:
   - `M3` count decreases from **4 to 0**.
   - `M1` baseline increases by **+4** (before factoring in Audit B adjustments from `M4`).
