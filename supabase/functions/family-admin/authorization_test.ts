// Pure authorization predicate tests for family-admin.
// Run with:
//   deno test supabase/functions/family-admin
// No network, no Supabase client.
import { canDeleteZone, canPurge } from "./authorization.ts";

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
      `ASSERTION FAILED (${message}): expected ${expected}, got ${actual}`,
    );
  }
}

Deno.test("canPurge: only the family owner may purge", () => {
  assert(canPurge("parent", true), "the owner must be able to purge");
  assertEqual(canPurge("parent", false), false, "a non-owner parent cannot purge");
});

Deno.test("canPurge: children and unset roles are rejected even if owner_id matched", () => {
  assertEqual(canPurge("child", true), false, "a child cannot purge");
  assertEqual(canPurge("unset", true), false, "an unset role cannot purge");
  assertEqual(canPurge("parent", false), false, "a non-owner parent cannot purge");
  assertEqual(canPurge("child", false), false, "a child cannot purge");
});

Deno.test("canDeleteZone: any active parent of the zone's family may delete", () => {
  assert(canDeleteZone("parent", true), "an active family parent may delete a zone");
  assertEqual(
    canDeleteZone("parent", false),
    false,
    "a parent of another family cannot delete a zone",
  );
  assertEqual(canDeleteZone("child", true), false, "a child cannot delete a zone");
  assertEqual(canDeleteZone("unset", false), false, "an unset role cannot delete a zone");
});

Deno.test("canDeleteZone is not owner-only (matches safe_zones insert/update policies)", () => {
  // A non-owner parent already holds insert/update on safe_zones, so delete
  // must not be stricter than the write policies it replaces.
  assert(canDeleteZone("parent", true), "a non-owner parent must be allowed");
});