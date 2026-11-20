// PRIV-01 (Option A) scope tests for the `account` retention/export payloads.
//
// Run with:
//   deno test --allow-read supabase/functions/account
// (the flag is only needed by retention_scope_wiring_test.ts; these cases are
// pure and touch no network, no Supabase credentials and no database.)
//
// The handler itself cannot be imported yet — every `index.ts` is a bare
// top-level `Deno.serve(...)` that builds a service-role client from the
// environment — so the scope rule lives in retention.ts as pure functions and
// is exercised caller-by-caller here. retention_scope_wiring_test.ts pins that
// index.ts actually consults them.
import {
  buildFamilyRetentionReport,
  buildRetentionReportPayload,
  NOT_REPORTED_SCOPE,
  resolveRetentionScope,
  retentionCountFilter,
  type RetentionScopeFacts,
  type SweepMarkerRow,
} from "./retention.ts";

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

const OWNER = "11111111-1111-1111-1111-111111111111";
const PARENT = "22222222-2222-2222-2222-222222222222";
const CHILD = "33333333-3333-3333-3333-333333333333";
const STRANGER = "44444444-4444-4444-4444-444444444444";
const FAMILY = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
const OTHER_FAMILY = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
const DEVICE_1 = "cccccccc-cccc-cccc-cccc-cccccccccccc";
const DEVICE_2 = "dddddddd-dddd-dddd-dddd-dddddddddddd";

/** A family whose `owner_id` is `owner`, plus the caller's membership rows. */
function facts(input: {
  callerUserId: unknown;
  profileRole: unknown;
  ownerId?: string;
  membershipRole?: unknown;
  familyId?: string;
  reportedFamily?: boolean;
}): RetentionScopeFacts {
  const familyId = input.familyId ?? FAMILY;
  return {
    callerUserId: input.callerUserId,
    profileRole: input.profileRole,
    memberships: input.membershipRole === undefined
      ? []
      : [{ family_id: familyId, role: input.membershipRole }],
    // `reportedFamily: false` models a family the caller is a member of but that
    // is not in the report (soft-deleted / row gone).
    families: input.reportedFamily === false
      ? []
      : [{ id: familyId, owner_id: input.ownerId ?? OWNER }],
  };
}

const SWEEP_METADATA = {
  swept_at: "2026-10-30T03:00:00.000Z",
  webrtc_signals: 900,
  audit_logs: 400,
  location_events: 5000,
  usage_daily: 600,
};

const SWEEP_ROW: SweepMarkerRow = {
  created_at: "2026-10-30T03:00:00.000Z",
  metadata: SWEEP_METADATA,
};

function report(familyId: string, location: number, usage: number) {
  return buildFamilyRetentionReport({
    familyId,
    name: "Our family",
    settings: { location_retention_days: 14, usage_retention_days: 60 },
    locationEventsOlder: location,
    usageDaysOlder: usage,
    now: new Date("2026-10-30T00:00:00.000Z"),
  });
}

// ---------------------------------------------------------------------------
// The caller-by-caller decision.
// ---------------------------------------------------------------------------

Deno.test("scope: a parent who owns the family gets family scope with sweep totals", () => {
  const decision = resolveRetentionScope(
    facts({ callerUserId: OWNER, profileRole: "parent", ownerId: OWNER, membershipRole: "parent" }),
  );
  assertEqual(decision.scope, "family", "family scope");
  assertEqual(decision.includeSweepTotals, true, "the owner sees the sweep totals");
  assertEqual(decision.readsSweepMarker, true, "the marker row is read");
});

Deno.test("scope: a non-owner parent member gets family counts but the sweep totals redacted", () => {
  const decision = resolveRetentionScope(
    facts({ callerUserId: PARENT, profileRole: "parent", ownerId: OWNER, membershipRole: "parent" }),
  );
  assertEqual(decision.scope, "family", "still family scope");
  assertEqual(decision.includeSweepTotals, false, "mirrors canPurge: owner-only totals");
  assertEqual(decision.readsSweepMarker, true, "the sweep timestamp still renders");
});

