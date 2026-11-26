# Lane 2 — Background, Location, Permissions and Recovery Results

**Overall lane status: PARTIAL — runtime evidence obtained; important limitations and two remote-access failures remain.**  
**Supersedes:** the gate-timeout version of this file dated `2026-11-26T10:59:18+05:30`. That earlier version is retained below only as coordination provenance; it is not a current result.  
**Runtime window:** `2026-11-26T12:22:00+05:30` through `2026-11-26T14:03:43+05:30`  
**Report timestamp:** `2026-11-26T14:08:00+05:30`  
**Repository:** `D:\parentcontrol_app`  
**Branch / HEAD:** `main` / `c7b475eb6f0c818a14d298ce4823e69b0d1a55e9`  
**Execution model:** main-agent continuation of the previously blocked lane-2 serialization slot; no additional subagent was created.  
**Remediation:** none. No application, backend, permission, account, device-pairing or Git mutation was performed.

## 1. Supersession and historical provenance

The original lane-2 subagent did not execute device tests because the required runtime inventory was not yet available during its bounded wait. Its historical record was:

- Wait start: `2026-11-26T10:46:54+05:30`
- Timeout: `2026-11-26T10:56:58+05:30`
- Duration: 604 seconds
- Checks: 120 at 5-second intervals
- Exit: 2
- Runtime tests at that time: 0
- Device interactions at that time: 0

Historical evidence remains in `evidence/lane2/gate_wait.txt`, `evidence/lane2/no_device_interaction.txt`, and `evidence/lane2/preflight_summary.txt`. After the inventory and predecessor lanes were available, the main agent continued the same lane and executed the tests documented here. The old **BLOCKED / zero-test** accounting is therefore superseded, not combined with the actual results.

## 2. Result accounting

Official case IDs are reconciled to `03_COMPLETE_RUNTIME_TEST_CASES.md`.

| Scope | PASS | PARTIAL | FAIL | BLOCKED | NOT TESTED | NOT IMPLEMENTED | NOT APPLICABLE | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| ENV-01–ENV-04 | 1 | 3 | 0 | 0 | 0 | 0 | 0 | 4 |
| LOC-01–LOC-13 | 7 | 3 | 0 | 2 | 0 | 1 | 0 | 13 |
| BG-01–BG-07 | 1 | 3 | 2 | 0 | 0 | 1 | 0 | 7 |
| **Lane-2 total** | **9** | **9** | **2** | **2** | **0** | **2** | **0** | **24** |

The two FAIL cases are BG-03 and BG-04: Parent-initiated camera and one-way audio requests failed before Child consent or media could begin. Their full remote-access evidence and CAM/AUD/MIR reconciliation are in `03_remote_access_results.md`.

## 3. Runtime baseline

### 3.1 Devices and installed application

| Item | Parent | Child |
|---|---|---|
| ADB serial | `emulator-5554` | `5HXWRGQ4IFU8WS4T` |
| Device | `sdk_gphone64_x86_64` | `RMX2161` (Realme/realme UI device) |
| Android / API | Android 17 / API 37 | Android 12 / API 31 |
| Security patch | `2026-08-05` | `2023-01-05` |
| Time zone | `Asia/Calcutta` | `Asia/Kolkata` |
| Package | `com.parentcontrol.parent_control` | `com.parentcontrol.parent_control` |
| Version / code | `1.0.0` / `1` | `1.0.0` / `1` |
| Target SDK | 36 | 36 |
| UID observed | `10238` | `11324` |

Evidence: `evidence/lane2/BG_ENV_parent_identity.txt`, `BG_ENV_child_identity.txt`, `BG_ENV_parent_package.txt`, `BG_ENV_child_package.txt`, `POST_BG06_parent.txt`, and `POST_BG06_child.txt`.

### 3.2 Existing relationship and capability state

- The Parent UI showed an active, Online linked Child and the same registered device details.
- The Child UI showed the account linked as a child, the phone Registered/Linked, and policy version `v3`.
- Child Device Admin is enabled. Device Owner is not available and was not provisioned.
- Child reports Device Admin only and explicitly states that app blocking is not available.
- Parent device details explicitly state that app suspension is unsupported without a fully managed Device Owner device and that a policy flag alone does not block an app.
- No Accessibility service, Notification Listener service or MediaProjection session was observed.
- Child Usage Access was allowed. Parent Usage Access was reported unknown by the read-only probe.
- Child precise, coarse and background location permissions were granted. Camera and microphone runtime grants were also present.
- Wi-Fi and mobile data were enabled; airplane mode was off; low-power mode was off on both observed baselines.
- Parent and Child screens were awake at baseline. The Child later entered an ordinary secure keyguard and screen-off state during BG-06.

