// P5-TEST-01 — executed handler tests for `device-command`.
//
// These replace the source-text pins for this handler: the real `handler()`
// body runs against an in-memory PostgREST fake, so every assertion below is
// about an observed response, an observed row, or an observed call order — not
// about how the file is worded. Authorization and envelope behavior is pinned
// at the level the contract cares about: status, `code`, `message`, and which
// tables were touched.
//
// Run: deno test --allow-read supabase/functions/device-command/
import { assertEquals, assert } from "jsr:@std/assert";
import { handler, type HandlerDeps } from "./handler.ts";
import { recordAudit } from "../_shared/audit.ts";
import { fakePostgrest, type Row } from "../_shared/fake_postgrest.ts";

const PARENT = "11111111-1111-4111-8111-111111111111";
const CHILD = "22222222-2222-4222-8222-222222222222";
const OTHER_PARENT = "33333333-3333-4333-8333-333333333333";
const FAMILY = "44444444-4444-4444-8444-444444444444";
const OTHER_FAMILY = "55555555-5555-4555-8555-555555555555";
const DEVICE = "66666666-6666-4666-8666-666666666666";
const COMMAND = "77777777-7777-4777-8777-777777777777";
/** One fixed instant: `expires_at` is derived from the injected clock. */
const CLOCK_ISO = "2026-11-03T12:00:00.000Z";
const UUID = "88888888-8888-4888-8888-888888888888";
const TOKEN = "token-for-tests-000000000000";
/** A stored hash that no test secret matches. */
const SECRET_HASH = "a".repeat(64);

