// deletion_test.ts — Phase 3.3 Account Deletion Retry Lockout Remediation Test Suite
//
// Tests all 15 required security and failure scenarios against `fakePostgrest`.
// Covers:
// 1. Normal Parent deletion with existing profile.
// 2. Child deletion with existing profile.
// 3. Missing profile + valid deletion retry.
// 4. Missing profile + non-delete action.
// 5. Invalid JWT.
// 6. Invalid confirmation.
// 7. Incorrect caller email.
// 8. Auth deletion failure after profile deletion.
// 9. Successful retry after partial failure.
// 10. Duplicate retry.
// 11. Concurrent duplicate requests.
// 12. Active child/device deletion blocker.
// 13. Cross-user deletion attempt.
// 14. Audit event correctness.
// 15. Existing account export behavior.

import { assertEquals, assert } from "jsr:@std/assert";
import { fakePostgrest, type Row } from "../../../../../supabase/functions/_shared/fake_postgrest.ts";
import { handleAccountRequest, type DeletionResult } from "./deletion.ts";

const PARENT_ID = "11111111-1111-4111-8111-111111111111";
const PARENT_EMAIL = "parent@example.com";
const OTHER_USER_ID = "22222222-2222-4222-8222-222222222222";
const OTHER_USER_EMAIL = "other@example.com";
const CHILD_ID = "33333333-3333-4333-8333-333333333333";
const CHILD_EMAIL = "child@example.com";
const FAMILY_ID = "44444444-4444-4444-8444-444444444444";
const DEVICE_ID = "55555555-5555-4555-8555-555555555555";
const TOKEN = "valid-test-bearer-token-123456789012";

interface ApiEnvelope<T = unknown> {
  ok: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
}

async function parseEnvelope<T = unknown>(res: Response): Promise<ApiEnvelope<T>> {
  return (await res.json()) as ApiEnvelope<T>;
}

function mockParentUser(id = PARENT_ID, email = PARENT_EMAIL): Row {
  return {
    id,
    email,
    email_confirmed_at: "2026-01-01T00:00:00.000Z",
  };
}

function mockChildUser(id = CHILD_ID, email = CHILD_EMAIL): Row {
  return {
    id,
    email,
    email_confirmed_at: "2026-01-01T00:00:00.000Z",
  };
}

function mockProfile(id: string, role: "parent" | "child", displayName = "Test"): Row {
  return {
    id,
    role,
    display_name: displayName,
    created_at: "2026-01-01T00:00:00.000Z",
    updated_at: "2026-01-01T00:00:00.000Z",
  };
}

