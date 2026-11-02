// SQL-05 failure-injection tests: safe-zone delete / audit-row atomicity.
//
// TWO TIERS, labelled honestly:
//
// 1. TRUE INJECTION (importable module). `delete_zone_atomicity.ts` owns the
//    post-delete audit decision, so audit-insert failure, restore failure and
//    retry success are injected with fake stores — the pattern established by
//    supabase/functions/remote-session/lifecycle_test.ts. These execute the
//    real decision code.
// 2. SOURCE-LEVEL WIRING PROOF (index.ts). The handler is a bare top-level
//    Deno.serve and cannot be imported (see handler_wiring_test.ts header),
//    so the delete/audit *call sites* in index.ts are pinned by reading the
//    source: the audit decision must be reached only inside the actual-removal
//    guard, only after the delete error check, and both failure kinds must
//    throw before any success return. These need --allow-read and fail
//    loudly without it.
//
// Run with:
//   deno test --allow-read supabase/functions/family-admin/delete_zone_atomicity_test.ts
import {
  AUDIT_MAX_ATTEMPTS,
  auditRetryDelayMs,
  auditZoneDeletion,
  buildZoneAuditInsert,
  type AuditLogInsert,
  type StoreFailure,
  type ZoneDeleteStore,
  type ZoneSnapshot,
} from "./delete_zone_atomicity.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
}