function parentUser(overrides: Row = {}): Row {
  return {
    id: PARENT,
    email: "parent@example.invalid",
    email_confirmed_at: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}

function profile(role: string, id: string = PARENT): Row {
  return { id, role, display_name: role };
}

function deviceRow(overrides: Row = {}): Row {
  return {
    id: DEVICE,
    family_id: FAMILY,
    child_user_id: CHILD,
    secret_hash: SECRET_HASH,
    status: "active",
    credential_revoked_at: null,
    display_name: "Child phone",
    policy_version: 3,
    last_seen_at: CLOCK_ISO,
    battery_level: 80,
    is_charging: false,
    enforcement_mode: "device_admin",
    ...overrides,
  };
}

/** The seeded world: one family, one parent, one active device. */
function world(): ReturnType<typeof fakePostgrest> {
  return fakePostgrest({
    profiles: [profile("parent", PARENT), profile("child", CHILD)],
    families: [{ id: FAMILY, deleted_at: null }],
    family_members: [
      { id: UUID, family_id: FAMILY, user_id: PARENT, role: "parent", status: "active" },
    ],
    devices: [deviceRow()],
    device_commands: [],
    audit_logs: [],
  }).setUser(parentUser());
}

/** A valid `request_usage` create body — the simplest accepted command. */
function createBody(overrides: Row = {}): Row {
  return {
    action: "create",
    device_id: DEVICE,
    type: "request_usage",
    payload: { days: 7 },
    idempotency_key: "k-default",
    ...overrides,
  };
}

function policyBody(overrides: Row = {}): Row {
  return {
    action: "create",
    device_id: DEVICE,
    type: "apply_policy",
    payload: { policy: { blocked_packages: ["com.example.game"] } },
    idempotency_key: "k-policy",
    ...overrides,
  };
}

function depsFor(fake: ReturnType<typeof fakePostgrest>): HandlerDeps {
  return {
    db: fake.asDb(),
    audit: recordAudit,
    now: () => new Date(CLOCK_ISO),
    uuid: () => UUID,
  };
}

async function call(
  fake: ReturnType<typeof fakePostgrest>,
  body: unknown,
  options: { token?: string | null; method?: string; headers?: Row } = {},
): Promise<{ status: number; json: Row }> {
  const method = options.method ?? "POST";
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (options.token !== null) headers.authorization = `Bearer ${options.token ?? TOKEN}`;
  for (const [name, value] of Object.entries(options.headers ?? {})) {
    headers[name] = String(value);
  }
  const res = await handler(
    new Request("http://localhost/device-command", {
      method,
      headers,
      // GET/HEAD requests cannot carry a body at all.
      ...(method === "GET" || method === "HEAD" ? {} : { body: JSON.stringify(body) }),
    }),
    depsFor(fake),
  );
  return { status: res.status, json: (await res.json()) as Row };
}

function errorOf(json: Row): Row {
  const error = json.error as Row;
  assert(error && typeof error === "object", `response has no error object: ${JSON.stringify(json)}`);
  return error;
}

/** The envelope every failure in this codebase uses: {ok:false,error:{code,message}}. */
function assertEnvelope(json: Row, code: string, message: string): void {
  assertEquals(json.ok, false, "error responses carry ok:false");
  assertEquals(errorOf(json).code, code, "error code");
  assertEquals(errorOf(json).message, message, "caller-facing message");
}

function verbs(fake: ReturnType<typeof fakePostgrest>, table: string): string[] {
  return fake.callsFor(table).map((record) => String(record.verb));
}

function writes(fake: ReturnType<typeof fakePostgrest>, table: string): number {
  return verbs(fake, table).filter((verb) => verb === "insert").length;
}

// ---------------------------------------------------------------------------
// Envelope
// ---------------------------------------------------------------------------

Deno.test("device-command: a GET is 405 method_not_allowed and touches no table", async () => {
  const fake = world();
  const res = await call(fake, { action: "create" }, { method: "GET" });
  assertEquals(res.status, 405);
  assertEnvelope(res.json, "method_not_allowed", "Use POST.");
  assertEquals(fake.log.length, 0, "the request must be rejected before any database read");
});

Deno.test("device-command: an unknown action is 400 unknown_action", async () => {
  const fake = world();
  const res = await call(fake, { action: "teleport" });
  assertEquals(res.status, 400);
  assertEnvelope(res.json, "unknown_action", "Unsupported action.");
});

Deno.test("device-command: a missing bearer token is 401 unauthorized, before any profile read", async () => {
  const fake = world();
  const res = await call(fake, createBody({ idempotency_key: "k1" }), { token: null });
  assertEquals(res.status, 401);
  assertEnvelope(res.json, "unauthorized", "Sign in to continue.");
  assertEquals(fake.callsFor("profiles").length, 0, "no profile lookup may happen unauthenticated");
  assertEquals(writes(fake, "device_commands"), 0, "nothing is written");
});

Deno.test("device-command: an invalidated session is 401 with the session message", async () => {
  const fake = world().setUserError({ code: "invalid_jwt", message: "token has expired" });
  const res = await call(fake, createBody());
  assertEquals(res.status, 401);
  assertEnvelope(res.json, "unauthorized", "Your session is not valid. Sign in again.");
});

Deno.test("device-command: a missing profile row is 403 profile_missing", async () => {
  const fake = world();
  fake.rows.profiles = [];
  const res = await call(fake, createBody());
  assertEquals(res.status, 403);
  assertEnvelope(
    res.json,
    "profile_missing",
    "The account profile is not ready yet. Try again shortly.",
  );
});

// ---------------------------------------------------------------------------
// Authorization
// ---------------------------------------------------------------------------

Deno.test("device-command: a child profile cannot create a command (403 role_required)", async () => {
  const fake = world();
  fake.setUser(parentUser({ id: CHILD }));
  fake.rows.profiles = [profile("child", CHILD)];
  const res = await call(fake, createBody({ idempotency_key: "k-child" }));
  assertEquals(res.status, 403);
  assertEnvelope(res.json, "role_required", "A parent account is required for this action.");
  assertEquals(writes(fake, "device_commands"), 0, "a refused role must not reach the write");
});

Deno.test("device-command: an unverified email is 403 email_not_verified on create", async () => {
  const fake = world().setUser(parentUser({ email_confirmed_at: null }));
  const res = await call(fake, createBody({ idempotency_key: "k-unverified" }));
  assertEquals(res.status, 403);
  assertEnvelope(res.json, "email_not_verified", "Confirm your email address before continuing.");
});

Deno.test("device-command: a parent of another family cannot command this device, and nothing is written", async () => {
  const fake = fakePostgrest({
    profiles: [profile("parent", OTHER_PARENT)],
    families: [{ id: FAMILY, deleted_at: null }],
    // The caller is a parent — but of a DIFFERENT family.
    family_members: [
      { id: UUID, family_id: OTHER_FAMILY, user_id: OTHER_PARENT, role: "parent", status: "active" },
    ],
    devices: [deviceRow()],
    device_commands: [],
    audit_logs: [],
  }).setUser(parentUser({ id: OTHER_PARENT }));
  const res = await call(fake, createBody({ idempotency_key: "k-cross" }));
  assertEquals(res.status, 403);
  assertEnvelope(res.json, "forbidden", "A parent in this family is required.");
  assertEquals(writes(fake, "device_commands"), 0);
  assertEquals(fake.rows.device_commands.length, 0, "no command row may exist");
  assertEquals(fake.rows.audit_logs.length, 0, "no audit row for a refused action");
});

Deno.test("device-command: a soft-deleted family is forbidden before the membership read", async () => {
  const fake = world();
  fake.rows.families = [{ id: FAMILY, deleted_at: CLOCK_ISO }];
  const res = await call(fake, createBody({ idempotency_key: "k-deleted-family" }));
  assertEquals(res.status, 403);
  assertEnvelope(res.json, "forbidden", "You do not have access to this family.");
});

Deno.test("device-command: an unknown device is 404 device_not_found", async () => {
  const fake = world();
  fake.rows.devices = [];
  const res = await call(fake, createBody({ idempotency_key: "k-no-device" }));
  assertEquals(res.status, 404);
  assertEnvelope(res.json, "device_not_found", "The device was not found.");
});

Deno.test("device-command: a non-active device is 403 device_not_active", async () => {
  const fake = world();
  fake.rows.devices = [deviceRow({ status: "removed" })];
  const res = await call(fake, createBody({ idempotency_key: "k-inactive" }));
  assertEquals(res.status, 403);
  assertEnvelope(res.json, "device_not_active", "The device is not active.");
});

// ---------------------------------------------------------------------------
// Happy path + the injected seams
// ---------------------------------------------------------------------------

Deno.test("device-command: create writes the command from the injected clock and audits it", async () => {
  const fake = world();
  const res = await call(fake, createBody({ idempotency_key: "k-happy" }));
  assertEquals(res.status, 200, `create failed: ${JSON.stringify(res.json)}\n${fake.trace()}`);
  assertEquals(res.json.ok, true);
  const command = (res.json.data as Row).command as Row;
  assertEquals(command.device_id, DEVICE);
  assertEquals(command.family_id, FAMILY);
  assertEquals(command.type, "request_usage");
  assertEquals(command.status, "pending");
  // ttl_seconds is absent, so the documented default of 300 s applies to the
  // injected clock — proof the clock seam is what produced the timestamp.
  assertEquals(command.expires_at, "2026-11-03T12:05:00.000Z", "expires_at = injected now + default ttl");

  const audits = fake.rows.audit_logs;
  assertEquals(audits.length, 1, "one command_created audit row");
  assertEquals(audits[0].event_type, "command_created");
  assertEquals(audits[0].actor_user_id, PARENT, "the actor is the verified JWT subject");
  assertEquals(audits[0].device_id, DEVICE);

  // Order: the device/authorization reads precede the insert, and the insert
  // precedes the audit — asserted on the observed call trace, not on source text.
  const trace = fake.trace();
  const devicesAt = trace.indexOf("devices select");
  const insertAt = trace.indexOf("device_commands insert");
  const auditAt = trace.indexOf("audit_logs insert");
  assert(devicesAt !== -1 && insertAt !== -1 && auditAt !== -1, `unexpected trace: ${trace}`);
  assert(devicesAt < insertAt, "the device/authorization read must precede the write");
  assert(insertAt < auditAt, "the audit row follows the stored command");
});

Deno.test("device-command: an explicit ttl is clamped to the documented 60..900 range", async () => {
  for (const [requested, expectedSeconds] of [[5000, 900], [1, 60], [600, 600]] as const) {
    const fake = world();
    const res = await call(
      fake,
      createBody({ type: "request_location", payload: {}, idempotency_key: `k-ttl-${requested}`, ttl_seconds: requested }),
    );
    assertEquals(res.status, 200, `ttl ${requested} must be accepted, not rejected: ${JSON.stringify(res.json)}`);
    const command = (res.json.data as Row).command as Row;
    const expected = new Date(new Date(CLOCK_ISO).getTime() + expectedSeconds * 1000).toISOString();
    assertEquals(command.expires_at, expected, `ttl ${requested} -> ${expectedSeconds}s`);
  }
});

Deno.test("device-command: a repeated idempotency key replays the stored command and writes nothing", async () => {
  const fake = world();
  fake.rows.device_commands = [{
    id: COMMAND,
    device_id: DEVICE,
    family_id: FAMILY,
    type: "request_usage",
    payload: { days: 7 },
    status: "pending",
    idempotency_key: "k-replay",
    created_at: CLOCK_ISO,
    expires_at: "2026-11-03T12:05:00.000Z",
    delivered_at: null,
    acked_at: null,
    result: null,
    error_message: null,
    attempts: 0,
  }];
  const res = await call(fake, createBody({ idempotency_key: "k-replay" }));
  assertEquals(res.status, 200, JSON.stringify(res.json));
  assertEquals(((res.json.data as Row).command as Row).id, COMMAND, "the existing row is returned");
  assertEquals(writes(fake, "device_commands"), 0, "no second insert");
  assertEquals(fake.rows.audit_logs.length, 0, "a replay is not re-audited as a new command");
});

Deno.test("device-command: an invalid payload is 400 validation_error before any write", async () => {
  const fake = world();
  const res = await call(fake, createBody({ payload: { not_a_field: 1 }, idempotency_key: "k-bad" }));
  assertEquals(res.status, 400);
  assertEquals(errorOf(res.json).code, "validation_error");
  assertEquals(fake.rows.device_commands.length, 0);
});

Deno.test("device-command: a non-UUID device id is refused before any database read", async () => {
  const fake = world();
  const res = await call(fake, createBody({ device_id: "not-a-uuid", idempotency_key: "k-badid" }));
  assertEquals(res.status, 400);
  assertEquals(errorOf(res.json).code, "validation_error");
  assertEquals(fake.callsFor("devices").length, 0, "an invalid id must not be looked up");
});

// ---------------------------------------------------------------------------
// apply_policy — the RPC + mapper path, executed
// ---------------------------------------------------------------------------

Deno.test("device-command: an apply_policy RPC denial maps to forbidden/403 and inserts no command", async () => {
  const fake = world();
  fake.setRpc("apply_policy_version", () => ({
    error: { code: "42501", message: "not_family_parent", details: "" },
  }));
  const res = await call(fake, policyBody({ idempotency_key: "k-policy-denied" }));
  assertEquals(res.status, 403, `SQL-03: a raised 42501 is a permission answer, never a 5xx: ${JSON.stringify(res.json)}`);
  assertEnvelope(res.json, "forbidden", "You do not have permission to perform this action.");
  assertEquals(fake.rows.device_commands.length, 0);
  assertEquals(fake.rows.audit_logs.length, 0);
});

Deno.test("device-command: apply_policy audits policy_updated + command_created, and an idempotent replay audits nothing", async () => {
  const policyRow = { id: UUID, version: 4, device_id: DEVICE };
  const commandRow = { id: COMMAND, device_id: DEVICE, status: "pending" };
  const fake = world();
  fake.setRpc("apply_policy_version", () => ({
    data: { policy: policyRow, command: commandRow, idempotent: false },
  }));
  const res = await call(fake, policyBody({ idempotency_key: "k-policy-2" }));
  assertEquals(res.status, 200, JSON.stringify(res.json));
  assertEquals(((res.json.data as Row).command as Row).id, COMMAND);
  assertEquals(fake.auditEvents(), ["policy_updated", "command_created"], "both audit rows, in order");
  assertEquals(
    fake.rows.audit_logs[0].actor_user_id,
    PARENT,
    "the ledger names the verified caller",
  );

  // A replay reported as idempotent may not re-audit.
  const replayFake = world();
  replayFake.setRpc("apply_policy_version", () => ({
    data: { policy: policyRow, command: commandRow, idempotent: true },
  }));
  const replay = await call(replayFake, policyBody({ idempotency_key: "k-policy-2" }));
  assertEquals(replay.status, 200);
  assertEquals(replayFake.auditEvents(), [], "an idempotent replay writes no audit row");
});

Deno.test("device-command: an unknown apply_policy RPC answer is a 500, never a fabricated success", async () => {
  const fake = world();
  fake.setRpc("apply_policy_version", () => ({ data: { policy: null, command: {} } }));
  const res = await call(fake, policyBody({ idempotency_key: "k-policy-3" }));
  assertEquals(res.status, 500);
  assertEnvelope(res.json, "internal_error", "The policy could not be saved.");
  assertEquals(fake.auditEvents(), [], "a failed policy is not audited as saved");
});

// ---------------------------------------------------------------------------
// Failure attribution — what the handler does when the ledger write fails
// ---------------------------------------------------------------------------

Deno.test("device-command: a failed audit insert is a 500 audit_failed, not a silent success", async () => {
  const fake = world();
  fake.failOn({
    table: "audit_logs",
    verb: "insert",
    error: { code: "23505", message: "duplicate key value", details: "" },
  });
  const res = await call(fake, createBody({ idempotency_key: "k-audit-fails" }));
  assertEquals(res.status, 500);
  assertEnvelope(res.json, "audit_failed", "The action could not be recorded in the audit log.");
  // Recorded honestly: unlike the SQL-05 zone path, the command row and its
  // audit row are still two separate transactions here, so the command IS
  // stored while the caller sees a failure. This test pins the observable
  // behaviour as it stands; closing the window is a separate owner decision.
  assertEquals(fake.rows.device_commands.length, 1, "the command row survives the failed audit");
});

Deno.test("device-command: a database insert failure is 500 internal_error with a fixed message", async () => {
  const fake = world();
  fake.failOn({
    table: "device_commands",
    verb: "insert",
    error: {
      code: "XX000",
      message: "connection terminated unexpectedly",
      details: "secret internal text",
    },
  });
  const res = await call(fake, createBody({ idempotency_key: "k-insert-fails" }));
  assertEquals(res.status, 500);
  assertEnvelope(res.json, "internal_error", "The command could not be queued.");
  assert(
    !JSON.stringify(res.json).includes("connection terminated"),
    "database text must never reach the caller",
  );
});

// ---------------------------------------------------------------------------
// poll — the device-side credential path
// ---------------------------------------------------------------------------

Deno.test("device-command: poll without device credentials is refused and runs no RPC", async () => {
  const fake = world();
  const res = await call(fake, { action: "poll" });
  assertEquals(res.status, 401);
  assertEnvelope(res.json, "device_auth_required", "Device credentials are required.");
  assertEquals(
    fake.log.filter((record) => record.kind === "rpc").length,
    0,
    "the poll RPC must not be reached without device credentials",
  );
});

Deno.test("device-command: poll with the wrong secret is refused and runs no RPC", async () => {
  const fake = world();
  const res = await call(fake, { action: "poll" }, {
    headers: { "x-device-id": DEVICE, "x-device-secret": "wrong-secret-value-000000" },
  });
  assertEquals(res.status, 401);
  assertEnvelope(res.json, "invalid_device_credentials", "Device credentials are not valid.");
  assertEquals(
    fake.log.filter((record) => record.kind === "rpc").length,
    0,
    "a wrong secret must not reach poll_device_commands",
  );
});

Deno.test("device-command: poll answers from the RPC and stamps the injected clock", async () => {
  const fake = world();
  // secret_hash is the sha256 of the secret below, matching requireDevice.
  const secret = "device-secret-for-tests-0000";
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secret));
  const hex = Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
  fake.rows.devices = [deviceRow({ secret_hash: hex })];
  fake.setRpc("poll_device_commands", () => [{ id: COMMAND, type: "request_usage", status: "pending" }]);
  const res = await call(fake, { action: "poll" }, {
    headers: { "x-device-id": DEVICE, "x-device-secret": secret },
  });
  assertEquals(res.status, 200, JSON.stringify(res.json));
  const data = res.json.data as Row;
  assertEquals((data.commands as Row[]).length, 1);
  assertEquals(data.server_time, CLOCK_ISO, "server_time comes from the injected clock");
});
