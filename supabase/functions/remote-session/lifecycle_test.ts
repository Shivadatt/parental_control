// Session lifecycle tests: the consent patch, the parent-only end predicate
// and the best-effort abandoned-session sweep. Pure logic only - no network and
// no Supabase client. Run with:
//   deno test supabase/functions/remote-session
import { ApiError } from "../_shared/envelope.ts";
import {
  ABANDONED_SWEEP_MAX_AGE,
  ABANDONED_SWEEP_RPC,
  abandonedSweepArgs,
  sweepAbandonedSessions,
  type SweepRpc,
  withAbandonedSweep,
} from "../_shared/remote_session_lifecycle.ts";
import {
  acceptPatch,
  assertParentOwner,
  declinePatch,
  endPatch,
} from "./guard.ts";

function assertEqual(actual: unknown, expected: unknown, message: string): void {
  if (actual !== expected) {
    throw new Error(
      `ASSERTION FAILED (${message}): expected ${expected}, got ${actual}`,
    );
  }
}

function assertJson(actual: unknown, expected: unknown, message: string): void {
  assertEqual(JSON.stringify(actual), JSON.stringify(expected), message);
}

const NOW = "2026-10-30T09:00:00.000Z";
const PARENT = "99999999-9999-4999-8999-999999999999";
const CHILD = "33333333-3333-4333-8333-333333333333";

interface Call {
  fn: string;
  args: Record<string, unknown>;
}

/** Minimal fake for SupabaseClient.rpc, recording order and arguments. */
function fakeRpc(
  handlers: Record<string, (args: Record<string, unknown>) => unknown>,
  calls: Call[],
): SweepRpc {
  return (fn, args) => {
    calls.push({ fn, args });
    const handler = handlers[fn];
    if (!handler) return Promise.reject(new Error(`unexpected rpc ${fn}`));
    return Promise.resolve(handler(args) as never);
  };
}

Deno.test("contract: the sweeper RPC name and arguments are stable", () => {
  assertEqual(
    ABANDONED_SWEEP_RPC,
    "expire_abandoned_sessions",
    "SQL function name",
  );
  assertEqual(ABANDONED_SWEEP_MAX_AGE, "24 hours", "default window");
  assertJson(
    abandonedSweepArgs(),
    { p_max_age: "24 hours" },
    "default call shape (public.expire_abandoned_sessions(interval))",
  );
  assertJson(
    abandonedSweepArgs("6 hours"),
    { p_max_age: "6 hours" },
    "explicit window is passed through",
  );
});

Deno.test("accept clears the pending deadline and records consent", () => {
  const patch = acceptPatch(NOW, "44444444-4444-4444-8444-444444444444");
  assertEqual(patch.status, "accepted", "status");
  assertEqual(patch.expires_at, null, "expires_at must be cleared on consent");
  assertEqual(patch.accepted_at, NOW, "accepted_at");
  assertEqual(patch.consent_recorded, true, "consent");
  assertEqual(
    Object.keys(patch).sort().join(","),
    "accepted_at,consent_recorded,expires_at,session_nonce,status",
    "no terminal fields on an accept patch",
  );
});

Deno.test("decline is terminal and keeps no deadline", () => {
  const patch = declinePatch(NOW);
  assertEqual(patch.status, "declined", "status");
  assertEqual(patch.ended_reason, "declined", "reason");
  assertEqual(patch.consent_recorded, false, "consent");
  assertEqual(
    Object.hasOwn(patch, "expires_at"),
    false,
    "a refused request must not carry a deadline",
  );
});

