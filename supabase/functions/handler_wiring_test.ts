// Handler wiring tests.
//
// Every `index.ts` is a bare top-level `Deno.serve(...)` with no exported
// handler, and the modules it calls build a service-role client from
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY, so the handlers cannot be imported
// into a test without binding a port and faking PostgREST. These tests instead
// pin the wiring at the source site: if a refactor drops the call to the
// extracted module — or replaces it with an inline second implementation of the
// rule — the assertion fails.
//
// Run with:
//   deno test --allow-read supabase/functions/handler_wiring_test.ts
// The flag is required because the handlers are read from disk; without it the
// tests fail loudly rather than skipping silently.
function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
}

/** Collapses whitespace so assertions survive formatting changes. */
function normalize(text: string): string {
  return text.replace(/\s+/g, " ");
}

async function handler(relativePath: string): Promise<string> {
  const source = await Deno.readTextFile(
    new URL(relativePath, import.meta.url),
  );
  return normalize(source);
}

function countOccurrences(haystack: string, needle: string): number {
  let count = 0;
  let index = haystack.indexOf(needle);
  while (index !== -1) {
    count += 1;
    index = haystack.indexOf(needle, index + needle.length);
  }
  return count;
}

/**
 * The body of one `case "<action>":` branch, up to the next case label. Scoping
 * an assertion to this slice is what makes it mean something: the same
 * authorization call appears in several actions, and a whole-file `includes()`
 * cannot tell "purge checks the owner" from "update_retention checks the owner".
 */
function caseBody(source: string, action: string): string {
  const label = `case "${action}":`;
  const start = source.indexOf(label);
  assert(start !== -1, `${label} must exist`);
  const next = source.indexOf("case \"", start + label.length);
  return source.slice(start, next === -1 ? source.length : next);
}

/** Fails if `before` is not strictly earlier than `after` inside `scope`. */
function assertOrder(
  scope: string,
  before: string,
  after: string,
  label: string,
): void {
  const first = scope.indexOf(before);
  const second = scope.indexOf(after);
  assert(first !== -1, `${label}: ${before} is missing`);
  assert(second !== -1, `${label}: ${after} is missing`);
  assert(
    first < second,
    `${label}: ${before} must run before ${after}, not after it`,
  );
}

Deno.test("device-command: the ack path decides enforcement only in enforcement.ts", async () => {
  // P5-TEST-01: the served logic lives in handler.ts behind a thin Deno.serve
  // entry. Pin the decision rule where it runs, then pin that the entry point
  // actually serves it, so the split cannot strand a dead copy.
  const source = await handler("./device-command/handler.ts");
  const entry = await handler("./device-command/index.ts");

  assert(
    entry.includes('import { handler, defaultDeps } from "./handler.ts";') &&
      entry.includes("Deno.serve(") &&
      entry.includes("handler(req, defaultDeps())"),
    "index.ts must register Deno.serve over the extracted handler",
  );
  assert(
    !entry.includes("decideEnforcement("),
    "the entry point must not keep a second enforcement decision site",
  );

  assert(
    source.includes(
      'import { decideEnforcement, policyTargetsApps } from "./enforcement.ts";',
    ),
    "the handler must import the enforcement module",
  );
  assert(
    source.includes(
      "const decision = decideEnforcement({ result, ackStatus: nextStatus, targetsApps: policyTargetsApps(command.payload.policy),",
    ),
    "the policy ack must be decided by decideEnforcement with the ack counters",
  );
  // One decision site only: no inline re-derivation of the enforced verdict.
  assertEqualCount(source, "decideEnforcement(", 1, "decideEnforcement");
  assert(
    source.includes("enforcement_status: decision.status"),
    "the written enforcement status must come from the decision",
  );
  assert(
    source.includes("decision.advancePolicyVersion"),
    "policy_version may advance only on the decision's instruction",
  );
  // The verdict must be computed before anything is written from it.
  assertOrder(
    source,
    "const decision = decideEnforcement(",
    "enforcement_status: decision.status",
    "device-command ack",
  );
});

