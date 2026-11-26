# HAVEN Feature-to-PDF Mapping

**Status of this document:** read-only source mapping, **supplementary evidence only**. It is not runtime proof, a pass/fail report, or a device-test result.  
**Requirements source:** `01_PDF_FEATURE_REQUIREMENTS_INVENTORY.md`, `PDF-R001`–`PDF-R104`.  
**Repository inspected:** `D:\parentcontrol_app` on branch `main`; source paths below are repository-relative and line numbers refer to the inspected working tree.  
**Coverage:** all **104** PDF requirements have a disposition. No AirDroid-only capability is credited to HAVEN without a located implementation.

## Disposition legend

- **I — Implemented in source only:** a bounded HAVEN implementation was located; runtime remains `NOT TESTED`.
- **P — Partial / narrower / ambiguous in source:** some implementation exists, but a PDF element, qualification, or consistent semantic contract is missing or conflicting.
- **M — Not implemented in inspected source:** no implementation was located in `lib`, `android/app/src`, and `supabase`; this is a source finding, not a runtime verdict. Executors may use `NOT IMPLEMENTED` only after the prescribed runtime/UI confirmation.
- **R — Reference / scope rule only:** the PDF statement is context, a negative-coverage caveat, OEM guidance, or an accuracy rule rather than an executable HAVEN feature.

**Counts:** I = **29**, P = **32**, M = **38**, R = **5**. Thus **61 requirements have at least one source-mapped HAVEN path**, **38 have no located implementation**, and **5 are reference/scope rules**. These counts are not runtime coverage or pass counts.

## Exact source anchors

Citations below resolve to exact `file:line` ranges. A range identifies the inspected implementation/UI contract, not a claim that the whole feature passed.

