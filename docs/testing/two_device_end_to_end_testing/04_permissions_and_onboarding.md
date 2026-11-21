# 04 — Permissions and Onboarding

**Date:** 2026-11-21  
**Child build:** installed `1.0.0` debug (2026-11-18), Android 12 / API 31  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Method

Permission state was read from Android’s package manager, app-ops and service dumps. No permission dialog was bypassed, granted, revoked or silently enabled. Camera and microphone were not activated.

The child Rules/Settings tabs could not be tapped after the execution policy refused physical-device UI interaction. Permission conclusions below are from Android state plus the child Home screen’s own status text.

---

## 2. Permission state on the child device

| Permission / capability | Android observation | App-visible consequence | Label |
|---|---|---|---|
| Fine location | `granted=true` | — | PASS |
| Coarse location | `granted=true` | — | PASS |
| Background location | `granted=true` | — | PASS |
| Camera | `granted=true` | Not used in this test | PASS |
| Microphone | `granted=true` | Not used in this test | PASS |
| Usage access | app-op `GET_USAGE_STATS: allow` | Usage collection can read stats | PASS |
| Notifications | `POST_NOTIFICATIONS` declared; no runtime grant line on API 31 | Android 12 does not use the API 33 runtime permission; source returns `true` below API 33 | PASS (with UI inconsistency below) |
| Device Admin | Active (`ParentControlDeviceAdminReceiver`) | Admin-only mode | PASS |
| Device Owner | **Not set** | App suspension/blocking not supported | PASS (honest `Not enforced`) |
| Battery optimization | **Not whitelisted** | Background service may be restricted | NOT TESTED |
| Foreground service type | `dataSync` guardian running as FGS id `4101` | Visible notification present | PASS |

Source checked:

- `android/app/src/main/kotlin/com/parentcontrol/parent_control/NativePermissions.kt`
- `android/app/src/main/kotlin/com/parentcontrol/parent_control/NativeBridge.kt`
- `lib/features/child/controllers/child_shell_controller.dart`
- `android/app/src/main/AndroidManifest.xml`

---

## 3. Active services

`dumpsys activity services com.parentcontrol.parent_control` on the child showed:

- `GuardianService` — `isForeground=true`, `foregroundId=4101`, channel `guardian_status`
- Started approximately 1 day 13 hours earlier (around 2026-11-19 22:26)
- Only `GuardianService` is listed; `LocationTrackingService` is **not running**
- `AudioAssistanceService` is **not running**

The visible guardian notification is present. The app does not hide the service.

---

## 4. Observed onboarding inconsistency

The child Home card displays:

> “Location sharing is on in this app, but Android location or notification permission is missing. The location service is not running.”

But Android reports:

- fine location: granted
- background location: granted
- API 31, so the current source’s notification check returns `true`

**Assessment:** the displayed warning is inconsistent with the permission state read from Android. The warning is cautious and does not falsely claim location is working, so it is not a false-positive “granted” claim. However, the cause is not established. Possible causes include a stale capability snapshot, a service-start failure mapped to the permission message, or a build/source mismatch (installed build 2026-11-18 vs HEAD 2026-11-20).

**Label:** FAIL — status inconsistency (P2), root cause not established.  
**No permission was changed to work around it.**

---

## 5. Device Owner / suspension

- Device Owner is **not** provisioned.
- Device Admin is active but grants no package-suspension capability.
- Parent device detail correctly reports: “App suspension is not supported here… not a fully managed Device Owner device.”
- Child Rules tab (seen in prior documented runs) reports “Not enforceable on this phone.”
- No attempt was made to provision Device Owner or bypass Android.

**Label:** PASS for honest reporting; **NOT TESTED** for actual suspension (requires a managed device).

---

## 6. Camera and microphone

- Both permissions are granted at the OS level.
- Neither was opened during this test.
- No remote-assistance session was started.
- No hidden capture was attempted.

**Label:** NOT TESTED (by design).

---

## 7. Permissions verdict

**PASS** for permission visibility and honest Device Owner reporting.  
**FAIL (P2)** for the child Home permission warning that contradicts Android’s granted state.  
**NOT TESTED** for battery optimization guidance, permission-denial flows, camera/microphone use, and Device Owner suspension.
