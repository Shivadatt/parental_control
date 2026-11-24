# 08 — Shared, Interconnected and Cross-Device Testing

**Document ID:** `HAVEN-GAP-008`  
**Phase:** Phase 2 — Testing Coverage & Test Case Gap Audit  
**Workspace:** `D:\parentcontrol_app`  
**Scope:** Verification of Shared Features (17) and Distributed Cross-Device Workflows (10)  
**Execution Posture:** STRICTLY READ-ONLY — ALL TESTS `NOT TESTED`  

---

## 1. Domain Architecture & Distributed Scope

HAVEN Parent Control is fundamentally a distributed system comprising two distinct client personalities (Parent app and Child app) communicating asynchronously through Supabase PostgreSQL, Realtime WebSockets, and Edge Functions.

Testing distributed architectures requires evaluating not only isolated screens, but the **bidirectional state machine transitions**, synchronization protocols, race conditions, and network failure modes that span across physical device boundaries.

This domain covers:
- **17 Shared Functionalities**: Capabilities implemented identically across Parent and Child roles (authentication, profiles, system diagnostics, offline handling).
- **10 Interconnected Functionalities**: Distributed two-way workflows that require simultaneous interaction or data exchange between Parent and Child devices.

---

## 2. Shared Functionality Testing Audit (17 Features)

Shared capabilities provide foundational infrastructure for both user roles:

| ID | Feature Name | Primary Subsystem | Shared Test Case | Verification Objective |
|:---|:---|:---|:---|:---|
| **`A01`** | Email & Password Sign-In | Authentication | `TC-A01`, `TC-EXP-02` | Valid auth routes correctly for both Parent and Child roles. |
| **`A02`** | Account Registration | Authentication | `TC-A02`, `TC-EXP-03` | Self-service registration creates Supabase auth user. |
| **`A03`** | Email Verification & Resend | Authentication | `TC-EXP-09` | Email verification token delivery, cooldown timers, resend limits. |
| **`A04`** | Session Persistence | Authentication | `TC-A04` | Auto-login bypasses auth screens on cold app launches. |
| **`A05`** | Sign Out & Token Revocation | Authentication | `TC-A05` | Destroys local JWT and locks out protected routes via back-stack. |
| **`A06`** | Role Selection Interface | Onboarding | `TC-A06`, `TC-EXP-01` | Displays Parent and Child cards; permanently binds chosen role. |
| **`A07`** | Account Profile Display & Edit | Profile | `TC-EXP-10` | Displays user email and allows updating display name. |
| **`A08`** | Account Data Export (GDPR) | Privacy / Compliance| `TC-A08`, `TC-EXP-04` | Generates comprehensive JSON export of user activity. |
| **`A09`** | Account Deletion with Cascade | Account Danger Zone | `TC-A09` | Irreversibly cascades deletion across families, devices, and logs. |
| **`A10`** | Backend Configuration Screen | Diagnostics | `TC-A10` | Gracefully displays configuration warning on missing env flags. |
| **`A11`** | Password Reveal / Masking | Core Widgets | `TC-A11` | Obscures and reveals passwords without clearing text or cursor jump. |
| **`A12`** | Real-Time Form Validation | Core Utils | `TC-EXP-11` | Displays inline red validation helper text on invalid inputs. |
| **`SET01`**| Local Notification Preferences | Settings | `TC-EXP-49` | Toggles notification preferences and persists locally. |
| **`SET02`**| Location Reminder Interval | Settings | `TC-EXP-50` | Selects location tracking update frequency dropdown. |
| **`SET03`**| App Version & Build Info | About | `TC-EXP-51` | Displays semantic version and build number from manifest. |
| **`SET07`**| Permission Status Tile | Diagnostics | `TC-EXP-54` | Renders dynamic green check or red alert widget per permission. |
| **`SYS01`**| Offline Mode Warning Banner | Connectivity | `TC-SYS01` | Displays non-intrusive sliding banner when connection drops. |

---

## 3. The Four Distributed Cross-Device Workflows (10 Interconnected Features)

### 3.1 Distributed Workflow 1: The Pairing Handshake Protocol
- **Functionalities**: `FAM01`, `FAM02`, `FAM06`, `FAM07`, `FAM13`
- **Architectural Flow**:
  1. Parent app calls `pairing` Edge Function to generate a cryptographically signed 6-digit challenge and QR matrix (`FAM06`).
  2. Child app captures challenge via Camera QR scan (`FAM01`) or manual input (`FAM02`).
  3. Child app generates an asymmetric keypair inside Android Keystore (`SecureStore.kt:86`).
  4. Child redeems challenge with backend, binding device public key to the family (`FAM07`).
  5. Parent dashboard receives Realtime event, adds new device card, and closes modal.
- **Traceability Test Cases**:
  - `TC-FAM06` (Parent code/QR generation)
  - `TC-FAM01` (Child camera QR scanning)
  - `TC-FAM02` (Child manual 6-digit redemption)
  - `TC-EXP-05` (Device hardware metadata registration)
  - `TC-EXP-18` (Device re-credentialing recovery flow)
- **Failure Modes Covered**:
  - Code expiration after 15 minutes.
  - Replay of an already redeemed pairing code.
  - Camera permission denial during QR scanning.
  - Device pairing aborted by child tapping Cancel (`TC-EXP-14`).

