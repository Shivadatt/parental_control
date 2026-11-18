# Phase 3.2.5 — Report 03: Account Deletion Failure, Concurrency & Retry Lockout Analysis

## 1. Executive Summary

This report delivers a critical failure-mode analysis of the account deletion workflow implemented in `supabase/functions/account/index.ts` (`deleteAccount`).

The analysis reveals an important architectural flaw:
> **Because deletion steps are independent non-atomic HTTP operations, if the final GoTrue authentication deletion (`db.auth.admin.deleteUser`) fails or times out, the user profile is already deleted. Subsequent retry attempts are rejected with `403 profile_missing` by `requireUser`, permanently stranding the account in a partially deleted state.**

---

## 2. Deletion Step Sequence & Transaction Non-Atomicity

In `supabase/functions/account/index.ts` lines 360–460, `deleteAccount` executes the following sequence:

1. **Input Validation:** `validateDeleteAccountInput` (requires confirmation `"DELETE"` and matching email).
2. **Owner Blocking Check:** `findDeletionBlocker` (blocks if other active members or devices exist).
3. **Audit Event Insertion:**
   ```ts
   await recordAudit(db, {
     familyId: ownedFamilies[0]?.id ?? familyIds[0] ?? null,
     actorUserId: userId,
     eventType: "account_deleted",
     targetType: "account",
     targetId: userId,
     metadata: { user_id: userId, memberships: memberships.length, owned_families: ownedFamilies.length },
   });
   ```
4. **Membership Deletion:**
   ```ts
   await db.from("family_members").delete().eq("user_id", userId);
   ```
5. **Empty Owned Family Deletion:**
   ```ts
   await db.from("families").delete().eq("id", family.id).eq("owner_id", userId);
   ```
6. **Profile Deletion:**
   ```ts
   await db.from("profiles").delete().eq("id", userId);
   ```
7. **Auth Record Deletion:**
   ```ts
   const authDelete = await db.auth.admin.deleteUser(userId);
   ```

### Finding ATOM-01: Independent Operations (No Single DB Transaction)
- Steps 3, 4, 5, 6, and 7 are executed as **separate, sequential HTTP REST/PostgREST requests** from the Deno runtime.
- They are **NOT** wrapped in a PostgreSQL `BEGIN ... COMMIT` block.
- A network drop, timeout, or service error at Step 7 leaves Steps 3, 4, 5, and 6 committed and un-rolled-back.

---

## 3. The `profile_missing` Retry Lockout Trap

### Step-by-Step Failure Scenario:
1. Steps 3–6 succeed: The caller's `family_members`, owned `families`, and `profiles` records are deleted.
2. Step 7 (`db.auth.admin.deleteUser`) encounters an error (e.g. GoTrue timeout, network blip, or rate limit).
3. The Edge Function throws `account_delete_incomplete` (HTTP 500):
   ```ts
   throw new ApiError(
     "account_delete_incomplete",
     "The account data was removed, but the sign-in record could not be deleted. Contact the project owner.",
     500,
   );
   ```
4. The client app receives the error and attempts an automated or user-initiated retry with the still-valid JWT.
5. **The Trap Closes at `requireUser`:**
   At the very entrypoint of the Edge Function (`supabase/functions/_shared/auth.ts:114`):
   ```ts
   const profileResult = await db.from("profiles").select("id, role, display_name").eq("id", user.id).maybeSingle();
   const row = profileResult.data as ProfileRow | null;
   if (!row) {
     throw new ApiError("profile_missing", "Your application profile could not be found. Complete onboarding.", 403);
   }
   ```
6. **Outcome:**
   - Because `profiles` was already deleted in Step 6, `requireUser` throws **`403 Forbidden` (`profile_missing`)**.
   - The execution halts *before* reaching `deleteAccount`.
   - **The user can NEVER retry deletion via the client.**
   - The user's credentials remain in `auth.users`, but any subsequent attempt to use the application throws `403 profile_missing`.

---

## 4. Concurrency & Race Condition Analysis

### What happens if concurrent duplicate delete requests arrive?
1. **Lack of Mutex / Explicit Row Locking:**
   - `deleteAccount` does not use `SELECT ... FOR UPDATE` or distributed redis/pg_locks.
2. **Race Outcome:**
   - If Request A and Request B execute simultaneously:
     - Both pass `validateDeleteAccountInput`.
     - Both execute `recordAudit`, generating **two duplicate `account_deleted` audit rows**.
     - Request A deletes `family_members`, `families`, and `profiles`.
     - Request B's delete queries execute harmlessly on 0 rows.
     - Both invoke `db.auth.admin.deleteUser(userId)`.
   - **Risk Level:** **LOW (P3)**. No data corruption occurs, but duplicate audit events are recorded.

---

## 5. Audit Trail Behavior on Cascade

- The `audit_logs` table schema defines:
  ```sql
  actor_user_id uuid references public.profiles(id) on delete set null
  ```
- When Step 6 deletes `public.profiles`, PostgreSQL automatically updates any referenced audit records to set `actor_user_id = NULL`.
- The audit record persists in `audit_logs` with `event_type = 'account_deleted'` and `metadata.user_id = '<deleted_uuid>'`, ensuring full compliance with forensic logging requirements.

---

## 6. Recommended Architecture Fix (Prior to General Availability)

To eliminate the `profile_missing` retry trap, `deleteAccount` should adopt one of two designs:
1. **Option A (Reorder Deletion):** Call `db.auth.admin.deleteUser(userId)` *first* or handle deletion in a PostgreSQL RPC triggered by auth deletion.
2. **Option B (Auth Gateway Exception):** Allow `requireUser` in `supabase/functions/account/index.ts` to proceed without a profile if the action is explicitly `"delete"`, enabling idempotent retry of `auth.admin.deleteUser`.
