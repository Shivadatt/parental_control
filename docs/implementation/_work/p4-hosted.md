# P4-G — production deployment gate: hosted state re-confirmed read-only, HOST-01 still open

Phase: 4 · Workstream: G (agent G captured the overview then died; coordinator completed the probes)
Observed: 2026-11-03 11:36:14 +0530 (06:06:14Z) · Verdict: **MITIGATED-NO / BLOCKED — HOST-01 remains a deployment blocker**
Raw capture: `.tools/p4g-probe-observations.txt` · one image: `.tools/p4g-00-overview.png`

Brief §10 asked for read-only reconfirmation of the Phase 3 hosted observations, with the explicit
constraint that nothing may be fixed. Every item below is an **observation**, not a change.

---

## 1. Method and its limits (stated before the findings)

- Only the dashboard UI of project `parent-control-prod`, ref `hhqgreaoqulmfwfwarhc`, plus
  **SELECT-only** catalog probes in the dashboard SQL editor. The Supabase CLI exists at
  `C:/Users/ASUS/AppData/Roaming/npm/supabase` and **was not invoked** — no `db`, `migration`,
  `functions`, `secrets`, `start` or `links` command was run in this phase.
- No hosted write of any kind: no DDL, no DML, no function call, no secret or Auth change, no saved or
  deleted SQL snippet, no dashboard setting touched, no deployment, no cron job.
- **Evidence-form limitation, disclosed:** screenshots and pointer clicks were unavailable this session
  (`NATIVE_BROWSER_VIEWPORT_UNAVAILABLE`, `visibilityState=hidden`, viewport 453×553). Structural
  inspection and script evaluation worked, so results were read from the rendered DOM instead. The only
  image artifact is agent G's overview screenshot from 09:52.
- **First attempt failed for a tooling reason, not a database one:** the editor's Monaco model was
  empty (model length 0 while the DOM textarea held 2 994 chars), so the dashboard submitted an empty
  query and returned `query: Too small: expected string to have >=1 characters`. Nothing executed
  server-side. Setting the model value directly fixed it; both probes then returned row sets
  ("13 rows", "7 rows").
- react-data-grid virtualises, and a hidden viewport paints only the first cells, so the 13-row probe
  was read as rows 1–8 and rows 9–13 were re-issued as a second, smaller query. Both result sets are
  recorded; neither is inferred.

## 2. Reconfirmation against the Phase 3 record (`phase-3-report.md` §7, point-in-time 2026-11-02)

| # | Surface | Phase 3 (2026-11-02) | Phase 4 (2026-11-03) | Moved? |
|---|---|---|---|---|
| 1 | public base tables | 19 | **19** | no |
| 2 | `safe_zones` relacl | `postgres=arwdDxtm/postgres, service_role=arwdDxtm/postgres, authenticated=rd/postgres` | **identical**, `authenticated=rd` | **no — exposure still live** |
| 3 | `safe_zones` policies | `safe_zones_delete_parent, safe_zones_insert_parent, safe_zones_select_family, safe_zones_update_parent` | **identical 4** | **no — `safe_zones_delete_parent` still present** |
| 4 | Phase 1 public RPCs | none of the Phase-1-introduced ones | `expire_abandoned_sessions` and `run_retention_sweep` **absent**; `apply_policy_version, request_remote_session, revoke_device, unlink_child` present **as their pre-Phase-1 bodies** (see §3) | no |
| 5 | `private.is_parent_of_family` | ABSENT | **ABSENT** (any schema) | no |
| 6 | Phase 1 indexes (`remote_sessions_abandoned_idx`, `webrtc_signals_created_idx`, `audit_logs_created_idx`, `webrtc_signals_session_sequence_uniq`) | NONE | **NONE** | no |
| 7 | `devices.installation_id` | text | **text** | no |
| 8 | `audit_logs_append_only` trigger | present | **present** | no |
| 9 | migration tracking (`supabase_migrations.schema_migrations` / `_supabase_migrations.database_migrations`) | table ABSENT | **ABSENT / ABSENT**, and the project overview reads **"No migrations"** | no |
| 10 | `cron.job` | "Cron is not installed." | **`cron.job` ABSENT** and the Cron integration page still says **"Cron is not installed."** | no |
| 11 | Edge Functions | 9, no `account` | **9, no `account`** (auth-bootstrap, cron, device-command, device-policy, device-register, device-telemetry, family-admin, pairing, remote-session; created 8 days ago, updated 6–8 days ago, 5–6 deployments each) | no |
| 12 | support schemas visible | only `private` of (`edge_functions`, `supabase_functions`, `private`, `supabase_migrations`) | **only `private`**; `edge_functions.functions` → ABSENT | no |
| 13 | `device_policies` columns | (not probed) | `acknowledged_at, created_at, created_by, device_id, enforcement_status, family_id, id, last_error, policy, version` — the pre-Phase-1 shape, **no counts columns** | new probe |
| 14 | `remote_sessions.ended_reason` | (not probed) | `text` (pre-existing) | new probe |