Deno.test("scope: a child member gets device scope and never the sweep marker", () => {
  const decision = resolveRetentionScope(
    facts({ callerUserId: CHILD, profileRole: "child", ownerId: OWNER, membershipRole: "child" }),
  );
  assertEqual(decision.scope, "device", "device scope");
  assertEqual(decision.includeSweepTotals, false, "no sweep totals");
  assertEqual(decision.readsSweepMarker, false, "no sweep marker read at all");
});

Deno.test("scope: a wrong-family caller is not_reported and reaches no family branch", () => {
  // Authenticated, has a profile, but is a member of a different family: the
  // report is built from the caller's own memberships, so the foreign family is
  // simply not there and nothing can be counted for it.
  const decision = resolveRetentionScope({
    callerUserId: STRANGER,
    profileRole: "parent",
    memberships: [{ family_id: OTHER_FAMILY, role: "parent" }],
    families: [{ id: FAMILY, owner_id: OWNER }],
  });
  assertEqual(decision.scope, NOT_REPORTED_SCOPE, "no membership in the reported family");
  assertEqual(decision.includeSweepTotals, false, "no sweep totals");
  assertEqual(decision.readsSweepMarker, false, "no sweep marker read");
  // Belt and braces: even the family id the caller does belong to yields no
  // query once the scope is not_reported.
  const filter = retentionCountFilter({
    scope: decision.scope,
    familyId: OTHER_FAMILY,
    deviceIds: [DEVICE_1],
  });
  assertEqual(filter.run, false, "not_reported runs no count query");
});

Deno.test("scope: an unauthenticated / profile-less caller is not_reported", () => {
  // `requireUser` rejects before the action runs, so the decision must have no
  // way to fall back to a family read: no user id, or no facts at all.
  assertEqual(resolveRetentionScope(null).scope, NOT_REPORTED_SCOPE, "null facts");
  assertEqual(resolveRetentionScope(undefined).scope, NOT_REPORTED_SCOPE, "undefined facts");
  assertEqual(resolveRetentionScope({}).scope, NOT_REPORTED_SCOPE, "empty facts");
  assertEqual(
    resolveRetentionScope(
      facts({ callerUserId: "", profileRole: "parent", membershipRole: "parent" }),
    ).scope,
    NOT_REPORTED_SCOPE,
    "empty caller id",
  );
  assertEqual(
    resolveRetentionScope(
      facts({ callerUserId: null, profileRole: "parent", membershipRole: "parent" }),
    ).scope,
    NOT_REPORTED_SCOPE,
    "null caller id",
  );
});

Deno.test("scope: a missing or unexpected profile role is not_reported with no counts", () => {
  for (
    const role of [undefined, null, "", "  ", "unset", "owner", "admin", "parent member", 42, true, {}, []]
  ) {
    const decision = resolveRetentionScope(
      facts({
        callerUserId: OWNER,
        profileRole: role,
        ownerId: OWNER,
        membershipRole: "parent",
      }),
    );
    assertEqual(
      decision.scope,
      NOT_REPORTED_SCOPE,
      `role ${JSON.stringify(role)} must not be reported`,
    );
    assertEqual(decision.includeSweepTotals, false, `role ${JSON.stringify(role)} sweep totals`);
    assertEqual(decision.readsSweepMarker, false, `role ${JSON.stringify(role)} marker read`);
    // Even with a family row and device ids in hand, no query is authorised.
    assertEqual(
      retentionCountFilter({ scope: decision.scope, familyId: FAMILY, deviceIds: [DEVICE_1] }).run,
      false,
      `role ${JSON.stringify(role)} must count nothing`,
    );
  }
});

