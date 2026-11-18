# Phase 3.3 — Report 02: Retry-Safe Account Deletion Remediation Design

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target Function:** `account` (`supabase/functions/account/`)  
**Design Phase:** Architectural Specification & Security Invariants

---

## 1. Architectural Strategy

The remediation adopts **Option B (Auth Gateway Exception with Dedicated Deletion Seam)** as specified in Phase 3.2.5 Report 03, reinforced with strict cryptographic and operational invariants.

Rather than weakening `requireUser()` globally across the system, the authentication helper is factored into two distinct tiers:
1. `requireAuthUser(req, db)`: Validates the caller's JWT against Supabase Auth (`db.auth.getUser(token)`). It strictly verifies that the token is valid, active, and unexpired, and returns `UserIdentity { user, emailVerified, accessToken }`.
2. `requireUser(req, db, options)`: Composes over `requireAuthUser`, additionally querying `public.profiles` for `user.id`. If missing or invalid, it throws `403 profile_missing` or `403 profile_invalid`.

Every normal edge function and normal action (`export`, `retention_report`, `device-command`, etc.) continues to use `requireUser()`. 

Only `delete_account` (and its alias `delete`) is allowed to authenticate via `requireAuthUser()` and enter a two-state deletion lifecycle:
- **State A (Fresh Deletion):** `profiles` exists $\rightarrow$ Validate confirmation & email $\rightarrow$ Check blockers $\rightarrow$ Record `account_deletion_requested` $\rightarrow$ Delete memberships & owned families $\rightarrow$ Delete profile $\rightarrow$ Delete Auth user $\rightarrow$ Record `account_deleted`.
- **State B (Resumed Retry):** `profiles` is NULL $\rightarrow$ Validate confirmation & email $\rightarrow$ Defensive relational cleanup $\rightarrow$ Retry `auth.admin.deleteUser` $\rightarrow$ If successful or already not found $\rightarrow$ Record `account_deleted` (with `retry: true`).

---

## 2. Invariants Verification Matrix

| # | Security Invariant | How It Is Guaranteed by Design |
| :---: | :--- | :--- |
| **1** | **Valid JWT Caller Identification** | `requireAuthUser` extracts and validates the Bearer token using `db.auth.getUser(token)`. Caller identity is strictly taken from `user.id` and `user.email`. |
| **2** | **Explicit Deletion Action** | Only `action: "delete_account"` and `action: "delete"` are routed to `executeAccountDeletion`. All other actions call `requireUser` and fail with 403 if the profile is missing. |
| **3** | **Exact Confirmation & Email Check** | `validateDeleteAccountInput` is invoked as the first step of deletion, requiring exact case-sensitive string `"DELETE"` and matching the caller's verified JWT email. |
| **4** | **No Access to Normal Actions** | If a profile is missing, invoking `export` or `retention_report` throws `403 profile_missing`. |
| **5** | **No Cross-User Deletion** | The target deletion ID is strictly bound to `caller.user.id`. Any `user_id` or `target_id` submitted in the request body is discarded and ignored. |
| **6** | **Safely Retryable Auth Deletion** | If `auth.admin.deleteUser` times out, the user can re-invoke `delete_account`. The handler recognizes that `profiles` is already absent and resumes straight to GoTrue deletion without blocking. |
| **7** | **Deletion Blockers Enforced** | If a profile exists, `findDeletionBlocker` checks if the owner's families have other active members or active devices. If so, HTTP `409 account_deletion_blocked` is thrown before any write. |
| **8** | **Audit Trail Integrity** | Pre-deletion is recorded as `account_deletion_requested` (or `account_deletion_failed` upon failure). The completion event `account_deleted` is written **ONLY AFTER** `auth.admin.deleteUser` succeeds. |
| **9** | **Idempotent Concurrency Handling** | If duplicate requests arrive concurrently, the second request sees either `profile == null` (retry path) or `user_not_found` from GoTrue, both resolving cleanly with `{ deleted: true }`. |
| **10** | **Information Disclosure Safety** | Errors are formatted using standard `ApiError` envelopes. Internal tokens, DB connection strings, and stack traces are never exposed. |

---

## 3. Remediated Execution Flow

```mermaid
flowchart TD
    Start(["Incoming POST /account"]) --> CheckAction{"Action?"}
    
    CheckAction -->|"export" / "retention_report"| RequireUser["requireUser()"]
    RequireUser --> ProfileExists1{"Profile Exists?"}
    ProfileExists1 -->|No| Err403["Throw 403 profile_missing"]
    ProfileExists1 -->|Yes| ExecAction["Execute Action (export/retention)"]
    
    CheckAction -->|"delete_account" / "delete"| RequireAuth["requireAuthUser() (JWT Verified)"]
    RequireAuth --> ValidInput{"Input Valid? (DELETE + email)"}
    ValidInput -->|No| Err400["Throw 400 (confirmation / email mismatch)"]
    ValidInput -->|Yes| CheckProfile{"Profile Exists in DB?"}
    
    CheckProfile -->|Yes (Fresh Deletion)| CheckBlockers{"Blockers Present? (members/devices)"}
    CheckBlockers -->|Yes| Err409["Throw 409 account_deletion_blocked"]
    CheckBlockers -->|No| AuditReq["recordAudit(account_deletion_requested)"]
    AuditReq --> DeleteDB["Delete family_members, families, profiles"]
    DeleteDB --> CallAuth["auth.admin.deleteUser(user.id)"]
    
    CheckProfile -->|No (Resumed Retry)| CleanLingering["Defensive relational cleanup"]
    CleanLingering --> CallAuth
    
    CallAuth --> AuthResult{"Auth Deletion Success?"}
    AuthResult -->|Error (not 404)| AuditFail["recordAudit(account_deletion_failed)"]
    AuditFail --> Err500["Throw 500 account_delete_incomplete"]
    
    AuthResult -->|Success or 404 Not Found| AuditSuccess["recordAudit(account_deleted)"]
    AuditSuccess --> Return200["Return 200 { deleted: true, retry: isRetry }"]
```

---

## 4. Foreign Key and Audit Cascade Analysis

1. **PostgreSQL FK Constraints on `public.profiles`:**
   - `audit_logs.actor_user_id` defines `references public.profiles(id) on delete set null`.
   - When Step `DELETE FROM profiles` executes, existing audit records retain their rows, and PostgreSQL automatically updates `actor_user_id = NULL`.
2. **Audit Logging After Profile Deletion:**
   - In State B (Resumed Retry), `actorUserId` must be passed as `null` to prevent a PostgreSQL `23503 foreign_key_violation`.
   - The user's identity is permanently recorded in `target_id: userId` and `metadata: { user_id: userId, retry: true }`.
3. **Audit Truthfulness:**
   - `account_deleted` is never committed if GoTrue rejects user deletion. Forensic monitors can rely on `account_deleted` as authoritative proof of complete user eradication.
