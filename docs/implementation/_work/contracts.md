# contracts — phase notes

Deliverables: `baseline.md`, `api-contract.md`, `feature-ownership.md`, `dependency-map.md`,
`phase-0-report.md` (all in `docs/implementation/`).

Decisions worth knowing (not restated in the contract):

1. **`ended_by='system'` is unrepresentable** — the column is `uuid references profiles`
   (`core.sql:340`). Implemented as `ended_by = null` + `ended_reason='abandoned'`. Contract wording
   should be amended (report D1).
   **Phase 2 correction (2026-11-02):** the amendment is made and ratified, so this is closed. The
   contract now states the resolved deviation directly
   (`docs/implementation/api-contract.md:231`, "resolved deviation … the pair is the system marker"),
   `_work/coordinator-contract.md:41-43` carries the amended frozen wording
   (`ended_reason='abandoned'`, `ended_by=NULL`), and the coordinator ratified it as forced by
   the column type (`docs/implementation/phase-1-report.md`, finding F4). No owner-level signature
   was recorded — see `docs/implementation/phase-2-governance.md` §2.
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