Deno.test("family-admin: zone delete and purge route through the authorization predicates", async () => {
  const source = await handler("./family-admin/index.ts");
  const zone = caseBody(source, "delete_zone");
  const purge = caseBody(source, "purge_data");

  assert(
    source.includes('import { canDeleteZone, canPurge } from "./authorization.ts";'),
    "the handler must import the authorization module",
  );
  assert(
    zone.includes('if (!canDeleteZone(auth.profile.role, membership.role === "parent"))'),
    "delete_zone itself must gate on canDeleteZone (not merely somewhere in the file)",
  );
  assert(
    zone.includes(
      'const membership = await assertFamilyParent( db, auth.user.id, zone.family_id, );',
    ),
    "delete_zone must resolve the caller's membership in the zone's own family",
  );
  // Reachability, not just presence: the gate has to precede the write.
  assertOrder(
    zone,
    "assertFamilyParent(",
    'db.rpc("delete_safe_zone_audited"',
    "delete_zone",
  );
  assertOrder(
    zone,
    "canDeleteZone(",
    'db.rpc("delete_safe_zone_audited"',
    "delete_zone",
  );
  assert(
    purge.includes(
      'if (!canPurge(auth.profile.role, family.owner_id === auth.user.id))',
    ),
    "purge_data must gate on canPurge",
  );
  assertEqualCount(
    purge,
    "assertFamilyOwner(",
    1,
    "purge_data owner assertion (the same call also guards update_retention)",
  );
  assert(
    purge.includes('const family = await assertFamilyOwner(db, auth.user.id, familyId);'),
    "purge_data must resolve the family through the owner assertion",
  );
  assertOrder(
    purge,
    "assertFamilyOwner(",
    "locationCutoffDays",
    "purge_data",
  );
  // What a non-owner actually receives: assertFamilyOwner throws first, so the
  // 403 mapping lives in _shared/auth.ts, not in the unreachable literal below
  // it inside the purge case.
  const auth = await handler("./_shared/auth.ts");
  assert(
    auth.includes('throw new ApiError( "owner_required", "Only the family owner can change this setting.", 403, );'),
    "assertFamilyOwner must answer owner_required/403",
  );
  assert(
    purge.includes('"owner_required"'),
    "the purge case keeps an owner_required response of its own (defensive duplicate)",
  );
});

Deno.test("family-admin: delete_zone sends the zone id and JWT actor to the atomic RPC", async () => {
  const source = await handler("./family-admin/index.ts");
  const zone = caseBody(source, "delete_zone");

  assert(
    source.includes('case "delete_zone":'),
    "the delete_zone action must stay reachable",
  );
  // SQL-05 replaced the two-transaction handler with one RPC call. Family
  // scoping moved inside the function, which resolves and locks the zone row
  // before it deletes (proof: supabase/tests/76_zone_delete_atomic_rpc.sql), so
  // the handler no longer has a delete statement to scope.
  assertEqualCount(
    zone,
    'db.rpc("delete_safe_zone_audited"',
    1,
    "delete_zone RPC call sites",
  );
  assert(
    zone.includes(
      'const rpc = await db.rpc("delete_safe_zone_audited", { p_zone_id: zoneId, p_actor_user_id: auth.user.id, });',
    ),
    "the RPC must be called with the validated zone id and the verified JWT subject",
  );
  assert(
    !zone.includes('.from("safe_zones") .delete('),
    "no client-side safe_zones delete may survive beside the RPC",
  );
  assertOrder(
    zone,
    "readUuid(body.zone_id, \"zone_id\")",
    'db.rpc("delete_safe_zone_audited"',
    "delete_zone",
  );
});

Deno.test("remote-session: request sweeps abandoned rows and respond uses the guard patches", async () => {
  const source = await handler("./remote-session/index.ts");

  assert(
    source.includes(
      'import { withAbandonedSweep } from "../_shared/remote_session_lifecycle.ts";',
    ),
    "the handler must import the sweeper wrapper",
  );
  assert(
    source.includes("const rpc = await withAbandonedSweep("),
    "the request path must run the abandoned sweep through the wrapper",
  );
  assert(
    source.includes("? acceptPatch(nowIso, crypto.randomUUID()) : declinePatch(nowIso);"),
    "consent must build its patch with the guard's accept/decline helpers",
  );
  // Terminal precedence: a settled session is never reopened by a late respond.
  assert(
    source.includes('if (session.status === "accepted" && accept) return ok(session);'),
    "an already-accepted session must return the existing row",
  );
  assert(
    source.includes('if (session.status !== "requested")'),
    "a terminal session must be rejected before any update",
  );
  assert(
    source.includes('.from("remote_sessions") .update(patch) .eq("id", session.id) .eq("status", "requested")'),
    "the update must keep the compare-and-set guard against a concurrent end",
  );
});

Deno.test("account: delete and retention actions use the extracted modules", async () => {
  const source = await handler("./account/index.ts");

  assert(
    source.includes('from "./validation.ts";'),
    "the handler must import the account validation module",
  );
  assert(
    source.includes('from "./retention.ts";'),
    "the handler must import the retention module",
  );
  assert(
    source.includes("const failure = validateDeleteAccountInput({"),
    "delete_account must validate confirm/email before touching any row",
  );
  assert(
    source.includes("const blocker = findDeletionBlocker(counts);"),
    "delete_account must consult the owner/parent blocker rule",
  );
  assert(
    source.includes("const windows = retentionFromSettings(family.settings);"),
    "retention_report must read each family's own windows",
  );
  assert(
    source.includes("return buildFamilyRetentionReport({"),
    "retention_report must build its rows in the retention module",
  );
  for (const action of ['case "export":', 'case "delete_account":', 'case "retention_report":']) {
    assert(source.includes(action), `the ${action} dispatch must remain wired`);
  }
});

function assertEqualCount(
  haystack: string,
  needle: string,
  expected: number,
  label: string,
): void {
  const actual = countOccurrences(haystack, needle);
  if (actual !== expected) {
    throw new Error(
      `ASSERTION FAILED (${label}): expected ${expected} occurrence(s), got ${actual}`,
    );
  }
}
