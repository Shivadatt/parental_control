// Pure helper tests for the per-device remote-session guard. Run with:
//   deno test --allow-env --allow-net supabase/functions/remote-session/guard_test.ts
import { ApiError } from "../_shared/envelope.ts";
import {
  assertParentOwner,
  endPatch,
  isOpenSessionStatus,
  mapRequestRpcError,
  sessionStatePayload,
  type SessionStateRow,
} from "./guard.ts";

function assertEqual(actual: unknown, expected: unknown, message: string): void {
  if (actual !== expected) {
    throw new Error(
      `ASSERTION FAILED (${message}): expected ${expected}, got ${actual}`,
    );
  }
}

function assertMapped(
  error: ApiError,
  code: string,
  status: number,
  message: string,
): void {
  if (!(error instanceof ApiError)) {
    throw new Error(`ASSERTION FAILED (${message}): not an ApiError`);
  }
  assertEqual(error.code, code, `${message} code`);
  assertEqual(error.status, status, `${message} status`);
}

function assertApiError(
  fn: () => unknown,
  code: string,
  status: number,
  message: string,
): void {
  try {
    fn();
  } catch (error) {
    if (!(error instanceof ApiError)) {
      throw new Error(`ASSERTION FAILED (${message}): not an ApiError`);
    }
    assertEqual(error.code, code, `${message} code`);
    assertEqual(error.status, status, `${message} status`);
    return;
  }
  throw new Error(`ASSERTION FAILED (${message}): expected an ApiError`);
}

Deno.test("open statuses hold the device microphone", () => {
  assertEqual(isOpenSessionStatus("requested"), true, "requested is open");
  assertEqual(isOpenSessionStatus("accepted"), true, "accepted is open");
  assertEqual(isOpenSessionStatus("active"), true, "active is open");
});

Deno.test("terminal statuses never block a new request", () => {
  for (const status of ["ended", "declined", "expired", "failed"]) {
    assertEqual(isOpenSessionStatus(status), false, `${status} is closed`);
  }
  assertEqual(isOpenSessionStatus("garbage"), false, "unknown is closed");
  assertEqual(isOpenSessionStatus(""), false, "empty is closed");
});

Deno.test("concurrent rejection maps to 409 session_in_progress", () => {
  const error = mapRequestRpcError({ message: "session_in_progress" });
  assertEqual(error.code, "session_in_progress", "code");
  assertEqual(error.status, 409, "status");
  assertEqual(
    error.message,
    "Another assistance session is already open for this device.",
    "message",
  );
  assertEqual(
    mapRequestRpcError({ message: 'P0001: session_in_progress' }).status,
    409,
    "wrapped message still maps",
  );
  assertEqual(
    mapRequestRpcError({ details: "ERROR: session_in_progress" }).status,
    409,
    "details fallback",
  );
});

Deno.test("device and kind errors map to their documented statuses", () => {
  assertMapped(
    mapRequestRpcError({ message: "device_not_found" }),
    "device_not_found",
    404,
    "missing device",
  );
  assertMapped(
    mapRequestRpcError({ message: "device_not_active" }),
    "device_not_active",
    403,
    "inactive device",
  );
  assertMapped(
    mapRequestRpcError({ message: "invalid_kind" }),
    "invalid_kind",
    400,
    "invalid kind",
  );
});

Deno.test("unexpected SQL errors become a generic 500", () => {
  assertMapped(
    mapRequestRpcError({ message: "relation does not exist", code: "42P01" }),
    "internal_error",
    500,
    "unknown SQL error",
  );
  assertMapped(
    mapRequestRpcError({}),
    "internal_error",
    500,
    "empty error",
  );
});

const session: SessionStateRow = {
  id: "11111111-1111-4111-8111-111111111111",
  device_id: "22222222-2222-4222-8222-222222222222",
  child_user_id: "33333333-3333-4333-8333-333333333333",
  status: "active",
  expires_at: "2026-10-28T12:00:00+00:00",
};

Deno.test("session_state returns only the three safe fields", () => {
  const payload = sessionStatePayload(session, {
    id: session.device_id,
    child_user_id: session.child_user_id,
  });
  assertEqual(payload.session_id, session.id, "session id");
  assertEqual(payload.status, "active", "status");
  assertEqual(payload.expires_at, session.expires_at, "expiry");
  assertEqual(
    Object.keys(payload).sort().join(","),
    "expires_at,session_id,status",
    "no extra fields (no signals, no PII)",
  );
});

Deno.test("session_state reports terminal and expired status verbatim", () => {
  for (const status of ["ended", "expired", "failed"]) {
    const payload = sessionStatePayload(
      { ...session, status },
      { id: session.device_id, child_user_id: session.child_user_id },
    );
    assertEqual(payload.status, status, `status ${status}`);
  }
});

Deno.test("session_state reports a null expiry for a consented session", () => {
  const payload = sessionStatePayload(
    { ...session, status: "accepted", expires_at: null },
    { id: session.device_id, child_user_id: session.child_user_id },
  );
  assertEqual(payload.expires_at, null, "accepted session has no deadline");
  assertEqual(
    Object.keys(payload).sort().join(","),
    "expires_at,session_id,status",
    "shape is unchanged",
  );
});

Deno.test("only the requesting parent may end a session", () => {
  const parentId = "99999999-9999-4999-8999-999999999999";
  const owner = { parent_user_id: parentId };
  assertParentOwner(owner, parentId); // no throw
  assertApiError(
    () => assertParentOwner(owner, session.child_user_id),
    "parent_only",
    403,
    "child cannot end the server session",
  );
  assertApiError(
    () => assertParentOwner(owner, "88888888-8888-4888-8888-888888888888"),
    "parent_only",
    403,
    "unrelated user cannot end the session",
  );
});

Deno.test("end patch is server-derived and ignores caller input", () => {
  const parentId = "99999999-9999-4999-8999-999999999999";
  const at = "2026-10-28T10:00:00.000Z";
  assertEqual(
    endPatch("requested", parentId, at).ended_reason,
    "cancelled_by_parent",
    "cancelling a pending request",
  );
  for (const status of ["accepted", "active"]) {
    const patch = endPatch(status, parentId, at);
    assertEqual(patch.ended_reason, "ended_by_parent", `${status} reason`);
    assertEqual(patch.status, "ended", `${status} status`);
    assertEqual(patch.ended_by, parentId, `${status} actor`);
    assertEqual(patch.ended_at, at, `${status} timestamp`);
  }
});

Deno.test("another device or child cannot read the session", () => {
  assertApiError(
    () =>
      sessionStatePayload(session, {
        id: "44444444-4444-4444-8444-444444444444",
        child_user_id: session.child_user_id,
      }),
    "forbidden",
    403,
    "different device",
  );
  assertApiError(
    () =>
      sessionStatePayload(session, {
        id: session.device_id,
        child_user_id: "55555555-5555-4555-8555-555555555555",
      }),
    "forbidden",
    403,
    "same device row, different child",
  );
});
