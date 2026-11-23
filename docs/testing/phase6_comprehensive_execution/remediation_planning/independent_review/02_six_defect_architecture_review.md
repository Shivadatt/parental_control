# 02 — Six Defects Architecture Review & Adversarial Challenge

**Document ID:** HAVEN-REV-002  
**Phase:** Phase 1.1 — Remediation Plan Independent Review (Strictly Read-Only)  
**Date:** 2026-11-23  
**Status:** COMPLETE INDEPENDENT TECHNICAL REVIEW  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `56636f62d5144610ae12c89d02d582feb48217fc`  

---

## 1. Overview & Review Purpose

This report delivers an independent, code-level adversarial evaluation of the proposed fix architectures for all six defects in the HAVEN Parent Control remediation package. Each defect proposal is evaluated against:
1. Actual source code implementation in the Flutter, Android Kotlin, and Supabase layers.
2. Geometric, semantic, and concurrency edge cases.
3. Collateral regressions across shared components.
4. Compliance with existing architectural contracts and accessibility standards.

---

## 2. In-Depth Adversarial Evaluation by Defect

---

### 2.1 HAVEN-QA-001: Role Selection Button Label Truncation

- **Proposed Solution**: Wrap button label in `FittedBox(fit: BoxFit.scaleDown)` inside `AppButton`, and adjust intra-button gap from 10dp to 8dp on `RoleSelectionPage`.
- **Target Files**: `lib/core/widgets/app_button.dart`, `lib/features/role_selection/role_selection_page.dart`.

#### The Adversarial Challenge: Global Blast Radius & Accessibility Defeat
1. **App-Wide Blast Radius (85+ Call Sites)**:
   - A search for `AppButton(` reveals **over 85 usages across 24 screens** in the application (`audit_logs_page`, `login_page`, `register_page`, `child_enrollment_page`, `device_detail_page`, `remote_assistance_page`, etc.).
   - Modifying `_buildLabel` in `AppButton` to use `FittedBox(fit: BoxFit.scaleDown)` applies auto-scaling to *every button in the entire product*.
   - If any button across the app has a long title or is rendered inside a narrow container, `FittedBox` silently shrinks the font size rather than triggering a layout error or wrapping.
2. **Defeating User Accessibility Preferences**:
   - Android and iOS allow users with visual impairments to increase the system font scale (e.g. 1.3x, 1.5x, 2.0x).
   - `FittedBox(fit: BoxFit.scaleDown)` directly counteracts the user's OS font scaling preference: when the system scales up the font, `FittedBox` aggressively scales it down to fit the tight 138dp box, resulting in illegible micro-text (~8–10sp), violating **WCAG 1.4.4 (Resize Text)**.
3. **Visual Asymmetry on the Same Card**:
   - On the Parent Mode card, the "Sign in" button (7 characters) stays at 16sp, while "Create account" (14 characters) scales down to ~13sp right next to it. They look visually mismatched and unpolished.
4. **Root Cause Avoidance**:
   - The true defect is in `RoleSelectionPage:151-172`: forcing two primary action buttons into a single horizontal `Row` inside a padded card (`Card padding: 16dp * 2 = 32dp`, `Screen margin: 20dp * 2 = 40dp`), leaving only 138dp per button on a 360dp phone display.

#### Required Technical Correction
Do **NOT** modify `AppButton` globally. The fix must be localized to `RoleSelectionPage`:
- **Option 1 (Recommended)**: Use an adaptive layout in `_RoleOptionCard`: if `MediaQuery.of(context).size.width < 380`, render the buttons stacked vertically in a `Column` with full 48dp height and complete 16sp font. On wider screens / tablets, render side-by-side.
- **Option 2 (Localized Opt-In)**: If side-by-side layout is strictly required by the design owner, add an explicit opt-in parameter to `AppButton` (e.g., `shrinkWrapText: false` by default, `true` only when opted in), or adjust `AppButton` internal horizontal padding from default 24dp to 12dp specifically for `RoleSelectionPage`.

**Verdict**: **PASS WITH CONDITIONS** (Condition: Localize fix to `RoleSelectionPage`; leave global `AppButton` untouched).

---

### 2.2 HAVEN-QA-002: Password Input Security (`SEC-001`)

- **Proposed Solution**: Hardcode `enableSuggestions: false`, `autocorrect: false`, `TextInputType.visiblePassword`, and `Semantics(password: true)` in `AppTextField` when `obscureText: true`.
- **Target Files**: `lib/core/widgets/app_text_field.dart`, `lib/features/auth/login_page.dart`, `lib/features/auth/register_page.dart`.

