# AirDroid Kids — Full Setup on Realme RMX2161 (2026-10-29)

Setup, screen recording and evidence pack for the child-side app (**AirDroid Kids**) on the
test phone, captured end-to-end over ADB. Every status below is either **PASS** (verified on
the device), **BLOCKED** (cannot be automated, manual step required) or **UNVERIFIED**
(no evidence available from this device). Nothing here is inferred.

---

## 1. Hinglish TL;DR

- Phone: **Realme RMX2161**, Android 12 (API 31) — ADB serial `5HXWRGQ4IFU8WS4T`.
- Kids app: **AirDroid Kids 1.8.5.0** + **AirDroid Kids Wizard 1.1.2.0**.
- Setup **teen baar** poora kiya: do normal runs + ek **fresh redo** (data clear → unbind → dobara
  consent → code → permissions), taaki ek clean, complete video mile.
- Guardian consent diya, ToS/Privacy accept kiya.
- Binding code **220742236** enter kiya → guardian **spg7753@gmail.com** ne device accept kiya
  (11:43, 11:57 aur fresh redo me 12:14 — teen baar same account resolve hua).
- Child profile: **Realme RMX2161**, DOB 2019 (7 years), default avatar.
- Permissions: Accessibility, Usage Access, Notification Listener, Overlay, Device Admin,
  Battery unrestricted, Location (incl. background), Camera/Mic, Contacts/SMS/Call log — **sab ON**.
- **Auto-start** (Realme ka apna setting) sirf manually on hoga — ADB se nahi (BLOCKED).
- **Hide notifications (stealth)** jaan-boojh kar **skip** kiya — neeche reason hai.
- **App icon** AirDroid Kids bind hone ke baad khud hide kar deta hai (wizard ne launcher alias
  disable kiya). Wapas dikhane ka ADB rasta BLOCKED hai, lekin app `airdroidkids://open/kid_activate`
  se khulti hai — dono baatein §5.4 me hain.
- Videos: `airdroid_kids_setup_fresh.mp4` (8 min 25 s, **main**) + `airdroid_kids_fresh_prelude.mp4`
  (1 min 50 s) + do purane runs.

---

## 2. Device and app facts

| Item | Value |
|---|---|
| Device | Realme RMX2161 (ADB serial `5HXWRGQ4IFU8WS4T`) |
| Android | 12, API 31, build 12 |
| Screen / density | 1080 × 2400, 480 dpi |
| Kids app | `com.sand.airdroidkids` v1.8.5.0 (installed 2026-10-29 11:05:30) |
| Setup wizard | `com.sand.airdroidkidsw` v1.1.2.0 (reinstalled 2026-10-29 11:53:56) |
| Screen recorder | `com.oplus.screenrecorder` v12.11.30 (native ColorOS recorder) |
| Guardian account | `spg7753@gmail.com` |
| Binding code used | `220742236` |

Why the OEM recorder: `adb shell screenrecord` is **not executable** on this build
(`/system/bin/sh: screenrecord: inaccessible or not found` — SELinux blocks the shell domain),
so recording was done with the phone's own recorder and pulled over ADB afterwards.

---

## 3. What was done — timeline

### 3.1 Permission pre-work (before the recorded run)

Most Android permissions were already granted on the device from the first pass; they were
re-verified at the end of the second pass, not re-granted:

| Permission / capability | State (evidence) |
|---|---|
| Accessibility service | `AccessibilityLimitService` enabled (`settings get secure enabled_accessibility_services`) |
| Notification listener | `NotificationService` in `enabled_notification_listeners` |
| Usage access | `GET_USAGE_STATS: allow` |
| Display over other apps | `SYSTEM_ALERT_WINDOW: allow` |
| Device admin | `KidDeviceAdminReceiver` active (`dumpsys device_policy`) |
| Battery optimisation | whitelisted (`dumpsys deviceidle whitelist` → `user,com.sand.airdroidkids`) |
| Notifications | allowed (`POST_NOTIFICATION` default allow) |
| Location | fine + coarse + **background** granted |
| Camera / Microphone | granted |
| Contacts / SMS / Call log / Phone state / Answer calls | granted |
| All files access | **not granted** (`MANAGE_EXTERNAL_STORAGE: default`) — optional, left off |