Deno.test("scope: a profile role that disagrees with the membership is not_reported", () => {
  // A parent profile whose only membership is a child row.
  assertEqual(
    resolveRetentionScope(
      facts({ callerUserId: PARENT, profileRole: "parent", membershipRole: "child" }),
    ).scope,
    NOT_REPORTED_SCOPE,
    "parent profile, child membership",
  );
  // A child profile that happens to be listed as a parent member.
  assertEqual(
    resolveRetentionScope(
      facts({ callerUserId: CHILD, profileRole: "child", membershipRole: "parent" }),
    ).scope,
    NOT_REPORTED_SCOPE,
    "child profile, parent membership",
  );
  // A child profile that owns the family row must never get the family branch.
  const childOwner = resolveRetentionScope(
    facts({ callerUserId: CHILD, profileRole: "child", ownerId: CHILD, membershipRole: "child" }),
  );
  assertEqual(childOwner.scope, "device", "a child owner stays device-scoped");
  assertEqual(childOwner.includeSweepTotals, false, "and still sees no sweep totals");
});

Deno.test("scope: membership in an unreported family cannot widen the scope", () => {
  const decision = resolveRetentionScope(
    facts({
      callerUserId: PARENT,
      profileRole: "parent",
      membershipRole: "parent",
      reportedFamily: false,
    }),
  );
  assertEqual(decision.scope, NOT_REPORTED_SCOPE, "no family row -> nothing to report");
  assertEqual(decision.readsSweepMarker, false, "and no sweep marker read");
});

// ---------------------------------------------------------------------------
// The count filter a scope authorises.
// ---------------------------------------------------------------------------

Deno.test("counts: family scope counts the family, device scope only the caller's devices", () => {
  assertEqual(
    retentionCountFilter({ scope: "family", familyId: FAMILY, deviceIds: [] }),
    { run: true, family_id: FAMILY, device_ids: null },
    "family scope carries no device filter",
  );
  assertEqual(
    retentionCountFilter({ scope: "device", familyId: FAMILY, deviceIds: [DEVICE_1, DEVICE_2] }),
    { run: true, family_id: FAMILY, device_ids: [DEVICE_1, DEVICE_2] },
    "device scope keeps both ids and stays inside the family",
  );
});

Deno.test("counts: a child with no devices of their own runs no query", () => {
  const filter = retentionCountFilter({ scope: "device", familyId: FAMILY, deviceIds: [] });
  assertEqual(filter.run, false, "an empty device list must not become an unfiltered read");
  assertEqual(filter.device_ids, [], "and stays empty rather than null");
});

Deno.test("counts: bogus device ids are dropped and duplicates collapsed", () => {
  const filter = retentionCountFilter({
    scope: "device",
    familyId: FAMILY,
    deviceIds: [DEVICE_1, DEVICE_1, "", "   ", "  " + DEVICE_2 + " "] as string[],
  });
  assertEqual(filter.run, true, "still runs");
  assertEqual(
    filter.device_ids,
    [DEVICE_1, DEVICE_2],
    "deduplicated and trimmed, whitespace-only ids dropped",
  );
  const allBogus = retentionCountFilter({
    scope: "device",
    familyId: FAMILY,
    deviceIds: ["", " "] as string[],
  });
  assertEqual(allBogus.run, false, "no usable id means no query");
});

// ---------------------------------------------------------------------------
// The payload redaction.
// ---------------------------------------------------------------------------

Deno.test("payload: the family owner alone receives the project-wide sweep totals", () => {
  const owner = buildRetentionReportPayload({
    now: new Date("2026-10-30T00:00:00.000Z"),
    decision: resolveRetentionScope(
      facts({ callerUserId: OWNER, profileRole: "parent", ownerId: OWNER, membershipRole: "parent" }),
    ),
    reports: [report(FAMILY, 7, 3)],
    lastSweep: SWEEP_ROW,
  });
  assertEqual(owner.scope, "family", "scope token");
  assertEqual(owner.last_sweep, SWEEP_METADATA, "owner sees the sweep totals");
  assertEqual(owner.last_sweep_at, SWEEP_ROW.created_at, "and the timestamp");
  assertEqual((owner.families as unknown[]).length, 1, "the family rows are reported");
});

