# 06 — In-Depth Audit of REV-008: Android Notification Permissions, Channel Inspection & Platform API Evolution

**Document ID:** HAVEN-AUD-006  
**Target Defect:** HAVEN-QA-004 (`DEF-604` / `MON05`)  
**Target Finding:** REV-008 (MEDIUM — Android Notification Channels & Runtime Permissions)  
**Phase:** Phase 1.3 — Independent Closure Verification & Owner Approval Readiness Audit (Strictly Read-Only)  
**Date:** 2026-11-24  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  

---

## 1. Executive Summary

This audit evaluates the native Android permission reporting mechanism implemented in `android/app/src/main/kotlin/com/parentcontrol/parent_control/NativePermissions.kt` and its integration with `GuardianService.kt`.

Phase 1.1 identified that inspecting only the app-level master switch via `NotificationManagerCompat.areNotificationsEnabled()` causes false-positive permission reporting on Android 8.0+ (API 26+) when an individual notification channel is disabled.

During source inspection, the audit uncovered a **critical discrepancy in the Phase 1.2 remediation report**: the report repeatedly cited the channel ID as `"guardian_service_channel"`, whereas source inspection of `GuardianService.kt:36` proved that the actual channel ID is `"guardian_status"`.

---

## 2. Section 13: In-Depth Audit of REV-008 (Answers to the 10 Mandatory Questions)

### 1. Does the named channel actually exist in the repository?
**Auditor Analysis: NO.** `guardian_service_channel` does **NOT** exist in the repository.  
Source inspection of `android/app/src/main/kotlin/com/parentcontrol/parent_control/GuardianService.kt:36` reveals:
```kotlin
private const val CHANNEL_ID = "guardian_status"
```
The channel constant in production code is `"guardian_status"`.

### 2. Is the channel ID identical to the foreground service notification channel ID?
**Auditor Analysis: NO in the Phase 1.2 report; YES once corrected to `"guardian_status"`.**  
In `GuardianService.kt:700`, `NotificationCompat.Builder(this, CHANNEL_ID)` binds the ongoing foreground service notification directly to `"guardian_status"`. Querying `"guardian_service_channel"` returns `null`.

### 3. What happens if the channel has not been created yet?
**Auditor Analysis: Vulnerability in Phase 1.2 Plan.**  
On API 26+, `getNotificationChannel("guardian_status")` returns `null` before `GuardianService.createChannel()` executes (lines 699–713). If `NativePermissions.kt` inspects the channel before the foreground service has ever started, a naive check evaluates `channel.importance` on a null reference or treats `null` as blocked, falsely reporting that permissions are denied.  
**Resolution**: The native check must handle `null` gracefully as `CHANNEL_NOT_YET_CREATED` or lazily invoke channel creation.

### 4. Is `IMPORTANCE_NONE` sufficient to identify blocking?
**Auditor Analysis: YES on API 26+.**  
When a user navigates to `App Info → Notifications → Channels` and disables the channel, Android sets `NotificationChannel.getImportance() == NotificationManager.IMPORTANCE_NONE`.

### 5. Can the notification channel group be blocked?
**Auditor Analysis: YES on API 28+ (Android 9 Pie).**  
Android 9 introduced `NotificationChannelGroup.isBlocked()`. If a channel belongs to a blocked group, notifications are suppressed even if the individual channel is active. While `"guardian_status"` is not currently assigned to a group, defensive engineering requires checking group status if groups are added in the future.

### 6. Does API 33+ (Android 13 Tiramisu) runtime permission denial produce the correct state?
**Auditor Analysis: YES.**  
`ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED` correctly flags runtime grant vs. denial.

### 7. What is reported below API 26 (Android 7.1 and lower)?
**Auditor Analysis:**  
Notification channels do not exist below API 26. `NotificationManagerCompat.from(context).areNotificationsEnabled()` must be inspected.  
*(Note: Current code at `NativePermissions.kt:30` erroneously returned `true` unconditionally below API 33, ignoring the master switch on APIs 21–32!).*

### 8. Can an app-level enabled result coexist with a disabled required channel?
**Auditor Analysis: YES (The Core Defect of HAVEN-QA-004).**  
The user leaves the master switch ON, but mutes the specific ongoing foreground notification channel. Under Phase 1 code, `areNotificationsEnabled()` returned `true`, but the foreground service failed to post its notification, leading Android to kill the background sync process (`onTimeout`).

### 9. Are optional channels incorrectly treated as required?
**Auditor Analysis: NO.**  
`"guardian_status"` is the sole notification channel registered and required by `GuardianService`.

### 10. Does the bridge return enough information to distinguish each condition?
**Auditor Analysis: NO in current code and Phase 1.2 plan.**  
Returning a single `Boolean` (`capabilities.notifications_granted`) prevents the Flutter UI from knowing *why* notifications are disabled, preventing it from showing tailored instructions (e.g., "Grant permission" vs. "Unmute Guardian Notification in Settings").

---

## 3. Recommended Typed Diagnostic Model

To provide actionable guidance without breaking wire compatibility, the native bridge should return a structured diagnostic enum:

```kotlin
enum class NotificationDiagnosticState {
    FULLY_GRANTED,                 // Master ON, Channel Active, Runtime Granted
    APP_NOTIFICATIONS_DISABLED,    // Master switch turned OFF
    REQUIRED_CHANNEL_BLOCKED,      // "guardian_status" importance == NONE
    REQUIRED_CHANNEL_NOT_CREATED,  // Service not yet initialized
    CHANNEL_GROUP_BLOCKED,         // Group blocked (API 28+)
    RUNTIME_PERMISSION_DENIED,     // POST_NOTIFICATIONS denied (API 33+)
    UNKNOWN_ERROR
}
```

### Native Implementation Specification (`NativePermissions.kt`):
```kotlin
fun getNotificationDiagnostic(context: Context): NotificationDiagnosticState {
    val manager = NotificationManagerCompat.from(context)
    if (!manager.areNotificationsEnabled()) {
        return NotificationDiagnosticState.APP_NOTIFICATIONS_DISABLED
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED) {
            return NotificationDiagnosticState.RUNTIME_PERMISSION_DENIED
        }
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = notificationManager.getNotificationChannel("guardian_status")
        if (channel == null) {
            return NotificationDiagnosticState.REQUIRED_CHANNEL_NOT_CREATED
        }
        if (channel.importance == NotificationManager.IMPORTANCE_NONE) {
            return NotificationDiagnosticState.REQUIRED_CHANNEL_BLOCKED
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val group = channel.group?.let { notificationManager.getNotificationChannelGroup(it) }
            if (group != null && group.isBlocked) {
                return NotificationDiagnosticState.CHANNEL_GROUP_BLOCKED
            }
        }
    }

    return NotificationDiagnosticState.FULLY_GRANTED
}

fun hasNotifications(context: Context): Boolean {
    val state = getNotificationDiagnostic(context)
    return state == NotificationDiagnosticState.FULLY_GRANTED ||
           state == NotificationDiagnosticState.REQUIRED_CHANNEL_NOT_CREATED
}
```

**REV-008 Official Status:** **CLOSED WITH CONDITIONS**  
*Mandatory Condition:* Fix channel ID to `"guardian_status"` in `NativePermissions.kt` and handle uncreated channel states gracefully.
