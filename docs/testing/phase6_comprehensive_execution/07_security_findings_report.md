# 07 — Security Findings & Risk Assessment Report

**Audit Execution Date:** 2026-11-23  
**Audit Phase:** Phase 6 Comprehensive End-to-End Execution  
**Auditor:** HAVEN QA Security & Gaps Audit Team (Subagent 4)  
**Target Application:** HAVEN Parent Control (`com.parentcontrol.parent_control`)  
**Baseline Git Commit:** `5ffc5c170add4bfafd236beb633f00b6fe86243b` (HEAD on `main`)  
**Scope:** In-Depth Security Audit of SEC-001, Password Masking, Role Separation Boundaries, Log/Storage Exposure, and Cryptographic Posture

---

## 1. Executive Security Summary

A comprehensive multi-plane security audit of HAVEN Parent Control was conducted covering static code security, dynamic accessibility metadata, inter-process communication, database row-level security (RLS), and native Android data protection.

### Overall Security Posture:
- **Backend Architecture & RLS (Strong):** The Supabase PostgreSQL database and Edge Functions enforce rigorous multi-tenant data isolation. Row-Level Security policies prevent unauthorized access across families, and all Edge Functions strictly assert verified roles (`parent` vs `child`) and family ownership (`assertFamilyOwner`).
- **Device Credential Architecture (Strong):** Device-to-cloud telemetry uses dual headers (`x-device-id` and `x-device-secret`) evaluated via constant-time SHA-256 hash comparisons, protecting against timing attacks. Local secrets in Kotlin are secured with Android `EncryptedSharedPreferences` backed by `MasterKey` AES256-GCM.
- **Logging Discipline (Strong):** Zero credentials, auth tokens, device secrets, or WebRTC SDP payloads are logged to Android Logcat or console outputs across both Dart and Kotlin codebases.
- **Client Authentication Input Vulnerability (HIGH SEVERITY DEFECT — SEC-001):** During Phase 6 live testing (Run 8), entered passwords on the Sign-in and Registration screens were exposed in cleartext in the accessibility node hierarchy (`password=false`), allowing any application with Android Accessibility permissions or UI automation tools to extract credentials in plaintext.

---

## 2. In-Depth Security Audit: SEC-001 (Password Plaintext Exposure)

---

### 1. Vulnerability Metadata & Summary
- **Security Finding ID:** `SEC-001` (Tracked in Defect Register as `HAVEN-QA-002`)
- **Test Case ID:** `P6-SEC-001`
- **Affected Components:**
  - `lib/features/auth/login_page.dart` (Parent / Child Sign-In)
  - `lib/features/auth/register_page.dart` (Account Registration & Confirmation)
  - `lib/core/widgets/app_text_field.dart` (Shared Form Text Field Component)
- **Severity:** **HIGH** (CVSS v3.1 Score: 7.1 — `AV:L/AC:L/PR:N/UI:R/S:U/C:H/I:N/A:N`)
- **Status:** **OPEN — NOT FIXED**
- **Observed Context:** Pixel 9a emulator (`emulator-5554`) during Run 8 AI-executed authentication.

---

### 2. Detailed Vulnerability Analysis & Run 8 Reproduction

During the Phase 6 Run 8 audit (`docs/testing/phase_6_comprehensive_manual_testing/reports/21_run8_ai_parent_login_result.md`), credentials were submitted on the Sign-in form. An automated accessibility and UI hierarchy snapshot revealed that:
1. The password input field displayed the entered characters in plaintext.
2. The underlying Android accessibility node (`AccessibilityNodeInfo`) reported:
   ```xml
   <node index="1" class="android.widget.EditText" package="com.parentcontrol.parent_control"
         password="false" text="[REDACTED_ENTERED_PASSWORD]" />
   ```
3. Because `password="false"` was emitted by the Flutter accessibility bridge, the XML attribute `text="..."` contained the **raw unmasked password string**.
4. In accordance with safety rules, the transient pre-submit screenshot and UI dump containing the live credential were immediately destroyed to prevent credential retention.

---

### 3. Code Root Cause Analysis in Flutter & Android Embedding

The vulnerability stems from three interrelated omissions in `AppTextField` and the authentication screens:

