// Pure retention-window helpers for the `account` Edge Function.
//
// Defaults match the `families.settings` column default in the core schema and
// `family-admin` (30 / 90 days). Both the retention report and the documented
// SQL sweep use the same fallback, so the number shown in Settings is the
// number the sweep enforces.

export const DEFAULT_LOCATION_RETENTION_DAYS = 30;
export const DEFAULT_USAGE_RETENTION_DAYS = 90;
/** Upper bound accepted by family-admin `update_retention` is lower; this is a
 * defensive clamp so a hand-edited settings object cannot delete everything. */
export const MAX_RETENTION_DAYS = 3650;

export interface RetentionWindows {
  location_retention_days: number;
  usage_retention_days: number;
}

/**
 * Accepts only a positive integer (number or numeric string). Anything else —
 * null, `""`, `"30 days"`, `1.5`, `0`, `-1` — falls back to the default. The
 * value is clamped to [1, MAX_RETENTION_DAYS] so a corrupt settings row can
 * never mean "retain nothing".
 */
export function parseRetentionDays(
  value: unknown,
  fallback: number,
): number {
  let parsed: number | null = null;
  if (typeof value === "number" && Number.isInteger(value)) {
    parsed = value;
  } else if (typeof value === "string" && /^\d{1,5}$/.test(value.trim())) {
    parsed = Number.parseInt(value.trim(), 10);
  }
  if (parsed === null || parsed < 1) return fallback;
  return Math.min(parsed, MAX_RETENTION_DAYS);
}

/** Reads both windows from a `families.settings` value. */
export function retentionFromSettings(settings: unknown): RetentionWindows {
  const raw = typeof settings === "object" && settings !== null
    ? settings as Record<string, unknown>
    : {};
  return {
    location_retention_days: parseRetentionDays(
      raw.location_retention_days,
      DEFAULT_LOCATION_RETENTION_DAYS,
    ),
    usage_retention_days: parseRetentionDays(
      raw.usage_retention_days,
      DEFAULT_USAGE_RETENTION_DAYS,
    ),
  };
}

// ===========================================================================
// PRIV-01 (Option A) — who a retention/export payload is about.
//
// Before this, `retention_report` answered every authenticated caller (including
// a Child) with whole-family counts plus the project-wide sweep totals read from
// `audit_logs` — a row a child cannot even select under RLS
// (`audit_logs_select_family_parent` requires a non-null family_id, and the
// sweep marker row has none). The scope is now an explicit three-state value
// that the UI renders verbatim, so a sentence is never guessed from a boolean.
//
// The rule mirrors the family-admin predicates rather than inventing a second
// policy: `canPurge(role, isOwner)` (owner-only) decides the sweep totals, and
// `canDeleteZone(role, isActiveParent)` (any active parent) decides the
// family-wide counts. An unknown/missing role never reaches the family branch.
// ===========================================================================

/** Exact wire tokens other workstreams (client, docs) depend on. */
export type RetentionScope = "family" | "device" | "not_reported";

/** The only token an undetermined caller may ever receive. */
export const NOT_REPORTED_SCOPE: RetentionScope = "not_reported";

export interface RetentionMembershipFact {
  family_id: string;
  role: unknown;
}

export interface RetentionFamilyFact {
  id: string;
  owner_id: string;
}

/**
 * The facts the decision needs, typed loosely and optionally on purpose: a
 * missing profile, a null role or a value outside the enum must land in
 * `not_reported` instead of throwing the caller into the family-wide branch.
 */
export interface RetentionScopeFacts {
  callerUserId?: unknown;
  profileRole?: unknown;
  memberships?: readonly RetentionMembershipFact[] | null | undefined;
  families?: readonly RetentionFamilyFact[] | null | undefined;
}

export interface RetentionScopeDecision {
  scope: RetentionScope;
  /** Owner-only: the project-wide sweep totals (`last_sweep`). */
  includeSweepTotals: boolean;
  /** Whether the sweep marker row may be read at all (family scope). */
  readsSweepMarker: boolean;
}

const NOT_REPORTED: RetentionScopeDecision = {
  scope: NOT_REPORTED_SCOPE,
  includeSweepTotals: false,
  readsSweepMarker: false,
};

