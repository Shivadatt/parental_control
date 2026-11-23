# 09 — Defect Register

Audit Execution Date: 2026-11-23  
Phase: Phase 6 Comprehensive End-to-End Execution  
Audit Authority: HAVEN QA Team

---

## 1. Defect Summary Table (Sorted by Severity)

| Issue ID | Title | Severity | Confidence | Affected Role | Functionality ID | Test Case ID | Status |
|---|---|---|---|---|---|---|---|
| **HAVEN-QA-002** | Password input exposes plaintext / lacks secure input hardening (SEC-001) | **High** | Confirmed | Shared | A01, A02 | P6-SEC-001 | Open (Security Finding) |
| **HAVEN-QA-003** | Device re-credentialing failure breaks heartbeat, usage & location uploads (DEF-601) | **High** | Confirmed | Child / Interconnected | MON04 | P6-LIM-001, P6-INT-004 | Open (Documented Limitation) |
| **HAVEN-QA-005** | Revoked devices duplicated in Parent dashboard and device list (DEF-602) | **High** | Confirmed | Parent | MON02, FAM12 | P6-PAR-008, P6-PAR-011 | Open (Known Defect) |
| **HAVEN-QA-004** | Notification permission reports false-positive "Granted" (DEF-604) | **Medium** | Confirmed | Child / Interconnected | MON05 | P6-LIM-002 | Open (Documented Limitation) |
| **HAVEN-QA-006** | Policy version inconsistency between Dashboard and Devices tab (DEF-603) | **Medium** | Confirmed | Parent | MON01, MON02 | P6-PAR-010, P6-PAR-011 | Open (Known Defect) |
| **HAVEN-QA-001** | Action button text truncated ("Create acc...") on Role Selection screen | **Low** | Confirmed | Shared | A06 | P6-SHR-006 / UI-Audit | Open (New Defect) |

---

## 2. Detailed Defect Records

---

### HAVEN-QA-001: Action Button Text Truncated ("Create acc...") on Role Selection Screen
- **Severity**: Low
- **Confidence**: Confirmed
- **Affected Role**: Shared (Parent Mode & Child Mode option cards)
- **Device**: Realme RMX2161 (Realme 7, Android 12, 1080×2400 px, 480 dpi)
- **Functionality ID**: A06 (Role selection)
- **Test-Case ID**: P6-SHR-006 / UI-Audit
- **Screen / Module**: `RoleSelectionPage` (`lib/features/role_selection/role_selection_page.dart`)
- **Preconditions**: Device resolution 1080×2400 with standard 480 dpi font scaling.
- **Reproduction Steps**:
  1. Launch the application on Realme RMX2161.
  2. Observe the Role Selection screen ("How will you use Parent Control?").
  3. Inspect the right-hand action button on both Parent Mode and Child Mode cards.
- **Expected Result**: Button displays complete text label *"Create account"*.
- **Actual Result**: Button text is clipped with an ellipsis, displaying *"Create acc..."*.
- **Reproducibility**: 100% reproducible on 480 dpi mobile displays.
- **Evidence Path**:
  - Screenshot: `docs/testing/phase6_comprehensive_execution/evidence/child_role_selection_clipped.png`
  - UI Hierarchy Dump: `docs/testing/phase6_comprehensive_execution/evidence/child_dump.xml` (bounds `[555,1475][969,1625]`)
- **Impact**: Degrades visual polish and onboarding usability; text truncation creates an unpolished user experience.
- **New or Known**: **NEW ISSUE** discovered during Phase 6 live testing.
- **Documented Limitation?**: No.
- **Recommended Investigation Area**: In `lib/features/role_selection/role_selection_page.dart`, adjust `AppButton` horizontal padding, wrap text in `FittedBox`, or allow `maxLines: 2`.

---