Evidence: `evidence/lane2/BG02_device_detail.ui.txt`, `BG02_child_final_visible.ui.txt`, `POST_BG06_parent.txt`, `POST_BG06_child.txt`, `BG02_child_permission_grants.txt`, `BG02_child_notification_appop.txt`, `BG02_child_camera_appop.txt`, and `BG02_child_microphone_appop.txt`.

### 3.3 Execution envelope

- All ADB commands ran from `D:\parentcontrol_app` through the sanitized lane helper or read-only collector.
- Output was confined to `evidence/lane2`.
- UI records, Android service/process state, app-ops, network counters, camera state, audio state, power state and Parent-received UI state were captured separately.
- Commands used ordinary UI taps, ordinary keyevents, normal app relaunch, `uiautomator dump`, `dumpsys`, package inspection and `cmd appops`.
- No `force-stop`, clear-data, uninstall, permission grant/revoke, mock-location, Device Owner, network toggle, factory reset, sign-out, unlink, re-pair, backend write, APK build/install or Git mutation was performed.
- Exact command lines, exits, durations and stdout counts are recorded in the per-artifact `.json` metadata and `.txt` headers. The aggregate evidence check is in Section 8.

## 4. ENV — environment, binding, OEM and permission baseline

### ENV-01 — Identity/version/platform

- **Window:** baseline collection during `2026-11-26T12:22:00+05:30`–`12:39:00+05:30`; final app-visible confirmation at `14:03:40+05:30`–`14:03:43+05:30`.
- **Actions:** Read device properties and installed package details; opened Parent linked-device details and Child Home/This phone.
- **Expected:** Both ends report the actual installed build and Android platform.
- **Actual:** Both ends showed version `1.0.0`, code `1`, target SDK 36; Parent Android 17/API 37 and Child Android 12/API 31; current serials and models matched the table above.
- **Status:** **PASS** — current identities and versions were verified directly, not inferred from historical reports.
- **Evidence:** `BG_ENV_parent_identity.txt`, `BG_ENV_child_identity.txt`, `BG_ENV_parent_package.txt`, `BG_ENV_child_package.txt`, `BG02_device_detail.ui.txt`, `BG02_child_final_visible.ui.txt`.

### ENV-02 — Existing binding/family relationship

- **Window:** `2026-11-26T12:36:00+05:30`–`12:39:00+05:30`; final Child confirmation `14:03:40+05:30`–`14:03:43+05:30`.
- **Actions:** Inspected Parent linked-device/family state and Child linked/registered state read-only. No request, unlink or re-pair control was used.
- **Expected:** The approved family, Child and device remain visibly bound at both ends.
- **Actual:** Parent showed the active linked Child; Child showed linked-as-child, Registered, Linked and Online. Account identifiers were redacted from retained evidence.
- **Status:** **PARTIAL** — the visible relationship and existing device registration were confirmed at both ends, but cryptographic/session-level pairing validation was outside this UI-only read-only check and no re-pair flow was exercised.
- **Evidence:** `BG02_device_detail.ui.txt`, `BG02_child_final_visible.ui.txt`.

### ENV-03 — OEM keep-alive/network baseline

- **Window:** `2026-11-26T12:22:00+05:30`–`13:20:00+05:30`; final baseline `14:02:51+05:30`–`14:02:53+05:30`.
- **Actions:** Read network, power, battery-optimization, Data Saver/background-restriction and service-related state exposed by Android/ADB. No setting was toggled.
- **Expected:** Actual OEM states and unavailable values are recorded without treating HAVEN service survival as proof of an OEM exemption.
- **Actual:** Wi-Fi and mobile data were enabled, airplane mode and low-power mode were off. Both apps had background network transport during the sampled windows. Low-power/battery-optimization settings queries returned `null` on the available probe path, so no exemption claim is made. Device Idle whitelist was false on both devices.
- **Status:** **PARTIAL** — network/power baseline was measured; not every Realme OEM autostart/keep-alive setting was exposed through the permitted read-only paths, and no OEM state was changed.
- **Evidence:** `BG_ENV_parent_network_settings.txt`, `BG_ENV_child_network_settings.txt`, `POST_BG06_parent.txt`, `POST_BG06_child.txt`, `BG06_child_monitor_summary.txt`, `BG02_parent_final_state.txt`, `BG02_child_final_state.txt`.

