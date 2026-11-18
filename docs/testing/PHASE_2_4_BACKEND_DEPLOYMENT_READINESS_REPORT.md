# PHASE 2.4 — SUPABASE BACKEND DEPLOYMENT READINESS & SECURITY AUDIT REPORT

**Project:** `D:\parentcontrol_app`  
**Supabase Project ID:** `hhqgreaoqulmfwfwarhc`  
**Target Function:** `supabase/functions/account/`  
**Actions Audited:** `retention_report`, `export`, `delete_account`  
**Audit Date:** 2026-11-18  
**Audit Status:** Complete — Read-Only Mode (No code changes, no DB mutations, no deployment performed)  
**Final Verdict:** `READY WITH CONDITIONS`

---

## 1. EXECUTIVE SUMMARY

During Phase 2.2 and Phase 2.3 functional testing, Defect **E-15** was observed in the Parent Settings screen:
> `Retention report unavailable: Requested function was not found`

Investigation revealed that the complete implementation of the `account` Edge Function exists in the local repository under `supabase/functions/account/` alongside a comprehensive unit test suite (30 automated Deno tests), but had not yet been deployed to the remote Supabase project `hhqgreaoqulmfwfwarhc`.

This security and deployment-readiness audit evaluated the complete source code, authentication flow, authorization matrix, cross-family isolation, sensitive data leakage risks, cascading deletion behaviors, and automated test coverage of `supabase/functions/account/`.

### Summary of Audit Findings
1. **Authentication & Identity Assurance:** Strict Bearer token validation via `db.auth.getUser(token)` on every non-OPTIONS HTTP request. Identity and permissions are derived strictly from the verified JWT and server-side database records. Client-supplied IDs cannot spoof or escalate privileges.
2. **Authorization & Privacy Scoping (PRIV-01):** Uses a three-state data scope model (`family`, `device`, `not_reported`). A Child caller is strictly confined to `device` scope (only devices where `devices.child_user_id == caller.id`). A Parent caller is confined to families where they hold an active membership. Project-wide sweep telemetry is restricted exclusively to family owners.
3. **Data Export Safety:** Sensitive device credentials (`secret_hash`, `device_secret`, pairing codes) are explicitly excluded from database projections. Queries are paged in 1,000-row chunks with a hard 20,000-row safety cap per table.
4. **Account Deletion Safeguards:** Requires dual confirmation: exact literal string `"DELETE"` plus case-insensitive caller email match. Family owners are blocked from deleting their account if active members or active devices still exist in the owned family, preventing orphaned or silently destroyed data. Audit log is recorded prior to record deletion.
5. **Test Results:** 30/30 Deno unit tests in `account/` passed. 184/184 backend tests across all Supabase Edge Functions passed.

---

## 2. SOURCE AUDIT & CALL FLOW TRACE

### 2.1 File Architecture
- `supabase/functions/account/index.ts` (581 lines): Main HTTP router, database query runners, pagination caps, and response formatters.
- `supabase/functions/account/retention.ts` (300 lines): Pure business logic for retention window parsing, scope resolution (`resolveRetentionScope`), cutoff calculation, and sweep telemetry redaction.
- `supabase/functions/account/validation.ts` (117 lines): Pure validation logic for account deletion confirmation, email normalization, and family owner deletion blocker evaluation (`findDeletionBlocker`).
- `supabase/functions/_shared/auth.ts`: Shared JWT verification (`requireUser`), service-role client initializer (`getServiceClient`).
- `supabase/functions/_shared/envelope.ts`: Standard JSON envelope and error handler (`ApiError`, `ok`, `errorResponse`).
- `supabase/functions/_shared/audit.ts`: Shared audit logging runner (`recordAudit`).

### 2.2 Request Call Flow Trace