#### Root Cause A: Missing Input Configuration in `AppTextField`
In `lib/core/widgets/app_text_field.dart` (lines 41–59):
```dart
@override
Widget build(BuildContext context) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    validator: validator,
    enabled: enabled,
    maxLines: maxLines,
    textInputAction: textInputAction,
    autofillHints: autofillHints,
    onFieldSubmitted: onFieldSubmitted,
    textCapitalization: textCapitalization,
    decoration: InputDecoration(...),
  );
}
```
1. **`enableSuggestions` is NOT set:** Defaults to `true` on Android. The software keyboard (IME) can inspect the input, suggest completions, and save password fragments into the user's personal keyboard learning dictionary.
2. **`autocorrect` is NOT set:** Defaults to `true`. Android predictive text engines can cache and display words typed in this field.
3. **`obscuringCharacter` is not hardened:** Relies on the framework default without explicit semantic obscuring flags.

#### Root Cause B: Keyboard Type Misconfiguration
In `lib/features/auth/login_page.dart` (lines 126–148) and `register_page.dart` (lines 122–175):
```dart
AppTextField(
  controller: _password,
  label: 'Password',
  obscureText: _obscurePassword,
  textInputAction: TextInputAction.done,
  autofillHints: const [AutofillHints.password],
  validator: Validators.password,
  prefixIcon: Icons.lock_outline,
  suffix: IconButton(...),
)
```
- Notice that `keyboardType` is **omitted entirely**.
- In `AppTextField`, `keyboardType` defaults to `null`, which defaults to standard `TextInputType.text`.
- For secure credential entry, Flutter requires `keyboardType: TextInputType.visiblePassword` when revealed or explicit password semantics so that Android's Input Method Editor (IME) activates secure input mode (`InputType.TYPE_TEXT_VARIATION_PASSWORD`).

#### Root Cause C: Flutter Android Accessibility Bridge Translation
In Flutter's Android embedding (`AccessibilityBridge.java`), the native `AccessibilityNodeInfo` receives `info.setPassword(node.hasFlag(Flag.IS_OBSCURED))`. 
When `obscureText` is initialized or toggled without disabling suggestions and autocorrect, or when input events are injected before semantics synchronization completes, the Android accessibility node fails to set `isPassword=true`. Consequently, `AccessibilityNodeInfo.getText()` exposes the cleartext value to Android accessibility readers.

---

### 4. Threat Modeling & Attack Vectors

```
+-------------------------------------------------------------------------------+
|                             THREAT VECTORS: SEC-001                           |
+-------------------------------------------------------------------------------+
| 1. Malicious Accessibility Service:                                           |
|    Any third-party app granted Android Accessibility permissions (e.g.        |
|    utility tools, cleaner apps) can listen to TYPE_VIEW_TEXT_CHANGED events    |
|    and harvest user passwords in cleartext because password=false.            |
|                                                                               |
| 2. Android Debug Bridge (ADB) / UI Automator Scraping:                        |
|    Any workstation or tool running `uiautomator dump` extracts the cleartext   |
|    password directly from the XML dump without requiring root privileges.     |
|                                                                               |
| 3. Keyboard IME Dictionary Poisoning:                                         |
|    Without enableSuggestions=false, third-party Android keyboards (Gboard,     |
|    SwiftKey) may cache sensitive passwords in plain text suggestions.         |
|                                                                               |
| 4. Shoulder Surfing & Screen Recording:                                       |
|    Toggling password visibility without auto-timeout exposes credentials to    |
|    surrounding cameras or background screen-recording utilities.              |
+-------------------------------------------------------------------------------+
```

---

### 5. Recommended Code Remediation (Concrete Fix)

#### Fix 1: Update `lib/core/widgets/app_text_field.dart`
Add `enableSuggestions`, `autocorrect`, and explicit `obscuringCharacter`:
```dart
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.validator,
    this.prefixIcon,
    this.suffix,
    this.textInputAction,
    this.maxLines = 1,
    this.enabled = true,
    this.helperText,
    this.autofillHints,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  final bool enableSuggestions;
  final bool autocorrect;
  ...

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enableSuggestions: obscureText ? false : enableSuggestions,
      autocorrect: obscureText ? false : autocorrect,
      ...
    );
  }
}
```

#### Fix 2: Harden Password Fields in `LoginPage` and `RegisterPage`
In both `LoginPage` and `RegisterPage`, configure the password fields explicitly:
```dart
AppTextField(
  controller: _password,
  label: 'Password',
  obscureText: _obscurePassword,
  enableSuggestions: false,
  autocorrect: false,
  keyboardType: _obscurePassword 
      ? TextInputType.text 
      : TextInputType.visiblePassword,
  textInputAction: TextInputAction.done,
  autofillHints: const [AutofillHints.password],
  validator: Validators.password,
  prefixIcon: Icons.lock_outline,
  suffix: IconButton(...),
)
```