| Key | Exact source citation | What the anchor establishes |
|---|---|---|
| C01 | `lib/features/parent_shell/parent_shell_page.dart:16-50` | Parent bottom navigation; feature entry through device details. |
| C02 | `lib/features/dashboard/parent_dashboard_tab.dart:21-25,51-72,124-304` | Refresh, offline/error state, device cards, battery/presence/policy/permission summaries. |
| C03 | `lib/features/dashboard/dashboard_controller.dart:19,64-76,101-185` | 60-second dashboard refresh, connectivity worker, retained data/error handling. |
| C04 | `lib/features/devices/parent_devices_tab.dart:53-72,131-217` | Device list and presence/enforcement/policy-version display. |
| C05 | `lib/features/devices/device_detail_page.dart:94-105,228-407` | Unmanaged warning, policy/ack/enforcement display, permission tiles, commands and feature links. |
| C06 | `lib/features/devices/device_presentation.dart:7-21,38-58,76-85` | Enforcement labels and heartbeat-derived presence/permission-gap presentation. |
| C07 | `lib/data/models/device.dart:4-104,118-259,335-480,515-627,688-709` | Policy windows/rules, enforcement states, 12/30-minute presence model, permissions, commands, installed apps. |
| C08 | `lib/features/app_restrictions/app_restrictions_page.dart:128-148,220-247,253-499,530-681,865-990` | Save/sync, policy correlation, installed-app picker, block-all/allowed lists, schedules. |
| C09 | `lib/features/app_restrictions/app_restrictions_controller.dart:118-149,224-255,346-383,402-657,659-712` | Device Owner rules, 30/50 app-picker limits, policy draft/save/sync, acknowledgement and report correlation. |
| C10 | `lib/data/models/policy_enforcement.dart:23-115,237-351` | Desired/applied/failed counters, full-enforcement requirements, exact `policy_id` correlation. |
| C11 | `lib/data/repositories/supabase_policy_repository.dart:21-31,33-78,80-143` | Latest policy read, `device-policy` update, commands and acknowledgement. |
| C12 | `lib/features/screen_time/screen_time_page.dart:81-130,155-259,261-455` | Usage Access warning, daily/7-day usage, stale-upload warning, daily limit and bedtime controls. |
| C13 | `lib/features/screen_time/screen_time_controller.dart:78-201,235-413,461-481` | Usage aggregation/staleness, policy save/ack polling, enforcement wording. |
| C14 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/PolicyModels.kt:3-85` | Policy/app-rule/window model; no-window block rule; daily quota and bedtime fields. |
| C15 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/PolicyJson.kt:8-71` | Accepted Child policy JSON and schedules; bounded policy schema. |
| C16 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/PolicyEvaluator.kt:5-76` | Explicit/newly present package evaluation and protected-package guard. |
| C17 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/policy/QuotaEvaluator.kt:31-41,69-99,140-236` | Device-local daily foreground quota, eligible app targets, unmanaged advisory versus managed suspension. |
| C18 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt:17-23,37-251,285-289,320-369,398-518` | Device Owner gate, suspend/restore and DPM verification, quota application, 60-second tick; bedtime informational at `502-503`. |
| C19 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/InstalledApps.kt:7-42` | Installed package snapshot; no install-event receiver in this class. |
| C20 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/UsageReporter.kt:8-22,37-85` | Real UsageStats foreground durations/last-used data; denied access throws. |
| C21 | `lib/features/location/location_page.dart:21-37,65-192,208-340` | Latest fix/history UI, coordinates/timeline/accuracy, stale warning; no map widget located. |
| C22 | `lib/features/location/location_controller.dart:7-21,44,61-91` | 24-hour/7-day selectors, 500-point history cap, refresh reads stored location. |
| C23 | `lib/data/repositories/supabase_location_repository.dart:25-93,95-155` | Latest/history reads, Child upload, safe-zone CRUD. |
| C24 | `lib/features/safe_zones/safe_zones_page.dart:81-119,127-238,240-385` | Zone list/editor/delete and manual latitude/longitude/radius fields. |
| C25 | `lib/features/safe_zones/safe_zones_controller.dart:113-145,147-235` | Zone validation and family-level create/edit/toggle/delete. |
| C26 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/LocationTrackingService.kt:23-35,62-187` | Visible permission-gated location service, 60-second default, provider fixes, mock flag, timestamp/accuracy. |
| C27 | `lib/data/models/telemetry.dart:86-123,125-259,278-337` | Location freshness, events, family-level safe zones, alert types/model. |
| C28 | `supabase/functions/device-telemetry/index.ts:28-32,68-155,157-237,239-352,357-427` | Heartbeat/low battery, usage/location uploads, server geofence baseline/transitions/alerts, app snapshot. |
| C29 | `lib/features/safety_alerts/safety_alerts_controller.dart:48-58,61-69,71-205`; `lib/features/safety_alerts/alerts_body.dart:71-130,220-318` | Alert load/realtime/reconciliation/acknowledgement and visible types. |
| C30 | `lib/features/remote_assistance/remote_assistance_page.dart:12-29,82-151,229-321` | Request dialog, Child Accept/Join requirement, Parent receive-only, no recording/screen capture, session list. |
| C31 | `lib/features/remote_assistance/remote_assistance_controller.dart:68-111` | Parent request creation and pending expiry. |
| C32 | `lib/data/models/remote_session.dart:3-73,132-170` | Audio/video session model and explicit server-state-versus-media-liveness boundary. |
| C33 | `lib/features/remote_assistance/remote_session_page.dart:137-173,175-274,277-415,418-620,669-738` | Consent/status, media/transport errors, Join/end controls, renderer, RTP wording, end confirmation. |
| C34 | `lib/features/remote_assistance/remote_session_controller.dart:67-81,178-181,298-303,327-465,732-905,1080-1657,1674-2000,2037-2052,2118-2235,2283-2355,2392-2617,2677-2748` | Role/consent gates, front-camera constraints, RTP evidence, recovery, permission/service loss, stop/end and deterministic track/service teardown. |
| C35 | `lib/features/child/child_session_page.dart:11-18,85-148,267-405,408-544,632-683` | Child session visibility, Accept then Join, Stop sharing, background behavior, capture-versus-RTP state. |
| C36 | `lib/features/child/controllers/child_shell_controller.dart:20-24,38-39,72-76,160-252,314-400,420-615,617-794,839-1010` | Server/native state separation, linked polling, service resume, suspension verification, permission/location controls. |
| C37 | `android/app/src/main/AndroidManifest.xml:4-39,79-115` | Declared runtime permissions, optional hardware, three foreground services, Device Admin/BootReceiver; no NotificationListener/Accessibility/MediaProjection declaration located. |
| C38 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/NativePermissions.kt:11-63` | Native camera/mic/location/notification/Usage Access checks and capability snapshot. |
| C39 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt:26-45,57-70,123-289,299-482,499-670,699-762` | Background intervals/start limits/watchdog, command handling, heartbeat/telemetry, location last-fix upload, foreground notification. |
| C40 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/BootReceiver.kt:9-16,29-51` | Guardian restart after boot/update where allowed; Android 15 restriction/error. |
| C41 | `android/app/src/main/kotlin/com/parentcontrol/parent_control/AudioAssistanceService.kt:24-67,75-219,242-384,388-778` | Consented microphone foreground service, 45-second capture watchdog, task-removal behavior, notification and backend-state poll. |
| C42 | `supabase/functions/device-policy/index.ts:46-105` | Parent-only verified policy update, active-device authorization, validation, atomic policy/command and audit. |
| C43 | `supabase/functions/_shared/policy.ts:27-65,94-152,158-235,241-303` | Strict policy keys, caps, windows, daily/bedtime fields and command payloads; no per-app/shared budget/request/location-downtime schema. |
| C44 | `supabase/functions/device-command/handler.ts:176-445` | Atomic policy commands, polling, acknowledgement, policy update and audit. |
| C45 | `supabase/functions/device-command/enforcement.ts:21-27,125-170,226-293,301-550` | Evidence-based enforcement normalization, unsupported/failed/count/quota/bedtime branches. |
| C46 | `supabase/functions/remote-session/index.ts:37,77-179,181-376` | Only audio/video kinds, participant authorization, pending expiry, Child consent/start, Parent end, ICE after consent. |
| C47 | `lib/data/repositories/supabase_remote_session_repository.dart:29-66,104-220,222-398` | Parent/Child session operations, end/ICE/signals and realtime/replay. |
| C48 | `supabase/migrations/20260101000000_core.sql:33-74,79-105,176-243,249-339` | Family/device constraints, policy/command/usage/location/zone/alert/session schema; no notification/content table. |
| C49 | `supabase/migrations/20260101000100_functions.sql:531-573,782-790,947-970` | Offline detector (>15 minutes, six-hour dedupe), service-only wrapper, optional pg_cron schedules. |
| C50 | `supabase/functions/cron/index.ts:31-132` | Authenticated scheduled actions for session expiry, offline detection, abandoned sessions and retention sweep. |
| C51 | `lib/features/settings/settings_body.dart:36-151,153-352,354-388`; `lib/features/settings/parent_settings_controller.dart:66-90,195-295` | Account/family/local toggles, privacy/export/deletion/retention UI and controller boundaries. |
| C52 | `lib/features/settings/account_privacy_repository.dart:12-77,147-269` | Export scope/file write, deletion call, retention report; saved JSON is a persistent local write. |
| C53 | `supabase/functions/account/index.ts:1-7,41-119,227-260` | Authenticated privacy lifecycle, export cap/paging and credential-safe columns; runtime scope logic follows. |
| C54 | `supabase/migrations/20261030000300_retention_sweep.sql:1-23,113-284`; `supabase/functions/account/retention.ts:8-53,122-175,217-249` | 30/90 defaults, scope rules, service-role sweep and report windows; external scheduling required. |
| C55 | `lib/features/family/family_page.dart:266-407,516-558` | Family owner/members/devices, pairing and retention overview; unlink controls are prohibited in this audit. |
| C56 | `lib/features/child/child_enrollment_page.dart:176-349`; `lib/features/child/controllers/child_enrollment_controller.dart:15-20,233-251` | Child ID/QR and Child approval; no linking until Child approves. |
| C57 | `lib/data/repositories/supabase_auth_repository.dart:186-249` | Auth error handling including minimum-eight-character password message; no MFA enrollment flow located. |
| C58 | `lib/features/audit_logs/audit_logs_page.dart:10-166,168-294`; `lib/features/audit_logs/audit_logs_controller.dart:22-49,65-118,120-236,238-272` | Read-only audit history, retention editor and owner-only destructive purge (not authorized). |
| C59 | `lib/features/child/tabs/child_home_tab.dart:93-207,278-514`; `lib/features/child/tabs/child_settings_tab.dart:66-76,110-305` | Child visible session/service/location/permission notices, local disclosure, prohibited unlink/sign-out controls. |
| C60 | `lib/features/child/widgets/policy_summary_card.dart:8-12,55-166,182-245` | Child configured-versus-DPM-verified distinction; informational daily/bedtime wording. |
| C61 | `supabase/functions/_shared/rate_limit.ts:20-21,181-199` | Invite rate limits (3 pending/10 per 24h), not an AirDroid-equivalent 10-device account cap. |

## Requirement-by-requirement mapping

### PDF page 2 — structure, dashboard, activity, app management

| PDF ID | Disp. | HAVEN source mapping and exact boundary |
|---|---|---|
| PDF-R001 | I | Parent shell/dashboard/device-detail entry points: C01, C02, C05. Live sessions are a separate route: C30. |
| PDF-R002 | P | Child uses Guardian/location/audio services and capability reporting: C36–C41. Notification synchronization and several PDF monitoring functions are absent; see M rows. |
| PDF-R003 | P | Child ID/QR plus explicit Child approval exists: C56. No AirDroid-equivalent 10-device account cap located; C61 limits invites, not bound-device count. Do not test by creating links. |
| PDF-R004 | I | Repository/device schema and manifest are Android Child scoped: C37, C48. This mapping does not claim iOS or AirDroid Personal support. |
| PDF-R005 | I | Today/7-day UsageStats aggregation and per-app UI: C12, C13, C20. Runtime freshness and completeness remain unverified. |
| PDF-R006 | M | No notification-listener declaration or notification-content table/pipeline located: C37, C48. Safety alerts are a different feature (C29). |
| PDF-R007 | M | UsageReporter exposes foreground milliseconds/last-used only: C20. No per-app mobile-data/NetworkStats path located; C37 has internet/network-state permissions, not data-usage reporting. |
| PDF-R008 | I | Per-app bars, most-used ordering and installed-app list: C12, C19, C20. |
| PDF-R009 | P | Usage UI is aggregate foreground time (C12, C20), not message/screen transcripts; Child privacy notice says messages/passwords are not read (C59). No complete-transcript claim should be made. |
| PDF-R010 | I | Installed package snapshot, Parent picker/search and upload: C08, C19, C28, C39. Snapshot limits require runtime freshness checks. |
| PDF-R011 | P | Explicit package block/unblock and schedules exist: C08, C09, C14–C18. No category-selection or per-app time-budget model located: C43. |
| PDF-R012 | M | InstalledApps is a snapshot (C19); Guardian uploads snapshots (C39). No package-added receiver/new-install alert producer located in C37 or C28/C49. |
| PDF-R013 | M | PolicyEvaluator evaluates newly present packages against the current policy (C16), and block-all targets current installed packages (C18), but no install-event-triggered auto-block option/alert exists. Do not equate next-tick re-evaluation with the PDF option. |
| PDF-R014 | I | Parent block/unblock controls and Child DPM suspend/restore verification: C08–C10, C18, C60. Device Owner remains mandatory. |
| PDF-R015 | M | Child Requests handles pairing and assistance only: C36, C59. Strict policy schema has no restricted-app request: C43. |
| PDF-R016 | M | Daily quota sums device-wide eligible foreground usage (C17), not a selected group's shared allowance. No selected-group budget field in C14/C43. |
| PDF-R017 | M | App rules support block state/windows (C14, C43), not per-app time budgets. A schedule is not an individual usage limit. |
| PDF-R018 | I | Per-app recurring windows, including overnight windows, policy application and Child summary: C07, C08, C14, C15, C18, C60. |
| PDF-R019 | I | Block-all-except-allowed plus allowed package list: C08, C14, C18, C43. Protected packages are independently guarded by C16. |
| PDF-R020 | P | Saving a block creates an atomic apply command (C11, C42, C44) and Guardian polls (C39), but there is no dedicated Instant Block control/latency contract in C08. Normal policy enforcement is not automatically “instant.” |
| PDF-R021 | M | No fixed-period/until-midnight/manual-off Instant Block selector or payload fields located: C08, C14, C43. |
| PDF-R022 | M | Safe zones produce entry/exit alerts (C28), but policy schema/evaluator contain no area condition or location-based downtime: C14–C18, C43. |
| PDF-R023 | I | Enforcement requires policy-correlated counters and DPM checks, not timer/ack alone: C09, C10, C18, C44, C45. |
| PDF-R024 | P | Latest reported fix is shown with timestamp/accuracy/staleness (C21, C27), but no map widget was located in the location page (C21). |
| PDF-R025 | P | Parent refresh re-reads stored location (C22, C23). Guardian `request_location` uploads `LiveState.lastFix` rather than obtaining a new GPS fix (`GuardianService.kt:433-455`, within C39). Freshness must be tested independently. |
| PDF-R026 | P | Timeline offers 24h/7d and caps history at 500 points (C21, C22); no route map or guaranteed 30-day view. Retention defaults/config are separate (C54). |
| PDF-R027 | I | Named family zone with manual coordinates and 50–5000 m radius: C24, C25, C27. |
| PDF-R028 | I | Server reads active family zones, baselines first sample, then creates enter/exit states/alerts on later transitions: C28. Runtime delivery remains unverified. |
| PDF-R029 | P | Accuracy, timestamp, provider/mock handling and stale warnings exist (C21, C26, C27); battery-saver/indoor behavior is an OS/device condition, not guaranteed by source. |
| PDF-R030 | M | Location service handles GPS/network fixes (C26), not driving event/sensor/speed/hard-braking/acceleration detection. No driving pipeline located. |
| PDF-R031 | P | Parent video request and Child consented front-camera WebRTC path exist: C30, C34, C35, C46. Child must Accept then Join; it is not silent background camera activation. |
| PDF-R032 | P | Child capture uses front-facing `facingMode: 'user'` (`remote_session_controller.dart:1203-1234`, within C34). No rear switch, rotate/full-screen, or flashlight control located in C30/C33/C34. |
| PDF-R033 | I | Video join always requests audio as well as front video (`remote_session_controller.dart:1203-1234`, C34); Parent is receive-only (C30). Actual audio still needs RTP evidence. |
| PDF-R034 | I | Audio-only session, Child microphone capture, Parent render/receive and RTP flow detection: C30, C32–C35, C46. |
| PDF-R035 | M | UI/controller explicitly state no audio/video recording (C30, C33, C35, C59); session schema has no recording artifact (C32, C46). Do not credit recording/management. |
| PDF-R036 | M | Only `audio`/`video` session kinds are accepted (`remote-session/index.ts:37`, C46); no MediaProjection declaration/flow (C37) and UI says screen is not captured (C33). |

### PDF page 3 — remote-monitoring caveats, notifications, social/image/web

| PDF ID | Disp. | HAVEN source mapping and exact boundary |
|---|---|---|
| PDF-R037 | I | On-demand request/accept/join/end model and explicit no-recording/no-screen-capture notices: C30, C32–C35, C46. |
| PDF-R038 | I | Pending expiry, online/transport errors, Child consent and permission/native-service preflight: C30–C35, C39, C41, C46. |
| PDF-R039 | I | Explicit Child consent, visible session/notifications and no hidden-surveillance wording: C30, C35, C41, C59. |
| PDF-R040 | M | No NotificationListenerService or notification sync table/API located: C37, C48. Parent Safety Alerts are not incoming app notifications. |
| PDF-R041 | M | Parent notification switch is explicitly local to the Parent phone (C51); it is not app-wise Child notification selection/mute. No listener configuration exists. |
| PDF-R042 | M | No notification preview/content collection path located: C37, C48. |
| PDF-R043 | M | No social-message keyword detector, supported-app registry, or keyword alert pipeline located; no notification/message access in C37. |
| PDF-R044 | M | No App Detection Management or Keyword Management surface/schema located: C37, C43, C48. |
| PDF-R045 | M | The PDF's non-universal limitation remains applicable, but HAVEN has no located social-detection implementation to evaluate. |
| PDF-R046 | M | No Gallery/media-store image scanning or image-detection pipeline located; manifest/capabilities are camera-session scoped (C37, C38, C59). |
| PDF-R047 | R | The PDF's exclusions are retained as negative scope. HAVEN's no-screen-capture/no-recording statements (C33, C59) must not be mistaken for image scanning. |
| PDF-R048 | M | No CallLog/SMS/Telephony, call-filter, safe-search, or AI-chat-monitoring implementation located; manifest has no corresponding permissions (C37) and policy schema is package-block only (C43). |
| PDF-R049 | M | No browser blacklist/whitelist, URL filter, VPN/DNS filter, or Accessibility web-control path located: C37, C43. |
| PDF-R050 | M | UsageReporter records foreground duration, not browser URLs/history (C20); no browsing-history table in C48. |
| PDF-R051 | M | Alert schema permits `other` but no blocked-site producer exists (C28, C48, C49). |
| PDF-R052 | M | No website/time-limit fields in policy schema (C43) or website control UI. |
| PDF-R053 | R | Browser-filtering caveat is retained as benchmark scope; it does not establish a HAVEN filter. |
| PDF-R054 | M | No Child blocked-app extra-time/access request or Parent approve/refuse path: C36, C43, C59. Pairing/assistance requests are different. |
| PDF-R055 | P | Low battery (C28), geofence transitions (C28), and offline SQL detector (C49) exist. No blocked-app-attempt or new-install producer located. Runtime scheduler/delivery unverified. |
| PDF-R056 | P | Parent/Child show permission gaps and app version (C05, C36, C51, C59), but no generated permission-disable/app-update safety-alert producer located in C28/C49. |

### PDF page 4 continuation — family tools and background access

| PDF ID | Disp. | HAVEN source mapping and exact boundary |
|---|---|---|
| PDF-R057 | M | No Family Chat, Child-triggered SOS, or Focus Mode implementation located in Parent/Child shell, policy schema, or backend command set: C01, C36, C43, C59. |
| PDF-R058 | P | Guardian/location services, watchdog and visible failure reporting exist (C26, C36, C39), but Android/OEM can stop them; no permanent-survival claim is made (C39, C40). |
| PDF-R059 | P | BootReceiver resumes Guardian where allowed (C40). It does not itself restore location/media; Child shell resumes location on load (C36). No in-app autostart grant/state control located. |
| PDF-R060 | M | No OEM “run in background” exemption inspector/control located. HAVEN foreground-service status is not OEM exemption state: C36, C39. |
| PDF-R061 | M | No battery-optimization state inspector/control located in C36/C38/C59. |
| PDF-R062 | M | No power-saving exception/state workflow located: C36, C38, C59. |
| PDF-R063 | M | No Data Saver/background-data inspector or exemption workflow located. Connectivity handling exists (C03, C36) but is not the PDF setting. |
| PDF-R064 | M | No Wi-Fi-always-on-during-sleep setting/state workflow located. |
| PDF-R065 | M | No OEM recent-app lock/cleanup allowlist workflow located. |
| PDF-R066 | P | App version is read/displayed (C51, C59) and permission states are reported (C36, C38), but no update-required alert/automatic update check located. |
| PDF-R067 | R | OEM-specific setting names are external Android guidance; HAVEN source cannot standardize them. Record the actual Realme/OEM UI without changing it. |
| PDF-R068 | I | Usage Access AppOps check, capability reporting, UsageStats collection and UI warning: C12, C20, C36, C38. |
| PDF-R069 | M | No AccessibilityService declaration or UI-level accessibility enforcement/detection path: C37, C43. Device Owner package suspension is a different mechanism (C18). |
| PDF-R070 | M | No Notification Access/listener implementation: C37, C48. |
| PDF-R071 | I | Fine/coarse/background location declarations/checks, visible location service, uploads, zones and geofence evaluation: C23–C28, C36–C39. |
| PDF-R072 | I | Camera permission declaration/check, Child-only session request and front-camera capture: C34, C35, C37, C38, C59. |
| PDF-R073 | I | Microphone declaration/check, session preflight, native microphone foreground service, privacy indicators/stop: C34, C35, C37, C38, C41, C59. |
| PDF-R074 | M | No MediaProjection permission/declaration/session token/screen stream: C37, C46. Camera video is not screen mirroring. |
| PDF-R075 | I | Foreground services, watchdog, sticky restart, boot handling and scheduled sync: C37, C39–C41. OEM/OS limits remain explicit. |
| PDF-R076 | I | Internet/network-state permissions, Edge API, command/heartbeat/location upload and WebRTC transport: C37, C39, C44, C47. |

### PDF page 5 — limitations, setup, privacy

| PDF ID | Disp. | HAVEN source mapping and exact boundary |
|---|---|---|
| PDF-R077 | R | The PDF table is explanatory, not reverse engineering. Mapping relies on HAVEN's actual manifest/services, not assumed AirDroid internals: C37–C41. |
| PDF-R078 | P | Offline/stale UI and errors exist (C02–C07, C36); network recovery is handled (C03, C36). Force-stop/uninstall/airplane/power-off are prohibited test mutations, not routine audit steps. |
| PDF-R079 | P | Permission state is surfaced on Child and Parent (C05, C36, C38, C59), and media permission loss releases capture (C34). Do not revoke permissions to test this. |
| PDF-R080 | P | Android 15/background-start/OEM limitations and retry/error surfaces exist: C36, C39–C41. Behavior still depends on runtime OS/OEM state. |
| PDF-R081 | I | Child Join, OS permission prompts, visible indicators, MediaProjection absence, and no bypass are consistent with C30, C34–C35, C37, C41. |
| PDF-R082 | P | Fix timestamp/accuracy/source/mock and stale warnings exist (C21, C26, C27), but seeded last-known fixes can be old; runtime freshness is essential. |
| PDF-R083 | P | Watchdog/retry/visible failure handling exists (C36, C39–C41); permanent survival is not guaranteed. |
| PDF-R084 | I | Existing authenticated Parent session is the only authorized setup state; account/family UI is C51. No sign-in/install test is authorized. |
| PDF-R085 | I | Existing Child ID/QR pairing and Child approval model: C55, C56. Runtime test inspects existing state only. |
| PDF-R086 | I | Child enrollment/consent/monitoring notices and session disclosures: C35, C56, C59. |
| PDF-R087 | P | Feature-wise Child permission review exists (C59) and enrollment disclosure exists (C56), but audit cannot grant permissions and no new setup run is allowed. |
| PDF-R088 | P | Child shows Guardian/location/network/permission state (C36, C59); dedicated battery/autostart/Data Saver/OEM-cleanup inspection is absent, so use read-only Android Settings evidence where allowed. |
| PDF-R089 | P | Individual test cases exist in report 03 for implemented subsets. Notification sync, instant block, and screen mirroring have no located HAVEN workflow and must not be substituted. |
| PDF-R090 | P | Parent permission-gap tiles and app version exist (C05, C51), but no automatic update/permission safety-alert generator or post-update retest automation located. |
| PDF-R091 | P | Transparent Child notices, proportional feature gating and security notes exist (C35, C51, C56, C59); legal authority/age proportionality cannot be proven by runtime UI alone. |
| PDF-R092 | I | Explicit lawful/transparent-use benchmark is implemented as consent, visible session state, no recording/screen capture and stop controls: C30, C33–C35, C41, C59. |
| PDF-R093 | P | Auth error text requires at least eight characters (C57); no MFA enrollment/management UI or flow located. Do not expose/change credentials. |
| PDF-R094 | I | Child visible app/session/service/location notices and ongoing foreground notifications: C35, C39, C41, C59. |
| PDF-R095 | P | Clear session state, Child Stop sharing, Parent End and audit history exist (C33–C35, C46, C58); automatic session-transition audit completeness remains a source ambiguity. |
| PDF-R096 | P | Retention/export/deletion source paths exist (C51–C54, C58); security notes exist (C51). No product-policy proof of server region, subscription terms, or encryption configuration is established by these files. Export/deletion/purge are prohibited mutations. |

### PDF pages 6–7 — availability snapshot and accuracy

| PDF ID | Disp. | HAVEN source mapping and exact boundary |
|---|---|---|
| PDF-R097 | I | **PDF: Listed.** HAVEN has Usage Access, UsageStats collection, daily/7-day UI and upload: C12, C13, C20, C28, C38. |
| PDF-R098 | P | **PDF: Listed.** HAVEN has explicit app blocks, schedules, Always Allowed and a device-wide daily app-suspension quota: C08–C18, C43–C45. Shared/per-app budgets, Instant Block durations, requests, and location downtime are absent. |
| PDF-R099 | P | **PDF: Listed.** Latest/timeline location, manual zones and server geofence transitions exist: C21–C28. No map, fresh-on-demand GPS proof, route map, 30-day guarantee, or driving detection. |
| PDF-R100 | P | **PDF: Listed.** Consented front-camera video and one-way audio exist: C30–C35, C41, C46–C47. No rear controls/recording; Child Accept+Join required. |
| PDF-R101 | M | **PDF: Listed.** No screen-mirroring/MediaProjection implementation: C37, C46. Independent `MIR` and `BG-05` tests are mandatory. |
| PDF-R102 | M | **PDF: Listed.** No notification synchronization/social keyword pipeline: C37, C48. |
| PDF-R103 | M | **PDF: Product-listed.** No image scan, calls/SMS/call-filter, safe-search/AI-chat, or web-filter implementation located: C20, C37, C43, C48. Variable product coverage does not justify inventing HAVEN support. |
| PDF-R104 | R | Accuracy/versioning rule retained. HAVEN displays app version and records device Android/app version (C48, C51, C59); every runtime result must bind observations to actual version/time/network/OEM state. |

## Source ambiguities requiring runtime resolution

These are not confirmed defects. They are precise places where source contracts differ or where source alone cannot establish behavior.

| ID | Source ambiguity | Exact evidence | Required runtime discriminator |
|---|---|---|---|
| SA-01 | Daily quota is app-suspension enforcement in native code, while Child UI calls daily screen-time limits informational/not system-wide. | C17 (`QuotaEvaluator.kt:140-236`), C18 (`PolicyApplier.kt:183-209`), C60 (`policy_summary_card.dart:124-131`), C59 (`child_restrictions_page.dart:295-300`). | On a pre-existing managed device, observe which eligible apps suspend at quota and which protected/foreground services remain usable; compare Parent/Child wording. Do not provision Device Owner. |
| SA-02 | Native bedtime is explicitly informational, but backend enforcement has a bedtime-only branch that may derive an enforced/unsupported state. | C18 (`PolicyApplier.kt:502-503`), C45 (`enforcement.ts:321-398`), C60. | Save a bedtime-only reversible policy only if authorized; observe that no independent bedtime suspension occurs and inspect correlated backend status. Otherwise `BLOCKED`. |
| SA-03 | Presence becomes Offline at 30 minutes, while the SQL offline-alert threshold is more than 15 minutes and depends on a scheduler. | C07 (`device.dart:335-457`), C49, C50. | Compare Parent presence timestamp, Safety Alert creation and actual heartbeat separately; do not force-stop. A safe network interruption may be used only with approval. |
| SA-04 | “Location refresh” reads stored data; Guardian location command uploads the last live fix rather than requesting a fresh GPS fix. Location service may also seed a last-known fix. | C22, C23, C26, C39 (`GuardianService.kt:433-455`). | Compare pre/post `recorded_at`, accuracy/provider evidence and Child service/network state. An unchanged old fix is not refresh success. |
| SA-05 | Video assistance starts a microphone-type foreground service; newer Android/OEM camera foreground-service requirements are not resolved by source. | C34 (`remote_session_controller.dart:1154-1169,1414-1493`), C37 (`AndroidManifest.xml:79-93`), C41. | On the actual Child OS, observe start success/failure, camera/mic indicators and visible notification. Do not label an OEM/OS restriction a defect without mishandling evidence. |
| SA-06 | Retention sweep and offline/session maintenance have source entry points, but production invocation is not proven. Optional pg_cron and authenticated Edge cron are different paths. | C49, C50, C54 (`retention_sweep.sql:1-6`). | Read-only retention report/last-sweep display and permitted scheduler evidence; never invoke purge or fabricate old rows. |
| SA-07 | PDF's AirDroid 10-device statement is plan-qualified; HAVEN has invite rate limits but no equivalent bound-device cap located. | C48 (`core.sql:55-74,79-105`), C61. | No runtime cap test: creating devices/accounts is prohibited. Record as product-scope difference, not a HAVEN defect. |
| SA-08 | Newly present packages are evaluated on policy ticks and block-all covers current packages, but there is no new-install alert/event trigger. | C16, C18 (`PolicyApplier.kt:64-110`), C19, C28, C39. | Installing an app is an unapproved mutation; mark install-dependent path `BLOCKED`. UI/source confirmation may support `NOT IMPLEMENTED` for alerting. |
| SA-09 | Parent “Show local notifications” and location reminder are local preferences, not server alert creation or Child notification-listener controls. | C51 (`settings_body.dart:116-150`), C29. | Inspect labels and observable local behavior only; do not claim Child notification sync from these toggles. |
| SA-10 | Alert schema permits offline/app-blocked/permission-missing, but only low-battery/geofence and SQL-offline producers were located. | C27, C28, C29, C48 (`core.sql:297-311`), C49. | Verify each event producer independently. An allowed enum value or icon is not an alert generator. |
| SA-11 | Child location copy says “No location is recorded by this app itself; uploads are short-lived fixes,” while server location history and configurable retention exist. | C59 (`child_home_tab.dart:425-431`), C23, C27, C48 (`core.sql:249-267`), C54. | Compare Child disclosure with actual Parent history/retention display. Record exact wording; do not expose coordinates. |
| SA-12 | Remote session server `active` state and ICE/DTLS connectivity do not prove media flow; only advancing RTP counters support live-audio wording. | C32 (`remote_session.dart:132-170`), C34 (`remote_session_controller.dart:178-181,2283-2355`), C33. | Require timestamp-correlated Child capture/service evidence plus Parent advancing RTP/received media; signalling alone is insufficient. |

## Mapping conclusions

1. **Strongest source candidates:** device/family dashboard, installed-app snapshots, UsageStats reports, explicit package blocks/schedules, Always Allowed, device-wide daily quota, latest/timeline location, manual safe zones, geofence transitions, consented front-camera video, one-way audio, background Guardian/location/audio services, and privacy/retention surfaces.
2. **Narrower than PDF:** no map, no guaranteed fresh-on-demand GPS, no 30-day route guarantee, no rear-camera controls, no recording, Child Accept+Join required, daily quota is not a whole-device lock, and no Instant Block duration UI.
3. **No located HAVEN implementation:** notification synchronization, social keyword/image/call/SMS/AI monitoring, web filtering/history, driving detection, shared/per-app time budgets, restricted-app requests, new-install alerts, location-based downtime, Family Chat/SOS/Focus Mode, and screen mirroring.
4. **No runtime status is assigned here.** Report 03 is the execution inventory; every case begins `NOT TESTED`.