Deno.test("end is parent-only; the child id can never be the actor", () => {
  assertParentOwner({ parent_user_id: PARENT }, PARENT); // no throw

  let rejected = false;
  try {
    assertParentOwner({ parent_user_id: PARENT }, CHILD);
  } catch (error) {
    if (!(error instanceof ApiError)) throw error;
    rejected = true;
    assertEqual(error.code, "parent_only", "child end code");
    assertEqual(error.status, 403, "child end status");
  }
  assertEqual(rejected, true, "a child must not end the server session");

  const patch = endPatch("active", PARENT, NOW);
  assertEqual(patch.ended_by, PARENT, "ended_by is the parent actor");
  assertEqual(
    patch.ended_by === CHILD,
    false,
    "a child id never reaches ended_by",
  );
  assertEqual(patch.ended_reason, "ended_by_parent", "reason");
});

Deno.test("request proceeds when the sweep fails (dependency-injected fake)", async () => {
  const calls: Call[] = [];
  const logs: string[] = [];
  const rpc = fakeRpc({
    // The migration may not be applied yet: PostgREST answers PGRST202.
    [ABANDONED_SWEEP_RPC]: () => ({
      data: null,
      error: { code: "PGRST202", message: "Could not find the function" },
    }),
    request_remote_session: () => ({
      data: { id: "session-1" },
      error: null,
    }),
  }, calls);

  const result = await withAbandonedSweep(
    rpc,
    () =>
      rpc("request_remote_session", {
        p_device_id: "d",
        p_parent_user_id: "p",
        p_kind: "audio",
      }),
    (message) => logs.push(message),
  );

  assertEqual(calls.length, 2, "both calls happen");
  assertEqual(calls[0].fn, ABANDONED_SWEEP_RPC, "sweep runs first");
  assertJson(
    calls[0].args,
    { p_max_age: "24 hours" },
    "sweep arguments",
  );
  assertEqual(calls[1].fn, "request_remote_session", "request still runs");
  assertEqual(result.error, null, "request result is untouched");
  assertEqual(
    (result.data as { id?: string }).id,
    "session-1",
    "request payload passes through",
  );
  assertJson(
    logs,
    ["abandoned_session_sweep_failed:PGRST202"],
    "one code-only log line, no SQL message",
  );
});

Deno.test("request proceeds when the sweep throws", async () => {
  const calls: Call[] = [];
  const logs: string[] = [];
  const rpc = fakeRpc({
    [ABANDONED_SWEEP_RPC]: () => {
      throw new Error("network down");
    },
    request_remote_session: () => ({ data: { id: "session-2" }, error: null }),
  }, calls);

  const result = await withAbandonedSweep(
    rpc,
    () => rpc("request_remote_session", {}),
    (message) => logs.push(message),
  );

  assertEqual(result.error, null, "request still succeeds");
  assertEqual(calls.length, 2, "request was attempted after the throw");
  assertEqual(
    logs[0],
    "abandoned_session_sweep_failed:unknown",
    "throw is logged without its message",
  );
});

Deno.test("sweep reports the closed count and stays quiet at zero", async () => {
  const silent = () => {};
  const closed = await sweepAbandonedSessions(
    () => Promise.resolve({ data: 3, error: null }),
    silent,
  );
  assertEqual(closed, 3, "closed count");

  const quiet: string[] = [];
  const none = await sweepAbandonedSessions(
    () => Promise.resolve({ data: 0, error: null }),
    (message) => quiet.push(message),
  );
  assertEqual(none, 0, "no rows closed");
  assertJson(quiet, [], "nothing is logged when nothing was abandoned");

  const logs: string[] = [];
  await sweepAbandonedSessions(
    () => Promise.resolve({ data: 2, error: null }),
    (message) => logs.push(message),
  );
  assertJson(logs, ["abandoned_session_sweep_closed:2"], "close is logged");
});

Deno.test("an unexpected sweep payload is discarded, not trusted", async () => {
  const logs: string[] = [];
  const result = await sweepAbandonedSessions(
    () => Promise.resolve({ data: { not: "a count" }, error: null }),
    (message) => logs.push(message),
  );
  assertEqual(result, null, "unparseable result is treated as no sweep");
  assertJson(
    logs,
    ["abandoned_session_sweep_failed:invalid_result"],
    "logged as invalid",
  );
});