---

## 3. Role Separation & Permission Boundaries

---

### 1. Gateway Role Selection vs Server-Side Enforcement

A critical security principle in HAVEN is that **client-side state is never trusted**:

- **Role Selection Screen (`RoleSelectionPage`):**
  When a user chooses "Parent Mode" or "Child Mode", the app only records a preference hint in local `SharedPreferences` (`cached_role`).
  - Code Proof: `lib/data/services/session_service.dart` (lines 6–9):
    ```dart
    /// Holds the signed-in user's *display* state only.
    ///
    /// The selected role and active family never grant access on their own: RLS,
    /// Edge Function caller checks and device credentials are authoritative.
    class SessionService extends GetxService { ... }
    ```
- **Server-Side Enforcement (`requireRole`):**
  Every sensitive action invokes Supabase Edge Functions where the caller's JWT is decoded and checked against `profiles.role` in PostgreSQL:
  ```typescript
  // supabase/functions/_shared/auth.ts (lines 145–155)
  export function requireRole(profile: ProfileRow, role: "parent" | "child"): void {
    if (profile.role !== role) {
      throw new ApiError("role_required", "A parent account is required for this action.", 403);
    }
  }
  ```
  Even if a malicious user alters local Flutter state or sends crafted HTTP requests, the backend rejects unauthorized actions with HTTP 403.

---

### 2. Row-Level Security (RLS) Policy Audit

The database migration `supabase/migrations/20260101000200_rls.sql` enforces rigorous tenant isolation across all tables:

| Database Table | Enforced RLS Policy | Authorization Rule | Audit Result |
|---|---|---|---|
| `profiles` | `profiles_select_self_or_family` | Users can only read their own profile or profiles of members within their active family. | **PASS** — Tenant Isolated |
| `families` | `families_select_members` / `families_update_owner` | Select allowed only for active family members; updates restricted strictly to `owner_id = auth.uid()`. | **PASS** — Owner Protected |
| `family_members`| `family_members_select_family` | Only members of the same family can view the membership roster. | **PASS** — Tenant Isolated |
| `devices` | `devices_select_parent_or_child` | Parents in the family can select all devices; children can only view devices linked to their `child_user_id`. | **PASS** — Role Bounded |
| `location_events`| `location_events_select_parent_or_child` | Parents can query all child locations; children can only select their own recorded locations. | **PASS** — Privacy Guarded |
| `usage_daily` | `usage_daily_select_parent_or_child` | Parents can query usage across all family devices; children view only their own device. | **PASS** — Privacy Guarded |
| `safety_alerts` | `safety_alerts_select_parent_or_child` | Restricted strictly to members of the alert's `family_id`. | **PASS** — Tenant Isolated |
| `audit_logs` | `audit_logs_select_family_parent` | `family_id is not null and private.is_family_parent(family_id)` — Children cannot view audit logs. | **PASS** — Parent-Only |
| `webrtc_signals`| `webrtc_signals_select_participant` | Caller must be either `parent_user_id` or `child_user_id` in an active, unexpired session. | **PASS** — Session Scoped |

---

### 3. Device Credential Authentication Security

Child device telemetry (`device-telemetry`) does not rely on easily forged client sessions. Instead, it enforces a cryptographic hardware-bound credential model:
1. **Dual Header Requirement:** Telemetry requests must supply `x-device-id` (UUID) and `x-device-secret` (32-byte Base64 secret).
2. **Timing Attack Protection:**
   In `supabase/functions/_shared/auth.ts` (lines 328–344):
   ```typescript
   const digest = await sha256Hex(secret);
   if (!constantTimeEqualHex(digest, device.secret_hash)) {
     throw new ApiError("invalid_device_credentials", "Device credentials are not valid.", 401);
   }
   ```
   Comparison uses constant-time string equality, preventing side-channel timing analysis.
3. **Revocation Enforcement:** If a parent revokes a device in the dashboard, `credential_revoked_at` is populated. The backend rejects subsequent requests immediately with HTTP 403 `device_revoked`.

---

## 4. Sensitive Data Exposure in Logs, Storage & UI

---

### 1. Logcat & Console Output Audit
A comprehensive audit of Android Logcat emissions and source code logging statements was conducted:
- **Dart Codebase:**
  - Search for `print(` or `debugPrint(` in `lib/`: **0 occurrences found**.
