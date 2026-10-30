# security — phase notes

Deliverables: `supabase/migrations/20261030000200_phase1_authorization.sql`,
`supabase/functions/family-admin/authorization.ts` (+ test), `family-admin/index.ts`,
`supabase/tests/70_phase1_authorization.sql`, safe-zone delete path in
`lib/data/repositories/supabase_location_repository.dart`.

Decisions worth knowing (not restated in the contract):

1. **`assertFamilyOwner` already existed** in `_shared/auth.ts` (signature
   `(db, userId, familyId)`, errmap `owner_required`/403) and was already used by
   `update_retention`. `purge_data` now uses it, so `auth.ts` needed no edit. The task's suggested
   argument order `(supabase, familyId, userId)` was not adopted because the existing helper matches
   `assertFamilyParent` exactly.
2. **`unlink_child` keeps the child self-unlink exception** (`p_actor = p_child`), because the child
   app unlinks itself from settings (`child_shell_controller.unlink` → `pairing` action `unlink`).
   `private.unlink_child` only acts on that child's own membership row, so the exception grants no
   cross-member power. A strict parent-only check would break a working feature.
3. **`revoke_device` / `apply_policy_version` resolve the family from the device row.** A missing
   device falls through to the private function so `device_not_found` (404) / `device_required` are
   preserved; only an existing row is parent-checked.
4. **Stale SQL assertions outside security ownership** (must be updated before the suite can pass):
   `30_rls.sql:110-112` (parent may delete a zone), `40_functions.sql:286-293` and `:417-420`
   (expect `forbidden`, now `not_family_parent`).
5. **Audit triggers left unchanged.** `audit_logs_append_only`, `profiles_before_update` and
   `families_before_update` gate on `current_user` (function owner under SECURITY DEFINER) plus
   `request.jwt.claim.role`. Replacing `current_user` with `session_user` would break service writes
   (PostgREST connects as `authenticator` and `SET ROLE`s), so no change is provably safe.
6. **`webrtc_signals`**: `sequence` is `generated always as identity`, so the duplicate probe can
   only pass; the dedupe index is therefore expected to be created. The pre-existing non-unique
   index `webrtc_signals_session_sequence_idx` is now redundant and was left in place.
7. **Not mapped to 403**: `remote-session`, `device-policy` and `device-command` do not map
   `not_family_parent`; they would return 500 if the new check ever fired. Not reachable from their
   code paths (each verifies the parent before the RPC) and those files are owned by other
   workstreams. `family-admin` maps it to 403.

Not executed: the migration and `70_phase1_authorization.sql` (local only, no host, no CLI).
Executed: `deno test supabase/functions/family-admin` → 4 passed; `deno check family-admin/index.ts`
clean.