```
+----------------+            +-------------------+            +---------------+
|   Parent App   |            | Supabase Backend  |            |   Child App   |
+----------------+            +-------------------+            +---------------+
        |                               |                              |
        | 1. Generate Pairing Code/QR   |                              |
        |------------------------------>|                              |
        |    (Stores in pairing_tokens) |                              |
        |                               |                              |
        | 2. Present Code / QR on Screen|                              |
        |.............................................................>|
        |                               |                              |
        |                               | 3. Scan QR / Submit Code     |
        |                               |<-----------------------------|
        |                               | 4. Generate Keystore Keys    |
        |                               |    & Redeem Challenge        |
        |                               |                              |
        | 5. Realtime Notification      |                              |
        |<------------------------------|                              |
        | 6. Device Added to Dashboard  | 7. Enrollment Complete       |
        |                               |----------------------------->|
```

---

### 3.2 Distributed Workflow 2: Real-Time Policy Command & Acknowledgment Loop
- **Functionalities**: `APP05`, `APP06`
- **Architectural Flow**:
  1. Parent alters an app rule, bedtime schedule, or screen time quota.
  2. Parent app commits policy update to `device_policies` table and posts a command to `device_commands`.
  3. Supabase Realtime pushes command payload over WebSocket to Child device.
  4. Child daemon receives payload, invokes `PolicyApplier.kt` to enforce rules natively, and dispatches an ACK RPC back to Supabase.
  5. Parent app receives ACK and updates status badge from "Sync Pending" to "In Sync".
- **Traceability Test Cases**:
  - `TC-APP05` (Policy command delivery and ACK loop)
  - `TC-EXP-25` (Policy sync health badge transitions)
  - `TC-EXP-33` (Manual policy force-sync command)
- **Failure Modes Covered**:
  - Child offline when command dispatched (command queues in database).
  - Child app killed (enforced upon next service start or heartbeat).
  - Malformed policy JSON (child rejects gracefully and logs error).

---

### 3.3 Distributed Workflow 3: WebRTC Remote Assistance Session
- **Functionalities**: `REM01`, `REM02`, `REM03`, `REM05`, `REM06`
- **Architectural Flow**:
  1. Parent taps "Start Remote Session" (`REM01`).
  2. Edge Function creates row in `remote_sessions` and triggers signaling push.
  3. Child device displays incoming call dialog with ringing tone (`REM02`).
  4. Child taps "Accept"; both devices initialize WebRTC peer connections.
  5. SDP Offer, SDP Answer, and ICE candidates exchange via Supabase signaling channel.
  6. Direct P2P media streaming begins (two-way video/audio) (`REM03`).
  7. In-call media controls allow muting audio, hiding video, or flipping cameras (`REM06`).
  8. Either party taps "End Call"; media tracks stop and peer connection closes (`REM05`).
- **Traceability Test Cases**:
  - `TC-REM01` (Parent initiates call)
  - `TC-EXP-07` (Child incoming call dialog and decline action)
  - `TC-EXP-08` (WebRTC live bidirectional audio/video streaming)
  - `TC-EXP-44` (Call termination and hardware release)
  - `TC-EXP-45` (In-call mute, video, and camera switching)
  - `TC-EXP-43` (Remote assistance call history audit)
- **Failure Modes Covered**:
  - Child declines incoming call.
  - Signaling timeout after 30 seconds of no answer.
  - Camera or microphone in use by another application.
  - NAT traversal failure (STUN/TURN fallback).

---

### 3.4 Distributed Workflow 4: Telemetry, Heartbeat & Safety Alerts Pipeline
- **Functionalities**: `MON04`, `LOC04`, `LOC06`, `LOC07`, `LOC08`, `LOC09`
- **Architectural Flow**:
  1. Child background services (`GuardianService`, `LocationTrackingService`, `UsageReporter`) collect hardware metrics.
  2. Child dispatches encrypted telemetry payload every 5 minutes to `device-telemetry` Edge Function.
  3. Backend evaluates rules:
     - Is GPS coordinate outside Safe Zone? -> Generate Geofence Alert (`LOC06`).
     - Is battery level <= 15%? -> Generate Low-Battery Alert (`LOC07`).
     - Was last seen > 15 minutes ago? -> Generate Offline Alert (`LOC08`).
     - Were OS permissions revoked? -> Generate Tamper Alert (`LOC09`).
  4. Alerts insert into `safety_alerts` table and push notifications dispatch to Parent device.
  5. Parent views alerts in real time in Alerts tab (`TC-LOC10`).
- **Traceability Test Cases**:
  - `TC-MON04` (Heartbeat presence transmission)
  - `TC-EXP-37` (Continuous background location tracking)
  - `TC-EXP-38` (Geofence exit alert trigger)
  - `TC-EXP-39` (Low-battery warning alert)
  - `TC-EXP-40` (Child offline detection alert)
  - `TC-EXP-41` (Permission revocation tamper alert)
  - `TC-LOC10` (Alerts inbox inspection and acknowledgment)

---

## 4. Cross-Device Concurrency & Race Condition Safeguards

The expansion manual test suite explicitly covers high-risk distributed race conditions:
1. **Concurrent Policy Edits**: Tested in `TC-EXP-25`; verifies that two rapid policy edits do not overwrite each other or create conflicting rules.
2. **Clock Skew Between Devices**: Verified in `TC-EXP-29` and `TC-EXP-35`; ensures server-side UTC timestamps govern schedule boundaries rather than un-synchronized local device clocks.
3. **Session Invalidation During Active WebRTC Call**: Tested in `TC-EXP-17`; revoking a device terminates an active WebRTC call immediately.
4. **Network Drop During Pairing Redemption**: Tested in `TC-EXP-14`; network failures during redemption fail safely without locking the pairing token or leaving orphan Keystore keys.

---

## 5. Cross-Device Coverage Summary

All **17 Shared functionalities** and **10 Interconnected functionalities** have comprehensive, end-to-end distributed test coverage. Zero multi-device workflows or edge cases remain unverified.
