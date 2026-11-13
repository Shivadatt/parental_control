# Realtime, WebRTC, and Two-Device Claims Verification Report

- **Target Repository:** `D:\parentcontrol_app`
- **Auditor:** Agent 2 — Realtime, WebRTC and Two-Device Claims Verification Specialist
- **Verification Date:** 2026-11-13
- **Primary Source Documents:**
  - `docs/testing/realtime_complete_audit/LIVE_TWO_DEVICE_TEST_REPORT.md`
  - `docs/testing/realtime_complete_audit/code_analysis/REALTIME_ARCHITECTURE_AND_CODE_AUDIT.md`
  - `docs/testing/realtime_complete_audit/NAVIGATION_MAP_AND_MATRIX.md`
- **Device Environment Under Audit:**
  - **Parent Device:** Android Emulator (`emulator-5554`, Google Pixel 9a, Android 17 / API 37, x86_64, PID 6274)
  - **Child Device:** Physical Smartphone (`5HXWRGQ4IFU8WS4T`, Realme 7 / Narzo 20 Pro `RMX2161`, Android 12 / API 31, arm64-v8a, PID 3839)
- **Status:** Complete Empirical & Codebase Verification (Read-Only)

---

## Executive Summary

This report delivers a rigorous, forensic verification of the critical claims, contradictory descriptions, and empirical test results documented during the live two-device audit of `com.parentcontrol.parent_control`. 

Through direct static analysis of Flutter (`lib/`), Android Kotlin native (`android/`), and Supabase Edge Functions / PostgreSQL (`supabase/`), cross-referenced with live UI dumps and logcat captures, all key architectural contradictions have been resolved:

1. **WebRTC Stream Topology is Strictly Unidirectional:** Early audit phrasing mentioning "two-way interactive WebRTC audio" is an operational mischaracterization. The Parent application never requests microphone permission, never calls `getUserMedia`, never starts the native microphone service, and never adds an outbound audio track. The Child captures local audio and transmits it UP to the Parent; the Parent acts strictly as a receive-only audio sink (`in 2908 pkts / out 0 pkts`).
2. **Supabase Realtime Scope is Restricted to Exactly Three Channels:** Realtime WebSocket subscriptions are used exclusively for `safety_alerts`, `webrtc_signals`, and `remote_sessions`. All presence, device listing, child shell sync, policy delivery, and command processing rely on deterministic HTTP polling loops (15s to 60s) and scheduled foreground telemetry (300s).
3. **Policy `enforced` Status Reflects Command Handshake, Not OS Suspension:** On standard Android devices (such as physical Realme RMX2161 where `dpm list-owners` is empty), `setPackagesSuspended` is never called by Android OS. Status `enforced` in `device_policies` signifies that the policy command was received, decoded, and stored in local `SecureStore`. Daily limits and bedtime remain purely advisory on non-Device Owner devices, producing the visual contradiction documented in Defects E-6 and E-7.
4. **Parent Permission Snapshot is Vulnerable to Permanent Staleness (Defect E-3):** Permission status tiles on the Parent Device Detail screen reflect cached columns on `public.devices`, refreshed only during child 300s heartbeats. If the child device disconnects or has permissions revoked while offline, the Parent UI indefinitely renders green "Granted" checkmarks without any staleness indicator.
5. **Reinstallation Permanently Invalidates Device Credentials (Defect E-1):** `SecureStore.kt` stores the cryptographic `device_secret` in Android `EncryptedSharedPreferences`. Reinstallation erases the keystore, prompting the child to generate a new secret. Because the backend retains the old `secret_hash`, all subsequent requests fail with `401 Unauthorized` (`invalid_device_credentials`), leaving the device record orphaned until a full re-pairing is executed.
6. **Reported Latency Figures Represent Single-Point Empirical Samples:** The reported latency metrics (14.8s policy sync, 920ms alert ack, 13.7s assistance prompt) represent discrete, single-event empirical timings governed by deterministic polling intervals (15s and 20s) and WebSocket push latencies, rather than statistical averages or network RTTs.

---

