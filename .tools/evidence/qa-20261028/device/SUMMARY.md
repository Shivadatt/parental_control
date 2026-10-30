# QA 2026-10-28 — Device evidence (read-only)

Collected 2026-10-28 ~08:21–08:26 IST. No app data cleared, no uninstall/sign-out/unlink/revoke, no policy or device-admin changes. Only taps/swipes/back/refresh were used; both devices stayed on `com.parentcontrol.parent_control/.MainActivity`.

## Device facts

| | LEFT (Parent) | RIGHT (Child) |
|---|---|---|
| ADB serial | `emulator-5554` | `5HXWRGQ4IFU8WS4T` |
| `ro.serialno` | `EMULATOR37X2X12X0` | `5HXWRGQ4IFU8WS4T` |
| Model | `sdk_gphone64_x86_64` | `RMX2161` (realme) |
| Android / SDK | **17 / 37** | **12 / 31** |
| Timezone | Asia/Calcutta (IST) | Asia/Kolkata (IST) |
| App version | 1.0.0 (versionCode **4002**, minSdk 24, targetSdk 36) | 1.0.0 (versionCode **4002**, minSdk 24, targetSdk 36) |
| firstInstallTime | 2026-10-27 14:55:10 | 2026-10-27 12:55:41 |
| lastUpdateTime | 2026-10-28 00:26:14 | 2026-10-28 00:26:03 |
| /data | 5.8G, 1.8G used, 3.8G avail (33%) | 108G, 51G used, 57G avail (48%) |
| Foreground activity | `.../.MainActivity` (topResumed) | `.../.MainActivity` (mResumed) |

## Signed-in identity shown by UI

Both screens display only the family label **"QA Family A"**. No email, phone number or account ID is shown on the captured screens. Exact signed-in account (email) is NOT TESTED / not exposed in UI.

## Parent Dashboard — all rows (3 scroll pages + refresh)

5 rows total. **4 = Revoked, 1 = Offline, 0 = Active/Online.**

1. QA Child A / **QA Test Phone A** — **Revoked** — Last seen **1 d ago · Oct 26, 2026 10:08 PM** — Battery 15% — Enforcement **Fully managed (Device Owner)** — Policy **Policy v1 · Enforced on device**
2. QA Child A / **QA Test Phone A** — **Revoked** — **1 d ago · Oct 26, 2026 10:23 PM** — 15% — Fully managed (Device Owner) — Policy v1 · Enforced on device
3. QA Child A / **QA Phone A** — **Revoked** — **Never reported** — Unknown — **Not enforced** — **Policy v2 · Waiting for device**
4. QA Child A / **QA Phone A** — **Revoked** — **Never reported** — Unknown — Not enforced — Policy v2 · Waiting for device (duplicate row)
5. QA Child A / **realme RMX2161** — **Offline** (NOT Revoked) — **4 min ago · Oct 28, 2026 3:47 AM** — **100% (charging)** — **Device admin only** — **No policy applied yet**

Contradiction with the brief/screenshot: the realme row is badged **Offline**, not Revoked. The "4 min ago" label conflicts with its own timestamp **3:47 AM** while both device clocks read **08:2x IST**; tapping Refresh returned the identical string, so it is not a live-ticking heartbeat.

## Child (realme) Home — exact visible text

- Badge: **Offline**; Name **realme RMX2161**; Last seen **39 min ago · Oct 28, 2026 7:41 AM**; Battery **100% (charging)**
- Android control: **Device admin only — app blocking is not available**
- Policy version: **No rules downloaded**
- Warning: **App blocking is not enforced on this phone** — "This phone is not set up as a managed Device Owner device. A normal app install cannot suspend other apps. A guardian can provision it through Android managed-device or Device Owner setup."
- **Background protection** — "A visible Android notification appears while this runs." — badge **Running** — Service **Running with a visible notification** — Last command check **36 min ago** — **Last error: App list upload failed: apps[13].package_name is not a valid Android package name.**

## Rules screen (realme, nav: View rules and permissions)

- **Enforcement cannot be verified on this phone** — "This app is not a Device Owner here, so it cannot suspend other apps. Rules are shown as configured, not as blocked. A guardian must provision Android managed-device or Device Owner setup."
- **No rules on this phone yet** — "Rules appear after your guardian saves them for this phone and the background service downloads them. Nothing is blocked until Android applies and confirms them."
- Button: **Refresh**.

