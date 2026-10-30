// Pure authorization predicates for the family-admin Edge Function.
//
// These are the single, unit-testable statement of *who* may perform the two
// privileged actions below. They take already-loaded facts (the profile role
// and the membership/ownership answer from the database) and never touch the
// network, so they can be exercised with `deno test` without Supabase.
//
// The database-facing helpers in ../_shared/auth.ts remain the enforcement
// point: assertFamilyOwner() and assertFamilyParent() load the facts and raise
// the stable ApiError contract. The predicates are consulted as an explicit
// second gate, so a future refactor of an assert cannot silently widen the
// policy without failing the handler.

/** Profile roles as stored in public.profiles.role. */
export type ProfileRole = "unset" | "parent" | "child";

/**
 * Purging family history is destructive and irreversible for the family, so it
 * is restricted to the family owner — not to every parent.
 */
export function canPurge(role: string, isOwner: boolean): boolean {
  return role === "parent" && isOwner;
}

/**
 * Deleting a safe zone is a normal parent action (any active parent of the
 * zone's family), matching the safe_zones insert/update policies. It is still
 * audited, which the direct client DELETE never was.
 */
export function canDeleteZone(role: string, isActiveParent: boolean): boolean {
  return role === "parent" && isActiveParent;
}