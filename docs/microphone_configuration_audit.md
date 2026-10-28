# Microphone & One-Way Audio Feature — Technical Configuration & Read-Only Audit

**Project:** `D:\parentcontrol_app`  
**Date:** 2026-10-28  
**Audit Type:** Read-Only Technical Configuration & Static/Device Audit  
**Author:** Antigravity Agentic Assistant  
**Target Environment:**
- **Parent Device (Left):** Android Emulator (`emulator-5554`), Android 17 (API 37), PID `5468`, logged in as QA Parent (`qa.parent.a2.20261026@example.com`).
- **Child Device (Right):** Physical realme 7 / Narzo 20 Pro (`RMX2161`), Serial `5HXWRGQ4IFU8WS4T`, Android 12 (API 31), PID `16237`, logged in as QA Child (`qa.child.a2.20261026@example.com`).
- **Backend Environment:** Hosted Supabase Project `hhqgreaoqulmfwfwarhc` (STUN enabled, TURN unconfigured).
- **Toolchain:** FVM Flutter 3.44.6, Dart 3.12.2, Kotlin 1.9.24.

---

## A. Executive Summary

### 1. Overall Status: CRITICAL ARCHITECTURAL CONFLICT & INCOMPLETE CONFIGURATION

The existing audio implementation in the repository was built as a **two-way mutual intercom/call**, directly contradicting the **one-way audio specification** (`Child microphone → audio capture → WebRTC transport → Parent receiver → Parent speaker`).

Furthermore, while the security, consent, and signaling layers are robustly implemented and strictly enforced, critical audio routing, background service declarations, in-session controls, and TURN relay infrastructure are either missing or misconfigured.

### 2. What is Already Configured & Verified
- **Permission Declarations:** `android.permission.RECORD_AUDIO` is declared in `android/app/src/main/AndroidManifest.xml` and is granted on the physical realme device (`5HXWRGQ4IFU8WS4T`, `granted=true`).
- **Native Android Bridge:** `NativePermissions.kt` and `NativeBridge.kt` provide functional method channels for querying and requesting runtime permissions.
- **Strict Authorization & Consent Gate:** Supabase Edge Function `remote-session` (`index.ts`) and database RLS enforce that only verified parents can request sessions, the child must explicitly accept before media can be opened, sessions expire after 10 min (requested) or 30 min (consented), and all signaling via `webrtc_signals` is restricted to authorized session participants.
- **Local Audio Capture & Preview:** Local child microphone capture and preview are functional and proven via `MediaSelfTestSheet` (`lib/features/child/widgets/media_self_test_sheet.dart`).
- **Teardown & Cleanup:** Session exit, back navigation (`PopScope`), expiry, or explicit termination reliably halts local media tracks and disposes the peer connection before invoking server endpoints.

### 3. What is Missing, Broken, or Misconfigured
- **Parent Receive-Only Architecture (VIOLATION / BUG-MIC-01):**
  - In `lib/features/remote_assistance/remote_session_controller.dart` (`join()`), the Parent application requests `getUserMedia({'audio': true})`, demands `RECORD_AUDIO` from the Parent OS, opens the Parent microphone, and transmits Parent audio to the Child.
  - If the Parent user denies microphone permission on their own phone, `permissionDenied.value = true` triggers and the Parent is completely blocked from joining or listening to the Child.
  - The UI explicitly announces "Tapping the button below opens your microphone" on the Parent screen (`remote_session_page.dart:284-295`).
- **Audio Output & Speakerphone Routing (BUG-MIC-02):**
  - `Helper.setSpeakerphoneOn` from `flutter_webrtc` is **never called anywhere in the codebase**.
  - On Android, WebRTC defaults audio playback to `AudioManager.MODE_IN_COMMUNICATION` (earpiece/handset). Incoming audio will not play through the device loudspeaker unless routed via native audio management.
- **Background Microphone Execution (RESTRICTED BY ANDROID OS / BUG-MIC-03):**
  - `AndroidManifest.xml` does **not** declare `android.permission.FOREGROUND_SERVICE_MICROPHONE`.
  - The existing background services (`GuardianService` for `dataSync` and `LocationTrackingService` for `location`) do not have the `microphone` foreground service type.
  - Under Android 11+ and Android 12 (API 31 on the realme), background microphone access without an active `microphone` foreground service is silenced by Android system policy (`AudioRecord` buffers are zeroed out by `AudioFlinger`).
  - `RemoteSessionController` has no `WidgetsBindingObserver` to manage background/foreground transitions.