function makeRequest(
  body: Record<string, unknown>,
  token: string | null = TOKEN,
): Request {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (token !== null) {
    headers["Authorization"] = `Bearer ${token}`;
  }
  return new Request("http://localhost/account", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

function setupBaseWorld(options: {
  includeProfile?: boolean;
  role?: "parent" | "child";
  userId?: string;
  userEmail?: string;
  hasOtherMember?: boolean;
  hasActiveDevice?: boolean;
} = {}): ReturnType<typeof fakePostgrest> {
  const userId = options.userId ?? PARENT_ID;
  const userEmail = options.userEmail ?? PARENT_EMAIL;
  const role = options.role ?? "parent";
  const includeProfile = options.includeProfile ?? true;

  const profiles: Row[] = [];
  if (includeProfile) {
    profiles.push(mockProfile(userId, role));
  }

  const families: Row[] = [
    {
      id: FAMILY_ID,
      name: "Test Family",
      owner_id: userId,
      settings: null,
      created_at: "2026-01-01T00:00:00.000Z",
      deleted_at: null,
    },
  ];

  const familyMembers: Row[] = [
    {
      id: "m-1111",
      family_id: FAMILY_ID,
      user_id: userId,
      role,
      status: "active",
    },
  ];

  if (options.hasOtherMember) {
    profiles.push(mockProfile(OTHER_USER_ID, "parent", "Other Parent"));
    familyMembers.push({
      id: "m-2222",
      family_id: FAMILY_ID,
      user_id: OTHER_USER_ID,
      role: "parent",
      status: "active",
    });
  }

  const devices: Row[] = [];
  if (options.hasActiveDevice) {
    devices.push({
      id: DEVICE_ID,
      family_id: FAMILY_ID,
      child_user_id: CHILD_ID,
      display_name: "Child Phone",
      status: "active",
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
    });
  }

  return fakePostgrest({
    profiles,
    families,
    family_members: familyMembers,
    devices,
    location_events: [],
    usage_daily: [],
    safety_alerts: [],
    audit_logs: [],
  }).setUser(mockParentUser(userId, userEmail));
}

// -----------------------------------------------------------------------------
// Test 1: Normal Parent deletion with existing profile
// -----------------------------------------------------------------------------
Deno.test("Test 1: Normal Parent deletion with existing profile", async () => {
  const fake = setupBaseWorld();
  const req = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  });

  const res = await handleAccountRequest(req, { db: fake.asClient() });
  assertEquals(res.status, 200);
  const envelope = await parseEnvelope<DeletionResult>(res);
  assertEquals(envelope.ok, true);
  assertEquals(envelope.data?.deleted, true);
  assertEquals(envelope.data?.retry, false);
  assertEquals(envelope.data?.memberships_removed, 1);
  assertEquals(envelope.data?.families_removed, 1);

  // Profile and family should be removed
  assertEquals(fake.rowsOf("profiles").length, 0);
  assertEquals(fake.rowsOf("families").length, 0);
  assertEquals(fake.rowsOf("family_members").length, 0);

  // Audit trail must contain account_deleted
  const events = fake.auditEvents();
  assert(events.includes("account_deleted"));
});

// -----------------------------------------------------------------------------
// Test 2: Child deletion with existing profile
// -----------------------------------------------------------------------------
Deno.test("Test 2: Child deletion with existing profile", async () => {
  const fake = fakePostgrest({
    profiles: [mockProfile(CHILD_ID, "child", "Child User")],
    families: [
      {
        id: FAMILY_ID,
        name: "Family",
        owner_id: PARENT_ID, // Parent owns family
        settings: null,
        created_at: "2026-01-01T00:00:00.000Z",
        deleted_at: null,
      },
    ],
    family_members: [
      {
        id: "m-child",
        family_id: FAMILY_ID,
        user_id: CHILD_ID,
        role: "child",
        status: "active",
      },
    ],
    devices: [],
    audit_logs: [],
  }).setUser(mockChildUser(CHILD_ID, CHILD_EMAIL));

  const req = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: CHILD_EMAIL,
  });

  const res = await handleAccountRequest(req, { db: fake.asClient() });
  assertEquals(res.status, 200);
  const envelope = await parseEnvelope<DeletionResult>(res);
  assertEquals(envelope.ok, true);
  assertEquals(envelope.data?.deleted, true);
  assertEquals(envelope.data?.memberships_removed, 1);
  assertEquals(envelope.data?.families_removed, 0); // Child did not own the family

  // Child profile removed, family persists
  assertEquals(fake.rowsOf("profiles").length, 0);
  assertEquals(fake.rowsOf("families").length, 1);
  assert(fake.auditEvents().includes("account_deleted"));
});

// -----------------------------------------------------------------------------
// Test 3: Missing profile + valid deletion retry
// -----------------------------------------------------------------------------
Deno.test("Test 3: Missing profile + valid deletion retry", async () => {
  // Simulate profile already deleted from previous partial attempt
  const fake = setupBaseWorld({ includeProfile: false });

  const req = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  });

  const res = await handleAccountRequest(req, { db: fake.asClient() });
  // Crucial: Must be 200 OK, NOT 403 profile_missing!
  assertEquals(res.status, 200);
  const envelope = await parseEnvelope<DeletionResult>(res);
  assertEquals(envelope.ok, true);
  assertEquals(envelope.data?.deleted, true);
  assertEquals(envelope.data?.retry, true);

  // Completed audit log must be stamped
  assert(fake.auditEvents().includes("account_deleted"));
});