Deno.test("payload: a non-owner parent keeps the timestamp but loses the totals", () => {
  const payload = buildRetentionReportPayload({
    now: new Date("2026-10-30T00:00:00.000Z"),
    decision: resolveRetentionScope(
      facts({ callerUserId: PARENT, profileRole: "parent", ownerId: OWNER, membershipRole: "parent" }),
    ),
    reports: [report(FAMILY, 7, 3)],
    lastSweep: SWEEP_ROW,
  });
  assertEqual(payload.scope, "family", "family counts");
  assertEqual(payload.last_sweep, null, "sweep totals redacted");
  assertEqual(payload.last_sweep_at, SWEEP_ROW.created_at, "global marker timestamp stays");
  assert(
    JSON.stringify(payload).includes(String(SWEEP_METADATA.location_events)) === false,
    "no project-wide total leaks anywhere in the payload",
  );
});

Deno.test("payload: a child report has device counts and no sweep at all", () => {
  const payload = buildRetentionReportPayload({
    now: new Date("2026-10-30T00:00:00.000Z"),
    decision: resolveRetentionScope(
      facts({ callerUserId: CHILD, profileRole: "child", ownerId: OWNER, membershipRole: "child" }),
    ),
    reports: [report(FAMILY, 2, 1)],
    lastSweep: SWEEP_ROW,
  });
  assertEqual(payload.scope, "device", "device scope");
  assertEqual(payload.last_sweep, null, "sweep totals absent for a child");
  assertEqual(payload.last_sweep_at, null, "and the sweep timestamp too");
  const rows = payload.families as Array<Record<string, unknown>>;
  assertEqual(rows.length, 1, "the child's own family row is reported");
  assertEqual(rows[0].location_events_older_than_window, 2, "device-scoped location count");
  assertEqual(rows[0].usage_days_older_than_window, 1, "device-scoped usage count");
  assertEqual(
    rows[0].location_events_older_than_window !== SWEEP_METADATA.location_events,
    true,
    "the family-wide sweep total is not reused as the child's count",
  );
});

Deno.test("payload: not_reported carries no counts, no families and no sweep", () => {
  const payload = buildRetentionReportPayload({
    now: new Date("2026-10-30T00:00:00.000Z"),
    decision: resolveRetentionScope(
      facts({ callerUserId: OWNER, profileRole: "unset", ownerId: OWNER, membershipRole: "parent" }),
    ),
    reports: [report(FAMILY, 7, 3)],
    lastSweep: SWEEP_ROW,
  });
  assertEqual(payload.scope, NOT_REPORTED_SCOPE, "not_reported token");
  assertEqual(payload.families, [], "no family rows even though reports was filled");
  assertEqual(payload.last_sweep, null, "no sweep totals");
  assertEqual(payload.last_sweep_at, null, "no sweep timestamp");
  const encoded = JSON.stringify(payload);
  assertEqual(encoded.includes(String(SWEEP_METADATA.location_events)), false, "no project total");
  assertEqual(encoded.includes(String(SWEEP_METADATA.audit_logs)), false, "no audit total");
  assertEqual(encoded.includes(String(SWEEP_METADATA.swept_at)), false, "no sweep timestamp");
});

Deno.test("payload: the documented defaults are reported whatever the scope", () => {
  for (const role of ["parent", "child", "unset"]) {
    const payload = buildRetentionReportPayload({
      now: new Date("2026-10-30T00:00:00.000Z"),
      decision: resolveRetentionScope(
        facts({ callerUserId: OWNER, profileRole: role, ownerId: OWNER, membershipRole: role }),
      ),
      reports: [],
      lastSweep: null,
    });
    assertEqual(
      payload.defaults,
      {
        location_retention_days: 30,
        usage_retention_days: 90,
        webrtc_signals_days: 7,
        audit_logs_days: 365,
      },
      `defaults for role ${role}`,
    );
  }
});

Deno.test("payload: a missing sweep row is reported as null, not as a guess", () => {
  const payload = buildRetentionReportPayload({
    now: new Date("2026-10-30T00:00:00.000Z"),
    decision: resolveRetentionScope(
      facts({ callerUserId: OWNER, profileRole: "parent", ownerId: OWNER, membershipRole: "parent" }),
    ),
    reports: [],
    lastSweep: null,
  });
  assertEqual(payload.last_sweep, null, "no sweep totals");
  assertEqual(payload.last_sweep_at, null, "no sweep timestamp");
});