Full dump: `permission_state.txt` in this folder.

### 3.2 Recorded run (video `airdroid_kids_setup_full.mp4`, 11:54:46 → 12:01:39)

| Time | Step | Evidence file |
|---|---|---|
| 11:54 | Wizard "Setup Completed" (wizard reinstalled at 11:53:56) | `media/step17_wizard_start.png` |
| 11:55 | Tap **Open AirDroid Kids** → Guardian Consent | `media/step18_kids_home_bound.png` |
| 11:56 | Tick "I have read and agree to the Terms of Service and the Privacy Policy" | `media/step19_consent_checked.png` |
| 11:56 | Tap **Accept** → "Join Your Family Group" code screen | `media/step20_after_accept.png` |
| 11:57 | Enter binding code **2 2 0 7 4 2 2 3 6** (digit by digit) | `media/step21_code_result.png` |
| 11:57 | Confirmation dialog: "The guardian (**spg7753@gmail.com**) will be able to manage how this device is used." → OK | — |
| 11:57 | Edit Child's Profile (name `Realme RMX2161`, DOB 2019 → 7 years) → Done | `media/step22_after_bind.png` |
| 11:58 | "Hide System Notifications" (stealth) → **Skip** (see §5.3) | `media/step24_hide_notify.png` |
| 11:58 | "You've completed basic settings" → only **Allow auto-start** remains | `media/step25_after_skip.png` |
| 11:58 | Tapping its **Settings** opens the App Info page — Realme exposes no auto-start there | `media/step26_autostart_result.png` |
| 12:01 | Kids app home: **Supervision Mode enabled — the guardian can manage how this device is used now** | `media/step27_final_home.png` |
| 12:02 | Family tab: Family Group (2), "Realme RMX2161 joined the group 11:58 am", member `User736952` | `media/probe_shade3.png` |

### 3.3 First pass (video `airdroid_kids_first_bind.mp4`, 11:41:32 → 11:44:56)

Same flow one hour earlier, including the **first** acceptance of code `220742236` at 11:43
(`media/step04_code_entered.png`) and the first "Supervision Mode enabled" state at 11:50
(`media/step11b_notifications_granted.png`). Kept as evidence that the code was accepted twice.

### 3.4 Fresh redo — clean run from zero (videos `airdroid_kids_fresh_prelude.mp4` + `airdroid_kids_setup_fresh.mp4`)

Requested: data clear karke unbind, phir poora flow dobara — slow pace par — taaki ek saaf
end-to-end recording bane. Unbind `pm clear com.sand.airdroidkids` se kiya (device-admin
`dpm remove-active-admin` Android ne refuse kiya: "Attempt to remove non-test admin").

**Prelude clip — 12:09:55 → 12:11:45 (1 min 50 s)**
1. Guardian/Parental Control app se device unbind + kids app data clear.
2. Kids app dobara launch → Guardian Consent screen (terms/checkbox reset the).
3. Recorder start karke consent screen se aage badhe.

**Main clip — 12:12:33 → 12:20:58 (8 min 25 s)**

| Time | Step | Evidence file |
|---|---|---|
| 12:12 | Consent screen (data clear ke baad) | `media/step30_fresh_consent.png` |
| 12:13 | ToS + Privacy checkbox tick | `media/step31_consent_ticked.png` |
| 12:13 | **Accept** → "Join Your Family Group" | `media/step32_join_group.png` |
| 12:14 | Code **220742236** digit-by-digit → server dialog naming guardian | `media/step33_code_dialog.png` |
| 12:15 | Child profile (name, DOB 2019) → Done | `media/step34_profile.png` |
| 12:16 | In-app checklist (Usage Limits, Screen Mirroring, Sync Notifications, Location Tracker, Remote Camera, One-Way Audio, Auto-start) | `media/step35_checklist.png` |
| 12:17 | Remote Camera → system camera dialog → **Allow** | `media/step36_camera_granted.png`, `media/step37_after_camera.png` |
| 12:18 | Usage Limits / Screen Mirroring → **Accessibility** system page → service ON | `media/step39_a11y_prompt.png`, `media/step39b_now.png`, `media/step40_a11y_page.png` |
| 12:19 | Sync Notifications → notification-access prompt shown (listener already granted via ADB) | `media/step41_checklist_after_grants.png` |
| 12:20 | Home: **Supervision Mode enabled — guardian spg7753@gmail.com** | `media/step42_now.png` |
| 12:22 | Post-run verification: admin + listener + accessibility still active, `POST_NOTIFICATION` appop (data clear ne `ignore` kar diya tha) wapas allow | `permission_state.txt` |

