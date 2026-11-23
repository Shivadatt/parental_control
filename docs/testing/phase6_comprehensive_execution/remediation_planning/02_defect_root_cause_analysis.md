# 02 — Defect Root Cause Analysis

**Document ID:** HAVEN-REM-002  
**Phase:** Phase 1 — Remediation Planning (Strictly Planning-Only)  
**Date:** 2026-11-23  
**Status:** DRAFT FOR OWNER REVIEW & APPROVAL  
**Workspace:** `D:\parentcontrol_app`  
**Git Baseline HEAD:** `5ffc5c170add4bfafd236beb633f00b6fe86243b`  

---

## 1. Scope & Objective

This report documents an independent, source-level root cause investigation for all **six confirmed application defects** (`HAVEN-QA-001` through `HAVEN-QA-006`). Every defect analysis identifies:
1. Exact file paths, class/function names, and source line numbers.
2. The specific algorithmic or architectural failure mechanism.
3. Why the defect manifests in runtime execution.
4. Primary evidence artifacts confirming the defect.
5. Technical prerequisites for resolution.

---

## 2. In-Depth Root Cause Analysis by Defect

---

### 2.1 HAVEN-QA-001: Action Button Label Truncation ("Create acc...") on Role Selection Screen
- **Severity**: Low
- **Category**: UI / Responsive Layout Defect
- **Affected Role**: Shared (Onboarding)
- **Primary Source File**: `lib/features/role_selection/role_selection_page.dart`
- **Exact Line References**:
  - `role_selection_page.dart:151-172` (Parent Mode card buttons)
  - `role_selection_page.dart:181-202` (Child Mode card buttons)
- **Runtime Environment**: High-density mobile displays (e.g. Realme RMX2161, 1080×2400 px, 480 dpi, scale factor 3.0).

#### Code Snippet (Current Implementation)
```dart
// lib/features/role_selection/role_selection_page.dart:151-172
actions: Row(
  children: [
    Expanded(
      child: AppButton(
        label: 'Sign in',
        outlined: true,
        onPressed: _opening
            ? null
            : () => _open(ProfileRole.parent, register: false),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: AppButton(
        label: 'Create account',
        onPressed: _opening
            ? null
            : () => _open(ProfileRole.parent, register: true),
      ),
    ),
  ],
)
```

#### Technical Mechanism of Failure
1. **Geometric Constraint Math**:
   - Screen physical width = $1080\text{ px}$. At $480\text{ dpi}$ ($3.0\times$ density), screen logical width = $360\text{ dp}$.
   - Outer horizontal padding on `RoleSelectionPage` = $20\text{ dp} \times 2 = 40\text{ dp}$.
   - Card internal padding = $16\text{ dp} \times 2 = 32\text{ dp}$.
   - Available width for `actions: Row` = $360 - 40 - 32 = 288\text{ dp}$.
   - Spacer between buttons = $10\text{ dp}$.
   - Available width per `Expanded` button = $(288 - 10) / 2 = 139\text{ dp}$ (measured on device dump as $138\text{ dp}$ / $414\text{ px}$).
2. **Text Measurement & Truncation**:
   - `AppButton` uses standard text styling (`fontSize: 16`, font weight medium) with internal horizontal padding.
   - The label `"Create account"` rendered in Flutter's default font requires approximately $124\text{ dp}$ of text width plus button padding ($2 \times 16\text{ dp} = 32\text{ dp}$), totaling $156\text{ dp}$.
   - Because $156\text{ dp} > 138\text{ dp}$, Flutter's text rendering engine enforces truncation with an ellipsis (`TextOverflow.ellipsis`), rendering `"Create acc..."`.
3. **Primary Evidence**:
   - UIAutomator dump: `docs/testing/phase6_comprehensive_execution/evidence/child_dump.xml` (bounds `[555,1475][969,1625]`, width 414 px).
   - Screenshot: `docs/testing/phase6_comprehensive_execution/evidence/child_role_selection_clipped.png`.

---

### 2.2 HAVEN-QA-002: Password Input Exposes Plaintext / Lacks Secure Input Hardening (`SEC-001`)
- **Severity**: High
- **Category**: Security Vulnerability (Credential Exposure)
- **Affected Role**: Shared (Authentication)
- **Primary Source Files**:
  - `lib/core/widgets/app_text_field.dart:41-60`
  - `lib/features/auth/login_page.dart:126-148`
  - `lib/features/auth/register_page.dart:118-175`
- **Runtime Environment**: Cross-Device (Android & Emulator).