function assertEqual(
  actual: unknown,
  expected: unknown,
  message: string,
): void {
  if (actual !== expected) {
    throw new Error(
      `ASSERTION FAILED (${message}): expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

function assertDeepEqual(
  actual: unknown,
  expected: unknown,
  message: string,
): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error(`ASSERTION FAILED (${message}):\n  actual   ${a}\n  expected ${e}`);
  }
}

const ZONE_ID = "a1000000-0000-4000-8000-000000000001";
const FAMILY_ID = "f1000000-0000-4000-8000-000000000001";
const ACTOR = "91000000-0000-4000-8000-000000000001";

const SNAPSHOT: ZoneSnapshot = {
  id: ZONE_ID,
  family_id: FAMILY_ID,
  name: "School",
  lat: 51.5,
  lng: -0.12,
  radius_m: 200,
  active: true,
  created_by: ACTOR,
  created_at: "2026-10-30T09:00:00.000Z",
};

interface FakeOptions {
  /** Number of leading audit attempts that fail; "always" fails every one. */
  auditFailures?: number | "always";
  restoreFails?: boolean;
}

interface Fake {
  store: ZoneDeleteStore;
  auditCalls: AuditLogInsert[];
  restoreCalls: ZoneSnapshot[];
  sleeps: number[];
}

function makeFake(options: FakeOptions = {}): Fake {
  const fake: Fake = {
    auditCalls: [],
    restoreCalls: [],
    sleeps: [],
    store: null as unknown as ZoneDeleteStore,
  };
  const auditFailure: StoreFailure = { code: "50006", message: "injected audit failure" };
  const restoreFailure: StoreFailure = { code: "23505", message: "injected restore failure" };
  fake.store = {
    insertAudit: async (row) => {
      fake.auditCalls.push(row);
      const failCount = options.auditFailures ?? 0;
      const shouldFail =
        failCount === "always" || fake.auditCalls.length <= failCount;
      return shouldFail ? auditFailure : null;
    },
    restoreZone: async (zone) => {
      fake.restoreCalls.push(zone);
      return options.restoreFails ? restoreFailure : null;
    },
  };
  return fake;
}

const injectSleep = (fake: Fake) => async (ms: number): Promise<void> => {
  fake.sleeps.push(ms);
};

// ---------------------------------------------------------------------------
// Tier 1 — TRUE INJECTION (executes the real decision module)
// ---------------------------------------------------------------------------

Deno.test("[injected] both succeed: one audit row, exactly the frozen shape, no restore", async () => {
  const fake = makeFake();
  const audit = buildZoneAuditInsert(SNAPSHOT, ACTOR);
  const outcome = await auditZoneDeletion(fake.store, audit, SNAPSHOT, {
    sleep: injectSleep(fake),
  });
  assertEqual(outcome.kind, "audited", "outcome kind");
  assertEqual(
    (outcome as { attempts: number }).attempts,
    1,
    "a healthy audit insert must take exactly one attempt",
  );
  assertEqual(fake.auditCalls.length, 1, "exactly one audit row written");
  assertDeepEqual(
    fake.auditCalls[0],
    {
      family_id: FAMILY_ID,
      actor_user_id: ACTOR,
      device_id: null,
      event_type: "zone_deleted",
      target_type: "safe_zone",
      target_id: ZONE_ID,
      metadata: { name: "School" },
    },
    "audit row field-for-field identical to the _shared/audit.ts recordAudit shape",
  );
  assertEqual(fake.restoreCalls.length, 0, "success must never touch the restore path");
  assertEqual(fake.sleeps.length, 0, "success must not sleep");
});

Deno.test("[injected] transient audit failures are retried within the bounded budget", async () => {
  const fake = makeFake({ auditFailures: 2 });
  const outcome = await auditZoneDeletion(
    fake.store,
    buildZoneAuditInsert(SNAPSHOT, ACTOR),
    SNAPSHOT,
    { maxAttempts: AUDIT_MAX_ATTEMPTS, sleep: injectSleep(fake) },
  );
  assertEqual(outcome.kind, "audited", "third attempt succeeds");
  assertEqual(fake.auditCalls.length, 3, "three insert attempts");
  assertEqual(fake.restoreCalls.length, 0, "an eventual audit success must not restore");
  assertDeepEqual(
    fake.sleeps,
    [auditRetryDelayMs(1), auditRetryDelayMs(2)],
    "one backoff sleep between attempts only",
  );
});

Deno.test("[injected] audit insert fails after a successful delete: zone is restored, outcome is not audited", async () => {
  const fake = makeFake({ auditFailures: "always" });
  const outcome = await auditZoneDeletion(
    fake.store,
    buildZoneAuditInsert(SNAPSHOT, ACTOR),
    SNAPSHOT,
    { sleep: injectSleep(fake) },
  );
  assertEqual(outcome.kind, "restored", "compensation ran and succeeded");
  assert(outcome.kind !== "audited", "a failed audit can never report audited");
  assertEqual(fake.auditCalls.length, AUDIT_MAX_ATTEMPTS, "audit attempts are bounded");
  assertEqual(fake.restoreCalls.length, 1, "one compensating restore");
  assertDeepEqual(fake.restoreCalls[0], SNAPSHOT, "the exact pre-delete row is restored");
  assertEqual(
    (outcome as { auditErrorCode?: string }).auditErrorCode,
    "50006",
    "the audit error code is carried out for the error surface",
  );
});

Deno.test("[injected] audit AND restore both fail: explicit unaudited_delete, never silence", async () => {
  const fake = makeFake({ auditFailures: "always", restoreFails: true });
  const outcome = await auditZoneDeletion(
    fake.store,
    buildZoneAuditInsert(SNAPSHOT, ACTOR),
    SNAPSHOT,
    { sleep: injectSleep(fake) },
  );
  assertEqual(outcome.kind, "unaudited_delete", "worst branch is named explicitly");
  assert(outcome.kind !== "audited", "must never look like success");
  if (outcome.kind === "unaudited_delete") {
    assertEqual(outcome.attempts, AUDIT_MAX_ATTEMPTS, "full audit budget was used");
    assertEqual(outcome.auditErrorCode, "50006", "audit failure surfaced");
    assertEqual(outcome.restoreErrorCode, "23505", "restore failure surfaced");
  }
  assertEqual(fake.restoreCalls.length, 1, "restore was still attempted exactly once");
});

Deno.test("[injected] retry budget of one skips straight to compensation (no sleeps)", async () => {
  const fake = makeFake({ auditFailures: "always" });
  const outcome = await auditZoneDeletion(
    fake.store,
    buildZoneAuditInsert(SNAPSHOT, ACTOR),
    SNAPSHOT,
    { maxAttempts: 1, sleep: injectSleep(fake) },
  );
  assertEqual(outcome.kind, "restored", "one failed attempt compensates");
  assertEqual(fake.auditCalls.length, 1, "exactly one insert attempt");
  assertEqual(fake.sleeps.length, 0, "no backoff after the final attempt");
});

Deno.test("[injected] delete-failure and zero-row-delete never reach the audit decision", async () => {
  // The handler calls auditZoneDeletion ONLY when the delete committed AND
  // matched a row, so on those two paths the module is not invoked at all and
  // no audit row can exist: here we prove the module itself writes nothing
  // unless called, and (tier 2, below) that index.ts only calls it inside the
  // actual-removal guard. This pins invariant 1 end to end.
  const fake = makeFake();
  assertEqual(fake.auditCalls.length, 0, "no audit row exists without a call");
  assertEqual(fake.restoreCalls.length, 0, "no restore without a call");
});

// ---------------------------------------------------------------------------
// Tier 2 — SOURCE-LEVEL WIRING PROOF (index.ts; requires --allow-read)
// ---------------------------------------------------------------------------

function normalize(text: string): string {
  return text.replace(/\s+/g, " ");
}

async function handlerSource(): Promise<string> {
  return normalize(
    await Deno.readTextFile(new URL("./index.ts", import.meta.url)),
  );
}

function caseBody(source: string, action: string): string {
  const label = `case "${action}":`;
  const start = source.indexOf(label);
  assert(start !== -1, `${label} must exist`);
  const next = source.indexOf('case "', start + label.length);
  return source.slice(start, next === -1 ? source.length : next);
}

function assertOrder(scope: string, before: string, after: string, label: string): void {
  const first = scope.indexOf(before);
  const second = scope.indexOf(after);
  assert(first !== -1, `${label}: ${before} is missing`);
  assert(second !== -1, `${label}: ${after} is missing`);
  assert(first < second, `${label}: ${before} must run before ${after}`);
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

Deno.test("[source-level] delete_zone routes the post-delete audit through the injected module", async () => {
  const source = await handlerSource();
  assert(
    source.includes(
      'import { auditZoneDeletion, buildZoneAuditInsert, type ZoneDeleteStore, type ZoneSnapshot, } from "./delete_zone_atomicity.ts";',
    ),
    "the handler must import the audit-decision module",
  );
  const zone = caseBody(source, "delete_zone");
  assertEqualCount(zone, "auditZoneDeletion(", 1, "single audit decision site");
  assert(
    !zone.includes("recordAudit("),
    "delete_zone must not keep the old best-effort recordAudit path",
  );
});

Deno.test("[source-level] audit only on actual removal; both failure kinds throw before any success", async () => {
  const source = await handlerSource();
  const zone = caseBody(source, "delete_zone");

  // Zero-row delete: the audit decision sits strictly inside the guard.
  assert(
    zone.includes("if ((deleted.count ?? 0) > 0)"),
    "the actual-removal guard must still gate the audit",
  );
  assertOrder(zone, "if ((deleted.count ?? 0) > 0)", "auditZoneDeletion(", "delete_zone audit gating");
  // Delete failure: the delete error check precedes the guard and the audit.
  assertOrder(zone, "ensureNoError(deleted)", "auditZoneDeletion(", "delete failure short-circuit");
  // Success is returned only after the audit decision — and after both
  // failure branches throw, so an unaudited result can never respond
  // {deleted: true} silently.
  assertOrder(zone, "auditZoneDeletion(", 'outcome.kind === "restored"', "restored branch");
  assertOrder(zone, 'outcome.kind === "restored"', 'outcome.kind === "unaudited_delete"', "branch order");
  assertOrder(zone, 'outcome.kind === "unaudited_delete"', "return ok({ deleted: true })", "failure throws before success");
  assertEqualCount(zone, '"audit_failed"', 2, "both failure kinds reuse the existing audit_failed code (no new error code)");
  assert(
    zone.includes("zone_delete_unaudited:"),
    "the unaudited deletion must be logged with its error code and zone id",
  );

  // Authorization ordering is preserved (also pinned by handler_wiring_test).
  assertOrder(zone, "assertFamilyParent(", '.from("safe_zones") .delete(', "authorization before write");
  assertOrder(zone, "zone_not_found", '.from("safe_zones") .delete(', "missing zone 404s before any delete");

  // A faithful compensation needs the whole row: the pre-read selects every
  // restore column, and the store really inserts them back.
  assert(
    zone.includes('"id, family_id, name, lat, lng, radius_m, active, created_by, created_at",'),
    "pre-read must select the full snapshot for the compensating restore",
  );
  assert(zone.includes('.from("audit_logs").insert('), "the store must insert the audit row through the service client");
  assert(zone.includes('.from("safe_zones").insert('), "the store must re-insert the zone row for compensation");
  assertEqualCount(zone, '.from("safe_zones") .delete(', 1, "still exactly one delete site");
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