**Reading.** Nothing moved in 24 hours. The hosted database is still at the pre-Phase-1 schema plus the
earlier committed stages, exactly as Phase 3 recorded.

## 3. The one thing this re-check adds

Phase 3's row 2 was ambiguous in isolation: "14 functions, neither `expire_abandoned_sessions` nor
`run_retention_sweep`" tells you the *new* RPCs are missing, but the four RPCs that
`20261030000200_phase1_authorization.sql` rewrites (`request_remote_session:221`,
`revoke_device:318`, `unlink_child:357`, `apply_policy_version:394`) exist hosted **because they existed
before Phase 1** — they are `create or replace` targets. Presence alone could therefore be misread as
"partially applied". Probe 14 closes that: **no hosted function body references `is_parent_of_family`**
(`prosrc like '%is_parent_of_family%'` → NONE), and the guard function itself is ABSENT (probe 5). So
the hosted versions of those four RPCs are provably the pre-Phase-1 bodies, not partially applied
Phase 1 versions. That removes the only reading of §7 that could have suggested a half-deployed
database.

## 4. HOST-01 status — unchanged, and it is a blocker, not a note

| | |
|---|---|
| Exposure | Any authenticated user can `DELETE` rows from `safe_zones` through PostgREST to the extent the `safe_zones_delete_parent` policy lets them — the policy is the `is_family_parent()` form Phase 1 removed, and the ACL still grants `d` to `authenticated`. |
| Why it is still live | `20261030000100/200/300` were never applied. Probes 2, 3, 5, 6, 9, 14 are all consistent with that single cause. |
| Local state | The fix **is** written, tested in-chain and committed locally (`953b337`). It is not deployed. |
| Status | **BLOCKED — deployment blocker. Must remain so until the security migrations are explicitly approved, applied through the authorised process, and independently verified.** |
| What Phase 4 did about it | Nothing, by design. §10 of the brief forbids applying a fix; this workstream re-measured and recorded. |
| Owner's path to closure | (a) decide the eight OWNER-ONLY items in `phase-4-owner-approval-register.md` — PRIV-01, SQL-01/R3, SQL-04, SQL-05, SQL-06, GOV-02/D1, TEST-01, commit/push; (b) run the two mandatory pre-checks (signaling duplicate check at `20261030000200:478-486`, which is load-bearing — see `_work/p4-docs-sql06.md`; and the retention-backlog/`PROCEDURE` decision); (c) apply the three migrations in order through the authorised process; (d) re-run these exact probes read-only and diff against §2; (e) deploy the `account` function; (f) only then install cron and schedule the sweep. |
| Independent verification | Step (d) is the verification; a green apply with an unchanged probe is the failure mode Phase 3 warned about. |

## 5. Residual artifacts left behind (disclosed)

- 14 browser-local "Untitled query" tabs plus the two probes run here, all unsaved drafts. Pre-existing
  from Phase 3 (`phase-3-report.md` §7 residual note); Phase 4 added to the count. No snippet was
  saved, renamed or deleted — those are dashboard writes.
- `.tools/p4g-00-overview.png` (agent G, 09:52) and `.tools/p4g-probe-observations.txt` (coordinator)
  are gitignored local evidence captures.

**No hosted system was changed by this workstream, or by Phase 4 as a whole.**
