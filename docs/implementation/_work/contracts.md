# contracts — phase notes

Deliverables: `baseline.md`, `api-contract.md`, `feature-ownership.md`, `dependency-map.md`,
`phase-0-report.md` (all in `docs/implementation/`).

Decisions worth knowing (not restated in the contract):

1. **`ended_by='system'` is unrepresentable** — the column is `uuid references profiles`
   (`core.sql:340`). Implemented as `ended_by = null` + `ended_reason='abandoned'`. Contract wording
   should be amended (report D1).
2. **`device_commands` is in the realtime publication but no Dart code subscribes.** Delivery is the
   20 s `poll` action; treat any "realtime command" claim as false.
3. **`/child/restrictions` reuses `ChildShellBinding`** (`app_pages.dart:171-175`), so its controller
   is `ChildShellController`, not a page-specific one. Mentioned because route→controller tables
   usually assume 1:1.
4. **`/parent/devices` is not a route** — the list is a tab inside the parent shell.
5. Ownership: `supabase/functions/_shared/*` is split by file (`auth.ts` → security, new
   `remote_session*.ts` → session); everything else in `_shared` is read-only in Phase 1.
6. 25/242 inventory rows were re-verified (report §2); two citation defects found (FA-012 range,
   FD-050 evidence superseded by design). 217 rows are unverified and must not be quoted as checked.

No source, migration, config or hosted object was modified by this workstream.