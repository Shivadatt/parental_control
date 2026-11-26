# Lane 4 — Parent Feature Runtime Results — Superseding Report

- Audit: HAVEN PDF-based complete real-time two-device functional audit
- Lane: 4 of 4 — Parent-side runtime validation
- Repository: `D:\parentcontrol_app`
- Branch: `main`
- Timezone: Asia/Kolkata (UTC+05:30)
- Runtime window: approximately `2026-11-26T14:20:00+05:30` through `2026-11-26T15:56:00+05:30`
- Execution model: main-agent continuation of the blocked lane; no additional subagent was created
- Remediation: none

## 1. Supersession

This report supersedes the historical gate-timeout report in which all 28 cases were BLOCKED and zero device actions occurred. That report is retained only as coordination provenance. The executed evidence is under `evidence/lane4/`; the alias definitions remain in `evidence/lane4/00_test_inventory.md`.

No application/source, backend, dependency, manifest, Gradle, account, pairing, permission, device credential, zone, policy, alert, export, network or Git mutation was performed. The two local reminder switches were toggled and restored to their original `true` values. `QA_Test_Zone_Live` was inspected and preserved.

## 2. Result accounting

| Status | Count |
|---|---:|
| PASS | 7 |
| PARTIAL | 3 |
| FAIL | 1 |
| BLOCKED | 7 |
| NOT TESTED | 1 |
| NOT IMPLEMENTED | 9 |
| NOT APPLICABLE | 0 |
| **Total** | **28** |

The FAIL is `L4-INV-01`: the Parent has no installed-app snapshot because the Child upload is rejected wholesale when two package names fail server validation. Device Owner enforcement is BLOCKED, not passed from policy storage. `L4-FINAL-01` remains NOT TESTED here because the final audit-wide device/Git verification belongs to FIN-01/FIN-02 and is completed separately.

## 3. Complete alias reconciliation