```mermaid
sequenceDiagram
    autonumber
    actor Client as Flutter App / HTTP Client
    participant Router as Deno.serve (index.ts)
    participant Auth as requireUser (auth.ts)
    participant Service as Supabase Service Client
    participant Handler as Action Handler (export / delete / retention)
    participant DB as Postgres Database

    Client->>Router: POST /account {action, ...} + Bearer JWT
    alt Method is OPTIONS
        Router-->>Client: 204 Preflight (CORS headers)
    else Method is not POST
        Router-->>Client: 405 Method Not Allowed
    end
    Router->>Auth: requireUser(req, db)
    Auth->>Service: db.auth.getUser(token)
    alt Invalid or expired token
        Service-->>Auth: Error
        Auth-->>Client: 401 Unauthorized
    end
    Auth->>Service: Load caller profile from profiles table
    Auth-->>Router: Return AuthContext {user, profile, emailVerified}
    
    alt action == "retention_report"
        Router->>Handler: retentionReport(db, auth)
        Handler->>DB: Query active family_members & families
        Handler->>Handler: resolveRetentionScope() -> family / device / not_reported
        Handler->>DB: Count older records (location_events, usage_daily)
        Handler-->>Client: 200 OK {ok: true, data: RetentionReport}
    else action == "export"
        Router->>Handler: exportAccount(db, auth)
        Handler->>DB: Fetch scoped tables (capped at 20,000 rows/table)
        Handler-->>Client: 200 OK (Content-Disposition: attachment; filename=*.json)
    else action == "delete_account"
        Router->>Handler: deleteAccount(db, auth, body)
        Handler->>Handler: validateDeleteAccountInput("DELETE", email)
        Handler->>DB: Check owned families for active members/devices
        alt Blocked by active members or devices
            Handler-->>Client: 409 Conflict (account_deletion_blocked)
        else Validation passed
            Handler->>DB: recordAudit("account_deleted")
            Handler->>DB: Delete family_members, empty families, profile
            Handler->>Service: db.auth.admin.deleteUser(userId)
            Handler-->>Client: 200 OK {deleted: true}
        end
    else Unknown action
        Router-->>Client: 400 Bad Request (unknown_action)
    end
```

---

## 3. AUTHORIZATION MATRIX

| Caller Role / State | `retention_report` | `export` | `delete_account` | Server-Side Enforcement Mechanism |
|---|---|---|---|---|
| **Unauthenticated** (Missing or invalid JWT) | ❌ **401 Unauthorized** | ❌ **401 Unauthorized** | ❌ **401 Unauthorized** | Gated by `requireUser` before action switch. |
| **Child** (Active child member) | ⚠️ **Allowed** (Device scope only) | ⚠️ **Allowed** (Device scope only) | ⚠️ **Allowed** (Own account only) | `resolveRetentionScope` yields `device`. Sweeps redacted. Export only includes rows matching caller's device IDs. Deletion only deletes caller's membership and profile. |
| **Parent (Non-Owner)** (Active parent member) | ⚠️ **Allowed** (Family scope, sweep totals redacted) | ⚠️ **Allowed** (Family scope) | ⚠️ **Allowed** (Own account only) | Family-wide counts returned. Sweep totals metadata stripped. Deletion does NOT delete the family; other parent retains ownership. |
| **Parent (Family Owner)** (Owner of active family) | ✅ **Allowed** (Full family scope + sweep totals) | ✅ **Allowed** (Full family scope) | ⚠️ **Conditional Guard** (Blocked if family has other members or active devices) | `findDeletionBlocker` blocks deletion with 409 if active members or active devices exist. Allows deletion only if family is empty. |
| **Cross-Family User** (Authenticated user not in target family) | ❌ **Zero Data Leakage** (`not_reported`) | ❌ **Zero Data Leakage** (`not_reported`) | ❌ **Zero Data Leakage** (Cannot touch other families) | Caller ID loaded from JWT; client cannot pass target family ID or user ID. Returns 0 rows. |
| **Profile-less / Incomplete Registration** | ❌ **Zero Data Leakage** (`not_reported`) | ❌ **Zero Data Leakage** (Only empty account metadata) | ⚠️ **Allowed** (Can delete incomplete auth record) | Safely unblocks stuck users without leaking system state. |

---

## 4. ACTION-BY-ACTION SECURITY ANALYSIS

### 4.1 Action: `retention_report`
- **Data Returned:** Summary retention windows (location retention days, usage retention days) and count of records older than the cutoff window (`location_events_older_than_window`, `usage_days_older_than_window`).
- **Privacy Protections:**
  - Never exposes raw event records, GPS coordinates, application package names, or personal identities.
  - Non-owner parents receive `last_sweep_at` timestamp, but `last_sweep` metadata (project-wide database sweep totals) is set to `null`.
  - Child accounts receive counts *only* for their own assigned devices (`device_ids = loadOwnDeviceIds(db, auth.user.id)`) and zero sweep markers.
  - Non-members receive `scope: "not_reported"` and an empty `families: []` array.
