# Phase 1 — frozen contract and file ownership (coordinator)

This file is the shared contract for the Phase 0 + Phase 1 workstreams. Read it before touching
code. Where this file and an older document disagree, this file wins for Phase 1.

## Non-negotiables

1. **Preserve the existing app.** Extend and fix; never rewrite a working module, never delete a
   feature, never rename a public class/table/route that other code depends on.
2. **No Supabase CLI.** It is not installed and must not be installed. All hosted operations would be
   dashboard-only — and in this phase there are **no hosted operations at all**.
3. **No deployment, no hosted SQL, no secret/auth changes.** Migrations are written locally as new
   files under `supabase/migrations/` and are **not** applied. Edge Functions are edited locally and
   **not** deployed. Deployment is a separate, owner-approved step.
4. **No destructive git.** No `reset --hard`, no `clean`, no branch deletion, no force push, no
   amending published commits. Uncommitted user work in the tree must be left untouched.
5. **No fabricated evidence.** Anything not executed is `NOT TESTED` / `BLOCKED`, never `PASS`.
6. **No hidden capture, no permission bypass, no keylogging.** Consent UI must stay truthful.
7. **Every code change gets regression coverage** in the same workstream (Flutter test, Deno test,
   SQL test, or a documented why-not if the suite cannot run here).
8. **No new tables** in Phase 1. No new columns on existing tables. No new RPC that clients call
   directly. Reuse `audit_logs` (text `event_type`), `devices`, `device_policies`,
   `remote_sessions`, `webrtc_signals`, `safe_zones`.
9. **No dependency additions** without coordinator approval. Assume none are approved.
10. **Do not run `flutter test` or `flutter build`** — the verification workstream runs them once at
    the end to avoid concurrent build-lock failures. `dart analyze <paths>` is allowed. `deno check`
    / `deno test <specific file>` is allowed.

## Fixed interfaces (do not change without coordinator approval)

### Session lifecycle (workstream: session)
- A row's `expires_at` is a **pending-request deadline only**: set on `request`, non-null only while
  `status='requested'`, cleared on accept. Consented rows have `expires_at IS NULL`.
- Terminal states `declined|ended|expired|failed` are final.
- `end` is **parent-only** server-side; the child stops sharing locally and never ends the row.
- New SQL function, exact signature:
  `public.expire_abandoned_sessions(p_max_age interval default '24 hours') returns integer`
  - SECURITY DEFINER, `set search_path = public, private, pg_temp`.
  - Closes `accepted|active` rows whose `accepted_at < now() - p_max_age` (or `requested_at` when
    `accepted_at` is null but status is consented — defensive only).
  - Sets `status='expired'`, `ended_at=now()`, `ended_reason='abandoned'`, `ended_by=NULL`.
    (`remote_sessions.ended_by` is `uuid references profiles(id)`; a system close cannot have an
    actor uuid, so NULL + reason is the frozen representation. Amended after workstream audit.)
  - Writes one `audit_logs` row per closed session: `event_type='session_expired'`,
    `metadata = {"reason":"abandoned","age_seconds":N}`.
  - Granted to `service_role` only; revoked from `public, anon, authenticated`.
- `cron` Edge Function action **`sweep_sessions`** calls it (owned by workstream: lifecycle).
- `remote-session` action `request` calls it best-effort before the advisory lock.

### Presence (workstream: presence)
- `Device.onlineWindow` becomes **12 minutes** (heartbeat 5 min × 2 + 2 min grace), documented.
- New derived getter `Device.syncHealth` → `healthy` (< onlineWindow), `stalled` (< 30 min),
  `offline` otherwise. UI must show *age* ("synced 3 min ago"), not just a boolean.
- A stalled guardian must be visible: if `last_seen_at` age > 2 × heartbeat, device card shows
  "Sync stalled" — never "Online".
- No schema change; `devices.capabilities` does not exist, so health is derived, not stored.

### Enforcement (workstream: enforcement)
- `policy_ack.result` adds: `desired_count`, `applied_count`, `failed_count`,
  `enforcement_supported` (bool), `enforcement_mode` (string).
- Server sets `device_policies.enforcement_status`:
  - `enforced` only when `enforcement_supported == true` AND `failed_count == 0` AND
    `applied_count == desired_count` AND (desired_count > 0 when the policy targets apps).
  - `unsupported` when `enforcement_supported == false` (the honest state on non-Device-Owner).
  - `failed` when attempted and any app failed.
  - `pending` otherwise.
- `devices.policy_version` advances only on `enforced` or `unsupported`, never on `failed`/`pending`.
- Parent UI must print "Applied to N of M apps" and must show an explicit unsupported state instead
  of a green enforced badge when `enforcement_supported` is false.
- `enforcement_status` check already allows `pending|enforced|failed|unsupported` — no migration.

### Authorization (workstream: security)
- `purge_data` requires **family owner**, not any parent.
- `safe_zones` client `DELETE` is removed (policy dropped, table DELETE revoked from
  `authenticated`); replacement is `family-admin` action **`delete_zone`** `{zone_id}`.
- New helper `private.is_parent_of_family(p_user uuid, p_family uuid) returns boolean`; the four
  service RPCs (`request_remote_session`, `revoke_device`, `unlink_child`, `apply_policy_version`)
  must call it and raise `not_family_parent` (`errcode 42501`) when false. `unlink_child` keeps the
  existing child-self-unlink exception (`p_actor = p_child`), which only touches that child's own
  membership row.