### ENV-04 — Permission/capability baseline

- **Window:** `2026-11-26T12:22:00+05:30`–`14:02:53+05:30`.
- **Actions:** Compared Child UI permission claims with package grants and app-ops; probed Accessibility, Notification Listener, Usage Access, Device Admin, Device Owner and Device Idle state; checked camera/microphone capture state and MediaProjection-related UI absence.
- **Expected:** Displayed/unknown states match actual capability; missing privileged capability is explicit.
- **Actual:** Child location, camera and microphone grants were present. Child Usage Access was allowed; Parent Usage Access was unknown. Accessibility and Notification Listener were false on both devices. Child Device Admin was true; Device Owner was false. No MediaProjection workflow/session was found. Parent device details accurately warned that app suspension is unsupported without Device Owner.
- **Status:** **PARTIAL** — the principal permission-to-capability relationships were verified, but Parent microphone state remained `unknown` in the final native snapshot and MediaProjection absence was confirmed by surface inspection rather than an attempted capture session.
- **Evidence:** `POST_BG06_parent.txt`, `POST_BG06_child.txt`, `BG02_child_permission_grants.txt`, `BG02_child_notification_appop.txt`, `BG02_child_camera_appop.txt`, `BG02_child_microphone_appop.txt`, `BG02_device_detail.ui.txt`, `03_remote_access_results.md`.

## 5. LOC — location, route history and geofence

### LOC-01 — Latest reported location

- **Window:** initial stale observation around `2026-11-26T12:40:00+05:30`; final fresh observation `13:37:00+05:30`–`13:38:00+05:30`.
- **Actions:** Opened Parent Location, recorded fix age/recorded/received/accuracy/source, and inspected Child service/permission state.
- **Expected:** Parent latest fix corresponds to a Child-reported fix with visible timestamp, accuracy and freshness.
- **Actual:** Initial Parent view correctly labelled the `09:54` fix stale. After normal Child relaunch, Parent showed a Recent fix recorded and received at `13:37`, accuracy ±100.0 m, source network, with accepted history points through `13:37`.
- **Status:** **PASS** — fresh Parent-received location was ultimately demonstrated while Child UI was not being held open by the agent.
- **Evidence:** `BG02_location_before_refresh.ui.txt`, `BG02_final_location_settled.ui.txt`, `BG02_child_after_refresh.txt`, `BG07_child_relaunched.txt`.

### LOC-02 — Fresh versus stale/cached

- **Window:** `2026-11-26T12:40:00+05:30`–`13:38:00+05:30`.
- **Actions:** Compared pre-refresh and post-relaunch fix age, warning text, timestamps, accuracy and provider label.
- **Expected:** An old last-known fix is not labelled fresh; stale/inaccurate state is explicit.
- **Actual:** The `09:54` network fix displayed **STALE LOCATION**, “This fix is older than 10 minutes. It is not the child’s current position,” ±100.0 m. The later `13:37` fix displayed Recent/Just now. No raw coordinates were retained.
- **Status:** **PASS** — stale and fresh states were truthfully distinguished in the UI.
- **Evidence:** `BG02_location_before_refresh.ui.txt`, `BG02_location_after_refresh.ui.txt`, `BG02_final_location_settled.ui.txt`.

### LOC-03 — Location refresh workflow

- **Window:** `2026-11-26T12:40:00+05:30`–`12:43:00+05:30`; post-relaunch comparison through `13:38:00+05:30`.
- **Actions:** With Child UI in Launcher/background and Guardian/Location services active, tapped Parent Refresh and compared `recorded_at`, `received_at`, provider and Child provider-request counters. Later compared the same surface after normal relaunch.
- **Expected:** Refresh distinguishes a newly acquired fix from a reload of cached data.
- **Actual:** The first Refresh left the `09:54`/`09:55` record unchanged. Child GPS/network request registrations existed at 60-second intervals, but sampled GPS and network counters did not advance during that immediate interval. Fresh accepted points appeared only later after relaunch.
- **Status:** **PARTIAL** — the UI exposed old data rather than falsely calling it fresh, but Refresh did not demonstrably request a new Android fix. The later fresh uploads cannot be attributed to that Refresh.
- **Evidence:** `BG02_location_before_refresh.ui.txt`, `BG02_refresh_location_tap.txt`, `BG02_location_after_refresh.ui.txt`, `BG02_child_location_requests.txt`, `BG02_child_after_refresh.txt`, `BG02_final_location_settled.ui.txt`.

