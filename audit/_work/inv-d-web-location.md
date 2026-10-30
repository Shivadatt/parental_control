# Inventory D — web filtering, web time, browsing history, location, route history, geofence

## 1. Scope actually covered

Read (Flutter): `lib/features/location/{location_controller,location_page,location_binding}.dart`,
`lib/features/safe_zones/{safe_zones_controller,safe_zones_page}.dart`,
`lib/features/app_restrictions/{app_restrictions_controller,app_restrictions_page}.dart` (labels only, to prove
app-blocking is package-level), `lib/features/child/controllers/child_shell_controller.dart` (location section),
`lib/features/parent_shell/parent_shell_page.dart`, `lib/app/routes/app_routes.dart`,
`lib/data/models/telemetry.dart`, `lib/data/models/device.dart` (PolicyPayload), `lib/data/repositories/repository_contracts.dart`,
`lib/data/repositories/supabase_location_repository.dart`, `lib/data/services/device_admin_service.dart`.

Read (Kotlin): `android/app/src/main/AndroidManifest.xml`,
`android/app/src/main/kotlin/com/parentcontrol/parent_control/LocationTrackingService.kt`,
`.../GuardianService.kt` (location + command sections), `.../NativeBridge.kt` (location methods),
`.../policy/PolicyModels.kt`.

Read (backend): `supabase/migrations/20260101000000_core.sql` (location_events, safe_zones, safe_zone_states,
safety_alerts), `supabase/migrations/20260101000200_rls.sql` (RLS), `supabase/functions/device-telemetry/index.ts`
(`location_upload` handler incl. geofence evaluation).

Searched repo-wide: `website|web_filter|url|blacklist|whitelist|browser|vpn|dns|accessibility` in `lib/`, `android/`,
`android_dpc/` (empty dir), `supabase/`. No website-filtering, VPN-service, DNS or accessibility-service code exists.

Skipped: hosted Supabase (never touch CLI/dashboard — other subagent), the screen_time feature beyond confirming it is
app/schedule based, and device runtime testing (read-only audit).

## 2. Findings

### 2.1 Inventory table

