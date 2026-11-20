# Phase 3.6 — Report 05: Multi-Tenant Security Threat Model (TEN-01 to TEN-14)

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Audit Date:** 2026-11-20  

---

## 1. Threat Model Overview

This threat model evaluates all potential attack vectors, cross-tenant leakages, and operational failure modes that could arise from introducing ephemeral test tenants into `parent-control-prod`.

```
                    ┌──────────────────────────────────┐
                    │  Ephemeral Test Tenant Threat    │
                    │         Boundary Analysis        │
                    └─────────────────┬────────────────┘
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         ▼                            ▼                            ▼
  Access & Isolation            Data Lifecycle             Operational & Leakage
(TEN-01 to TEN-06)            (TEN-07 to TEN-10)            (TEN-11 to TEN-14)
 - RLS bypass                  - Mass retention purge        - Sensitive log leakage
 - Scope leakage               - Accidental real user sweep  - Global config tampering
 - Cross-tenant deletion       - Orphaned Auth records       - UI cross-contamination
```

---

## 2. Comprehensive Threat Evaluation Matrix

### TEN-01: Test Parent Accesses Another Tenant
- **Attack Scenario:** A test parent user presents their valid JWT to read profiles, families, or devices belonging to another real family.
- **Preconditions:** Test parent is authenticated; attempts direct PostgREST or Edge Function queries.
- **Impact:** High (Unauthorized data disclosure across tenants).
- **Existing Mitigation:** RLS policies `families_select_members` and `profiles_select_self_or_family` enforce `private.is_family_member(family_id)` and `private.shares_active_family(id)`.
- **Additional Control:** Pre-flight isolation probe in Stage 2 before running any functional test.
- **Evidence Reference:** `20260101000200_rls.sql` lines 27–48; `20260101000000_core.sql` lines 571–620.
- **Residual Risk:** Low | **Status:** **PASS**

### TEN-02: Test Child Accesses Another Family
- **Attack Scenario:** A test child user attempts to query devices, locations, or policies of another family.
- **Preconditions:** Test child is authenticated; queries `devices` or `location_events`.
- **Impact:** High (Breach of minor child and family privacy).
- **Existing Mitigation:** RLS policies `devices_select_parent_or_child` and `location_events_select_parent_or_child` require `child_user_id = auth.uid()` or parent membership in the target family.
- **Additional Control:** Unit test suite `scope_test.ts` (17 tests) verifies that child scope cannot cross family boundaries.
- **Evidence Reference:** `20260101000200_rls.sql` lines 68–73, 122–129.
- **Residual Risk:** Low | **Status:** **PASS**

### TEN-03: User-Supplied User ID Overrides Verified JWT Identity
- **Attack Scenario:** An attacker supplies `"user_id": "<VICTIM_UUID>"` in the JSON request body to `export` or `delete`.
- **Preconditions:** Attacker has valid JWT; targets victim's account.
- **Impact:** Critical (Account hijacking or unauthorized deletion).
- **Existing Mitigation:** Edge Function strictly extracts identity from GoTrue Auth claims (`caller.user.id`), completely ignoring client body parameters.
- **Additional Control:** Regression test `deletion_test.ts` (Test 13: Cross-user deletion attempt).
- **Evidence Reference:** `shared-auth.ts` lines 84–105 (`requireAuthUser`); `deletion.ts` line 423.
- **Residual Risk:** Negligible | **Status:** **PASS**

### TEN-04: Test Device Accesses Another User's Data
- **Attack Scenario:** A test device presents headers `x-device-id` and `x-device-secret` attempting to poll or acknowledge commands for a production device.
- **Preconditions:** Device possesses test secret; requests foreign device ID.
- **Impact:** High (Device command injection or telemetry spoofing).
- **Existing Mitigation:** Constant-time comparison `constantTimeEqualHex` on SHA-256 secret hashes; RLS on `device_commands` checks device ownership.
- **Additional Control:** Test devices use unique installation IDs (`test-inst-...`).
- **Evidence Reference:** `shared-auth.ts` device validation; `20260101000200_rls.sql` line 105.
- **Residual Risk:** Low | **Status:** **PASS**