### LOC-04 — Last-24-hour timeline

- **Window:** `2026-11-26T12:43:00+05:30`–`12:47:00+05:30`; final history comparison through `13:38:00+05:30`.
- **Actions:** Opened route history, inspected timestamps/order and gaps, and compared with Child upload/service observations.
- **Expected:** Real uploaded points appear in time order; gaps and the 500-point cap are not hidden.
- **Actual:** Timeline contained timestamped accepted points. The final view showed a continuous recent sequence from `13:15` through `13:37` with visible gaps between some points; older initial data was stale. The 7-day view explicitly disclosed its 500-point cap.
- **Status:** **PASS** — 24-hour history rendering and timestamp ordering were observed without treating provider requests alone as uploaded points.
- **Evidence:** `BG02_open_location.ui.txt`, `BG02_final_location_settled.ui.txt`, `BG02_history_7d.ui.txt`, `BG02_child_location_requests.txt`.

### LOC-05 — Last-7-day timeline

- **Window:** `2026-11-26T12:47:00+05:30`–`12:52:00+05:30`.
- **Actions:** Selected Last 7 days, waited for the view to settle, and inspected visible point count/range and disclosure.
- **Expected:** HAVEN's 7-day view/500-point limit is shown accurately and not confused with 30-day retention.
- **Actual:** The settled 7-day view stated “Showing the most recent 500 points in this range.” Approximately 500 timestamped points were accessible; the visible span was approximately 23 hours because older points were excluded by the cap.
- **Status:** **PASS** — the UI accurately disclosed the cap rather than presenting the visible range as guaranteed seven-day completeness.
- **Evidence:** `BG02_history_7d.ui.txt`, `BG02_history_7d_tap.txt`, `BG02_history_7d_settled.ui.txt`.

### LOC-06 — Retention versus route view

- **Window:** `2026-11-26T12:52:00+05:30`–`12:56:00+05:30`.
- **Actions:** Compared the 7-day/500-point route view with Parent Settings retention information. No retention control was changed.
- **Expected:** UI view limits and server retention are described separately.
- **Actual:** Parent Settings showed location retention 30 days and usage retention 90 days, with 0 expired location events and 0 expired usage days; last retention sweep was “Not recorded yet.” Settings also described the 7-day signalling, 365-day audit, family export scope and two-confirmation deletion. The 7-day route cap was therefore not misreported as data loss.
- **Status:** **PASS** — route-view limitation and retention policy were visibly distinct.
- **Evidence:** `BG02_parent_settings.ui.txt`, `BG02_history_7d_settled.ui.txt`.

### LOC-07 — Named area/radius configuration

- **Window:** `2026-11-26T12:49:39+05:30`–`12:50:50+05:30`.
- **Actions:** Opened existing Safe zones, inspected `QA_Test_Zone_Live`, opened its editor read-only, and used Cancel. No Save, Create, Edit or Delete mutation was performed.
- **Expected:** Existing named zone, Active state and 50–5000 m radius are represented without inventing per-device assignment or a map picker.
- **Actual:** `QA_Test_Zone_Live` remained Active with radius 150 m. Editor stated “Server accepts 50–5000 m.” Coordinates were redacted. Cancel returned to the same Active/150 m card.
- **Status:** **PASS** — existing zone configuration and validation were verified and preserved.
- **Evidence:** `BG02_safe_zones_loaded.ui.txt`, `BG02_zone_editor.ui.txt`, `BG02_zone_editor_cancel.ui.txt`, `BG02_safe_zones_after_cancel.ui.txt`.

### LOC-08 — Geofence first-sample baseline

