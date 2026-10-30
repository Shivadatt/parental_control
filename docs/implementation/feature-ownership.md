# Feature and file ownership

Source of truth: `docs/implementation/_work/coordinator-contract.md` §"File ownership". This file
restates it for the workstreams and adds the role collapse. Where the two disagree, the coordinator
contract wins.

## 1. The 10 workstreams and their owned paths

Paths are exclusive: a file appears under exactly one workstream. `android/.../` abbreviates
`android/app/src/main/kotlin/com/parentcontrol/parent_control/`.

| # | Workstream | Owned paths | Phase 1 scope |
|---|---|---|---|
| 1 | **contracts** | `docs/implementation/**` except `regression-matrix.md`, `deployment-log.md` (verification) and `phase-1-report.md`, `remaining-gaps.md` (review) | freeze contracts, baseline, ownership, dependency map, this phase report |
| 2 | **session** | `supabase/functions/remote-session/**`, `supabase/migrations/20261030000100_*.sql`, `supabase/functions/_shared/remote_session*.ts` (new file only) | `expire_abandoned_sessions`, best-effort sweep in `request`, parent-only `end` preserved |
| 3 | **presence** | `lib/data/models/device.dart`, `lib/features/dashboard/**`, `lib/features/devices/**`, `android/.../GuardianService.kt`, `android/.../BootReceiver.kt`, `test/data/device_model_test.dart`, `test/features/dashboard/**`, `test/features/devices/**` | 12-minute `onlineWindow`, `Device.syncHealth`, honest "synced N min ago" / "Sync stalled" |
| 4 | **enforcement** | `android/.../PolicyApplier.kt`, `android/.../policy/**`, `supabase/functions/device-policy/**`, `supabase/functions/device-command/**`, `lib/features/app_restrictions/**`, `lib/features/child/child_restrictions_page.dart`, `test/features/app_restrictions/**` | truthful ack counts, `enforced` only when proven, "Applied to N of M apps", explicit unsupported state |
| 5 | **security** | `supabase/migrations/20261030000200_*.sql`, `supabase/functions/family-admin/**`, `supabase/functions/_shared/auth.ts`, `supabase/tests/7*_phase1_*.sql`, `test/features/safe_zones/**` | owner-only purge, `delete_zone`, `private.is_parent_of_family`, revoke PUBLIC execute on two helpers, optional `(session_id, sequence)` unique index |
| 6 | **lifecycle** | `supabase/functions/account/**` (new), `supabase/functions/cron/**`, `supabase/migrations/20261030000300_*.sql`, `lib/features/settings/**`, `test/features/settings/**` | `account` export/delete/retention, `cron` `sweep_sessions` + `retention_sweep`, "Privacy & data" settings |
| 7 | **audio** | `lib/features/remote_assistance/**`, `android/.../AudioAssistanceService.kt`, `test/features/remote_assistance/**` | one peer per session, explicit idempotent teardown, native capture start/stop idempotence |
| 8 | **android** | `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/**`, `android/key.properties.example`, `android/.../MainActivity.kt` | release signing from `key.properties` or loud fallback, cleartext off, deep-link validation |
| 9 | **verification** | `docs/implementation/regression-matrix.md`, `docs/implementation/deployment-log.md` | the only workstream that runs `flutter test` / `flutter build`; records evidence and deploy state |
| 10 | **review** | `docs/implementation/phase-1-report.md`, `docs/implementation/remaining-gaps.md` | cross-workstream review, gap register, final sign-off |

Read-anywhere / write-nowhere: `audit/**` (frozen evidence), `lib/app/routes/**`, `lib/data/repositories/**`
(except as noted), `supabase/migrations/2026 0101…2026 1028…` (already deployed history — never edit
an applied migration).

## 2. Role collapse: 15 roles → 10 workstreams

The master prompt defines product/engineering roles. Phase 1 collapses them onto the ten
workstreams above so that each role has exactly one owner and each file one editor. Roles 11–15 are
**out of scope for Phase 1** and must not be started without a coordinator decision.

