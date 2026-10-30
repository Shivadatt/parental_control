# Phase 1 — remaining gaps

Scope: the product capabilities and contract items that were **not** delivered by Phase 1, or were
delivered only in part. Status vocabulary is fixed: `NOT STARTED`, `PARTIAL`,
`BLOCKED — <reason>`. This file records state only; it does not authorise any change. Evidence paths
are relative to `D:\parentcontrol_app`.

Summary: 5 of the 9 named product areas are `NOT STARTED` (camera FGS, screen mirroring, web
filtering, l10n/a11y, push), 4 are `PARTIAL` (Device Owner provisioning, notifications, reports,
TURN), and none of the nine is externally `BLOCKED` yet. Of the ten Phase 1 contract items originally
listed in §2, **six are now closed** (cron shapes, nonce wording, manifest, `config.toml`, verification
publication, governance ratification), three remain `PARTIAL` (export scope wording,
`retention_report` role scope, hosted duplicate pre-check) and one is `BLOCKED` only by the Kotlin
environment. Closures are recorded in `phase-1-report.md` "Coordinator addendum". Nothing in this file
was executed, deployed or provisioned.

## 1. Product capabilities

### 1.1 Device Owner provisioning — PARTIAL
- What exists: `PolicyApplier` checks `isDeviceOwnerApp` before any suspension and reports
  `supported=false` otherwise (`android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt:285-314`);
  `DeviceAdminReceiver` and `res/xml/device_admin.xml` exist; Phase 1 adds honest
  `enforcement_mode`/`enforcement_supported` reporting end to end.
- What is missing: an actual provisioning flow. There is no QR/NFC/ADB onboarding in the app, no
  step in the parent UI, and provisioning has never been performed — `docs/app-restrictions.md:66-69`
  records it as not done, and `docs/backend.md:102` lists it as a future device step.
- Consequence: on every real device today app blocking is `unsupported`, which the Phase 1 UI now
  states truthfully instead of showing a false green badge.
- Unblock: factory-reset a disposable device, provision with `adb shell dpm set-device-owner
  com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver`, then run the enforcement
  matrix. A QR provisioning flow is Phase 2/3 work.

### 1.2 Camera foreground service — NOT STARTED
- The manifest declares `CAMERA` and `android.hardware.camera` as not required
  (`android/app/src/main/AndroidManifest.xml:9,32`), and the device model reports
  `cameraGranted`, but no camera capture exists: the only foreground service types are `dataSync`,
  `location` and `microphone` (`AndroidManifest.xml:82-93`), and no camera service or
  `FOREGROUND_SERVICE_CAMERA` permission is present.
- Unblock: design consent-first camera streaming (separate FGS type, visible notification, capture
  abstraction in `NativeBridge`), then add the FGS permission and type in a single Android change.

### 1.3 Screen mirroring — NOT STARTED
- No `MediaProjection`, `MediaProjectionManager`, virtual display or screen-capture code exists
  anywhere under `android/app/src/main/kotlin/` or `lib/`.
- Unblock: a separate workstream with explicit on-device consent UI, a `mediaProjection` FGS type,
  and a new signalling payload; it must not reuse the audio session's single-peer contract without a
  contract revision.

### 1.4 Notifications — PARTIAL
- What exists: the audio foreground service creates a notification channel and requests
  `POST_NOTIFICATIONS` (`android/.../AudioAssistanceService.kt:558-569`,
  `AndroidManifest.xml:11`); nothing else does.
- What is missing: any notification for safety alerts, offline devices, pairing, session requests or
  policy failures. There is no notification service, no local notification scheduling, and no
  deep-link target for notifications.
- Unblock: a notification workstream that consumes the existing `safety_alerts` and presence signals;
  keep it local-notification-only until push (1.9) exists.

### 1.5 Web filtering — NOT STARTED
- No WebView, VPN service, DNS interception, accessibility-based filtering or blocklist code exists
  in `lib/` or `android/`. `app_restrictions` covers installed-package suspension only.
- Unblock: requires a product decision (DNS/VPN vs in-app browser) plus a new FGS type; not a
  Phase 2 dashboard item.

### 1.6 Reports — PARTIAL
- What exists: real `UsageStatsManager` collection (`android/.../UsageReporter.kt:16-43`),
  `usage_daily` storage, an audit-log viewer (`lib/features/audit_logs/`), and the new
  `account retention_report` action (`supabase/functions/account/index.ts:366-432`).
- What is missing: a parent-facing report (weekly screen time, per-app totals, trend, export/PDF) and
  any scheduled generation.
- Unblock: Phase 2 dashboard work can consume `usage_daily`; no new table is needed.