## 1. Contradiction 1: WebRTC Media Stream Direction & Topology

### 1.1 The Contradiction
- **Audit Claim / Initial Description:** Some initial documentation referenced "two-way interactive WebRTC audio" between Parent and Child.
- **Empirical Evidence in Logs & UI:** 
  - Parent UI Content-Description (`parent_listening.xml`):
    ```xml
    One-way audio live
    Listening to the child device (loudspeaker enabled).
    Media connected
    Audio live
    DEBUG RTP: in 2908 pkts / 193895 B · out 0 pkts / 0 B
    Ending stops audio listening.
    ```
  - Parent logcat (`parent_webrtc_session.log`):
    ```log
    11-13 16:30:12.923 6274 13577 I audio_device_buffer.cc: (line 506): [PLAY: 10003msec, 8kHz] callbacks: 999, samples: 79920, rate: 7990, rate diff: 0%, level: 63
    ```

### 1.2 Codebase Verification

#### A. Controller Specification & Topology (`RemoteSessionController.dart`)
In `lib/features/remote_assistance/remote_session_controller.dart`:
- Lines 79–81:
  > *"For audio assistance, the Parent is strictly receive-only: the Parent never requests microphone permission or captures local audio. Incoming audio from the Child is routed to the Parent loudspeaker."*
- Lines 1154–1170:
  ```dart
  if (isChildRole) {
    final preflight = await _preflightChildCapture(token);
    if (!preflight) return;
    final serviceReady = await _startConfirmedAudioService(token);
    if (!serviceReady) return;
    serviceStarted = true;
  }
  ```
- Lines 1203–1234: Local media is captured **only** if `isChildRole`:
  ```dart
  MediaStream? localStream;
  if (isChildRole) {
    final constraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'highpassFilter': true,
      },
      if (latest.kind == SessionKind.video)
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
    };
    final stream = await _captureUserMedia(constraints);
    localStream = stream;
    _localStream = stream;
    _setCaptureActive(true);
    _startCaptureHeartbeat();
  }
  ```
- Lines 1278–1290: Track addition vs Offerer constraints:
  ```dart
  if (localStream != null) {
    for (final track in localStream.getTracks()) {
      await peerConnection.addTrack(track, localStream);
    }
  }
  if (isParentRole) {
    final offerConstraints = <String, dynamic>{
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': latest.kind == SessionKind.video,
      },
      'optional': [],
    };
    final offer = await peerConnection.createOffer(offerConstraints);
    await peerConnection.setLocalDescription(offer);
  ...
  ```
- Line 1648:
  ```dart
  Future<bool> _requestMediaPermissions({required bool needsCamera}) async {
    if (!isChildRole) return false;
    ...
  }
  ```

#### B. Native Service Ownership (`AudioAssistanceService.kt`)
In `android/app/src/main/kotlin/com/parentcontrol/parent_control/AudioAssistanceService.kt`:
- Lines 25–34:
  > *"Android Foreground Service of type MICROPHONE. Runs exclusively during active, child-consented audio assistance sessions. Displays a persistent, non-dismissible notification informing the child that the microphone is active and providing an immediate 'Stop' action. This allows Android 11+ and Android 12+ (e.g. realme RMX2161) to continue microphone capture and WebRTC transmission while the app is in the background..."*
- The Parent application NEVER launches `AudioAssistanceService`.

#### C. WebRTC Signaling Role Differentiation
- **Offerer:** The Parent is the sole offerer (`isParentRole`), creating an SDP offer specifying `OfferToReceiveAudio = true` with zero local media tracks attached.
- **Answerer:** The Child is the answerer (`isChildRole`). Upon user hardware consent ("Join with microphone"), Child requests Android runtime `RECORD_AUDIO`, starts the `MICROPHONE` foreground service (`AudioAssistanceService`, ID 4303), acquires microphone input via `getUserMedia()`, adds the audio track to its peer connection, and answers the Parent's SDP offer.