| Role | Role focus | Maps to | In Phase 1? |
|---|---|---|---|
| 1 | Architecture and interface freeze | contracts | yes |
| 2 | Session lifecycle and consent | session | yes |
| 3 | Presence, heartbeat, device health | presence | yes |
| 4 | App enforcement and policy application | enforcement | yes |
| 5 | Authorization, RLS, secrets | security | yes |
| 6 | Privacy and data lifecycle (export, delete, retention) | lifecycle | yes |
| 7 | Real-time audio (WebRTC, capture) | audio | yes |
| 8 | Android platform hardening (signing, manifest, deep links) | android | yes |
| 9 | Verification and evidence | verification | yes |
| 10 | Review and release gate | review | yes |
| 11 | Location and geofencing | — (no Phase 1 workstream) | **no** — geofence server path is untouched; presence owns only `last_seen_at` display |
| 12 | Screen time and usage reporting | — | **no** — `usage_daily` is read-only for Phase 1 |
| 13 | Website filtering / browsing history (`VpnService`) | — | **no** — 0 % implemented; no code exists to harden |
| 14 | Notifications and push (FCM, notification listener) | — | **no** — no push transport exists; adding one is a new dependency and needs approval |
| 15 | Screen mirroring, camera, media capture | — | **no** — audio is the only media path in scope; video stays a documented limitation |

Consequences of the collapse, stated plainly:

- Roles 11–15 have **no Phase 1 deliverable**. Any claim that website filtering, notifications,
  screen mirroring, camera capture or geofencing UX was "addressed" in Phase 1 is false.
- Where an out-of-scope role touches an in-scope file (e.g. `GuardianService.kt` carries heartbeat
  *and* location upload), the in-scope workstream owns the file and must not change the
  out-of-scope behaviour in the same edit.

## 3. Editing rules

1. **No concurrent edits to the same file.** Ownership is per path, not per feature. If a change
   needs a file owned by another workstream, the change is not made — it is reported to the
   coordinator with the exact path and the reason.
2. **No independent production Supabase changes.** No `supabase db push`, no dashboard DDL, no
   Edge Function deploy, no secret/auth edit, no CLI install. Migrations and functions are written
   locally; applying them is a separate owner-approved step recorded in
   `docs/implementation/deployment-log.md`.
3. **Cross-module changes need coordinator approval before the edit**, including:
   - a new or renamed route (26 paths are frozen, `api-contract.md` §1);
   - a new table, column, publication member, or client-callable RPC;
   - a new dependency in `pubspec.yaml`, `deno.json`, `build.gradle.kts`;
   - a change to any signature in coordinator-contract §"Fixed interfaces";
   - a change to another workstream's public class or model field (e.g. `Device`, `RemoteSession`).
4. **Shared files are read-only unless listed above.** In practice: `supabase/functions/_shared/*`
   is split by file — `auth.ts` belongs to security, a new `remote_session*.ts` to session,
   everything else is read-only in Phase 1.
5. **Tests live with the owner.** Adding a test to another workstream's directory is a cross-module
   change; add it under your own path and report the gap instead.
6. **Never edit an applied migration.** `2026010100*` and `2026102800*` are deployed history. Phase
   1 changes are new files `20261030000100`, `…000200`, `…000300`.
7. **Kotlin test results are `BLOCKED — environment`** regardless of what was written; do not
   claim a Kotlin pass.

## 4. Ownership of the Phase 1 contract documents

| File | Owner | May other workstreams edit? |
|---|---|---|
| `docs/implementation/baseline.md` | contracts | no — propose a change to the coordinator |
| `docs/implementation/api-contract.md` | contracts | no |
| `docs/implementation/feature-ownership.md` | contracts | no |
| `docs/implementation/dependency-map.md` | contracts | no |
| `docs/implementation/phase-0-report.md` | contracts | no |
| `docs/implementation/_work/<workstream>.md` | that workstream | only its own file |
| `docs/implementation/regression-matrix.md`, `deployment-log.md` | verification | no |
| `docs/implementation/phase-1-report.md`, `remaining-gaps.md` | review | no |