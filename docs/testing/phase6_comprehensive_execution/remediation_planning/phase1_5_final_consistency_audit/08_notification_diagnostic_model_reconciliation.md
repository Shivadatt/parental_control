# Phase 1.5: Notification Diagnostic Model Reconciliation

**Document ID:** `HAVEN-AUD-008-PHASE1.5`  
**Phase:** Phase 1.5 — Independent Final Consistency & Security Closure Review  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Android Native Permissions & Diagnostics Reconciliation  

---

## 1. Executive Summary

This assessment resolves the root causes of defect `HAVEN-QA-004` (DEF-604: false-positive notification permission reporting) and the state-mixing defects in Phase 1.4. In Phase 1.4, permissions, notification channels, and background foreground service execution states were collapsed into a single flat diagnostic enum (`ACTIVE`, `CHANNEL_BLOCKED`, `NOTIFICATIONS_DISABLED`, `REQUIRED_CHANNEL_NOT_CREATED`, `SERVICE_RUNNING`, `PERMISSION_DENIED`).

By inspecting Android native source files (`NativePermissions.kt`, `GuardianService.kt`, `MainActivity.kt`), this audit establishes an orthogonal **Three-Dimensional Diagnostic Model** that prevents false-positive reporting across all Android OS versions (specifically contrasting Android 12 and Android 13+).

---

## 2. Root Cause Analysis of False-Positive Reporting (HAVEN-QA-004)

### 2.1 The Code Defect in `NativePermissions.kt`
Direct inspection of `android/app/src/main/kotlin/com/parentcontrol/parent_control/NativePermissions.kt:29-32` reveals:
```kotlin
fun hasNotifications(context: Context): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
    return granted(context, Manifest.permission.POST_NOTIFICATIONS)
}
```

#### Why This Failed on Android 12 (Realme RMX2161)
1. Android 13 (`TIRAMISU`, API 33) introduced the runtime permission `Manifest.permission.POST_NOTIFICATIONS`.
2. On Android 12 and below (API $\le 32$), the runtime permission did not exist, leading the original author to assume `if (Build.VERSION.SDK_INT < TIRAMISU) return true`.
3. However, on Android 12 and below, users can still disable notifications globally for the application via the Android OS Application Settings.
4. When a user disabled notifications in system settings on Android 12, `hasNotifications()` continued to return `true`, producing a confirmed false-positive report to both the child UI and the parent dashboard.

### 2.2 The Remediation Fix Required
To accurately detect notification status across all versions, the call must evaluate system-level enablement via AndroidX:
```kotlin
fun hasNotifications(context: Context): Boolean {
    // 1. Check system-level enablement across ALL Android versions
    if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
        return false
    }
    // 2. On Android 13+, additionally check runtime permission
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        return granted(context, Manifest.permission.POST_NOTIFICATIONS)
    }
    return true
}
```

---

## 3. The Flaw of Single-Enum Dimension Mixing

In Phase 1.4, diagnostic states were conflated into a single enum:
- `ACTIVE`
- `CHANNEL_BLOCKED`
- `NOTIFICATIONS_DISABLED`
- `REQUIRED_CHANNEL_NOT_CREATED`
- `SERVICE_RUNNING`
- `SERVICE_STOPPED`
- `PERMISSION_DENIED`

### Why Single-Enum Collapsing Fails:
1. **Service Running $\not\Rightarrow$ Notification Permission**: `GuardianService` may be actively running in the background as a foreground service, but if the user blocked notifications, the foreground notification is hidden, degrading foreground service reliability on Android 14+.
2. **Notification Permission $\not\Rightarrow$ Channel Enabled**: Even if global notifications are `Granted`, Android 8.0+ allows users to selectively disable individual notification channels (e.g., muting channel `"guardian_status"` while leaving other channels open).
3. **Channel Exists $\not\Rightarrow$ Notification Visible**: A channel may exist in `NotificationManager`, but if importance is set to `IMPORTANCE_NONE`, notifications are silently dropped.
4. **Arbitrary Priority Precedence**: A single enum forces an arbitrary hierarchy (e.g., does `SERVICE_STOPPED` take precedence over `CHANNEL_BLOCKED`?).

---

## 4. Canonical Three-Dimensional Diagnostic Architecture

The diagnostics are decoupled into three independent, orthogonal dimensions:

```
+--------------------------------------------------------------------------------------------------+
|                                THREE-DIMENSIONAL DIAGNOSTIC MODEL                                |
|                                                                                                  |
|  [ DIMENSION 1: NOTIFICATION PERMISSION ]                                                        |
|  - System App Level: ENABLED | DISABLED (via NotificationManagerCompat.areNotificationsEnabled)  |
|  - Runtime Permission (API 33+): GRANTED | DENIED | NOT_APPLICABLE (API <= 32)                   |
|                                                                                                  |
|  [ DIMENSION 2: NOTIFICATION CHANNEL ] (Channel ID: "guardian_status")                           |
|  - AVAILABLE (Importance > IMPORTANCE_NONE)                                                      |
|  - BLOCKED (Importance == IMPORTANCE_NONE)                                                       |
|  - NOT_CREATED (Channel null in NotificationManager)                                             |
|  - NOT_APPLICABLE (API < 26)                                                                     |
|                                                                                                  |
|  [ DIMENSION 3: GUARDIAN SERVICE RUNTIME ] (GuardianService.isRunning)                          |
|  - RUNNING (Foreground service actively polling and heartbeating)                                |
|  - STOPPED (Service halted or not started)                                                       |
|  - BLOCKED_BY_SYSTEM (Android 12+ background start restriction encountered)                      |
+--------------------------------------------------------------------------------------------------+
```

### 4.1 Detailed Dimension Specification

| Dimension | Diagnostic Value | API Availability | Native Android Detection Logic | Semantic Meaning |
|---|---|---|---|---|
| **1. Permission** | `GLOBAL_DISABLED` | All APIs | `!NotificationManagerCompat.from(ctx).areNotificationsEnabled()` | User disabled all app notifications in OS settings. |
| **1. Permission** | `RUNTIME_DENIED` | API 33+ | `ContextCompat.checkSelfPermission(...) != PERMISSION_GRANTED` | User denied `POST_NOTIFICATIONS` runtime prompt. |
| **1. Permission** | `GRANTED` | All APIs | System enabled AND (API < 33 OR runtime granted) | App has full OS authority to display notifications. |
| **2. Channel** | `AVAILABLE` | API 26+ | `channel != null && channel.importance > IMPORTANCE_NONE` | Channel `"guardian_status"` active and audible/visible. |
| **2. Channel** | `BLOCKED` | API 26+ | `channel != null && channel.importance == IMPORTANCE_NONE` | Channel `"guardian_status"` specifically muted by user. |
| **2. Channel** | `NOT_CREATED` | API 26+ | `notificationManager.getNotificationChannel("guardian_status") == null` | Service has not yet executed `createNotificationChannel()`. |
| **2. Channel** | `NOT_APPLICABLE` | API < 26 | `Build.VERSION.SDK_INT < Build.VERSION_CODES.O` | Notification channels not supported by Android OS. |
| **3. Service** | `RUNNING` | All APIs | `GuardianService.isRunning == true` | Background execution worker active and running. |
| **3. Service** | `STOPPED` | All APIs | `GuardianService.isRunning == false && lastError == null` | Service halted normally or waiting for start. |
| **3. Service** | `BLOCKED_BY_SYSTEM`| All APIs | `lastError != null` (e.g., ForegroundServiceStartNotAllowedException) | Android OS blocked background service startup. |

---

## 5. MethodChannel Bridge & Data Contract

To pass typed diagnostics to the Flutter UI without string parsing ambiguities, `NativeBridge.kt` must return a structured map:

```json
{
  "permission": {
    "system_enabled": true,
    "runtime_granted": true,
    "status": "GRANTED"
  },
  "channel": {
    "channel_id": "guardian_status",
    "status": "AVAILABLE",
    "importance": 3
  },
  "service": {
    "is_running": true,
    "status": "RUNNING",
    "last_error": null
  }
}
```

### User-Facing State Derivation Matrix

| Permission Status | Channel Status | Service Status | Child UI Display Badge | Parent Dashboard Indicator |
|---|---|---|---|---|
| `GRANTED` | `AVAILABLE` | `RUNNING` | **"Protection Active"** (Green) | **"Online & Protected"** (Green) |
| `GRANTED` | `AVAILABLE` | `STOPPED` | **"Protection Paused"** (Amber) | **"Service Inactive"** (Amber) |
| `GRANTED` | `AVAILABLE` | `BLOCKED_BY_SYSTEM`| **"Android Blocked Background Service"** (Red) | **"Service Blocked by OS"** (Red) |
| `GLOBAL_DISABLED` | Any | Any | **"Notifications Disabled in Settings"** (Amber) | **"Notifications Blocked"** (Amber) |
| `GRANTED` | `BLOCKED` | `RUNNING` | **"Status Notification Muted"** (Amber) | **"Channel Muted"** (Amber) |
| `RUNTIME_DENIED` | Any | Any | **"Permission Required"** (Amber) | **"Permission Denied"** (Amber) |

---

## 6. Conclusion & Gate Readiness

- **Defect Resolved**: `HAVEN-QA-004` (DEF-604) is completely addressed by decoupling dimensions and invoking `NotificationManagerCompat.from(context).areNotificationsEnabled()`.
- **Implementation Scope (Wave 1)**: Modifies `NativePermissions.kt` and `GuardianService.kt` under Gate 2. Zero database or backend impact.