- **Window:** stationary observation around `2026-11-26T13:00:00+05:30`–`13:04:00+05:30` and later `13:37:00+05:30`.
- **Actions:** Observed existing zone state, accepted location timestamps and available Alerts state without movement or zone edits.
- **Expected:** First sample establishes a baseline without a false entry/exit transition.
- **Actual:** Provider activity and accepted uploads were observed, but the retained evidence does not expose a complete zone-baseline state transition plus alert sequence sufficient to prove first-sample behavior.
- **Status:** **PARTIAL** — stationary baseline inputs were collected; full first-sample geofence evaluation was not proven.
- **Evidence:** `BG02_safe_zones_loaded.ui.txt`, `BG02_final_location_settled.ui.txt`, `BG06_child_monitor_summary.txt`.

### LOC-09 — Geofence entry alert

- **Window:** not executed.
- **Actions:** none.
- **Expected:** authorized safe physical outside→inside movement creates one named entry alert.
- **Actual:** no physical movement was authorized or performed; no mock location or coordinate injection was used.
- **Status:** **BLOCKED** — required safe physical transition was unavailable.
- **Evidence:** official test preconditions in `03_COMPLETE_RUNTIME_TEST_CASES.md`; no runtime transition artifact exists.

### LOC-10 — Geofence exit alert

- **Window:** not executed.
- **Actions:** none.
- **Expected:** authorized safe physical inside→outside movement creates one exit alert.
- **Actual:** no physical movement was authorized or performed; entry precondition also did not occur.
- **Status:** **BLOCKED** — required safe physical transition was unavailable.
- **Evidence:** official test preconditions in `03_COMPLETE_RUNTIME_TEST_CASES.md`; no runtime transition artifact exists.

### LOC-11 — Geofence accuracy/false transitions

- **Window:** `2026-11-26T12:40:00+05:30`–`13:38:00+05:30`.
- **Actions:** Recorded accuracy/source/timestamps during ordinary stationary operation and inspected any available transition evidence. No boundary loitering, mock provider or jitter was manufactured.
- **Expected:** Accuracy limitations are reported and borderline fixes are not silently called definitive transitions.
- **Actual:** Network fixes showed ±100.0 m and stale/fresh labels were explicit. No natural boundary-crossing sequence was available, so false-transition behavior could not be exercised.
- **Status:** **PARTIAL** — accuracy disclosure was verified; geofence boundary robustness remains unproven.
- **Evidence:** `BG02_location_before_refresh.ui.txt`, `BG02_final_location_settled.ui.txt`, `BG02_child_location_requests.txt`.

### LOC-12 — Indoor/weak-signal stale behavior

- **Window:** `2026-11-26T12:40:00+05:30`–`13:38:00+05:30`.
- **Actions:** Observed naturally available stale/accuracy state without disabling GPS, Wi-Fi, mobile data or battery saver.
- **Expected:** Stale/inaccurate fix is disclosed and the app does not claim guaranteed live precision.
- **Actual:** The old `09:54` network fix was explicitly marked stale and not current; accuracy ±100.0 m and source network were visible.
- **Status:** **PASS** — stale/inaccurate behavior was disclosed truthfully under the naturally observed conditions.
- **Evidence:** `BG02_location_before_refresh.ui.txt`, `BG02_location_after_refresh.ui.txt`.

### LOC-13 — Driving/speed/risky events

- **Window:** surface inspection through `2026-11-26T13:38:00+05:30`.
- **Actions:** Inspected Location, device details, available reports/family/settings surfaces and the source-mapped feature inventory. No driving or sensor manipulation was performed.
- **Expected:** no driving-detection workflow is found; ordinary route points are not called driving safety events.
- **Actual:** no HAVEN driving/speed/hard-braking/acceleration workflow was located or exposed on the inspected surfaces.
- **Status:** **NOT IMPLEMENTED** — absence confirmed within the inspected product surfaces; no risky driving test was attempted.
- **Evidence:** `02_HAVEN_FEATURE_TO_PDF_MAPPING.md`, `BG02_device_detail.ui.txt`, `BG02_parent_settings.ui.txt`, `BG02_final_location_settled.ui.txt`.

## 6. BG — mandatory background scenarios

### BG-01 — Background telemetry