// -----------------------------------------------------------------------------
// Test 4: Missing profile + non-delete action
// -----------------------------------------------------------------------------
Deno.test("Test 4: Missing profile + non-delete action", async () => {
  const fake = setupBaseWorld({ includeProfile: false });

  // 4a. Export with missing profile
  const exportReq = makeRequest({ action: "export" });
  const exportRes = await handleAccountRequest(exportReq, { db: fake.asClient() });
  assertEquals(exportRes.status, 403);
  const exportEnvelope = await parseEnvelope(exportRes);
  assertEquals(exportEnvelope.ok, false);
  assertEquals(exportEnvelope.error?.code, "profile_missing");

  // 4b. Retention report with missing profile
  const retentionReq = makeRequest({ action: "retention_report" });
  const retentionRes = await handleAccountRequest(retentionReq, { db: fake.asClient() });
  assertEquals(retentionRes.status, 403);
  const retentionEnvelope = await parseEnvelope(retentionRes);
  assertEquals(retentionEnvelope.ok, false);
  assertEquals(retentionEnvelope.error?.code, "profile_missing");
});

// -----------------------------------------------------------------------------
// Test 5: Invalid JWT
// -----------------------------------------------------------------------------
Deno.test("Test 5: Invalid JWT", async () => {
  const fake = setupBaseWorld();

  // 5a. Missing token
  const noTokenReq = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  }, null);
  const res1 = await handleAccountRequest(noTokenReq, { db: fake.asClient() });
  assertEquals(res1.status, 401);
  const envelope1 = await parseEnvelope(res1);
  assertEquals(envelope1.ok, false);
  assertEquals(envelope1.error?.code, "unauthorized");

  // 5b. Short / invalid bearer token
  const badTokenReq = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  }, "short");
  const res2 = await handleAccountRequest(badTokenReq, { db: fake.asClient() });
  assertEquals(res2.status, 401);

  // 5c. Auth service rejects token
  fake.setUserError({ message: "Invalid JWT signature", code: "bad_jwt" });
  const rejectedTokenReq = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  });
  const res3 = await handleAccountRequest(rejectedTokenReq, { db: fake.asClient() });
  assertEquals(res3.status, 401);
});

// -----------------------------------------------------------------------------
// Test 6: Invalid confirmation
// -----------------------------------------------------------------------------
Deno.test("Test 6: Invalid confirmation", async () => {
  const fake = setupBaseWorld();

  const req = makeRequest({
    action: "delete_account",
    confirm: "delete", // lowercase - invalid
    email: PARENT_EMAIL,
  });

  const res = await handleAccountRequest(req, { db: fake.asClient() });
  assertEquals(res.status, 400);
  const envelope = await parseEnvelope(res);
  assertEquals(envelope.ok, false);
  assertEquals(envelope.error?.code, "confirmation_required");

  // Zero mutations occurred
  assertEquals(fake.rowsOf("profiles").length, 1);
});

// -----------------------------------------------------------------------------
// Test 7: Incorrect caller email
// -----------------------------------------------------------------------------
Deno.test("Test 7: Incorrect caller email", async () => {
  const fake = setupBaseWorld();

  const req = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: "wrong.parent@example.com",
  });

  const res = await handleAccountRequest(req, { db: fake.asClient() });
  assertEquals(res.status, 400);
  const envelope = await parseEnvelope(res);
  assertEquals(envelope.ok, false);
  assertEquals(envelope.error?.code, "email_mismatch");

  // Zero mutations occurred
  assertEquals(fake.rowsOf("profiles").length, 1);
});