#### Code Snippet (Current Implementation)
```dart
// lib/core/widgets/app_text_field.dart:41-60
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
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      suffixIcon: suffix,
    ),
  );
}
```

#### Technical Mechanism of Failure
1. **Omission of Suggestion and Autocorrect Disablement**:
   - In Flutter's `TextFormField` / `EditableText`, `enableSuggestions` and `autocorrect` default to `true` unless explicitly overridden.
   - When a user enters text into a field where `obscureText: true` but `enableSuggestions` is not set to `false`, certain software keyboards (OEM keyboards, custom IMEs, Gboard under specific configurations) continue to buffer, predict, and cache typed characters into user dictionary stores.
2. **Missing Password Keyboard Classification**:
   - In `LoginPage` (`lib/features/auth/login_page.dart:126-148`), `AppTextField` is instantiated without passing `keyboardType: TextInputType.visiblePassword` or `TextInputType.text`.
   - On Android, the underlying IME is not signaled with `TYPE_TEXT_VARIATION_PASSWORD` via input connection flags, allowing accessibility services or third-party keyboards to inspect clipboard or prediction streams.
3. **Accessibility Node Semantics Leakage**:
   - When `Semantics` are not explicitly configured with `password: true`, screen readers or UIAutomator dump tools scrape the raw text property in the accessibility node before form submission.
   - Run 8 historical execution (`21_run8_ai_parent_login_result.md`) observed plaintext credentials captured by UIAutomator scraping.
4. **Primary Evidence**:
   - `docs/testing/phase6_master_matrix/07_security_and_approval_required_register.md` (`SEC-001`).
   - Code inspection of `lib/core/widgets/app_text_field.dart:41-60`.

---

### 2.3 HAVEN-QA-003: Device Re-credentialing Failure Breaks Telemetry (`DEF-601` / `MON04`)
- **Severity**: High
- **Category**: Architectural Limitation / Identity State Machine Defect
- **Affected Role**: Child / Interconnected
- **Primary Source Files**:
  - `android/app/src/main/kotlin/com/parentcontrol/parent_control/SecureStore.kt:86-102`
  - `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt:229-235`
  - `supabase/functions/device-register/index.ts:197-207`
  - `supabase/functions/_shared/auth.ts:297-353`
  - `supabase/functions/device-telemetry/index.ts:68-83`
- **Runtime Environment**: Realme RMX2161 / Any reinstalled or updated Child client.

#### Code Snippet (Current Implementation)
```kotlin
// SecureStore.kt:86-102
fun installationId(): String {
    val existing = prefs.getString(KEY_INSTALLATION_ID, null)
    if (!existing.isNullOrBlank()) return existing
    val created = UUID.randomUUID().toString()
    prefs.edit().putString(KEY_INSTALLATION_ID, created).apply()
    return created
}

fun deviceSecret(): String {
    val existing = prefs.getString(KEY_DEVICE_SECRET, null)
    if (!existing.isNullOrBlank()) return existing
    val bytes = ByteArray(32)
    SecureRandom().nextBytes(bytes)
    val created = Base64.encodeToString(bytes, Base64.NO_WRAP)
    prefs.edit().putString(KEY_DEVICE_SECRET, created).apply()
    return created
}
```

```typescript
// supabase/functions/_shared/auth.ts:340-345
const digest = await sha256Hex(clientSecret);
if (!constantTimeEqualHex(digest, device.secret_hash)) {
  throw new ApiError(
    "invalid_device_credentials",
    "Device credentials are not valid.",
    401,
  );
}
```

#### Technical Mechanism of Failure
1. **Client Keystore Ephemerality**:
   - On Android, `SecureStore` stores the device's installation ID and raw 32-byte cryptographic secret in `EncryptedSharedPreferences`.
   - When the Child application is reinstalled, cleared by the OS, or deployed with an updated debug signing key, the Android KeyStore master key is wiped or regenerated. `SecureStore` lazily generates a **brand-new installation ID** and **brand-new device secret**.
2. **Server-Side Credential Deadlock**:
   - On the server, the `devices` table retains the existing row with `status = 'active'`, tied to the original `secret_hash`.
   - When the reinstalled Child app signs in as the existing Child user, `fetchMyDevice()` loads the existing active `devices.id`.
   - The Child shell then attempts to configure `GuardianService` with the **old** server device UUID and the **new** local secret.
   - When `GuardianService` sends telemetry (heartbeat, usage, location) to `/device-telemetry`, `requireDevice()` hashes the new secret and compares it to `devices.secret_hash`.
   - The hashes do not match. The server returns HTTP 401 `invalid_device_credentials`.
