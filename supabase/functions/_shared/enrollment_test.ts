import { requiresRelink } from "./enrollment.ts";

function assertEqual(actual: unknown, expected: unknown, message: string): void {
  if (actual !== expected) {
    throw new Error(
      `ASSERTION FAILED (${message}): expected ${expected}, got ${actual}`,
    );
  }
}

Deno.test("revoked device stays blocked without a later approval", () => {
  assertEqual(
    requiresRelink("2026-10-01T10:00:00Z", null),
    true,
    "no approval ever recorded",
  );
  assertEqual(
    requiresRelink("2026-10-01T10:00:00Z", "2026-10-01T09:59:59Z"),
    true,
    "approval before revocation",
  );
  assertEqual(
    requiresRelink("2026-10-01T10:00:00Z", "2026-10-01T10:00:00Z"),
    true,
    "approval at the same instant is not enough",
  );
});

Deno.test("a later approved re-link clears the block", () => {
  assertEqual(
    requiresRelink("2026-10-01T10:00:00Z", "2026-10-02T08:00:00Z"),
    false,
    "approval after revocation",
  );
});

Deno.test("missing revocation time and invalid dates fail closed", () => {
  assertEqual(requiresRelink(null, "2026-10-02T08:00:00Z"), true, "null revoked_at");
  assertEqual(requiresRelink(undefined, undefined), true, "undefined values");
  assertEqual(
    requiresRelink("not-a-date", "2026-10-02T08:00:00Z"),
    true,
    "unparseable revoked_at",
  );
  assertEqual(
    requiresRelink("2026-10-01T10:00:00Z", "not-a-date"),
    true,
    "unparseable approval",
  );
});