// -----------------------------------------------------------------------------
// Test 8: Auth deletion failure after profile deletion
// -----------------------------------------------------------------------------
Deno.test("Test 8: Auth deletion failure after profile deletion", async () => {
  const fake = setupBaseWorld();
  fake.setAdminError({ message: "GoTrue connection timeout", code: "gotrue_timeout" });

  const req = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  });

  const res = await handleAccountRequest(req, { db: fake.asClient() });
  assertEquals(res.status, 500);
  const envelope = await parseEnvelope(res);
  assertEquals(envelope.ok, false);
  assertEquals(envelope.error?.code, "account_delete_incomplete");

  // Profile was removed before auth failure
  assertEquals(fake.rowsOf("profiles").length, 0);

  // Invariant 8: Audit events must NOT falsely claim successful deletion!
  const events = fake.auditEvents();
  assert(!events.includes("account_deleted"));
  assert(events.includes("account_deletion_failed"));
});

// -----------------------------------------------------------------------------
// Test 9: Successful retry after partial failure
// -----------------------------------------------------------------------------
Deno.test("Test 9: Successful retry after partial failure", async () => {
  const fake = setupBaseWorld();
  // 1. First attempt fails at Auth deletion
  fake.setAdminError({ message: "GoTrue connection timeout", code: "gotrue_timeout" });
  const req1 = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  });
  const res1 = await handleAccountRequest(req1, { db: fake.asClient() });
  assertEquals(res1.status, 500);

  // Profile is now gone
  assertEquals(fake.rowsOf("profiles").length, 0);

  // 2. Second attempt (retry) after GoTrue recovers
  fake.setAdminError(null);
  const req2 = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  });
  const res2 = await handleAccountRequest(req2, { db: fake.asClient() });
  assertEquals(res2.status, 200);
  const envelope = await parseEnvelope<DeletionResult>(res2);
  assertEquals(envelope.ok, true);
  assertEquals(envelope.data?.deleted, true);
  assertEquals(envelope.data?.retry, true);

  // Final account_deleted audit log is now recorded
  assert(fake.auditEvents().includes("account_deleted"));
});

// -----------------------------------------------------------------------------
// Test 10: Duplicate retry
// -----------------------------------------------------------------------------
Deno.test("Test 10: Duplicate retry", async () => {
  const fake = setupBaseWorld();

  // First call succeeds
  const req1 = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  });
  const res1 = await handleAccountRequest(req1, { db: fake.asClient() });
  assertEquals(res1.status, 200);

  // Immediate duplicate call with same token: auth user is already gone from GoTrue
  const req2 = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  });
  const res2 = await handleAccountRequest(req2, { db: fake.asClient() });
  // Since auth user was deleted in attempt 1, fake getUser returns user_not_found -> 401 unauthorized
  assertEquals(res2.status, 401);
});

// -----------------------------------------------------------------------------
// Test 11: Concurrent duplicate requests
// -----------------------------------------------------------------------------
Deno.test("Test 11: Concurrent duplicate requests", async () => {
  const fake = setupBaseWorld();

  const req1 = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  });
  const req2 = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  });

  const [res1, res2] = await Promise.all([
    handleAccountRequest(req1, { db: fake.asClient() }),
    handleAccountRequest(req2, { db: fake.asClient() }),
  ]);

  // Both requests must complete cleanly without 500 server error
  assert(res1.status === 200 || res1.status === 401);
  assert(res2.status === 200 || res2.status === 401);
  // At least one was 200
  assert(res1.status === 200 || res2.status === 200);
  // Database state is cleanly purged
  assertEquals(fake.rowsOf("profiles").length, 0);
});

