// Pure helper tests. Run with:
//   deno test supabase/functions/account
// No network, no Supabase credentials, no database.
import {
  DELETE_CONFIRMATION,
  findDeletionBlocker,
  normalizeEmail,
  validateDeleteAccountInput,
} from "./validation.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
}

function assertEqual(actual: unknown, expected: unknown, message: string): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error(`ASSERTION FAILED (${message}): expected ${e}, got ${a}`);
  }
}

Deno.test("normalizeEmail trims, lowercases and rejects non-strings", () => {
  assertEqual(normalizeEmail("  Parent@Example.TEST "), "parent@example.test", "normalizes");
  assertEqual(normalizeEmail(""), null, "empty");
  assertEqual(normalizeEmail(null), null, "null");
  assertEqual(normalizeEmail(42), null, "number");
});

Deno.test("delete requires the literal DELETE word", () => {
  const callerEmail = "parent@example.test";
  assertEqual(
    validateDeleteAccountInput({ confirm: "delete", email: callerEmail, callerEmail }),
    {
      code: "confirmation_required",
      message: `Type ${DELETE_CONFIRMATION} to confirm account deletion.`,
      status: 400,
    },
    "lowercase is refused",
  );
  assertEqual(
    validateDeleteAccountInput({ confirm: " DELETE ", email: callerEmail, callerEmail }),
    null,
    "surrounding whitespace is tolerated",
  );
  assertEqual(
    validateDeleteAccountInput({ confirm: "DELETE", email: callerEmail, callerEmail }),
    null,
    "exact request passes",
  );
});

Deno.test("delete requires the caller's own email, case-insensitively", () => {
  const callerEmail = "parent@example.test";
  const mismatch = validateDeleteAccountInput({
    confirm: "DELETE",
    email: "other@example.test",
    callerEmail,
  });
  assert(mismatch !== null, "mismatch refused");
  assertEqual(mismatch.code, "email_mismatch", "mismatch code");
  assertEqual(mismatch.status, 400, "mismatch status");

  assertEqual(
    validateDeleteAccountInput({
      confirm: "DELETE",
      email: "  PARENT@example.TEST ",
      callerEmail,
    }),
    null,
    "case and whitespace differences do not matter",
  );
});

Deno.test("delete refuses when the token carries no email", () => {
  const failure = validateDeleteAccountInput({
    confirm: "DELETE",
    email: "parent@example.test",
    callerEmail: null,
  });
  assert(failure !== null, "refused");
  assertEqual(failure.code, "email_unavailable", "code");
  assertEqual(failure.status, 409, "status");
});

Deno.test("owner blocker: an otherwise empty family never blocks", () => {
  assertEqual(
    findDeletionBlocker([
      { familyId: "f1", otherActiveMembers: 0, activeDevices: 0 },
    ]),
    null,
    "empty family",
  );
  assertEqual(findDeletionBlocker([]), null, "no owned families");
});

Deno.test("owner blocker: other active members block with their family ids", () => {
  const blocker = findDeletionBlocker([
    { familyId: "f1", otherActiveMembers: 0, activeDevices: 0 },
    { familyId: "f2", otherActiveMembers: 2, activeDevices: 0 },
    { familyId: "f3", otherActiveMembers: 1, activeDevices: 4 },
  ]);
  assert(blocker !== null, "blocked");
  assertEqual(blocker.blocked_reason, "owned_family_has_other_members", "reason");
  assertEqual(blocker.family_ids, ["f2", "f3"], "all offending families");
  assert(blocker.message.includes("Remove or transfer"), "actionable message");
});

Deno.test("owner blocker: active devices block when no other member remains", () => {
  const blocker = findDeletionBlocker([
    { familyId: "f1", otherActiveMembers: 0, activeDevices: 1 },
    { familyId: "f2", otherActiveMembers: 0, activeDevices: 2 },
  ]);
  assert(blocker !== null, "blocked");
  assertEqual(blocker.blocked_reason, "owned_family_has_active_devices", "reason");
  assertEqual(blocker.family_ids, ["f1", "f2"], "family ids");
  assert(blocker.message.includes("Revoke"), "actionable message");
});