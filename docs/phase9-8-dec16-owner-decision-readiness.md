# Phase 9.8: DEC-16 Screen Mirroring & Recording Decision Readiness Report

**Document class:** Technical Audit & Decision Readiness Consolidation.  
**Decision Reference:** DEC-16 (Screen Mirroring & Screen Recording Product Scope).  
**Current Governance Status:** **PROPOSED — AWAITING EXPLICIT OWNER SELECTION.**  
**Authored Date:** 2026-11-05 (Phase 9.8).  
**Repository:** `D:\parentcontrol_app` (`main`).  
**Backend Reference:** Supabase `parent-control-prod` (`hhqgreaoqulmfwfwarhc`).  
**Primary Deliverable:** [`docs/dec-16-screen-mirroring-recording-owner-decision.md`](dec-16-screen-mirroring-recording-owner-decision.md).

---

## 1. Executive Summary & Audit Baseline

Phase 9.8 conducted a rigorous, read-only technical audit of the HAVEN repository to establish the baseline for **DEC-16 (Screen Mirroring & Screen Recording Product Scope)**.

### Key Audit Findings:
1. **100% Absence of Screen Capture & Recording:**
   - **Android Subsystem:** Zero lines of `MediaProjection`, `createVirtualDisplay`, `PixelCopy`, `ImageReader`, or screen recording code exist. No service in [`AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml) declares `foregroundServiceType="mediaProjection"`.
   - **Flutter Client:** Zero screen capture or recording controllers exist. The WebRTC implementation in [`remote_session_controller.dart`](../lib/features/remote_assistance/remote_session_controller.dart#L1205-L1218) requests strictly front-facing camera video (`facingMode: 'user'`) and microphone audio; `getDisplayMedia` is completely absent.
   - **Supabase Backend:** No media storage buckets, recording tables, or media cleanup Edge Functions exist.
   - **Canonical Feature Inventory:** In [`audit/01_COMPLETE_FEATURE_INVENTORY.md`](../audit/01_COMPLETE_FEATURE_INVENTORY.md), feature rows `FB-015` through `FB-026` are classified as `MISSING`, `FB-027` is `NOT APPLICABLE`, and `FA-036` (image alerts) is `MISSING`.
2. **Strict Privacy Invariants Shipped in UI:**
   - The application explicitly promises minors and parents that it **never** records screen content or takes screenshots:
     - [`child_settings_tab.dart:67-70`](../lib/features/child/tabs/child_settings_tab.dart#L67-L70): *"This app never records audio or video, takes screenshots, reads messages, or captures passwords."*
     - [`child_session_page.dart:144-147`](../lib/features/child/child_session_page.dart#L144-L147): *"Nothing is recorded... The app never takes screenshots or reads messages."*
     - [`remote_assistance_page.dart:89-91`](../lib/features/remote_assistance/remote_assistance_page.dart#L89-L91): *"Nothing is recorded, and no screenshots or recordings are saved."*
     - [`remote_session_page.dart:139-142`](../lib/features/remote_assistance/remote_session_page.dart#L139-L142): *"This app does not record audio or video, take screenshots, or save recordings."*
   - Adding screen capture would require formally reversing this product commitment and rewriting all user-facing privacy disclosures.
3. **Preservation of Existing Audio Privacy Requirements:**
   - Live assistance audio is strictly one-way (child-to-parent), child-consented ("Join now" tap), protected by a visible green dot and persistent notification, and **never recorded to disk**.

---

## 2. Four Architecture Options Under Review

| Option | Architecture | Key Advantages | Critical Risks & Blockers |
|---|---|---|---|
| **Option A** | **Exclude Both Mirroring & Recording** (Recommended) | - 100% upholds existing privacy promises.<br/>- Zero cloud storage or media liability.<br/>- Zero battery or network overhead.<br/>- Allows 100% focus on P0 release blockers. | - Competitors (AirDroid, mSpy) advertise screen mirroring; HAVEN will not compete on screen capture. |
| **Option B** | **Allow Live Screen Mirroring Only** | - Enables real-time child visual assistance.<br/>- Ephemeral stream; no media stored in cloud.<br/>- Encrypted peer-to-peer via DTLS-SRTP. | - Requires rewriting all child privacy promises.<br/>- Mandates per-session OS consent dialog.<br/>- High battery and bandwidth consumption.<br/>- Hardware encoder unproven on Realme RMX2161. |
| **Option C** | **Allow Live Mirroring & Recording** | - Provides asynchronous parental playback of video clips and screenshots. | - **Severe Privacy & Legal Risk:** Captures banking, passwords, and private chats.<br/>- Requires Supabase Storage, KMS encryption, and retention sweeps.<br/>- Massive regulatory liability (COPPA, GDPR-K). |
| **Option D** | **Defer Both Features to Future Milestone** | - Neither feature in current release.<br/>- Leaves architectural choice open for post-release re-evaluation. | - Defers the final decision rather than establishing a permanent product boundary. |

---

## 3. Practical Distinction: Option A vs. Option D

- **Option A (Formal Product Exclusion):** Ratifies the 2026-10-27 owner ruling as a permanent product principle. HAVEN positions itself as a transparent, child-consented safety tool that refuses to build screen surveillance or capture private communications. Any future reversal would require a full product re-charter.
- **Option D (Milestone Deferral):** Acknowledges that screen capture cannot be built or tested for the current release due to active P0 release blockers, but leaves open the possibility of building live screen sharing (Option B) or recording (Option C) in a post-release phase.

---

## 4. Advisory Recommendation and Rationale

### Recommendation
**OPTION A — EXCLUDE BOTH SCREEN MIRRORING AND RECORDING FROM PRODUCT SCOPE.**

*(If the owner prefers to retain future flexibility without permanent exclusion, the alternative recommendation is **Option D — Defer Both Features to a Future Milestone**.)*

### Rationale
1. **Preserving User Trust & Compliance:** Upholding the "never records video or takes screenshots" promise prevents ethical and regulatory issues regarding the interception of minors' private communications.
2. **Technical Feasibility & Release Stability:** Option A eliminates the need to build and maintain complex MediaProjection services, video encoders, storage buckets, and retention daemons.
3. **Resource Focus on Active P0 Blockers:** Engineering capacity must remain focused on:
   - **DEC-02:** 4 unapplied hosted migrations and Edge Function deployments.
   - **DEC-03:** 75/75 controlled Android QA rows `NOT RUN`.
   - **DEC-12:** Screen time daily limit enforcement logic.
   - **DEC-13:** Production release signing key and Device Owner safe-exit mechanism.

---

## 5. Privacy, Security, and Technical Risks

1. **Unrelated Sensitive Data Exposure (Options B & C):** Screen capture mirrors everything on the child's screen, including private messaging with third parties, two-factor authentication codes, health searches, and banking details.
2. **Android Invariants (Options B & C):** Android enforces strict system-level indicators that cannot be suppressed:
   - Interactive system prompt on every session.
   - Persistent status bar capture chip and ongoing notification.
   - Blackout of secure windows (`FLAG_SECURE`).
3. **Storage & Data Breach Risk (Option C):** Storing video clips of children's phones creates an attractive target for account takeovers and family boundary breaches.
4. **Hardware Encoder Risk:** On budget devices (e.g. Realme RMX2161, ColorOS Android 11+), hardware video encoding under MediaProjection is unproven and prone to SELinux denial.

---

## 6. Open Owner Questions Requiring Explicit Selection

The project owner must review `docs/dec-16-screen-mirroring-recording-owner-decision.md` and explicitly decide:

1. **Which option is formally selected for DEC-16?**
   - Option A: Exclude both screen mirroring and recording from product scope.
   - Option B: Allow live screen mirroring only; recording excluded.
   - Option C: Allow live mirroring and recording, subject to additional privacy and security requirements.
   - Option D: Defer both features to a future milestone.
2. **Product Identity Alignment:** Does the owner confirm that HAVEN should remain a privacy-respecting, child-consented assistance platform rather than a screen-surveillance tool?

---

## 7. Strict Governance & Compliance Statement

- **DEC-16 remains strictly PROPOSED.**
- No feature was implemented.
- No Kotlin, Dart, TypeScript, or SQL source file was modified.
- No Android services, permissions, or manifest entries were added.
- No Supabase migrations were created or applied.
- No Edge Functions were deployed.
- No APK was compiled, no Gradle task was run, and no ADB command was issued.
- No hardware device or emulator was accessed or provisioned.
- No git state-changing commands (`add`, `commit`, `push`, `reset`, `clean`, `checkout`, `restore`, or `stash`) were executed.
- Workspace integrity is 100% preserved.

**STOPPED. Awaiting explicit owner decision on DEC-16.**

