# 06 — Notification Permission & UI Remediation Design

**Document ID:** HAVEN-REM-006  
**Target Defects:** HAVEN-QA-004 (`DEF-604` / `MON05`) & HAVEN-QA-001  
**Phase:** Phase 1 — Remediation Planning (Strictly Planning-Only)  
**Date:** 2026-11-23  
**Status:** DRAFT FOR OWNER REVIEW & APPROVAL  
**Workspace:** `D:\parentcontrol_app`  
**Git Baseline HEAD:** `5ffc5c170add4bfafd236beb633f00b6fe86243b`  

---

## 1. Context & Objectives

This report details the remediation architecture for two client-level defects:
1. **HAVEN-QA-004 (`DEF-604` / `MON05`)**: On Android versions below 13 (API 33), `NativePermissions.kt` hardcodes notification permission as "Granted", creating false-positive indicators on Parent monitoring screens even if notifications are blocked in OS settings.
2. **HAVEN-QA-001**: On 480 dpi mobile devices (such as Realme RMX2161), the primary action button on `RoleSelectionPage` clips the label "Create account" to "Create acc...".

---

## 2. Part 1: Notification Permission Detection Remediation (`HAVEN-QA-004`)

### 2.1 Current Implementation & Defect Mechanics
In `android/app/src/main/kotlin/com/parentcontrol/parent_control/NativePermissions.kt:29-32`:
```kotlin
fun hasNotifications(context: Context): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
    return granted(context, Manifest.permission.POST_NOTIFICATIONS)
}
```

#### Why This Fails
- On Android 12 (`API 31`) and earlier, the runtime permission `android.permission.POST_NOTIFICATIONS` did not exist.
- However, users have always been able to block an app's notifications in system settings (`Settings → Apps → Notification Toggle: OFF`).
- Furthermore, on Android 8.0+ (API 26+), specific notification channels can be blocked by the user.
- Hardcoding `return true` on Android < 33 causes the Child app to transmit `notifications_granted = true` in telemetry heartbeats regardless of actual delivery capability.

### 2.2 Proposed Native Android Implementation
The canonical Android solution across all API levels is `androidx.core.app.NotificationManagerCompat.areNotificationsEnabled()`.

```kotlin
// In android/app/src/main/kotlin/com/parentcontrol/parent_control/NativePermissions.kt
import androidx.core.app.NotificationManagerCompat

object NativePermissions {
    // ... other methods preserved ...

    fun hasNotifications(context: Context): Boolean {
        // Step 1: Check overall app-level notification enablement (all Android versions)
        val notificationsEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        if (!notificationsEnabled) return false

        // Step 2: On Android 13+ (API 33+), also verify runtime POST_NOTIFICATIONS grant
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return granted(context, Manifest.permission.POST_NOTIFICATIONS)
        }

        return true
    }
}
```

### 2.3 System Impact & Verification
- **Realme RMX2161 (Android 12)**: If notification toggle is OFF in Android Settings, `hasNotifications()` returns `false`.
- **Pixel 9 (Android 15 / Tiramisu+)**: Returns `true` only if both app notifications are enabled AND `POST_NOTIFICATIONS` is granted.
- **Parent Telemetry**: Accurately reflects notification health on the Parent Dashboard, removing false security assumptions.

---

## 3. Part 2: Role Selection Responsive Layout Remediation (`HAVEN-QA-001`)

### 3.1 Current Implementation & Geometry Breakdown
In `lib/features/role_selection/role_selection_page.dart:151-172, 181-202`:
```dart
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

#### Geometry on 480 DPI Device
- Logical width = $360\text{ dp}$.
- Available width per button = $138\text{ dp}$ ($414\text{ px}$).
- Label `"Create account"` with standard padding requires $156\text{ dp}$.
- Text engine truncates to `"Create acc..."`.

### 3.2 Evaluation of Layout Alternatives

| Alternative | Implementation | Usability | Accessibility / Touch Target | Recommendation |
|---|---|---|---|---|
| **Option 1: FittedBox Text Scaling** | Scale down text inside `AppButton` when width is constrained | Clean appearance; preserves single-line layout | Text scales to ~14sp; touch target (48dp height) preserved | **RECOMMENDED** |
| **Option 2: Responsive Wrap / Column** | Stack buttons vertically if logical width < 380dp | Full text size; requires taller card height | Expands vertical card height; shifts layout | Alternative |
| **Option 3: Label Text Shortening** | Change label to "Register" instead of "Create account" | Minimal code change | Inconsistent with branding/onboarding copy | Fallback |

### 3.3 Proposed Architectural Fix: Scaled Button Text + Responsive Padding
We enhance `AppButton` (`lib/core/widgets/app_button.dart`) and `RoleSelectionPage`:

#### 1. In `AppButton` (`lib/core/widgets/app_button.dart`):
Ensure the button text label is wrapped in `FittedBox` with a bounded minimum scale, preventing ellipses on tight density boundaries:
```dart
Widget _buildLabel(BuildContext context) {
  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.center,
    child: Text(
      label,
      maxLines: 1,
      style: textStyle,
    ),
  );
}
```

#### 2. In `RoleSelectionPage` (`lib/features/role_selection/role_selection_page.dart`):
Adjust the inner button spacing and padding:
```dart
// Reduce intra-button gap from 10dp to 8dp to yield 2dp additional width
actions: Row(
  children: [
    Expanded(
      child: AppButton(
        label: 'Sign in',
        outlined: true,
        onPressed: _opening ? null : () => _open(role, register: false),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: AppButton(
        label: 'Create account',
        onPressed: _opening ? null : () => _open(role, register: true),
      ),
    ),
  ],
)
```

---

## 4. Verification & Regression Plan

1. **Native Permissions Unit Test**:
   - Roboelectric / JUnit test in `android/app/src/test/kotlin/.../NativePermissionsTest.kt`:
     - Mock `NotificationManagerCompat.areNotificationsEnabled() = false` on SDK 31 → assert `hasNotifications() == false`.
     - Mock `NotificationManagerCompat.areNotificationsEnabled() = true` on SDK 31 → assert `hasNotifications() == true`.
2. **Flutter Widget Test**:
   - In `test/features/role_selection/role_selection_page_test.dart`:
     - Pump `RoleSelectionPage` with a constrained screen width of $360\text{ dp}$ (equivalent to 1080px at 480dpi).
     - Assert that `find.text('Create account')` is found and visible without any clipped ellipsis.
     - Verify both Parent Mode and Child Mode cards render complete text labels.