### 1.3 Resolution of Contradiction 1
| Aspect | Audit Initial Phrasing | Verified Implementation & Reality |
|---|---|---|
| **Audio Stream Direction** | "Two-way interactive WebRTC audio" | **Strictly Unidirectional (Child -> Parent)** |
| **Parent Microphone Access** | Implied bidirectional talkback | **None.** Parent never requests `RECORD_AUDIO`, never calls `getUserMedia()`, has no outbound audio stream. |
| **Parent PeerConnection** | Media Sender & Receiver | **Receive-Only Sink.** `OfferToReceiveAudio: true`, 0 tracks added. |
| **Empirical RTP Traffic** | Symmetrical packets | **Asymmetrical.** `in 2908 pkts / 193895 B · out 0 pkts / 0 B` |
| **Child Device Role** | Peer in bidirectional call | **Microphone Capture & Transmitter** under active foreground notification (ID 4303). |

---

## 2. Contradiction 2: Realtime vs Polling vs Scheduled Telemetry

### 2.1 The Contradiction
Audit documentation frequently uses the blanket term "realtime" to describe features that actually operate via periodic HTTP polling, background tickers, or database crons.

### 2.2 Exhaustive Codebase Inventory of Supabase Realtime Channels
A complete recursive search across all Dart files (`lib/`) for `_supabase.client.channel()` confirms that **exactly three (3)** Supabase Realtime channels exist in the entire application:

1. **Safety Alerts Channel:**
   - **File & Line:** `lib/data/repositories/supabase_alert_repository.dart:70-73`
   - **Topic Pattern:** `safety-alerts:<familyId>:<microsecondsSinceEpoch>`
   - **Configuration:** `opts: const RealtimeChannelConfig(private: true)`
   - **Table & Events:** `public.safety_alerts` (`INSERT`, `UPDATE`), filtered by `family_id=eq.<familyId>`
   - **Authorized By:** `private.realtime_topic_allowed()` via RLS

2. **WebRTC Signaling Channel:**
   - **File & Line:** `lib/data/repositories/supabase_remote_session_repository.dart:230-233`
   - **Topic Pattern:** `webrtc-signals:<sessionId>:<microsecondsSinceEpoch>`
   - **Configuration:** `opts: const RealtimeChannelConfig(private: true)`
   - **Table & Events:** `public.webrtc_signals` (`INSERT`), filtered by `session_id=eq.<sessionId>`
   - **Authorized By:** `private.realtime_topic_allowed()` via RLS

3. **Remote Session State Channel:**
   - **File & Line:** `lib/data/repositories/supabase_remote_session_repository.dart:334-337`
   - **Topic Pattern:** `remote-session:<sessionId>:<microsecondsSinceEpoch>` or `remote-session-family:<familyId>:<microsecondsSinceEpoch>`
   - **Configuration:** `opts: const RealtimeChannelConfig(private: true)`
   - **Table & Events:** `public.remote_sessions` (`INSERT`, `UPDATE`)
   - **Authorized By:** `private.realtime_topic_allowed()` via RLS

**Critical Architectural Finding:**
- **Zero** Supabase Broadcast channels exist (`channel.sendBroadcast()` / `channel.onBroadcast()` is never called).
- **Zero** Supabase Presence channels exist (`channel.track()` / `channel.onPresence()` is never called).

### 2.3 Inventory of Polling Loops & Scheduled Telemetry
All other data flows in the application rely on deterministic timers, periodic HTTP polling, or scheduled background tasks:

| Feature / Domain | Architectural Pattern | Code Location | Cadence / Interval | Trigger / Target |
|---|---|---|---|---|
| **Parent Dashboard Telemetry** | Deterministic HTTP Polling | `DashboardController.dart:71-76` | **60 seconds** | `Timer.periodic` fetching family, devices, and latest policy. |
| **Devices List View** | Deterministic HTTP Polling | `DevicesController.dart:61-66` | **60 seconds** | `Timer.periodic` refreshing device cards. |
| **Child Shell Sync** | Deterministic HTTP Polling | `ChildShellController.dart:388-406` | **20 seconds** | `_linkedPollTimer` checking pairing requests and active sessions. |
| **Child Requests Poller** | Deterministic HTTP Polling | `ChildRequestsController.dart:43-48` | **15 seconds** | `_pollTimer` polling incoming assistance and pairing requests. |
| **Child Enrollment Check** | Deterministic HTTP Polling | `ChildEnrollmentController.dart:73-78` | **15 seconds** | `_pollTimer` polling approval status of child enrollment. |
| **Pairing Requests Poller** | Deterministic HTTP Polling | `PairingRequestsController.dart:49-54` | **20 seconds** | `_pollTimer` refreshing pending family invitations. |
| **Pairing Invite Redemption** | Deterministic HTTP Polling | `PairingRedeemController.dart:163-168` | **10 seconds** | `_statusPollTimer` checking status of invite code. |
| **Policy ACK Verification** | Polling Loop with Exit Cap | `ScreenTimeController.dart:432-459` | **5 seconds (Max 30s cap)** | Polls `device_policies` to verify device acknowledged policy update. |
| **App Restriction ACK** | Polling Loop with Exit Cap | `AppRestrictionsController.dart:629-657`| **5 seconds (Max 30s cap)** | Polls `device_policies` to confirm package suspensions. |
| **Child Command Execution** | Native Foreground Daemon Polling | `GuardianService.kt:260-277, 360-372`| **20 seconds** | Background HTTP loop polling `device-command` Edge Function. |
| **Child Scheduled Heartbeat** | Native Foreground Service Ticker | `GuardianService.kt:279-281` | **300 seconds (5 min)** | Scheduled HTTP POST to `device-telemetry` (battery, charging, permissions). |
| **Child Location Stream** | Hardware GPS Ticker | `LocationTrackingService.kt:180-210` | **60 seconds** | Uploads GPS fix coordinates to PostgREST. |
| **Device Presence Calculation** | State Calculation from Heartbeat | `device_presentation.dart:18-35` | On Data Load | Evaluates `devices.last_seen_at`: `<12m` = Online, `12-30m` = Stalled, `>30m` = Offline. |
| **Offline Detection Alerting**| Database Cron Worker | `supabase/functions/cron/index.ts` | **Periodic Cron** | Runs `private.detect_offline_devices()` flagging devices unseen > 15m. |

### 2.4 Resolution of Contradiction 2
The system is fundamentally a **hybrid command-and-control polling architecture** supplemented by WebSocket streams strictly for low-latency interactive workflows (safety alerts and WebRTC session negotiation). It does not maintain an open realtime WebSocket backplane for device presence or command delivery.

---

## 3. Contradiction 3: Policy `enforcement_status = 'enforced'` vs Native Reality

### 3.1 The Contradiction
- In Scenario RT-05, after the Parent bumped the screen-time limit to 1h 30m and saved the policy, the Parent UI displayed:
  - `Screen-time policy`
  - `Enforced on device` (Green Shield)
  - `Policy v2 acknowledged by the device`
- But on the physical Child device (Android 12 Realme RMX2161):
  - `adb shell dpm list-owners` returned **empty** (no Device Owner provisioned).
  - Child Rules screen displayed Defect E-6: *"Daily screen-time limits and bedtime are shown for information only. This Android build enforces app blocks and their schedules, not a system-wide time limit."*
  - Child Rules card displayed Defect E-7: Header chip displayed `Enforced on device`, while the banner directly above warned: *"Not enforceable on this phone. This phone is not a Device Owner, so the app cannot suspend other apps."*

### 3.2 Root Cause Analysis in Code

#### A. Native Execution in `PolicyApplier.kt`
In `android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt`:
1. `isDeviceOwner()` is evaluated via `devicePolicyManager.isDeviceOwnerApp(context.packageName)` (lines 333–338). On the test device, this is `false`.
2. Lines 135–144:
   ```kotlin
   if (desiredCount > 0 && !isOwner) {
       errors.add("Device Owner provisioning is required to suspend apps on this device. No apps were suspended.")
       unsupported.addAll(appDesired)
   } else if (isOwner) {
       ...
       suspendCallSucceeded = suspendPackages(toSuspend, errors)
   }
   ```
