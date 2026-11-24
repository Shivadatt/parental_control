# Phase 1.4: Future Verification and Staging Test Plan

**Document ID:** `HAVEN-AUD-011-PHASE1.4`  
**Phase:** Phase 1.4 — Independent Security Clarification & Final Authorization Gate Audit  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Rigorous Staging Verification Protocol  

---

## 1. Executive Summary

This document establishes the comprehensive, multi-phase verification and test execution plan required before any code implemented in Waves 1, 2, or 3 can be deployed to production environments or executed on live test devices. 

It defines test environments, automated test specifications, mock harnesses, stress fixtures, and objective pass/fail exit criteria across the Canonical 8-Gate Lifecycle, ensuring that theoretical design proofs are validated by rigorous runtime evidence.

---

## 2. Test Environment Architecture & Governance

To preserve the production database, active credentials, and enrolled test devices (`emulator-5554` and `5HXWRGQ4IFU8WS4T`), all verification activities must take place within isolated, disposable environments.

```
+-------------------------------------------------------------------------+
|                  DISPOSABLE STAGING TEST HARNESS                         |
|                                                                         |
|  +---------------------+   +---------------------+   +---------------+  |
|  |  Ephemeral Staging  |   | Deno Deploy Staging |   | Mock Android  |  |
|  |  PostgreSQL Engine  |<--| Edge Function Host  |<--| Client Runner |  |
|  |  (Local/Container)  |   | (Isolated Project)  |   | (Robolectric) |  |
|  +---------------------+   +---------------------+   +---------------+  |
|            ^                         ^                       ^          |
|            |                         |                       |          |
|    [Gate 4 Migrations]       [Gate 5 Edge Code]      [Gate 2 Client]    |
+-------------------------------------------------------------------------+
                                     |
                                     v
                       +---------------------------+
                       | Gate 6: Staging E2E Suite |
                       +---------------------------+
                                     |
                                     v (Owner Explicit Approval Required)
                       +---------------------------+
                       | Gate 7: Production Deploy |
                       +---------------------------+
                                     |
                                     v
                       +---------------------------+
                       | Gate 8: Live Device QA    |
                       +---------------------------+
```

### Environment Isolation Invariants
1. **Zero Production Mutation**: No test runner may connect to the production Supabase database or edge endpoints during Gates 2 through 6.
2. **Disposable Database Instances**: Staging database instances must be completely ephemeral (e.g., local Supabase CLI docker containers or disposable branch databases).
3. **Hardware Device Quarantine**: The physical Realme phone (`5HXWRGQ4IFU8WS4T`) and the Pixel 9 emulator (`emulator-5554`) are strictly quarantined and must not be used until Gate 8 is authorized.

---

## 3. Wave 1 Test Specification: Client Security, UI & Native Permissions

Wave 1 encompasses client-side fixes: `HAVEN-QA-001` (password visibility toggle), `HAVEN-QA-002` (UI text scaling and button wrapping), and `HAVEN-QA-005` (notification channel diagnostic).

### 3.1 HAVEN-QA-001: Password Visibility & Masking Unit Tests
- **Target**: `AppTextField` and its 3 authentic callers (`auth_form_fields.dart`, `parent_pin_dialog.dart`, `login_page.dart`).
- **Framework**: `flutter_test`.
- **Test Cases**:
  1. `test_password_field_initializes_masked`: Verify `obscureText == true` when `isPassword: true` on initial render.
  2. `test_password_field_toggles_visibility`: Tap visibility icon; assert `obscureText == false`. Tap again; assert `obscureText == true`.
  3. `test_decoupled_obscure_text_independence`: Pass `isPassword: true` and verify `obscureText` can be overridden or decoupled without internal state corruption.
  4. `test_pin_dialog_masks_input`: Verify `ParentPinDialog` renders PIN input masked by default with working reveal toggle.
  5. `test_non_password_field_has_no_toggle`: Pass `isPassword: false`; assert suffix icon toggle is absent.

### 3.2 HAVEN-QA-002: Dynamic Layout & Text Scaling Golden Widget Tests
- **Target**: `QuickActionsCard` inside `parent_dashboard_page.dart`.
- **Framework**: `flutter_test` with custom screen surface constraints.
- **Test Matrix (Width x Text Scale)**:
  - Widths: `320dp` (small handset), `360dp` (standard Android), `400dp` (modern Android), `480dp` (large handset).
  - Text Scalers: `TextScaler.noScaling` (1.0x), `TextScaler.linear(1.15)` (1.15x threshold), `TextScaler.linear(1.5)` (1.5x large), `TextScaler.linear(2.0)` (2.0x max accessibility).
- **Assertions**:
  1. For `screen_width < 420dp` or `textScaler.scale(1.0) > 1.15`: Buttons render in a `Column` (vertical layout).
  2. For `screen_width >= 420dp` and `textScaler.scale(1.0) <= 1.15`: Buttons render in a `Row` (horizontal layout).
  3. Zero `RenderFlex overflowed by X pixels` layout exceptions across all 16 matrix combinations.
  4. Verify button touch targets remain $\ge 48\text{dp}$ height under all configurations.

