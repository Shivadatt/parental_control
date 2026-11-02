// SQL-03 — authorization error mapping tests.
//
// Two kinds of proof, deliberately separated:
//
//   1. BEHAVIOURAL. `_shared/error_mapping.ts` is an extracted module with no
//      Deno.serve and no Supabase client, so it is imported and executed here,
//      and the ApiError it returns is fed through the real `errorResponse()` /
//      `ok()` that the handlers' catch blocks call. Status codes and wire shape
//      are therefore observed, not asserted from text.
//   2. WIRING (source-level). The four handlers are bare top-level
//      `Deno.serve(...)` with no export and build a service-role client
//      internally, so they cannot be imported and executed (see
//      handler_wiring_test.ts and phase-2-open-gaps.md TEST-01). Those tests
//      read the sources from disk and pin that each handler's RPC error branch
//      reaches the shared mapper before its generic 500, that its existing
//      mappings survive, and that no handler re-implements the rule.
//
// Run with:
//   deno test --allow-read supabase/functions/_shared/error_mapping_test.ts
// `--allow-read` is required by the wiring half; without it those tests fail
// loudly instead of skipping silently.
import { ApiError, errorResponse, ok } from "./envelope.ts";
import {
  authorizationError,
  authorizationReason,
  denyAuthorization,
  INSUFFICIENT_PRIVILEGE,
  isAuthorizationError,
  type PostgresErrorLike,
} from "./error_mapping.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
}

function assertEqual(actual: unknown, expected: unknown, message: string): void {
  if (actual !== expected) {
    throw new Error(
      `ASSERTION FAILED (${message}): expected ${JSON.stringify(expected)}, ` +
        `got ${JSON.stringify(actual)}`,
    );
  }
}

/** Collapses whitespace so assertions survive formatting changes. */
function normalize(text: string): string {
  return text.replace(/\s+/g, " ");
}

async function source(relativePath: string): Promise<string> {
  return normalize(await Deno.readTextFile(new URL(relativePath, import.meta.url)));
}

/** The body of one `case "<action>":` branch, up to the next case label. */
function caseBody(text: string, action: string): string {
  const label = `case "${action}":`;
  const start = text.indexOf(label);
  assert(start !== -1, `${label} must exist`);
  const next = text.indexOf('case "', start + label.length);
  return text.slice(start, next === -1 ? text.length : next);
}

/** The body of one `function <name>(...)`, up to the next function declaration. */
function fnBody(text: string, name: string): string {
  const label = `function ${name}(`;
  const start = text.indexOf(label);
  assert(start !== -1, `${name} must exist`);
  const next = text.indexOf("function ", start + label.length);
  return text.slice(start, next === -1 ? text.length : next);
}

/** Removes every space so the repo's tall formatting cannot decide whether a
 *  wiring assertion passes. */
function flat(text: string): string {
  return text.replace(/\s+/g, "");
}

function assertOrder(
  scope: string,
  before: string,
  after: string,
  label: string,
): void {
  const haystack = flat(scope);
  const first = haystack.indexOf(flat(before));
  const second = haystack.indexOf(flat(after));
  assert(first !== -1, `${label}: ${before} is missing`);
  assert(second !== -1, `${label}: ${after} is missing`);
  assert(first < second, `${label}: ${before} must run before ${after}`);
}

function countOf(haystack: string, needle: string): number {
  let count = 0;
  let index = haystack.indexOf(needle);
  while (index !== -1) {
    count += 1;
    index = haystack.indexOf(needle, index + needle.length);
  }
  return count;
}

/** Reads the real {ok:false,error:{code,message}} envelope off a Response. */
async function readEnvelope(response: Response) {
  const body = JSON.parse(await response.text()) as Record<string, unknown>;
  return {
    status: response.status,
    body,
    error: (body.error ?? {}) as Record<string, unknown>,
  };
}