### TEN-05: Account Export Leaks Unrelated Records
- **Attack Scenario:** Ephemeral parent invokes `action: "export"`, and the resulting archive contains rows from real families.
- **Preconditions:** Ephemeral parent is authenticated.
- **Impact:** Critical (GDPR breach, cross-tenant data spill).
- **Existing Mitigation:** `exportAccount` resolves scope via `resolveRetentionScope`, querying strictly `WHERE family_id IN (caller_family_ids)`. If caller has no families, it substitutes `NO_MATCH_UUID` (`00000000-...`). Device secrets are censored.
- **Additional Control:** Unit test `deletion_test.ts` (Test 15).
- **Evidence Reference:** `index.ts` lines 227–343.
- **Residual Risk:** Low | **Status:** **PASS**

### TEN-06: Account Deletion Removes Another Tenant's Data
- **Attack Scenario:** Ephemeral parent invokes `action: "delete"`, and cascade triggers deletion of foreign family or device rows.
- **Preconditions:** Ephemeral parent is authenticated.
- **Impact:** Catastrophic (Data loss for real families).
- **Existing Mitigation:** `executeAccountDeletion` deletes strictly where `user_id = caller.user.id` and `families.owner_id = caller.user.id`. Owned families with other members or active devices are blocked with `409`.
- **Additional Control:** Foreign key constraints with `ON DELETE CASCADE` follow verified ownership trees.
- **Evidence Reference:** `deletion.ts` lines 418–599; `validation.ts` blocker checks.
- **Residual Risk:** Low | **Status:** **PASS**

### TEN-07: Retention Cleanup Selects Non-Test Users
- **Attack Scenario:** A test execution triggers retention cleanup, purging real location or usage data prematurely.
- **Preconditions:** Request sent to `account` function with `action: "retention_cleanup"`.
- **Impact:** Critical (Unrecoverable data loss).
- **Existing Mitigation:** `account` Edge Function router explicitly omits `retention_cleanup` (throws `400 unknown_action`). Retention purging is exclusively handled by the server-side cron function `public.run_retention_sweep()`.
- **Additional Control:** Phase 3.6 permanently prohibits invoking the cron function or modifying retention windows.
- **Evidence Reference:** `index.ts` lines 460–476; `20261030000300_retention_sweep.sql`.
- **Residual Risk:** Negligible | **Status:** **PASS**

### TEN-08: Cleanup Selector Matches a Real User
- **Attack Scenario:** A test cleanup script runs a wildcard or broad query (e.g. `DELETE FROM profiles WHERE display_name LIKE '%Test%'`) that matches a real production user.
- **Preconditions:** Cleanup script executed with broad matching criteria.
- **Impact:** Catastrophic (Accidental deletion of operational users).
- **Existing Mitigation:** Cleanup scripts are prohibited from using substring matching.
- **Additional Control:** Cleanup must strictly query by exact `metadata->>'test_correlation_id'` and assert explicit exclusion of protected accounts (`spg7753@gmail.com`, `ankit@gmail.com`, `ankit1@gmail.com`).
- **Evidence Reference:** Report 08 cleanup specification.
- **Residual Risk:** Low | **Status:** **PASS**

### TEN-09: Expired Test Tenant Remains Accessible
- **Attack Scenario:** An ephemeral tenant is not cleaned up after testing and remains active indefinitely.
- **Preconditions:** Test suite crashes or is interrupted before cleanup.
- **Impact:** Moderate (Database clutter, unmanaged active accounts).
- **Existing Mitigation:** None in core schema.
- **Additional Control:** Mandatory Stage 5 Expiration and Recovery Sweeper with a 1-hour TTL on test correlation metadata.
- **Evidence Reference:** Report 04 Stage 5.
- **Residual Risk:** Low | **Status:** **PASS**