3. **Missing Re-credentialing Primitive**:
   - `device-register` only allows secret rotation if `installation_id` matches (`device-register/index.ts:141-194`). Because the reinstall generated a new `installation_id`, this branch is rejected with `409 device_already_registered`.
   - The only existing server recovery RPC (`request_device_recovery`) destroys the family relationship and revokes the device entirely, requiring a fresh pairing request.
   - Result: Telemetry is permanently broken, and the device stays permanently "Offline" on the Parent dashboard.
4. **Primary Evidence**:
   - `docs/testing/functionality_inventory/05_missing_and_incomplete_functionalities.md` (`MON04`).
   - Run 8 logcat: *"Usage upload failed: Device credentials are not valid."*

---

### 2.4 HAVEN-QA-004: Notification Permission Reports False-Positive "Granted" on Android 12 (`DEF-604` / `MON05`)
- **Severity**: Medium
- **Category**: Native Platform Integration Bug
- **Affected Role**: Child / Interconnected
- **Primary Source File**: `android/app/src/main/kotlin/com/parentcontrol/parent_control/NativePermissions.kt`
- **Exact Line References**: `NativePermissions.kt:29-32`
- **Runtime Environment**: Realme RMX2161 (Realme 7, Android 12, API 31).

#### Code Snippet (Current Implementation)
```kotlin
// android/app/src/main/kotlin/com/parentcontrol/parent_control/NativePermissions.kt:29-32
fun hasNotifications(context: Context): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
    return granted(context, Manifest.permission.POST_NOTIFICATIONS)
}
```

#### Technical Mechanism of Failure
1. **Flawed Android Version Assumption**:
   - Android 13 (`Build.VERSION_CODES.TIRAMISU`, API 33) introduced the runtime permission `android.permission.POST_NOTIFICATIONS`.
   - For Android 12 (`API 31`) and earlier, the developer assumed that because `POST_NOTIFICATIONS` does not exist as a runtime prompt, notifications are "always granted" and hardcoded `return true`.
2. **Ignored App-Level Notification Disablement**:
   - In all Android versions (API 19 through API 35), users can disable notifications for any application via System Settings (`Settings → Apps → Parent Control → Notifications → Off`).
   - By unconditionally returning `true` on `Build.VERSION.SDK_INT < TIRAMISU`, `NativePermissions.hasNotifications()` reports `true` even if the user or OEM battery saver has blocked notifications at the OS level.
3. **Telemetry Distortion**:
   - The Child device sends `capabilities.notifications_granted = true` in the heartbeat payload (`GuardianService.kt:285`).
   - The Parent dashboard and device detail screens project "Notifications: Granted", misleading parents into believing alert delivery is functional when notifications are suppressed by the OS.
4. **Primary Evidence**:
   - Dumpsys dump: `dumpsys_permissions_child.txt` (shows `POST_NOTIFICATIONS` is ungranted).
   - Source code inspection: `NativePermissions.kt:29-32`.

---

### 2.5 HAVEN-QA-005: Revoked Devices Duplicated in Parent Dashboard & Device List (`DEF-602`)
- **Severity**: High
- **Category**: Repository Query / Projection Bug
- **Affected Role**: Parent
- **Primary Source File**: `lib/data/repositories/supabase_device_repository.dart`
- **Exact Line References**: `supabase_device_repository.dart:31-40`
- **Runtime Environment**: Pixel 9 Emulator / Cross-Device.

#### Code Snippet (Current Implementation)
```dart
// lib/data/repositories/supabase_device_repository.dart:31-40
@override
Future<List<Device>> fetchDevices(String familyId) => _guard(() async {
      final rows = await _supabase.client
          .from('devices')
          .select(_deviceColumns)
          .eq('family_id', familyId)
          .order('created_at', ascending: true);
      return rows
          .map((row) => Device.fromJson(jsonMap(row)))
          .toList(growable: false);
    });
```

#### Technical Mechanism of Failure
1. **Unfiltered Database Query**:
   - The query filters solely on `family_id` and orders by `created_at`.
   - There is NO filter on device `status` (such as `.neq('status', 'revoked')` or `.eq('status', 'active')`).
2. **Lifecycle State Accumulation**:
   - When a parent revokes a child device or unlinks a device, the backend database sets `devices.status = 'revoked'` and records `credential_revoked_at`. The row is retained for audit logging and historic usage retention.
   - When the child device is subsequently re-enrolled or paired again, a second row is inserted into `devices` with `status = 'active'`.
