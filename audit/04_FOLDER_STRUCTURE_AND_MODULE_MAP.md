# 04 — Folder structure and module map

Verified on 2026-10-30 against the working tree. Counts from `find`; responsibilities from `audit/_work/s1-flutter-architecture.md` §2.1 and `s3-android-native.md` §2.4. No files were moved.

## 1. Repository root

```
D:\parentcontrol_app
├── lib/                    140 Dart files   Flutter app (see §2)
├── android/                Kotlin app module + Gradle + manifests
├── android_dpc/            Device Owner provisioning companion (empty/no source)
├── supabase/               10 migrations, 9 Edge Functions, SQL tests
├── test/                   Flutter unit/widget tests
├── integration_test/       On-device Dart probes
├── docs/                   Runtime reports + evidence (stage4/5/8)
├── scripts/                Build + QA scripts (build_debug_apk.sh, …)
├── reports/                Earlier generated reports
├── build/, .dart_tool/     Generated artifacts (not source)
└── audit/                  This audit (new, documentation only)
```

## 2. Flutter (`lib/`, 140 files)

```
lib/
├── main.dart                          1   bootstrap + DI order
├── app/                               4
│   ├── app.dart                          GetMaterialApp (no locale/navigator config)
│   ├── bindings/repository_binding.dart  registers 10 repositories permanently
│   └── routes/                           app_routes.dart (26 consts) + app_pages.dart (26 GetPages)
├── core/                             16
│   ├── config/env.dart                   compile-time Supabase config + validation
│   ├── errors/app_exception.dart         AppErrorCodes + AppException.from()
│   ├── theme/app_theme.dart              light theme only
│   ├── utils/                            json, validators, formatters
│   └── widgets/                          10 shared presentational widgets
├── data/                             24
│   ├── models/                        7  account, device, pairing, remote_session, telemetry, audit, barrel
│   ├── repositories/                 11  contracts + Supabase implementations
│   └── services/                      6  supabase, edge_api, session, local_settings, connectivity, device_admin
└── features/                         95
    ├── app_restrictions/              3  parent policy editor (block lists, schedules)
    ├── audit_logs/                    3  audit read, retention, purge
    ├── auth/                         15  splash, login, register, verify-email, session flow
    ├── child/                        20  shell, enrollment, requests, session, 4 tabs
    ├── configuration/                 1  unconfigured-build gate
    ├── dashboard/                     2  parent dashboard tab
    ├── devices/                       6  device list + detail (revoke/recover/commands)
    ├── family/                        6  family setup, members, unlink
    ├── location/                      3  latest fix + point history
    ├── pairing/                       7  redeem/invite, requests, QR parser
    ├── parent_shell/                  3  4-tab parent shell
    ├── remote_assistance/             7  request list, session engine, registry, bindings
    ├── role_selection/                3  parent/child choice, role lock
    ├── safe_zones/                    3  geofence CRUD
    ├── safety_alerts/                 5  alerts list + realtime
    ├── screen_time/                   3  usage display + limit/bedtime
    └── settings/                      5  parent settings
```

Notes: there is **no** `lib/routes/`, `lib/l10n/`, `lib/logging/`, `lib/analytics/`, `lib/controllers/`, `lib/widgets/`, `lib/models/`, `lib/services/` — those names exist only inside `data/` or `features/`. `lib/features/child/views/` exists but is empty.

## 3. Android (`android/app/src/main/kotlin/com/parentcontrol/parent_control/`, 20 Kotlin files)

```
MainActivity.kt                       process-scoped FlutterEngine + channel attachment
NativeBridge.kt                       25 MethodChannel methods + EventChannel plumbing
NativeEventBus.kt                     service_status, location_update, command, audio events
NativePermissions.kt                  runtime permission probing/requests
SecureStore.kt                        EncryptedSharedPreferences: installation id, device secret
DeviceHttpClient.kt                   HTTPS-only device-authenticated transport
GuardianService.kt                    dataSync FGS: 10s tick, 20s poll, heartbeat, uploads
AudioAssistanceService.kt             microphone FGS, watchdogs, parent-end poll, notification
LocationTrackingService.kt            location FGS, GPS+NETWORK
BootReceiver.kt                       BOOT_COMPLETED / MY_PACKAGE_REPLACED (API<35 only)
UsageReporter.kt                      UsageStatsManager aggregation
InstalledApps.kt                      PackageManager inventory
LiveState.kt                          in-process state shared with the service
PolicyApplier.kt                      Device Owner setPackagesSuspended (DO-gated)
ParentControlDeviceAdminReceiver.kt   device-admin receiver (never Device Owner by itself)
JsonConvert.kt, TimeUtils.kt          helpers
policy/PolicyModels.kt                policy JSON model
policy/PolicyJson.kt                  parsing
policy/PolicyEvaluator.kt             pure evaluation of rules/schedules (JVM-tested)
```