/** The one shape every authorization answer must have, observed on the wire. */
async function assertAuthorizationResponse(
  error: unknown,
  label: string,
): Promise<Record<string, unknown>> {
  const parsed = await readEnvelope(errorResponse(error));
  assertEqual(parsed.status, 403, `${label}: status`);
  assertEqual(parsed.body.ok, false, `${label}: ok`);
  assertEqual(Object.keys(parsed.body).join(","), "ok,error", `${label}: body keys`);
  assertEqual(
    Object.keys(parsed.error).join(","),
    "code,message",
    `${label}: error keys`,
  );
  assertEqual(parsed.error.code, "forbidden", `${label}: code`);
  assert(
    typeof parsed.error.message === "string" && parsed.error.message.length > 0,
    `${label}: message must be non-empty safe text`,
  );
  return parsed.error;
}

/** The exact error PostgreSQL sends when `private.is_parent_of_family()` fails. */
const NOT_PARENT: PostgresErrorLike = {
  message: "not_family_parent",
  code: INSUFFICIENT_PRIVILEGE,
  details: "ERROR:  42501: not_family_parent\nCONTEXT: PL/pgSQL function",
};

// ---------------------------------------------------------------------------
// 1. Behavioural: the mapping itself.
// ---------------------------------------------------------------------------

Deno.test("SQL-03: not_family_parent maps to a 403 forbidden and never a 5xx", () => {
  const mapped = authorizationError(NOT_PARENT);
  assert(mapped instanceof ApiError, "must produce an ApiError");
  assertEqual(mapped.code, "forbidden", "code");
  assertEqual(mapped.status, 403, "status");
  assert(mapped.status >= 400 && mapped.status < 500, "must be a 4xx");
  assert(isAuthorizationError(NOT_PARENT), "must be recognized");
  assert(!isAuthorizationError(null), "no error is not an authorization failure");
  assert(!isAuthorizationError(undefined), "undefined is not an authorization failure");
  assertEqual(
    authorizationReason(NOT_PARENT),
    "not_family_parent",
    "reason token for the log",
  );
});

Deno.test("SQL-03: a raised 42501 with an unrecognised message is still authorization", () => {
  const mapped = authorizationError({
    message: "parent_membership_check_failed",
    code: "42501",
  });
  assert(mapped instanceof ApiError, "42501 alone is authorization-shaped");
  assertEqual(mapped.code, "forbidden", "code");
  assertEqual(mapped.status, 403, "status");
  assertEqual(
    authorizationReason({ message: "parent_check_failed", code: "42501" }),
    "unrecognised_42501",
    "the log reason must be a whitelisted token, not the message",
  );
});

Deno.test("SQL-03: the raise text maps even when the SQLSTATE is lost in transport", () => {
  for (const message of [
    "not_family_parent",
    "ERROR: 42501: not_family_parent",
    "forbidden",
    "owner_required",
    "permission denied for table devices",
    "row-level security policy for table safe_zones",
  ]) {
    const mapped = authorizationError({ message, code: "P0001" });
    assert(mapped instanceof ApiError, `${message} must map to an ApiError`);
    assertEqual(mapped.code, "forbidden", `${message}: code`);
    assertEqual(mapped.status, 403, `${message}: status`);
  }
});

Deno.test("SQL-03: non-authorization SQL errors keep their handler's own mapping", () => {
  const notAuthorization: PostgresErrorLike[] = [
    { message: "device_not_found", code: "P0002" },
    { message: "device_not_active", code: "P0001" },
    { message: "invalid_policy", code: "22023" },
    { message: "code_unavailable", code: "P0001" },
    { message: "session_in_progress", code: "P0001" },
    { message: "duplicate key value violates unique constraint", code: "23505" },
    { message: "relation does not exist", code: "42P01" },
    { message: "syntax error at or near SELECT", code: "42601" },
    { message: "", code: "" },
    {},
  ];
  for (const error of notAuthorization) {
    assert(!isAuthorizationError(error), `${error.message} must not be authorization`);
    assertEqual(authorizationError(error), null, `${error.message}: must return null`);
    assertEqual(
      authorizationReason(error),
      "not_authorization",
      `${error.message}: reason`,
    );
  }
});