3. **UI Duplication**:
   - `fetchDevices()` returns BOTH rows (the revoked row and the active row).
   - `DashboardController` and `DevicesController` iterate through the entire list returned by `fetchDevices()` without filtering, causing two cards to render for the same physical device: one marked "Revoked" (or "Offline") and one marked "Active".
4. **Primary Evidence**:
   - `docs/testing/phase_6_comprehensive_manual_testing/reports/11_defect_register.md` (`DEF-602`).
   - Source inspection of `supabase_device_repository.dart:31-40`.

---

### 2.6 HAVEN-QA-006: Policy Version Inconsistency Across Parent Dashboard and Devices Tab (`DEF-603`)
- **Severity**: Medium
- **Category**: Presentation State Divergence Bug
- **Affected Role**: Parent
- **Primary Source Files**:
  - `lib/features/dashboard/dashboard_controller.dart:202-205`
  - `lib/features/devices/devices_controller.dart:159-163`
  - `lib/features/devices/device_presentation.dart:23-34`
- **Runtime Environment**: Pixel 9 Emulator / Parent Mode.

#### Code Snippets (Current Implementation)
```dart
// lib/features/dashboard/dashboard_controller.dart:202-205
String policySummaryFor(Device device) => policySummary(
      devicePolicyVersion: device.policyVersion,
      policy: policies[device.id],
    );

// lib/features/devices/device_presentation.dart:23-34
String policySummary({
  required int? devicePolicyVersion,
  required DevicePolicy? policy,
}) {
  final version = policy?.version ?? devicePolicyVersion;
  if (version == null || version <= 0) return 'No policy applied yet';
  if (policy == null) return 'Policy v$version · status not available';
  if (policy.status == PolicyEnforcementStatus.unsupported) {
    return 'Policy v$version · Advisory (Unmanaged)';
  }
  return 'Policy v$version · ${policy.status.label}';
}

// lib/features/devices/devices_controller.dart:159-163
String policySummaryFor(Device device) {
  final version = device.policyVersion;
  if (version == null || version <= 0) return 'No policy applied yet';
  return 'Policy v$version';
}
```

#### Technical Mechanism of Failure
1. **Asymmetric State Projection**:
   - `dashboard_controller.dart` calls `policySummary()` in `device_presentation.dart`, which projects `policy?.version` (the desired version recorded in the `device_policies` table on the server).
   - `devices_controller.dart` completely bypasses `device_presentation.dart` and directly inspects `device.policyVersion` (the version recorded on the `devices` table, which is only incremented when the Child device acknowledges policy enforcement via `/device-command`).
2. **Runtime Divergence on Policy Mutation**:
   - When a parent modifies a policy (e.g. adjusts screen time rules or blocked apps), a new row is created in `device_policies`, bumping the desired version from `v2` to `v4`.
   - Until the child device executes a background sync tick, downloads the policy, and acknowledges it, `device.policyVersion` remains `v2`.
   - In this window, the **Dashboard** displays `"Policy v4 · Waiting for device"`, while the **Devices tab** displays `"Policy v2"`.
   - The parent sees conflicting policy versions on two adjacent tabs of the same application.
3. **Primary Evidence**:
   - `docs/testing/phase_6_comprehensive_manual_testing/reports/11_defect_register.md` (`DEF-603`).
   - Source inspection of `dashboard_controller.dart:202-205` vs `devices_controller.dart:159-163`.

---

## 3. Summary of Root Cause Classifications

| Defect ID | Layer | Root Cause Type | Technical Remedy |
|---|---|---|---|
| `HAVEN-QA-001` | Flutter UI | Rigid layout constraint (138dp button width) | Flexible/FittedBox button layout in `RoleSelectionPage` |
| `HAVEN-QA-002` | Flutter Core | Omission of input hardening flags in `AppTextField` | Hardcode suggestions=false, autocorrect=false, password semantics |
| `HAVEN-QA-003` | Native + Backend | Missing re-credentialing protocol on KeyStore reset | Implement Parent-approved challenge & atomic rotation RPC |
| `HAVEN-QA-004` | Android Native | Hardcoded `Build.VERSION < TIRAMISU` bypass | Use `NotificationManagerCompat.areNotificationsEnabled()` |
| `HAVEN-QA-005` | Flutter Data | Unfiltered `fetchDevices()` query including revoked rows | Add `.neq('status', 'revoked')` filter to query |
| `HAVEN-QA-006` | Flutter State | Divergent projection: `policy.version` vs `device.policyVersion` | Harmonize `policySummary()` to render target and applied versions |