3. If no explicit app packages are configured for suspension (i.e. only Daily Limit or Bedtime is set), `desiredCount == 0`.
4. Lines 223–226:
   ```kotlin
   success = errors.isEmpty() && (desiredCount == 0 || (enforcementSupported && appliedCount == desiredCount))
   ```
   When `desiredCount == 0`, `success = true`, `desiredCount = 0`, `appliedCount = 0`, and `errors` is empty!
5. In `GuardianService.kt:407-409`:
   ```kotlin
   result = applier.apply(policy, version)
   val success = result.optBoolean("success", false)
   status = if (success) "succeeded" else "failed"
   ```
   `GuardianService` marks the command execution status as `"succeeded"`.

#### B. Backend Enforcement Decision (`enforcement.ts`)
In `supabase/functions/device-command/enforcement.ts`:
- Lines 355–360:
  ```typescript
  // Zero desired and a policy that does not target apps: there is nothing to
  // suspend, and Device Owner is confirmed, so the version is applied.
  return {
    ...base,
    status: "enforced",
    lastError: null,
    advancePolicyVersion: true,
  };
  ```
- Lines 421–424: In `decideQuotaEnforcement`, when a daily limit is configured but the current usage has not reached the threshold (`!quota.limit_reached`), if `quota.enforcement_supported` is evaluated or if app enforcement succeeded, `enforcement_status` is written to `device_policies` as `'enforced'`!

#### C. Database Write & Version Advancement (`handler.ts`)
In `supabase/functions/device-command/handler.ts:398-424`:
```typescript
await db.from("device_policies").update({
  acknowledged_at: nowIso,
  enforcement_status: decision.status, // "enforced"
  last_error: decision.lastError,
}).eq("id", policyId);

if (decision.advancePolicyVersion) {
  await db.from("devices").update({ policy_version: appliedVersion }).eq("id", device.id);
}
```

### 3.3 Resolution of Contradiction 3
`enforcement_status = 'enforced'` in PostgreSQL is a **protocol-level acknowledgment state**, not an operating-system-level confirmation of package suspension. 

- **What `enforced` Actually Means:** The child device successfully downloaded the policy payload via `GuardianService`, parsed the configuration, stored it in `SecureStore`, verified that zero app-blocking errors occurred (because 0 packages were targeted), and posted an acknowledgment payload back to the Edge Function.
- **What `enforced` Does NOT Mean:** It does not mean Android OS suspended any applications or that Android OS is enforcing system-level screen-time limits. On a non-Device Owner phone (`dpm list-owners` empty), package suspension is impossible, and limits remain purely informational.
- **The Defect:** Presenting `enforcement_status = 'enforced'` in the UI with a shield badge and the text "Enforced on device" misleads parents into believing that Android OS is actively restricting their child's screen time.

---

## 4. Contradiction 4: Parent Permission Snapshot Staleness (Defect E-3)

### 4.1 The Contradiction
The Parent Device Detail view (`/parent/devices/detail`) presents six permission status tiles:
- Usage access: `Granted`
- Location: `Granted`
- Background location: `Granted`
- Camera: `Granted`
- Microphone: `Granted`
- Notifications: `Granted`

The audit investigated whether these status chips represent live, real-time queries to the child device or cached database snapshots that become stale.

### 4.2 Code Analysis of Data Ingestion & Presentation

#### A. UI Presentation (`device_detail_page.dart`)
In `lib/features/devices/device_detail_page.dart:321-357`:
```dart
Widget _buildPermissionsCard(Device device) {
  return SectionCard(
    title: 'Device permissions',
    subtitle: 'Reported by the child device. Unknown means it has not reported.',
    child: Column(
      children: [
        PermissionStatusTile(title: 'Usage access', granted: device.usageAccessGranted ?? false),
        PermissionStatusTile(title: 'Location', granted: device.locationGranted ?? false),
        PermissionStatusTile(title: 'Background location', granted: device.backgroundLocationGranted ?? false),
        PermissionStatusTile(title: 'Camera', granted: device.cameraGranted ?? false),
        PermissionStatusTile(title: 'Microphone', granted: device.microphoneGranted ?? false),
        PermissionStatusTile(title: 'Notifications', granted: device.notificationsGranted ?? false),
      ],
    ),
  );
}
```
All six status indicators read directly from properties on the `Device` model (`device.dart:463-468`), which deserialize columns on the `public.devices` PostgreSQL table.