Deno.test("SQL-03: integrity 42501 raises stay server faults, not caller permissions", () => {
  // 20260101000000_core.sql raises 42501 from the append-only / immutability
  // triggers. They can only fire on a service-role write, i.e. a broken deploy:
  // relabelling one a 403 would hide the fault behind a permission message.
  for (const message of [
    "audit_logs is append-only",
    "profile id is immutable",
    "profile role is immutable",
    "family owner is immutable",
  ]) {
    assert(
      !isAuthorizationError({ message, code: "42501" }),
      `${message} must not be relabelled as authorization`,
    );
    assertEqual(
      authorizationError({ message, code: "42501" }),
      null,
      `${message}: must fall through to the handler`,
    );
  }
});

Deno.test("SQL-03: nothing internal reaches the caller and only a token reaches the log", async () => {
  const leaked = [
    "not_family_parent",
    "is_parent_of_family",
    "private.",
    "public.",
    "device_policies",
    "42501",
    "P0001",
    "SECRET-TOKEN-1234",
    "check constraint",
  ];
  const nasty: PostgresErrorLike = {
    message: "not_family_parent -- SECRET-TOKEN-1234",
    code: "42501",
    details: 'unnecessary detail on "device_policies", check constraint foo',
    hint: "private.is_parent_of_family() returned false for public.devices",
  };
  const mapped = authorizationError(nasty);
  assert(mapped instanceof ApiError, "must map");
  const parsed = await readEnvelope(errorResponse(mapped));
  const wire = JSON.stringify(parsed.body);
  for (const needle of leaked) {
    assert(!wire.includes(needle), `the response body must not contain ${needle}`);
  }
  assertEqual(parsed.error.code, "forbidden", "stable machine-readable code");
  assertEqual(Object.keys(parsed.error).join(","), "code,message", "no details leak");

  const lines: string[] = [];
  const thrown = denyAuthorization(nasty, "apply_policy", (line) => lines.push(line));
  assert(thrown instanceof ApiError, "denyAuthorization returns the error to throw");
  assertEqual(lines.length, 1, "one diagnostic line");
  assertEqual(lines[0], "apply_policy_denied:42501:not_family_parent", "log line");
  assert(!lines[0].includes("SECRET-TOKEN-1234"), "no payload text in the log");
});

Deno.test("SQL-03: denyAuthorization is silent and yields for non-authorization errors", () => {
  const lines: string[] = [];
  assertEqual(
    denyAuthorization(
      { message: "device_not_found", code: "P0002" },
      "apply_policy",
      (line) => lines.push(line),
    ),
    null,
    "the handler keeps its own 404",
  );
  assertEqual(lines.length, 0, "a pass-through must not log a denial");
  assertEqual(denyAuthorization(null, "apply_policy", () => {}), null, "no error");
});

Deno.test("SQL-03: an authorization failure is never a success and never retryable", async () => {
  const mapped = authorizationError(NOT_PARENT);
  assert(mapped instanceof ApiError, "must map");
  const response = errorResponse(mapped);
  assert(!response.ok, "a denial must not be reported as a success");
  assert(response.status !== 200, "a denial must not be a 200");
  assert(response.status < 500, "a denial must not be a retryable 5xx");
  const parsed = await readEnvelope(response);
  assertEqual(parsed.body.ok, false, "envelope ok flag");
  // A real server fault must still be a 500 — the fix may not swallow those.
  assertEqual(
    errorResponse(new ApiError("internal_error", "The policy could not be saved.", 500))
      .status,
    500,
    "a genuine 500 still reports 500",
  );
  // And a successful policy write keeps the unchanged {ok:true,data} shape.
  const success = await readEnvelope(ok({ policy: { id: "p1" } }));
  assertEqual(success.status, 200, "success stays 200");
  assertEqual(success.body.ok, true, "success envelope flag");
  assertEqual(Object.keys(success.body).join(","), "ok,data", "success shape");
});