| Alias | Official test IDs | Status | Runtime basis | Principal evidence |
|---|---|---|---|---|
| L4-ENV-01 | ENV-01–ENV-04 | PASS | Both identities, versions, roles, linkage, services and principal permissions inspected; finer ENV limitations are retained in the official statuses | `L4_000_*`, `L4_001_*`, `L4_021_*`, `L4_030_*` |
| L4-DASH-01 | DASH-01, DASH-02, DASH-04 | PASS | Dashboard/devices/alerts/settings/family navigation; active and revoked records; refresh; heartbeat/policy summary | `L4_002_dashboard.ui.txt`, `L4_003_dashboard_refreshed.ui.txt`, `L4_026_family.ui.txt` |
| L4-USAGE-01 | USG-01–USG-05 | PARTIAL | Usage Access, Today/7-day totals and per-app rows rendered; Refresh did not advance last upload or prove a new background upload | `L4_006_screen_time_settled.ui.txt`, `L4_007_usage_*.ui.txt` |
| L4-INV-01 | APP-01, APP-02 | FAIL | Parent showed no snapshot; Child upload failed package validation; 343 installed, 341 accepted, 2 rejected | `L4_011_restrictions_bottom.ui.txt`, `L4_030_child_settings_scrolled.ui.txt`, `L4_031_child_package_validation_summary.json` |
| L4-INV-02 | APP-13, APP-14, ALT-07 | NOT IMPLEMENTED | No new-install alert or auto-block workflow found on inspected surfaces; no app install attempted | `L4_014_alerts.ui.txt`, restrictions/settings surfaces; mapping C19/C28/C37/C39 |
| L4-LIM-01 | POL-04, POL-07, POL-08 | PASS | Device-wide limit unset; Device Admin only; Parent warns suspension unsupported; Child warns nothing should be described as blocked | `L4_008_app_restrictions.ui.txt`, `L4_021_child_rules.ui.txt`, `L4_025_screen_time_policy.ui.txt` |
| L4-LIM-02 | APP-05 | NOT IMPLEMENTED | No selected-group shared allowance control/payload found | Restrictions and Screen-time surfaces; mapping C17/C43 |
| L4-LIM-03 | APP-06 | NOT IMPLEMENTED | No individual per-app minute budget; only block/schedule controls | Restrictions and Screen-time surfaces; mapping C14/C43 |
| L4-DOWNTIME-01 | APP-07, APP-08 | BLOCKED | No existing named blocked rule; persistent schedule mutation and exact restoration unauthorized; Device Owner unavailable | `L4_011_restrictions_bottom.ui.txt`, `L4_021_child_rules.ui.txt` |
| L4-DOWNTIME-02 | POL-04 | PARTIAL | Bedtime controls and unset/unenforced presentation verified; no configured window or enforcement run | `L4_025_screen_time_policy.ui.txt`, `L4_021_child_rules.ui.txt` |
| L4-ALW-01 | APP-09 | BLOCKED | Allowed-app picker requires a snapshot; snapshot is absent; block-all mutation and Device Owner enforcement unavailable | `L4_012_allowed_picker.ui.txt` |
| L4-BLOCK-01 | APP-10–APP-12 | NOT IMPLEMENTED | No Instant Block duration/expiry selector or dedicated immediate mode | Restrictions surfaces; mapping C08/C11/C42–C44 |
| L4-BLOCK-02 | APP-03, APP-04, POL-02, POL-03, POL-05, POL-06 | BLOCKED | Device Owner required for package suspension and is unavailable; no policy mutation performed | `L4_008_app_restrictions.ui.txt`, `L4_021_child_rules.ui.txt` |
| L4-REQ-01 | APP-15, ALT-01 | NOT IMPLEMENTED | Child Requests covers linking/assistance only; no restricted-app request or Parent approve/refuse inbox | `L4_013_child_requests.ui.txt`, Alerts/Family/Restrictions surfaces |
| L4-NOTIF-01 | NTF-01, NTF-03, NTF-04 | NOT IMPLEMENTED | No Child notification-content synchronization; service/safety notifications were not treated as app-notification sync | Child permission/service baseline; Parent report surfaces |
| L4-NOTIF-02 | NTF-02 | NOT IMPLEMENTED | No Child app-wise notification selection/mute; Parent local reminder is explicitly local | `L4_028_switches_restored.ui.txt`, Child settings |
| L4-IMG-01 | IMG-01 | NOT IMPLEMENTED | No Gallery/image-scanning workflow; camera permission not treated as image detection | Settings/Rules surfaces; mapping C37/C38/C59 |
| L4-WEB-01 | WEB-01–WEB-04 | NOT IMPLEMENTED | No URL filter/history/blocked-site/safe-search/AI/website-time workflow | Restrictions/Settings/Alerts surfaces; mapping C37/C43/C48/C49 |
| L4-ALERT-01 | ALT-08 (list/filter portion) | PASS | All/Info/Warning/Critical filters and counts rendered; existing alerts already acknowledged | `L4_014_alerts.ui.txt`, `L4_015_alerts_*.ui.txt` |
| L4-ALERT-02 | ALT-08 (ack portion) | BLOCKED | Existing alerts acknowledged; acknowledgement mutation explicitly prohibited | `L4_014_alerts.ui.txt` |
| L4-ZONE-01 | LOC-07 | PASS | Existing active 150 m zone and editor 50–5000 m validation inspected; `QA_Test_Zone_Live` preserved | `L4_019_retention.ui.txt` plus lane-2 `BG02_safe_zones_*` |
| L4-ZONE-02 | LOC-07 (editor portion) | PARTIAL | Editor/validation/cancel verified; create/edit/toggle persistence prohibited | lane-2 `BG02_zone_editor*.ui.txt`, `BG02_safe_zones_after_cancel.ui.txt` |
| L4-ZONE-03 | LOC-08–LOC-11, ALT-04, ALT-05 | BLOCKED | No safe physical boundary crossing or approved zone mutation | lane-2 location/zone report; no transition artifact |
| L4-SET-01 | PRV-01–PRV-05, PRV-07, PRV-08 | PASS | Settings, privacy, retention, audit/security and disclosures inspected read-only; retention 30/90 days | `L4_016_settings.ui.txt`, `L4_018_settings_bottom.ui.txt`, `L4_019_retention.ui.txt`, `L4_030_child_settings_scrolled.ui.txt` |
| L4-SET-02 | PRV-02 (local-preference portion) | PASS | Both local switches toggled and restored `true`; UI states they do not alter server/Child authorization | `L4_027_switches_original.ui.txt`, `L4_028_switches_restored.ui.txt` |
| L4-EXPORT-01 | PRV-06 | BLOCKED | Export writes raw private JSON; retention/deletion prohibited; controls and warnings inspected only | `L4_018_settings_bottom.ui.txt` |
| L4-OFF-01 | DASH-03, ALT-03 | BLOCKED | No approved exact network-interruption/restoration path | lane-4 inventory safety rule |
| L4-FINAL-01 | FIN-01 | NOT TESTED | Deferred to final audit-wide device/session/service/network and Git verification | final report/evidence index |

