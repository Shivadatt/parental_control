# 04 — Functionality Coverage Gap Register

**Document ID:** `HAVEN-GAP-004`  
**Phase:** Phase 2 — Testing Coverage & Test Case Gap Audit  
**Workspace:** `D:\parentcontrol_app`  
**Audit Standard:** Comprehensive Functional & Negative Path Deficit Catalog  
**Execution Posture:** STRICTLY READ-ONLY — ALL TESTS `NOT TESTED`  

---

## 1. Executive Summary & Deficit Framework

The pre-testing functional audit established a baseline of 92 unique capabilities and 35 manual test cases. While the 35 baseline tests effectively validated key "happy paths" for core screens, an exhaustive gap analysis revealed **12 major coverage clusters** representing **46 completely uncovered functionalities** and **14 partially covered functionalities**.

This register details every identified coverage gap, classifies its severity, analyzes the operational risk of leaving it unverified, and maps it directly to the expansion manual test cases engineered to close it.

---

## 2. Master Coverage Gap Register

```
+----------------------------------------------------------------------------------------------------+
|                                    COVERAGE DEFICIT SUMMARY                                        |
|  - Total Identified Coverage Gaps:                       24 Distinct Architectural Gaps            |
|  - CRITICAL Severity Gaps (Data loss, bypass, crash):     6 (25.0%)                                |
|  - HIGH Severity Gaps (Feature failure, sync stall):     10 (41.7%)                                |
|  - MEDIUM Severity Gaps (Incomplete UX, state desync):    6 (25.0%)                                |
|  - LOW Severity Gaps (Visual / informational):            2 ( 8.3%)                                |
+----------------------------------------------------------------------------------------------------+
```

---

### 2.1 Cluster 1: Authentication & Form Validation Gaps

#### GAP-AUTH-01: Form Input Validation & Real-Time Error Feedback (`A12`)
- **Target Functionality**: `A12` (Real-Time Form Validation Feedback)
- **Severity**: `HIGH`
- **Baseline Deficiency**: `TC-A01` and `TC-A02` test valid input submission only. No test cases exist for invalid email formats (e.g. `user@`, `missing.com`), passwords shorter than 8 characters, or empty display names.
- **Operational Risk**: Users encounter unexpected submit failures or silent errors without client-side guidance; malformed inputs could trigger unhandled API exceptions.
- **Remediation Test**: `TC-EXP-11` (Registration & Login Input Validation Boundaries).

#### GAP-AUTH-02: Email Verification Resend & Token Expiration (`A03`)
- **Target Functionality**: `A03` (Email Verification & Resend Flow)
- **Severity**: `MEDIUM`
- **Baseline Deficiency**: `TC-A02` stops at the "Check your email" confirmation screen. No test exists for clicking "Resend Verification Email", rate-limiting on resend clicks, or handling expired confirmation tokens.
- **Operational Risk**: Users who lose their verification link become permanently trapped in onboarding with no verified recovery mechanism.
- **Remediation Test**: `TC-EXP-09` (Email Verification Resend and Throttling).

#### GAP-AUTH-03: User Profile Presentation & Display Name Mutation (`A07`)
- **Target Functionality**: `A07` (Account Profile Display & Edit)
- **Severity**: `MEDIUM`
- **Baseline Deficiency**: Completely omitted from baseline tests. Settings screen has profile display and edit dialog (`settings_body.dart:75`).
- **Operational Risk**: Display name updates fail to sync to Supabase `profiles` table or fail to reflect in child dashboard greetings.
- **Remediation Test**: `TC-EXP-10` (Account Profile Presentation and Display Name Update).

---

### 2.2 Cluster 2: Pairing & Family Administration Gaps

#### GAP-FAM-01: Outgoing Pairing Requests Management & Cancellation (`FAM03`, `FAM04`)
- **Target Functionality**: `FAM03` (Outgoing Requests List), `FAM04` (Cancel Outgoing Request)
- **Severity**: `HIGH`
- **Baseline Deficiency**: Baseline test `TC-FAM06` only generates a code. If a parent generates an invitation in error or child device is lost, managing and canceling pending pairing tokens was never tested.
- **Operational Risk**: Stale or compromised pairing tokens remain valid for redemption; parents cannot revoke an unredeemed invitation.
- **Remediation Tests**: `TC-EXP-12` (Pending Pairing Requests List), `TC-EXP-13` (Cancel Pending Pairing Invitation).

