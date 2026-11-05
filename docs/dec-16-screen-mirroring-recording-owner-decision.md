# DEC-16 Owner Decision: Screen Mirroring & Recording Scope

**Document class:** Owner Decision Record (Governance, Architecture & Technical Comparison).  
**Decision ID:** DEC-16.  
**Decision Title:** Screen Mirroring & Screen Recording Product Scope.  
**Registered Governance Status:** **APPROVED — Option A (Screen Mirroring and Recording Excluded from Product Scope).**  
**Approval Date:** 2026-11-05 (Phase 9.9).  
**Target System:** HAVEN / `parentcontrol_app` (Flutter parent/child client, Kotlin Android native services, Supabase hosted backend `parent-control-prod` / `hhqgreaoqulmfwfwarhc`).  
**Implementation Authorization:** **STRICTLY PROHIBITED / NONE.** This document records architectural approval of Option A (product scope exclusion). It does not authorize writing or modifying code, adding Android services/permissions, deploying Edge Functions, applying migrations, building APKs, issuing ADB commands, or testing on hardware.

---

## 1. Decision Identification and Governance Status

- **Decision ID:** DEC-16
- **Title:** Screen Mirroring & Screen Recording Product Scope
- **Status:** **APPROVED — Option A** (Approved by Project Owner on 2026-11-05, Phase 9.9)
- **Approved Architectural Choice:** **Option A: Exclude both screen mirroring and screen recording from product scope.**
- **Governing Phase:** Phase 9.9
- **Exact Owner Ruling:**
  > **DEC-16 owner decision: Option A — Exclude both screen mirroring and screen recording from product scope.**
- **Approved Interpretation & Scope Boundaries:**
  1. **Parent-to-child screen mirroring is excluded** from HAVEN product scope.
  2. **Child-to-parent screen mirroring is excluded** from HAVEN product scope.
  3. **Live screen viewing and remote display capture are excluded.**
  4. **Persistent screen recording and video clip storage are excluded.**
  5. **Screenshot capture and scheduled screen captures are excluded.**
  6. **Android MediaProjection-based screen capture is excluded.**
  7. **Screen-capture WebRTC tracks are excluded.**
  8. **Media recording storage, playback and export capabilities are excluded.**
  9. **No hidden or covert screen capture is permitted.**
  10. **Existing audio-only assistance and front-camera assistance remain governed by their existing approved requirements.** DEC-16 does not authorize changing or expanding those features.
  11. **Existing child privacy promises must remain intact.**
  12. **Reconsidering screen capture in the future requires a formal product re-charter and a separate explicit owner decision.** Option A is a formal product-scope exclusion, not a temporary deferral. Options B, C, and D remain unselected.
- **Preceding Decisions & System Governance Context:**
  - **DEC-01:** **APPROVED — Choice B** (Local-only client diagnostics; DUR-01 remains OPEN; remote log harvesting prohibited).
  - **DEC-02:** **PENDING / BLOCKED** (Hosted Supabase mutations and deployments strictly prohibited; Stage 7 migration pair 20261028000200 and 20261028000300 verified applied hosted; 4 remaining repository migrations [20261030000100, 20261030000200, 20261030000300, 20261103000100], preflights, and 3 Edge Function deployments [account, family-admin, device-command] remain unapplied).
  - **DEC-03:** **PENDING / BLOCKED** (75/75 controlled Android QA rows remain `NOT RUN`; APK builds, ADB commands, and device hardware testing strictly prohibited).
  - **DEC-05:** **APPROVED — Choice B** (On-demand execution only; `pg_cron` absent hosted).
  - **DEC-12:** **APPROVED — Choices D1-B, B1-B, O1-C, P1-A, DEFER** (Screen-time and bedtime enforcement; hard suspension via Device Owner; child emergency override 10-min pass; implementation gated).
  - **DEC-13:** **APPROVED — Option B** (Managed Mode required for full enforcement; mandatory non-destructive in-app exit as release blocker; Device Administrator retired; implementation gated).
  - **DEC-14:** **APPROVED — Option B** (Realtime primary + FCM non-authoritative wake-up transport; opaque payloads only; implementation gated).
  - **DEC-15:** **APPROVED — Option D** (Website filtering deferred for current release; implementation gated).
  - **DEC-16:** **APPROVED — Option A** (Subject of this document; screen mirroring and recording formally excluded from product scope).

*No implementation authorization may be inferred from any approved architecture decision.*

---

## 2. Problem Statement