| ID | AirDroid category | Subfeature | UI route/screen | Flutter files:line | Kotlin/service/permission | table/function/RLS | Connected? | tests | runtime evidence | STATUS | gap + risk + priority |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F-W01 | Website Restrictions | URL blacklist (block list of sites) | — | none | none (no VpnService/AccessibilityService; `AndroidManifest.xml:78-114`) | no web/URL table in any migration | no | — | — | MISSING | No storage, no UI, no enforcement. Child browses freely. P0 |
| F-W02 | Website Restrictions | URL whitelist (allow only listed sites) | — | none | none | — | no | — | — | MISSING | App-level analogue only (`device.dart:119` blockAllExceptAllowed is package-based). P0 |
| F-W03 | Website Restrictions | Modes: unrestricted / blacklist / whitelist | — | none; `PolicyPayload` has no web field (`device.dart:118-125`) | `ChildPolicy` has no web field (`PolicyModels.kt:37-45`) | — | no | — | — | MISSING | No mode selector anywhere in parent UI (`parent_shell_page.dart:18-49` tabs). P0 |
| F-W04 | Website Restrictions | Website categories (violence/adult/social…) | — | none | none | — | no | — | — | MISSING | No category taxonomy or dataset in repo. P1 |
| F-W05 | Website Restrictions | Harmful-content filtering / SafeSearch | — | none | none | — | no | — | — | MISSING | No blocklists shipped and no filter to feed them. P1 |
| F-W06 | Website Restrictions | Browser integration (in-app / managed browser) | — | none; `pubspec.yaml` has no webview/in-app browser dep (assumption from absence of imports) | no WebView activity in `AndroidManifest.xml:46-76` | — | no | — | — | MISSING | Only browser opened is the auth redirect deep link (`AndroidManifest.xml:68-75`). P0 |
| F-W07 | Website Restrictions | Supported browsers | — | none | none | — | no | — | — | MISSING | Vacuous: no browser (Chrome, WebView, Firefox) is covered at all. P1 |
| F-W08 | Website Restrictions | HTTPS handling (SNI/CONNECT interception) | — | none | none | — | no | — | — | MISSING | Would need VPN + TLS/SNI strategy; absent, so even a domain list could not see HTTPS hosts. P1 |
| F-W09 | Website Restrictions | Domain/subdomain matching | — | none | none | — | no | — | — | MISSING | No URL/domain parser anywhere (repo-wide grep found none). P1 |
| F-W10 | Website Restrictions | VPN / DNS / local filtering enforcement | — | none | no `VpnService` subclass, no `BIND_VPN_SERVICE`, no DNS/Private-DNS code (`AndroidManifest.xml:4-29, 78-114`) | — | no | — | — | MISSING | This is the enforcement layer; none of the three mechanisms exists. Rules could not be enforced even if stored. P0 |
| F-W11 | Website Restrictions | Bypass resistance (uninstall/other browser/VPN toggle) | — | none | Device admin exists but only for app policy (`ParentControlDeviceAdminReceiver.kt`) | — | no | — | — | MISSING | Nothing to bypass because no filter exists. P1 |
| F-W12 | Website Restrictions | Offline behaviour of web rules | — | none | none | — | no | — | — | MISSING | N/A until enforcement exists. P2 |
| F-W13 | Website Restrictions | Rule sync parent→child | — | none; policy sync path carries only app fields (`device-policy` payload) | `PolicyApplier` applies app/screen-time only (`PolicyApplier.kt`) | `device_policies` payload jsonb, no web keys | no | — | — | MISSING | Would need a new payload key + applier; absent. P1 |
| F-W14 | Website Restrictions | Blocked-page behaviour (interstitial/block page) | — | none | none | — | no | — | — | MISSING | P2 |
| F-T01 | Web Time | Web time limits (AirDroid: iOS-specific) | — | none | none | — | no | — | — | NOT APPLICABLE | AirDroid's Web Time is iOS-only; no Android equivalent is expected. Android screen time is app-based (`screen_time` feature, out of scope). |
| F-T02 | Web Time | Per-site daily time budget on Android | — | none | none | — | no | — | — | MISSING | No time accounting exists below package granularity (`usage_daily` is per package, `core.sql:226-246`). P2 |
| F-H01 | Browsing History | URL history capture | — | none | no browser/URL logging; `UsageReporter.kt` reports packages only | no browsing/history table in migrations | no | — | — | MISSING | P0 |
| F-H02 | Browsing History | Browser identification | — | none | none | — | no | — | — | MISSING | App-level usage could name the browser package, but no URL source exists to identify visits. P1 |
| F-H03 | Browsing History | Visit timestamp | — | none | none | — | no | — | — | MISSING | No per-visit timestamps; `usage_daily.last_used_at` is per package/day (`core.sql:228-246`). P1 |
| F-H04 | Browsing History | Domain categorization | — | none | none | — | no | — | — | MISSING | No domain data is collected, so nothing to categorise. P2 |
| F-H05 | Browsing History | Blocked-URL history | — | none | none | — | no | — | — | MISSING | Depends on F-W01. P2 |
| F-H06 | Browsing History | Parent browsing-history screen | — | no route (`app_routes.dart:4-32`) | — | — | no | — | — | MISSING | Parent shell has 4 tabs only (`parent_shell_page.dart:18-49`). P1 |
| F-H07 | Browsing History | Sync to backend | — | none | none | — | no | — | — | MISSING | `device-telemetry` exposes no browsing action; only `heartbeat`, `usage_upload`, `location_upload`, `apps_upload` (`index.ts:68,157,239,357`). P1 |
| F-H08 | Browsing History | Retention policy | — | none | none | — | no | — | — | MISSING | No history exists to retain; a future store would need its own purge policy. P2 |
| F-H09 | Browsing History | Privacy (consent, visible collection) | — | none | none | — | no | — | — | MISSING | No collection at all, so no privacy exposure today. P3 |
| F-H10 | Browsing History | Browser coverage | — | none | none | — | no | — | — | MISSING | Zero browsers observed; no WebView or Chrome history access path. P2 |
| F-L01 | Location | Current location (latest fix) | `/parent/location` | `location_page.dart:208-340`; `location_controller.dart:26-42,61-91` | `LocationTrackingService.kt:164-191` → `NativeEventBus.kt:28-31` → `GuardianService.kt:458-495` | `location_events` select + `device-telemetry/location_upload` insert (`device-telemetry/index.ts:239-268`) | yes | `test/features/location/location_controller_test.dart:41,54,67` | — | IMPLEMENTED — PARTIALLY VERIFIED | Parent sees latest fix only while child's service runs; child must opt in (`child_shell_controller.dart:914-1003`). No runtime device evidence in docs/evidence. P1 |
| F-L02 | Location | Permission handling (fine + notification) | child settings tab | `child_shell_controller.dart:914-980` | `NativePermissions.hasFineLocation` (`AndroidManifest.xml:6-7`; `NativeBridge.kt:197-198`) | — | yes | — | — | IMPLEMENTED — PARTIALLY VERIFIED | Service self-stops without fine-location or notifications (`LocationTrackingService.kt:65-73`). No automated test. P2 |
| F-L03 | Location | Background location | child settings tab | `child_shell_controller.dart:972-979` (warning only) | `ACCESS_BACKGROUND_LOCATION` (`AndroidManifest.xml:8`), `foregroundServiceType="location"` (`:86`), START_STICKY (`LocationTrackingService.kt:96`) | — | partial | — | — | CODE EXISTS — NOT TESTED | Chooses foreground service over background permission; no runtime proof the fix keeps arriving when UI is closed. P1 |
| F-L04 | Location | Accuracy reporting | `/parent/location` | `telemetry.dart:90-92,152-154`; `location_page.dart:325-328,180` | `LocationTrackingService.kt:180` (`location.accuracy`) | `location_events.accuracy_m` check ≥0 (`core.sql:257`) | yes | — | — | IMPLEMENTED — PARTIALLY VERIFIED | Displayed for latest fix and per history point; not used to filter bad fixes. P2 |
| F-L05 | Location | Refresh (manual/pull-to-refresh) | `/parent/location` | `location_page.dart:23-31,44-45,71` | — | — | yes | — | — | IMPLEMENTED — PARTIALLY VERIFIED | No polling and no realtime subscription; parent must pull. P2 |
| F-L06 | Location | Last-updated / staleness | `/parent/location` | `telemetry.dart:146-147` (>10 min); `location_page.dart:283-305,315-324` | — | — | yes | `location_controller_test.dart:41-65` | — | IMPLEMENTED — PARTIALLY VERIFIED | Uses server `recorded_at`; correct and honest. P3 |
| F-L07 | Location | Offline state | `/parent/location` | `location_page.dart:50-64` banner; `location_controller.dart:80-89` clears `latest` on error | — | — | yes | — | — | PARTIALLY IMPLEMENTED | Banner claims "Showing the last data loaded" but the controller nulls `latest` on failure (`location_controller.dart:81`) and nothing is cached to disk, so the card may show "No location reported yet" instead. Misleading copy. P2 |
| F-L08 | Location | Location history (list) | `/parent/location` | `location_controller.dart:44,93-110`; `location_page.dart:148-192` | — | `location_events` select RLS parent-or-child (`rls.sql:122-128`), 500-row limit (`supabase_location_repository.dart:45-68`) | yes | — | — | IMPLEMENTED — PARTIALLY VERIFIED | 24 h / 7 d only; 500 cap silently truncates (banner at `location_page.dart:77-83`). P2 |
| F-L09 | Location | Battery impact / doze handling | — | none | no battery-optimisation exemption request, no WorkManager/FusedLocation (`AndroidManifest.xml:4-29`); `GuardianService.kt:499-520` only reports battery level | — | no | — | — | MISSING | Plain `LocationManager.requestLocationUpdates` every 60 s (`LocationTrackingService.kt:150`) with no doze mitigation and no adaptive interval. P2 |
| F-L10 | Location | Map integration | — | `location_page.dart:46` (ListView); `safe_zones_page.dart:88` ("never from a map") | — | — | no | — | — | MISSING | The "map" is a text list of coordinates. No map SDK dependency. P1 |
| F-L11 | Location | Revocation / stop sharing | child settings tab | `child_shell_controller.dart:991-1003,1054-1060` | `LocationTrackingService.kt:52-54` | — | yes | — | — | IMPLEMENTED — PARTIALLY VERIFIED | Only the child can stop; parent has no remote off switch, and unlink clears tracking. P2 |
| F-L12 | Location | Parent-side sharing controls (request a fresh fix / live share) | — | `device.dart:442,472` recognise `request_location` only as a label for the command log; no button sends it | `GuardianService.kt:308-320` executes a `request_location` command; validated at `_shared/policy.ts:263` | `device_commands` | partial | `_shared/policy_test.ts:281-288` | — | BACKEND ONLY | Handler + validation exist; no Flutter call site (grep `request_location` in `lib/` hits only the enum). Parent cannot trigger a fix on demand. P2 |
| F-R01 | Route History | Continuous recording | — | — | upload driven by GuardianService poll (`GuardianService.kt:37` 20 s, `:222`) of the newest fix (`:458-467`) | `location_events` insert per accepted fix | partial | — | — | IMPLEMENTED — PARTIALLY VERIFIED | One row per poll only if the fix timestamp advanced; otherwise skipped entirely (`:460`). No path polyline. P1 |
| F-R02 | Route History | Historical coordinates | `/parent/location` | `location_page.dart:148-192` | — | `location_events` (device,recorded_at desc index, `core.sql:264-267`) | yes | — | — | IMPLEMENTED — PARTIALLY VERIFIED | Raw points only; no ordering/segment reconstruction. P2 |
| F-R03 | Route History | Timeline view | `/parent/location` | `location_page.dart:163-175` (time + relative time, newest first) | — | — | yes | — | — | PARTIALLY IMPLEMENTED | A reverse-chronological list, not a timeline with durations between points. P2 |
| F-R04 | Route History | Map visualisation / route polyline | — | none | — | — | no | — | — | MISSING | Requires F-L10; the parent sees coordinate pairs, never the path taken. P1 |
| F-R05 | Route History | Date filtering | `/parent/location` | `location_controller.dart:7-21,112-116` | — | query window only (`supabase_location_repository.dart:55-56`) | yes | — | — | PARTIALLY IMPLEMENTED | Only two fixed presets (24 h / 7 d); no calendar picker. P2 |
| F-R06 | Route History | Accuracy per point | `/parent/location` | `location_page.dart:179-185` | `LocationTrackingService.kt:150` (`minDistance = 0f`) | `accuracy_m` stored | yes | — | — | IMPLEMENTED — PARTIALLY VERIFIED | Every fix accepted regardless of accuracy; no accuracy threshold or smoothing. P2 |
| F-R07 | Route History | Retention / cleanup | — | — | — | no delete/cleanup of `location_events` in any migration or `cron` function | no | — | — | MISSING | Rows accumulate forever; `family-admin` only deletes on family deletion (`family-admin/index.ts:188-202`). P2 |
| F-R08 | Route History | Missing-sample handling | — | `location_page.dart:138-146` empty state only | — | — | no | — | — | MISSING | No gap detection; a hole in the route looks identical to a stationary child. P1 |
| F-R09 | Route History | Offline upload / local queue | — | — | no queue: `uploadPendingLocation` retries only the *latest* in-memory fix (`GuardianService.kt:458-474`); `LiveState` holds one fix | — | no | — | — | MISSING | Every fix gathered while offline except the newest is lost; route history has holes. P0 |
| F-G01 | Geofence | Create geofence | `/parent/safe-zones` | `safe_zones_page.dart:125-133,238-383`; `safe_zones_controller.dart:124-168` | — | `safe_zones` insert, parent-only policy (`rls.sql:149-154`) | yes | `safe_zones_controller_test.dart:25`; `supabase/tests/30_rls.sql:104-110,228-234` | — | IMPLEMENTED — PARTIALLY VERIFIED | Coordinates typed by hand; no map picker and no "use current location" button. P1 |
| F-G02 | Geofence | Edit geofence | `/parent/safe-zones` | `safe_zones_page.dart:125-133`; `safe_zones_controller.dart:124-168` | — | update policy (`rls.sql:155-161`); `upsertSafeZone` update path (`supabase_location_repository.dart:126-133`) | yes | `supabase/tests/30_rls.sql:104-110` | — | IMPLEMENTED — PARTIALLY VERIFIED | Editing lat/lng resets nothing; existing `safe_zone_states` baseline stays, so a moved zone can fire a false enter/exit. P2 |
| F-G03 | Geofence | Delete geofence | `/parent/safe-zones` | `safe_zones_page.dart:135-158`; `safe_zones_controller.dart:198-212` | — | delete policy (`rls.sql:162-166`); cascade `safe_zone_states` (`core.sql:287`) | yes | `supabase/tests/30_rls.sql:104-110` | — | IMPLEMENTED — PARTIALLY VERIFIED | No confirm-copy check beyond a dialog; no runtime evidence. P2 |
| F-G04 | Geofence | Radius setting + validation | `/parent/safe-zones` | `safe_zones_controller.dart:115-122` (50–5000 m) | — | `radius_m` check 50–5000 (`core.sql:278`) | yes | `safe_zones_controller_test.dart:25` | — | IMPLEMENTED — PARTIALLY VERIFIED | Matches DB constraint; no visual radius editor. P2 |
| F-G05 | Geofence | Entry/exit alerts | `/parent/alerts` | `alerts_body.dart:81,308-312` (renders types) | — | server evaluation on upload: `device-telemetry/index.ts:274-352` inserts `safety_alerts` with `geofence_enter`/`geofence_exit` | yes | — | — | IMPLEMENTED — PARTIALLY VERIFIED | Real evaluation (haversine `validation.ts:400-413` + previous-state compare), not just stored rows. Depends on child uploads (F-R09). P0 |
| F-G06 | Geofence | Multiple geofences | `/parent/safe-zones` | `safe_zones_controller.dart:24,71-79` (list) | — | loop over all active zones (`index.ts:277-352`); no unique constraint on family | yes | — | — | IMPLEMENTED — PARTIALLY VERIFIED | Unlimited zones; no per-device zone assignment (zones are family-wide). P2 |
| F-G07 | Geofence | Background monitoring | — | — | no `GeofencingClient`; relies on the tracking foreground service and the 20 s poll | evaluation only runs inside `location_upload` (`index.ts:239-352`) | partial | — | — | CODE EXISTS — NOT TESTED | If the child service is off, no evaluation happens at all. No OS geofence registration. P1 |
| F-G08 | Geofence | Offline handling | — | — | — | evaluation is server-side only | no | — | — | PARTIALLY IMPLEMENTED | Transitions that occur while the child is offline are collapsed to one comparison at reconnect; enter+exit inside the gap yields a single spurious alert. P1 |
| F-G09 | Geofence | Duplicate-alert prevention | — | — | — | first sample = baseline, alerts only on `wasInside !== inside` (`index.ts:303-333`); state upsert keyed (zone_id, device_id) (`core.sql:286-292`) | yes | — | — | IMPLEMENTED — PARTIALLY VERIFIED | Correct at state-transition level; no advisory lock, so two concurrent uploads could both read the stale state and double-insert. P2 |
| F-G10 | Geofence | Requests/Alerts integration | `/parent/alerts` | `alerts_body.dart:81,300-320`; `safety_alerts_controller.dart` | — | `safety_alerts` insert (`index.ts:349`) + select RLS (`rls.sql:171-176`) | yes | `test/features/safety_alerts/safety_alerts_controller_test.dart` | — | IMPLEMENTED — PARTIALLY VERIFIED | Alert appears live while the parent app is open (private RLS channel, `supabase_alert_repository.dart:13-100`) but there is no push channel (no FCM dependency in `pubspec.yaml`), so a closed app gets no notification. P1 |
| F-G11 | Geofence | Accuracy / hysteresis / battery efficiency | — | none | — | point-in-circle only, no accuracy buffer or dwell time (`index.ts:301-303`) | no | — | — | PARTIALLY IMPLEMENTED | A child near the boundary with ±50 m accuracy can flap enter/exit repeatedly; every flap is an alert. P1 |

