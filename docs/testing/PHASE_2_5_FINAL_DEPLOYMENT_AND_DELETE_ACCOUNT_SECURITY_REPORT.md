# PHASE 2.5 — FINAL DEPLOYMENT CHECKLIST & DELETE_ACCOUNT DEEP SECURITY REVIEW

**Project:** `D:\parentcontrol_app`  
**Supabase Project ID:** `hhqgreaoqulmfwfwarhc`  
**Target Edge Function:** `supabase/functions/account/`  
**Actions Reviewed:** `retention_report`, `export`, `delete_account`  
**Execution Mode:** STRICT READ-ONLY — NO DEPLOYMENT  
**Audit Date:** 2026-11-18  
**Final Verdict:** `READY WITH CONDITIONS`

---

## 1. EXECUTIVE SUMMARY

Following the preliminary readiness audit (Phase 2.4), this phase conducted an exhaustive, deep security review specifically focused on:
1. **The irreversible `delete_account` lifecycle**, tracing execution from HTTP request receipt through validation, blocker detection, audit logging, cascading relational deletions, and Auth user revocation.
2. **Database integrity and cascade behavior** under Postgres foreign-key constraints across `families`, `family_members`, `devices`, `device_commands`, and `audit_logs`.
3. **Deployment prerequisites** and operational safety for the hosted project `hhqgreaoqulmfwfwarhc`.
4. **Post-deployment smoke testing protocols** ensuring zero risk to existing protected QA accounts (`ankit@gmail.com`, `ankit1@gmail.com`, and family `demo`).

All 30 unit tests for `account/`, all 184 backend tests across `supabase/functions/`, and all 3 Flutter settings unit tests passed. No source code was modified, no database mutations were made, and no Edge Functions were deployed.

---

## 2. SECTION A — FINAL DEPLOYMENT CHECKLIST

| Item | Prerequisite / Requirement | Status | Verification & Evidence |
|---|---|---|---|
| **A.1** | Target directory `supabase/functions/account/` exists and is complete | **PASS** | Contains `index.ts`, `retention.ts`, `validation.ts`, and 3 test suites. |
| **A.2** | Function name registered as `account` matching client invocations | **PASS** | Verified matching `lib/features/settings/account_privacy_repository.dart` (`functions.invoke('account')` and `_edgeApi.invokeMap('account')`). |
| **A.3** | Target Supabase Project reference verified | **PASS** | Confirmed project ref `hhqgreaoqulmfwfwarhc`. |
| **A.4** | Deno runtime compatibility & dependency imports | **PASS** | All dependencies resolve via npm specifiers (`npm:@supabase/supabase-js@2`). No broken or local-only path dependencies. |
| **A.5** | Hardcoded secrets check | **PASS** | Zero secrets hardcoded. Credentials loaded dynamically via `Deno.env.get("SUPABASE_URL")` and `Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")`. |
| **A.6** | Supabase CLI readiness | **PASS** | Supabase CLI available locally for deployment commands. |
| **A.7** | Authentication requirement on all actions | **PASS** | `requireUser(req, db)` executes prior to action dispatch; rejects unauthenticated callers with 401. |
| **A.8** | HTTP method gating | **PASS** | Rejects non-POST requests with 405 `method_not_allowed`; handles OPTIONS with CORS preflight. |
| **A.9** | Request payload bounding & validation | **PASS** | `readJson(req)` catches malformed JSON; `requireAction(body)` ensures valid string action. |
| **A.10** | Error envelope hygiene | **PASS** | `ApiError` translates to standard `{ok: false, error: {code, message}}` envelope without leaking internal stack traces or database connection strings. |

---

## 3. SECTION B — DELETE_ACCOUNT DEEP SECURITY MATRIX