Deno.test("SQL-03: caller scenarios produce the documented statuses through the real envelope", async () => {
  // Each entry is the error the server actually produces for that caller, run
  // through the same errorResponse() the handlers' catch blocks call.
  const scenarios: [string, unknown, number, string][] = [
    // Unauthenticated: auth.ts bearerToken()/requireUser() before any SQL.
    ["unauthenticated", new ApiError("unauthorized", "Sign in to continue.", 401), 401, "unauthorized"],
    // Wrong role (a child posting a parent action): requireRole() before any SQL.
    ["child on a parent action", new ApiError("role_required", "A parent account is required for this action.", 403), 403, "role_required"],
    ["unverified email", new ApiError("email_not_verified", "Confirm your email address before continuing.", 403), 403, "email_not_verified"],
    // Wrong family caught by the Edge Function's own pre-check (auth.ts).
    ["wrong-family parent (pre-check)", new ApiError("forbidden", "A parent in this family is required.", 403), 403, "forbidden"],
    // Wrong family caught in SQL — the SQL-03 bug, previously a 500.
    ["wrong-family parent (SQL raise)", authorizationError(NOT_PARENT), 403, "forbidden"],
    // A child unlinking somebody else's membership (not_family_parent).
    ["child unlinking another child", authorizationError(NOT_PARENT), 403, "forbidden"],
    // A device-secret caller that is not the device's family is a 401, unchanged.
    ["revoked device credential", new ApiError("device_revoked", "This device credential was revoked. Link the device again.", 403), 403, "device_revoked"],
  ];
  for (const [label, error, status, code] of scenarios) {
    const parsed = await readEnvelope(errorResponse(error));
    assertEqual(parsed.status, status, `${label}: status`);
    assertEqual(parsed.error.code, code, `${label}: code`);
    assertEqual(Object.keys(parsed.body).join(","), "ok,error", `${label}: body keys`);
    assertEqual(
      Object.keys(parsed.error).join(","),
      "code,message",
      `${label}: error keys`,
    );
    assert(
      status >= 400 && status < 500,
      `${label}: must be a client error, never a retryable 5xx`,
    );
  }
});

// ---------------------------------------------------------------------------
// 2. Wiring: device-policy and device-command.
// ---------------------------------------------------------------------------

