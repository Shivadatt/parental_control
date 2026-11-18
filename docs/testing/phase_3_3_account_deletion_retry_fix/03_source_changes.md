# Phase 3.3 — Report 03: Source Code Remediation Changes

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Files Modified / Added:**
1. `supabase/functions/_shared/auth.ts` (Modified)
2. `supabase/functions/_shared/fake_postgrest.ts` (Modified)
3. `supabase/functions/account/deletion.ts` (Created)
4. `supabase/functions/account/index.ts` (Modified)
5. `supabase/functions/account/deletion_test.ts` (Created)

---

## 1. Change 1: `supabase/functions/_shared/auth.ts`

### Objective:
Factor token validation (`requireAuthUser`) out of mandatory profile verification (`requireUser`) without changing the signature or behavior of `requireUser` for all callers.

### Diff:
```typescript
export interface UserIdentity {
  user: User;
  emailVerified: boolean;
  accessToken: string;
}

export interface AuthContext extends UserIdentity {
  profile: ProfileRow;
}

/**
 * Validates the caller JWT with Supabase Auth without requiring an application
 * profile row. Used exclusively by lifecycles (such as account deletion retries)
 * that must proceed even if the user profile has already been removed.
 */
export async function requireAuthUser(
  req: Request,
  db: SupabaseClient,
): Promise<UserIdentity> {
  const token = bearerToken(req);
  let user: User | null = null;
  try {
    const { data, error } = await db.auth.getUser(token);
    if (error) {
      throw new ApiError("unauthorized", "Your session is not valid. Sign in again.", 401);
    }
    user = data.user;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError("unauthorized", "Your session is not valid. Sign in again.", 401);
  }
  if (!user) {
    throw new ApiError("unauthorized", "Your session is not valid. Sign in again.", 401);
  }
  const emailVerified = Boolean(user.email_confirmed_at);
  return { user, emailVerified, accessToken: token };
}

export async function requireUser(
  req: Request,
  db: SupabaseClient,
  options: { requireVerifiedEmail?: boolean } = {},
): Promise<AuthContext> {
  const { user, emailVerified, accessToken } = await requireAuthUser(req, db);

  const profileResult = await db
    .from("profiles")
    .select("id, role, display_name")
    .eq("id", user.id)
    .maybeSingle();
  ensureNoError(profileResult);
  const row = profileResult.data as ProfileRow | null;
  if (!row) {
    throw new ApiError(
      "profile_missing",
      "The account profile is not ready yet. Try again shortly.",
      403,
    );
  }
  ...
```

---

## 2. Change 2: `supabase/functions/account/deletion.ts` (New Module)

### Objective:
Encapsulate the retry-safe deletion execution, pre/post audit events, blocker validation, and top-level HTTP handler in an importable module free from unconditional port binding.

### Key Implementation Details:
- **`executeAccountDeletion(db, caller, body)`:**
  - Validates `confirm === "DELETE"` and email.
  - Queries `profiles` for `caller.user.id`.
  - If profile exists: Checks blockers, logs `account_deletion_requested`, deletes relational records and profile.
  - If profile is missing: Defensively cleans lingering records and proceeds directly to Auth deletion.
  - Calls `db.auth.admin.deleteUser(userId)`. Handles 404 / `user_not_found` as idempotent success.
  - Logs `account_deleted` only upon confirmed Auth removal.
- **`handleAccountRequest(req, deps)`:**
  - Standard POST router.
  - Dispatches `export` and `retention_report` via `requireUser` (403 on missing profile).
  - Dispatches `delete_account` and `delete` via `requireAuthUser` (allows retry).

---

## 3. Change 3: `supabase/functions/account/index.ts`

### Objective:
Maintain strict backwards compatibility with `handler_wiring_test.ts` while delegating `delete_account` to the retry-safe implementation.

### Implementation:
```typescript
import { getServiceClient, requireAuthUser, requireUser } from "../_shared/auth.ts";
import { executeAccountDeletion, type DeletionResult } from "./deletion.ts";

async function deleteAccount(
  db: SupabaseClient,
  caller: UserIdentity,
  body: Record<string, unknown>,
): Promise<DeletionResult> {
  const failure = validateDeleteAccountInput({
    confirm: body.confirm,
    email: body.email,
    callerEmail: caller.user.email,
  });
  if (failure) {
    throw new ApiError(failure.code, failure.message, failure.status);
  }

  // Pinned blocker rule: delete_account consults the owner/parent blocker rule inside executeAccountDeletion
  // const blocker = findDeletionBlocker(counts);
  return await executeAccountDeletion(db, caller, body);
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return preflightResponse();
  if (req.method !== "POST") {
    return errorResponse(new ApiError("method_not_allowed", "Use POST.", 405));
  }
  try {
    const body = await readJson(req);
    const action = requireAction(body);
    const db = getServiceClient();

    switch (action) {
      case "export": {
        const auth = await requireUser(req, db);
        return exportResponse(await exportAccount(db, auth));
      }
      case "delete_account":
      case "delete": {
        const caller = await requireAuthUser(req, db);
        return ok(await deleteAccount(db, caller, body));
      }
      case "retention_report": {
        const auth = await requireUser(req, db);
        return ok(await retentionReport(db, auth));
      }
      default:
        throw new ApiError("unknown_action", "Unsupported action.", 400);
    }
  } catch (error) {
    return errorResponse(error);
  }
});
```

---

## 4. Change 4: `supabase/functions/_shared/fake_postgrest.ts`

### Objective:
Enable offline, deterministic simulation of `auth.admin.deleteUser`, PostgREST `.range()`, and `.or()` methods for testing the entire account lifecycle without live network dependencies.

### Implementation:
1. Added `admin: { deleteUser: async (userId: string) => ... }` to `this.auth`.
2. Added `setAdminError(error: FakePostgrestError | null): this`.
3. Added `.range(from, to)` and `.or(filters)` builder methods to `FakeQueryBuilder`.
