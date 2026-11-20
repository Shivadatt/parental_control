# Phase 3.5 — Report 04: Authentication & Authorization Architecture Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Module:** `docs/testing/phase_3_4_3_browser_package/staging/account/shared-auth.ts`  
**Audit Date:** 2026-11-20  

---

## 1. Authentication Architecture Overview

The `account` Edge Function implements defense-in-depth authentication using cryptographically signed JSON Web Tokens (JWT) verified against Supabase Auth (GoTrue). The identity of the caller is strictly bound to the claims verified by GoTrue, completely ignoring any client-supplied `user_id` in request payloads.

```
Incoming Request
  │
  ├─► Check 'Authorization: Bearer <token>' (regex: /^Bearer\s+(\S+)$/i, length >= 20)
  │     └─► Fails? ──► 401 ApiError("unauthorized", "Sign in to continue.", 401)
  │
  ├─► Verify with GoTrue: db.auth.getUser(token)
  │     └─► Invalid/Expired? ──► 401 ApiError("unauthorized", "Your session is not valid. Sign in again.", 401)
  │
  ├─► UserIdentity Established: { user, emailVerified, accessToken }
  │
  ├─► Branching by Action Type:
        │
        ├─► [delete / delete_account]: requireAuthUser (Does NOT query profiles table)
        │     └─► Permits retry recovery even if profiles row was previously deleted
        │
        └─► [export / retention_report]: requireUser
              └─► Queries profiles where id = user.id
              └─► Missing row? ──► 403 ApiError("profile_missing", ..., 403)
              └─► Invalid role? ──► 403 ApiError("profile_invalid", ..., 403)
```

---

## 2. Decoupled Authentication Functions

### `requireAuthUser(req, db): Promise<UserIdentity>`
- **Source Location:** `shared-auth.ts` lines 84–105.
- **Responsibility:** Validates the caller's JWT directly against Supabase Auth (`db.auth.getUser(token)`).
- **Profile Independence:** This function **does not** touch the `profiles` table.
- **Critical Security Purpose:** Used exclusively by the `delete` / `delete_account` lifecycle. When a prior account deletion attempt suffers an intermittent network failure during GoTrue user deletion, the user's relational rows (including `profiles`) have already been erased. Using `requireAuthUser` allows the user to re-authenticate and complete the Auth deletion without encountering a fatal `403 profile_missing` lockout.

### `requireUser(req, db, options): Promise<AuthContext>`
- **Source Location:** `shared-auth.ts` lines 111–143.
- **Responsibility:** First calls `requireAuthUser`, then loads the caller's profile row from `profiles`.
- **Enforcement Rules:**
  - If no profile row exists: Throws `403 profile_missing` (`"The account profile is not ready yet. Try again shortly."`).
  - If `role` is not in `{"unset", "parent", "child"}`: Throws `403 profile_invalid`.
  - If `options.requireVerifiedEmail` is set and email is unconfirmed: Throws `403 email_not_verified`.
- **Target Actions:** Utilized by `export` and `retention_report` to ensure full authorization context is present.

---

## 3. Authorization Boundaries & Role Scoping

Role-based access control is evaluated at multiple tiers:

1. **Role Verification:**
   - Evaluated via `requireRole(profile, "parent" | "child")` or through pure domain logic in `resolveRetentionScope`.
   - Prevents privilege escalation: an unassigned (`unset`) or invalid role is immediately quarantined.

2. **Cross-Tenant & Cross-User Isolation:**
   - `exportAccount` strictly queries:
     - For parent: `family_members.user_id = auth.user.id`, then fetches only families where the caller has active membership.
     - For child: `devices.child_user_id = auth.user.id`, ensuring children cannot inspect sibling or parental devices.
     - Device secret hashes (`devices.secret_hash`) are explicitly omitted from the export projection `DEVICE_COLUMNS`.
   - `executeAccountDeletion` operates strictly on `caller.user.id`:
     - A user cannot delete or initiate deletion for any account other than their own authenticated identity.

3. **Multi-Tenancy Isolation:**
   - All database queries filter explicitly by `family_id` and `user_id`.
   - In instances where a family ID list is empty, queries substitute `00000000-0000-0000-0000-000000000000` (`NO_MATCH_UUID`) rather than generating unbounded or empty `in.()` queries that could default to broad table scans.

---

## 4. Protected Accounts Isolation Audit

The production database contains active administrative and testing accounts that must remain protected:
- `spg7753@gmail.com` (Owner / Admin)
- `ankit@gmail.com` (Parent QA)
- `ankit1@gmail.com` (Child QA)

**Audit Findings:**
- The `account` Edge Function contains no hardcoded bypasses, backdoors, or administrative overrides.
- No deletion or modification of these accounts is possible without presenting their respective cryptographically valid JWT tokens and typing their exact emails as affirmative confirmation.
- Phase 3.5 offline tests utilize mock identities (`auth-uuid-test`, `test@example.com`) and zero live requests were issued targeting these protected accounts.
