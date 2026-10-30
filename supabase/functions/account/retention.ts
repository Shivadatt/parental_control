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