Commercial child monitoring software (such as AirDroid Parental Control, FlashGet Kids, and mSpy) frequently advertises "Screen Mirroring" (real-time remote viewing of the child's display) and "Screen Recording" (automated or periodic capturing of screenshots and video clips).

However, introducing screen capture or persistent visual recording into HAVEN presents fundamental privacy, security, legal, and OS-level conflicts:

1. **Explicit Child-Facing Privacy Commitments:** The HAVEN application displays clear, unhedged privacy promises to the child across multiple surfaces:
   - [`lib/features/child/tabs/child_settings_tab.dart:67-70`](../lib/features/child/tabs/child_settings_tab.dart#L67-L70): *"This app never records audio or video, takes screenshots, reads messages, or captures passwords."*
   - [`lib/features/child/child_session_page.dart:144-147`](../lib/features/child/child_session_page.dart#L144-L147): *"Nothing is recorded. Camera and microphone are used only while you are sharing and stop when you tap Stop sharing... The app never takes screenshots or reads messages."*
   - [`lib/features/remote_assistance/remote_assistance_page.dart:89-91`](../lib/features/remote_assistance/remote_assistance_page.dart#L89-L91): *"Nothing is recorded, and no screenshots or recordings are saved."*
   - [`lib/features/remote_assistance/remote_session_page.dart:139-142`](../lib/features/remote_assistance/remote_session_page.dart#L139-L142): *"This app does not record audio or video, take screenshots, or save recordings."*
   Implementing screen capture or recording while these user-facing promises are active would constitute an intentional misrepresentation to minors and guardians.
2. **Exposure of Sensitive Unrelated Content:** Screen mirroring captures everything rendered on the child's display: personal private chats, banking and payment details, medical queries, two-factor authentication SMS/prompts, and communications with third parties who have not consented to surveillance.
3. **Android MediaProjection & OS Indicator Invariants:** Android 10+ (and especially Android 14+ / API 34+) enforces strict anti-covert requirements:
   - MediaProjection cannot be initiated without an interactive, non-bypassable system consent dialog on the child device.
   - Android displays an ongoing system-level screen capture indicator (chip/dot in the status bar) and persistent foreground notification that cannot be hidden or suppressed.
   - Screen capture tokens are strictly single-use and time-limited on Android 14+.
   - Android displays black frames for any window protected by `FLAG_SECURE` (banking, password managers, private messaging).
4. **Prohibitive Storage, Retention, and Security Overhead:** Storing recorded video clips requires cloud media storage (Supabase Storage buckets), signed URL management, strict encryption at rest, automated retention purges, and high bandwidth. HAVEN currently has zero storage buckets and zero file I/O infrastructure.
5. **Feature Inventory Provenance Discrepancy:** The canonical inventory ([`audit/01_COMPLETE_FEATURE_INVENTORY.md`](../audit/01_COMPLETE_FEATURE_INVENTORY.md)) records rows `FB-015` through `FB-026` as `MISSING` (with `FB-027` as `NOT APPLICABLE`), whereas informal parity discussions classified all 12 rows as `N/A` based on the owner's 2026-10-27 scope exclusion.

The project owner must formally decide whether HAVEN should permanently exclude both mirroring and recording (Option A), permit live screen mirroring only (Option B), permit live mirroring and recording (Option C), or formally defer the decision to a future milestone (Option D).

---

## 3. Read-Only Repository Audit & Implementation Baseline

A comprehensive technical audit was conducted across Kotlin Android sources, AndroidManifest declarations, Flutter application code, and Supabase backend schemas.

### 3.1 Detailed Audit of the 15 Investigation Domains

| # | Investigation Domain | Repository Source Reference | Governance Classification | Technical Audit Finding |
|---|---|---|---|---|
| **1** | **Parent-to-Child Screen Mirroring** | `lib/features/`, `android/` | **Missing** | Zero parent-screen capture or transmission code exists. |
| **2** | **Child-to-Parent Screen Mirroring** | `lib/features/`, `android/` | **Missing** | Zero child-display capture exists. WebRTC implementation (`remote_session_controller.dart:1205-1218`) requests front camera (`facingMode: 'user'`) only. `getDisplayMedia` is absent. |
| **3** | **Screen Capture Primitives** | `android/app/src/main/kotlin/` | **Missing** | Zero matches for `MediaProjection`, `createVirtualDisplay`, `PixelCopy`, or `ImageReader` across Android sources. |
| **4** | **Screen Recording** | `android/`, `lib/` | **Missing** | No `MediaRecorder` or H.264 video encoding pipeline exists. Zero video saving to disk. |
| **5** | **Screenshot Capture** | `android/`, `lib/` | **Missing** | Zero screenshot capture methods or scheduled screen grabs. |
| **6** | **Audio Capture with Screen Share** | `android/.../AudioAssistanceService.kt` | **Missing** | Audio capture exists strictly for one-way audio assistance via mic. `AudioPlaybackCapture` (capturing internal device audio) is absent. |
| **7** | **Media Storage & Retention** | `supabase/migrations/` | **Missing** | Zero Supabase Storage buckets exist; zero recording tables; zero `bytea` columns. `purge_expired_recordings` is absent. |
| **8** | **WebRTC Streaming Infrastructure** | `lib/features/remote_assistance/` | **Partially Implemented** | WebRTC signaling via `webrtc_signals` table and peer connections exists for one-way mic audio and front camera; video path untested on hardware (DEC-03). Screen track absent. |
| **9** | **Android MediaProjection Integration** | `android/app/src/main/` | **Missing** | No `MediaProjectionManager.createScreenCaptureIntent()` call site exists in Kotlin. |
| **10** | **Foreground Service Requirements** | [`AndroidManifest.xml:79-94`](../android/app/src/main/AndroidManifest.xml#L79-L94) | **Missing** | No service declared with `foregroundServiceType="mediaProjection"`. Manifest declares only `dataSync`, `location`, `microphone`. |
| **11** | **Runtime Permissions & Consent** | [`AndroidManifest.xml:4-29`](../android/app/src/main/AndroidManifest.xml#L4-L29) | **Missing** | `FOREGROUND_SERVICE_MEDIA_PROJECTION` is not declared. Camera (`CAMERA`) and Mic (`RECORD_AUDIO`) are declared for live assistance. |
| **12** | **Parent-Side Viewing UI** | [`remote_session_page.dart:455-479`](../lib/features/remote_assistance/remote_session_page.dart#L455-L479) | **Partially Implemented** | `RTCVideoView` exists for front camera video stream; zero video player dependencies (`video_player` absent from `pubspec.yaml`) for clip playback. |
| **13** | **Child Consent & Stop-Sharing UI** | [`child_session_page.dart:144-160, 408-520`](../lib/features/child/child_session_page.dart#L144-L160) | **Implemented in Code (Audio/Camera Only; Hardware QA Not Run)** | Child UI implements explicit "Join now" tap to start live assistance; persistent "Stop sharing" button wired to tear down session. Camera and audio runtime unexecuted under DEC-03. Does not cover screen capture. |
| **14** | **Session Authorization & Revocation** | `supabase/functions/remote-session/guard.ts` | **Implemented in Code (Audio/Camera Only; Hardware QA Not Run)** | Strict RLS and Edge Function validation enforce parent ownership and active session tokens. Immediate teardown designed on session end; end-to-end runtime unexecuted under DEC-03. |
| **15** | **Audit Logging & Security Controls** | [`core.sql:372-385`](../supabase/migrations/20260101000000_core.sql#L372-L385) | **Partially Implemented** | Assistance session start/end logged to `public.audit_logs`. No media access or export logging exists because no media is stored. |

### 3.2 Key Audit Finding
**Screen mirroring, screen recording, and screenshots are 100% absent from the codebase.**
- Not a single line of MediaProjection, screen recording, or screenshot code exists in Kotlin or Dart.
- AndroidManifest does not request screen capture permissions or declare a media projection foreground service.
- The existing WebRTC infrastructure supports only live microphone audio and optional front-camera video for consented remote assistance sessions.
- Explicit child-facing privacy guarantees promise that the app never takes screenshots, records video, or captures passwords.

---

## 4. Architecture and Scope Options

Four distinct options are evaluated objectively:

```
+----------------------------------------------------------------------------------------------------+
|                                    DEC-16 ARCHITECTURE OPTIONS                                     |
+------------------------------------+----------------------------------+----------------------------+
| Option A: Exclude Both (Recommend) | Option B: Live Mirroring Only    | Option C: Mirror & Record  |
| - Formal scope exclusion           | - Ephemeral WebRTC screen track  | - Live view + MP4 clips    |
| - Upholds "never records" promise  | - Mandates child system consent  | - Supabase Storage bucket  |
| - Zero storage / zero media risk   | - Rewrites privacy disclosures   | - Severe privacy liability |
+------------------------------------+----------------------------------+----------------------------+
| Option D: Defer to Future Milestone                                                                |
| - Neither feature in current release; leaves architectural selection open                          |
| - Allows post-release re-evaluation without committing to permanent exclusion                      |
+----------------------------------------------------------------------------------------------------+
```

---

### Option A — Exclude Both Mirroring and Recording (Recommended)

#### Description
Formally ratify the 2026-10-27 owner ruling as a binding product boundary. Screen mirroring, screen recording, and screenshot capture are completely excluded from HAVEN. Existing live assistance features remain strictly limited to child-consented live microphone audio and optional front-camera video.

#### Technical & Operational Characteristics
- **Zero New Code:** No MediaProjection integration, no foreground service additions, no video encoders, no storage buckets.
- **Privacy Invariant Preservation:** Preserves existing user-facing privacy guarantees without modification ([`child_settings_tab.dart:67-70`](../lib/features/child/tabs/child_settings_tab.dart#L67-L70): *"This app never records audio or video, takes screenshots, reads messages, or captures passwords"*).
- **Zero Media Storage Liability:** No encrypted storage buckets, no media retention sweeps, no risk of leaking recorded child communications or banking screens.
- **Immediate Release Focus:** Eliminates all screen-capture testing overhead, allowing the team to concentrate 100% on active P0 release blockers (DEC-02 hosted migrations, DEC-03 Android QA rows, DEC-12 screen time execution, and DEC-13 release signing / safe exit).

---

### Option B — Allow Live Screen Mirroring Only (Recording Excluded)

#### Description
Permit ephemeral, live-only child-to-parent screen streaming over WebRTC during child-consented remote assistance sessions. Stored screen recordings, clips, and screenshot captures remain strictly excluded.

#### Technical & Operational Requirements
- **WebRTC Display Track:** Implement Android `MediaProjection` via a new `ScreenRecordService` (`foregroundServiceType="mediaProjection"`), feeding a display video track into `flutter_webrtc`.
- **Mandatory System Consent:** Child must interactively accept the Android OS `createScreenCaptureIntent()` prompt on every session. Caching tokens across sessions is prohibited and impossible on Android 14+.
- **Mandatory OS Privacy Indicator:** System status bar capture chip and persistent notification remain active throughout the session.
- **Child Stop-Sharing Control:** Persistent floating or notification-level control allowing the child to sever the screen stream instantly.
- **Privacy Promise Rewrite:** Requires completely rewriting [`child_settings_tab.dart:67-70`](../lib/features/child/tabs/child_settings_tab.dart#L67-L70), [`child_session_page.dart:144-147`](../lib/features/child/child_session_page.dart#L144-L147), and [`remote_session_page.dart:139-142`](../lib/features/remote_assistance/remote_session_page.dart#L139-L142) to disclose that live screen viewing is active.
- **FLAG_SECURE Blackout:** Android automatically blacks out banking apps, password managers, and DRM content.

---

### Option C — Allow Live Mirroring and Recording

#### Description
Permit both real-time screen mirroring and persistent screen recording (capturing MP4 video clips or periodic screenshots) uploaded to cloud storage for asynchronous parental review.

#### Technical & Operational Requirements
- **Full Video Pipeline:** On-device `MediaRecorder` encoding H.264 video to private app cache.
- **Cloud Media Infrastructure:** Supabase Storage bucket (`recordings`), upload Edge Functions, signed playback URLs, and metadata database tables.
- **Cryptographic Encryption & Integrity:** End-to-end encryption in transit (TLS) and encryption at rest in storage buckets, with SHA-256 integrity digests.
- **Automated Retention & Purge:** Hard retention limits (e.g. 7 days) enforced by automated purge cron jobs, with complete deletion on family unlink.
- **Access Audit Logging:** Immutably logging every parental playback, download, and deletion event in `public.audit_logs`.
- **Extreme Privacy & Legal Liability:** Exposes the product to severe regulatory risk under COPPA, GDPR-K, and child protection laws regarding the interception and storage of minors' private messages and account credentials.

---

### Option D — Defer Both Features to a Future Milestone

#### Description
Exclude both screen mirroring and screen recording from the current production release, but leave the architectural choice open for re-evaluation in a post-release phase.

#### Practical Distinction Between Option A and Option D
- **Option A (Formal Scope Exclusion):** Establishes an architectural and product principle that HAVEN is a non-surveillance, privacy-respecting safety tool that does not capture children's screens. Any future proposal to add screen capture would require an explicit product reversal and full privacy impact assessment.
- **Option D (Milestone Deferral):** Acknowledges that screen capture cannot be built or tested for the current release due to active P0 blockers, but defers the formal architectural decision between live-only (Option B) and permanent exclusion (Option A) to a later phase.

---

## 5. Technical Comparison Matrix (25 Criteria)

| # | Comparison Criterion | Option A: Exclude Both | Option B: Live Mirroring Only | Option C: Mirror & Record | Option D: Defer Features | Repository Evidence & Technical Invariants |
|---|---|---|---|---|---|---|
| **1** | **Child Consent** | `NOT APPLICABLE` | `FEASIBLE` (OS Dialog Req) | `FEASIBLE` (Dual Consent Req)| `NOT APPLICABLE` | Opt B/C mandate Android `MediaProjection` system prompt; Opt C requires separate recording consent. |
| **2** | **Parent Authorization** | `NOT APPLICABLE` | `FEASIBLE` (Edge Function Auth)| `FEASIBLE` (Edge Function Auth)| `NOT APPLICABLE` | Enforced via `remote-session` Edge Function and `assertParentOwner` (`guard.ts:117-128`). |
| **3** | **Android MediaProjection**| `NOT APPLICABLE` | `FEASIBLE` (New Kotlin Req) | `FEASIBLE` (New Kotlin Req) | `NOT APPLICABLE` | Opt B/C require new Kotlin capture manager; single-use token on Android 14+ (`docs/screen-recording-plan.md:73-82`). |
| **4** | **Foreground Service Type** | `NOT APPLICABLE` | `FEASIBLE` (Manifest Req) | `FEASIBLE` (Manifest Req) | `NOT APPLICABLE` | Opt B/C mandate `FOREGROUND_SERVICE_MEDIA_PROJECTION` in manifest (`AndroidManifest.xml:79-94`). |
| **5** | **Visible OS Indicator** | `NOT APPLICABLE` | `FEASIBLE` (Mandatory OS Chip)| `FEASIBLE` (Mandatory OS Chip)| `NOT APPLICABLE` | Android status bar chip/indicator cannot be hidden or suppressed. |
| **6** | **Persistent Notification** | `NOT APPLICABLE` | `FEASIBLE` (Mandatory FGS Req)| `FEASIBLE` (Mandatory FGS Req)| `NOT APPLICABLE` | Android mandates persistent ongoing notification during active projection. |
| **7** | **Child Stop-Sharing** | `NOT APPLICABLE` | `FEASIBLE` (Mandatory Stop UI)| `FEASIBLE` (Mandatory Stop UI)| `NOT APPLICABLE` | Invariant: child can terminate stream at any time (`child_session_page.dart:144-147`). |
| **8** | **Screen Lock Behavior** | `NOT APPLICABLE` | `FEASIBLE` (Stream Blanking) | `PARTIAL` (Records lock)| `NOT APPLICABLE` | Keyguard lock blanks or pauses projection stream. |
| **9** | **Background Behavior** | `NOT APPLICABLE` | `FEASIBLE` (OS Capture + SECURE)| `FEASIBLE` (OS Capture + SECURE)| `NOT APPLICABLE` | Captures home screen and apps; `FLAG_SECURE` blanks protected windows. |
| **10** | **App Process Termination**| `NOT APPLICABLE` | `FEASIBLE` (Failsafe Teardown)| `PARTIAL` (Truncated file)| `NOT APPLICABLE` | Service death immediately releases `VirtualDisplay` and stops projection. |
| **11** | **Permission Revocation** | `NOT APPLICABLE` | `FEASIBLE` (Auto-Teardown Req)| `FEASIBLE` (Auto-Teardown Req)| `NOT APPLICABLE` | Token invalidation immediately halts projection. |
| **12** | **Session Expiry** | `NOT APPLICABLE` | `FEASIBLE` (Session Watchdog)| `FEASIBLE` (Session Watchdog)| `NOT APPLICABLE` | Governed by `remote_sessions.expires_at` and watchdog. |
| **13** | **Network Disconnection** | `NOT APPLICABLE` | `FEASIBLE` (Drop Live Frames)| `PARTIAL` (Local cache) | `NOT APPLICABLE` | Opt B drops live frames; Opt C accumulates video in local storage (`cacheDir`). |
| **14** | **WebRTC/TURN Requirement** | `NOT APPLICABLE` | `FEASIBLE` (High Bandwidth Req)| `PARTIAL` (Signaling only)| `NOT APPLICABLE` | Opt B requires stable video TURN relay; Opt C uploads over HTTPS. |
| **15** | **Battery & Bandwidth** | `MINIMAL` (Zero overhead) | `UNSUPPORTED` (High drain)| `UNSUPPORTED` (Extreme) | `MINIMAL` (Zero overhead) | Screen encoding + WebRTC streaming consumes heavy CPU and battery on budget hardware. |
| **16** | **Audio/Video Sync** | `NOT APPLICABLE` | `PARTIAL` (WebRTC RTP) | `UNSUPPORTED` (Muxing) | `NOT APPLICABLE` | Lip-sync or display audio synchronization adds major complexity. |
| **17** | **Media Encryption** | `NOT APPLICABLE` | `FEASIBLE` (DTLS-SRTP Design)| `PARTIAL` (Storage bucket)| `NOT APPLICABLE` | Opt B encrypted peer-to-peer via DTLS; Opt C requires bucket-level KMS encryption. |
| **18** | **Recording Storage** | `NONE NEEDED` | `NONE NEEDED` | `UNSUPPORTED` (New infra)| `NONE NEEDED` | Opt C requires introducing Supabase Storage buckets (currently 0 in project). |
| **19** | **Data Retention & Purge** | `NONE NEEDED` | `NONE NEEDED` | `UNSUPPORTED` (Complex) | `NONE NEEDED` | Opt C requires automated purge cron (`run_retention_sweep`), currently unconfigured. |
| **20** | **Access Auditing** | `VERIFIED` (Audit Logs) | `FEASIBLE` (Session logs)| `PARTIAL` (File audit) | `VERIFIED` (Audit Logs) | Opt C requires logging every playback and export event in `public.audit_logs`. |
| **21** | **Unauthorized Access Risk**| `ZERO RISK` (No Media) | `PARTIAL` (Live leak) | `UNSUPPORTED` (Stored leak)| `ZERO RISK` (No Media) | Stored video clips create massive target for family boundary breaches. |
| **22** | **Privacy & Legal Risk** | `MINIMAL` (No Screen Data)| `PARTIAL` (Live view) | `UNSUPPORTED` (Severe) | `MINIMAL` (No Screen Data)| Opt C risks recording banking credentials, private chats, and third-party minors. |
| **23** | **Device/OEM Compatibility**| `UNIVERSAL` (No Encoder)| `PARTIAL` (Realme unproven)| `PARTIAL` (Realme unproven)| `UNIVERSAL` (No Encoder)| Realme RMX2161 ColorOS SELinux encoder behavior unverified (`screen-recording-plan.md:81`). |
| **24** | **Runtime Testing Burden** | `ZERO` (No Tests Needed)| `UNSUPPORTED` (Heavy) | `UNSUPPORTED` (Prohibitive)| `ZERO` (No Tests Needed)| Opt B/C add massive testing requirements to already blocked matrix (DEC-03). |
| **25** | **Product Claim Accuracy** | `PRESERVED` (Copy Intact) | `PARTIAL` (Requires rewrite)| `PARTIAL` (Requires rewrite)| `PRESERVED` (Copy Intact)| Opt A/D preserve existing "never records" copy; Opt B/C require rewriting all privacy strings. |

---

## 6. Mandatory Safety, Privacy, and Child Transparency Requirements

If screen sharing (Option B) or recording (Option C) is ever authorized in a future milestone, the implementation must strictly satisfy the following 14 mandatory invariants:

### 6.1 Requirements for Live Screen Mirroring (Option B)
1. **Explicit Interactive Child Consent:** Screen capture shall **never** start automatically from parent request, device boot, background service, or pairing. The child must explicitly tap an interactive consent button on the child device, followed by the system-level Android `MediaProjection` consent dialog.
2. **Clear Disclosure of Scope:** The child UI must explicitly explain that the parent can see everything rendered on the screen (including personal messages and notifications) until sharing stops.
3. **Mandatory Unsuppressed OS Indicators:** The application shall **never** attempt to suppress, hide, or overlay the Android status bar capture chip or ongoing foreground service notification. If the OS indicator fails to appear, capture must abort immediately.
4. **Child-Accessible Instant Stop Affordance:** A prominent "Stop sharing" button must be permanently accessible in the child application and in the ongoing notification shade. Tapping it must sever the WebRTC track and release the `MediaProjection` within 500 ms.
5. **Immediate Teardown on Revocation or Lock:** Screen capture must terminate immediately if:
   - The child revokes permissions in Android Settings.
   - The device keyguard locks.
   - The parent ends the session.
   - The network disconnects.
6. **No Covert Capture or Background Evasion:** Screen capture shall never run from `GuardianService`, `BootReceiver`, or any background sync process.
7. **FLAG_SECURE Compliance:** The app must respect Android's `FLAG_SECURE` window protections. No attempt to bypass window security flags or capture banking/password manager screens shall ever be made.

### 6.2 Additional Requirements for Persistent Recording (Option C)
8. **Separate, Explicit Recording Consent:** If recording is enabled, the child must provide an explicit, separate consent tap specifically acknowledging that a video file will be saved.
9. **Persistent On-Screen Recording Badge:** A permanent, pulsing visual recording indicator must remain visible on the child screen throughout the entire recording duration.
10. **Zero Plaintext Storage in Transit & at Rest:** Recorded media files must be encrypted in transit via TLS 1.3 and encrypted at rest in dedicated private storage buckets using unique cryptographic keys.
11. **Strict Data Minimization & Bounded Duration:** Screen recordings must have a strict maximum duration ceiling (e.g. 60 seconds) and must never capture continuous background activity.
12. **Automated Deletion & Retention Sweeps:** Recordings must be purged automatically after a maximum retention window (e.g. 7 days). All recordings must be purged immediately if a family unlinks or an account is deleted.
13. **Immutable Playback & Export Auditing:** Every parent playback, download, or deletion of a recorded clip must insert an append-only row into `public.audit_logs`.
14. **Legal & Compliance Review:** A formal legal review under COPPA, GDPR-K, and applicable child protection statutes must be completed and approved prior to shipping any recording feature.

---

## 7. Preservation of Existing Audio Privacy Requirements

This decision explicitly affirms and preserves baseline remote assistance audio privacy design requirements (DEC-14 governs out-of-band FCM alerts only; hardware execution remains gated under DEC-03):

1. **One-Way Child-to-Parent Audio Only:** Remote assistance audio design remains strictly one-way. The parent client is receive-only and never captures or transmits audio to the child.
2. **Interactive Audio Consent:** Audio capture architecturally begins only after explicit child consent ("Join now" tap) and confirmation of the microphone foreground service ([`AudioAssistanceService.kt:345`](../android/app/src/main/kotlin/com/parentcontrol/parent_control/AudioAssistanceService.kt#L345)). (Note: tested build 4005 failed foreground-service start with `MIC-01`, with immediate screen-off failure. The candidate microphone FGS fix existed in the worktree but remains NOT TESTED in the installed APK; no successful runtime verification of the candidate fix is available in the reviewed evidence. A later Stage 8 test survived a two-minute locked-screen interval, but five-minute and fifteen-minute locked-screen endurance remain NOT TESTED; long-duration locked-screen reliability remains NOT VERIFIED).
3. **OS Privacy Indicator Invariant:** Android's green microphone privacy dot and notification channel 4303 notification are architectural safety requirements. (Note: privacy dot was not observed on tested ColorOS 12.1 hardware, and channel importance was assigned `NONE` in prior tests).
4. **No Covert Audio Interception:** The app architecture prohibits background ambient audio capture, room conversations, or telephone calls outside an active, consented assistance session.
5. **No Audio Recording to Disk:** Remote assistance audio is designed for live streaming over WebRTC DTLS-SRTP and is **never written to disk, stored, or recorded**. (Note: RTP packet transmission was observed through packet-counter deltas on LAN STUN only. Successful human-audible playback on the parent device remains NOT TESTED / NOT VERIFIED; TURN relay absent).
6. **Boundary Protection:** No screen mirroring or recording option may weaken, modify, or expand the audio capture pipeline.

---

## 8. Recommendation and Architectural Synthesis

### 8.1 Advisory Recommendation
**OPTION A — EXCLUDE BOTH SCREEN MIRRORING AND RECORDING FROM PRODUCT SCOPE.**

*(If the owner prefers to keep future product options open without committing to permanent exclusion, the alternative recommendation is **Option D — Defer Both Features to a Future Milestone**.)*

### 8.2 Detailed Rationale for Recommending Option A
1. **Preserves Core Product Trust & Identity:** HAVEN is designed as a transparent, child-consented safety and digital wellbeing tool, not covert spyware. Excluding screen recording reinforces HAVEN's market positioning and upholds its unambiguous child-facing privacy guarantees ([`child_settings_tab.dart:67-70`](../lib/features/child/tabs/child_settings_tab.dart#L67-L70)).
2. **Eliminates High-Risk Privacy Liabilities:** Capturing children's full displays inevitably intercepts banking transactions, sensitive private chats, health searches, and credentials. Option A eliminates this entire class of privacy and regulatory risk.
3. **Avoids Heavy Cloud & Storage Overhead:** Option A requires zero cloud storage buckets, zero media encryption infrastructure, zero retention sweep daemons, and zero video player dependencies.
4. **Zero Battery & Network Impact:** Screen encoding and high-bitrate WebRTC video streaming cause severe thermal throttling and battery drain on budget Android devices (such as the target Realme RMX2161).
5. **Focuses Resources on Active P0 Release Blockers:** The engineering and QA teams must resolve critical existing blockers:
   - **DEC-02:** Historical Stage 7 pair reconciled separately; 4 repository migrations (`20261030000100`, `20261030000200`, `20261030000300`, `20261103000100`), preflights, and 3 Edge Function deployments (`account`, `family-admin`, `device-command`) unapplied.
   - **DEC-03:** 75/75 controlled Android QA rows are strictly `NOT RUN`.
   - **DEC-12:** Screen time daily limit execution logic.
   - **DEC-13:** Production release signing keystore and Device Owner non-destructive exit.

---

## 9. Future Acceptance Criteria (If Option B or C is Ever Authorized)

*(These are prospective requirements for any hypothetical future implementation, not statements of current verification. None of these tests have been executed or passed; runtime testing remains strictly blocked under DEC-03)*:

If a future owner decision reverses this exclusion and authorizes screen sharing or recording, the implementation must satisfy:

- **AC-16-01 (Contract & Privacy Rewrite):** All user-facing strings in `child_settings_tab.dart`, `child_session_page.dart`, and `remote_session_page.dart` are formally rewritten to disclose screen capture, with prior owner approval.
- **AC-16-02 (System Consent Gate):** Automated tests must verify that screen capture cannot begin without the OS `createScreenCaptureIntent()` dialog grant.
- **AC-16-03 (Anti-Covert Failsafe):** Static analysis and runtime tests must prove that killing the foreground service or losing focus immediately halts the `VirtualDisplay`.
- **AC-16-04 (Child Stop-Sharing Latency):** Hardware tests must prove that tapping "Stop sharing" destroys the projection and WebRTC track within 500 ms.
- **AC-16-05 (FLAG_SECURE Compliance):** Capture tests must prove that secure surfaces (banking apps, keyguard) render as solid black frames.
- **AC-16-06 (No Background Start):** Static verification must confirm that `BootReceiver` and `GuardianService` have zero references to screen capture classes.
- **AC-16-07 (Hardware Encoder Proof):** Video capture and encoding must be proven functional on physical target hardware (Realme RMX2161, ColorOS Android 11+).
- **AC-16-08 (Storage Isolation & KMS):** (Option C only) Cross-family storage penetration tests must prove that family B cannot read or guess family A's recording URLs.
- **AC-16-09 (Automated Purge Proof):** (Option C only) Execution of `purge_expired_recordings()` must be verified to prove expired media files are permanently deleted.
- **AC-16-10 (Audit Trail Proof):** (Option C only) Every recording playback and deletion must be proven to generate an immutable row in `public.audit_logs`.

---

## 10. Implementation Authorization Boundary

**STRICT PROHIBITION IN FORCE:**
- This document records formal approval of **Option A: Exclude both screen mirroring and screen recording from product scope.**
- It does **NOT** grant authorization to implement screen capture, mirroring, recording, or screenshots.
- It does **NOT** authorize adding Android `MediaProjection` APIs or modifying `AndroidManifest.xml`.
- It does **NOT** authorize creating Supabase Storage buckets or modifying backend schemas.
- It does **NOT** authorize building APKs, issuing ADB commands, or testing on hardware.
- DEC-16 is formally **APPROVED — Option A (Product Scope Exclusion Confirmed)**. Screen mirroring and screen recording are excluded from the HAVEN product scope.

---

## 11. DEC-16 Owner Decision — Ratified Ruling

The project owner has formally reviewed the DEC-16 decision package and explicitly ruled on 2026-11-05 (Phase 9.9):

- [x] **Option A: Exclude both screen mirroring and recording from product scope.** (**APPROVED by Project Owner on 2026-11-05.** Screen mirroring, recording, and screenshots are formally excluded from the product scope; existing "never records" privacy guarantees are preserved; storage and legal liabilities are eliminated; resources remain focused on P0 release blockers).
- [ ] **Option B: Allow live screen mirroring only; recording excluded.** *(Not selected; retained as historical evaluation).*
- [ ] **Option C: Allow live mirroring and recording, subject to additional privacy and security requirements.** *(Not selected; retained as historical evaluation; rejected due to severe privacy, legal, and storage liabilities).*
- [ ] **Option D: Defer both features to a future milestone.** *(Not selected; Option A chosen as formal, binding product-scope exclusion).*

### Binding Authorization Boundary:
This approval ratifies Option A (formal scope exclusion). It does **NOT** authorize writing code, creating database tables, modifying `AndroidManifest.xml`, provisioning devices, building APKs, or initiating Phase 10.

