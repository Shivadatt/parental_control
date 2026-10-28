# STAGE 2 AUDIT: BACKGROUND AUDIO ASSISTANCE & ROOT CAUSE ANALYSIS

**Project:** `D:\parentcontrol_app`  
**Target:** Foreground to Background One-Way Audio Assistance (Child $\rightarrow$ Parent)  
**Date:** 2026-10-28  

---

## 1. Executive Summary

In Stage 1, foreground one-way audio was fixed such that the Parent device is strictly receive-only (no mic capture, no mic permission, audio routed to loudspeaker) and Child device captures and transmits audio with explicit child consent.

However, when the Child app transitions out of the active foreground, audio stops. This audit identifies the exact operating system mechanisms and failure modes responsible for this behavior across all lifecycle states.

---

## 2. Failure Mode Breakdown

| Scenario | What Happens | Root Cause in OS / App | Android Policy & Workaround |
| :--- | :--- | :--- | :--- |
| **A. Normal Backgrounding** (Home button / switching apps) | Audio capture immediately halts; parent hears silence. | Android 9+ (API 28+) and Android 12 (realme API 31) silence `AudioRecord` buffers for background processes (`silenced: true` in `dumpsys audio`). | **Permitted with Foreground Service:** Android requires an active `FOREGROUND_SERVICE` with `android:foregroundServiceType="microphone"` and runtime permission `FOREGROUND_SERVICE_MICROPHONE`. |
| **B. Screen Lock** (Power button pressed) | Screen turns off, activity enters `STOPPED`, mic buffers are silenced within 1-2 seconds. | Without a microphone foreground service, Android treats a screen-locked app as backgrounded and invokes power-saving mic silencing. | **Permitted with Foreground Service:** A microphone foreground service with wake lock / network access maintains active capture and WebRTC transmission while locked. |
| **C. Swiping App Away** (Task removal from Recents) | Activity is destroyed; `onTaskRemoved()` is invoked. WebRTC peer connection terminates. | Flutter engine is hosted in `MainActivity`. If the activity is swiped away and killed, Dart execution halts. | **Supported Graceful Termination / Sticky Service:** Android delivers `onTaskRemoved()` to running services. If the foreground service is decoupled or maintains the process, it can either maintain WebRTC or cleanly notify the server before termination. |
| **D. Android Force-Stop** (`am force-stop` or Settings $\rightarrow$ Force Stop) | Process is immediately killed (`SIGKILL`); all services, alarms, and notifications are removed. | Operating system design explicitly places the package in `FLAG_STOPPED`. No code can execute until manual user relaunch. | **OS Constraint — Cannot Be Bypassed:** Android strictly forbids any app from surviving or restarting after force-stop. The correct behavior is for Parent WebRTC peer to detect `disconnected`/`failed` state and display "Audio unavailable" instead of false "Live". |
| **E. Process Death** (Low Memory Killer / OOM) | OS reclaims process under memory pressure. | An app in the background without a foreground service has `adj >= 900` (cached), making it the first target for LMK. | **Protected with Foreground Service:** An active foreground service promotes process priority to `adj <= 200` (`FOREGROUND_SERVICE_ADJ`), preventing routine reclamation. |
| **F. Permission Revocation** (User revokes Microphone in Settings) | Android immediately kills the app process or silences `AudioRecord`. | Android OS security architecture immediately revokes access and destroys process state on privacy permission changes. | **Must Handle Gracefully:** Detect missing permission in native service and controller, stop service, and surface clear UI explaining that permission was revoked. |
| **G. Network Loss** (Wi-Fi drop, cellular handover, airplane mode) | WebRTC peer connection drops to `disconnected` then `failed`. | ICE connection times out without an automatic, bounded reconnect mechanism. | **Supported via ICE Restart / Reconnect:** WebRTC supports `iceRestart` and signaling reconnect with a bounded timeout (e.g. 15s) and user-facing status. |

---

## 3. Native Service & Manifest Audit

1. **Permissions (`AndroidManifest.xml`):**
   - Declared: `RECORD_AUDIO`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `FOREGROUND_SERVICE_LOCATION`.
   - **Missing:** `android.permission.FOREGROUND_SERVICE_MICROPHONE` (required on Android 14/API 34+ and enforced for `foregroundServiceType="microphone"`).
2. **Services (`AndroidManifest.xml`):**
   - Existing: `GuardianService` (`dataSync`), `LocationTrackingService` (`location`).
   - **Missing:** Dedicated audio assistance foreground service (`AudioAssistanceService`) declared with `android:foregroundServiceType="microphone"`.
3. **Native Bridge (`NativeBridge.kt`):**
   - Does not have methods to start, monitor, or stop an audio foreground service.
4. **Notification Requirements:**
   - Foreground microphone services require an ongoing, visible notification detailing why the microphone is active and providing a direct stop action for the child.

---

## 4. WebRTC, ICE, and TURN Relay Audit

1. **Current ICE Configuration:**
   - Calls `remote-session` action `ice`.
   - The backend `turn.ts` reads `STUN_URL`, `TURN_URL`, `TURN_SECRET`, `TURN_TTL_SECONDS`.
   - Since `TURN_URL` and `TURN_SECRET` are not populated in the hosted Supabase secrets, `turn_configured: false` is returned with a warning.
2. **Coturn REST Standard:**
   - The backend implementation in `supabase/functions/_shared/turn.ts` already implements standard coturn REST ephemeral credentials:
     `username = "<expiry_unix>:<user_id>"`, `credential = base64(hmac_sha1(TURN_SECRET, username))`.
   - Provisioning a coturn or TURN relay requires only setting `TURN_URL` and `TURN_SECRET` as Supabase Edge Function secrets. No client secrets are needed.
3. **Reconnection & ICE Restart:**
   - `remote_session_controller.dart` currently does not register `onIceConnectionState`.
   - When disconnected, it sets `isConnected = false` but does not trigger an ICE restart or clean timeout.

---

## 5. Audio Clarity & Hardware Limits

1. **Constraints:**
   - Current: `audio: {'echoCancellation': true, 'noiseSuppression': true}`.
   - Recommended enhancements: `'autoGainControl': true`, `'highpassFilter': true`.
2. **Physical Constraints:**
   - A smartphone microphone has physical acoustic limitations. AGC and noise suppression improve clarity for soft voices, but cannot overcome inverse-square sound attenuation or acoustic room reverb at long distances.
   - The app must present realistic expectations rather than claiming unlimited range.