### HAVEN-QA-002: Password Input Exposes Plaintext / Lacks Secure Input Hardening (SEC-001)
- **Severity**: High
- **Confidence**: Confirmed
- **Affected Role**: Shared (Authentication)
- **Device**: Pixel 9 Emulator / Cross-Device
- **Functionality ID**: A01 (Sign-in), A02 (Registration)
- **Test-Case ID**: P6-SEC-001
- **Screen / Module**: `LoginPage` (`lib/features/auth/login_page.dart`), `AppTextField` (`lib/core/widgets/app_text_field.dart`)
- **Preconditions**: User at Sign-in or Register screen.
- **Reproduction Steps**:
  1. Open Sign-in screen.
  2. Focus the Password input field.
  3. Inspect UI accessibility semantics and input configuration.
- **Expected Result**: Password input strictly enforces secure password semantics (`password: true`), disables clipboard exposure, and disables keyboard text prediction/suggestions.
- **Actual Result**: `AppTextField` lacks `enableSuggestions: false` and `autocorrect: false`. During Run 8 live inspection, the input accessibility node reported `password=false` and displayed entered credentials in plaintext prior to submission.
- **Reproducibility**: Confirmed in code audit; observed in Run 8 execution.
- **Evidence Path**:
  - `docs/testing/phase6_master_matrix/07_security_and_approval_required_register.md` (SEC-001).
  - Code inspection of `lib/core/widgets/app_text_field.dart:41-59`.
- **Impact**: Severe security and privacy exposure; potential credential harvesting via screen readers, accessibility services, or keyboard predictive caches.
- **New or Known**: Known security issue (SEC-001).
- **Documented Limitation?**: No (Security Defect).
- **Recommended Investigation Area**: In `lib/core/widgets/app_text_field.dart`, add `enableSuggestions: false`, `autocorrect: false`, and ensure explicit password accessibility semantics when `obscureText: true`.

---

### HAVEN-QA-003: Device Re-credentialing Failure Breaks Heartbeat, Usage & Location Uploads (DEF-601)
- **Severity**: High
- **Confidence**: Confirmed
- **Affected Role**: Child / Interconnected
- **Device**: Realme RMX2161
- **Functionality ID**: MON04
- **Test-Case ID**: P6-LIM-001, P6-INT-004
- **Screen / Module**: Guardian Background Service / Telemetry Upload Pipeline
- **Preconditions**: Child app reinstalled or fresh APK deployed on existing enrolled hardware.
- **Reproduction Steps**:
  1. Deploy fresh build to Child device.
  2. Launch app and observe Background protection in Settings.
  3. Inspect device upload logs and heartbeat status.
- **Expected Result**: Child device credentials reconcile with backend `device_credentials` table; heartbeat updates `last_seen_at`; usage and location telemetry upload smoothly.
- **Actual Result**: Client generates new local key/secret while server retains historical `secret_hash`. Background sync logs report *"Device credentials are not valid"*; child device remains permanently "Offline" on Parent dashboard.
- **Reproducibility**: 100% on reinstalled/updated client instances without manual database re-seeding.
- **Evidence Path**:
  - `docs/testing/functionality_inventory/05_missing_and_incomplete_functionalities.md` (MON04).
  - `docs/testing/phase_6_comprehensive_manual_testing/reports/11_defect_register.md` (DEF-601).
- **Impact**: Primary parent control features (live location, daily app usage tracking, online presence alerts) become non-functional.
- **New or Known**: Known architectural limitation and confirmed defect.
- **Documented Limitation?**: Yes (Documented Limitation MON04).
- **Recommended Investigation Area**: Implement an authenticated device credential rotation RPC allowing an enrolled child account to re-register its device secret with server authorization.

---

### HAVEN-QA-004: Notification Permission Reports False-Positive "Granted" (DEF-604)
- **Severity**: Medium
- **Confidence**: Confirmed
- **Affected Role**: Child / Interconnected
- **Device**: Realme RMX2161 (Android 12)
- **Functionality ID**: MON05
- **Test-Case ID**: P6-LIM-002
- **Screen / Module**: Child Settings → Android permissions / Parent Device Detail
- **Preconditions**: App installed on Android device without notification grant.
- **Reproduction Steps**:
  1. Open Child Settings → Android permissions.
  2. Compare displayed "Notifications: Granted" status with `adb shell dumpsys package com.parentcontrol.parent_control`.