### 2.2 Website restrictions — no enforcement mechanism exists

There is no website/web-filter feature in this repository at any layer:

- No route. `lib/app/routes/app_routes.dart:4-32` lists every route; there is no website/URL/web-filter screen, and the
  parent shell has exactly four tabs (`parent_shell_page.dart:18-49`).
- No model or policy field. `PolicyPayload` carries `blockedPackages`, `allowedPackages`, `appRules`,
  screen-time and bedtime only (`lib/data/models/device.dart:118-125`); the Kotlin mirror `ChildPolicy` has the same
  fields and nothing web-related (`PolicyModels.kt:37-45`).
- No storage. No migration defines a URL/domain/rule table; the only telemetry tables are `usage_daily`,
  `location_events`, `device_apps` (see `supabase/migrations/20260101000000_core.sql:249-267`).
- No enforcement surface. `AndroidManifest.xml:78-114` declares exactly three services (`GuardianService` dataSync,
  `LocationTrackingService` location, `AudioAssistanceService` microphone), one device-admin receiver and `BootReceiver`.
  There is no `VpnService`, no `BIND_VPN_SERVICE`/`BIND_ACCESSIBILITY_SERVICE` permission and no accessibility service;
  `android_dpc/` is empty.
- What *does* exist is package-level app blocking (`app_restrictions_page.dart:323-421`, "Block all except allowed" at
  `:413-421`). That blocks apps, not URLs, and cannot block a browser's traffic.

