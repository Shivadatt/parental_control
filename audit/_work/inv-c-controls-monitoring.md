# Controls & monitoring inventory (subagent 8) findings

Scope A–G: Instant Block, Downtime, App Management, Notifications Monitoring,
Social Content Detection, Inappropriate Image Detection, Calls & SMS.
One row per subfeature, brief row format, brief status vocabulary.

## 1. Scope actually covered (files/dirs read; anything skipped and why)

Read in full or in the cited ranges:

- `android/app/src/main/AndroidManifest.xml` (all 131 lines), `android/app/src/main/res/xml/device_admin.xml`.
- Kotlin: `ParentControlDeviceAdminReceiver.kt`, `PolicyApplier.kt`, `policy/PolicyModels.kt`,
  `policy/PolicyEvaluator.kt`, `policy/PolicyJson.kt`, `GuardianService.kt`, `NativeBridge.kt`,
  `BootReceiver.kt`, `NativePermissions.kt`, `UsageReporter.kt`, `InstalledApps.kt`, `TimeUtils.kt`,
  `SecureStore.kt` (policy/state accessors only), `android/app/src/test/.../PolicyEvaluatorTest.kt`.
- Flutter: `lib/features/app_restrictions/*` (page 897 lines, controller 505 lines),
  `lib/features/screen_time/*` (page, controller), `lib/features/safety_alerts/*`,
  `lib/features/configuration/configuration_page.dart`, `lib/features/settings/*`,
  `lib/features/child/controllers/child_shell_controller.dart` (all 1121 lines),
  `lib/features/child/child_restrictions_page.dart`, `child/tabs/child_settings_tab.dart` (grep + cited ranges),
  `child/widgets/policy_summary_card.dart`, `child/models/child_enforcement.dart`,
  `lib/data/models/device.dart` (all 818 lines), `lib/data/models/telemetry.dart` (alert enum),
  `lib/data/services/device_admin_service.dart`, `lib/data/repositories/supabase_policy_repository.dart`,
  `supabase_alert_repository.dart`, `lib/app/routes/app_routes.dart`, `pubspec.yaml`.
- Backend: `supabase/migrations/20260101000000_core.sql` (tables), `20260101000100_functions.sql`
  (policy/command/apps/offline functions), `20260101000200_rls.sql` (policy names),
  `supabase/functions/device-policy/index.ts`, `device-command/index.ts`,
  `device-telemetry/index.ts`, `_shared/policy.ts`, `family-admin/index.ts` (ack path).
- Evidence: `docs/app-restrictions.md`, `docs/verification-report.md` (policy sections),
  `docs/device-owner-provisioning.md` (grep), `docs/bug-report.md` (grep), `docs/integrations-setup.md` (grep),
  `integration_test/parent_ui_journey_test.dart` (grep), unit tests under `test/features/`.
- `android_dpc/` exists but is an **empty directory** — no DPC module to audit.

Repo-wide negative searches (no hits for any of these): `Accessibility`, `NotificationListener`,
`MediaStore`, `ContentObserver`, `Telephony`, `SmsManager`, `READ_SMS`, `READ_CALL_LOG`, `CALL_PHONE`,
`ROLE_SMS`, `overlay`, `SYSTEM_ALERT_WINDOW`, `keyword`, `nsfw`, `inappropriate`, `gallery`, `tiktok`,
`snapchat`, `firebase`, `fcm`, `ROLE_DIALER`. Results drive the D–G rows.