#### B. Database Ingestion (`device-telemetry/index.ts`)
In `supabase/functions/device-telemetry/index.ts:96-118`:
```typescript
const permissionMap: Array<[string, string]> = [
  ["usage_access_granted", "usage_access_granted"],
  ["location_granted", "location_granted"],
  ["background_location_granted", "background_location_granted"],
  ["camera_granted", "camera_granted"],
  ["microphone_granted", "microphone_granted"],
  ["notifications_granted", "notifications_granted"],
];
for (const [field, column] of permissionMap) {
  const value = readOptionalBoolean(capabilities[field], `capabilities.${field}`);
  if (value !== undefined) patch[column] = value;
}
await db.from("devices").update(patch).eq("id", device.id);
```
These database columns are updated **only** when the child device transmits its periodic telemetry heartbeat (`GuardianService.kt:279-281`, interval: **300 seconds / 5 minutes**).

### 4.3 Defect E-3 Verification & Impact
1. **No Live Push or Query:** The Parent client does not query the Child device when opening the Device Detail page; it performs a standard PostgREST `select` on `devices`.
2. **Permanent Staleness Under Disconnection:** If the physical phone runs out of battery, loses network connectivity, is killed by OEM battery management (Defect E-9), or if permissions are manually revoked by the child in Android OS Settings (`Settings > Apps > Parent Control > Permissions`), the database columns remain unchanged.
3. **UI Misrepresentation:** The Parent UI continues to display all six permissions as "Granted" indefinitely. The screen provides **no staleness indicator**, **no last-verified timestamp**, and **no warning** that the data may be days or weeks out of date if the device is currently offline.

---

## 5. Contradiction 5: Device Credential Integrity & Reinstallation (Defect E-1)

### 5.1 The Contradiction
The audit identified Defect E-1 regarding what happens when the Child application is uninstalled and reinstalled, or when its application storage is cleared.

### 5.2 Forensic Trace of the Failure Mechanism

#### A. Local Credential Generation (`SecureStore.kt`)
In `android/app/src/main/kotlin/com/parentcontrol/parent_control/SecureStore.kt:71-105`:
```kotlin
init {
    val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()
    prefs = EncryptedSharedPreferences.create(
        context,
        FILE_NAME,
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )
}

fun deviceSecret(): String {
    val existing = prefs.getString(KEY_DEVICE_SECRET, null)
    if (!existing.isNullOrBlank()) return existing
    val bytes = ByteArray(32)
    SecureRandom().nextBytes(bytes)
    val created = Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    prefs.edit().putString(KEY_DEVICE_SECRET, created).apply()
    return created
}
```
1. `SecureStore` relies on Android `EncryptedSharedPreferences` backed by the Android Keystore system.
2. When the user uninstalls the app or executes `pm clear com.parentcontrol.parent_control`, Android wipes the shared preferences XML file and invalidates the Keystore encryption keys.
3. Upon reinstall, `prefs.getString(KEY_DEVICE_SECRET, null)` returns `null`.
4. `SecureStore` generates a **brand-new random 32-byte secret** and a new `installation_id`.

#### B. Server-Side Authentication Verification (`auth.ts`)
In `supabase/functions/_shared/auth.ts:281-328`:
```typescript
export async function requireDevice(req: Request, db: SupabaseClient): Promise<DeviceRow> {
  const deviceId = req.headers.get("x-device-id") ?? "";
  const secret = req.headers.get("x-device-secret") ?? "";
  ...
  const { data: device } = await db.from("devices").select("*").eq("id", deviceId).maybeSingle();
  const digest = await sha256Hex(secret);
  
  if (!device || !device.secret_hash) {
    throw new ApiError("invalid_device_credentials", "Device credentials are not valid.", 401);
  }
  if (!constantTimeEqualHex(digest, device.secret_hash)) {
    throw new ApiError("invalid_device_credentials", "Device credentials are not valid.", 401);
  }
  ...
}
```