- `private.remote_session_transition_guard()` and `private.request_device_recovery(uuid,uuid)` lose
  default PUBLIC execute.
- `webrtc_signals` gains a unique index on `(session_id, sequence)` only if the table currently has
  no duplicates; the migration must check and skip with a notice instead of deleting rows.
- `session_nonce` is **removed as a claim**, not enforced: no client sends it and adding validation
  would break signaling. Document it as reserved.
- Audit immutability triggers: inspect, and only change if the fix is provably safe. If in doubt,
  leave the trigger and record the finding.

### Data lifecycle (workstream: lifecycle)
- New Edge Function `account` with actions:
  - `export` → JSON attachment (`Content-Disposition`) containing the caller's profile, family,
    devices, and their own rows from `location_events`, `usage_daily`, `safety_alerts`,
    `audit_logs`; hard cap 20 000 rows per table, `truncated` flags in the payload.
  - `delete_account` → requires body `{confirm: "DELETE", email: "<caller email>"}`. Refuses if the
    caller owns a family with other active members or active devices (must unlink/transfer first).
    Deletes membership rows, profile, then `auth.admin.deleteUser`.
  - `retention_report` → returns the configured windows and the last sweep timestamp.
- `cron` action **`retention_sweep`**: deletes `webrtc_signals` older than 7 days, `audit_logs`
  older than 365 days, and per-family `location_events` / `usage_daily` outside
  `location_retention_days` / `usage_retention_days`. SQL function
  `public.run_retention_sweep() returns jsonb`, service-role only.
- Settings UI gains a "Privacy & data" section wired to these actions with real loading/error states.

### Audio reliability (workstream: audio)
- One `RTCPeerConnection` per live session; any recreate must dispose the previous peer and all local
  tracks first.
- Teardown is explicit and idempotent; transient states never tear down media.
- Native capture start/stop is idempotent; `AudioRecord` released exactly once.
- No behaviour change to consent, signaling protocol, or session lifetime.

### Android hardening (workstream: android)
- Release signing reads `android/key.properties` when present, else keeps the current debug
  fallback **with an explicit warning** printed at build time. Add `android/key.properties.example`.
- `network_security_config.xml`: cleartext disabled; no pinning yet (document as TODO).
- Auth callback: validate that the incoming deep link carries the expected scheme/host and a
  `code`/`access_token`-shaped parameter; ignore anything else. No new exported component.

## File ownership (exclusive — do not edit files owned by another workstream)

| Workstream | Owned paths |
|---|---|
| contracts | `docs/implementation/**` (except files owned by verification/review below) |
| session | `supabase/functions/remote-session/**`, `supabase/migrations/20261030000100_*.sql`, `supabase/functions/_shared/remote_session*.ts` (new file only) |
| presence | `lib/data/models/device.dart`, `lib/features/dashboard/**`, `lib/features/devices/**`, `android/.../GuardianService.kt`, `android/.../BootReceiver.kt`, `test/data/device_model_test.dart`, `test/features/dashboard/**`, `test/features/devices/**` |
| enforcement | `android/.../PolicyApplier.kt`, `android/.../policy/**`, `supabase/functions/device-policy/**`, `supabase/functions/device-command/**`, `lib/features/app_restrictions/**`, `lib/features/child/child_restrictions_page.dart`, `test/features/app_restrictions/**` |
| security | `supabase/migrations/20261030000200_*.sql`, `supabase/functions/family-admin/**`, `supabase/functions/_shared/auth.ts`, `supabase/tests/7*_phase1_*.sql`, `test/features/safe_zones/**` |
| lifecycle | `supabase/functions/account/**` (new), `supabase/functions/cron/**`, `supabase/migrations/20261030000300_*.sql`, `lib/features/settings/**`, `test/features/settings/**` |
| audio | `lib/features/remote_assistance/**`, `android/.../AudioAssistanceService.kt`, `test/features/remote_assistance/**` |
| android | `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/**`, `android/key.properties.example`, `android/.../MainActivity.kt` |
| verification | `docs/implementation/regression-matrix.md`, `docs/implementation/deployment-log.md` |
| review | `docs/implementation/phase-1-report.md`, `docs/implementation/remaining-gaps.md` |

Anything outside your list: read it, do not edit it. If a cross-module change is unavoidable, stop
and report it in your output instead of making it.

## Test rules

- Add tests in your own ownership area with unique file names.
- Flutter: place under `test/...` mirroring the source path; use the existing fake/mock style
  (see neighbouring tests). Do not delete or weaken existing tests.
- Deno: `_test.ts` beside the function; no network, no real Supabase.
- SQL: a new file under `supabase/tests/` following the existing numbering; it will not be executed
  in this phase (no CLI, no hosted access), so write it to be runnable and say so.
- Kotlin: unit tests cannot run on this workstation (cross-drive Gradle). You may add them, but the
  result must be reported as `BLOCKED — environment`.
- Do not claim a suite passed unless you executed it.

## Report format (returned to the coordinator, ≤ 40 lines)

```
Workstream: <name>
Changed files: <path: one-line reason> (exact list)
Contract deviations: <none | list with why>
Tests added: <path> — <what it asserts>
Executed: <command> → <result>   (or "none — reason")
Blocked: <item — exact unblock action>
Known risks: <≤5 bullets>
```

Write your phase notes to `docs/implementation/_work/<workstream>.md` (short; no duplication of the
contract).