# PHASE 3.1 — STAGE B: DELETE_ACCOUNT SAFETY REGRESSION REVIEW

**Project:** Parent Control App  
**Target Function:** `supabase/functions/account/` (Action: `delete_account`)  
**Execution Mode:** STRICT READ-ONLY SECURITY AUDIT  
**Audit Date:** 2026-11-18  

---

## 1. MANDATORY SAFETY STATEMENT

```
DELETE_ACCOUNT_EXECUTION = NOT PERFORMED
```

No account deletion was executed, simulated against production accounts, or tested destructively during Phase 3.1. Protected QA accounts `ankit@gmail.com` and `ankit1@gmail.com` remain 100% untouched.

---

## 2. SECURITY SCENARIO VERIFICATION TABLE

| Security Scenario | Expected Result | Source Evidence | Status |
|---|---|---|---|
| **SEC-01: Missing Confirmation** | 400 Bad Request (`confirmation_required`) | `validation.ts:47-56`: Rejects if `confirm !== "DELETE"`. | **PASS** |
| **SEC-02: Lowercase Confirmation (`"delete"`)** | 400 Bad Request (`confirmation_required`) | `validation.ts:49`: Exact case match enforced (`DELETE_CONFIRMATION = "DELETE"`). | **PASS** |
| **SEC-03: Caller Email Mismatch** | 400 Bad Request (`email_mismatch`) | `validation.ts:57-64`: Enforces `typedEmail === callerEmail` after lowercasing. | **PASS** |
| **SEC-04: Token Carrying No Email** | 409 Conflict (`email_unavailable`) | `validation.ts:39-46`: Rejects if JWT email is null or empty. | **PASS** |
| **SEC-05: Family Owner with Active Child** | 409 Conflict (`account_deletion_blocked`) | `index.ts:373-394`, `validation.ts:98-106`: Detects `otherActiveMembers > 0`. | **PASS** |
| **SEC-06: Family Owner with Active Linked Device** | 409 Conflict (`account_deletion_blocked`) | `index.ts:382-394`, `validation.ts:107-115`: Detects `activeDevices > 0`. | **PASS** |
| **SEC-07: Owner of Empty Family (0 members, 0 devices)** | 200 OK — Allowed | `index.ts:425-458`: Removes family membership, owned family, profile, and Auth user. | **PASS** |
| **SEC-08: Non-Owner Parent Deletion** | 200 OK — Allowed (Self-only) | `index.ts:360-370`: `ownedFamilies` is empty. Deletes only caller's membership & profile. Family persists. | **PASS** |
| **SEC-09: Child Account Deletion** | 200 OK — Allowed (Self-only) | `index.ts:425-447`: Deletes child membership & profile. Cascade removes child device. | **PASS** |
| **SEC-10: Cross-Family Deletion Override Attempt** | Ignored / Prevented | `index.ts:346`: Identity loaded strictly from verified JWT `auth.user.id`. Body user ID ignored. | **PASS** |
| **SEC-11: Audit Trail Immortality** | Audit entry preserved for 365 days | `index.ts:410-421`, `20260101000000_core.sql:378`: `audit_logs.actor_user_id` is `ON DELETE SET NULL`. | **PASS** |
| **SEC-12: Auth Deletion Failure (Profile Deleted)** | 500 `account_delete_incomplete` + Idempotent Retry | `index.ts:448-456`, `_shared/auth.ts:105-115`: Subsequent retry recovers via profile stub and deletes Auth record. | **PASS** |

---

## 3. DATABASE REFERENTIAL INTEGRITY RE-VERIFICATION

Direct inspection of migration `supabase/migrations/20260101000000_core.sql` confirmed the database constraints:

1. **`family_members` Foreign Key:**
   ```sql
   family_id uuid not null references public.families (id) on delete cascade,
   user_id uuid not null references public.profiles (id) on delete cascade
   ```
   *Behavior:* Deleting a profile automatically cascades to remove that user's membership rows.
2. **`families` Foreign Key:**
   ```sql
   owner_id uuid not null references public.profiles (id) on delete cascade
   ```
   *Behavior:* An owned family cascades on profile deletion, but `findDeletionBlocker` prevents this path unless all other members and devices were already removed.
3. **`devices` Foreign Key:**
   ```sql
   family_id uuid not null references public.families (id) on delete cascade,
   child_user_id uuid not null references public.profiles (id) on delete cascade
   ```
   *Behavior:* Deleting a child's profile safely cleans up their assigned device rows.
4. **`audit_logs` Foreign Key:**
   ```sql
   family_id uuid references public.families (id) on delete set null,
   actor_user_id uuid references public.profiles (id) on delete set null,
   device_id uuid references public.devices (id) on delete set null
   ```
   *Behavior:* Deleting an account or family **sets the foreign key to NULL but does NOT delete the audit log entry**. Historical audit logs survive for the standard 365-day retention lifecycle.

---

## 4. PARTIAL FAILURE & RETRY RESILIENCY AUDIT

### Step-by-Step Failure Trace
1. **Audit Recording:** `recordAudit` executes first. If it fails, the function aborts before any deletion occurs (Zero data lost).
2. **Database Cleanups:** Scoped by `user_id == caller.id`. If any database query fails, `ensureNoError` aborts execution.
3. **Auth User Deletion:** Calls `db.auth.admin.deleteUser(userId)`.
   - If Supabase Auth is temporarily unreachable, the database row is gone, but the Auth account remains.
   - When the user retries `delete_account`, `requireUser` queries `profiles`. Because the profile was already deleted, `requireUser` generates a safe fallback stub:
     ```typescript
     const profile = (profileResult.data as ProfileRow | null) ?? {
       id: user.id,
       role: "unset",
       display_name: "",
     };
     ```
   - The deletion workflow proceeds, finds 0 active memberships and 0 owned families, writes an audit record, and successfully retries `db.auth.admin.deleteUser(userId)`.
   - **Conclusion:** The deletion lifecycle is monotonically progressive, idempotent, and resilient against network blips.