Note: `pm clear` device-admin ko bhi hata deta hai; re-bind ke baad admin dobara active mila
(`KidDeviceAdminReceiver`, `testOnlyAdmin=false`) — ye checklist ke Accessibility step ke saath
hi wapas aaya. Launcher icon is run ke baad bhi hidden raha (§5.4).

---

## 4. The binding code 220742236 — what it is and what was observed

- It is the **9-digit binding code** generated in the guardian's **AirDroid Parental Control**
  app. Typing it on the child device is what creates the supervision relationship.
- Observed: entered at **11:43**, **11:57** and again at **12:14** (fresh redo, after
  `pm clear`) on 2026-10-29. On all three occasions the server resolved it to the **same
  guardian account** (`spg7753@gmail.com`) and showed the "guardian will be able to manage this
  device" dialog before binding.
- Expected: codes are time-limited and normally single-use per binding. Observed: the same code
  bound the device **three times over ~31 minutes**, i.e. it stayed valid and reusable within its
  window for this account, even across a client-side data clear. After it expires, the parent app
  must generate a new code — the child app cannot mint one.
- Treat the code as a credential: anyone holding it plus physical access to a child device can
  attach that device to the same guardian account. Rotate/regenerate after testing.

---

## 5. Permissions — what each one actually does (and status)

### 5.1 Granted (PASS)

| Permission | Why AirDroid Kids needs it | How it was confirmed |
|---|---|---|
| Guardian consent (ToS + Privacy) | Legal basis for collecting the child's device data | Checkbox + Accept in-app |
| Binding code | Links this device to the guardian account | Server dialog naming the guardian |
| Accessibility service | App/screen-time enforcement and app blocking | `enabled_accessibility_services` |
| Usage access | App usage, screen time, app-usage reports | `GET_USAGE_STATS: allow` |
| Notification listener | Reads device notifications for the parent dashboard | `enabled_notification_listeners` |
| Display over other apps | Draws the block/lock overlay | `SYSTEM_ALERT_WINDOW: allow` |
| Device admin | Anti-uninstall / lock / wipe protection | `KidDeviceAdminReceiver` active |
| Battery optimisation off | Keeps the guardian service alive | Device-idle whitelist |
| Notifications | Foreground-service and alert notifications | App Info shows "Allow" |
| Location (fine, coarse, background) | Geofencing and location history | Runtime grants |
| Camera / Microphone | Remote camera & remote audio assistance | Runtime grants |
| Contacts / SMS / Call log / Phone state | Call & SMS monitoring features | Runtime grants |
| Storage (read) | File/media features | Runtime grants |

### 5.2 BLOCKED — auto-start (Realme/ColorOS)

The in-app checklist still shows **"Allow auto-start"**. Realme's auto-start list lives in the
protected `com.oplus.safecenter/.startupapp.view.StartupAppListActivity`, which requires
`oplus.permission.OPLUS_COMPONENT_SAFE`; ADB is refused:

```
java.lang.SecurityException: Permission Denial: ... requires oplus.permission.OPLUS_COMPONENT_SAFE
```

The App Info page on this build has no auto-start toggle, so this is a **manual** step:

1. Open **Phone Manager** (or Settings → Apps → *Auto-start*, depending on build).
2. Find **AirDroid Kids** and enable **Allow auto-start**.

Impact is low: the app already runs a foreground service, has the battery exemption, device
admin, accessibility and notification-listener rights, so it survives normal backgrounding.