function text(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

/**
 * Decides the scope from already-loaded facts. Pure: no network, so the whole
 * rule is exercisable with `deno test`.
 */
export function resolveRetentionScope(
  facts: RetentionScopeFacts | null | undefined,
): RetentionScopeDecision {
  const callerUserId = text(facts?.callerUserId);
  if (!facts || !callerUserId) return NOT_REPORTED;

  const role = text(facts.profileRole);
  const families = Array.isArray(facts.families) ? facts.families : [];
  const memberships = Array.isArray(facts.memberships)
    ? facts.memberships
    : [];
  const familyIds = new Set(
    families.map((family) => text(family?.id)).filter((id) => id !== ""),
  );
  /**
   * A membership only counts for a family that is actually in the report, so a
   * removed/soft-deleted family cannot widen the scope.
   */
  const isMemberOf = (membershipRole: string): boolean =>
    memberships.some(
      (membership) =>
        text(membership?.role) === membershipRole &&
        familyIds.has(text(membership?.family_id)),
    );
  const ownsFamily = families.some(
    (family) => text(family?.owner_id) === callerUserId,
  );

  // Owner of a reported family, and a parent: family counts plus sweep totals.
  if (role === "parent" && ownsFamily) {
    return {
      scope: "family",
      includeSweepTotals: true,
      readsSweepMarker: true,
    };
  }
  // A parent member who is not the owner: family counts, sweep totals redacted.
  if (role === "parent" && isMemberOf("parent")) {
    return {
      scope: "family",
      includeSweepTotals: false,
      readsSweepMarker: true,
    };
  }
  // A child member: their own device rows only, and no sweep marker at all.
  if (role === "child" && isMemberOf("child")) {
    return {
      scope: "device",
      includeSweepTotals: false,
      readsSweepMarker: false,
    };
  }
  return NOT_REPORTED;
}

/**
 * The where-clause one count query must carry. `device_ids === null` means the
 * whole family (family scope only); an empty array means "match nothing", so
 * `run` is false and no query is issued — an empty `in.()` is never sent.
 */
export interface RetentionCountFilter {
  run: boolean;
  family_id: string;
  device_ids: readonly string[] | null;
}

export function retentionCountFilter(input: {
  scope: RetentionScope;
  familyId: string;
  deviceIds: readonly string[];
}): RetentionCountFilter {
  const familyId = typeof input.familyId === "string" ? input.familyId : "";
  if (input.scope === "not_reported") {
    return { run: false, family_id: familyId, device_ids: [] };
  }
  if (input.scope === "family") {
    return { run: true, family_id: familyId, device_ids: null };
  }
  const ids = [
    ...new Set(
      (Array.isArray(input.deviceIds) ? input.deviceIds : [])
        .filter((id): id is string => typeof id === "string")
        .map((id) => id.trim())
        .filter((id) => id !== ""),
    ),
  ];
  return { run: ids.length > 0, family_id: familyId, device_ids: ids };
}

/** Newest `event_type = 'retention_sweep'` row, as stored. */
export interface SweepMarkerRow {
  created_at?: string | null;
  metadata?: unknown;
}

/** Static, documented sweep windows — project constants, not family data. */
export const SWEEP_DEFAULT_DAYS = {
  webrtc_signals_days: 7,
  audit_logs_days: 365,
} as const;

/**
 * Final response shape, with the redactions applied by the decision rather than
 * by the call sites, so a future query cannot leak a field back in.
 */
export function buildRetentionReportPayload(input: {
  now: Date;
  decision: RetentionScopeDecision;
  reports: readonly FamilyRetentionReport[];
  lastSweep: SweepMarkerRow | null;
}): Record<string, unknown> {
  const familyScope = input.decision.scope === "family";
  return {
    generated_at: input.now.toISOString(),
    scope: input.decision.scope,
    defaults: {
      location_retention_days: DEFAULT_LOCATION_RETENTION_DAYS,
      usage_retention_days: DEFAULT_USAGE_RETENTION_DAYS,
      ...SWEEP_DEFAULT_DAYS,
    },
    last_sweep_at: familyScope ? input.lastSweep?.created_at ?? null : null,
    last_sweep: input.decision.includeSweepTotals
      ? input.lastSweep?.metadata ?? null
      : null,
    families: input.decision.scope === "not_reported"
      ? []
      : [...input.reports],
  };
}

/**
 * Cutoffs the report counts against. Location uses a timestamp; usage is a
 * calendar day (the `usage_daily.day` column is `date`).
 */
export function retentionCutoffs(
  now: Date,
  windows: RetentionWindows,
): { location_before: string; usage_before: string } {
  const dayMs = 24 * 60 * 60 * 1000;
  return {
    location_before: new Date(
      now.getTime() - windows.location_retention_days * dayMs,
    ).toISOString(),
    usage_before: new Date(
      now.getTime() - windows.usage_retention_days * dayMs,
    ).toISOString().slice(0, 10),
  };
}

export interface FamilyRetentionReport {
  family_id: string;
  name: string;
  location_retention_days: number;
  usage_retention_days: number;
  location_events_older_than_window: number;
  usage_days_older_than_window: number;
  cutoffs: { location_before: string; usage_before: string };
}

/** Shapes one family's report row without inventing counts. */
export function buildFamilyRetentionReport(input: {
  familyId: string;
  name: string;
  settings: unknown;
  locationEventsOlder: number;
  usageDaysOlder: number;
  now: Date;
}): FamilyRetentionReport {
  const windows = retentionFromSettings(input.settings);
  return {
    family_id: input.familyId,
    name: input.name,
    location_retention_days: windows.location_retention_days,
    usage_retention_days: windows.usage_retention_days,
    location_events_older_than_window: Math.max(0, input.locationEventsOlder),
    usage_days_older_than_window: Math.max(0, input.usageDaysOlder),
    cutoffs: retentionCutoffs(input.now, windows),
  };
}