- **Window:** Child monitor `2026-11-26T12:24:39+05:30`–`12:30:48+05:30`; Parent monitor `12:30:48+05:30`–`12:37:04+05:30`.
- **Actions:** With Child UI moved to Launcher/background, sampled UID/PID, Guardian/Location services, app-ops and per-UID network state; then observed Parent dashboard heartbeat without tapping Refresh.
- **Expected:** Child UI is background while permitted services continue and a new heartbeat reaches Parent without manual reopen.
- **Actual:** Child GuardianService and LocationTrackingService remained active in the same process. Parent active Child card remained Online; heartbeat advanced from `12:29` to `12:34`.
- **Status:** **PASS** — background communication and Parent heartbeat advancement were demonstrated. The monitor windows were sequential rather than fully simultaneous; the correlated boundary is `12:30:47/12:30:48`, and later Parent advancement is independent evidence.
- **Evidence:** `BG01_monitor_summary.txt`, `BG01_summary.txt`.

### BG-02 — Parent location access while Child is background

- **Window:** `2026-11-26T12:39:00+05:30`–`13:38:00+05:30`.
- **Actions:** Kept Child UI in Launcher/background, opened Parent Location, tapped Refresh, compared fix timestamps/accuracy and observed Child provider/service state; later observed fresh uploads after relaunch.
- **Expected:** Parent can access available telemetry and a genuinely new fix is distinguished from cached data.
- **Actual:** Parent could access the old fix and labelled it stale. Refresh did not change the record or prove a new fix request. After normal relaunch, accepted points resumed and Parent showed a fresh `13:37` fix.
- **Status:** **PARTIAL** — background access and eventual upload recovery were proven; immediate Refresh-to-new-fix behavior was not.
- **Evidence:** `BG02_child_after_refresh.txt`, `BG02_location_before_refresh.ui.txt`, `BG02_location_after_refresh.ui.txt`, `BG02_child_location_requests.txt`, `BG02_final_location_settled.ui.txt`.

### BG-03 — Parent-initiated camera while Child is background

- **Window:** remote-access lane before `2026-11-26T12:08:35+05:30`; Child background/foreground rechecks remained blocked before this final lane report.
- **Actions:** Parent attempted the camera request while Child was background and again while Child app was foreground. Child consent/Join was never reached.
- **Expected:** Child must visibly consent/Join before actual camera media reaches Parent; Parent camera remains inactive; End stops capture.
- **Actual:** Parent displayed **“Request failed The device is not active.”** No Child consent UI, WebRTC media, RTP, received frames, camera switch, Stop sharing or End flow could be exercised.
- **Status:** **FAIL** — request delivery failed before consent/media. This is not a media-quality failure and not a successful request.
- **Evidence:** `03_remote_access_results.md`; `evidence/lane3/` remote-attempt artifacts.

### BG-04 — Parent-initiated one-way audio while Child is background

- **Window:** remote-access lane before `2026-11-26T12:08:35+05:30`; Child background/foreground rechecks remained blocked.
- **Actions:** Parent attempted one-way audio while Child was background and foreground. Child consent/Join was never reached.
- **Expected:** actual one-way audio flows only after visible consent/Join; Parent microphone remains unpublished; End releases Child microphone/service.
- **Actual:** Parent displayed **“Request failed The device is not active.”** No Child consent, RTP/audio, Parent-mic test or teardown flow occurred.
- **Status:** **FAIL** — request delivery failed before consent/media.
- **Evidence:** `03_remote_access_results.md`; `evidence/lane3/` remote-attempt artifacts.

### BG-05 — Screen mirroring while Child is background

- **Window:** read-only remote/capability inspection before `2026-11-26T12:08:35+05:30`.
- **Actions:** Independently inspected Parent controls and Child MediaProjection/system-consent state; did not substitute camera video or screen-capture workarounds.
- **Expected:** no HAVEN mirroring workflow is found unless MediaProjection consent/session support exists.
- **Actual:** no HAVEN screen-mirroring workflow or MediaProjection session was found.
- **Status:** **NOT IMPLEMENTED** — Android screen-capture capability was not treated as HAVEN support.
- **Evidence:** `03_remote_access_results.md`; MIR-01–MIR-03 reconciliation there.

### BG-06 — Screen-off background operation