## Device Owner / admin state

- Emulator `dpm list-owners` → empty output. `dumpsys device_policy`: **Enabled Device Admins (User 0): none**; `Device Owner Type: -1`. → **No Device Owner, no active admin.**
- Realme `dpm list-owners` → **`no owners`**.
- Realme `dumpsys device_policy`: active admin **`com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver`**, uid 11312, `testOnlyAdmin=false`; no Device Owner / Profile Owner entry. → **Device admin only, NOT Device Owner.**
- Note: Parent rows 1–2 advertise "Fully managed (Device Owner)" but that is stale/revoked historical data; the emulator itself has no admin or DO installed.

## Background service / notification

- Realme: `GuardianService` present, `isForeground=true`, `foregroundId=4101`, `createTime=-7h19m`, **`lastActivity=-37m20s`**, `startForegroundCount=1`.
- Emulator: `dumpsys activity services com.parentcontrol.parent_control` → `(nothing)`.
- Realme notification record id 4101, channel `guardian_status`, title **Parent Control**, text **"Background sync needs attention. Tap to review."**, `when` 1793156003432. It is visible in the shade only after scrolling, under **Silent notifications**, shown as "now". Emulator has no active app notification.
- "Running" is true at the service level, but the notification itself says the sync needs attention.

## Why the realme shows no rules

- Parent row 5 says **No policy applied yet** (there is no applied policy for this device to fetch).
- Child Rules screen says **No rules on this phone yet / No rules downloaded**.
- App is **not Device Owner** (`no owners`), so app blocking cannot be applied even if rules arrived.
- Child reports **App list upload failed: apps[13].package_name is not a valid Android package name.**
- No policy fetch/ack or HTTP status lines exist in the captured logcat; the app is not debuggable, so server-side fetch/ack state could not be read (BLOCKED).

## Heartbeat assessment

No evidence of a current heartbeat. Child's own "last seen" is 39 min ago (7:41 AM), "last command check" 36 min ago, and `GuardianService.lastActivity` 37m20s ago. Parent's "4 min ago" is not corroborated: its timestamp is 3:47 AM (≈4h35m before the 08:2x clocks) and the string did not change after Refresh. No recent app network traffic in logcat.

## Contradictions with the supplied screenshot/brief

1. Realme row is **Offline**, not Revoked; only 4 of 5 rows are Revoked.
2. Realme "Last seen 4 min ago · 3:47 AM" is internally inconsistent and stale; child UI and service state say ~36–39 min.
3. "Background protection Running" is service-true, but the posted notification says "Background sync needs attention" and is filed under Silent notifications.
4. Dashboard shows "Fully managed (Device Owner)" for old revoked rows, but the emulator currently has no Device Owner and no active admin.
5. Emulator is Android **17/API 37**, not Android 12.

## Evidence files (all under `.tools/evidence/qa-20261028/device/`)

- `emulator-5554_01_dashboard.png`, `emulator-5554_02_scroll.png`, `emulator-5554_03_scroll.png`, `emulator-5554_04_refresh.png`
- `5HXWRGQ4IFU8WS4T_01_home.png`, `..._02_rules.png`, `..._03_shade.png`, `..._04_shade_scroll.png`, `..._05_home_after.png`
- `emulator-5554_ui.xml`, `..._ui_scroll2.xml`, `..._ui_scroll3.xml`, `..._ui_refresh.xml`, `emulator-5554_ui_text.txt`, `emulator-5554_ui_scroll3_text.txt`
- `5HXWRGQ4IFU8WS4T_ui.xml`, `..._ui_rules.xml`, `..._ui_shade.xml`, `..._ui_text.txt`, `..._ui_rules_text.txt`
- `dpm_owners.txt`, `device_policy_full.txt`, `services_both.txt`, `notifications.txt`, `notification_detail.txt`, `jobscheduler_realme.txt`, `alarms_realme.txt`, `clocks.txt`
- `emulator-5554_logcat.txt`, `5HXWRGQ4IFU8WS4T_logcat.txt`, `5HXWRGQ4IFU8WS4T_logcat_pid.txt` (sanitized; no tokens/JWTs/auth headers stored)
