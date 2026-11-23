# 05 — Test Coverage & Verification Plan Independent Review

**Document ID:** HAVEN-REV-005  
**Phase:** Phase 1.1 — Remediation Plan Independent Review (Strictly Read-Only)  
**Date:** 2026-11-23  
**Status:** COMPLETE INDEPENDENT TECHNICAL REVIEW  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `56636f62d5144610ae12c89d02d582feb48217fc`  

---

## 1. Overview & Verification Review Scope

This report evaluates `09_fix_verification_and_regression_test_plan.md` to determine whether the proposed automated unit, widget, native, and database test suites provide adequate coverage to prevent defect recurrence and protect against regressions.

The review specifically evaluates:
1. Positive (happy-path) test coverage.
2. Negative, boundary, and hostile edge-case test coverage.
3. Concurrency, race condition, and asynchronous failure testing.
4. Device accessibility, font scaling, and IME compatibility.
5. Absolute safety compliance (zero exposure of live credentials or sessions).

---

## 2. Test Plan Evaluation by Defect

---

### 2.1 HAVEN-QA-001 (Role Selection Button Truncation)
- **Proposed Test**: Single widget test setting physical size to 1080×2400 @ 480dpi and asserting `renderParagraph.didExceedMaxLines == false`.
- **Review Evaluation**: **INSUFFICIENT**.
- **Identified Gaps**:
  1. **Accessibility Font Scaling Gaps**: Fails to test behavior when the user enables Android OS Accessibility text scaling (e.g. `textScaleFactor: 1.3`, `1.5`, `2.0`). Under the proposed `FittedBox` fix, this test would pass even if the text shrinks to illegible 8sp micro-text!
  2. **Device Width Boundaries**: Tests only 360dp width (Realme RMX2161). Fails to test ultra-narrow screens (320dp, e.g. Android Go or small devices) and wide tablets (600dp+).
  3. **Touch Target Size**: Fails to assert that the clickable touch target height remains $\ge 48\text{ dp}$ per Material Design and WCAG 2.5.5 guidelines.
- **Required Test Additions**:
  - Test `RoleSelectionPage` with `textScaleFactor = 1.5` asserting text size remains $\ge 12\text{ sp}$.
  - Test button tap targets: `expect(tester.getSize(find.byType(AppButton).first).height, greaterThanOrEqualTo(48.0))`.

---

### 2.2 HAVEN-QA-002 (Password Input Security / SEC-001)
- **Proposed Test**: Widget test verifying `obscureText == true`, `enableSuggestions == false`, `autocorrect == false`, and `Semantics.isPassword == true`.
- **Review Evaluation**: **INSUFFICIENT (CRITICAL GAP)**.
- **Identified Gaps**:
  1. **Eyeball Visibility Toggle Test Missing (REV-003)**: Does NOT test what happens when the user taps "Show password" (`Icons.visibility_outlined`). Under the proposed design, tapping the visibility icon switches `obscureText` to `false`, causing `enableSuggestions` and `autocorrect` to revert to `true`! The test suite completely failed to test this state.
  2. **Autofill Manager Integration**: Fails to assert that `autofillHints` contains `AutofillHints.password` and triggers autofill callbacks properly without throwing exceptions.
  3. **Registration Confirm Password Field**: Only tests a standalone `AppTextField`, omitting verification of the confirm password field in `RegisterPage`.
- **Required Test Additions**:
  - Test toggling `_obscurePassword = false`: Assert that `enableSuggestions` and `autocorrect` **STILL** remain `false` even when text is visually unmasked.
  - Test `LoginPage` and `RegisterPage` form integration verifying no plaintext password is leaked to debug logs or error messages.

---

### 2.3 HAVEN-QA-003 (Device Re-credentialing Protocol)
- **Proposed Test**: SQL test `46_recredentialing.sql` verifying happy-path challenge insertion, execution of `rotate_device_secret`, and hash replacement.
- **Review Evaluation**: **CRITICALLY INCOMPLETE**.
- **Identified Gaps**:
  1. **Brute-Force Rate Limiting Test Missing**: Because of the PL/pgSQL transaction rollback bug (REV-001), the test suite did not test submitting 5 invalid tokens! If it had tested 5 invalid tokens, the developers would have immediately observed that `attempts` was never incremented!
  2. **Concurrent Redemption Race Condition**: Fails to test two simultaneous HTTP requests redeeming the same challenge token.
  3. **Client Persistence Failure / Lost Response**: Fails to test the client-side state machine when HTTP 200 is lost or KeyStore write fails.
  4. **Expired Challenge Boundary**: Fails to test redemption at $t = \text{expires\_at} + 1\text{ second}$.
  5. **Foreign Child / Foreign Family Isolation**: Fails to assert that a Child user from Family B cannot redeem a challenge issued for Family A.
  6. **Revoked Device Re-credentialing Denial**: Fails to test that a device with `status = 'revoked'` is strictly rejected by `rotate_device_secret`.