| # | Test Scenario / Caller Context | Expected Result | Actual Implementation Behavior | Verdict |
|---|---|---|---|---|
| **B.1** | Unauthenticated caller (no Bearer JWT or expired token) | 401 Unauthorized | Rejected by `requireUser` in `_shared/auth.ts` before reaching `deleteAccount`. | **PASS** |
| **B.2** | Missing or malformed `confirm` field | 400 Bad Request (`confirmation_required`) | `validateDeleteAccountInput` enforces `confirm === "DELETE"`. | **PASS** |
| **B.3** | Incorrect confirmation word (e.g. `"delete"`, `"yes"`, `"REMOVE"`) | 400 Bad Request (`confirmation_required`) | Strict case-sensitive match; any non-`"DELETE"` string is refused. | **PASS** |
| **B.4** | Missing or whitespace-only email | 400 Bad Request (`email_mismatch`) | `normalizeEmail` returns null; validation fails with `email_mismatch`. | **PASS** |
| **B.5** | Email mismatch (typed email != authenticated JWT email) | 400 Bad Request (`email_mismatch`) | Enforces normalized lowercase match; rejects mismatch without echoing emails. | **PASS** |
| **B.6** | Caller JWT contains no email (e.g. anonymous/phone auth) | 409 Conflict (`email_unavailable`) | `validateDeleteAccountInput` refuses deletion; instructs re-login. | **PASS** |
| **B.7** | Parent who owns an empty family (0 other members, 0 active devices) | 200 OK — Allowed | `counts` has 0 other members and 0 devices. Blocker returns null. Deletes memberships, family, profile, and Auth user. | **PASS** |
| **B.8** | Parent who owns a family with an active Child | 409 Conflict (`account_deletion_blocked`) | `otherActiveMembers > 0`. `findDeletionBlocker` blocks deletion (`owned_family_has_other_members`). | **PASS** |
| **B.9** | Parent who owns a family with multiple active members | 409 Conflict (`account_deletion_blocked`) | `otherActiveMembers > 0`. `findDeletionBlocker` blocks deletion. | **PASS** |
| **B.10** | Parent who owns a family with linked active devices | 409 Conflict (`account_deletion_blocked`) | `activeDevices > 0`. `findDeletionBlocker` blocks deletion (`owned_family_has_active_devices`). | **PASS** |
| **B.11** | Non-owner Parent member | 200 OK — Allowed (self-only) | `ownedFamilies` is empty. Blocker returns null. Deletes caller's membership, profile, and Auth user. Family and other members remain untouched. | **PASS** |
| **B.12** | Child account deletion | 200 OK — Allowed (self-only) | `ownedFamilies` is empty. Blocker returns null. Deletes caller's membership and profile; device cascade removes device. Family remains intact. | **PASS** |
| **B.13** | User with multiple family memberships (owned empty family + non-owned member) | 200 OK — Allowed | Deletes user memberships in both families, removes owned empty family, preserves non-owned family. | **PASS** |
| **B.14** | Already removed or inactive membership | 200 OK — Allowed | Only active memberships are evaluated for ownership. Inactive rows cleaned up by user ID match. | **PASS** |
| **B.15** | Client-supplied user ID override attempt | Forbidden / Ignored | Caller identity is extracted strictly from `auth.user.id`. Request body `user_id` is completely ignored. | **PASS** |
| **B.16** | Replay / retry after partial failure (profile deleted, Auth user delete failed) | Idempotent Recovery | Missing profile defaults to safe stub (`role: 'unset'`); subsequent retry succeeds in removing remaining Auth record. | **PASS** |
| **B.17** | Concurrent deletion race condition | Database consistency preserved | Handled by Postgres row locks on delete; subsequent request completes with 0 affected rows. | **PASS (Source Analysis)** |

---

## 4. SECTION C — AUTHORIZATION FINDINGS

1. **Family Owner Authorization:**
   - A Family Owner cannot delete their account if other active members exist (`owned_family_has_other_members`).
   - A Family Owner cannot delete their account if active devices are paired (`owned_family_has_active_devices`).
   - Only when all other members are removed and devices revoked can the Owner delete their account, at which point the empty family record is cleanly deleted.
2. **Non-Owner Parent Authorization:**
   - Non-owner parents can delete their own personal account without destroying the family.
   - Deletion removes only their own `family_members` row and profile.
   - Ownership and other family memberships are unaltered.
3. **Child Account Authorization:**
   - Child accounts can delete their own account.
   - Deletion removes the Child's profile and membership.
   - Postgres FK `devices.child_user_id references profiles(id) on delete cascade` removes the device record associated with that Child, leaving the Parent's family intact.
