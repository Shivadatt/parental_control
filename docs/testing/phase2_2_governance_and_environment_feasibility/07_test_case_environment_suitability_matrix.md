# 07 — Test Case Environment Suitability Matrix

**Document ID:** `HAVEN-GOV-007`  
**Phase:** Phase 2.2 — Owner Corrections, Governance Closure & Test Environment Feasibility Audit  
**Workspace:** `D:\parentcontrol_app`  
**Scope:** Environmental & Infrastructure Categorization for All 99 Manual Test Cases  
**Audit Standard:** Execution Prerequisite & Multi-Tenant Suitability Standard  
**Execution Posture:** STRICTLY READ-ONLY — ALL TESTS `NOT TESTED`  

---

## 1. Environment Classification Framework

Every test case in the authoritative 99-test suite has been evaluated against physical hardware and backend constraints to determine its execution compatibility under **Pathway A (Dedicated Staging)** and **Pathway B (In-Project QA Quarantine)**.

### Classification Categories (Multi-Tag Applicable):
- **`CAT-A` (Environment Independent)**: Read-only UI, client validation, local navigation. Requires zero backend mutations. Executable in any environment.
- **`CAT-B` (Staging Required)**: High-risk global operations that **CANNOT be safely executed on a shared production project** (`TC-EXP-47`, `TC-EXP-48`). Executable ONLY in Pathway A.
- **`CAT-C` (QA Isolation Compatible)**: Standard mutations that can be safely executed in Pathway B provided they are strictly scoped to dedicated QA families via RLS.
- **`CAT-D` (Physical Android Device Required)**: Requires physical hardware (camera sensor, telephony stack, persistent foreground service, device settings).
- **`CAT-E` (Specialist Infrastructure Required)**: Requires hardware benches (two-way WebRTC streaming, mock GPS injection, ADB Device Owner provisioning).
- **`CAT-F` (Owner Authorization Required)**: Requires explicit owner sign-off for destructive actions (`A09`, `FAM10`, `FAM12`) or OS permission changes (`SET05`, `SET08`, `USE03`, `LOC04`).

---

## 2. Master 99-Test Environment Suitability Matrix