#### The Adversarial Challenge: Eyeball Visibility Toggle Security Leak
1. **The Show/Hide Password Toggle Flaw (REV-003)**:
   - In `LoginPage` (`lib/features/auth/login_page.dart:129`) and `RegisterPage` (`lib/features/auth/register_page.dart:132`), `obscureText: _obscurePassword` is toggled when the user taps the eyeball visibility icon (`Icons.visibility_outlined`).
   - In the proposed `AppTextField` architecture:
     ```dart
     final effectiveEnableSuggestions = obscureText ? false : (enableSuggestions ?? true);
     final effectiveAutocorrect = obscureText ? false : (autocorrect ?? true);
     ```
   - When the user taps "Show password" to check what they typed, `_obscurePassword` becomes `false`.
   - Under the proposed logic, `effectiveEnableSuggestions` and `effectiveAutocorrect` immediately revert to `true`!
   - As the user continues typing or editing their visible password, the software keyboard immediately starts analyzing keystrokes, offering suggestions, and caching the password in the keyboard predictive dictionary!
   - Furthermore, `Semantics(password: obscureText)` switches `password: false`, exposing the plain string to accessibility scrapers while visible!
2. **Keyboard Type Quirks (`TextInputType.visiblePassword`)**:
   - `TextInputType.visiblePassword` is intended by Android IME specs for inputs that are visually plain text but should not be learned by dictionaries (e.g. Wi-Fi passwords).
   - When paired with `obscureText: true`, certain OEM keyboards (e.g. older Samsung OneUI IMEs) disable their secure hardware entry panel and fall back to plain alphanumeric keyboards without masking.
   - For a password field that is obscured, Flutter's standard `TextInputType.text` or `null` combined with explicit `enableSuggestions: false`, `autocorrect: false` is the canonically supported approach.

#### Required Technical Correction
1. Add an explicit `isPassword` boolean property to `AppTextField` (or inspect `autofillHints?.contains(AutofillHints.password) == true`):
   ```dart
   final isPasswordField = isPassword || (autofillHints?.any((h) => 
       h == AutofillHints.password || h == AutofillHints.newPassword) ?? false);

   final effectiveEnableSuggestions = isPasswordField ? false : (enableSuggestions ?? true);
   final effectiveAutocorrect = isPasswordField ? false : (autocorrect ?? true);
   ```
2. Wrap in `Semantics(password: isPasswordField, obscured: obscureText)`. Even when the user toggles text visibility (`obscureText: false`), the accessibility node still declares `password: true` and keyboard suggestions remain permanently suppressed.

**Verdict**: **PASS WITH CONDITIONS** (Condition: Decouple password hardening from `obscureText` toggle; use dedicated `isPassword` flag).

---

### 2.3 HAVEN-QA-003: Device Re-credentialing Failure (`DEF-601` / `MON04`)

- **Proposed Solution**: Option C: Parent authorization creates challenge token; Child redeems via atomic `rotate_device_secret` RPC; updates `devices.secret_hash` without changing `devices.id`.
- **Target Files**: `SecureStore.kt`, `GuardianService.kt`, `supabase/functions/device-register/index.ts`, `20261124000100_device_recredentialing.sql`.

#### The Adversarial Challenge: Critical RPC Rollback Bug & Persistence Deadlock
1. **The PL/pgSQL Attempt Counter Rollback Bug (CRITICAL FINDING REV-001)**:
   - In `03_credential_lifecycle_remediation_design.md:120-127`:
     ```sql
     if v_challenge.challenge_hash <> v_token_hash then
       update public.device_recovery_challenges
       set attempts = attempts + 1
       where id = v_challenge.id;
       raise exception 'Invalid re-credentialing challenge token.'
         using errcode = 'P0005';
     end if;
     ```
   - In PostgreSQL, calling `RAISE EXCEPTION` aborts the current transaction and rolls back **ALL** modifications made within that transaction!
   - Because the attempt counter increment is executed before `RAISE EXCEPTION`, the increment is completely rolled back!
   - The stored `attempts` count in `device_recovery_challenges` will **NEVER** reach `max_attempts`! An attacker can submit millions of brute-force guesses without ever triggering lockout!
2. **The Asymmetric Update / Lost Response Deadlock (CRITICAL FINDING REV-002)**:
   - What happens if the server successfully commits `rotate_device_secret` (updating `devices.secret_hash` to `hash_new` and marking challenge consumed), but the network drops before the Child client receives HTTP 200, OR the Child client crashes before `SecureStore.kt` commits `device_secret_new` to Android KeyStore?
   - The server has switched to `hash_new`.
   - The challenge is consumed.
   - The client still possesses `secret_old` (or an uncommitted `secret_new`).
   - When the client attempts to heartbeat, it sends `secret_old`, which is rejected (401).
   - Because the challenge is consumed, the client cannot retry. The device is now permanently bricked from telemetry without manual database intervention!