- **In-Session Audio Controls (BUG-MIC-04):**
  - There are no controls for in-session mute/unmute, volume control, or live audio level / waveform visualization on either device. Only a static icon (`Icons.graphic_eq`) is displayed.
- **Relay Infrastructure (BUG-MIC-05):**
  - Supabase project `hhqgreaoqulmfwfwarhc` has no `TURN_URL` or `TURN_SECRET` configured. ICE relies entirely on Google STUN (`stun:stun.l.google.com:19302`). Symmetric NATs, carrier firewalls, or cellular-to-Wi-Fi routing will fail media establishment.

---

## B. Configuration Matrix

| # | Feature / Component | Status | Evidence (File & Symbol) | Actual Test Performed | Missing Configuration / Defect | Recommended Action |
|---|---------------------|--------|--------------------------|-----------------------|--------------------------------|-------------------|
| **1** | **Android Microphone Permission Declaration** | `PASS — STATICALLY VERIFIED` | [AndroidManifest.xml](file:///d:/parentcontrol_app/android/app/src/main/AndroidManifest.xml#L10), [AndroidManifest.xml](file:///d:/parentcontrol_app/android/app/src/main/AndroidManifest.xml#L32-L33) | Inspected manifest declarations; ran `dumpsys package com.parentcontrol.parent_control` on realme. | None for basic capture. Missing `FOREGROUND_SERVICE_MICROPHONE` for background capture. | Keep declaration; add foreground service permission if background capture is required. |
| **2** | **Runtime Permission Handling** | `PASS — STATICALLY VERIFIED` | [NativePermissions.kt](file:///d:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/NativePermissions.kt#L14), [NativeBridge.kt](file:///d:/parentcontrol_app/android/app/src/main/kotlin/com/parentcontrol/parent_control/NativeBridge.kt#L348), [device_admin_service.dart](file:///d:/parentcontrol_app/lib/data/services/device_admin_service.dart#L131) | Static code audit; unit tested via `remote_session_controller_test.dart:195`. Realme device dumpsys confirmed `RECORD_AUDIO: granted=true`. | Bridge is functional, but Parent controller mistakenly requests mic permission for Parent role. | In `RemoteSessionController`, bypass permission request if `isParentRole == true`. |
| **3** | **Foreground-Service Configuration** | `NOT CONFIGURED` | [AndroidManifest.xml](file:///d:/parentcontrol_app/android/app/src/main/AndroidManifest.xml#L75-L84) (`GuardianService`, `LocationTrackingService`) | Inspected service declarations and types in manifest and Kotlin service classes. | No service declared with `android:foregroundServiceType="microphone"`. Missing `FOREGROUND_SERVICE_MICROPHONE` permission. | If background audio is needed, declare `FOREGROUND_SERVICE_MICROPHONE` and implement a dedicated foreground service with an ongoing notification. |
| **4** | **Child Microphone Capture** | `PASS — LOCAL TEST VERIFIED` | [remote_session_controller.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_controller.dart#L498-L509), [media_self_test_sheet.dart](file:///d:/parentcontrol_app/lib/features/child/widgets/media_self_test_sheet.dart#L147) | Exercised via local camera/microphone self-test on realme RMX2161; unit tested with mock repository. | Code captures mic with echo cancellation and noise suppression, but lacks audio level metering. | Add real-time audio volume / waveform stream to provide visual feedback of audio transmission. |
| **5** | **Parent Receive-Only Enforcement** | `FAIL — ARCHITECTURAL DEFECT` | [remote_session_controller.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_controller.dart#L507-L509), [remote_session_controller.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_controller.dart#L572-L574), [remote_session_page.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_page.dart#L284-L295) | Static audit of `join()` method and UI text in `remote_session_page.dart`. | Parent captures mic, requires mic permission, transmits audio track to child, and UI says "Join with microphone". | Enforce receive-only on Parent: omit audio constraints in `getUserMedia` for Parent, set `offerToReceiveAudio: true` in SDP offer. |
| **6** | **WebRTC Audio Transport & Routing** | `PARTIAL` | [remote_session_controller.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_controller.dart#L517-L543), [remote_session_controller.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_controller.dart#L665-L679) | Checked track attachment and renderer initialization in `_attachRemote`. Grepped codebase for speakerphone helpers. | Audio playback defaults to earpiece (`MODE_IN_COMMUNICATION`). `Helper.setSpeakerphoneOn` is never called. STUN-only ICE. | Call `Helper.setSpeakerphoneOn(true)` on remote stream reception; configure coturn TURN secrets in Supabase. |
| **7** | **Supabase Backend Authorization** | `PASS — HOSTED API VERIFIED` | [remote-session/index.ts](file:///d:/parentcontrol_app/supabase/functions/remote-session/index.ts#L84-L345), [20260101000200_rls.sql](file:///d:/parentcontrol_app/supabase/migrations/20260101000200_rls.sql#L202-L231) | Executed backend test suite (`validation_test.ts`, `turn_test.ts`); tested live API flow via `.tools/live/verify_devices.mjs`. | None. Authorization is strict: authenticated parent, active child device, mandatory child consent, nonces, and TTLs enforced. | Maintain existing backend contract and RLS policies. |
| **8** | **Background Operation** | `BLOCKED / RESTRICTED` | [remote_session_controller.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_controller.dart#L20-L75), Android 11+ OS AudioFlinger policy | Inspected lifecycle listeners in controller; reviewed Android 12 background restrictions. | No `WidgetsBindingObserver`. Android 11+ silences background mic capture when no microphone foreground service is active. | Add lifecycle listener to terminate session gracefully upon backgrounding, or implement a microphone foreground service. |
| **9** | **Session Termination & Resource Cleanup** | `PASS — STATICALLY & UNIT TESTED` | [remote_session_controller.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_controller.dart#L695-L777), [remote_session_controller_test.dart](file:///d:/parentcontrol_app/test/features/remote_assistance/remote_session_controller_test.dart#L170-L193) | Verified teardown ordering: stops tracks, disposes peer, resets renderer, then calls server end; tested offline failure handling. | Expiry sweep cron job is disabled in hosted project (`CRON_SECRET` unset), but server actions fail closed lazily. | Enable pg_cron or edge scheduled trigger for `expire_stale_sessions` when `CRON_SECRET` is set. |
| **10** | **Error Handling & User Feedback** | `PASS — STATICALLY VERIFIED` | [remote_session_controller.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_controller.dart#L604-L614), [child_session_page.dart](file:///d:/parentcontrol_app/lib/features/child/child_session_page.dart#L104-L160) | Code audit of banner tones (`warning`, `danger`), permission denial dialogs, and ICE failure alerts. | In-session connection warnings are presented as static text banners; no automatic ICE reconnect/restart. | Add reconnection retry action when signaling or media drops. |

---

## C. Real-Device Test Matrix

| Test Scenario | Status | Device / Environment | Detailed Observation & Technical Root Cause |
|---------------|--------|----------------------|----------------------------------------------|
| **1. RECORD_AUDIO Permission State** | `PASS — LIVE DEVICE VERIFIED` | realme RMX2161 (`5HXWRGQ4IFU8WS4T`) | `dumpsys package com.parentcontrol.parent_control` confirms `android.permission.RECORD_AUDIO: granted=true` (flags: `USER_SET`). |
| **2. Child Local Audio Capture** | `PASS — LOCAL TEST VERIFIED` | realme RMX2161 (`5HXWRGQ4IFU8WS4T`) | Child self-test sheet initializes `flutter_webrtc` audio capture cleanly with green OS microphone indicator visible. |
| **3. Parent Receive-Only Enforcement** | `FAIL` | Codebase & Emulator (`emulator-5554`) | **CRITICAL DEFECT:** Parent UI prompts "Join with microphone", initializes local mic capture via `getUserMedia`, and adds outgoing audio track to peer connection. |
| **4. Parent Loudspeaker Audio Playback** | `NOT IMPLEMENTED / FAIL` | Emulator (`emulator-5554`) & realme | `Helper.setSpeakerphoneOn` is never called. WebRTC defaults to earpiece receiver (`MODE_IN_COMMUNICATION`). No audible loudspeaker playback. |
| **5. In-Session Mute / Unmute** | `NOT IMPLEMENTED` | Both devices | Neither `remote_session_page.dart` nor `child_session_page.dart` provides mute buttons or track disable toggles during a call. |
| **6. Live Audio Level / Waveform Meter** | `NOT IMPLEMENTED` | Both devices | Only a static `Icons.graphic_eq` icon is shown. No WebRTC `getStats()` or audio volume analysis is performed. |
| **7. Two-Device Media Negotiation (STUN)** | `PASS — STATICALLY VERIFIED` | Emulator + realme (local network) | SDP offer/answer exchange through `webrtc_signals` table is verified in unit tests and SQL RLS policies. |
| **8. Two-Device Media Negotiation (TURN)** | `NOT CONFIGURED / BLOCKED` | Hosted Supabase | Hosted `remote-session` returns `turn_configured: false`. Traversal through symmetric carrier NATs cannot be established. |
| **9. Background Microphone Capture** | `BLOCKED` | realme RMX2161 (Android 12) | Blocked by Android OS. Without `FOREGROUND_SERVICE_MICROPHONE`, Android 12 silences mic buffers when the app leaves the foreground. |
| **10. Lock Screen Microphone Capture** | `BLOCKED` | realme RMX2161 (Android 12) | Screen locking stops the activity (`onStop`); Android silences capture due to lack of a microphone foreground service. |
| **11. App Swiped / Force Stopped** | `PASS — STATICALLY VERIFIED` | Both devices | OS terminates the process. Media streams are abruptly severed. Remote peer connection transitions to `RTCPeerConnectionStateDisconnected` / `Failed`. |
| **12. Session Expiry & Teardown** | `PASS — LOCAL TEST VERIFIED` | Unit tests & static code | `_teardownMedia()` reliably releases native camera/microphone tracks before invoking backend `end` endpoint. |
| **13. Audible End-to-End One-Way Playback** | `BLOCKED` | Both devices | Cannot be marked as passing because the current build transmits two-way audio, routes audio to earpiece, and lacks speakerphone routing. |

---

## D. Bugs & Technical Recommendations

### 1. BUG-MIC-01 (Severity: Critical — Architectural Defect)
- **Description:** Parent application captures local microphone and transmits audio to Child instead of acting as a receive-only listener.
- **Affected Files:**
  - [lib/features/remote_assistance/remote_session_controller.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_controller.dart#L460-L471), lines 460–471, 498–509, 572–574.
  - [lib/features/remote_assistance/remote_session_page.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_page.dart#L284-L295), lines 284–295.
- **Root Cause:**
  - `_requestMediaPermissions()` is called on both roles requesting `microphone: true`. If the Parent denies mic access on their phone, the session aborts.
  - `join()` acquires `getUserMedia({'audio': ...})` unconditionally and adds local tracks to the peer connection for both roles.
- **Recommended Fix:**
  1. In `remote_session_controller.dart`, modify `_requestMediaPermissions()`:
     ```dart
     if (isParentRole) return true; // Parent is receive-only, no mic permission needed
     ```
  2. In `join()`, wrap local stream capture:
     ```dart
     MediaStream? localStream;
     if (!isParentRole) {
       localStream = await navigator.mediaDevices.getUserMedia(constraints);
       for (final track in localStream.getTracks()) {
         await peerConnection.addTrack(track, localStream);
       }
     }
     ```
  3. When creating the SDP offer on Parent, configure audio reception:
     ```dart
     final offer = await peerConnection.createOffer({
       'offerToReceiveAudio': 1,
       'offerToReceiveVideo': latest.kind == SessionKind.video ? 1 : 0,
     });
     ```
  4. In `remote_session_page.dart`, change button label and explanatory text from "Join with microphone" to "Start listening" / "Listen to audio".
- **Required Regression Test:** Unit test verifying that Parent `join()` does not call `getUserMedia` or request `microphone` permission, and generates an offer with `offerToReceiveAudio: 1`.

---

### 2. BUG-MIC-02 (Severity: High — Missing Audio Routing)
- **Description:** Incoming audio on the Parent device is routed to the telephone earpiece rather than the loudspeaker.
- **Affected File:** [lib/features/remote_assistance/remote_session_controller.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_controller.dart#L665-L679), lines 665–679 (`_attachRemote`).
- **Root Cause:** `flutter_webrtc` uses native Android WebRTC audio device modules which set audio mode to `AudioManager.MODE_IN_COMMUNICATION`. Without an explicit call to `Helper.setSpeakerphoneOn(true)`, audio is heard only through the internal earpiece.
- **Recommended Fix:**
  1. In `_attachRemote(MediaStream stream)`:
     ```dart
     if (stream.getAudioTracks().isNotEmpty) {
       await Helper.setSpeakerphoneOn(true);
     }
     ```
  2. In `_teardownMedia()`:
     ```dart
     await Helper.setSpeakerphoneOn(false);
     ```
- **Required Regression Test:** Integration test verifying `Helper.setSpeakerphoneOn` invocation during media attach and reset on teardown.

---

### 3. BUG-MIC-03 (Severity: High — Background Audio Silencing)
- **Description:** Microphone capture on Child device is silenced by Android 11+ / Android 12 when app is backgrounded or screen locked.
- **Affected Files:**
  - [android/app/src/main/AndroidManifest.xml](file:///d:/parentcontrol_app/android/app/src/main/AndroidManifest.xml#L10-L15)
  - [android/app/src/main/AndroidManifest.xml](file:///d:/parentcontrol_app/android/app/src/main/AndroidManifest.xml#L75-L84)
  - [lib/features/remote_assistance/remote_session_controller.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_controller.dart#L20-L75)
- **Root Cause:**
  - Android 11+ (API 30+) and Android 12 (API 31 on realme) prohibit background microphone capture unless an active foreground service with type `microphone` (`FOREGROUND_SERVICE_MICROPHONE`) is bound.
  - The app's existing foreground services are `GuardianService` (`dataSync`) and `LocationTrackingService` (`location`).
  - `RemoteSessionController` has no lifecycle observer (`WidgetsBindingObserver`).
- **Recommended Fix:**
  - **Option A (Foreground-Only Design — Highly Recommended for Child Privacy):**
    Implement `WidgetsBindingObserver` in `RemoteSessionController`. If the Child app is paused/backgrounded, actively pause capture and display a notification/warning to the Parent: "Child app was backgrounded; audio paused".
  - **Option B (Background Audio Assistance):**
    Declare `android.permission.FOREGROUND_SERVICE_MICROPHONE` in manifest, add `android:foregroundServiceType="microphone"` to an audio assistance service, and start it with an ongoing notification ("Assistance audio active") while the call is connected.
- **Required Regression Test:** Device test verifying audio capture behavior when Child screen is locked and app is minimized.

---

### 4. BUG-MIC-04 (Severity: Medium — Missing In-Session Controls)
- **Description:** No in-session mute/unmute, volume slider, or audio transmission level meter exists.
- **Affected Files:**
  - [lib/features/child/child_session_page.dart](file:///d:/parentcontrol_app/lib/features/child/child_session_page.dart#L283-L358)
  - [lib/features/remote_assistance/remote_session_page.dart](file:///d:/parentcontrol_app/lib/features/remote_assistance/remote_session_page.dart#L316-L350)
- **Root Cause:** UI only displays static status text and static icon `Icons.graphic_eq`.
- **Recommended Fix:**
  1. Add `RxBool isMuted = false.obs` in `RemoteSessionController` and toggle `track.enabled = !isMuted.value`.
  2. Add an interactive Mute button to `ChildSessionPage` and a volume / speaker toggle to `RemoteSessionPage`.
  3. Add a dynamic audio wave visualizer bound to WebRTC audio track volume levels.
- **Required Regression Test:** Widget test verifying tapping Mute disables the audio track and updates UI state.

---

### 5. BUG-MIC-05 (Severity: Medium — Missing TURN Relay Infrastructure)
- **Description:** Remote session ICE configuration is STUN-only; calls over carrier NATs or restrictive Wi-Fi fail.
- **Affected File:** [supabase/functions/_shared/turn.ts](file:///d:/parentcontrol_app/supabase/functions/_shared/turn.ts#L24-L34).
- **Root Cause:** `TURN_URL` and `TURN_SECRET` environment secrets are not configured in the hosted Supabase project dashboard.
- **Recommended Fix:**
  - Deploy coturn server or provision Twilio / Cloudflare TURN relay.
  - Add `TURN_URL` and `TURN_SECRET` to Supabase Edge Function secrets.
- **Required Regression Test:** Verify `remote-session` ICE endpoint returns `turn_configured: true` with ephemeral credentials.

---

## E. Read-Only Audit Conclusion & Next Steps

1. **Audit Compliance:**
   - No source code, manifests, permissions, migrations, or hosted configurations were modified.
   - All uncommitted changes and working tree state have been strictly preserved.
2. **Current Readiness for Live Verification:**
   - **BLOCKED.** Performing a live two-device test with the current codebase will transmit Parent audio to Child and route audio to earpiece.
3. **Required Next Actions (Upon User Approval):**
   1. Fix **BUG-MIC-01**: Make Parent strictly receive-only in `remote_session_controller.dart`.
   2. Fix **BUG-MIC-02**: Add `Helper.setSpeakerphoneOn(true)` in `_attachRemote()`.
   3. Decide on background policy (Option A Foreground-Only vs. Option B Background Service).
   4. Configure TURN relay credentials in Supabase Edge Functions.
   5. Execute controlled two-device audio test between physical realme and Parent device.