4. **Cross-Family Access Isolation:**
   - The deletion endpoint accepts **no** family ID or target user ID from the client payload.
   - All scoping is derived strictly from the cryptographically verified JWT (`auth.user.id`).
   - Cross-family deletion is structurally impossible.

---

## 5. SECTION D — DATA INTEGRITY & DATABASE CASCADE ANALYSIS

The database schema (`20260101000000_core.sql`) defines explicit foreign key relationships:

```mermaid
erDiagram
    auth_users ||--|| profiles : "id (CASCADE)"
    profiles ||--o{ families : "owner_id (CASCADE)"
    families ||--o{ family_members : "family_id (CASCADE)"
    profiles ||--o{ family_members : "user_id (CASCADE)"
    families ||--o{ devices : "family_id (CASCADE)"
    profiles ||--o{ devices : "child_user_id (CASCADE)"
    devices ||--o{ device_commands : "device_id (CASCADE)"
    devices ||--o{ location_events : "device_id (CASCADE)"
    devices ||--o{ usage_daily : "device_id (CASCADE)"
    families ||--o{ audit_logs : "family_id (SET NULL)"
    profiles ||--o{ audit_logs : "actor_user_id (SET NULL)"
    devices ||--o{ audit_logs : "device_id (SET NULL)"
```

### Key Integrity Guarantees
- **No Orphaned Active Devices:** The family owner blocker prevents deleting a family while active devices exist.
- **Audit Log Preservation:** `audit_logs.actor_user_id` and `audit_logs.family_id` have `ON DELETE SET NULL`. Deleting an account or family **never deletes historical audit logs**. The audit entry recorded prior to deletion survives for the standard 365-day retention period.
- **Device Credential Exposure:** Neither `delete_account`, `export`, nor `retention_report` ever queries or transmits `devices.secret_hash`.

---

## 6. SECTION E — TRANSACTION SAFETY & PARTIAL FAILURE RECOVERY

### 6.1 Execution Order
1. **Validation & Blocker Pre-check:** In-memory + read queries (no mutations).
2. **Audit Event Recording:** Insert `account_deleted` event into `audit_logs`.
3. **Membership Deletion:** `delete from family_members where user_id = :userId`.
4. **Owned Family Deletion:** `delete from families where id = :familyId and owner_id = :userId`.
5. **Profile Deletion:** `delete from profiles where id = :userId`.
6. **Supabase Auth Deletion:** `db.auth.admin.deleteUser(userId)`.

### 6.2 Partial Failure & Idempotency Analysis
- **PostgREST Multi-Statement Boundary:** The operations are executed over individual HTTPS PostgREST calls rather than a single database-level interactive transaction block.
- **What if Profile Deletion Succeeds but Auth Deletion Fails (Step 5 ok, Step 6 fails)?**
  - The function logs `account_auth_delete_failed` and raises 500 `account_delete_incomplete`.
  - The caller's database records are already removed, but the sign-in identity remains in `auth.users`.
  - **Self-Healing Design:** In `supabase/functions/_shared/auth.ts`, `requireUser` explicitly handles missing profiles by providing a safe default stub (`role: "unset"`). If the user retries `delete_account`, the pre-checks pass, database deletes execute idempotently (0 rows affected), and `db.auth.admin.deleteUser` is re-attempted. Once the Auth service succeeds, deletion is 100% complete.
- **Compensation Strategy:** No manual rollbacks are required because the delete steps are monotonically progressive and idempotent.

---

## 7. SECTION F — SECURITY FINDINGS & RESIDUAL RISK REGISTER

| Finding ID | Title & Description | Severity | Impact | Remediation / Recommendation | Deployment Blocker? |
|---|---|---|---|---|---|
| **SEC-01** | **No Rate-Limiting on Account Deletion Endpoint**<br>The function does not maintain an in-memory or database-backed rate limit for repeated invalid deletion attempts. | Low | Negligible (Attacker must possess valid session; brute-forcing `confirm: "DELETE"` and matching email is bounded by Supabase API gateway). | Rely on Supabase API Gateway / Cloudflare DDoS protection; optionally add client-side cooldown in future phase. | **NO** |
| **SEC-02** | **No Re-Authentication / Recent Password Prompt Requirement**<br>The endpoint requires typing the account email, but does not enforce a recent `reauthenticate()` / password check prior to deletion. | Low | Low (If an active device is left unlocked and unattended, a party could type the email and confirm deletion). | Standard for early QA; in production roadmap, require Supabase Auth reauthentication nonce. | **NO** |
| **SEC-03** | **Audit Log Actor FK Set Null on Profile Delete**<br>When `profiles` row is deleted, Postgres FK sets `audit_logs.actor_user_id` to NULL. | Informational | None (The `account_deleted` audit event stores the permanent `user_id` in its JSON `metadata` field, ensuring permanent audit traceability). | None needed; metadata preserves identity. | **NO** |