3. **Database Check Constraint Consistency**:
   - `supabase/migrations/20260101000000_core.sql:112` enforces:
     `constraint devices_revoked_credential_consistency check (status <> 'revoked' or secret_hash is null)`
   - The proposed RPC must ensure that if a device is ever in `status = 'revoked'`, `rotate_device_secret` strictly aborts and never sets a non-null `secret_hash` on a revoked device.
4. **Rollback Misconception (REV-005)**:
   - Report 08 suggests dropping the challenge table and RPC to rollback Step 6.
   - Dropping the table/RPC does **NOT** roll back already-rotated device credentials! Devices that already rotated their secret will be rejected by old code. Reversing credential rotation requires an explicit forward recovery runbook.

#### Required Technical Correction
1. In the PL/pgSQL RPC, do NOT use `RAISE EXCEPTION` for verification failures. Return a structured JSON response (`{"ok": false, "error": "invalid_token", "attempts_remaining": 5 - attempts}`), allowing PostgreSQL to **COMMIT** the attempt increment.
2. Implement a two-phase confirmation or recovery latch: the client writes `device_secret_new` into KeyStore as "pending confirmation" before sending redemption; upon receiving HTTP 200, it marks it "active". If response is lost, the client can query a verification endpoint using `secret_new`.
3. Revise the rollback runbook to specify forward recovery procedures.

**Verdict**: **FAIL AS SPECIFIED (BLOCKED FOR IMPLEMENTATION)** (Requires architectural redesign of attempt counting and failure recovery before owner approval).

---

### 2.4 HAVEN-QA-004: Notification Permission Detection False-Positive (`DEF-604`)

- **Proposed Solution**: Replace `if (Build.VERSION.SDK_INT < TIRAMISU) return true` with `NotificationManagerCompat.from(context).areNotificationsEnabled()`.
- **Target File**: `android/app/src/main/kotlin/com/parentcontrol/parent_control/NativePermissions.kt`.

#### The Adversarial Challenge: Notification Channel Blocking (Android 8.0+)
1. **Master Switch vs. Channel Blocking (REV-008)**:
   - `NotificationManagerCompat.areNotificationsEnabled()` checks the app-level master notification switch.
   - On Android 8.0+ (API 26+), notifications are divided into **Notification Channels**.
   - A user can leave the master notification switch enabled, but navigate to `Settings → Apps → Parent Control → Notifications → Guardian Service Channel` and disable only that channel.
   - When the Guardian Service channel is disabled, foreground service alerts and safety warnings are suppressed by Android, yet `areNotificationsEnabled()` continues to return `true`!
2. **Foreground Service Notification Invariant**:
   - For `GuardianService.kt`, notification delivery is critical because running as a foreground service requires posting an active notification to `guardian_service_channel`.

#### Required Technical Correction
Enhance `NativePermissions.hasNotifications()` to check both the master switch and the critical notification channel:
```kotlin
fun hasNotifications(context: Context): Boolean {
    val manager = NotificationManagerCompat.from(context)
    if (!manager.areNotificationsEnabled()) return false

    // On Android 8.0+ (API 26+), also check if the Guardian channel is blocked
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val channel = manager.getNotificationChannel("guardian_service_channel")
        if (channel != null && channel.importance == NotificationManager.IMPORTANCE_NONE) {
            return false
        }
    }

    // On Android 13+ (API 33+), check runtime POST_NOTIFICATIONS grant
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        return granted(context, Manifest.permission.POST_NOTIFICATIONS)
    }

    return true
}
```

**Verdict**: **PASS WITH CONDITIONS** (Condition: Include notification channel check for API 26+).

---

### 2.5 HAVEN-QA-005: Revoked Devices Duplicated in Parent Device List (`DEF-602`)

- **Proposed Solution**: Add `.neq('status', 'revoked')` filter to `fetchDevices()` by default, with optional `includeRevoked: true` flag.
- **Target File**: `lib/data/repositories/supabase_device_repository.dart:31-40`.

#### The Adversarial Challenge: Domain Status Invariants & Pending Devices
1. **The Three-State Domain Model (REV-006)**:
   - In `supabase/migrations/20260101000000_core.sql:91-92`:
     `status text not null default 'pending' check (status in ('pending', 'active', 'revoked'))`
   - The domain model contains three distinct states: `pending`, `active`, and `revoked`.
   - By filtering `.neq('status', 'revoked')`, the query returns both `active` AND `pending` devices.
   - If a child started an enrollment flow that was abandoned, a `pending` device row remains in the database.
   - Under `.neq('status', 'revoked')`, the Parent Dashboard would render the `pending` device card alongside the `active` device card!