#### C. The Resulting Lockout & Database Orphan
1. The PostgreSQL `devices` table stores `secret_hash = sha256(original_device_secret)`.
2. When the reinstalled child app attempts to poll for commands or report telemetry using the newly generated secret, `constantTimeEqualHex` fails.
3. The server immediately returns **HTTP 401 Unauthorized** (`invalid_device_credentials`).
4. **Database Record State:** The `devices` row is **never modified or revoked** by this error; it remains in `status = 'active'` with the old `secret_hash`.
5. **Parent Presentation:** The Parent dashboard continues to show the existing device card.
6. **Child Deadlock:** The child device cannot sync, cannot report heartbeat telemetry, cannot receive policies, and cannot initiate WebRTC sessions. The only recovery path is for the Parent to manually revoke/delete the device from the dashboard and execute a fresh enrollment/pairing flow.

---

## 6. Contradiction 7: Latency & Performance Measurements

### 6.1 The Contradiction
The audit report (`LIVE_TWO_DEVICE_TEST_REPORT.md` Section 5) recorded precise latency metrics:
- Parent Policy Push: **14.8 seconds**
- Command ACK Return: **2.5 seconds**
- Safety Alert Trigger & Ack: **920 ms / 850 ms**
- Assistance Request Propagation: **13.7 seconds**
- Assistance Consent Push: **1.4 seconds**
- Live Audio RTP Latency: **~45 ms**
- Network Reconnection Recovery: **2.8 seconds**

The verification objective is to determine whether these figures represent single-point empirical measurements, statistical rolling averages, or theoretical network RTT calculations.

### 6.2 Forensic Analysis of Timing Evidence

#### A. Policy Push: 14.8 Seconds
- **Originating Code:** `ScreenTimeController.dart:400-459` (Parent taps save -> Edge Function `device-policy` -> inserts into `device_commands`).
- **Consuming Code:** `GuardianService.kt:260-277` (`sync_tick` polling `device-command` every **20 seconds**).
- **Logcat & Report Timestamps:**
  - Save tapped: `15:29:11`
  - Command processed & ACK returned: `15:29:26` (delta: ~15 seconds).
- **Nature of Figure:** **Single-point empirical measurement.** Because the child polls every 20 seconds, the propagation delay is a discrete uniform random variable between 0 and 20 seconds ($\mathcal{U}[0, 20]$). A measurement of 14.8 seconds reflects the exact timing offset of that specific test execution.

#### B. Assistance Request Propagation: 13.7 Seconds
- **Originating Code:** `RemoteSessionController.dart:820-845` (Parent initiates audio request -> inserts row in `remote_sessions`).
- **Consuming Code:** `ChildRequestsController.dart:43-48` (`pollInterval = const Duration(seconds: 15)`).
- **Logcat & Report Timestamps:**
  - Parent initiated: `16:20:33`
  - Child badge appeared: `16:20:46.7` (delta: 13.7 seconds).
- **Nature of Figure:** **Single-point empirical measurement.** The child was running a 15-second polling loop; the parent request arrived ~1.3 seconds into the 15-second window, resulting in a 13.7-second delay before the next poll tick retrieved it.

#### C. Safety Alert Acknowledgment: 920 Milliseconds
- **Originating Code:** Parent taps `Acknowledge` in UI -> Edge Function `family-admin` (`ack_alert`) -> PostgreSQL updates `acknowledged_at` on `safety_alerts`.
- **Consuming Code:** Supabase Realtime WebSocket subscription (`SupabaseAlertRepository.dart:60-143`) on `safety_alerts` receives `UPDATE` event -> pushes to `SafetyAlertsController.dart` -> updates `RxList`.
- **Nature of Figure:** **Single-point empirical measurement** of the end-to-end WebSocket push and UI repaint latency.