Consequence: website restrictions, website categories, harmful-content filtering, HTTPS/domain matching and
blocked-page behaviour are all `MISSING`, and "rule sync" has nothing to sync. Even a future rule store would be inert
without one of the three enforcement mechanisms, none of which is present.

### 2.3 Web Time — AirDroid's version is iOS-specific

AirDroid's Web Time is an iOS-only capability; the Android product has no equivalent, so no Android counterpart is
expected. Nothing in this repo accounts for time at URL or domain granularity: usage is stored per package/day
(`usage_daily`, `core.sql:226-246`) and reported by `UsageReporter.kt`. F-T01 is therefore `NOT APPLICABLE` (not a
gap); the only defensible "missing" item is a hypothetical per-site budget (F-T02), which should not be counted against
feature parity with AirDroid on Android.

### 2.4 Location — the "map" is a coordinate list, and the Dart upload path is dead code

The parent Location screen is a `ListView` of cards, never a map (`location_page.dart:46`). The safe-zone screen is
explicit about it: coordinates are "never from a map or a guessed position" (`safe_zones_page.dart:88`), and the zone
editor takes four text fields including raw latitude/longitude (`safe_zones_page.dart:258-270,326`).

The working write path is entirely native: `LocationTrackingService` (`LocationTrackingService.kt:30-263`) publishes
fixes to `LiveState`/`NativeEventBus` (`:185-186`), and `GuardianService` uploads the newest fix on each poll
(`GuardianService.kt:222,458-495`). The Flutter `LocationRepository.uploadLocation`
(`repository_contracts.dart:141-146`, `supabase_location_repository.dart:70-93`) has **no call site anywhere in `lib/`**
(repo-wide grep returns only the two declarations), so the Dart telemetry upload is dead code. This does not break the
feature — Kotlin owns it — but it means any Flutter-side test of "location upload" tests nothing.