### 3.3 HAVEN-QA-005: Native Notification Channel Typed Diagnostics
- **Target**: `GuardianService.kt` and `MethodChannel` bridge.
- **Framework**: Android JUnit / Robolectric test harness.
- **Test Cases**:
  1. `test_existing_channel_returns_active`: Query `NotificationManager.getNotificationChannel("guardian_status")` when channel exists; assert response is `ACTIVE`.
  2. `test_missing_channel_returns_typed_error`: Mock `getNotificationChannel` returning `null`; assert response is `REQUIRED_CHANNEL_NOT_CREATED` (not a generic null pointer or channel creation crash).
  3. `test_disabled_notifications_returns_notifications_disabled`: Mock `areNotificationsEnabled() == false`; assert response is `NOTIFICATIONS_DISABLED`.
  4. `test_blocked_channel_returns_channel_blocked`: Mock `channel.importance == IMPORTANCE_NONE`; assert response is `CHANNEL_BLOCKED`.

---

## 4. Wave 2 Test Specification: Client Persistence & Repository Integrity

Wave 2 encompasses `HAVEN-QA-004` (device list filter desynchronization) and `HAVEN-QA-006` (policy status presentation misleading state).

### 4.1 HAVEN-QA-004: Clean Repository Methods & Ternary State Unit Tests
- **Target**: `DeviceRepository` and `DeviceService`.
- **Framework**: Dart unit tests (`test`).
- **Test Cases**:
  1. `test_fetch_active_devices_filters_correctly`: Query returns 5 devices (2 active, 2 revoked, 1 pending); `fetchActiveDevices()` returns strictly the 2 active devices (`status == 'active'`).
  2. `test_fetch_device_history_returns_all_statuses`: Query returns all devices; verify history list includes `active`, `revoked`, and `pending` records.
  3. `test_fetch_pending_devices_returns_strictly_pending`: Verify only `pending` enrollment records are returned.
  4. `test_domain_model_parses_ternary_statuses`: Assert `Device.fromJson` correctly deserializes `'active'`, `'revoked'`, and `'pending'` without defaulting or dropping records.

### 4.2 HAVEN-QA-006: Canonical Policy Status & SyncHealth Presentation Tests
- **Target**: `PolicyCard` and `PolicyStatusBadge` widgets.
- **Framework**: `flutter_test`.
- **Test Cases**:
  1. `test_canonical_enforced_status_displays_active_protection`: Model with `status == 'enforced'` and `syncHealth == 'healthy'` renders badge "Active Protection" in primary green.
  2. `test_enforced_with_stale_sync_displays_sync_delayed`: Model with `status == 'enforced'` and `syncHealth == 'stale'` renders warning badge "Sync Delayed".
  3. `test_pending_status_displays_pending_activation`: Model with `status == 'pending'` renders badge "Pending Activation" in amber.
  4. `test_revoked_status_displays_inactive`: Model with `status == 'revoked'` renders badge "Protection Disabled" in neutral gray.
  5. `test_invalid_active_status_rejected_at_parse`: Raw JSON with `status: 'active'` triggers validation assertion or maps safely to typed fallback with warning logged.

---

## 5. Wave 3 Test Specification: Re-credentialing Protocol & Backend (Gate 4–6)

Wave 3 encompasses `HAVEN-QA-003` (Device Re-credentialing Architecture). Testing must be executed strictly across Gates 4, 5, and 6.

### 5.1 Gate 4: Disposable Staging PostgreSQL Migration Verification
- **Target**: PostgreSQL Migration Script `20261124000100_device_recredentialing.sql`.
- **Environment**: Isolated PostgreSQL 15+ container instance.
- **Automated Verification Suite (`pgTAP` / Node.js test script)**:
  1. `test_migration_applies_cleanly`: Execute migration script; verify zero SQL syntax errors or warnings.
  2. `test_constant_time_equals_correctness`:
     - Test identical strings return `true`.
     - Test mismatched strings of equal length return `false`.
     - Test mismatched strings of different lengths return `false`.
     - Test empty strings return `true`.
  3. `test_partial_unique_index_enforcement`:
     - Insert active challenge for `device_1` $\rightarrow$ Success.
     - Insert second active challenge for `device_1` $\rightarrow$ DB raises unique constraint violation.
     - Update first challenge to `superseded`; insert second active challenge $\rightarrow$ Success.
  4. `test_rotate_device_secret_transactional_commit`:
     - Call `rotate_device_secret` with valid token $\rightarrow$ Verifies `devices.secret_hash` updated and challenge status is `'redeemed'`.
     - Call `rotate_device_secret` with invalid token $\rightarrow$ Verifies `attempts` counter increments to 1, committed to disk.
  5. `test_attempt_lockout_invariant`:
     - Submit 5 invalid tokens sequentially. Assert attempt counter increments: 1, 2, 3, 4, 5.
     - At attempt 5, assert status transitions to `'exhausted'` and `attempts_remaining: 0`.
     - Submit 6th attempt; assert immediate rejection without further counter increment.
  6. `test_row_level_locking_prevents_deadlock`:
     - Interleave concurrent `rotate_device_secret` and `revoke_device` operations across 20 connections; verify zero deadlock exceptions (`40P01`).