- **Required Test Additions**:
  - SQL test asserting attempt counter increments on failure:
    ```sql
    -- Submit invalid token
    perform public.rotate_device_secret(v_dev, 'wrong_token', ...);
    -- Assert attempts incremented to 1
    select attempts into v_attempts from public.device_recovery_challenges where id = v_chal;
    perform tests.assert_equals(v_attempts, 1, 'Attempt counter must increment on failure');
    ```
  - Test lockout on 5th attempt: Assert 6th attempt returns `max_attempts_exceeded`.
  - Negative test: Assert foreign child JWT receives HTTP 403 / permission denied.

---

### 2.4 HAVEN-QA-004 (Notification Permission Detection)
- **Proposed Test**: Robolectric JUnit test on Android 12 (API 31) verifying `hasNotifications()` returns true/false based on `shadowNotificationManager.setNotificationsEnabled()`.
- **Review Evaluation**: **PARTIALLY COMPLETE**.
- **Identified Gaps**:
  1. **Notification Channel Block Missing**: Fails to test Android 8.0+ (API 26+) behavior when the master notification toggle is enabled, but the Guardian service channel is set to `IMPORTANCE_NONE`.
  2. **Android 13+ Runtime Permission Matrix**: Fails to test API 33+ when runtime `POST_NOTIFICATIONS` is granted vs denied.
- **Required Test Additions**:
  - Test on API 33 with `POST_NOTIFICATIONS` denied → returns `false`.
  - Test on API 28 with channel `guardian_service_channel` blocked → returns `false`.

---

### 2.5 HAVEN-QA-005 (Revoked Devices Filter)
- **Proposed Test**: Mock repository test asserting `fetchDevices()` excludes `status == 'revoked'`.
- **Review Evaluation**: **INSUFFICIENT**.
- **Identified Gaps**:
  1. **Pending Status Device Handling**: Fails to test behavior when a family has devices in `pending` status. Under `.neq('status', 'revoked')`, pending rows leak into the active device list.
  2. **Multi-Child Families**: Fails to test families with multiple children where Child A has an active device and Child B has a revoked device.
- **Required Test Additions**:
  - Test `fetchDevices()` with a database set containing 1 active, 1 pending, and 1 revoked device: Assert returned list contains **ONLY** the active device.
  - Test explicit history query: Assert `fetchDeviceHistory()` returns all rows including revoked devices.

---

### 2.6 HAVEN-QA-006 (Policy Version Consistency)
- **Proposed Test**: Unit test for `resolvePolicyStatus()` testing `applied == 2, desired == 4` ("Updating...") and `applied == 4, desired == 4` ("Policy v4").
- **Review Evaluation**: **INSUFFICIENT**.
- **Identified Gaps**:
  1. **Enforcement Failure Case Missing**: Fails to test when `policy.status == PolicyEnforcementStatus.failed`. (Label should NOT say "Updating...").
  2. **Unmanaged / Unsupported Device Case Missing**: Fails to test when device lacks Device Owner capability (`enforcement_mode != 'device_owner'`).
  3. **Device Offline Sync-Lag Case Missing**: Fails to test when the device is offline (`device.syncHealth == DeviceSyncHealth.offline`).
- **Required Test Additions**:
  - Test when policy enforcement failed → assert label reflects failure tone.
  - Test when device is offline → assert label reflects sync paused awaiting device.

---

## 3. Test Safety & Execution Rules Verification

The proposed test plan was audited for compliance with the **Strictly Non-Destructive Testing Rules**:
- **Mock Token Usage**: All Flutter and native tests use simulated mock responses; zero live network requests are issued.
- **Disposable SQL Fixtures**: Backend tests run in a dedicated transaction with rollback or disposable local PostgreSQL containers; zero production database records are touched.
- **Zero Real Credentials**: No test fixtures or assertions contain real passwords or live user accounts.
- **Verdict**: **PASS**. The test plan respects all non-destructive testing constraints.

---

## 4. Test Plan Sign-Off Recommendation

The test plan in `09_fix_verification_and_regression_test_plan.md` is **CONDITIONALLY APPROVED**.
Before implementation begins, the engineering team must incorporate the 12 required test additions documented above to guarantee that edge cases, brute-force limits, visibility toggles, and notification channels are rigorously verified.