### TEN-10: Incomplete Cleanup Leaves Orphaned Auth or Database Records
- **Attack Scenario:** Database rows are removed, but GoTrue Auth user remains (or vice-versa), cluttering Auth.
- **Preconditions:** Network timeout during two-phase deletion.
- **Impact:** Low-to-Moderate (Orphaned auth records, email namespace pollution).
- **Existing Mitigation:** `account` Edge Function implements retry recovery (`requireAuthUser` authorizes deletion retries when profile is missing).
- **Additional Control:** Cleanup script verifies both GoTrue Auth and database tables, retrying until both are clean.
- **Evidence Reference:** `deletion.ts` lines 536–576.
- **Residual Risk:** Low | **Status:** **PASS**

### TEN-11: Audit Events Expose Sensitive Identifiers
- **Attack Scenario:** Audit logs generated during test runs record real credentials, unencrypted tokens, or private user IDs.
- **Preconditions:** Test actions generate audit rows.
- **Impact:** Moderate (Security audit trail pollution or secret leakage).
- **Existing Mitigation:** `recordAudit` logs only event types, target IDs, and structured metadata; secret material is never passed to audit helpers.
- **Additional Control:** Synthetic test accounts use fake identifiers; audit logs for test runs are tagged with `test_correlation_id`.
- **Evidence Reference:** `shared-audit.ts` lines 1–37.
- **Residual Risk:** Negligible | **Status:** **PASS**

### TEN-12: Test Configuration Accidentally Affects Production Users
- **Attack Scenario:** A test changes global family settings (e.g., default retention window) affecting other families.
- **Preconditions:** Test modifies project-wide tables or functions.
- **Impact:** High (System-wide configuration alteration).
- **Existing Mitigation:** Retention settings are strictly per-family JSON columns (`families.settings`); there is no global mutable settings table.
- **Additional Control:** Prohibit DDL, migration, or Vault changes.
- **Evidence Reference:** `20260101000000_core.sql` line 37.
- **Residual Risk:** Negligible | **Status:** **PASS**

### TEN-13: Test Credentials or Secrets Leak into Reports/Logs
- **Attack Scenario:** Temporary JWTs or passwords used during ephemeral testing are printed into git markdown reports or CI logs.
- **Preconditions:** Verbose logging in test scripts.
- **Impact:** High (Unauthorized API access).
- **Existing Mitigation:** Strict testing guidelines prohibit printing tokens or secrets.
- **Additional Control:** Scripts output sanitized tokens (`Bearer eyJ...***`); ephemeral tokens expire within 1 hour.
- **Evidence Reference:** Phase 3.6 Report 06 (Test Data Classification).
- **Residual Risk:** Negligible | **Status:** **PASS**

### TEN-14: Test Tenant Becomes Visible to Real Application Users
- **Attack Scenario:** A real parent or child browsing the Flutter app sees ephemeral test families or devices in their list.
- **Preconditions:** RLS failure or UI query lacking family scoping.
- **Impact:** High (Loss of user trust, confusing UI clutter).
- **Existing Mitigation:** `families_select_members` strictly requires membership in the family; devices are visible only to family members. A user never sees unlinked families.
- **Additional Control:** Ephemeral families are never linked to real users.
- **Evidence Reference:** `20260101000200_rls.sql` lines 43–64.
- **Residual Risk:** Negligible | **Status:** **PASS**

---

## 3. Threat Model Verdict

$$\mathbf{14\ of\ 14\ Threats\ Evaluated\ -\ ZERO\ UNMITIGATED\ CRITICAL\ RISKS}$$

All multi-tenant isolation, cross-tenant mutation, and audit risks are fully controlled by existing database constraints, RLS policies, Edge Function logic, and the newly defined Stage 1–5 operational guardrails.