The child controls collection: sharing is off by default and only starts after the child enables it and grants fine
location plus notifications (`child_shell_controller.dart:914-980`); the service refuses to run without those
(`LocationTrackingService.kt:65-73`). AirDroid's model is parent-driven; here the child can simply leave the switch off
(`child_shell_controller.dart:991-1003`) and the parent sees "No location reported yet"
(`location_page.dart:255-278`). That is a product gap, not a security hole, but it means location cannot be relied on
as a parental control.

Mock locations are treated as untrusted: the native side flags `isMock` (`LocationTrackingService.kt:171-176`) and the
uploader refuses to send mocked fixes, logging once per 5 minutes (`GuardianService.kt:465-474`). That is a solid
anti-spoof measure, though the Dart `LocationFix.isMock` (`telemetry.dart:101`) is unused.

### 2.5 Route history — no map, no gap handling, and offline samples are lost

Route history is the `location_events` stream rendered newest-first with time and accuracy
(`location_page.dart:148-192`), filtered to 24 h or 7 d (`location_controller.dart:7-21`) and capped at 500 rows
(`supabase_location_repository.dart:58`, banner `location_page.dart:77-83`). There is no polyline, no map, no calendar
date filter, no gap detection, and no retention job (`family-admin` only purges on family deletion,
`family-admin/index.ts:188-202`).