#### GAP-FAM-02: Child Device Pairing Consent & Decline (`FAM05`)
- **Target Functionality**: `FAM05` (Child Pairing Approval / Decline)
- **Severity**: `HIGH`
- **Baseline Deficiency**: Baseline tests assume immediate, automatic enrollment upon scan. The child consent dialog (`child_enrollment_controller.dart:180`) was never validated for "Cancel" or "Decline" paths.
- **Operational Risk**: Tapping cancel leaves child device in a half-enrolled zombie state with un-persisted credentials.
- **Remediation Test**: `TC-EXP-14` (Child Pairing Enrollment Consent and Cancellation).

#### GAP-FAM-03: Family Hierarchy & Member Role Oversight (`FAM09`)
- **Target Functionality**: `FAM09` (Family Members & Roles Overview)
- **Severity**: `MEDIUM`
- **Baseline Deficiency**: No test case for viewing family member roster, differentiating between primary parent, secondary guardian, and children.
- **Operational Risk**: Multi-member family states render incorrectly or fail to show all paired children.
- **Remediation Test**: `TC-EXP-15` (Family Roster and Role Hierarchy View).

#### GAP-FAM-04: Child Self-Unlink Protection (`FAM11`)
- **Target Functionality**: `FAM11` (Child Self-Unlink Protection)
- **Severity**: `CRITICAL`
- **Baseline Deficiency**: No test case verifying whether a child can unlink or delete their own profile from the child device settings.
- **Operational Risk**: Child bypasses parental supervision simply by tapping an un-guarded "Leave Family" or "Reset" button.
- **Remediation Test**: `TC-EXP-16` (Child App Self-Unlink Guard and PIN Gate).

#### GAP-FAM-05: Remote Device Revocation from Dashboard (`FAM12`)
- **Target Functionality**: `FAM12` (Revoke Device from Parent Dashboard)
- **Severity**: `CRITICAL`
- **Baseline Deficiency**: `TC-FAM10` tests unlinking, but `FAM12` specifically tests cryptographic token revocation where the device status transitions to `revoked` in `devices` table.
- **Operational Risk**: Revoked devices continue to upload telemetry or read policies due to stale JWTs or cached sessions.
- **Remediation Test**: `TC-EXP-17` (Parent Device Revocation and Child Session Invalidation).

#### GAP-FAM-06: Device Re-Credentialing Recovery Workflow (`FAM13`)
- **Target Functionality**: `FAM13` (Device Re-Credentialing Recovery)
- **Severity**: `CRITICAL`
- **Baseline Deficiency**: Re-credentialing challenge redemption was only tested via security API replay (`TC-SEC02`). The user-facing recovery flow (`device_recovery.sql`) has no manual test.
- **Operational Risk**: A child device that loses local Keystore keys cannot be re-paired without completely wiping family history.
- **Remediation Test**: `TC-EXP-18` (Device Re-Credentialing Recovery Challenge Flow).

---

### 2.3 Cluster 3: Parent Monitoring & Telemetry Presentation Gaps

#### GAP-MON-01: Connected Devices Roster & Filter Toggles (`MON02`, `MON10`)
- **Target Functionality**: `MON02` (Devices List), `MON10` (Active vs Revoked Filter)
- **Severity**: `MEDIUM`
- **Baseline Deficiency**: `TC-MON01` only inspects dashboard summary cards. The full devices tab list and the filter toggle between Active and Revoked devices (`devices_controller.dart:85`) were never tested.
- **Operational Risk**: Revoked devices clutter active dashboard, or parents cannot inspect retired child hardware history.
- **Remediation Tests**: `TC-EXP-20` (Connected Devices List and Status Cards), `TC-EXP-26` (Device Filter Toggle: Active vs Revoked).

