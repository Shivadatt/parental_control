# Phase 7 — Android Controlled QA Gate & Execution Evaluation Report

**Workstream:** Workstream D (Android Controlled QA Gate & Execution Evaluation)  
**Document:** `docs/implementation/phase-7-android-qa-report.md`  
**Phase:** Phase 7  
**Date:** 2026-11-04  
**Author / Evaluator:** Subagent 7 (Android Controlled QA Gate & Execution Evaluator)  
**Coordinator / Caller ID:** `e0d3326c-5a13-4314-b902-7ea17d798c30`  
**Repository & Working Directory:** `D:\parentcontrol_app`  
**QA Gate Status:** **STOPPED / AWAITING OWNER APPROVAL DEC-03**  
**Execution Verdict:** **75 / 75 Rows Strictly NOT RUN**  
**Grounding Documents:** `docs/implementation/phase-6-qa-readiness.md`, `docs/implementation/phase-6-owner-decision-register.md`, `docs/implementation/phase-5-owner-decision-log.md` (Ruling #9), `docs/stage6_account_and_media_recovery_report.md`

---

## 1. Executive Summary & Gate Evaluation Verdict

### 1.1 Owner Decision Gate DEC-03 Evaluation
In accordance with project governance rules and Workstream D responsibilities, the status of **Owner Decision DEC-03** (*AND-01 / GATE-B-01 Android Device Execution Authorization*) was evaluated:

> **Core Governance Rule:**  
> *"Do not infer approval from a previous implementation or a report recommendation. Approval must be explicit, active, and unambiguous. If approval is ambiguous or absent, STOP."*

#### Factual Governance Findings:
1. **Ruling #9 Still Active:** In the Phase 5 Owner Decision Log (`docs/implementation/phase-5-owner-decision-log.md:Ruling #9`), Gate B / AND-01 device execution was **explicitly refused** by the repository owner.
2. **DEC-03 Pending in Register:** In the Phase 6 Owner Decision Register (`docs/implementation/phase-6-owner-decision-register.md:324`), DEC-03 is formally recorded as:
   - **Severity:** P1 (Release Blocker)
   - **Current State:** *"Zero physical device execution. 75-row validation matrix is 100% unrun."*
   - **Required Owner Action:** Awaiting explicit owner ruling between Option A (Authorize high-risk subset), Option B (Authorize full 75-row matrix), or Option C (Defer device execution).
3. **No Explicit Authorization Granted:** No active, written owner instruction authoring DEC-03 has been issued entering Phase 7.
4. **Mandatory Gate Enforcement:** Because DEC-03 is **NOT authorized**, the controlled QA execution gate is **IMMEDIATELY ENFORCED AND STOPPED**.

### 1.2 Strict Negative Constraints Enforced
Under the mandatory gate enforcement, this workstream has strictly complied with the 10 negative operational boundaries:
1. **NO APK build for device testing:** Zero debug, release, or QA APK packages were compiled (`flutter build apk` and `./gradlew assembleDebug` were NOT run).
2. **NO APK installation:** No package was installed or updated on physical hardware or emulators (`adb install` was NOT executed).
3. **NO ADB execution against devices:** Zero interactive, shell, or push ADB commands were targeted at QA hardware.
4. **NO microphone capture:** No microphone audio hardware was initialized, recorded, or streamed.
5. **NO device-owner policy manipulation:** No device administration, profile owner, or enterprise policies were modified.
6. **NO permission manipulation:** No runtime permissions (`RECORD_AUDIO`, `POST_NOTIFICATIONS`, `SYSTEM_ALERT_WINDOW`, etc.) were granted, revoked, or spoofed.
7. **NO notification channel manipulation:** No OS notification channels or importance levels were altered.
8. **NO real device pairing or unpairing:** No pairing requests, approval handshakes, or device unlinks were dispatched on devices.
9. **NO matrix row execution:** Not a single test row was executed on hardware.
10. **Zero Fabricated Status:** In compliance with honest status discipline, **all 75 test rows** carry `Actual Result = NOT RUN` and `Status = NOT RUN`.

---

## 2. Hardware Reality & Connection Preflight

### 2.1 Target Device Architecture & Mapping

The project test architecture defines two fixed physical/virtual roles. These roles are non-interchangeable:

| Parameter | Parent Device (Monitor) | Child Device (Monitored) |
|---|---|---|
| **Role** | Primary Parent Monitor / Receive-Only Audio Client | Monitored Child / Guardian Service / Audio Sender |
| **Device Model** | Android Emulator (`sdk_gphone64_x86_64` / Pixel 9a AVD) | Realme 7 (`RMX2161`) |
| **Serial / Identifier** | `emulator-5554` | `5HXWRGQ4IFU8WS4T` |
| **Operating System** | Android 17 (API 37) | Android 12 (API 31, ColorOS 12.1) |
| **ABI Architecture** | `x86_64` | `arm64-v8a` |
| **Microphone Capability** | Receive & playback only (Upstream capture forbidden) | Capture & WebRTC stream via `AudioAssistanceService` |
| **Notification Behavior** | Standard Android 17 notification management | ColorOS custom shade; channel importance `NONE` edge case |

### 2.2 Connection Preflight Status
A safe check for ADB execution capability was conducted:
- **Command:** `adb devices`
- **Result:** `adb` command is not available in the current sandboxed execution PATH.
- **Hardware Isolation:** Neither `emulator-5554` nor `5HXWRGQ4IFU8WS4T` is accessible in the sandboxed workspace.
- **Negative Boundary Adherence:** In compliance with negative constraints and absence of DEC-03, unsandboxed execution to force-detect or manipulate ADB was purposefully withheld.

### 2.3 Device Pairing Preflight Status
An audit of historical device pairing records (`docs/stage6_account_and_media_recovery_report.md:221-228`) establishes the following factual baseline:
- **Server Device Links:** All QA device rows in the database for the parent account are **`Revoked`** (last active October 2026).
- **Client Cache State:** The child physical device cached state indicates "Linked", but server-side queries reject requests due to revoked status.
- **Pairing Dependency:** No live audio assistance, device command dispatch, or policy correlation test can execute until a formal re-pairing ceremony (`pairing.invite` $\rightarrow$ `pairing.respond accept`) is authorized and conducted.
- **Pairing Ceremony Gating:** Re-pairing mutates account and device association state and must not be performed without explicit owner consent.

### 2.4 Account & Credential Topology
- **Parent Account:** QA Family A Parent (`PARENT_A_USER` / `PARENT_A_PASS` defined in `.tools/qa_accounts.env`).
- **Child Account:** `qa.child.a2.20261026@example.com` (`CHILD_A_USER` / `CHILD_A_PASS`).
- **Unverified Dashboard Accounts:** Accounts `ankit@gmail.com` and `ankit1@gmail.com` remain unverified and absent from repository test fixtures.
- **Credential Hygiene:** In accordance with repository security policy, zero passwords, Supabase keys, JWTs, or TURN secrets are exposed in this report.

---

## 3. Mandatory Privacy & Safety Invariants

Every row in the controlled QA matrix strictly adheres to the following 10 immutable privacy invariants. Any test execution, script, or application behavior that violates these invariants is **invalid by definition**:

1. **Invariant 1: No Hidden Microphone Capture**  
   The application must never activate, acquire, or stream microphone audio in the background without explicit, active child consent and truthful visual disclosure.
2. **Invariant 2: No Bypassing Android `RECORD_AUDIO` Permission**  
   The Android OS runtime permission dialog must be presented honestly. The app must never circumvent, mock, or exploit platform vulnerabilities to capture audio without an active user grant.
3. **Invariant 3: No Bypassing Foreground Service Microphone Restrictions**  
   The child app must strictly adhere to Android 11+ (API 30), Android 12+ (API 31), and Android 14+ (API 34) Foreground Service (FGS) restrictions. Audio capture must only occur while `AudioAssistanceService` is running with `foregroundServiceType="microphone"`.
4. **Invariant 4: No Suppressing Android Green Microphone Indicator**  
   The OS-level status bar privacy chip (green microphone dot/pill) is Android-owned. The app must never attempt to overlay, mask, hide, or delay this indicator.
5. **Invariant 5: No Suppressing Foreground Service Notifications**  
   `AudioAssistanceService` (ID 4303) must display an ongoing, non-dismissible notification. If an OEM channel configuration (such as Realme ColorOS importance `NONE`) suppresses the visual shade notification, the app UI must truthfully report that the shade notification is hidden and must not fabricate a "visible notification" state.
6. **Invariant 6: Child "Stop Sharing" Must Be Honoured Immediately**  
   The child retains absolute local revocation authority. Tapping "Stop sharing" must instantly tear down WebRTC media and terminate local microphone capture without requiring parent approval or backend round-trip confirmation.
7. **Invariant 7: Parent Is Receive-Only**  
   The parent device is strictly an audio receiver. The parent application must never capture, transmit, or route upstream parent audio to the child device.
8. **Invariant 8: Force-Stop / Process Death Must End Media**  
   Standard Android lifecycle termination (User Force Stop, OEM Task Killer, or Recents Swipe) ends media capture unconditionally. `AudioAssistanceService` must remain `START_NOT_STICKY` so that an OS kill does not spawn a zombie capture service.
9. **Invariant 9: No Zombie Microphone Session**  
   The background watchdog (15-second polling loop) and RTP capture heartbeat must ensure that if the server session ends, expires, or is abandoned, microphone capture halts automatically even if the child app is in the background.
10. **Invariant 10: No Silent Settings Modification**  
    The application must never silently modify device administration privileges, notification channel importances, OEM auto-start/battery optimization overrides, or lock-screen behavior.

---

## 4. Priority Execution Order & High-Risk Focus Areas

When Owner Decision DEC-03 is formally granted, execution must NOT proceed alphabetically. Instead, testing must strictly follow risk tiers, focusing first on high-risk safety, consent, and process lifecycle failure modes:

```mermaid
flowchart TD
    Tier1["Tier 1: Policy Correlation & Phrasing Safety<br/>ENF-02, ENF-03 (Wrong-Policy & Uncorrelated Attribution)"]
    Tier2["Tier 2: Session Lifetime & Premature Expiry<br/>NET-07 (30-Minute Accepted-Session Expiry / Defect F1)"]
    Tier3["Tier 3: OEM Process Death & Teardown<br/>LIFE-04, LIFE-05 (Realme Task-Kill & Process Force Stop)"]
    Tier4["Tier 4: Background Watchdog & Zombie Prevention<br/>SESS-07 (Parent-End Watchdog Termination within ≤15s)"]
    Tier5["Tier 5: Consent Gating & Signaling Security<br/>SESS-01, SESS-02, SESS-03 (Consent Gating & ICE 403)"]
    Tier6["Tier 6: OS Permission Revocation & Notification Gates<br/>PERM-01, PERM-04 (RECORD_AUDIO & POST_NOTIFICATIONS Revocation)"]
    Tier7["Tier 7: Full Matrix Sequential Execution<br/>Remaining 63 rows (AUTH, PAIR, PRES, CMD, ZONE, etc.)"]

    Tier1 --> Tier2 --> Tier3 --> Tier4 --> Tier5 --> Tier6 --> Tier7
```

### Detailed Justification of Prioritized Scenarios:

1. **ENF-02 & ENF-03 — Wrong-Policy & Uncorrelated Policy Attribution (P0):**
   - *Failure Mode:* A parent UI showing a green "Confirmed Suspended" badge for Policy v2 when the child device actually acknowledged Policy v1 or an empty policy ID.
   - *Verification Target:* Verify that correlation strictly enforces `payload.policy_id` matching, rejects mismatched versions, and displays the exact disclaimer: *"Device report not linked to this policy"*.
2. **NET-07 — Accepted-Session 30-Minute Expiry (Defect F1) (P0):**
   - *Failure Mode:* The deployed hosted backend (`remote-session`) stamps `expires_at = accepted_at + 30 min`. If migration `20261028000200` (nullable expiry) is absent, live audio terminates prematurely after 30 minutes while the UI still promises an indefinite session.
   - *Verification Target:* Prove whether the session survives past 30 minutes without unexpected server termination.
3. **LIFE-04 & LIFE-05 — Physical Realme Task-Kill & Process Force Stop (P0):**
   - *Failure Mode:* Realme ColorOS aggressively issues `signal 9` upon swiping from Recents, or the user force-stops the app in Android Settings.
   - *Verification Target:* Confirm immediate cessation of microphone recording clients (`dumpsys audio`), destruction of `AudioAssistanceService` without zombie respawn (`START_NOT_STICKY`), and preservation of session state for explicit rejoin.
4. **SESS-07 — Parent-End Watchdog Background Termination (P0):**
   - *Failure Mode:* Parent ends session while the child device is in the background with screen locked; teardown WebSocket message is dropped.
   - *Verification Target:* Confirm that the child background watchdog (15-second polling loop) detects server `ended` status and stops `AudioAssistanceService` and microphone capture within $\le 15$ seconds without child user interaction.
5. **SESS-01 to SESS-03 — Consent-Before-Microphone Access & ICE Gate (P0):**
   - *Failure Mode:* Premature acquisition of microphone audio or SDP/ICE candidate exchange before explicit child acceptance.
   - *Verification Target:* Verify that `remote_sessions.status` transitions strictly: `requested` $\rightarrow$ `consented` $\rightarrow$ `active`. Verify that calling the `ice` Edge Function prior to consent returns `403 Forbidden`.
6. **PERM-01 & PERM-04 — Runtime Permission Revocation & Notification Gating (P0):**
   - *Failure Mode:* User revokes `RECORD_AUDIO` or `POST_NOTIFICATIONS` in OS Settings while streaming.
   - *Verification Target:* Confirm immediate, graceful termination of capture without crash loops or zombie services. Verify that starting FGS without notification permission produces `notification_permission_required`.

---

## 5. Comprehensive 75-Row Controlled QA Matrix (All Rows NOT RUN)

### Risk Taxonomy
- **P0 (Critical / Blocker):** Privacy invariants, consent gating, zombie microphone prevention, process death teardown, wrong-policy correlation, safety regressions.
- **P1 (High):** Core functional workflows, session lifetime, command delivery/ack, pairing/unlinking integrity, audit logging.
- **P2 (Medium):** Transient network reconnection, presence sync degradation, safe zone CRUD, edge-case UI banners.
- **P3 (Low):** Minor display text phrasing, non-functional telemetry, cosmetic layout elements.

| Test ID | Feature | Preconditions | Parent Action | Child Action | Expected Result | Actual Result | Evidence Required | Risk Level | Status |
|---|---|---|---|---|---|---|---|---|---|
| **AUTH-01** | Parent Authentication | Parent emulator, no session, config compiled in, network active | Launch app; sign in as QA Family A parent; navigate to Home | None (idle) | Splash $\rightarrow$ Login $\rightarrow$ Home completes; shows family dashboard; no "Connect backend" error | NOT RUN | `AUTH-01-parent-home.png`, logcat filter | P1 | NOT RUN |
| **AUTH-02** | Child Authentication | Child physical device, clean state | None (idle) | Launch app; sign in as `qa.child.a2.20261026@example.com`; reach Home | Child Home restores signed-in profile; Requests tab accessible; account not switched | NOT RUN | `AUTH-02-child-home.png` | P1 | NOT RUN |
| **AUTH-03** | Family Role Setup | Unset-role account on parent emulator | Register new account; select parent role; submit family name | None | `set_role` succeeds on first call; `create_family` returns family row; parent role persisted | NOT RUN | Parent screenshot, read-only `profiles`, `families` | P2 | NOT RUN |
| **AUTH-04** | Role Immutability | Account from AUTH-03 with role already set | Attempt to change role to child via bootstrap endpoint | None | Second `set_role` rejected with `409 Conflict` (write-once); profile uncorrupted | NOT RUN | Edge log `auth-bootstrap` (409), screenshot | P1 | NOT RUN |
| **AUTH-05** | Email Verification Gate | Parent signed in with unverified email | Attempt to access restricted family controls | None | `requireUser` blocks action; displays email verification prompt; no family data leakage | NOT RUN | Parent UI screenshot, read-only `profiles` | P2 | NOT RUN |
| **AUTH-06** | Multi-Family Isolation | Child member of Family A only; Family B exists | None | Sign in; inspect family membership and notifications | Child sees Family A only; RLS blocks access to Family B data; no cross-family leakage | NOT RUN | Child UI screenshot, read-only `family_members` | P1 | NOT RUN |
| **PAIR-01** | Pairing Invite UI | Parent signed in; active family; no linked devices | Navigate to Devices tab $\rightarrow$ Tap "Invite child" | None | Child ID input displayed; accepts permanent `PC-XXXXXXXX` format | NOT RUN | `PAIR-01-parent-invite.png` | P2 | NOT RUN |
| **PAIR-02** | Permanent Child ID | Child signed in on Home screen | Inspect invite input | Open child app; locate displayed Child ID on Home | Child displays valid, permanent `PC-XXXXXXXX` ID matching server record | NOT RUN | Child UI screenshot | P2 | NOT RUN |
| **PAIR-03** | Auto Invite Delivery | Parent entered child's ID and sent invite | Tap "Send invite" | Wait up to 20 s on child Home without pulling to refresh | Pending invite appears automatically within 20 s (D1 fix); no manual refresh required | NOT RUN | Child screenshot ($<20$ s), read-only `pairing_requests` | P1 | NOT RUN |
| **PAIR-04** | Child Pairing Approval | Pending pairing invite on child | Observe Devices tab | Tap "Approve" on pairing request card | `pairing.respond` RPC succeeds; child linked to family; confirmation view shown | NOT RUN | Child screenshot, read-only `family_members`, `devices` | P0 | NOT RUN |
| **PAIR-05** | Parent Pairing Auto-Move | Child approved pairing; parent on Devices tab | Wait up to 60 s without manual refresh | None (approved) | Devices list auto-updates (D2); pairing card transitions to approved (D3) | NOT RUN | Two timestamped parent screenshots | P2 | NOT RUN |
| **PAIR-06** | Process Restart Persistence | Devices paired and linked; both apps closed | Force stop parent app; relaunch; sign in | Force stop child app; relaunch; sign in | Both devices restore linked status; no duplicate pairing prompt or duplicate invite row | NOT RUN | Screenshots both devices, read-only `pairing_requests` | P1 | NOT RUN |
| **PAIR-07** | Device Unlink Teardown | Active paired child device | Member settings $\rightarrow$ Tap "Unlink child" $\rightarrow$ Confirm | Observe child app state and active services | `pairing.unlink` RPC executes; child loses link; live sessions torn down; device status updated | NOT RUN | Parent screenshot, read-only `family_members.status='removed'` | P0 | NOT RUN |
| **PAIR-08** | Expired Invite Rejection | Pairing invite left untouched past `expires_at` | Observe invite status | Tap "Approve" on expired invite | Approval rejected; UI displays expiration notice; no partial membership created | NOT RUN | Child screenshot, read-only `pairing_requests` | P2 | NOT RUN |
| **PRES-01** | Presence Baseline | Linked child foreground, network active | Inspect Devices tab presence indicator | Keep app in foreground across $\ge 2$ heartbeat cycles (10 min) | Child shows "Online · Last seen ~1 min ago"; `devices.last_seen_at` advances regularly | NOT RUN | Parent screenshots, read-only `devices.last_seen_at` ($t_1, t_2$) | P1 | NOT RUN |
| **PRES-02** | Healthy Sync Status | Child `last_seen_at` $< 12$ min | Open device detail view | Send regular heartbeats | `syncHealth == healthy`; displays "synced N min ago"; no warning badges | NOT RUN | Parent UI screenshot | P2 | NOT RUN |
| **PRES-03** | Stalled Sync Degradation | Child `last_seen_at` between 12 and 30 min | Inspect device badge | Suspend child heartbeat for 15 min | Badge displays dedicated "Sync stalled" state; NOT marked as "Offline" | NOT RUN | Parent screenshot, read-only `devices` row | P2 | NOT RUN |
| **PRES-04** | Offline Sync Transition | Child `last_seen_at` $> 30$ min | Inspect device status badge | Keep child offline for $> 30$ min | Device marked "Offline"; stale "Session active" banner is NEVER shown without offline warning | NOT RUN | Parent screenshot, read-only `devices` row | P1 | NOT RUN |
| **PRES-05** | Never-Synced Device State | Device registered but `last_seen_at` IS NULL | Inspect device detail card | None (new device) | Displays "Never synced" — no NaN, no "0 min ago", no UI crash | NOT RUN | Parent device detail screenshot | P3 | NOT RUN |
| **PRES-06** | Heartbeat Freeze Detection | Guardian poll/heartbeat freeze simulated | Inspect presence over time | Freeze child heartbeat while FGS stays foreground | Presence transitions to stalled/offline honestly; FGS `isForeground=true` alone does not fake online | NOT RUN | Read-only `devices`, `dumpsys activity services`, child UI | P1 | NOT RUN |
| **CMD-01** | Atomic Policy Command | Parent updates app restriction policy | Toggle restricted apps $\rightarrow$ Tap "Save" | None (idle) | `apply_policy_version` creates `device_policies` row and `device_commands` row atomically | NOT RUN | Read-only `device_commands`, `device_policies` | P1 | NOT RUN |
| **CMD-02** | Command Delivery Status | Policy command queued; child online | None | GuardianService polls (20 s cycle) | Server marks command `delivered`; Guardian invokes `handleCommand` | NOT RUN | Read-only `device_commands.status='delivered'`, logcat | P1 | NOT RUN |
| **CMD-03** | Command Ack Structure | Delivered `apply_policy` command | None | Guardian executes policy and posts ack | Ack contains `{action, command_id, status, result}`; includes counts and enforcement mode | NOT RUN | Read-only `device_commands.result` JSON | P1 | NOT RUN |
| **CMD-04** | Unsupported Command Ack | Policy requires Device Owner; child lacks DO | Save app suspension policy | Device attempts suspension and fails | Child posts `failed` ack with reason; server marks policy `unsupported` (not `enforced`) | NOT RUN | Read-only `device_commands.status='failed'`, `device_policies` | P1 | NOT RUN |
| **CMD-05** | Background End Rejection | Queued `end_session` command; media inactive | Send `end_session` command | Guardian handles command | Guardian returns `failed` ack: media managed by visible screen only; no silent teardown | NOT RUN | Read-only failed ack, logcat | P1 | NOT RUN |
| **CMD-06** | Expired Command TTL | Short TTL command; child offline past expiry | Create command with TTL = 10 s | Connect child after 30 s | Guardian drops expired command; server status transitions to `expired` | NOT RUN | Read-only `device_commands.status='expired'` | P2 | NOT RUN |
| **CMD-07** | Command Idempotency | Command already processed by child | Re-send identical command | Receive duplicate command | Store checks handled set; drops duplicate execution; exactly one ack written | NOT RUN | Database query (1 command row, 1 ack) | P1 | NOT RUN |
| **ENF-01** | Matched Policy Correlation | Device ack matches current policy ID | Open policy in App Restrictions | None (already acked) | Correlation `matched`; green verified badge shown ONLY if applied == desired and failed == 0 | NOT RUN | UI screenshot, `device_commands.payload` vs `device_policies.id` | P0 | NOT RUN |
| **ENF-02** | Mismatched Policy Correlation | Policy v2 created; latest ack belongs to v1 | Open policy v2 screen | None | Latest ack is `mismatched`; v2 shows "Pending device acknowledgement"; no green badge | NOT RUN | UI screenshot, command payload ID vs displayed policy ID | P0 | NOT RUN |
| **ENF-03** | Uncorrelated Policy ID | Ack payload has empty/null `policy_id` | View policy detail | None | Correlation `uncorrelated`; displays "Device report not linked to this policy"; no verified badge | NOT RUN | Parent screenshot, read-only ack with empty ID | P0 | NOT RUN |
| **ENF-04** | Unproven Counts Banner | Policy `enforced` but ack lacks counts | Open policy details | None | Banner displays "Enforcement not proven by counts"; verified badge suppressed | NOT RUN | Parent screenshot, read-only ack JSON | P1 | NOT RUN |
| **ENF-05** | Unsupported Status UI | Device reported enforcement unsupported | Open policy details | None | Banner displays "Unsupported on this device"; explicit warning, no false claims | NOT RUN | Parent screenshot, read-only `enforcement_status` | P1 | NOT RUN |
| **ENF-06** | In-Flight Race Guard | Rapidly save new policy version | Save policy v3 while v2 ack in-flight | Dispatch ack for v2 | Generation guard drops stale v2 report; UI does not overwrite v3 with v2 data | NOT RUN | Logcat/UI sequence, read-only timestamps | P1 | NOT RUN |
| **ENF-07** | Phrasing Integrity | Child reported partial suspension failure | Inspect app restrictions detail | Report partial failure | Section header reads exactly: "Apps the device could not confirm as suspended" | NOT RUN | UI screenshot with exact phrasing | P1 | NOT RUN |
| **ENF-08** | Multi-Device Ack Scoping | Device B acks policy; Device A selected | View policy for Device A | Device B sends ack | Device B's ack is ignored for Device A; correlation strictly scoped by `device_id` | NOT RUN | Read-only `device_commands` across two devices | P1 | NOT RUN |
| **SESS-01** | Assistance Request State | Linked child online; no active session | Tap "Start audio assistance" | Observe screen; mic inactive | Session created in `requested` state; parent shows "Waiting for consent"; no mic open | NOT RUN | Parent screenshot, read-only `remote_sessions.status` | P0 | NOT RUN |
| **SESS-02** | Explicit Consent Gating | Pending session request on child | Waiting on session screen | Requests tab $\rightarrow$ Tap "Accept" | `respond accept` records consent; `AudioAssistanceService` starts; mic notification appears | NOT RUN | Child screenshot, `dumpsys activity services`, `dumpsys audio` | P0 | NOT RUN |
| **SESS-03** | ICE Signaling Consent Gate | Unconsented session request | Attempt to trigger `ice` RPC | None | Edge Function rejects `ice` with `403 Forbidden` (consent required); no SDP/ICE leak | NOT RUN | Edge Function log (403), screenshot | P0 | NOT RUN |
| **SESS-04** | Truthful Audio Live UI | Consented active session established | Listen for 5 min; inspect status chip | Speak into child microphone | UI displays "Audio live" ONLY when RTP packet deltas are positive; badge alone insufficient | NOT RUN | `dumpsys audio` both devices, RTP UI logcat, screenshot | P0 | NOT RUN |
| **SESS-05** | Notification Gate (API 33+) | `POST_NOTIFICATIONS` denied on child | Request audio assistance | Tap "Accept" on request card | Mic capture refused (`notification_permission_required`); FGS does not start without notification | NOT RUN | Child screenshot, logcat refusal token | P0 | NOT RUN |
| **SESS-06** | Realme Channel Importance | Realme channel importance = NONE | Observe session state | Accept session on Realme device | FGS runs with live mic; UI truthfully notes notification hidden by OS; no silent config edit | NOT RUN | `dumpsys activity services`, notification shade screenshot | P1 | NOT RUN |
| **SESS-07** | Parent Watchdog Teardown | Active session; child app backgrounded | Tap "End session" | Keep child app in background | Server session `ended`; child watchdog halts FGS and mic within $\le 15$ s; no zombie mic | NOT RUN | `dumpsys activity services` before/after, read-only session | P0 | NOT RUN |
| **SESS-08** | Child Decline Flow | Pending session request on child | Waiting on session screen | Requests tab $\rightarrow$ Tap "Decline" | Session transitions to `declined`; no media/FGS started; parent UI shows declined state | NOT RUN | Read-only `remote_sessions.status`, screenshots both | P1 | NOT RUN |
| **SESS-09** | Concurrent Session Limit | Active session already in progress | Request second session for device | None | Edge Function rejects with `409 session_in_progress`; exactly one active session allowed | NOT RUN | Edge Function log (409), read-only query (1 open row) | P1 | NOT RUN |
| **NET-01** | Transient Outage Handling | Active audio streaming session | Observe status banner during outage | Disable Wi-Fi/cellular for 60 s; restore | Parent shows "Reconnecting"; session stays open; UI never falsely claims "live" while offline | NOT RUN | Parent screenshots, `dumpsys`, read-only session row | P1 | NOT RUN |
| **NET-02** | Recovery Budget Exhaustion | Active session; network cut $> 50$ s | Observe parent UI | Keep network offline $> 50$ s; restore | `_pauseMediaAfterConnectionLoss` halts capture; "Stop sharing" remains visible; session open | NOT RUN | Child screenshot (Stop sharing visible), `dumpsys audio` | P1 | NOT RUN |
| **NET-03** | Explicit Rejoin Protocol | Recovery exhausted; session still open | Tap "Join with explicit consent" | Tap "Reconnect microphone" | Media re-established on SAME `session_id`; no duplicate session row; no server `end` | NOT RUN | Read-only query (1 open session), RTP logcat, screenshots | P1 | NOT RUN |
| **NET-04** | Signaling Terminal Reset | Signaling hit 5-attempt terminal failure | Tap "Refresh / Rejoin" | Observe incoming signaling | Explicit user action re-arms signaling loop; session recovers from terminal state | NOT RUN | Logcat signaling sequence, screenshot | P2 | NOT RUN |
| **NET-05** | STUN-Only Disclosures | STUN active; no TURN relay configured | Inspect connection diagnostics | Inspect ICE candidate types | Parent UI displays "Relay not configured"; candidates are host/srflx; relay count = 0 | NOT RUN | ICE candidate logcat, screenshot | P2 | NOT RUN |
| **NET-06** | TURN Credential Refresh | Hypothetical TURN config; ICE restart | Trigger ICE restart | Trigger ICE restart | (BLOCKED: no relay deployed). Expected: credentials refreshed before restart attempt | NOT RUN | Logcat of `ice` response showing fresh credentials | P2 | NOT RUN |
| **NET-07** | 15-Minute Endurance (F1) | Active session held for 15 min | Hold session open 15 min | Keep device active | Expected: continuous audio. Defect F1: pre-fix server expires at 30 min, causing premature death | NOT RUN | Timestamped parent screenshots, read-only session `expired` | P0 | NOT RUN |
| **PERM-01** | Mic Permission Revocation | Active audio session streaming | Observe session UI | Settings $\rightarrow$ Revoke `RECORD_AUDIO` | FGS and mic capture halt immediately; NO auto-restart; no zombie mic; graceful handling | NOT RUN | `dumpsys audio` (capture absent), screenshot, read-only session | P0 | NOT RUN |
| **PERM-02** | Child Immediate Stop | Active audio session streaming | Observe session UI | Tap "Stop sharing" $\rightarrow$ Confirm | Capture halts instantly; FGS stops; server session stays open (parent authority preserved) | NOT RUN | Child screenshot ("Sharing stopped"), `dumpsys audio` | P0 | NOT RUN |
| **PERM-03** | Stop Sharing Availability | Session recovery exhausted; peer disconnected | Observe session UI | Check "Stop sharing" button | `canStopSharing` remains true; tapping succeeds idempotently with no errors | NOT RUN | Child screenshot, logcat | P1 | NOT RUN |
| **PERM-04** | Notification Perm Revoke | Active session on Android 13+ | Observe session UI | Settings $\rightarrow$ Revoke `POST_NOTIFICATIONS` | FGS halts with `notification_permission_required`; no silent audio capture allowed | NOT RUN | Child screenshot, logcat refusal reason | P0 | NOT RUN |
| **PERM-05** | Privacy Indicator Display | Active audio session streaming | None | Pull down shade; check green dot | Ongoing notification and green privacy dot present; no OS indicator suppression | NOT RUN | Notification shade screenshot, `dumpsys notification` | P1 | NOT RUN |
| **PERM-06** | Post-Revocation Dashboard | Permission revoked as in PERM-01 | None | Return to Child Dashboard | Dashboard MUST NOT claim "Microphone sharing in progress" once permission revoked | NOT RUN | Child dashboard screenshot | P1 | NOT RUN |
| **PERM-07** | Dual Authority Resolution | Active session; child stops first | Parent taps "End session" | Child taps "Stop sharing" | Child stop halts local capture; parent End is terminal action setting `ended_by='parent'` | NOT RUN | Read-only session `status='ended'`, `ended_by='parent'`, screenshots | P0 | NOT RUN |
| **ZONE-01** | Safe Zone Creation | Parent signed in, family active | Safe Zones $\rightarrow$ Create (name, radius) | None | Zone row inserted via client RLS; zone appears in list | NOT RUN | Parent screenshot, read-only `safe_zones` row | P2 | NOT RUN |
| **ZONE-02** | Safe Zone Update | Existing safe zone in family | Edit radius/toggle $\rightarrow$ Tap "Save" | None | `upsertSafeZone` updates row in place; list reflects changes | NOT RUN | Parent screenshot, read-only `safe_zones` row | P2 | NOT RUN |
| **ZONE-03** | Audited Zone Deletion | Existing safe zone in family | Select zone $\rightarrow$ Delete $\rightarrow$ Confirm | None | `delete_safe_zone_audited` deletes zone and writes `zone_deleted` audit row atomically | NOT RUN | Parent screenshot, read-only `safe_zones` (gone), `audit_logs` | P1 | NOT RUN |
| **ZONE-04** | Child Zone Edit Denial | Child account signed in | None | Attempt to call zone mutation RPC | Rejected with `403 Forbidden` ("Parent required to change safe zones"); no change | NOT RUN | Child screenshot, Edge Function log (403) | P1 | NOT RUN |
| **ZONE-05** | Vanished Zone Delete 404 | Non-existent zone ID | Attempt delete on missing ID | None | Pre-read returns 404 `zone_not_found`; skips audit write; no fabricated audit row | NOT RUN | Parent screenshot, read-only `audit_logs` (no new row) | P2 | NOT RUN |
| **ZONE-06** | Audit Failure Compensation | Simulated transient audit write failure | Attempt delete while audit fails | None | (BLOCKED: requires unapplied code). Expected: zone restored, `audit_failed` 500 error shown | NOT RUN | Parent screenshot, read-only `safe_zones`, Edge log token | P1 | NOT RUN |
| **ZONE-07** | Total DB Failure Path | Simulated audit AND restore failure | Attempt delete under DB fault | None | (BLOCKED: unapplied code). Expected: 500 "deleted but not recorded", no false success | NOT RUN | Parent screenshot, read-only `safe_zones`, Edge log token | P1 | NOT RUN |
| **ZONE-08** | Duplicate Audit Handling | Network timeout retry on zone delete | Re-try delete after timeout | None | Audit table safely appends duplicate `zone_deleted` records; never under-records | NOT RUN | Read-only `audit_logs` ($\ge 1$ `zone_deleted` rows) | P2 | NOT RUN |
| **LIFE-01** | Home Background Survival | Active audio streaming session | Observe parent audio stream | Press Home button; wait 30 s; return | Child PID unchanged; session stays Active; audio continues uninterrupted | NOT RUN | `dumpsys activity services`, before/after screenshots | P1 | NOT RUN |
| **LIFE-02** | Lock Screen Survival | Active audio streaming session | Observe parent audio stream | Press power button (lock 2 min); unlock | Session remains Active; audio stream continues; no teardown | NOT RUN | `dumpsys`, screenshots, read-only session row | P1 | NOT RUN |
| **LIFE-03** | Parent Recents Swipe | Active session on emulator parent | Swipe parent app from Recents; reopen | Keep streaming audio | Process and FGS survive; `onTaskRemoved` non-terminal; reopening restores session UI | NOT RUN | `dumpsys activity services` after swipe, parent screenshots | P1 | NOT RUN |
| **LIFE-04** | Realme Recents Task-Kill | Active session on Realme child | Observe session indicators | Swipe child app from Recents | OEM killer terminates task (`signal 9`); FGS dies; capture halts; session open for rejoin | NOT RUN | Logcat (`task removed`), parent screenshot, read-only session | P0 | NOT RUN |
| **LIFE-05** | Process Force-Stop | Active audio session streaming | Observe audio indicators | Settings $\rightarrow$ Force Stop child app | Process and services terminated; mic indicator gone; parent reflects offline; no auto-restart | NOT RUN | `dumpsys activity services` (empty), read-only session row | P0 | NOT RUN |
| **LIFE-06** | Post-Kill Rejoin Protocol | Child app killed via LIFE-04/05 | Tap "Join with explicit consent" | Relaunch child app; tap "Reconnect" | Rejoin restores audio on SAME `session_id`; single service/controller re-created | NOT RUN | Screenshots both devices, read-only query (1 open row) | P1 | NOT RUN |
| **LIFE-07** | Back Navigation Dialog | Session open on child screen | None | Press Back button on assistance route | Confirmation dialog shown ("End and leave?"); "Stay" keeps capture; leaving detaches route only | NOT RUN | Dialog screenshot, read-only session row | P2 | NOT RUN |
| **LIFE-08** | Logout / Unlink Cleanup | Active session streaming | Observe session state | Log out child or unlink device | `releaseActive()` halts local capture and stops FGS; re-login restores clean state | NOT RUN | `dumpsys activity services`, read-only session row | P1 | NOT RUN |
| **LIFE-09** | Sticky Reboot Recovery | Child device rebooted | Observe presence indicator | Reboot child physical device | `GuardianService` (`START_STICKY`) restarts via `BootReceiver`; presence heartbeats resume | NOT RUN | `dumpsys`, read-only `last_seen_at` across reboot | P1 | NOT RUN |

---

## 6. Matrix Coverage Summary

| Section | Domain Area | Total Rows | Risk P0 | Risk P1 | Risk P2 | Risk P3 | Phase 7 Status |
|---|---|---|---|---|---|---|---|
| **§A** | Authentication & Family Association | 6 | 0 | 4 | 2 | 0 | **6 NOT RUN** |
| **§B** | Pairing & Unlinking Lifecycle | 8 | 2 | 2 | 4 | 0 | **8 NOT RUN** |
| **§C** | Device Presence & Sync Health | 6 | 0 | 3 | 2 | 1 | **6 NOT RUN** |
| **§D** | Device Commands & Policy Correlation | 15 | 3 | 10 | 2 | 0 | **15 NOT RUN** |
| **§E** | Remote Consent & Microphone FGS | 9 | 6 | 3 | 0 | 0 | **9 NOT RUN** |
| **§F** | Network Interruption & Reconnection | 7 | 1 | 3 | 3 | 0 | **7 NOT RUN** |
| **§G** | Permission Revocation & User Controls | 7 | 4 | 3 | 0 | 0 | **7 NOT RUN** |
| **§H** | Safe Zones & Audited Deletion | 8 | 0 | 4 | 4 | 0 | **8 NOT RUN** |
| **§I** | Process Lifecycle & Process Death | 9 | 2 | 6 | 1 | 0 | **9 NOT RUN** |
| **Total** | **Comprehensive Controlled Matrix** | **75** | **18** | **38** | **18** | **1** | **75 NOT RUN (100%)** |

---

## 7. Prerequisites Required Before Execution Can Begin

Before any single row in the 75-row matrix can transition from `NOT RUN` to active testing on hardware, the following 6 mandatory prerequisites must be fulfilled:

```mermaid
flowchart LR
    P1["Prereq 1:<br/>Owner Decision DEC-03<br/>Explicit Authorization"] --> P2["Prereq 2:<br/>Hardware & ADB<br/>Connectivity Verified"]
    P2 --> P3["Prereq 3:<br/>Pairing Ceremony<br/>Authorization & Re-link"]
    P3 --> P4["Prereq 4:<br/>Backend Deployment<br/>(DEC-02 / HOST-01)"]
    P4 --> P5["Prereq 5:<br/>Relay Infrastructure<br/>(DEC-06 / STUN vs TURN)"]
    P5 --> P6["Prereq 6:<br/>Credential Verification<br/>(QA Family A Fixtures)"]
```

1. **Prerequisite 1: Explicit Owner Decision DEC-03 Authorization**  
   The repository owner must formally issue written approval authorising:
   - Compilation of debug/QA test APKs.
   - Installation of test packages on `emulator-5554` and Realme `5HXWRGQ4IFU8WS4T`.
   - ADB command execution against both QA devices.
   - Audio capture and WebRTC media streaming during controlled test windows.
2. **Prerequisite 2: Hardware Attachment & ADB Accessibility Verification**  
   - The Android SDK `platform-tools` must be added to the execution environment PATH.
   - `adb devices` must report both targets in the `device` state:
     - `emulator-5554` (AVD online, API 37).
     - `5HXWRGQ4IFU8WS4T` (Realme 7 USB debugging authorized, API 31).
3. **Prerequisite 3: Re-Pairing Ceremony Authorization & State Re-establishment**  
   - Because all prior device links are `Revoked`, an owner-authorized pairing ceremony must be performed:
     1. Parent emulator sends pairing invite to child ID `PC-XXXXXXXX`.
     2. Child Realme accepts invite.
     3. Verify `family_members` and `devices` state transition to active linked status.
4. **Prerequisite 4: Hosted Backend Deployment (HOST-01 / DEC-02)**  
   - Testing against production Supabase (`hhqgreaoqulmfwfwarhc`) requires owner resolution of DEC-02 (applying migrations 1–4 and Edge Functions 1–3) to prevent tests from failing due to pre-Phase-1 backend state (e.g., client-side DELETE on safe zones, missing atomic RPCs).
   - Alternatively, owner must authorize testing against a verified local Supabase instance.
5. **Prerequisite 5: Relay Infrastructure Decision (DEC-06 / STUN vs TURN)**  
   - Owner must decide whether TURN relay credentials will be provisioned. If unprovisioned, NET-06 must remain formally scoped as `UNSUPPORTED (STUN-only)`.
6. **Prerequisite 6: Test Account Credential Verification**  
   - Verify that `.tools/qa_accounts.env` holds valid tokens for QA Family A (`PARENT_A_USER` and `CHILD_A_USER`).
   - Confirm unverified accounts (`ankit@gmail.com`) are excluded from automated test routines.

---

## 8. Evidence Capture Discipline & Sanitization Protocol

When DEC-03 is unlocked and execution proceeds, evidence collection must strictly comply with the established forensic standards:

### 8.1 Evidence Directory Structure
All evidence artifacts must be stored under `docs/evidence/phase7/`:
```
docs/evidence/phase7/<section>/<test_id>-<actor>-<state>.<ext>
```
- `<section>`: One of `auth`, `pair`, `pres`, `cmd_enf`, `sess`, `net`, `perm`, `zone`, `life`.
- `<test_id>`: Exact test matrix identifier (e.g., `SESS-02`, `ENF-02`, `LIFE-04`).
- `<actor>`: `parent`, `child`, `edge`, or `db`.
- `<state>`: Specific lifecycle checkpoint (e.g., `requested`, `consented`, `killed`, `restored`).

### 8.2 Device Hardware State Verification Commands
Hardware assertions must never rely solely on UI representations:
```bash
# 1. Child Foreground Service inspection (verifies microphone type & channel ID):
adb -s 5HXWRGQ4IFU8WS4T shell dumpsys activity services com.parentcontrol.parent_control

# 2. Child active audio recording client inspection (verifies PID & AudioRecord state):
adb -s 5HXWRGQ4IFU8WS4T shell dumpsys audio | grep -A 10 "AudioRecord"

# 3. Notification channel importance & status bar privacy chip:
adb -s 5HXWRGQ4IFU8WS4T shell dumpsys notification --noredact com.parentcontrol.parent_control
```

### 8.3 Logcat Sanitization Protocol
Execution logs must be extracted with targeted filters and sanitized before commitment:
```bash
adb -s 5HXWRGQ4IFU8WS4T logcat -d -v time \
  "parent_control:V RemoteSession:V WebRtc:V AudioAssist:V *:S"
```
> [!CAUTION]
> **Credential Sanitization:**  
> Logs must be programmatically verified to ensure NO bearer tokens (`Bearer eyJ...`), passwords, Supabase secrets (`service_role`, `anon`), or device encryption keys are stored in evidence directories.

### 8.4 Read-Only Database Queries
Backend assertions must strictly utilize read-only queries in the Supabase SQL editor:
```sql
-- Read-only check for remote session consent and termination attribution:
SELECT id, family_id, child_device_id, parent_user_id, status, 
       consent_recorded, ended_by, ended_reason, created_at, expires_at 
FROM remote_sessions 
WHERE id = '<session_id>';

-- Read-only check for device command delivery and ack payloads:
SELECT id, device_id, command_type, status, payload, result, created_at, acked_at 
FROM device_commands 
WHERE device_id = '<device_id>' 
ORDER BY created_at DESC LIMIT 5;
```

---

## 9. Conclusion & Mandatory Stop Condition

### 9.1 Summary of Evaluation Findings
1. **Gate Enforcement:** Owner Decision DEC-03 has not been granted. Gate B remains formally **CLOSED**.
2. **Device State:** Hardware is detached/sandboxed; all prior QA device links are Revoked.
3. **Execution Status:** **0 of 75 rows executed (100% NOT RUN)**.
4. **Safety & Privacy:** All 10 mandatory privacy invariants and prioritized risk tiers are formally codified and ready for immediate deployment upon owner authorization.

### 9.2 Mandatory Stop Directive
In strict adherence to project safety rules and Owner Ruling #9:
**Execution stops here. No APKs will be built, no devices will be touched, and no microphone capture will occur until the owner explicitly authorises DEC-03.**