| Test ID | Test Name | Environment Compatibility | Applicable Categories | Required Accounts | Required Devices | OS Permissions Needed | Status |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| **`TC-A10`** | Backend Configuration Screen | Both A & B | `CAT-A` | None | Any | None | `NOT TESTED` |
| **`TC-A06`** | Role Selection Screen Options | Both A & B | `CAT-A`, `CAT-C` | Unassigned Profile | Any | None | `NOT TESTED` |
| **`TC-SYS01`**| Offline Mode Detection Banner | Both A & B | `CAT-A` | Enrolled Session | Any | None | `NOT TESTED` |
| **`TC-A01`** | Parent & Child Email Sign-In | Both A & B | `CAT-C` | Dedicated QA User | Any | None | `NOT TESTED` |
| **`TC-A02`** | Account Registration Flow | Both A & B | `CAT-C` | Fresh QA Email | Any | None | `NOT TESTED` |
| **`TC-A04`** | Cold App Launch Auto-Login | Both A & B | `CAT-A` | Enrolled Session | Any | None | `NOT TESTED` |
| **`TC-A05`** | Sign Out & Token Revocation | Both A & B | `CAT-C` | Active Session | Any | None | `NOT TESTED` |
| **`TC-A08`** | Account Data Export (GDPR) | Both A & B | `CAT-C` | Populated QA Account| Any | None | `NOT TESTED` |
| **`TC-A09`** | Account Deletion Cascade | Both A & B | `CAT-C`, `CAT-F` | Disposable QA Account| Any | None | `NOT TESTED` |
| **`TC-A11`** | Password Reveal Toggle | Both A & B | `CAT-A` | None | Any | None | `NOT TESTED` |
| **`TC-FAM08`**| Family Group Creation | Both A & B | `CAT-C` | Fresh Parent QA User| Any | None | `NOT TESTED` |
| **`TC-FAM06`**| Pairing Code & QR Generation | Both A & B | `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-FAM01`**| Link Child via QR Scan | Both A & B | `CAT-C`, `CAT-D` | Parent + Child QA | 2 Devices (Camera) | `CAMERA` | `NOT TESTED` |
| **`TC-FAM02`**| Link Child via Manual Code | Both A & B | `CAT-C`, `CAT-D` | Parent + Child QA | 2 Devices | None | `NOT TESTED` |
| **`TC-FAM07`**| Child Hardware Registration | Both A & B | `CAT-C`, `CAT-D` | Child QA User | Android Phone | Keystore Access | `NOT TESTED` |
| **`TC-FAM10`**| Unlink Child from Dashboard | Both A & B | `CAT-C`, `CAT-D`, `CAT-F` | Paired QA Family | 2 Devices | None | `NOT TESTED` |
| **`TC-MON01`**| Parent Dashboard Summary Cards | Both A & B | `CAT-A`, `CAT-C` | Paired Parent QA | Parent Phone | None | `NOT TESTED` |
| **`TC-MON03`**| Device Detail Technical Telemetry | Both A & B | `CAT-A`, `CAT-C` | Paired QA Family | Parent Phone | None | `NOT TESTED` |
| **`TC-MON04`**| Background Heartbeat Transmission | Both A & B | `CAT-C`, `CAT-D` | Paired Child QA | Child Phone | Background Service | `NOT TESTED` |
| **`TC-USE01`**| Daily Screen Time 7-Day Chart | Both A & B | `CAT-A`, `CAT-C` | Paired QA Family | Parent Phone | None | `NOT TESTED` |
| **`TC-USE02`**| Per-Application Usage Breakdown | Both A & B | `CAT-A`, `CAT-C` | Paired QA Family | Parent Phone | None | `NOT TESTED` |
| **`TC-USE05`**| Daily Screen Time Quota Limit | Both A & B | `CAT-C` | Paired QA Family | Parent Phone | None | `NOT TESTED` |
| **`TC-APP01`**| Blocking Individual Target App | Both A & B | `CAT-C`, `CAT-D` | Paired QA Family | 2 Devices | None | `NOT TESTED` |
| **`TC-APP02`**| Whitelist Mode | Both A & B | `CAT-C`, `CAT-D` | Paired QA Family | 2 Devices | None | `NOT TESTED` |
| **`TC-APP04`**| Per-App Schedule Windows | Both A & B | `CAT-C`, `CAT-D` | Paired QA Family | 2 Devices | None | `NOT TESTED` |
| **`TC-APP05`**| Policy Delivery & ACK Loop | Both A & B | `CAT-C`, `CAT-D` | Paired QA Family | 2 Devices | None | `NOT TESTED` |
| **`TC-APP07`**| Native App Suspension Under DO | Both A & B | `CAT-D`, `CAT-E`, `CAT-F` | Child QA Device | Device Owner Phone | Device Owner (ADB) | `NOT TESTED` |
| **`TC-LOC01`**| Child Real-Time Map Location | Both A & B | `CAT-A`, `CAT-C` | Paired QA Family | Parent Phone | None | `NOT TESTED` |
| **`TC-LOC05`**| Safe Zone Geofence Creation | Both A & B | `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-LOC10`**| Safety Alerts Inbox & Read State| Both A & B | `CAT-A`, `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-REM01`**| Initiating Remote Assistance Call | Both A & B | `CAT-C`, `CAT-D`, `CAT-E` | Parent QA User | Parent Phone | `RECORD_AUDIO`, `CAMERA`| `NOT TESTED` |
| **`TC-AUD01`**| Administrative Audit Log Viewer | Both A & B | `CAT-A`, `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-CHD01`**| Child Home Protection Shield | Both A & B | `CAT-A`, `CAT-D` | Enrolled Child QA | Child Phone | None | `NOT TESTED` |
| **`TC-CHD02`**| Child Rules Oversight View | Both A & B | `CAT-A`, `CAT-D` | Enrolled Child QA | Child Phone | None | `NOT TESTED` |
| **`TC-CHD03`**| Child Requests Inbox & Modal | Both A & B | `CAT-C`, `CAT-D` | Enrolled Child QA | Child Phone | None | `NOT TESTED` |
| **`TC-CHD05`**| Hardware Self-Test (Camera/Mic) | Both A & B | `CAT-D` | Any Child Device | Physical Phone | `CAMERA`, `RECORD_AUDIO`| `NOT TESTED` |
| **`TC-CHD09`**| Emergency Quick-Call Action | Both A & B | `CAT-D` | Enrolled Child QA | Phone with Dialer | Telephony Stack | `NOT TESTED` |
| **`TC-CHD04`**| Guardian Foreground Persistent Notif| Both A & B | `CAT-D`, `CAT-E`, `CAT-F` | Enrolled Child QA | Android Phone | Battery Opt Exemption| `NOT TESTED` |
| **`TC-SET05`**| Android Device Admin Activation | Both A & B | `CAT-D`, `CAT-E`, `CAT-F` | Fresh Child Install | Android Phone | Device Admin | `NOT TESTED` |
| **`TC-SEC01`**| Cross-Family RLS Data Boundary | Both A & B | `CAT-C` | 2 QA Families | Staging / QA API | None | `NOT TESTED` |
| **`TC-SEC02`**| Staged Credential Replay Attack | Both A & B | `CAT-C` | QA Device Challenge | Staging / QA API | None | `NOT TESTED` |
| **`TC-EXP-01`**| Role Assignment Immutability | Both A & B | `CAT-C` | Fresh QA User | Any | None | `NOT TESTED` |
| **`TC-EXP-02`**| Login Invalid Password & Rate Limit | Both A & B | `CAT-A`, `CAT-C` | Known QA User | Any | None | `NOT TESTED` |
| **`TC-EXP-03`**| Registration Duplicate Email Reject | Both A & B | `CAT-A`, `CAT-C` | Registered QA Email| Any | None | `NOT TESTED` |
| **`TC-EXP-04`**| Account Data Export Schema Validate | Both A & B | `CAT-C` | Populated QA Account| Any | None | `NOT TESTED` |
| **`TC-EXP-05`**| Child Hardware Metadata Registration| Both A & B | `CAT-C`, `CAT-D` | Paired QA Family | Android Phone | Keystore Access | `NOT TESTED` |
| **`TC-EXP-06`**| Whitelist Mode Emergency Phone Bypass| Both A & B | `CAT-C`, `CAT-D` | Paired QA Family | Child Phone | None | `NOT TESTED` |
| **`TC-EXP-07`**| Child Incoming Call Dialog & Decline| Both A & B | `CAT-C`, `CAT-D`, `CAT-E` | Paired QA Family | 2 Devices | None | `NOT TESTED` |
| **`TC-EXP-08`**| WebRTC Two-Way Audio/Video Stream | Both A & B | `CAT-C`, `CAT-D`, `CAT-E` | Paired QA Family | 2 Devices (Cam/Mic)| `CAMERA`, `RECORD_AUDIO`| `NOT TESTED` |
| **`TC-EXP-09`**| Email Verification Resend Throttling| Both A & B | `CAT-C` | Unverified QA Email | Any | None | `NOT TESTED` |
| **`TC-EXP-10`**| Parent Display Name Update | Both A & B | `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-11`**| Form Real-Time Validation Feedback | Both A & B | `CAT-A` | None | Any | None | `NOT TESTED` |
| **`TC-EXP-12`**| Pending Pairing Requests List | Both A & B | `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-13`**| Cancel Outgoing Pairing Request | Both A & B | `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-14`**| Child Enrollment Consent & Cancel | Both A & B | `CAT-C`, `CAT-D` | Child QA User | Child Phone | None | `NOT TESTED` |
| **`TC-EXP-15`**| Family Members & Roles Overview | Both A & B | `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-16`**| Child Self-Unlink Protection & PIN | Both A & B | `CAT-A`, `CAT-D` | Enrolled Child QA | Child Phone | None | `NOT TESTED` |
| **`TC-EXP-17`**| Revoke Device from Dashboard | Both A & B | `CAT-C`, `CAT-D`, `CAT-F` | Paired QA Family | 2 Devices | None | `NOT TESTED` |
| **`TC-EXP-18`**| Device Re-Credentialing Recovery | Both A & B | `CAT-C`, `CAT-D`, `CAT-F` | Paired QA Family | Child Phone | Keystore Access | `NOT TESTED` |
| **`TC-EXP-19`**| Family Settings Update Backend API | Both A & B | `CAT-C` | Parent QA User | Backend / API | None | `NOT TESTED` |
| **`TC-EXP-20`**| Connected Devices List & Cards | Both A & B | `CAT-A`, `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-21`**| Child Permission Diagnostics Remote | Both A & B | `CAT-A`, `CAT-C` | Paired QA Family | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-22`**| Command Delivery & ACK History Log | Both A & B | `CAT-A`, `CAT-C` | Paired QA Family | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-23`**| Installed Apps Snapshot Upload | Both A & B | `CAT-C`, `CAT-D`, `CAT-E` | Child QA User | Android Phone | PackageManager | `NOT TESTED` |
| **`TC-EXP-24`**| Parent Dashboard Pull-to-Refresh | Both A & B | `CAT-A`, `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-25`**| Policy Sync Health Badge Transitions| Both A & B | `CAT-C`, `CAT-D` | Paired QA Family | 2 Devices | None | `NOT TESTED` |
| **`TC-EXP-26`**| Device Filter Toggle: Active/Revoked| Both A & B | `CAT-A`, `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-27`**| Usage Access Guidance Banner | Both A & B | `CAT-D`, `CAT-E`, `CAT-F` | Child QA User | Android Phone | `PACKAGE_USAGE_STATS` | `NOT TESTED` |
| **`TC-EXP-28`**| Native Usage Collection & Upload | Both A & B | `CAT-C`, `CAT-D`, `CAT-E` | Child QA User | Android Phone | `PACKAGE_USAGE_STATS` | `NOT TESTED` |
| **`TC-EXP-29`**| Bedtime Schedule & Curfew Lockout | Both A & B | `CAT-C`, `CAT-D` | Paired QA Family | 2 Devices | None | `NOT TESTED` |
| **`TC-EXP-30`**| Real-Time Remaining Quota Countdown | Both A & B | `CAT-A`, `CAT-D` | Enrolled Child QA | Child Phone | None | `NOT TESTED` |
| **`TC-EXP-31`**| Quota Exhaustion Lock Screen Trigger| Both A & B | `CAT-D`, `CAT-E`, `CAT-F` | Enrolled Child QA | Android Phone | System Window Overlay | `NOT TESTED` |
| **`TC-EXP-32`**| App Whitelist Category Selection | Both A & B | `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-33`**| Manual Policy Force-Sync Command | Both A & B | `CAT-C`, `CAT-D` | Paired QA Family | 2 Devices | None | `NOT TESTED` |
| **`TC-EXP-34`**| App Restrictions Search & Filter | Both A & B | `CAT-A` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-35`**| 24-Hour Location Route History | Both A & B | `CAT-A`, `CAT-C` | Paired QA Family | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-36`**| Child Location Sharing Switch | Both A & B | `CAT-C`, `CAT-D` | Paired QA Family | Child Phone | None | `NOT TESTED` |
| **`TC-EXP-37`**| Background Location Daemon Tracking | Both A & B | `CAT-C`, `CAT-D`, `CAT-E` | Child QA User | Android Phone | `ACCESS_BACKGROUND_LOC`| `NOT TESTED` |
| **`TC-EXP-38`**| Geofence Breach Alert Dispatch | Both A & B | `CAT-C`, `CAT-E` | Paired QA Family | Mock GPS Bench | None | `NOT TESTED` |
| **`TC-EXP-39`**| Low Battery Warning Alert Under 15% | Both A & B | `CAT-C`, `CAT-E` | Paired QA Family | Battery Mock Bench| None | `NOT TESTED` |
| **`TC-EXP-40`**| Child Device Offline Detection Alert| Both A & B | `CAT-C`, `CAT-D` | Paired QA Family | Child Phone | None | `NOT TESTED` |
| **`TC-EXP-41`**| Tamper Alert on Permission Revoke | Both A & B | `CAT-C`, `CAT-D`, `CAT-F` | Paired QA Family | Android Phone | Permission Revocation | `NOT TESTED` |
| **`TC-EXP-42`**| Safe Zone Radius Slider Resize | Both A & B | `CAT-A` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-43`**| Remote Assistance Call Log History | Both A & B | `CAT-A`, `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-44`**| Call Termination & Hardware Teardown| Both A & B | `CAT-C`, `CAT-D`, `CAT-E` | Paired QA Family | 2 Devices (Cam/Mic)| None | `NOT TESTED` |
| **`TC-EXP-45`**| In-Call Media Toggle Controls | Both A & B | `CAT-C`, `CAT-D`, `CAT-E` | Paired QA Family | 2 Devices | `CAMERA`, `RECORD_AUDIO`| `NOT TESTED` |
| **`TC-EXP-46`**| Audit Retention Period Settings | Both A & B | `CAT-C` | Parent QA User | Parent Phone | None | `NOT TESTED` |
| **`TC-EXP-47`**| On-Demand Historical Audit Purge | **PATHWAY A ONLY**| `CAT-B`, `CAT-F` | Disposable QA User| Staging DB | None | `NOT TESTED` |
| **`TC-EXP-48`**| Database Scheduled Retention Sweep | **PATHWAY A ONLY**| `CAT-B`, `CAT-F` | Database Admin | Staging DB | None | `NOT TESTED` |
| **`TC-EXP-49`**| Local Notification Preferences | Both A & B | `CAT-A` | None | Any | None | `NOT TESTED` |
| **`TC-EXP-50`**| Location Reminder Interval Dropdown | Both A & B | `CAT-A` | None | Any | None | `NOT TESTED` |
| **`TC-EXP-51`**| App Version & Build Display | Both A & B | `CAT-A` | None | Any | None | `NOT TESTED` |
| **`TC-EXP-52`**| Runtime Permission Launcher Bridge | Both A & B | `CAT-D`, `CAT-E` | Child QA User | Android Phone | Runtime Permissions | `NOT TESTED` |
| **`TC-EXP-53`**| Background Location Launcher Bridge | Both A & B | `CAT-D`, `CAT-E` | Child QA User | Android Phone | Background Location | `NOT TESTED` |
| **`TC-EXP-54`**| Permission Status Tile Visual | Both A & B | `CAT-A` | None | Any | None | `NOT TESTED` |
| **`TC-EXP-55`**| Device Admin Revocation Tamper Alert| Both A & B | `CAT-D`, `CAT-E`, `CAT-F` | Child QA User | Android Phone | Device Admin Deactivation| `NOT TESTED` |
| **`TC-EXP-56`**| Child Daemon Sync Network Reconnect | Both A & B | `CAT-C`, `CAT-D` | Child QA User | Android Phone | Airplane Mode Toggle | `NOT TESTED` |
| **`TC-EXP-57`**| Child Rules Tab Pull-to-Refresh | Both A & B | `CAT-A`, `CAT-D` | Enrolled Child QA | Child Phone | None | `NOT TESTED` |
| **`TC-EXP-58`**| Periodic Heartbeat Polling Fallback | Both A & B | `CAT-C` | Enrolled Session | Any | None | `NOT TESTED` |

---

## 3. Environment Compatibility Summary

```
+====================================================================================================+
|                                    ENVIRONMENT COMPATIBILITY TOTALS                                |
+====================================================================================================+
| Total Unique Test Cases in Master Baseline:                  99 (100.0%)                           |
| - Compatible with BOTH Pathway A and Pathway B:              97 ( 98.0%)                           |
| - Compatible ONLY with Pathway A (Staging Required):          2 (  2.0%) [TC-EXP-47, TC-EXP-48]    |
| - Blocked / Incompatible in Pathway B:                        2 (  2.0%) [TC-EXP-47, TC-EXP-48]    |
+====================================================================================================+
| Multi-Category Tag Distribution:                                                                   |
| - CAT-A (Environment Independent / Read-Only UI):            23 Test Cases                         |
| - CAT-B (Staging Project Required / Global Sweeps):           2 Test Cases                         |
| - CAT-C (QA Isolation Compatible / Scoped Mutations):        59 Test Cases                         |
| - CAT-D (Physical Android Device Required):                  36 Test Cases                         |
| - CAT-E (Specialist Hardware / Mock / ADB Bench):            16 Test Cases                         |
| - CAT-F (Owner Authorization Required / Destructive / OS):   12 Test Cases                         |
+====================================================================================================+
```