### 5.2 Gate 5: Edge Function Staging Unit & Concurrency Tests
- **Target**: Supabase Edge Functions (`family-admin`, `device-register`, `device-telemetry`).
- **Environment**: Deno test runner (`deno test --allow-net --allow-env`).
- **Test Suite**:
  1. `test_base32_normalization`:
     - Input `"7k4x9m"` $\rightarrow$ Normalized `"7K4X9M"`.
     - Input `"oO1lIi"` $\rightarrow$ Normalized `"001111"`.
     - Input `"INVALID!"` $\rightarrow$ Throws typed `ValidationError`.
  2. `test_rate_limiter_persistent_query`:
     - Mock DB challenge query returning 3 challenges within past hour; assert request rejected with HTTP 429.
  3. `test_asymmetric_feature_flag`:
     - Set `FEATURE_RECREDENTIALING_ENABLED = false`.
     - `POST /family-admin (request_recredential_challenge)` $\rightarrow$ Returns HTTP 503.
     - `POST /device-register (redeem_recredential_challenge)` $\rightarrow$ Returns HTTP 503.
     - `POST /device-register (verify_device_rotation)` $\rightarrow$ Returns HTTP 200 (remains fully active).
     - `POST /device-telemetry` $\rightarrow$ Returns HTTP 200 (remains fully active).

### 5.3 Gate 6: End-to-End Staging Integration & Fault-Injection Tests
- **Target**: Integrated system (Mock Android Client + Deno Edge + Staging PostgreSQL).
- **Integration Test Scenarios**:
  1. **Happy Path Flow**: Parent requests challenge $\rightarrow$ receives 6-char code $\rightarrow$ Child submits code with staged candidate secret $\rightarrow$ Server rotates hash $\rightarrow$ Child promotes staged key $\rightarrow$ Child sends telemetry with new secret $\rightarrow$ Server verifies and accepts telemetry.
  2. **Lost-Response Recovery (CP-08/09 Simulation)**:
     - Child submits valid code.
     - Server commits key rotation to DB.
     - Test proxy drops HTTP 200 response (simulating radio loss).
     - Child client times out; detects staged candidate keys; transitions to `RECOVERY_REQUIRED`.
     - Child invokes `verify_device_rotation` with `(candidate_installation_id, candidate_secret_hash)`.
     - Server confirms rotation (`confirmed: true`).
     - Child promotes key; resumes telemetry. Zero parent re-authentication required.
  3. **Brute-Force Attack Simulation (ATT-01)**:
     - Automated attacker submits 1,000 rapid incorrect tokens.
     - Assert first 4 return HTTP 400 (`attempts_remaining: 4..1`).
     - 5th returns HTTP 400 (`attempts_remaining: 0, status: exhausted`).
     - Subsequent attempts return HTTP 410 / 400 (`challenge_exhausted`).
  4. **Concurrent Redemption Race (ATT-02)**:
     - Two concurrent worker threads submit the valid token simultaneously.
     - Exactly 1 thread receives HTTP 200 (`status: redeemed`).
     - The second thread receives HTTP 409 / 400 (`challenge_already_redeemed`).

---

## 6. Verification Gate Exit Criteria

| Gate | Scope | Required Pass Rate | Mandatory Artifacts Required for Sign-Off |
|---|---|---|---|
| **Gate 2** | Client UI & Native Unit Tests | 100% (0 failures) | Unit test report, coverage report (>85% on changed lines), widget test logs. |
| **Gate 3** | Wave 3 SQL Script Review | 100% Design Approval | Static analysis report of SQL script, syntax check, lock order proof. |
| **Gate 4** | Disposable Staging DB Migration | 100% (0 failures) | `pgTAP` execution log, table definition diff, index verification log. |
| **Gate 5** | Staging Edge Functions | 100% (0 failures) | `deno test` output log, rate limiting verification log, curl response traces. |
| **Gate 6** | Disposable Staging E2E Suite | 100% (0 failures) | E2E integration test execution report, chaos fault injection trace, timing log. |
| **Gate 7** | Production Deployment | 100% Verification | Post-deploy smoke test log, feature flag status verification, telemetry metrics. |
| **Gate 8** | Live Hardware QA Execution | 100% Test Case Pass | Device execution log (`emulator-5554` & `5HXWRGQ4IFU8WS4T`), screenshots. |

---

## 7. Conclusion

By enforcing this multi-stage staging verification plan, all theoretical design verifications (including all 24 red-team attack scenarios) will be empirically transformed into verified runtime evidence before any production changes or live device operations take place.