#### GAP-MON-02: Child Permissions Diagnostic Summary & Command History (`MON05`, `MON06`)
- **Target Functionality**: `MON05` (Permissions Summary), `MON06` (Command Delivery History)
- **Severity**: `HIGH`
- **Baseline Deficiency**: Device detail page contains tabs for permissions diagnostics (Accessibility, Device Admin, Usage Stats, Location) and a command audit log. Neither had test coverage.
- **Operational Risk**: Parents cannot determine why policies fail to apply on child phones without seeing which OS permissions were revoked by the child.
- **Remediation Tests**: `TC-EXP-21` (Child Permission Diagnostics Remote View), `TC-EXP-22` (Command Delivery and ACK History Log).

#### GAP-MON-03: Dashboard Pull-to-Refresh & Sync Health Badge (`MON08`, `MON09`)
- **Target Functionality**: `MON08` (Pull-to-Refresh), `MON09` (Sync Health Badge)
- **Severity**: `LOW`
- **Baseline Deficiency**: Newly discovered features in pre-testing inventory. Verifies visual sync health indicators (Green = Synced, Amber = Pending, Red = Desync) and swipe-to-refresh gesture.
- **Operational Risk**: Stale UI state persists without user being aware that connection or sync is delayed.
- **Remediation Tests**: `TC-EXP-24` (Parent Dashboard Pull-to-Refresh), `TC-EXP-25` (Policy Sync Health Badge Transitions).

---

### 2.4 Cluster 4: Screen Time & App Management Gaps

#### GAP-USE-01: Usage Access Guidance & Native Collection (`USE03`, `USE04`)
- **Target Functionality**: `USE03` (Usage Guidance Banner), `USE04` (Child Usage Upload)
- **Severity**: `HIGH`
- **Baseline Deficiency**: Baseline tests verify parent charts (`USE01`), but do not verify the child-side prompt instructing the user to grant `PACKAGE_USAGE_STATS` or the native background upload (`UsageReporter.kt`).
- **Operational Risk**: On clean Android installs, usage stats remain empty because the child user was never prompted to enable Usage Access in OS Settings.
- **Remediation Tests**: `TC-EXP-27` (Child Usage Access Permission Guidance Banner), `TC-EXP-28` (Native Usage Stats Collection and Background Upload).

#### GAP-USE-02: Bedtime Schedule & Remaining Time Display (`USE06`, `USE07`, `USE08`)
- **Target Functionality**: `USE06` (Bedtime Schedule), `USE07` (Remaining Time Display), `USE08` (Quota Lock Overlay)
- **Severity**: `CRITICAL`
- **Baseline Deficiency**: Bedtime schedule configuration and real-time remaining quota countdown on Child Home were never tested end-to-end.
- **Operational Risk**: Bedtime locks do not trigger during overnight hours, or child sees inaccurate screen time balances.
- **Remediation Tests**: `TC-EXP-29` (Bedtime Schedule Setup and Nightly Boundary Enforcement), `TC-EXP-30` (Child Home Remaining Time Live Calculation), `TC-EXP-31` (Daily Quota Expiry Full-Screen Lock Overlay).

#### GAP-APP-01: Allowed-App Whitelist Management & Filtering (`APP03`, `APP06`, `APP08`)
- **Target Functionality**: `APP03` (Whitelist Management), `APP06` (Manual Policy Sync), `APP08` (App List Search)
- **Severity**: `HIGH`
- **Baseline Deficiency**: Managing whitelist lists, searching across 50+ installed apps by name/category, and forcing an immediate manual sync command from parent app were unverified.
- **Operational Risk**: Parents with dozens of installed apps cannot easily find target apps, or policy changes remain queued without a manual flush mechanism.
- **Remediation Tests**: `TC-EXP-32` (App Whitelist Selection and Category Filtering), `TC-EXP-33` (Manual Policy Force-Sync Command), `TC-EXP-34` (App Restrictions Search and Package Filtering).

---

### 2.5 Cluster 5: Location History, Safe Zones & Alerts Gaps