Deno.test("SQL-03: device-policy and device-command delegate the RPC denial and keep their mappings", async () => {
  const policy = await source("../device-policy/index.ts");
  const command = await source("../device-command/index.ts");

  for (const [name, text, fnName] of [
    ["device-policy", policy, "mapPolicyRpcError"],
    ["device-command", command, "mapApplyPolicyRpcError"],
  ] as const) {
    assert(
      text.includes('from "../_shared/error_mapping.ts"'),
      `${name}: must import the shared mapper`,
    );
    assertEqual(countOf(text, "denyAuthorization("), 1, `${name}: exactly one denial site`);
    const body = fnBody(text, fnName);
    assert(body.includes("denyAuthorization("), `${name}: ${fnName} must call the mapper`);
    // The denial is answered before the generic 500, not after it.
    assertOrder(body, "denyAuthorization(", '"internal_error"', `${name} ${fnName}`);
    assert(
      body.includes('"internal_error"'),
      `${name} ${fnName}: the unknown-error 500 must remain`,
    );
    // No second implementation of the rule (quoted literals only; comments may
    // name the SQL state).
    assert(
      !/["']not_family_parent["']/.test(text),
      `${name}: must not match the SQL message itself`,
    );
    assert(!/["']42501["']/.test(text), `${name}: must not test the SQLSTATE itself`);
    assert(!/["']insufficient_privilege["']/.test(text), `${name}: no inline vocabulary copy`);
  }

  // Existing mappings preserved verbatim (rule 2: nothing that worked changes).
  for (const needle of [
    '"device_not_found", "The device was not found.", 404',
    '"device_not_active", "The device is not active.", 403',
    '"invalid_policy"',
    '"invalid_idempotency_key"',
    '"device_required"',
    '"validation_error", "The policy request is not valid.", 400',
    '"unknown_action", "Unsupported action.", 400',
    '"method_not_allowed", "Use POST.", 405',
    "mapPolicyRpcError(rpc.error)",
  ]) {
    assert(policy.includes(needle), `device-policy must keep: ${needle}`);
  }
  for (const needle of [
    '"device_not_found", "The device was not found.", 404',
    '"device_not_active", "The device is not active.", 403',
    'if (inserted.error.code === "23505")',
    '"command_not_found", "The command was not found.", 404',
    '"The command expired before it was acknowledged.", 410',
    '"unknown_action", "Unsupported action.", 400',
    '"method_not_allowed", "Use POST.", 405',
    "mapApplyPolicyRpcError(applied.error)",
  ]) {
    assert(command.includes(needle), `device-command must keep: ${needle}`);
  }

  // Identity gates still run before the RPC, so a child or an anonymous caller
  // never reaches apply_policy_version at all.
  const create = caseBody(command, "create");
  assertOrder(create, "await requireUser(req, db", 'db.rpc("apply_policy_version"', "device-command create");
  assertOrder(create, 'requireRole(auth.profile, "parent")', 'db.rpc("apply_policy_version"', "device-command create");
  assertOrder(create, "requireActiveDeviceForParent(", 'db.rpc("apply_policy_version"', "device-command create");
  // device-policy is single-action — it guards with `if (action !== "update")`
  // instead of a switch — so the gate order is asserted over its serve body.
  const updateGuard = policy.indexOf('if (action !== "update")');
  assert(updateGuard !== -1, 'device-policy must keep its "update" action guard');
  const update = policy.slice(updateGuard);
  assertOrder(update, "await requireUser(req, db", 'db.rpc("apply_policy_version"', "device-policy update");
  assertOrder(update, 'requireRole(auth.profile, "parent")', 'db.rpc("apply_policy_version"', "device-policy update");
  assertOrder(update, "requireActiveDeviceForParent(", 'db.rpc("apply_policy_version"', "device-policy update");
});

// ---------------------------------------------------------------------------
// 3. Wiring: pairing.
// ---------------------------------------------------------------------------

Deno.test("SQL-03: pairing maps every RPC error branch it owns before its generic 500", async () => {
  const text = await source("../pairing/index.ts");
  assert(
    text.includes('from "../_shared/error_mapping.ts"'),
    "pairing: must import the shared mapper",
  );
  assertEqual(countOf(text, "denyAuthorization("), 4, "pairing: respond, invite, redeem, unlink");
  assert(
    !/["']not_family_parent["']/.test(text) && !/["']42501["']/.test(text),
    "pairing: no second implementation of the rule",
  );

  const respond = fnBody(text, "mapResponseRpcError");
  assertOrder(respond, "denyAuthorization(", 'new ApiError("internal_error"', "pairing respond");

  const unlink = caseBody(text, "unlink");
  assertOrder(unlink, "denyAuthorization(", 'new ApiError("internal_error"', "pairing unlink");
  const redeem = caseBody(text, "redeem");
  assertOrder(redeem, "denyAuthorization(", 'new ApiError("internal_error"', "pairing redeem");
  // code_unavailable must still win its branch first.
  assertOrder(redeem, 'includes("code_unavailable")', "denyAuthorization(", "pairing redeem");

  // Existing mappings preserved verbatim.
  for (const needle of [
    '"request_not_found", "The request was not found.", 404',
    '"forbidden", "You cannot respond to this request.", 403',
    '"code_expired", "This linking request has expired. Ask for a new code.", 410',
    '"child_already_linked", "This child account is already linked to a family.", 409',
    '"request_already_responded", "This request has already been answered.", 409',
    '"request_unavailable", "This request is no longer valid.", 409',
    '"membership_not_found", "That child is not linked to this family.", 404',
    '"forbidden", "You cannot unlink this account.", 403',
    '"code_unavailable", "This linking code was used.", 409',
    "mapResponseRpcError(rpc.error)",
  ]) {
    assert(text.includes(needle), `pairing must keep: ${needle}`);
  }

  // The child-self unlink exception and its pre-checks are unchanged.
  assert(
    unlink.includes("if (auth.user.id === childUserId)"),
    "pairing unlink must keep the child-self branch",
  );
  assertOrder(unlink, "await requireUser(req, db", 'db.rpc("unlink_child"', "pairing unlink");
  assert(
    unlink.includes('requireRole(auth.profile, "child")') &&
      unlink.includes('requireRole(auth.profile, "parent")'),
    "pairing unlink must keep both role branches",
  );
  const respondCase = caseBody(text, "respond");
  assertOrder(respondCase, 'requireRole(auth.profile, "child")', "mapResponseRpcError(", "pairing respond");
});

// ---------------------------------------------------------------------------
// 4. Cross-handler agreement, including family-admin (read-only: owned by P3-C).
// ---------------------------------------------------------------------------

Deno.test("SQL-03: all four affected handlers answer a denial with the same code and shape", async () => {
  const familyAdmin = await source("../family-admin/index.ts");
  const revoke = caseBody(familyAdmin, "revoke_device");
  const start = revoke.indexOf('if (message.includes("not_family_parent"))');
  assert(start !== -1, "family-admin must keep its not_family_parent branch");
  assert(
    flat(revoke.slice(start, start + 220)).includes(
      flat('throw new ApiError( "forbidden", "A parent in this family is required.", 403'),
    ),
    "family-admin must map the raise to forbidden/403",
  );
  assert(
    familyAdmin.includes('"device_not_found", "The device was not found.", 404'),
    "family-admin must keep device_not_found 404",
  );

  // The shared mapping and family-admin's hand-written rule agree on what the
  // client reads, observed through the real envelope.
  const shared = await assertAuthorizationResponse(authorizationError(NOT_PARENT), "shared");
  const handWritten = await assertAuthorizationResponse(
    new ApiError("forbidden", "A parent in this family is required.", 403),
    "family-admin",
  );
  assertEqual(shared.code, handWritten.code, "same code across the four handlers");
  assertEqual(
    Object.keys(shared).join(","),
    Object.keys(handWritten).join(","),
    "same shape across the four handlers",
  );

  for (const path of [
    "../family-admin/index.ts",
    "../device-policy/index.ts",
    "../device-command/index.ts",
    "../pairing/index.ts",
  ]) {
    const text = await source(path);
    assert(
      text.includes("return errorResponse(error);"),
      `${path}: a thrown ApiError must reach errorResponse`,
    );
  }
});

Deno.test("SQL-03: the caller-facing message is fixed text, never database text", () => {
  const mapped = authorizationError(NOT_PARENT);
  assert(mapped instanceof ApiError, "must map");
  assertEqual(
    mapped.message,
    "You do not have permission to perform this action.",
    "default message is fixed safe text",
  );
  const custom = authorizationError(NOT_PARENT, "A parent in this family is required.");
  assert(custom instanceof ApiError, "an override must still map");
  assertEqual(custom.code, "forbidden", "an override never changes the code");
  assertEqual(custom.status, 403, "an override never changes the status");

  // No caller-facing branch in the three wired handlers builds a message from a
  // database error object.
  for (const path of [
    "../device-policy/index.ts",
    "../device-command/index.ts",
    "../pairing/index.ts",
  ]) {
    const text = Deno.readTextFileSync(new URL(path, import.meta.url));
    assert(
      !/new ApiError\(\s*"[a-z_]+",\s*(rpc|applied|inserted|result)\.error/.test(text),
      `${path}: must not build a caller message from a database error`,
    );
    assert(
      !text.includes("error.details ??"),
      `${path}: must not echo database details to the caller`,
    );
  }
});