- **Expected Result**: UI displays "Notifications: Not Granted" or "Optional" when `POST_NOTIFICATIONS` is not granted.
- **Actual Result**: Application reports "Granted" when OS runtime dump confirms permission is absent or unrequested.
- **Reproducibility**: 100% on Android versions where `POST_NOTIFICATIONS` is not granted.
- **Evidence Path**:
  - `dumpsys_permissions_child.txt` (shows `POST_NOTIFICATIONS` not in runtime permissions).
  - `docs/testing/phase_6_comprehensive_manual_testing/reports/11_defect_register.md` (DEF-604).
- **Impact**: Parents receive inaccurate health indicators; may lead to false assumptions regarding child alert delivery.
- **New or Known**: Known issue (DEF-604).
- **Documented Limitation?**: Yes (Documented Limitation MON05).
- **Recommended Investigation Area**: Audit permission checking logic in `lib/data/services/permission_service.dart` to properly branch for Android 13+ (`API >= 33`) vs legacy Android notification settings.

---

### HAVEN-QA-005: Revoked Devices Duplicated in Parent Dashboard & Device List (DEF-602)
- **Severity**: High
- **Confidence**: Confirmed
- **Affected Role**: Parent
- **Device**: Pixel 9 Emulator
- **Functionality ID**: MON02, FAM12
- **Test-Case ID**: P6-PAR-008, P6-PAR-011
- **Screen / Module**: Parent Dashboard / Devices Tab
- **Preconditions**: A child device has been revoked via device management.
- **Reproduction Steps**:
  1. Open Parent Dashboard and Devices tab.
  2. Observe device cards.
- **Expected Result**: Revoked devices are cleanly archived or excluded from active monitoring cards.
- **Actual Result**: Two cards appear for the same physical device: one marked "Revoked", one marked "Offline", creating duplicate entries.
- **Reproducibility**: 100% when revoked device rows exist in database.
- **Evidence Path**: `docs/testing/phase_6_comprehensive_manual_testing/reports/11_defect_register.md` (DEF-602).
- **Impact**: Confusing UX for parents; risk of applying policies to stale or duplicate device rows.
- **New or Known**: Known defect (DEF-602).
- **Documented Limitation?**: No (Bug in device list projection query).
- **Recommended Investigation Area**: In `lib/data/repositories/device_repository.dart`, filter out revoked devices (`status != 'revoked'`) from active device queries, or separate them into an "Archived Devices" section.

---

### HAVEN-QA-006: Policy Version Inconsistency Across Parent Dashboard and Devices Tab (DEF-603)
- **Severity**: Medium
- **Confidence**: Confirmed
- **Affected Role**: Parent
- **Device**: Pixel 9 Emulator
- **Functionality ID**: MON01, MON02
- **Test-Case ID**: P6-PAR-010, P6-PAR-011
- **Screen / Module**: Parent Dashboard vs Devices Tab
- **Preconditions**: Device policy updated to a new version.
- **Reproduction Steps**:
  1. Open Parent Dashboard and note policy version on device card (e.g. Policy v4).
  2. Navigate to Devices tab and inspect the same device (shows Policy v2).
- **Expected Result**: Policy version is consistent across all views.
- **Actual Result**: Dashboard and Devices tab project different policy version numbers.
- **Reproducibility**: 100% when policy revisions have occurred.
- **Evidence Path**: `docs/testing/phase_6_comprehensive_manual_testing/reports/11_defect_register.md` (DEF-603).
- **Impact**: Inconsistent status reporting; parent cannot confirm which policy is actively enforced.
- **New or Known**: Known defect (DEF-603).
- **Documented Limitation?**: No.
- **Recommended Investigation Area**: Harmonize policy query joins across `DashboardController` and `DevicesController`.