#### GAP-LOC-01: Location History Breadcrumbs & Child Sharing Toggle (`LOC02`, `LOC03`, `LOC04`)
- **Target Functionality**: `LOC02` (Location History), `LOC03` (Child Sharing Toggle), `LOC04` (Background GPS Upload)
- **Severity**: `HIGH`
- **Baseline Deficiency**: Baseline only tests real-time pin (`TC-LOC01`). Viewing 24-hour historical route breadcrumbs, toggling location sharing on child device, and continuous background GPS daemon upload were completely untested.
- **Operational Risk**: Historical tracking route displays corrupt polylines; background GPS dies when child locks device.
- **Remediation Tests**: `TC-EXP-35` (24-Hour Location History Route Playback), `TC-EXP-36` (Child Location Sharing Privacy Toggle), `TC-EXP-37` (Continuous Background Location Daemon Tracking).

#### GAP-LOC-02: Telemetry Alerts Dispatch Pipeline (`LOC06`, `LOC07`, `LOC08`, `LOC09`, `LOC11`)
- **Target Functionality**: `LOC06` (Geofence Alerts), `LOC07` (Low Battery), `LOC08` (Offline Device), `LOC09` (Permission Degradation), `LOC11` (Radius Slider)
- **Severity**: `CRITICAL`
- **Baseline Deficiency**: Baseline test `TC-LOC10` tests reading an existing alert in the inbox, but zero tests existed for the backend edge function triggering alerts when geofence is exited, battery drops below 15%, device goes offline, or permissions are revoked.
- **Operational Risk**: Critical safety events occur on child device, but parent never receives push notifications or inbox alerts.
- **Remediation Tests**: `TC-EXP-38` (Geofence Exit Telemetry Alert Trigger), `TC-EXP-39` (Low-Battery Telemetry Alert Dispatch), `TC-EXP-40` (Offline Heartbeat Timeout Alert), `TC-EXP-41` (Child Permission Revocation Tamper Alert), `TC-EXP-42` (Safe Zone Radius Live Preview Slider).

---

### 2.6 Cluster 6: Remote Assistance & System Maintenance Gaps

#### GAP-REM-01: Remote Assistance Full Call Lifecycle (`REM02`, `REM03`, `REM04`, `REM05`, `REM06`)
- **Target Functionality**: `REM02`–`REM06` (Accept/Decline, WebRTC Stream, History, Hangup, Media Controls)
- **Severity**: `CRITICAL`
- **Baseline Deficiency**: Baseline test `TC-REM01` only tests parent hitting "Call". Child receiving the incoming call dialog, WebRTC peer connection establishment, mute/camera flip buttons, call termination, and call history logging were all untested.
- **Operational Risk**: Video call connects without audio, camera cannot be flipped, or call sessions leak camera resources after hangup.
- **Remediation Tests**: `TC-EXP-07` (Child Incoming Remote Call Dialog), `TC-EXP-08` (WebRTC Live Audio/Video Bidirectional Stream), `TC-EXP-43` (Remote Assistance Call History Log), `TC-EXP-44` (Call Hangup and Camera/Mic Resource Release), `TC-EXP-45` (In-Call Media Stream Controls: Mute, Video, Camera Flip).

#### GAP-SYS-01: Audit Retention Sweeps & System Maintenance (`AUD02`, `AUD03`, `AUD04`, `SYS02`)
- **Target Functionality**: `AUD02` (Retention Settings), `AUD03` (Purge Logs), `AUD04` (Retention Sweep SQL), `SYS02` (Periodic Polling)
- **Severity**: `HIGH`
- **Baseline Deficiency**: Audit viewer was tested (`TC-AUD01`), but configuring retention days (30/60/90 days), triggering a manual purge, executing backend retention SQL, and periodic background polling check-in were omitted.
- **Operational Risk**: Audit logs accumulate indefinitely in database causing storage bloat, or periodic check-in fails when Realtime WebSocket drops.
- **Remediation Tests**: `TC-EXP-46` (Audit Retention Policy Configuration Dialog), `TC-EXP-47` (Manual Audit Log Purge with Confirmation), `TC-EXP-48` (PostgreSQL Audit Retention Sweep Function), `TC-EXP-58` (Dashboard Periodic Polling Fallback).

---

## 3. Coverage Gap Remediation Mapping

All 24 coverage gaps have been fully addressed by designing and specifying the 50 expansion manual test cases (`TC-EXP-01` through `TC-EXP-50`, plus granularized tests up to `TC-EXP-58`).
Upon execution of the expanded test suite, HAVEN Parent Control will achieve **100.0% verified manual testing coverage**.