### 1.7 Localisation and accessibility — NOT STARTED
- No `lib/l10n/`, no `flutter_localizations` / `intl` delegate configuration, and no `Semantics`
  usage anywhere in `lib/` (zero matches). All user-facing strings are hardcoded English.
- Unblock: a dedicated l10n/a11y pass after Phase 2 screens stabilise; add semantics labels to icon
  buttons and dynamic status chips first, since the new "Sync stalled" and enforcement banners are
  colour-plus-text.

### 1.8 TURN relay — PARTIAL
- What exists: the client models and refreshes `ice_servers`
  (`lib/data/models/remote_session.dart:217-259`,
  `lib/features/remote_assistance/remote_session_controller.dart:1186-1238,1993`), and the server
  mints time-limited TURN credentials from `TURN_URL`/`TURN_SECRET`
  (`supabase/functions/_shared/turn.ts:35-102`, with tests in `turn_test.ts`).
- What is missing: no relay is configured or tested. `docs/backend.md:21` records `TURN_URL` and
  `TURN_SECRET` as absent, so ICE returns STUN-only; no coturn deployment exists.
- Unblock: owner-approved TURN secrets plus a coturn host, then a restrictive-network session test.

### 1.9 Push (FCM/APNs) — NOT STARTED
- No Firebase dependency, no `google-services.json`, no messaging service or push function; the
  function list contains no push/inbox function. `docs/backend.md:7` lists FCM as blocked.
- Unblock: requires a Firebase/APNs project, a device-token table (which Phase 1's "no new tables"
  rule forbids), and a new function; must be its own phase with an owner decision on data model.

## 2. Phase 1 contract items left partial or unratified

| Item | Status | Evidence | What closes it |
|---|---|---|---|
| `cron` `sweep_sessions` request/response | CLOSED | Contract now reads `{}` → `{closed_sessions}` and the fixed 24 h window (`api-contract.md:147`, `:236`), matching `cron/index.ts:83-101` | — |
| `cron` `retention_sweep` response keys | CLOSED | Contract now lists `{swept_at, webrtc_signals, audit_logs, location_events, usage_daily, families_examined, per_family}` (`api-contract.md:148`), matching the SQL | — |
| Export scope wording | PARTIAL | Contract says "their own rows" (`coordinator-contract.md:94`); parents get family-scoped rows (`account/index.ts:150-177`), children their own | Ratify family scope for parents in the contract, or narrow the implementation |
| `retention_report` role scope | PARTIAL | Callable by any authenticated member; returns family-wide windows and older-row counts (`account/index.ts:366-424`) | Decide parent-only vs member-wide; if parent-only, add `requireRole`-style gating in the handler |
| `session_nonce` documentation | CLOSED | `api-contract.md` §5 now states the field is reserved, never validated, and points at the unique `(session_id, sequence)` index for replay protection |
| `webrtc_signals` unique index effectiveness | PARTIAL | The migration creates it only if hosted data has no duplicates, otherwise logs a notice (`20261030000200_phase1_authorization.sql:334-354`); hosted duplicate state is unknown (no hosted access) | Run the pre-check query on the target database before apply; if duplicates exist, plan a one-off dedupe with owner approval |
| Debug/verification evidence | CLOSED (Kotlin blocked) | `regression-matrix.md` and `deployment-log.md` published; Kotlin tests remain `BLOCKED — environment` (cross-drive Gradle) | Kotlin suite runs on a co-located Gradle checkout |
| Contract amendment and out-of-ownership edits | CLOSED | Ratified in `phase-1-report.md` "Coordinator addendum" (contract amendment, `supabase_location_repository.dart`, `30_rls.sql`, `40_functions.sql`, `supabase/tests/README.md`); the Android workstream's `flutter build apk --debug` is explicitly **not** ratified as evidence | — |
| Deploy manifest correctness | CLOSED | `deployment/manifest.md` now names `20261030000300_retention_sweep.sql` and carries recomputed hashes for all three migrations | Re-verify hashes on the applying machine at apply time |
| `account` function deploy config | CLOSED | `[functions.account] verify_jwt = true` added to `supabase/config.toml` | Per-function deploy-order wording still belongs to the deployment step |

## 3. Not gaps (recorded to avoid future duplicate work)

- Presence windows, age labels and stall watchdog are complete for the parent/child UI and the
  guardian tick; they need device-level runtime validation after a deploy, not more code.
- Abandoned-session sweep, retention sweep, owner-only purge, `delete_zone` and the four
  membership-checked RPCs are implemented and covered by SQL/Deno tests at module level; the
  remaining gap is handler-wiring tests and a real run, not missing behaviour.
- Debug release signing and cleartext hardening are complete for Phase 1; certificate pinning is
  intentionally a TODO (`android/app/src/main/res/xml/network_security_config.xml`) and should stay
  one until a certificate-rotation plan exists.