- **Native Kotlin Codebase:**
  - Search for `Log.d`, `Log.i`, `Log.w`, `Log.e`, `println` in `android/app/src/main/kotlin/`: **0 occurrences found**.
  - Strict developer comments confirm zero-credential logging:
    - `AudioAssistanceService.kt:740`: *"Credentials are never logged."*
    - `DeviceHttpClient.kt:15`: *"Only HTTPS is accepted. Credentials are sent in headers and never logged."*
    - `NativeBridge.kt:27`: *"Nothing here logs credentials, codes, SDP or tokens."*
    - `SecureStore.kt:22`: *"Values written here must never be logged: the device secret, sync config, etc."*
- **Supabase SDK Logcat Audit:**
  - In `emulator-5554` and `5HXWRGQ4IFU8WS4T` logcats, Supabase logs are strictly sanitized:
    `supabase.auth: INFO: Signing out user with scope: local`
  - No access tokens, refresh tokens, user passwords, or API secrets appear in Logcat.

---

### 2. Local Storage Security
- **Device Secrets (`SecureStore.kt`):**
  Stored in `EncryptedSharedPreferences` with Android Keystore-backed AES256-GCM master key (`MasterKey.KeyScheme.AES256_GCM`). Keys cannot be extracted without root access or device compromise.
- **Flutter Secure Storage (`flutter_secure_storage`):**
  Used for authentication session tokens; backed by Android Keystore and encrypted preferences.
- **Non-Sensitive Preferences (`LocalSettingsService.dart`):**
  Standard `SharedPreferences` only holds UI hints: `cached_role`, `active_family_id`, `notifications_enabled`, and `location_sharing_enabled`. No passwords or secrets are stored in cleartext XML.

---

### 3. Network Cryptographic Controls & Cleartext Traffic
- **Network Security Config:**
  In `android/app/src/main/res/xml/network_security_config.xml`:
  ```xml
  <network-security-config>
      <base-config cleartextTrafficPermitted="false" />
  </network-security-config>
  ```
  Cleartext HTTP traffic is blocked at the Android OS network stack.
- **Client Configuration Validation:**
  In `lib/core/config/env.dart` (lines 31–57):
  The app validates that `SUPABASE_URL` uses `https://` (permitting `http://` only for local emulator testing on `10.0.2.2`). It also verifies that `SUPABASE_ANON_KEY` does not contain a privileged `service_role` key.
- **Vulnerability Noted (SEC-002):** Certificate pinning is currently **omitted** (`network_security_config.xml:5-7`: `TODO: certificate pinning. No stable pins exist...`). This leaves network traffic vulnerable to TLS interception in environments with untrusted user certificates installed.

---

## 5. Security Risk Matrix & Release Sign-Off Criteria

| Finding ID | Vulnerability Description | Severity | Impact | Release Blocker? | Remediation Requirement |
|---|---|---|---|---|---|
| **SEC-001** | Password input exposes plaintext and `password=false` in accessibility nodes | **HIGH** | Plaintext credential harvesting via accessibility apps or UI dump | **YES — RELEASE BLOCKER** | Harden `AppTextField` with `enableSuggestions: false`, `autocorrect: false`, and explicit password input types. |
| **SEC-002** | Absence of TLS Certificate Pinning | **MEDIUM** | Man-in-the-middle risks if rogue CA certificate installed on device | NO (Recommended for v1.1) | Implement certificate pinning with backup pin sets in `network-security-config`. |
| **SEC-003** | Device credential break on app reinstall (`MON04`) | **HIGH** | Operational denial of service: child device permanently loses sync | **YES — RELEASE BLOCKER** | Introduce re-credentialing RPC to link reinstalled devices safely. |
| **SEC-004** | Notification permission false positive reporting (`MON05`) | **MEDIUM** | Misleads parents into believing notification pipeline is operational | NO (Recommended for v1.0.1) | Check `NotificationManagerCompat.areNotificationsEnabled()` across all API levels. |

---

## 6. Authoritative Security Conclusion

The HAVEN backend and native architecture demonstrate commendable security engineering, featuring rock-solid Row-Level Security, constant-time credential hashing, and zero-leak logging discipline.

However, **SEC-001 (Password plaintext exposure in accessibility nodes)** represents an unacceptable credential leakage risk that directly violates secure mobile application guidelines (OWASP MASVS-STORAGE and MASVS-AUTH).

**Security Verdict:**  
**BLOCKED FROM PRODUCTION RELEASE** until `SEC-001` is remediated in `AppTextField`, `LoginPage`, and `RegisterPage`, and verified through an isolated test pass.