### 5.3 Deliberately skipped

- **Hide System Notifications (stealth)** — hides AirDroid Kids' notification and makes the app
  hard for the child to discover. Skipped: it is not a permission, and this repository's own
  design stance (`docs/remote-assistance.md`) is that supervision must be visible to the child.
  Enable it from the app if the product decision is stealth.
- **All files access** (`MANAGE_EXTERNAL_STORAGE`) — only needed for full file browsing; left off.

### 5.4 Launcher icon is hidden after binding — BLOCKED to restore via ADB

AirDroid Kids bind hone ke baad apna launcher entry khud disable kar deta hai. Verification:

```
$ adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER com.sand.airdroidkids
No activity found
$ adb shell dumpsys package com.sand.airdroidkids | grep -A3 disabledComponents
  disabledComponents:
    com.sand.airdroidkids.KidSplashActivity_alias
  lastDisabledCaller: com.sand.airdroidkidsw
```

Ye AirDroid Kids ka **built-in anti-tamper** hai (child app ko home screen/app drawer se chhupana),
na ki koi permission. Isi wajah se home screen par sirf wizard ka icon dikhta hai
(`media/step46_home_after.png`).

Restore karne ke do hi raste hain, dono ADB se BLOCKED:

```
$ adb shell pm enable com.sand.airdroidkids/com.sand.airdroidkids.KidSplashActivity_alias
java.lang.SecurityException: Shell cannot change component state for ... to 1
```

1. **Guardian side** — AirDroid Parental Control app me *My → Admin Code* se code set karke
   child device par *Parental Settings → app icon* wapas on karna. (Child device par
   *Parental Settings* kholte hi "Admin Code Not Set" dialog aata hai —
   `media/step45_parental_settings.png` — yaani bachcha khud setting badal nahi sakta.)
2. **Unbind** karke app dobara install karna.

Verified workaround (PASS): app deep link se khulti hai aur Supervision Mode active dikhata hai —

```bash
adb shell am start -a android.intent.action.VIEW -d 'airdroidkids://open/kid_activate'
# → com.sand.airdroidkids/.ui.main.KidMainActivity, "Supervision Mode enabled"
```

`media/step43_deeplink.png` (app khula) aur `media/step44_overflow.png` (menu: Clear Cache /
Feedback / About Us / Uninstall — koi "show icon" option nahi).

Impact: functionality par koi asar nahi (services, admin, accessibility sab chal rahe hain);
asar sirf discoverability par hai — jo actually intended behaviour hai.

---

## 6. Video files

| File | Duration | Covers |
|---|---|---|
| `airdroid_kids_setup_fresh.mp4` | 8 min 25 s (95.9 MB) | **Main deliverable** — fresh redo: consent → code → profile → camera → accessibility → notifications → supervision enabled (12:12:33–12:20:58) |
| `airdroid_kids_fresh_prelude.mp4` | 1 min 50 s (41.9 MB) | Unbind + data clear + relaunch + consent screen (12:09:55–12:11:45) |
| `airdroid_kids_setup_full.mp4` | 6 min 53 s (59.4 MB) | Second pass: consent → code → profile → permissions checklist → supervision enabled (11:54:46–12:01:39) |
| `airdroid_kids_first_bind.mp4` | 3 min 24 s (25.0 MB) | First pass incl. first code entry at 11:43 |

The fresh pair together is the complete, uninterrupted story; the two earlier clips are kept as
evidence that the code bound the same guardian three times.

All were produced by `com.oplus.screenrecorder` (1080×2400 device). Note: notification content
and the notification shade appear in the video; the guardian e-mail `spg7753@gmail.com` and the
binding code are visible — treat the recordings as private credentials-adjacent material.

---

## 7. How this maps to `parent_control` (your app)