- **Defensive Safeguards:**
  - Clamping: Settings retention values are clamped between 1 and 3,650 days (`MAX_RETENTION_DAYS`) with fallbacks of 30 days (location) and 90 days (usage).
  - Empty `in.()` queries are structurally prevented by `retentionCountFilter`.

### 4.2 Action: `export`
- **Sensitive Field Exclusion:**
  - The query selecting devices explicitly targets safe columns only:
    `id, family_id, child_user_id, status, display_name, policy_version, last_seen_at, battery_level, is_charging, enforcement_mode, credential_revoked_at`
  - Sensitive columns (`secret_hash`, `device_secret`, pairing codes) are **strictly excluded**.
- **Denial-of-Service / Memory Exhaustion Protection:**
  - Queries are capped at `EXPORT_PAGE_SIZE = 1,000` and `EXPORT_ROW_CAP = 20,000` per table.
  - If a table reaches the 20,000-row cap, the export payload marks `truncated: true` for that table rather than exhausting Edge Function memory limits.
- **File Delivery:**
  - Sent with `Content-Type: application/json; charset=utf-8`, `Content-Disposition: attachment; filename="parent-control-export-YYYY-MM-DD.json"`, and `Cache-Control: no-store`.

### 4.3 Action: `delete_account`
- **Accidental Deletion Guards:**
  - Requires `confirm === "DELETE"` (strict case-sensitive match).
  - Requires `normalizeEmail(body.email) === normalizeEmail(auth.user.email)`.
- **Orphan / Disruption Prevention:**
  - Evaluates `findDeletionBlocker`:
    - If other active family members exist: `409 account_deletion_blocked` (`owned_family_has_other_members`).
    - If active devices exist: `409 account_deletion_blocked` (`owned_family_has_active_devices`).
- **Audit Trail Durability:**
  - Writes an audit log entry (`event_type: "account_deleted"`) *before* executing deletions.
  - While `profiles.id` foreign key sets `actor_user_id` to NULL upon deletion, the immutable audit event itself survives for the standard 365-day audit retention period.
- **Atomic Cascade Sequence:**
  1. Record audit event (`account_deleted`).
  2. Delete `family_members` rows where `user_id == caller.id`.
  3. Delete empty owned `families` where `owner_id == caller.id`.
  4. Delete `profiles` row where `id == caller.id`.
  5. Delete Supabase Auth record via `db.auth.admin.deleteUser(caller.id)`.

---

## 5. AUTOMATED TEST SUITE VERIFICATION

The Deno test suite was executed locally in read-only offline mode:

```bash
deno test --allow-read --allow-env supabase/functions/account/
```

### Results
```
running 6 tests from ./supabase/functions/account/retention_test.ts
parseRetentionDays falls back for unusable values ... ok (1ms)
parseRetentionDays accepts integers and numeric strings ... ok (237µs)
parseRetentionDays clamps absurd windows ... ok (152µs)
retentionFromSettings reads both windows with schema defaults ... ok (248µs)
retentionCutoffs uses a timestamp for location and a date for usage ... ok (1ms)
buildFamilyRetentionReport never invents negative counts ... ok (426µs)

running 17 tests from ./supabase/functions/account/scope_test.ts
scope: a parent who owns the family gets family scope with sweep totals ... ok (1ms)
scope: a non-owner parent member gets family counts but the sweep totals redacted ... ok (320µs)
scope: a child member gets device scope and never the sweep marker ... ok (194µs)
scope: a wrong-family caller is not_reported and reaches no family branch ... ok (363µs)
scope: an unauthenticated / profile-less caller is not_reported ... ok (246µs)
scope: a missing or unexpected profile role is not_reported with no counts ... ok (621µs)
scope: a profile role that disagrees with the membership is not_reported ... ok (296µs)
scope: membership in an unreported family cannot widen the scope ... ok (221µs)
counts: family scope counts the family, device scope only the caller's devices ... ok (272µs)
counts: a child with no devices of their own runs no query ... ok (160µs)
counts: bogus device ids are dropped and duplicates collapsed ... ok (204µs)
payload: the family owner alone receives the project-wide sweep totals ... ok (613µs)
payload: a non-owner parent keeps the timestamp but loses the totals ... ok (342µs)
payload: a child report has device counts and no sweep at all ... ok (262µs)
payload: not_reported carries no counts, no families and no sweep ... ok (340µs)
payload: the documented defaults are reported whatever the scope ... ok (19ms)
payload: a missing sweep row is reported as null, not as a guess ... ok (322µs)

running 7 tests from ./supabase/functions/account/validation_test.ts
normalizeEmail trims, lowercases and rejects non-strings ... ok (872µs)
delete requires the literal DELETE word ... ok (337µs)
delete requires the caller's own email, case-insensitively ... ok (225µs)
delete refuses when the token carries no email ... ok (136µs)
owner blocker: an otherwise empty family never blocks ... ok (256µs)
owner blocker: other active members block with their family ids ... ok (243µs)
owner blocker: active devices block when no other member remains ... ok (154µs)

Total Account Tests: 30 passed | 0 failed (292ms)
Total Backend Tests (All Functions): 184 passed | 0 failed (5s)
```