Android resources/manifests: `android/app/src/main/AndroidManifest.xml` (3 FGS: dataSync/location/microphone; exported MainActivity + device-admin receiver), `res/xml/device_admin.xml` (no policies requested). `android_dpc/` contains no source.

## 4. Backend (`supabase/`)

```
supabase/
├── migrations/ (10)
│   ├── 20260101000000_core.sql                      19 tables, constraints, indexes, immutability triggers
│   ├── 20260101000100_functions.sql                38 SQL functions
│   ├── 20260101000200_rls.sql                       22 policies + private.is_family_* helpers
│   ├── 20260101000300_service_role_grants.sql       anon = zero grants
│   ├── 20260101000400_device_recovery.sql           request_device_recovery
│   ├── 20260101000500_child_contact_ids.sql         permanent Child ID
│   ├── 20260101000600_atomic_pairing_invite.sql     atomic invite/request
│   ├── 20261028000100_remote_session_concurrency.sql advisory lock + one active session
│   ├── 20261028000200_parent_controlled_session_lifetime.sql nullable expiry, guard, pending-only sweep
│   └── 20261028000300_signaling_open_session.sql    webrtc_signals RLS without expiry
├── functions/ (9 + _shared)
│   ├── auth-bootstrap/     role assignment/lock
│   ├── cron/               externally-invoked maintenance
│   ├── device-command/     command create/ack, policy status
│   ├── device-policy/      policy update (parent) — no device-side fetch of latest
│   ├── device-register/    device registration/credential
│   ├── device-telemetry/   heartbeat, usage, location, geofence evaluation
│   ├── family-admin/       members, retention, purge
│   ├── pairing/            invite/redeem/respond
│   ├── remote-session/     request/accept/start/media/ice/end (STALE HOSTED BUILD)
│   └── _shared/            audit, auth, cors, enrollment, envelope, policy, rate_limit, turn, validation (+ tests)
└── tests/ (11 SQL suites + 2 race scripts)
```

## 5. Tests and evidence

- `test/` + `integration_test/` + `supabase/tests/` = 55 files (Dart/Kotlin-adjacent Dart/TS/SQL). Latest recorded run: 275 Flutter tests pass, analyze clean, 47 Deno pass, Kotlin blocked by the cross-drive Gradle issue.
- `docs/evidence/stage8/` holds the real two-device runtime artifacts (screenshots, dumpsys captures, F1 expiry evidence, media proof).
- SQL suites cover schema, RLS, functions, recovery, realtime policy, pairing race, session concurrency, lifetime, signaling.

## 6. Module ownership summary

| Concern | Owner | Notes |
|---|---|---|
| UI, navigation, state | Flutter `features/*` + GetX | 26 routes, no guards |
| Backend access | Flutter `data/*` | user JWT for PostgREST; Edge Functions for writes |
| Capture/background | Kotlin services | mic, location, guardian, boot |
| Enforcement | Kotlin `PolicyApplier` | Device Owner only |
| Identity | `SecureStore` + `DeviceHttpClient` | device secret, HTTPS, no pinning |
| Policy/session truth | Postgres + Edge Functions | 19 tables, 9 functions |
| Media | flutter_webrtc + `webrtc_signals` | one-way, no TURN |
| Notifications | none | no FCM/local delivery |

Structural red flags: two enforcement halves that can disagree (Dart policy editor vs Kotlin applier), four dead Dart write paths, and the missing scheduled-maintenance layer (`pg_cron` absent) — all detailed in `10_GAP_ANALYSIS_AND_PRIORITIES.md`.