- **Window:** `2026-11-26T12:59:48+05:30`–`13:04:00+05:30`; ordinary wake around `13:16:00+05:30`.
- **Actions:** Locked Child with ordinary power keyevent `26`; ran five overlapping Child samples and five Parent samples; inspected power, wake locks, foreground services, process identity, app-ops, per-UID network state, provider counters, camera/audio state and Parent heartbeat. Woke Child with ordinary power keyevent after observation.
- **Expected:** ordinary heartbeat/location/telemetry behavior is measured separately from camera/mic/screen capture while the screen is off.
- **Actual:** Child remained `mWakefulness=Asleep`; display/wake-lock suspend blockers were false. GuardianService and LocationTrackingService stayed foreground with the same PID. Parent card remained Online and heartbeat advanced from `12:55` to `13:00`. GPS counter stayed `2758`; network-location counter advanced `2812`→`2816`, and new provider history lines appeared at `13:00`–`13:03`. Camera and recording/playback remained inactive in every sample.
- **Status:** **PARTIAL** — screen-off service survival, Parent heartbeat and provider activity were proven. Provider counters/history do not prove a HAVEN-accepted server upload or Parent receipt during the BG-06 window. The fresh Parent-received `13:37` points occurred later and are not retroactive BG-06 upload proof.
- **Evidence:** `BG06_parent_prelock.txt`, `BG06_child_prelock.txt`, `BG06_child_lock.txt`, `BG06_child_locked.txt`, `BG06_parent_summary.txt`, `BG06_child_monitor_summary.txt`, `BG06_child_s01_*`–`BG06_child_s05_*`, `BG06_child_wake.txt`, `BG06_child_woke.txt`.

### BG-07 — Background recovery

- **Window:** `2026-11-26T13:16:00+05:30`–`13:22:00+05:30`; final app-visible state `14:03:40+05:30`–`14:03:43+05:30`.
- **Actions:** Woke Child normally; attempted ordinary Unlock control; launched HAVEN normally with the Android Launcher intent; observed activity/services and Parent heartbeat; used an ordinary swipe-up to inspect the secure keyguard. No PIN entry, bypass, force-stop, network interruption or reboot was performed.
- **Expected:** normal relaunch restores supported services without re-pairing; stale state clears or errors remain accurate; network/reboot limitations are recorded rather than bypassed.
- **Actual:** Normal relaunch exited 0 in 1.189 seconds. Activity-manager state showed `com.parentcontrol.parent_control/.MainActivity` focused; Guardian/Location services remained active. Parent heartbeat advanced from `13:15` to `13:20`. The visible UI remained behind the secure six-digit PIN/face-unlock keyguard, so agent-controlled visible recovery was blocked. At `14:03`, the Child app was visibly open again with background protection running, Linked/Registered/Online, synced at `14:01`; the audit did not perform or claim the credential unlock.
- **Status:** **PARTIAL** — activity/service/background-communication recovery and eventual visible app state were observed, but secure-keyguard recovery was not agent-controlled. Network interruption was not authorized; reboot was not approved and remains not tested.
- **Evidence:** `BG07_child_after_unlock.txt`, `BG07_child_relaunch.txt`, `BG07_child_relaunched.txt`, `BG07_child_swipe_unlock.txt`, `BG07_child_unlocked_ui.ui.txt`, `BG07_parent_summary.txt`, `BG07_parent_s01.ui.txt`–`BG07_parent_s03.ui.txt`, `BG02_child_final_visible.ui.txt`, `BG02_child_final_state.txt`.

## 7. Cross-cutting observations and explicit answers

### 7.1 Location upload interpretation

The evidence supports four separate statements, which must not be collapsed:

1. **Initial Refresh was a reload, not proven new-fix acquisition.** The `09:54`/`09:55` record did not change, and sampled provider counters did not advance.
2. **BG-06 proved provider activity while the screen was off.** Network-location counters/history advanced, but that alone is not a server-upload acknowledgement.
3. **Fresh Parent-received uploads resumed later.** After normal relaunch, Parent displayed accepted points through `13:37`, including a Recent fix recorded/received at `13:37`.
4. **The `13:37` uploads do not prove an upload during BG-06.** They occurred after the screen-off sample window and cannot be used to backfill that claim.

The initial location problem was therefore intermittent and recoverable, not a demonstrated permanent inability to upload. The exact backend/source reason for the delay remains a root-cause task for report 09.

### 7.2 Remote command/access observations