Skipped: hosted Supabase dashboard state (other subagent's scope); any `supabase …` CLI command
(forbidden); runtime device execution (read-only audit).

## 2. Findings

### 2.1 Inventory table — A. Instant Block

| ID | AirDroid category | Subfeature | UI route/screen | Flutter files:line | Kotlin/service/permission | Table/function/RLS | Connected? | Tests | Runtime evidence | STATUS | Gap + risk + priority |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F-A01 | Instant Block | Immediate app blocking (single app toggle) | /parent/app-restrictions (lib/app/routes/app_routes.dart:17) | app_restrictions_page.dart:321-380; app_restrictions_controller.dart:241-268,375-412 | PolicyApplier.kt:31-153,236-244; GuardianService.kt:267-282 | device_policies core.sql:176-189; apply_policy_version functions.sql:86-184 | yes | test/features/app_restrictions/app_restrictions_controller_test.dart:43-110; PolicyEvaluatorTest.kt:134-152 | docs/verification-report.md:71,203-208 | IMPLEMENTED — PARTIALLY VERIFIED | Suspension never executed on hardware; blocking policy acked failed (verification-report.md:206-208). "Instant" is ≤20 s poll + 60 s tick, not instant. P0 |
| F-A02 | Instant Block | Block all restricted apps (block all except allowed) | /parent/app-restrictions card | app_restrictions_page.dart:411-448; controller:212-222,294-296 | PolicyApplier.kt:76-92 skips isSystem; PolicyModels.kt:67-76 | device_policies.policy jsonb core.sql:181 | yes | PolicyEvaluatorTest.kt:83-91 | — | CODE EXISTS — NOT TESTED | Block-all loop never exercised at runtime; system apps are skipped so it is not literally "all"; no automatic launcher whitelist. P1 |
| F-A03 | Instant Block | Always-allowed apps | /parent/app-restrictions allowed list + picker | app_restrictions_page.dart:483-523,655-744; controller:275-292 | PolicyModels.kt:67-76 (rule wins; allowed only in block-all) | policy.allowed_packages core.sql:181 | yes | PolicyEvaluatorTest.kt:93-108 | — | CODE EXISTS — NOT TESTED | Allowed list only matters when block_all_except_allowed is on (page:484-487); a blocked app rule overrides it. Not a true "always allowed". P1 |
| F-A04 | Instant Block | Parent command delivery | Save restrictions + Request device sync (page:216-243) | controller:375-451; supabase_policy_repository.dart:33-61,80-108 | GuardianService.kt:37,208,226-238,240-348 | device_commands core.sql:196-219; poll_device_commands functions.sql:596-651 | yes | integration_test/parent_ui_journey_test.dart:1096-1275 | verification-report.md:71,575,801 | IMPLEMENTED — PARTIALLY VERIFIED | Poll-only (20 s, backoff to 300 s). apply_policy TTL is 900 s (functions.sql:174), so an offline child can permanently miss a saved policy. P0 |
| F-A05 | Instant Block | Child enforcement (real mechanism) | /child/restrictions (app_routes.dart:29) | device_admin_service.dart:82-96; child_shell_controller.dart:502-568 | PolicyApplier.kt:94-133,209-254; ParentControlDeviceAdminReceiver.kt:1-18 | device_policies.enforcement_status core.sql:185-187 | yes | PolicyEvaluatorTest.kt only (pure logic) | verification-report.md:604-612,862-874 (dpm list-owners: no owners) | IMPLEMENTED — PARTIALLY VERIFIED | Real suspension requires Device Owner; ack "enforced" is possible with an empty desired set on a non-owner device (PolicyApplier.kt:94-101,137). Real suspension = BLOCKED — ACCESS REQUIRED. P0 |
| F-A06 | Instant Block | Realtime sync | /parent/app-restrictions policy state card | controller:453-480 (5 s x6 poll); no channel in supabase_policy_repository.dart | — | Realtime publication covers safety_alerts only (functions.sql:917-925) | partial | controller tests 43-110 (state only) | verification-report.md:575 | PARTIALLY IMPLEMENTED | No Realtime for device_policies/device_commands; parent sees acknowledgement at best ~30 s later, and only while the screen is open. P2 |
| F-A07 | Instant Block | Offline behaviour | Offline banner page:81-92; save/queue copy:138-146 | controller:147-151,375-392 | SecureStore.kt:162-176; GuardianService.kt:184-193,283-298 | none (device-local cache) | partial | — | — | CODE EXISTS — NOT TESTED | Stored policy is re-applied every 60 s without network, but sync_policy replays the *stale* stored JSON (GuardianService.kt:283-298). No device-side fetch of the latest version (device-policy/index.ts:44-48). P0 |
| F-A08 | Instant Block | Scheduled / temporary block | Add schedule dialog page:545-562,618-639,746-872 | controller:309-373; device.dart:4-53 | PolicyModels.kt:4-35; PolicyApplier.kt:42-52 | policy.app_rules.windows core.sql:181 | yes | PolicyEvaluatorTest.kt:12-81 | — | PARTIALLY IMPLEMENTED | Per-app windows exist and are pure-tested; there is no temporary timed block ("block for 1 h"), and window edges only move on the 60 s guardian tick or the next app open. P1 |
| F-A09 | Instant Block | Emergency recovery | Child unlink (child_settings_tab.dart:315-324); parent removes blocks page:450-481 | child_shell_controller.dart:1012-1062 | NativeBridge.kt:381-396; PolicyApplier.kt:186-207 restoreAll | local only; no "unblock" command type core.sql:200-202 | yes | child_shell_controller_test.dart:456 (unlink path) | — | PARTIALLY IMPLEMENTED | Only local restore (unlink/sign-out/policy change). No parent-side emergency unblock command; restore needs Device Owner and the child app alive. P1 |
| F-A10 | Instant Block | Reboot persistence | — | — | BootReceiver.kt:17-52; AndroidManifest.xml:106-114; GuardianService.kt:129-135 | none | partial | — | — | PARTIALLY IMPLEMENTED | Android 15+ explicitly refuses the dataSync FGS at boot (BootReceiver.kt:31-37); nothing re-applies policy until the app is opened; scheduled windows freeze. P1 |
| F-A11 | Instant Block | Android enforcement mechanism | Child rules screen banner | — | PolicyApplier.kt:16-28,209-254; device_admin.xml:1-6; manifest:94-104 | DevicePolicyManager only | yes | PolicyEvaluatorTest.kt:154-180 | verification-report.md:862-874 | IMPLEMENTED — PARTIALLY VERIFIED | No accessibility service, no overlay, no device-admin lock. Play-Store install cannot block anything; only setPackagesSuspended on a managed device. P0 |
| F-A12 | Instant Block | Bypass resistance | /child/settings (unlink + device admin tiles) | child_shell_controller.dart:1012-1062 | NativeBridge.kt:381-396; device_admin.xml:2-5 (no policies requested) | — | partial | — | — | PARTIALLY IMPLEMENTED | The child can unlink from the family and every suspension is restored (NativeBridge.kt:386); force-stop freezes schedule evaluation; no uninstall protection or tamper alert. P0 |
| F-A13 | Instant Block | Permissions | /child/restrictions permissions card:185-234; device detail:330-340 | child_shell_controller.dart:828-840; device_admin_service.dart:201-226 | NativePermissions.kt:34-55; manifest:4-29 | devices.*_granted core.sql:95-103 | yes | integration_test/device_capabilities_test.dart | verification-report.md:203-208 | IMPLEMENTED — PARTIALLY VERIFIED | Device Owner is manual adb/factory-reset provisioning; QUERY_ALL_PACKAGES is Play-policy restricted (manifest:24-29); no monitoring permissions requested at all. P2 |

### 2.2 Inventory table — B. Downtime (screen-time limits / bedtime)

| ID | AirDroid category | Subfeature | UI route/screen | Flutter files:line | Kotlin/service/permission | Table/function/RLS | Connected? | Tests | Runtime evidence | STATUS | Gap + risk + priority |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F-B01 | Downtime | Start/end schedule (bedtime) | /parent/screen-time (app_routes.dart:18) | screen_time_page.dart:260-442,363-407; screen_time_controller.dart:39-41,286-320,322-361 | PolicyApplier.kt:297-298 (bedtime explicitly informational); PolicyModels.kt:44-60 | policy.bedtime_start_minutes/end_minutes core.sql:181; validation policy.ts:55-57 | no | screen_time_controller_test.dart:114 (state only); PolicyEvaluatorTest.kt:183-205 | — | BACKEND ONLY | Bedtime is saved, echoed in the child card (policy_summary_card.dart:120-128) and never enforced; the child screen says so (child_restrictions_page.dart:295-301). P0 |
| F-B02 | Downtime | Multiple downtime schedules | — | screen_time_controller.dart:39-41 (single pair) | PolicyModels.kt:44-60 (single window) | policy jsonb core.sql:181 | no | — | — | MISSING | Only one bedtime window per device; no list of downtime periods. P1 |
| F-B03 | Downtime | Weekday / weekend schedules | — | screen_time_page.dart:363-407 (no day chips) | PolicyModels.kt:44-60 (no days) | policy.ts:55-57 (no day fields) | no | — | — | MISSING | No day-of-week selection for downtime; per-app windows have days (PolicyModels.kt:4-22) but that is a different feature. P1 |
| F-B04 | Downtime | Time zones | — | TimeUtils.kt:69-103 (device-local only) | — | usage_daily.day is a child-local date string | no | — | — | MISSING | Everything is the child's wall clock; no timezone field, display or override, so a parent in another zone cannot predict windows. P2 |
| F-B05 | Downtime | Device-local scheduling (app windows) | App restrictions schedule dialog | device.dart:20-32; app_restrictions_page.dart:746-872 | PolicyWindow.isActiveAt PolicyModels.kt:11-21; PolicyApplier.kt:42-44 | app_rules.windows | yes | PolicyEvaluatorTest.kt:12-41 | — | PARTIALLY IMPLEMENTED | Windows use device Calendar local time with midnight wrap and are JVM-tested; no device runtime test of an edge; downtime does not use this path. P1 |
| F-B06 | Downtime | Location-based schedules | — | — | — | — | no | — | — | MISSING | No geofence-driven policy or schedule; safe_zones only raise alerts (device-telemetry/index.ts:300-350). P2 |
| F-B07 | Downtime | Always-allowed apps during downtime | — | screen_time_controller.dart (no app list) | PolicyModels.kt:67-76 (allowed list is block-all only) | policy.allowed_packages core.sql:181 | no | — | — | MISSING | Allowed packages never affect bedtime because bedtime is not enforced and has no app list. P1 |
| F-B08 | Downtime | Parent override (pause / extend) | — | screen_time_page.dart:112-119 (save only) | device_commands has no override type core.sql:200-202 | device_commands | no | — | — | MISSING | No temporary lift, snooze or "5 more minutes"; the parent can only rewrite the whole policy (new version). P1 |
| F-B09 | Downtime | Realtime updates | /parent/screen-time policy card | screen_time_controller.dart:380-407 (5 s x6) | — | no Realtime on device_policies | partial | screen_time_controller_test.dart:114 | verification-report.md:575 | PARTIALLY IMPLEMENTED | Polling only; there is no push, so a bedtime change lands ≤20 s + 60 s tick at best. P2 |
| F-B10 | Downtime | Offline enforcement | Offline banner page:59-68 | screen_time_controller.dart:195-199 | PolicyApplier.kt:184-193 | local policy cache SecureStore.kt:162 | no | — | — | MISSING | Offline the child re-applies stored app blocks only; bedtime and daily limit have no offline (or online) enforcement. P1 |
| F-B11 | Downtime | Reboot behaviour | — | — | BootReceiver.kt:17-52 | — | partial | — | — | PARTIALLY IMPLEMENTED | Service restart is best-effort and refused on Android 15+ (BootReceiver.kt:31-37); downtime has nothing to restore. P1 |
| F-B12 | Downtime | Conflicts between rules | — | device.dart:141-153 | PolicyModels.kt:62-76 (rule beats lists) | — | partial | PolicyEvaluatorTest.kt:49-63,93-108 | — | PARTIALLY IMPLEMENTED | Only app-rule vs package-list precedence is defined and tested; bedtime vs daily limit vs block-all interactions are undefined. P2 |
| F-B13 | Downtime | DST / time change | — | device.dart:20-32; TimeUtils.kt:91-103 | Calendar.getInstance() each tick PolicyApplier.kt:42 | — | partial | — | — | CODE EXISTS — NOT TESTED | Windows follow wall-clock minutes so DST shifts window edges silently; no test, no warning, and a stalled tick can leave a block active past its window. P2 |

### 2.3 Inventory table — C. App Management

| ID | AirDroid category | Subfeature | UI route/screen | Flutter files:line | Kotlin/service/permission | Table/function/RLS | Connected? | Tests | Runtime evidence | STATUS | Gap + risk + priority |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F-C01 | App Management | Installed app list | /parent/app-restrictions installed apps card:321-380 | controller:83-91,104-107,138-183 | InstalledApps.kt:14-42; GuardianService.kt:40,217-219,396-422 | device_apps core.sql:395-407; replace_device_apps functions.sql:654-703 | yes | controller test:43-75 | verification-report.md:203-208 | IMPLEMENTED — PARTIALLY VERIFIED | Snapshot only every 30 min (GuardianService.kt:40); no on-demand refresh command is exposed in UI; empty snapshot is handled honestly (page:336-344). P2 |
| F-C02 | App Management | Usage (per app, per day) | /parent/screen-time usage card:188-258 | screen_time_controller.dart:98-131,233-255; screen_time_page.dart:229-255 | UsageReporter.kt:21-86; GuardianService.kt:41,220-222,424-456 | usage_daily core.sql:228-243 | yes | screen_time_controller_test.dart:43-113 | verification-report.md:203-208 (32 usage rows uploaded) | IMPLEMENTED — PARTIALLY VERIFIED | Relies on Usage Access; hourly upload; totals aggregate per package, no per-app history drill-down. P2 |
| F-C03 | App Management | Per-app restrictions | /parent/app-restrictions switch list:354-367 | controller:241-273; page:450-481 | PolicyApplier.kt:50-74,103-117 | policy.blocked_packages/app_rules core.sql:181 | yes | controller test:111; PolicyEvaluatorTest.kt | verification-report.md:71,204-208 | IMPLEMENTED — PARTIALLY VERIFIED | Same Device Owner dependency as F-A01; real suspension never observed; system-critical packages silently reported unsupported (PolicyApplier.kt:58-68). P0 |
| F-C04 | App Management | Per-app daily limits | — | — | — | — | no | — | — | MISSING | Only a global daily limit exists, and it is unenforced (F-B01). No per-app minute cap, no usage-based auto-block. P1 |
| F-C05 | App Management | App schedules | App restrictions schedule chips:618-639 | controller:309-373; device.dart:4-53 | PolicyModels.kt:4-35 | app_rules.windows | yes | PolicyEvaluatorTest.kt:12-81 | — | PARTIALLY IMPLEMENTED | Windows are pure-tested only; switching depends on the 60 s tick, and a stopped service leaves the last suspend state in place. P1 |
| F-C06 | App Management | Always-allowed apps | Allowed apps list:483-523 | controller:275-292 | PolicyModels.kt:67-76 | policy.allowed_packages | yes | PolicyEvaluatorTest.kt:93-108 | — | CODE EXISTS — NOT TESTED | Not a standalone whitelist: it is inert unless block-all is on, and app rules override it. P1 |
| F-C07 | App Management | Auto-block new apps | — | — | PolicyApplier.kt:76-92 re-evaluated each 60 s tick | device_policies only | partial | PolicyEvaluatorTest.kt:83-91 (predicate) | — | CODE EXISTS — NOT TESTED | New installs are only caught if block_all_except_allowed is on and the guardian tick runs; no immediate reaction; system apps exempt. P1 |
| F-C08 | App Management | New-install detection | — | — | no PACKAGE_ADDED receiver (manifest:94-114) | no install event table | no | — | — | MISSING | A newly installed app is invisible to the parent until the next 30 min snapshot; no alert exists. P1 |
| F-C09 | App Management | Policy changes / versioning | Policy state card:249-319 | controller:375-428,482-504 | GuardianService.kt:267-282; ack path device-command/index.ts:318-351 | device_policies.version unique core.sql:188; apply_policy_version functions.sql:147-158 | yes | controller test:75-110; journey test:1113-1275 | verification-report.md:71,575 | IMPLEMENTED — PARTIALLY VERIFIED | Version + idempotency are solid; ack marks "enforced" on success only, but success can be empty-set (F-A05). P1 |
| F-C10 | App Management | Child enforcement + verification display | /child/restrictions:100-108,124-183 | child_shell_controller.dart:488-568; child_enforcement.dart:9-38 | PolicyApplier.kt:209-220 (isSuspended) | devices.enforcement_mode core.sql:97-99 | yes | child_shell_controller_test.dart (verification cases) | verification-report.md:862-874 | IMPLEMENTED — PARTIALLY VERIFIED | Verification only works when Device Owner; otherwise the app honestly shows "not verified" — good, but the enforcement itself is the same unexercised path. P0 |
| F-C11 | App Management | Usage sync | Screen time upload card:154-186 | screen_time_controller.dart:233-255; app_restrictions_controller.dart:430-451 | GuardianService.kt:220-222 hourly; request_usage handler:299-307 | usage_daily upsert device-telemetry/index.ts:157-237 | yes | screen_time_controller_test.dart:43-83 | verification-report.md:203-208 | IMPLEMENTED — PARTIALLY VERIFIED | Parent has no "request usage now": request_usage exists in the model (device.dart:438-444) but is never created by any UI. P2 |
| F-C12 | App Management | Uninstall detection | — | — | GuardianService.kt:396-422 (snapshot upload) | replace_device_apps deletes the whole snapshot then inserts (functions.sql:677-699) | partial | — | — | PARTIALLY IMPLEMENTED | An uninstalled app disappears at the next snapshot; no event, no alert, and a still-blocked package that was uninstalled is only cleaned up on the next tick. P2 |
| F-C13 | App Management | Permission / API limitations | Child permissions card:185-234 | device_admin_service.dart:74-80,244-268 | NativePermissions.kt:34-55; manifest:21-29 | device_apps, usage_daily | partial | integration_test/device_capabilities_test.dart | verification-report.md:203-208 | IMPLEMENTED — PARTIALLY VERIFIED | Usage Access must be granted manually; QUERY_ALL_PACKAGES is Play-restricted; AppOps/Usage data can be stale on some OEMs (untested). P2 |

### 2.4 Inventory table — D. Notifications Monitoring

| ID | AirDroid category | Subfeature | UI route/screen | Flutter files:line | Kotlin/service/permission | Table/function/RLS | Connected? | Tests | Runtime evidence | STATUS | Gap + risk + priority |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F-D01 | Notifications | Notification listener integration | — | — | No NotificationListenerService: manifest declares only Guardian, Location, Audio (AndroidManifest.xml:78-92) | — | no | — | — | MISSING | POST_NOTIFICATIONS (manifest:11) is the app's own foreground-service notification, not a listener grant. P1 |
| F-D02 | Notifications | Notification collection | — | — | none; no BIND_NOTIFICATION_LISTENER_SERVICE in manifest:41-121 | no table in core.sql:17-425 | no | — | — | MISSING | Nothing is captured from other apps' notifications. P1 |
| F-D03 | Notifications | Parent timeline | — | — | — | no notification table; alerts limited to battery/offline/geofence (core.sql:302-303) | no | — | — | MISSING | Alerts tab shows only those three generated types (alerts_body.dart:74-86); app_blocked/permission_missing are allowed in SQL but never generated. P1 |
| F-D04 | Notifications | Per-app notification filtering | — | — | — | — | no | — | — | MISSING | No filter model, no policy key (policy.ts:49-58 lists every accepted policy field). P2 |
| F-D05 | Notifications | Mute apps | — | — | — | — | no | — | — | MISSING | No mute list anywhere in policy or settings. P2 |
| F-D06 | Notifications | Block from notification context | — | — | — | — | no | — | — | MISSING | No notification action/intent handler exists (manifest intent-filters:62-75 only MAIN and auth callback). P2 |
| F-D07 | Notifications | Sync to parent | — | — | — | — | no | — | — | MISSING | No notification payloads uploaded; device-telemetry actions are heartbeat/usage/location/apps only (device-telemetry/index.ts:64-430). P1 |
| F-D08 | Notifications | Privacy / consent for notification data | — | — | — | — | no | — | — | MISSING | No monitoring disclosure or consent screen; only remote-session consent exists. P2 |
| F-D09 | Notifications | Retention | — | — | — | — | no | — | — | MISSING | No notification storage means no retention policy to audit. P3 |
| F-D10 | Notifications | Permission revocation / recovery | — | — | NativePermissions.kt:34-55 has no listener-access check | — | no | — | — | MISSING | No special-access grant flow, no detection that the listener was revoked (nothing to revoke). P2 |

### 2.5 Inventory table — E. Social Content Detection

| ID | AirDroid category | Subfeature | UI route/screen | Flutter files:line | Kotlin/service/permission | Table/function/RLS | Connected? | Tests | Runtime evidence | STATUS | Gap + risk + priority |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F-E01 | Social detection | Supported app detection (WhatsApp/Instagram/etc.) | — | — | no detection code (repo-wide search for whatsapp/tiktok/snapchat finds only a test constant PolicyEvaluatorTest.kt:87) | no table | no | — | — | MISSING | Only Instagram has a block shortcut (app_restrictions_controller.dart:19-20,298-307); nothing detects social apps for monitoring. P1 |
| F-E02 | Social detection | App detection management (choose monitored apps) | — | — | — | policy.ts:49-58 has no monitored-app key | no | — | — | MISSING | No UI, no policy field, no server validation path for monitored apps. P1 |
| F-E03 | Social detection | Keyword management | — | — | — | — | no | — | — | MISSING | Search for "keyword" returns zero hits across lib, android, supabase, test. P1 |
| F-E04 | Social detection | Keyword matching engine | — | — | — | — | no | — | — | MISSING | No matcher, no locale handling, no false-positive controls. P1 |
| F-E05 | Social detection | Message-content source | — | — | No AccessibilityService in manifest:78-114 | no message/content table | no | — | — | MISSING | Without accessibility or a notification listener there is no legal source for message text. P1 |
| F-E06 | Social detection | Alert generation | — | — | — | safety_alerts.type lacks a content type (core.sql:302-303) | no | — | — | MISSING | Content alerts cannot even be stored: the enum check rejects them. P1 |
| F-E07 | Social detection | Alert display | Safety alerts tab (alerts_body.dart:98-106) | telemetry.dart:205-247 | — | — | no | safety_alerts_controller_test.dart | — | MISSING | The display exists but only for battery/offline/geofence types; no content alert can reach it. P2 |
| F-E08 | Social detection | False-positive handling | — | — | — | — | no | — | — | MISSING | No review/dismiss/feedback loop because no detector exists. P2 |
| F-E09 | Social detection | Android version behaviour | — | — | — | — | no | — | — | MISSING | No version gating; accessibility policies differ sharply by OEM/version and are unaddressed. P2 |
| F-E10 | Social detection | Accessibility requirement | — | — | No AccessibilityService or BIND_ACCESSIBILITY_SERVICE (manifest:41-121) | — | no | — | — | MISSING | The most viable Android source for message text is absent; docs explicitly rule it out (docs/app-restrictions.md:55-56). P1 |
| F-E11 | Social detection | Privacy / consent | — | — | — | — | no | — | — | MISSING | No consent or disclosure for content monitoring; app only collects app list, usage, location. P2 |
| F-E12 | Social detection | Backend storage | — | — | — | no content/message table in core.sql:17-425 | no | — | — | MISSING | 17 tables total; none stores notifications, messages, keywords or content matches. P1 |
| F-E13 | Social detection | Delivery to parent | — | — | — | Realtime channel exists for safety_alerts only (functions.sql:917-925) | no | — | — | MISSING | No push transport at all (no FCM/Firebase dependency in pubspec.yaml:30-46); delivery would be in-app only. P2 |

### 2.6 Inventory table — F. Inappropriate Image Detection

| ID | AirDroid category | Subfeature | UI route/screen | Flutter files:line | Kotlin/service/permission | Table/function/RLS | Connected? | Tests | Runtime evidence | STATUS | Gap + risk + priority |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F-F01 | Image detection | New-image detection | — | — | No ContentObserver/MediaStore code (repo-wide search) | — | no | — | — | MISSING | Nothing observes the gallery or camera roll. P1 |
| F-F02 | Image detection | Gallery monitoring | — | — | — | — | no | — | — | MISSING | No READ_MEDIA_IMAGES/READ_EXTERNAL_STORAGE in manifest:4-29 (scoped storage would also block broad reads on Android 13+). P1 |
| F-F03 | Image detection | Image processing pipeline | — | — | — | — | no | — | — | MISSING | No thumbnailing, hashing or staging code. P2 |
| F-F04 | Image detection | Detection engine / classification | — | — | — | — | no | — | — | MISSING | No on-device model, no cloud classifier call, no vendor SDK. P1 |
| F-F05 | Image detection | Alerts on detection | — | — | — | safety_alerts has no image type (core.sql:302-303) | no | — | — | MISSING | Same enum gap as F-E06; an image alert could not be inserted. P1 |
| F-F06 | Image detection | False-positive handling | — | — | — | — | no | — | — | MISSING | No detector, so no review surface or thresholds. P2 |
| F-F07 | Image detection | Retention of flagged images | — | — | — | no Storage bucket use in app code | no | — | — | MISSING | No image storage or deletion policy. P2 |
| F-F08 | Image detection | Local vs cloud processing | — | — | — | — | no | — | — | MISSING | Neither path exists; privacy trade-off never designed. P2 |
| F-F09 | Image detection | Permissions | — | — | CAMERA (manifest:9) is used only for remote video assistance; no media-read permission | — | no | — | — | MISSING | Without media permissions gallery scanning is impossible; camera access alone cannot see existing photos. P1 |
| F-F10 | Image detection | Privacy / consent | — | — | — | — | no | — | — | MISSING | No disclosure for image analysis; children are never informed (contrast remote-session consent). P2 |

### 2.7 Inventory table — G. Calls & SMS Monitoring

| ID | AirDroid category | Subfeature | UI route/screen | Flutter files:line | Kotlin/service/permission | Table/function/RLS | Connected? | Tests | Runtime evidence | STATUS | Gap + risk + priority |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F-G01 | Calls & SMS | Incoming call detection | — | — | No PHONE_STATE receiver or InCallService; manifest receivers are device-admin and boot only (manifest:94-114) | no call table | no | — | — | MISSING | No telephony permission requested (manifest:4-29). P1 |
| F-G02 | Calls & SMS | Call blacklist / whitelist | — | — | No ROLE_DIALER, no call-screening service | no contact/blocklist table (child_contact_ids is for pairing only, child_contact_ids.sql:18) | no | — | — | MISSING | Blocking calls requires ROLE_DIALER + InCallService; neither is requested. P1 |
| F-G03 | Calls & SMS | SMS detection | — | — | No READ_SMS or SMS_RECEIVED receiver | no message table | no | — | — | MISSING | On Android 4.4+ full SMS access requires the default-SMS role; the app does not request it. P1 |
| F-G04 | Calls & SMS | SMS keyword detection | — | — | — | — | no | — | — | MISSING | No keyword system at all (F-E03). P1 |
| F-G05 | Calls & SMS | Alerts for calls/SMS | — | — | — | safety_alerts type check excludes call/SMS types (core.sql:302-303) | no | — | — | MISSING | Alerts tab could not display such an alert even if generated (alerts_body.dart:302-319 icon switch). P1 |
| F-G06 | Calls & SMS | Parent notification of events | Alerts tab only (in-app) | safety_alerts_controller.dart:78-93 | — | safety_alerts Realtime | no | safety_alerts_controller_test.dart | — | MISSING | No push notifications anywhere (pubspec.yaml:30-46); a parent would only see an alert with the app open. P2 |
| F-G07 | Calls & SMS | Permissions for call/SMS monitoring | — | — | No READ_CALL_LOG/READ_PHONE_STATE/SEND_SMS in manifest:4-29 | — | no | — | — | MISSING | All telephony permissions absent; Play restricts these to default handlers. P1 |
| F-G08 | Calls & SMS | Default-SMS-app restrictions | — | — | — | — | no | — | — | NOT APPLICABLE | No SMS feature exists, so no default-SMS role is requested. Platform fact: reading SMS bodies needs the user-chosen default SMS app (Android 4.4+), which a parental-control app cannot hold simultaneously with the real messaging app. P3 |
| F-G09 | Calls & SMS | Android version limits | — | — | — | — | no | — | — | MISSING | No version gating exists because no feature exists; call screening needs API 24+ InCallService, ROLE_SMS/ROLE_DIALER arrive with API 29, and Android 10+ restricts background call/SMS access further. P2 |
| F-G10 | Calls & SMS | Device compatibility | — | — | — | — | no | — | — | MISSING | No OEM/dual-SIM handling, no capability reporting for telephony; heartbeat capabilities cover only permissions and enforcement mode (GuardianService.kt:365-394). P2 |

### 2.8 Prose — what the evidence actually shows

**A. Instant Block.** The only real enforcement mechanism in the repository is
`DevicePolicyManager.setPackagesSuspended` (`PolicyApplier.kt:236-244`), gated on
`isDeviceOwnerApp` (`PolicyApplier.kt:222-227`). There is **no** AccessibilityService,
overlay, `SYSTEM_ALERT_WINDOW`, app-usage polling loop or device-admin lock task in the
manifest or Kotlin sources (`AndroidManifest.xml:78-114` lists exactly three services and two
receivers). Consequently a normal Play-Store install cannot block anything, and the parent UI
says so (`app_restrictions_page.dart:126-136`; `docs/app-restrictions.md:16-18`).

The policy path itself is coherent and honest about state: policy validation
(`functions/policy.ts:158-...`), atomic version + command creation (`functions.sql:86-184`),
device poll/ack (`functions.sql:596-651`, `device-command/index.ts:224-364`), and a status
machine that shows Pending / Enforced / Failed / Unsupported
(`app_restrictions_controller.dart:482-504`). Runtime evidence exists for the *transport*: a
benign policy v1 was acknowledged and enforced, and a blocking policy v2 was acknowledged as
`failed` with the Device Owner error (`docs/verification-report.md:71,203-208`). **Actual
suspension was never executed on any device** (`docs/verification-report.md:862-874`; no
Device Owner on the RMX2161), so every "blocking works" claim stays unverified.

Two correctness risks stand out. First, `apply()` returns `success = errors.isEmpty()`
(`PolicyApplier.kt:137`); on a non-Device-Owner phone whose blocked rules are currently outside
their windows, `desired` is empty, no error is raised (`PolicyApplier.kt:94-101`), the ack is
`succeeded`, and the server flips the policy to `enforced`
(`device-command/index.ts:318-351`) even though nothing can ever be suspended. Second, delivery
is poll-only with a 900-second command TTL (`functions.sql:174`); if the child is offline longer
than that, the policy row is only reachable by the parent saving a *new* version, because
`sync_policy` re-applies the locally stored JSON (`GuardianService.kt:283-298`) and the
`device-policy` function exposes only the parent `update` action (`device-policy/index.ts:44-48`).
The audit trail for the previous loss is recorded at `docs/verification-report.md:795-805`.

Bypass resistance is weak by design: the child can unlink the phone
(`child_settings_tab.dart:315-324`), which calls `clearBackgroundSync` → `restoreAll`
(`NativeBridge.kt:381-396`), restoring every suspended package without parent approval. A
force-stop stops the 60-second policy tick, freezing scheduled windows in their last state.
Boot persistence is best-effort and explicitly refused on Android 15+
(`BootReceiver.kt:31-37`).

**B. Downtime.** There is no downtime product, only two policy fields. `bedtime_start_minutes`
/ `bedtime_end_minutes` and `daily_screen_time_limit_minutes` are validated
(`policy.ts:55-57`), stored in `device_policies.policy` (`core.sql:181`), edited through the
Screen time page (`screen_time_page.dart:260-442`) and displayed on the child card
(`policy_summary_card.dart:91-101`) — but the native applier never consumes them:
`PolicyApplier.kt:297-298` calls bedtime "informational only", and no Kotlin file references
`dailyScreenTimeLimitMinutes` outside the model/parser. The child UI states this plainly
(`child_restrictions_page.dart:295-301`; `policy_summary_card.dart:120-128`). Therefore
downtime is **BACKEND ONLY**: stored and displayed, never enforced. There is exactly one
bedtime window (no multiple schedules, no weekday/weekend selection, no location-based
downtime, no per-app exceptions) and no parent override of any kind. Day/time handling is
device-local wall clock (`TimeUtils.kt:91-103`), so DST simply moves the window; nothing tests
that and nothing warns the parent.

**C. App Management.** Installed-app inventory and usage are real and wired to the device:
`InstalledAppsProvider` (`InstalledApps.kt:14-42`) uploads a snapshot every 30 minutes
(`GuardianService.kt:40,217-219`), and `UsageReporter` reads `UsageStatsManager`
(`UsageReporter.kt:21-86`) and uploads hourly (`GuardianService.kt:41,220-222,424-456`); the
server replaces the snapshot atomically (`functions.sql:654-703`). Both were observed live
(`docs/verification-report.md:203-208`). Where App Management falls short is per-app control
granularity: there are no per-app daily limits, no new-install detection (no `PACKAGE_ADDED`
receiver at `AndroidManifest.xml:94-114`), no uninstall event, and no on-demand usage refresh
in the UI — `request_usage`/`request_location` exist as command types
(`device.dart:438-444`) but no code path ever creates them (grep over `lib/` finds only the
enum/model). `block_all_except_allowed` incidentally auto-blocks newly installed apps at the
next tick (`PolicyApplier.kt:76-92`), which is the closest thing to "new app control".

**D–G. Monitoring families.** Notifications, social-content, image and call/SMS monitoring do
not exist in any layer. The Android manifest requests only internet, location, camera, mic,
notifications (own service), boot and usage/packages permissions (`AndroidManifest.xml:4-29`),
declares three services (`:78-92`) and two receivers (`:94-114`), and there is no
`NotificationListenerService`, `AccessibilityService`, `InCallService`, SMS receiver, or media
permission anywhere. The database has 17 tables and none stores notifications, messages,
keywords, images or call logs (`core.sql:17-425`); `safety_alerts.type` admits only
`low_battery`, `offline`, `geofence_enter`, `geofence_exit`, `app_blocked`,
`permission_missing`, `other` (`core.sql:302-303`), and only the first four are ever generated
(`device-telemetry/index.ts:121-148,323-350`; `functions.sql:531-573`). The policy schema
accepts exactly eight keys, all of them app-block or screen-time related (`policy.ts:49-58`),
so there is no server-side surface to configure monitoring either. The parent app has no
routes, tabs, settings or alert types for these features
(`app_routes.dart:11-31`; `parent_shell_page.dart:19-47`; `alerts_body.dart:302-319`), and no
push transport exists at all (`pubspec.yaml:30-46`), so even if an alert were generated the
parent would see it only through the in-app Realtime list
(`supabase_alert_repository.dart:59-119`). Child consent exists only for remote
audio/video sessions, not for content monitoring.

Platform constraints that any future implementation must respect (documented here, not
implemented): reading SMS bodies requires the default-SMS role (Android 4.4+), call control
requires `ROLE_DIALER` plus an `InCallService`, `READ_CALL_LOG`/`READ_SMS` are Play-policy
restricted, gallery access on Android 13+ requires `READ_MEDIA_IMAGES` and is scoped, and
message-text extraction realistically requires a user-granted accessibility service. None of
these roles, permissions or services is declared or requested in this repository.

## 3. Evidence gaps / BLOCKED items

- **Real app suspension: BLOCKED — ACCESS REQUIRED.** No Device Owner device was available;
  `dpm list-owners` reported no owners (`docs/verification-report.md:862-874`) and the project
  documents the gap itself (`docs/app-restrictions.md:62-68`). Every claim about an app actually
  being blocked, about restore after a rule is removed, and about suspension surviving reboot is
  therefore code-only. `device-owner-provisioning.md` (read in part) describes the provisioning
  steps but records no executed run.
- **Schedules / offline / reboot:** no runtime evidence that a window edge suspends or restores
  an app, that the stored policy is applied with no network, or that the guardian resumes after
  boot. The JVM suite covers only the pure predicates (`PolicyEvaluatorTest.kt`), and the
  Flutter tests cover controller state, not device behaviour.
- **Enforcement status truthfulness on non-owner devices:** the empty-`desired` success path
  (`PolicyApplier.kt:94-101,137` → `device-command/index.ts:321`) was reasoned from code; no
  runtime capture of an "enforced" badge on a device that cannot enforce was obtained.
- **D–G runtime:** no device testing is possible because the features are absent; the negative
  evidence is static (manifest, schema, policy keys, repo-wide searches) and is cited per row.
- **Hosted backend state** (whether migrations/functions/cron are actually deployed) is out of
  scope for this subagent and left to the dashboard subagent.
- I did not run the app, the Kotlin/Flutter test suites, or any Supabase command; all test
  claims are "the test file exists and asserts this", not "the test passed in this session".

## 4. One-paragraph summary a reviewer can trust

Parental control in this repository reduces to one real mechanism: package suspension through
`DevicePolicyManager`, available only when Parent Control is provisioned as Device Owner
(`PolicyApplier.kt:236-244`). The surrounding machinery — policy versioning, command
queue/poll/ack, enforcement-status display, installed-app and usage telemetry — is implemented
and partly verified live (`docs/verification-report.md:71,203-208,575`), but no app has ever
actually been suspended in any recorded run, and the project says so
(`docs/app-restrictions.md:62-68`; `docs/verification-report.md:862-874`). Per-app schedule
windows are the only time-based control that reaches the device; the "Downtime" product
(bedtime, daily screen-time limit) is stored, displayed and explicitly non-enforced
(`PolicyApplier.kt:297-298`; `child_restrictions_page.dart:295-301`). Two P0-level risks sit in
the control plane: a non-owner device can ack a policy as "enforced" when its desired suspend set
is empty, and policy delivery is poll-only with a 900-second TTL plus a `sync_policy` that
replays stale local JSON, so a save made while the child is offline can be silently lost.
Bypass resistance is low — the child can unlink and every suspension is restored
(`NativeBridge.kt:386`) — and on Android 15+ background sync does not resume at boot
(`BootReceiver.kt:31-37`). Notifications monitoring, social-content detection, inappropriate
image detection and calls/SMS monitoring are entirely absent: no listener, accessibility,
telephony or media permission, no table, no policy key, no route, no alert type and no push
transport exists anywhere in the app or backend.

```
counts: fully_verified=0 partially_verified=12 partial=11 ui_only=0 backend_only=1
code_untested=6 broken=0 missing=51 blocked=0 not_applicable=1
```