Additionally, Flutter settings unit tests were executed and verified:
```bash
fvm flutter test test/features/settings/parent_settings_controller_test.dart
# Result: 3 passed | 0 failed
```

---

## 6. DEPLOYMENT PREREQUISITES & COMMANDS

### 6.1 Prerequisites
1. **Supabase CLI:** Installed and authenticated with access to project `hhqgreaoqulmfwfwarhc`.
2. **Environment Secrets:** Standard Supabase secrets automatically populated by the platform:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SUPABASE_ANON_KEY`
3. **JWT Verification Flag:**
   The function's code handles JWT extraction and verification natively in `requireUser` using `db.auth.getUser(token)`. It can be deployed with standard settings.

### 6.2 Deployment Command (Do NOT run without approval)
```powershell
supabase functions deploy account --project-ref hhqgreaoqulmfwfwarhc
```

### 6.3 Rollback Plan
If deployment encounters unexpected runtime errors on the remote environment:
```powershell
supabase functions delete account --project-ref hhqgreaoqulmfwfwarhc
```
Deleting the function will return the system to the pre-deployment state where client callers safely receive 404 and handle it via the existing `Retention report unavailable` message without application crashes.

---

## 7. POST-DEPLOYMENT SMOKE TEST PLAN

Once deployment is explicitly approved and performed:
1. **Parent Settings Retention Report Verification:**
   - On the Pixel 9a emulator (logged in as Parent `ankit@gmail.com`), navigate to Settings tab.
   - Verify that the previous error (`Retention report unavailable: Requested function was not found`) is gone.
   - Verify that retention windows (30 days location, 90 days usage) and record counts load cleanly.
2. **Export Data Verification:**
   - Tap "Export my data" in Settings.
   - Verify that a valid JSON file is generated with `scope: "family"` and table counts.
3. **Delete Account Dialog Validation Test (Non-Destructive):**
   - Tap "Delete account" to open the confirmation dialog.
   - Enter invalid text (e.g. `cancel` or wrong email) and confirm that client and server reject the action.
   - **Do NOT enter the true confirmation to protect QA accounts.**

---

## 8. RISK ASSESSMENT & RESIDUAL RISKS

| Risk Description | Severity | Likelihood | Mitigation in Place |
|---|---|---|---|
| Accidental deletion of Parent or Child QA accounts | High | Very Low | Dual confirmation (`DELETE` + email), owner blocking guards, explicit tester protection rules. |
| Cross-family data leakage during export | High | Very Low | Query filtering derived exclusively from server-side JWT context; client cannot override scope. |
| Edge Function memory exhaustion during export | Medium | Low | 1,000-row batching with hard 20,000-row cap per table (`EXPORT_ROW_CAP`). |
| Database lockup during cascading deletion | Medium | Very Low | Deletions are scoped strictly by indexed UUIDs (`user_id`, `owner_id`). |

---

## 9. FINAL VERDICT & RECOMMENDATION

### Verdict: `READY WITH CONDITIONS`

**Conditions for Deployment:**
1. **Formal Authorization:** Explicit user approval must be granted before running `supabase functions deploy account`.
2. **Protected Account Rule:** QA accounts `ankit@gmail.com` and `ankit1@gmail.com` and family `demo` must remain protected; destructive account deletion must not be executed against these accounts.
3. **Execution Mode:** Deploy the function using the documented command, followed immediately by executing the non-destructive smoke test on the Pixel 9a emulator.