// -----------------------------------------------------------------------------
// Test 12: Active child/device deletion blocker
// -----------------------------------------------------------------------------
Deno.test("Test 12: Active child/device deletion blocker", async () => {
  // Family has active device and active other member
  const fake = setupBaseWorld({ hasOtherMember: true, hasActiveDevice: true });

  const req = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  });

  const res = await handleAccountRequest(req, { db: fake.asClient() });
  assertEquals(res.status, 409);
  const envelope = await parseEnvelope(res);
  assertEquals(envelope.ok, false);
  assertEquals(envelope.error?.code, "account_deletion_blocked");
  const details = envelope.error?.details as Record<string, unknown>;
  assertEquals(details?.blocked_reason, "owned_family_has_other_members");

  // Zero deletions executed
  assertEquals(fake.rowsOf("profiles").length, 2);
  assertEquals(fake.rowsOf("families").length, 1);
  assertEquals(fake.rowsOf("devices").length, 1);
  assert(!fake.auditEvents().includes("account_deleted"));
});

// -----------------------------------------------------------------------------
// Test 13: Cross-user deletion attempt
// -----------------------------------------------------------------------------
Deno.test("Test 13: Cross-user deletion attempt", async () => {
  const fake = setupBaseWorld({ hasOtherMember: true });

  // Caller is PARENT_ID, but body maliciously targets OTHER_USER_ID with other's email
  const req1 = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: OTHER_USER_EMAIL,
    user_id: OTHER_USER_ID,
  });

  const res1 = await handleAccountRequest(req1, { db: fake.asClient() });
  // Blocked by email mismatch with authenticated caller
  assertEquals(res1.status, 400);
  const envelope1 = await parseEnvelope(res1);
  assertEquals(envelope1.ok, false);
  assertEquals(envelope1.error?.code, "email_mismatch");

  // Other user's profile and data are untouched
  const profiles = fake.rowsOf("profiles");
  assert(profiles.some((p: any) => p.id === OTHER_USER_ID));
});

// -----------------------------------------------------------------------------
// Test 14: Audit event correctness
// -----------------------------------------------------------------------------
Deno.test("Test 14: Audit event correctness", async () => {
  const fake = setupBaseWorld();

  const req = makeRequest({
    action: "delete_account",
    confirm: "DELETE",
    email: PARENT_EMAIL,
  });

  const res = await handleAccountRequest(req, { db: fake.asClient() });
  assertEquals(res.status, 200);

  const logs = fake.rowsOf("audit_logs");
  assertEquals(logs.length, 2);

  // 1. Pre-deletion requested log
  assertEquals(logs[0].event_type, "account_deletion_requested");
  assertEquals(logs[0].target_id, PARENT_ID);
  assertEquals(logs[0].actor_user_id, PARENT_ID);

  // 2. Post-auth deleted log
  assertEquals(logs[1].event_type, "account_deleted");
  assertEquals(logs[1].target_id, PARENT_ID);
  // actor_user_id must be null because profile is already removed
  assertEquals(logs[1].actor_user_id, null);
  const metadata = logs[1].metadata as Record<string, unknown>;
  assertEquals(metadata.user_id, PARENT_ID);
  assertEquals(metadata.retry, false);
});

// -----------------------------------------------------------------------------
// Test 15: Existing account export behavior
// -----------------------------------------------------------------------------
Deno.test("Test 15: Existing account export behavior", async () => {
  const fake = setupBaseWorld();

  const req = makeRequest({ action: "export" });
  const res = await handleAccountRequest(req, { db: fake.asClient() });
  assertEquals(res.status, 200);

  // Check export headers
  assert(res.headers.get("Content-Type")?.includes("application/json"));
  assert(res.headers.get("Content-Disposition")?.includes("attachment"));

  // Check export payload shape
  const body = (await res.json()) as Record<string, unknown>;
  assertEquals(body.scope, "family");
  assert(typeof body.generated_at === "string");
  const account = body.account as Record<string, unknown>;
  assertEquals(account.user_id, PARENT_ID);
  assertEquals(account.email, PARENT_EMAIL);
  const profile = body.profile as Record<string, unknown>;
  assertEquals(profile.role, "parent");
});