Offline behaviour is the weakest point: `uploadPendingLocation` returns early unless the in-memory fix is newer than the
last upload and only retries that single newest fix (`GuardianService.kt:458-467`), while upload failures just log
(`:484-489`). Fixes produced while the network is down are overwritten in `LiveState` by newer fixes and never
uploaded, so the route silently loses its middle.

### 2.6 Geofence — server-side evaluation is real, but it rides on location uploads

Geofence evaluation is genuinely implemented, not merely stored rows: on every accepted `location_upload` the edge
function loads the family's active zones, compares each distance against the radius, reads the previous state from
`safe_zone_states`, and inserts `safety_alerts` rows of type `geofence_enter`/`geofence_exit` only when the state flips
(`device-telemetry/index.ts:274-352`). The first sample for a zone is deliberately treated as a baseline and produces
no alert (`:304-311`), which is the correct way to avoid a false "entered" alert on setup.

Limits: evaluation happens only inside that handler, so a child whose tracking service is stopped gets no evaluation at
all (F-G07); there is no `GeofencingClient` registration, so all monitoring depends on the app's own 20 s poll; there is
no accuracy buffer, dwell time or hysteresis, so a boundary-straddling child with ±50 m fixes can flap
(`:301-303`); and because only the newest fix is uploaded after an outage, an enter-and-exit that happens entirely
offline collapses to a single comparison (F-G08). `safe_zone_states` is service-role only, with no policies
(`rls.sql:168`), which correctly prevents clients from forging state.