- Parent camera and one-way audio requests failed with **“The device is not active”** even while Child Guardian/Location services were running, network state was valid, and Child app was foreground.
- Child Settings showed **“Last command check 20 h ago”** and **“App list upload failed: apps[14].package_name is not a valid Android package name.”**
- **Retry background protection** advanced Last command check to **Just now**, but the app-list validation error and remote request failure remained.
- These observations are retained in `03_remote_access_results.md` and `evidence/lane3/MAINRECOVERY_*` artifacts. They require source/backend tracing in report 09; no cause is asserted here.

### 7.3 Device Admin versus Device Owner

Child Device Admin is enabled; Device Owner is unavailable. The Parent UI explicitly states that app suspension is unsupported without Device Owner and that a policy flag alone does not block apps. No app-blocking, quota enforcement, bedtime enforcement or suspension success is claimed from database/policy state. The coexistence of “Enforced on device” wording and the Device Owner warning must be reconciled in the policy/reporting analysis; this lane does not classify that wording tension as a proven defect without runtime enforcement evidence.

### 7.4 Capture safety

No HAVEN camera open client, active recording or playback was observed in final native state or during BG-06 samples. Historical camera/microphone app-op entries were not treated as active capture. No hidden capture, MediaProjection bypass, consent bypass or Parent-microphone publication occurred.

## 8. Evidence integrity and privacy

Final integrity check: `2026-11-26T14:07:53+05:30`.

| Check | Result |
|---|---:|
| JSON files checked | 291 |
| Invalid JSON | 0 |
| Missing referenced outputs | 0 |
| Hash checks | 288 |
| Hash mismatches | 0 |
| Notification-shade redaction issues | 0 |
| Legacy timestamp-placeholder files | 16, documented |
| Manifest file count | 603 |
| Manifest total bytes | 1,387,663 |

- Validation record: `evidence/lane2/BG02_final_evidence_validation.json`
- Manifest: `evidence/lane2/evidence_manifest.json`
- The 16 placeholder files are legacy BG-07 artifacts where original short Android log timestamps could not be safely reconstructed. Outer capture timestamps and monitor summaries remain available.
- `BG06_child_woke.ui.txt` had 24 unrelated notification nodes removed after capture; omission count and recomputed hash are recorded in its metadata.
- The final Child UI capture had account identifiers redacted and its output hash refreshed.
- No raw coordinates, credentials, tokens, device secrets, SSIDs/network names, unrelated notification contents or private account identifiers are intentionally retained in this report or the cited final artifacts.
- Screenshot redaction remains coupled to filtered UI records in the helper. No system-UI screenshots were taken; future system-UI screenshot use remains restricted until that coupling is corrected.

## 9. Final device state

At `2026-11-26T14:02:51+05:30`–`14:03:43+05:30`:

- **Parent:** HAVEN `MainActivity` foreground; screen awake; no HAVEN foreground service, active camera, recording or playback observed. Authenticated session remained in the app.
- **Child:** HAVEN `MainActivity` visibly foreground; screen awake; GuardianService and LocationTrackingService active; background protection running; Linked/Registered/Online; last sync `14:01`; no active camera, recording or playback observed.
- Existing family relationship, device registration, policy version `v3`, permissions and `QA_Test_Zone_Live` were preserved.
- No sign-out, unlink, re-pair, deletion, permission change, Device Owner provisioning, network change, reboot, build/install, backend change, source fix or Git mutation was performed.

Evidence: `BG02_parent_final_state.txt`, `BG02_child_final_state.txt`, `BG02_child_final_visible.ui.txt`.

## 10. Handoff

- **Report 04:** use the 24 reconciled statuses in Section 2 and the per-case records in Sections 4–6.
- **Report 05:** preserve the distinctions in Sections 7.1–7.4; do not convert provider activity into upload proof or Device Admin into Device Owner enforcement.
- **Report 07:** remote request delivery failures BG-03/BG-04 are confirmed runtime failures; app-list validation error is an observed Child-side error requiring source/backend trace before root-cause attribution.
- **Report 08:** LOC-09/LOC-10 are BLOCKED by unavailable safe physical movement; BG-07 network interruption/reboot remain untested; driving detection and screen mirroring are NOT IMPLEMENTED.
- **Report 09:** trace the “device is not active” command path, app-list package validation error, Refresh/new-fix semantics, delayed location upload and policy-status wording only after all runtime lanes are aggregated.