2. **Alignment with `fetchMyDevice()`**:
   - In `supabase_device_repository.dart:66`, `fetchMyDevice()` already uses `.eq('status', 'active')`!
   - Having `fetchMyDevice()` filter on `active` while `fetchDevices()` filters on `!= revoked` creates an architectural inconsistency between Child and Parent projections.
3. **Boolean Parameter Anti-Pattern**:
   - Adding `bool includeRevoked = false` to repository contracts creates boolean-flag coupling.

#### Required Technical Correction
1. In `SupabaseDeviceRepository.fetchDevices()`, filter strictly on `.eq('status', 'active')` for active monitoring views.
2. If historical/revoked devices must be inspected, expose an explicit method: `Future<List<Device>> fetchDeviceHistory(String familyId)`.

**Verdict**: **PASS WITH CONDITIONS** (Condition: Filter strictly by `.eq('status', 'active')` for active dashboards).

---

### 2.6 HAVEN-QA-006: Policy Version Inconsistency Across Parent Screens (`DEF-603`)

- **Proposed Solution**: Harmonize presentation to display `"Policy v2 · Updating to v4..."`.
- **Target Files**: `dashboard_controller.dart`, `devices_controller.dart`, `device_presentation.dart`.

#### The Adversarial Challenge: Omission of Failed and Unsupported Enforcement States
1. **The Backend Enforcement State Machine (REV-007)**:
   - In `supabase/functions/device-command/handler.ts:385-432`, when a device acknowledges an `apply_policy` command, `device_policies.enforcement_status` can become:
     - `'active'`: Policy enforced successfully.
     - `'pending'`: Acknowledged but quota/counters pending.
     - `'unsupported'`: Device lacks Device Owner or required capability.
     - `'failed'`: Device reported an enforcement exception.
2. **Misleading "Updating to v4..." Label**:
   - If a child device is unmanaged (e.g. lacks Device Owner) or reported a policy error (`enforcement_status == 'failed'`), displaying `"Policy v2 · Updating to v4..."` misleads the parent into believing synchronization is in progress, when in reality policy application permanently failed!
3. **Stale Offline Acknowledgements**:
   - If the device is offline (`device.isOnline == false`), the label should explicitly communicate that policy sync is paused awaiting device reconnection.

#### Required Technical Correction
The presentation resolver in `device_presentation.dart` must evaluate both `device.syncHealth` and `policy.status`:
- If `policy.status == PolicyEnforcementStatus.failed`: Render `"Policy v$applied · Update failed (v$desired)"` (tone: danger).
- If `policy.status == PolicyEnforcementStatus.unsupported`: Render `"Policy v$applied · Advisory only"`.
- If device is offline: Render `"Policy v$applied · Update to v$desired pending reconnection"`.
- If sync is healthy and pending: Render `"Policy v$applied · Applying v$desired..."`.

**Verdict**: **PASS WITH CONDITIONS** (Condition: Map `failed`, `unsupported`, and `offline` states in presentation helper).

---

## 3. Summary of Architecture Review Classifications

| Defect ID | Original Planning Proposal | Independent Review Classification | Corrected Architecture Recommendation |
|---|---|---|---|
| `HAVEN-QA-001` | Global `FittedBox` in `AppButton` | **PASS WITH CONDITIONS** | Localize adaptive layout to `RoleSelectionPage`; do not touch global `AppButton`. |
| `HAVEN-QA-002` | ObscureText-driven hardening | **PASS WITH CONDITIONS** | Decouple password hardening from eyeball visibility toggle; introduce `isPassword: true`. |
| `HAVEN-QA-003` | Option C + PL/pgSQL RPC | **FAIL AS SPECIFIED** | Fix attempt increment transaction rollback bug; add lost response recovery latch. |
| `HAVEN-QA-004` | `areNotificationsEnabled()` | **PASS WITH CONDITIONS** | Add notification channel inspection for Android 8.0+ (API 26+). |
| `HAVEN-QA-005` | `.neq('status', 'revoked')` | **PASS WITH CONDITIONS** | Use `.eq('status', 'active')` for active views; separate history query. |
| `HAVEN-QA-006` | Dual version string | **PASS WITH CONDITIONS** | Incorporate `failed`, `unsupported`, and `offline` enforcement statuses. |