Parent-side delivery: alerts are rendered by type in the Alerts tab (`alerts_body.dart:81,300-320`) and arrive over a
private, RLS-filtered Realtime channel while the app is running (`supabase_alert_repository.dart:13-14,62-100`). There
is no push provider in the project (no Firebase/FCM entry in `pubspec.yaml`, no messaging service in
`AndroidManifest.xml:78-114`), so a geofence alert is invisible until the parent reopens the app — materially weaker
than AirDroid's background push.

## 3. Evidence gaps / BLOCKED items

- No runtime device evidence for location upload, geofence firing or route history anywhere under `docs/evidence/`
  (`docs/evidence/stage8/` contains only remote-assistance media). All D/E/F statuses above are code-level.
- Hosted Supabase state (whether `location_events`/`safe_zones`/`safety_alerts` exist and are populated in the deployed
  project) is `BLOCKED — ACCESS REQUIRED` (dashboard subagent owns it).
- SQL tests cover the `safe_zones` schema and its RLS (read isolation `supabase/tests/30_rls.sql:62-64`, parent
  insert/update/delete `:104-110`, child insert denied `:228-234`) and `safety_alerts` RLS (`:171-176`), but no test
  anywhere exercises the `location_upload` handler in `supabase/functions/device-telemetry/index.ts` — the geofence
  arithmetic, baseline suppression and transition-to-alert logic are unexercised by any automated test (the only
  `_test.ts` files under `supabase/functions/` cover policy, validation, TURN, enrollment and session guard).
- Device power/doze behaviour of `LocationTrackingService` cannot be assessed statically; unverified (assumption).

## 4. Summary

Website filtering does not exist in this product: there is no route, no policy field, no rule table, no URL parser, and
crucially no VPN/accessibility/DNS/browser integration (`app_routes.dart:4-32`, `device.dart:118-125`,
`PolicyModels.kt:37-45`, `AndroidManifest.xml:78-114`). Only package-level app blocking exists, which cannot restrict
web content, so every Web subfeature is `MISSING` and AirDroid's Web Time is `NOT APPLICABLE` on Android. Location is
the strongest of these areas: a consent-gated native foreground service collects GPS/network fixes
(`LocationTrackingService.kt:112-191`), Kotlin uploads the newest fix on a 20 s poll via `device-telemetry`
(`GuardianService.kt:222,458-495`), and the parent sees a latest-fix card with staleness, accuracy and source plus a
24 h/7 d history list (`location_page.dart:119-341`). But the "map" is a text list, route history has no polyline or
gap handling, offline fixes are dropped except the newest, and there is no retention policy. Geofencing is real
server-side evaluation with transition-only alerts and baseline suppression (`device-telemetry/index.ts:274-352`), yet
it is entirely dependent on the child's upload stream, has no hysteresis, no OS-level geofence registration, no push
delivery, and no test that exercises its evaluation logic — so its correctness under real movement is unproven.

counts: fully_verified=0 partially_verified=18 partial=5 ui_only=0 backend_only=1
code_untested=2 broken=0 missing=31 blocked=0 not_applicable=1