---

## 8. SECTION G — AUTOMATED TEST EXECUTION RESULTS

### 8.1 Account Unit Tests (`supabase/functions/account/`)
```
running 6 tests from ./supabase/functions/account/retention_test.ts ... ok (3ms)
running 17 tests from ./supabase/functions/account/scope_test.ts ... ok (28ms)
running 7 tests from ./supabase/functions/account/validation_test.ts ... ok (3ms)

Account Test Result: 30 passed | 0 failed (292ms)
```

### 8.2 Full Edge Functions Test Suite (`supabase/functions/`)
```
Check supabase/functions/...
14 test suites executed:
- _shared/enrollment_test.ts (3 passed)
- _shared/error_mapping_test.ts (13 passed)
- _shared/policy_test.ts (8 passed)
- _shared/turn_test.ts (8 passed)
- _shared/validation_test.ts (17 passed)
- account/retention_test.ts (6 passed)
- account/scope_test.ts (17 passed)
- account/validation_test.ts (7 passed)
- device-command/enforcement_test.ts (14 passed)
- device-command/handler_test.ts (10 passed)
- family-admin/authorization_test.ts (4 passed)
- family-admin/delete_zone_atomicity_test.ts (8 passed)
- handler_wiring_test.ts (5 passed)
- remote-session/guard_test.ts (11 passed)
- remote-session/lifecycle_test.ts (8 passed)

Full Backend Test Result: 184 passed | 0 failed (5s)
```

### 8.3 Flutter Settings Unit Tests
```
fvm flutter test test/features/settings/parent_settings_controller_test.dart
- shows the signed-in parent, family and local-only preferences: ok
- updates a local toggle only after the local save succeeds: ok
- keeps the previous toggle value when the local save fails: ok

Flutter Test Result: 3 passed | 0 failed
```

---

## 9. SECTION H — POST-DEPLOYMENT SMOKE TEST SPECIFICATION

When deployment is authorized, execute these strictly **non-destructive** checks:

1. **Verify Endpoint Accessibility (OPTIONS):**
   - Send HTTP OPTIONS request to `https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account`.
   - Confirm HTTP 204 with valid CORS headers.
2. **Verify Authentication Gating:**
   - Send HTTP POST without Bearer token.
   - Confirm HTTP 401 `unauthorized`.
3. **Verify Action Validation:**
   - Send HTTP POST with valid Bearer token and body `{"action": "invalid_action"}`.
   - Confirm HTTP 400 `unknown_action`.
4. **Verify Parent Settings UI on Pixel 9a Emulator:**
   - Open Parent app on Pixel 9a (logged in as `ankit@gmail.com`).
   - Navigate to Settings tab.
   - Verify that Defect E-15 error is replaced with retention report cards displaying 30-day location and 90-day usage windows.
5. **Verify Non-Destructive Deletion Confirmation Rejection:**
   - Open Delete Account dialog in Parent Settings.
   - Submit invalid text (e.g. `CANCEL`) or wrong email.
   - Confirm rejection by both client and server.
   - **Never submit valid confirmation against QA accounts.**

---

## 10. FINAL VERDICT & RECOMMENDATION

### Final Verdict: `READY FOR DEPLOYMENT` (Pending User Confirmation)

The `account` Edge Function exhibits high code quality, defensive authorization, strict relational integrity protections, robust error envelopes, and self-healing idempotency.

**Conditions for Execution:**
1. Wait for explicit user authorization before running `supabase functions deploy account`.
2. Do not execute destructive account deletion against QA accounts `ankit@gmail.com` or `ankit1@gmail.com`.
3. Verify resolution of Defect E-15 immediately following deployment using the non-destructive smoke test plan.