Alias rows are coverage groupings, not additional tests. Final counting uses only the 112 official IDs.

## 4. Detailed findings

### 4.1 Installed-app inventory failure

Parent Restrictions showed **“No app snapshot reported”** and **“This device has not reported its installed apps yet.”** The Allowed-app picker correctly refused selection because no snapshot existed.

Child Settings showed **“App list upload failed: apps[14].package_name is not a valid Android package name.”** A sanitized comparison applied the server regex to the installed-package list without retaining identities:

- Installed packages: **343**
- Accepted by server regex: **341**
- Rejected: **2**
- Rejected single-segment names: **2**
- Package identities retained: **false**

The upload validates every entry before replacing the snapshot, so one invalid entry rejects the whole batch. This is **BUG-002**, severity High for the inventory-dependent feature family. It does not prove that all 343 names are valid Android application IDs; it proves a producer/validator contract mismatch on this device.

### 4.2 Device Admin versus Device Owner

Parent displayed:

- **“Enforcement: Device admin only”**
- **“App suspension unsupported on this device”**
- **“A database flag does not block an app”**
- Policy `Unverified`, version 3, applied 0 of 0
- No daily limit configured
- Enforcement mode `Not enforced`

Child Rules displayed **“Not enforceable on this phone”**, Device Owner required for suspension, rules version 3, and an explicit warning that nothing should be described as blocked. Some dashboard/rules cards also used **“Enforced on device”** wording. That wording tension is retained as a reporting concern, not promoted to a proven enforcement defect without a configured-rule run.

No app blocking, quota blocking, bedtime enforcement or suspension success is claimed.

### 4.3 Usage and freshness

Screen time rendered Usage Access Granted, last upload `1:35 PM · 56 min ago`, Today `9h 20m`, Last 7 days `59h 13m`, per-app durations and last-used values. A later settled view showed Today `10h 20m` and Last 7 days `60h 13m`. Refresh did not advance the upload timestamp in the sampled immediate interval.

This proves report rendering and period switching, not a controlled foreground-use interval or a newly completed background usage upload. USG-01–USG-05 therefore remain PARTIAL/NOT TESTED at official-case level as specified in report 04.

### 4.4 Alerts, zones, settings and local switches

- Alerts showed `0 unacknowledged · 2 total`; All/Info/Warning/Critical controls rendered and existing low-battery alerts were already acknowledged. No acknowledgement was performed.
- Existing `QA_Test_Zone_Live` remained Active at radius 150 m. The editor disclosed 50–5000 m and Cancel preserved the card.
- Audit & retention disclosed append-only history, location retention 30 days, usage retention 90 days, global sweep wording and export/deletion safeguards. Save retention and Purge were not activated.
- Settings showed verified Parent role, family Owner, app version 1.0.0 and security notes. Sign-out was not used.
- Both local switches were restored to `checked=true`; UI explicitly says they do not grant/revoke permissions or alter Child/server authorization.

### 4.5 Confirmed missing workflow families

Runtime navigation plus source mapping found no workflow for:

- New-install alerts or automatic new-app blocking.
- Shared selected-app allowance or individual per-app minute budget.
- Instant Block duration modes.
- Restricted-app access-request review.
- Child notification-content synchronization or app-wise notification configuration.
- Social keyword detection/management.
- Gallery/image scanning.
- Website filtering/history/blocked-site alerts/safe-search/AI monitoring.
- Family Chat, SOS or Focus Mode.
- Per-app mobile-data usage reports.

These are `NOT IMPLEMENTED`, not BLOCKED merely because their privileged permissions are absent.

## 5. Safety and restoration

- Existing Parent and Child accounts, family, pairing, device credentials and permissions were preserved.
- No sign-out, unlink, re-pair, account/device creation, permission change, Device Owner provisioning, policy/zone/alert mutation, export, purge, deletion, network change, reboot, build/install or Git mutation occurred.
- `QA_Test_Zone_Live` and residual QA data were preserved.
- Normal remote-session request/cancel evidence from `L4_032_*` is reconciled in `03_remote_access_results.md`; it is not counted as an extra Parent-feature test.
- Evidence sanitation/hash validation is recorded in `evidence/evidence_reconciliation_summary.json` and the final evidence index.