#### D. Live Audio RTP Flow: ~45 Milliseconds
- **Mechanism:** WebRTC P2P direct socket communication between physical phone and emulator on local Wi-Fi subnet.
- **Nature of Figure:** **Calculated network transit and jitter buffer estimate**, derived from libwebrtc audio track pacing (20ms audio frame packets) and standard local LAN transmission.

### 6.3 Comprehensive Classification Table of Latency Metrics

| Vector | Reported Timing | Classification | Underlying Mechanism Governing Time |
|---|---|---|---|
| **Policy Push** | 14.8 s | Single-Point Empirical | Child `GuardianService` 20s command poll loop. |
| **Command ACK** | 2.5 s | Single-Point Empirical | Parent `ScreenTimeController` 5s ACK poll tick. |
| **Alert Trigger** | 920 ms | Single-Point Empirical | Postgres Realtime WebSocket push. |
| **Alert Ack** | 850 ms | Single-Point Empirical | Edge Function RPC + Postgres Realtime push. |
| **Assistance Request** | 13.7 s | Single-Point Empirical | Child `ChildRequestsController` 15s poll timer. |
| **Assistance Consent** | 1.4 s | Single-Point Empirical | Postgres Realtime WebSocket row update. |
| **Live Audio Transit** | ~45 ms | Network P2P Estimation | WebRTC UDP LAN streaming (20ms audio frames). |
| **Assistance Teardown**| 890 ms | Single-Point Empirical | Supabase Realtime status push + FGS cancellation. |
| **Network Reconnect** | 2.8 s | Single-Point Empirical | Android `ConnectivityManager` + StreamController resume. |

---

## 7. Synthesis & Definitive Matrix of Claims vs Reality

| Contradiction / Claim | Stated Audit Claim | Verified Physical / Native Reality | Definitive Architectural Verdict |
|---|---|---|---|
| **1. WebRTC Direction** | "Two-way interactive WebRTC audio" | Parent receives audio; Child captures audio. Parent logs: `out 0 pkts / 0 B`. Parent never acquires `RECORD_AUDIO`. | **STRICTLY UNIDIRECTIONAL (Child -> Parent)**. Parent is a loudspeaker sink. |
| **2. Realtime vs Polling** | Realtime architecture for full app | Exactly 3 Realtime WebSocket channels exist. All presence, device listing, and policy sync use 15s–60s polling or 300s telemetry. | **HYBRID ARCHITECTURE**. Interactive sessions use WebSockets; background operations use polling. |
| **3. Policy Enforcement** | `enforced` = active OS app restrictions | `PolicyApplier.kt` cannot suspend apps (`dpm list-owners` is empty). Limits are advisory. | **PROTOCOL ACK ONLY**. Indicates command receipt, not Android OS package suspension. |
| **4. Permission Staleness** | Parent shows live permission status | Parent displays cached `devices.capabilities` columns updated only on 300s heartbeats. Stale indefinitely when offline. | **VERIFIED DEFECT (E-3)**. Freeze-frame display lacking staleness indicators. |
| **5. Credential Reinstall** | Child device seamlessly reconnects | `SecureStore.kt` wipes encryption keys on reinstall. New secret causes permanent HTTP 401 lockout. | **VERIFIED DEFECT (E-1)**. Device orphaned until manual parent re-enrollment. |
| **6. Latency Metrics** | General performance benchmarks | Precise timestamps from single live test executions. Governed by 15s/20s poll loop phase offsets. | **DISCRETE TEST MEASUREMENTS**. Empirical single-point timings, not statistical averages. |

---

## 8. Conclusion

All six critical contradictions and claims have been verified against the production codebase and empirical live test artifacts:
1. WebRTC audio is **strictly one-way** (Child microphone to Parent loudspeaker).
2. The real-time surface is **strictly limited to three table channels**; the operational backbone is deterministic HTTP polling.
3. Policy status **`enforced` does not signify native OS suspension** on non-Device Owner devices.
4. Permission snapshots are **frozen database columns** that do not reflect live child permission revoking while offline.
5. Child app reinstallation **permanently breaks device authentication** without backend record cleanup.
6. Latency figures are **discrete empirical samples** directly tied to the application's polling timers.