| AirDroid Kids | Your app (`D:\parentcontrol_app`) |
|---|---|
| 9-digit code from parent app | Pairing code issued by an Edge Function, scoped by RLS — same "parent proves, child joins" pattern |
| Accessibility service blocks apps | Your design uses Device Admin / **Device Owner** + `UsageStatsManager`; your docs are explicit that package suspension needs Device Owner and that a normal install must report `Unsupported` |
| Notification listener | Your app has no notification-listener path; AirDroid gains notification content from it — a product privacy decision |
| Battery exemption + auto-start | Your guardian foreground service + battery exemption; no OEM auto-start equivalent yet |
| Stealth "hide notifications" | Your docs forbid covert operation; AirDroid offers it — keep the visible/consented stance unless product says otherwise |
| Hidden launcher icon + Admin Code gate (§5.4) | Your docs require visible supervision; if you ever add an icon-hide option, make it opt-in, child-visible in the wizard and documented — AirDroid does neither |

---

## 8. Honest status

| Claim | Status |
|---|---|
| Guardian consent + ToS accepted | **PASS** (in-app, video, all three runs) |
| Code `220742236` bound device to `spg7753@gmail.com` | **PASS** (server dialog names the guardian, three times) |
| Supervision Mode enabled on child | **PASS** (app home + Family tab) |
| Accessibility / usage / listener / overlay / admin / battery / notifications | **PASS** (system dumps, re-verified after fresh redo) |
| Runtime permissions (location, camera, mic, contacts, SMS, call log, phone state) | **PASS** (runtime grants) |
| Fresh redo from cleared data works end-to-end | **PASS** (video 12:09–12:21) |
| Auto-start (ColorOS) | **BLOCKED** — manual step, §5.2 |
| Launcher icon visible after binding | **BLOCKED** — hidden by the app; workaround verified, §5.4 |
| Parent-side dashboard shows and controls this device | **UNVERIFIED** — no access to the parent app from this device |
| Remote features (location, camera, mic, app blocking) actually act on the device | **UNVERIFIED** — needs a parent-side action to observe |

Residual gaps are not passes. Everything listed as UNVERIFIED needs a parent-side test.

---

## 9. Reproduce

```bash
adb devices -l                      # RMX2161 serial 5HXWRGQ4IFU8WS4T
# fresh redo / unbind (device admin ko dpm se hatana security exception deta hai, pm clear chalta hai)
adb shell pm clear com.sand.airdroidkids
adb shell am start -a android.intent.action.VIEW -d 'airdroidkids://open/kid_activate'
# start ColorOS recorder from the phone, then drive the wizard:
adb shell input tap 540 1250                                  # Open AirDroid Kids
adb shell input tap 96 1591                                   # ToS checkbox
adb shell input tap 540 2009                                  # Accept
for d in 2 2 0 7 4 2 2 3 6; do adb shell input text $d; sleep 0.8; done
adb shell input tap 540 1446                                  # OK (after countdown)
adb shell input tap 540 2185                                  # Done on child profile
# permissions jo app ke checklist se trigger hote hain, ADB equivalent:
adb shell pm grant com.sand.airdroidkids android.permission.CAMERA
adb shell settings put secure enabled_accessibility_services \
  com.sand.airdroidkids/com.sand.airdroidkids.services.AccessibilityLimitService
adb shell cmd notification allow_listener \
  com.sand.airdroidkids/com.sand.airdroidkids.services.NotificationService
adb shell appops set com.sand.airdroidkids POST_NOTIFICATION allow   # API 31: pm grant nahi chalta
# pull the recording (Git Bash needs path conversion off):
MSYS_NO_PATHCONV=1 adb pull /sdcard/Pictures/Screenshots/Record_2026-10-29-12-12-33.mp4 out.mp4
```

## 10. Evidence index

```
reports/kids-setup-2026-10-29/
  README.md                       this report
  permission_state.txt            raw system dumps (accessibility, listener, admin, appops, grants)
  airdroid_kids_setup_fresh.mp4   fresh redo walkthrough, 8m25s  ← main
  airdroid_kids_fresh_prelude.mp4 unbind + consent prelude, 1m50s
  airdroid_kids_setup_full.mp4    second pass, 6m53s
  airdroid_kids_first_bind.mp4    first pass, 3m24s
  media/                          50 step screenshots (step00 … step46, incl. 06b/11b/39b) + 5 probe shots
```
