// Pure retention-window tests. Run with:
//   deno test supabase/functions/account
import {
  buildFamilyRetentionReport,
  DEFAULT_LOCATION_RETENTION_DAYS,
  DEFAULT_USAGE_RETENTION_DAYS,
  MAX_RETENTION_DAYS,
  parseRetentionDays,
  retentionCutoffs,
  retentionFromSettings,
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

Deno.test("parseRetentionDays falls back for unusable values", () => {
  const fallback = 30;
  for (const value of [null, undefined, "", "  ", "30 days", "1.5", 1.5, 0, -3, true, {}]) {
    assertEqual(
      parseRetentionDays(value, fallback),
      fallback,
      `fallback for ${JSON.stringify(value)}`,
    );
  }
});

Deno.test("parseRetentionDays accepts integers and numeric strings", () => {
  assertEqual(parseRetentionDays(45, 30), 45, "number");
  assertEqual(parseRetentionDays("45", 30), 45, "string");
  assertEqual(parseRetentionDays(" 45 ", 30), 45, "padded string");
  assertEqual(parseRetentionDays(1, 30), 1, "minimum");
});

Deno.test("parseRetentionDays clamps absurd windows", () => {
  assertEqual(parseRetentionDays(99999, 30), MAX_RETENTION_DAYS, "upper clamp");
  assertEqual(parseRetentionDays("99999", 30), MAX_RETENTION_DAYS, "string clamp");
});

Deno.test("retentionFromSettings reads both windows with schema defaults", () => {
  assertEqual(
    retentionFromSettings(null),
    {
      location_retention_days: DEFAULT_LOCATION_RETENTION_DAYS,
      usage_retention_days: DEFAULT_USAGE_RETENTION_DAYS,
    },
    "null settings",
  );
  assertEqual(
    retentionFromSettings({ location_retention_days: 14 }),
    {
      location_retention_days: 14,
      usage_retention_days: DEFAULT_USAGE_RETENTION_DAYS,
    },
    "partial settings",
  );
  assertEqual(
    retentionFromSettings({
      location_retention_days: "7",
      usage_retention_days: "365",
    }),
    { location_retention_days: 7, usage_retention_days: 365 },
    "string settings from jsonb",
  );
});

Deno.test("retentionCutoffs uses a timestamp for location and a date for usage", () => {
  const now = new Date("2026-10-30T12:00:00.000Z");
  assertEqual(
    retentionCutoffs(now, {
      location_retention_days: 30,
      usage_retention_days: 90,
    }),
    {
      location_before: "2026-09-30T12:00:00.000Z",
      usage_before: "2026-08-01",
    },
    "30/90 day cutoffs",
  );
});

Deno.test("buildFamilyRetentionReport never invents negative counts", () => {
  const report = buildFamilyRetentionReport({
    familyId: "f1",
    name: "Our family",
    settings: { location_retention_days: 14, usage_retention_days: 60 },
    locationEventsOlder: -1,
    usageDaysOlder: 4,
    now: new Date("2026-10-30T00:00:00.000Z"),
  });
  assertEqual(report.location_retention_days, 14, "location window");
  assertEqual(report.usage_retention_days, 60, "usage window");
  assertEqual(report.location_events_older_than_window, 0, "clamped location count");
  assertEqual(report.usage_days_older_than_window, 4, "usage count");
  assert(report.cutoffs.location_before.startsWith("2026-10-16"), "location cutoff");
  assert(report.cutoffs.usage_before.startsWith("2026-08-31"), "usage cutoff");
});