# Phase 9.9.2: Locked-Screen Audio Evidence Precision Correction Report

**Document class:** Evidence Accuracy Precision & Governance Report.  
**Task Reference:** Phase 9.9.2 (Locked-Screen Audio Evidence Precision Correction).  
**Repository:** `D:\parentcontrol_app` (`main`).  
**Backend Project:** Supabase `parent-control-prod` (`hhqgreaoqulmfwfwarhc`).  
**Date:** 2026-11-05.  
**Companion Documents:**
- Ratified Decision Record: [`docs/phase9-9-dec16-owner-approval-record.md`](phase9-9-dec16-owner-approval-record.md)
- Ratified Detailed Specification: [`docs/dec-16-screen-mirroring-recording-owner-decision.md`](dec-16-screen-mirroring-recording-owner-decision.md)
- Evidence Accuracy Report: [`docs/phase9-9-1-evidence-accuracy-correction-report.md`](phase9-9-1-evidence-accuracy-correction-report.md)
- Governance Registers: [`phase-9-owner-decision-register.md`](../phase-9-owner-decision-register.md) and [`docs/implementation/phase-9-owner-decision-register.md`](implementation/phase-9-owner-decision-register.md)
- P0 Specifications: [`docs/p0-decision-specifications.md`](p0-decision-specifications.md)
- Historical Physical Evidence Reports:
  - [`docs/mic_only_test_report.md`](mic_only_test_report.md)
  - [`docs/runtime-mic-test-report.md`](runtime-mic-test-report.md)
  - [`docs/runtime-failure-analysis.md`](runtime-failure-analysis.md)
  - [`docs/stage5_background_audio_survival_report.md`](stage5_background_audio_survival_report.md)
  - [`phase-8-android-qa-report.md`](../phase-8-android-qa-report.md)

---

## 1. Objective & Purpose

This report formalizes a narrowly scoped documentation-only accuracy correction to eliminate ambiguous or oversimplified summaries of locked-screen audio survival across the HAVEN Parental Control governance documents.

Earlier reports tended to either collapse the locked-screen status into a single generic "FAIL" (based on Build 4005) or risk over-generalizing a later two-minute survival observation into an unverified claim of long-duration endurance. Phase 9.9.2 establishes complete factual precision by explicitly distinguishing:
1. The earlier Build 4005 screen-off failure.
2. The candidate microphone foreground service (FGS) fix status (existed in worktree; untested in installed APK; runtime behavior unverified).
3. The later limited two-minute locked-screen observation on Stage 8.
4. The untested status of 5-minute and 15-minute locked-screen endurance criteria.
5. The independent hosted Edge Function clock expiry at 8 minutes 14 seconds (backend failure, distinct from device audio capture).
6. The unverified status of long-duration locked-screen audio reliability.

**Strict Governance Invariant:** Zero implementation, zero device operations, zero APK builds, zero ADB commands, zero hosted Supabase changes, and zero Git state mutations occurred during this pass.

---

## 2. Historical Physical Evidence Breakdown

### 2.1 Build 4005 Evidence (2026-10-28)
- **Tested Hardware:** Child physical device Realme 7 (`RMX2161`, Android 12 / ColorOS 12.1, API 31); Parent emulator `emulator-5554` (API 37).
- **Installed Artifact:** `versionCode 4005`, `versionName 1.0.0` (debug APK).
- **Defect MIC-01:** The installed APK lacked `FOREGROUND_SERVICE_MICROPHONE` permission and had no service declared with `foregroundServiceType="microphone"` in `AndroidManifest.xml` ([`mic_only_test_report.md:86`](mic_only_test_report.md#L86)).
- **Screen-Off Behavior (Case 6.3):** Power key pressed at 12:07:11; Keyguard reported `onStartedGoingToSleep` at 12:07:10. Child audio capture stopped immediately (appops last access 12:07:10, no `(running)` flag, `AudioIn_66` went to standby; parent playout decayed to level 0 by 12:07:42, [`mic_only_test_report.md:139`](mic_only_test_report.md#L139)).
- **Candidate Fix Status:** The candidate microphone FGS fix existed in the worktree but remains **NOT TESTED in the installed APK**. No successful runtime verification of the candidate fix is available in the reviewed evidence ([`mic_only_test_report.md:47, 87, 145, 166`](mic_only_test_report.md#L47)).

### 2.2 Later Stage 8 Test Evidence
- **Two-Minute Locked-Screen Observation (Case D1):** Tested on physical child hardware. Screen locked for 2 minutes (120 seconds, 17:34:40–17:36:40Z). `mWakefulness=Asleep` held, RTP audio stream continued with +7,084 packets transmitted (~50.2 pkts/sec). Classified as a **LIMITED PASS / SURVIVED 2 MINUTES** ([`runtime-mic-test-report.md:123`](runtime-mic-test-report.md#L123)).
- **Five-Minute & Fifteen-Minute Locked Endurance (Case D4):** Case D4 ("Lock both 5/15 min") was not reached during testing and was formally recorded as **NOT TESTED** ([`runtime-mic-test-report.md:126`](runtime-mic-test-report.md#L126)).
- **Separate Fifteen-Minute Endurance Run (Case B3):** Tested under background execution (12:08:24–12:16:38Z). Media ran continuously for **8 minutes 14 seconds** (494 seconds). At 12:16:38.393Z, the session was terminated by hosted defect **F1** ([`runtime-mic-test-report.md:95`](runtime-mic-test-report.md#L95)).

---

## 3. Clear Separation of Technical Failure Domains

To maintain rigorous technical clarity, failure domains must never be conflated:

```
+-----------------------------------------------------------------------------------+
|                           DEVICE / ANDROID RUNTIME DOMAIN                         |
|                                                                                   |
|  - Build 4005: Screen-off failed immediately (Defect MIC-01; no mic FGS).         |
|  - Candidate FGS fix: Existed in worktree; NOT TESTED in installed APK.           |
|  - Stage 8 Case D1: Survived 2-minute lock (120 s, 17:34:40-17:36:40Z).           |
|  - Stage 8 Case D4: 5-minute / 15-minute lock NOT TESTED.                         |
|  - Process survival: Child FGS held capture for 8m14s until server tear-down.     |
+-----------------------------------------------------------------------------------+
                                          |
                                          | [Transport: LAN STUN / WebRTC Signaling]
                                          v
+-----------------------------------------------------------------------------------+
|                           HOSTED SUPABASE BACKEND DOMAIN                          |
|                                                                                   |
|  - Hosted Edge Function: `remote-session` (pre-fix) stamped `expires_at = +30m`.  |
|  - Clock Expiry Defect F1: Next API call after 12:16:38Z flipped session to       |
|    `status='expired'`, terminating WebRTC media from the server side.             |
|  - Scope Reality: The 8m14s cutoff was a HOSTED CLOCK EXPIRY, NOT a device       |
|    microphone crash, process termination, or Android OS freeze.                  |
+-----------------------------------------------------------------------------------+
```

### Key Analytical Invariants:
1. **Hosted clock expiry does NOT prove device microphone failure:** Child-side background survival held for the full 8m14s until the backend flipped the session state to expired (`runtime-mic-test-report.md:224`).
2. **Two-minute lock survival does NOT prove long-duration reliability:** 120 seconds of survival in an unisolated sequence does not satisfy 5-minute or 15-minute endurance requirements.
3. **Build 4005 failure does NOT prove permanent Android impossibility:** The failure was tied directly to missing manifest FGS declarations (`MIC-01`), which candidate code aimed to address.
4. **All 75 QA rows remain NOT RUN under DEC-03:** Historical Stage 8 logs do not substitute for formal QA execution.

---

## 4. Evidence Classification Taxonomy

| Investigation Item | Evidence-Qualified Classification | Evidentiary Source |
|---|---|---|
| **Build 4005 Screen-Off Operation** | `FAILED in tested environment` | `mic_only_test_report.md:89, 139` |
| **Candidate Microphone FGS Fix** | `Existed in worktree; NOT TESTED in installed APK (runtime unverified)` | `mic_only_test_report.md:47, 87, 166` |
| **Stage 8 Two-Minute Lock Interval** | `LIMITED PASS / SURVIVED 2 MINUTES` | `runtime-mic-test-report.md:123` |
| **Five-Minute Locked Endurance** | `NOT TESTED` | `runtime-mic-test-report.md:126` |
| **Fifteen-Minute Locked Endurance** | `NOT TESTED as isolated acceptance criterion` | `runtime-mic-test-report.md:126, 175` |
| **Separate 15-Minute Run (8m14s)** | `FAILED due to hosted Edge Function clock expiry (Defect F1)` | `runtime-mic-test-report.md:95`; `runtime-failure-analysis.md:45` |
| **Long-Duration Locked Reliability** | `NOT VERIFIED` | Synthesized cross-report finding |

---

## 5. Approved Standard Wording Formulations

The following exact text blocks were ratified for use across the repository:

### 5.1 Full Wording Formulation (Prose & Section Analysis)
> **Locked-Screen Audio Survival — Evidence-Qualified Status**  
> Build 4005 failed immediately upon screen-off in the tested environment. A later Stage 8 test survived a two-minute locked-screen interval. Five-minute and fifteen-minute locked-screen endurance tests remain NOT TESTED as isolated locked-screen acceptance criteria. The separate fifteen-minute endurance run failed at 8 minutes 14 seconds due to hosted Edge Function clock expiry. Long-duration locked-screen audio reliability remains NOT VERIFIED.

### 5.2 Condensed Formulation (Table Cells)
> Build 4005 screen-off failure; later two-minute lock survival observed. Five-minute and fifteen-minute locked-screen endurance NOT TESTED. Long-duration reliability NOT VERIFIED.

---

## 6. Audit and Corrections Applied Across Documentation

### 6.1 `docs/phase9-9-dec16-owner-approval-record.md`
- **Location:** Section 5, Item 1 (Line 77).
- **Before:**
  ```markdown
  ...recorded a foreground-service build failure (`MIC-01`), background failure (~24s survival), locked-screen failure, lack of observed OS green microphone privacy dot on ColorOS, and notification channel default importance `NONE`. A candidate build fix existed in the tree but was **NOT TESTED**, and end-to-end assistance remains unexecuted on physical hardware with all 75 QA rows **NOT RUN** under DEC-03.
  ```
- **After:**
  ```markdown
  ...recorded a foreground-service build failure (`MIC-01`), background failure (~24s survival), lack of observed OS green microphone privacy dot on ColorOS, and notification channel default importance `NONE`. A candidate build fix existed in the tree but was **NOT TESTED**. Regarding locked-screen operation: Build 4005 failed immediately upon screen-off in the tested environment. A later Stage 8 test survived a two-minute locked-screen interval. Five-minute and fifteen-minute locked-screen endurance tests remain NOT TESTED as isolated locked-screen acceptance criteria. The separate fifteen-minute endurance run failed at 8 minutes 14 seconds due to hosted Edge Function clock expiry. Long-duration locked-screen audio reliability remains NOT VERIFIED. Overall end-to-end assistance remains unexecuted on physical hardware with all 75 QA rows **NOT RUN** under DEC-03.
  ```

### 6.2 `docs/dec-16-screen-mirroring-recording-owner-decision.md`
- **Location:** Section 7, Item 2 (Line 248).
- **Before:**
  ```markdown
  (Note: tested build 4005 failed foreground-service start with `MIC-01`; candidate fix untested).
  ```
- **After:**
  ```markdown
  (Note: tested build 4005 failed foreground-service start with `MIC-01`, with immediate screen-off failure; candidate fix untested. A later Stage 8 test survived a two-minute locked-screen interval, but five-minute and fifteen-minute locked-screen endurance remain NOT TESTED; long-duration locked-screen reliability remains NOT VERIFIED).
  ```

### 6.3 `docs/phase9-9-1-evidence-accuracy-correction-report.md`
- **Location:** Section 2 Table, Row 49 (Line 49) & Section 3.1 Item 3 (Line 74).
- **Adjustments:**
  - Table Row 49 updated to use the exact condensed status: `Build 4005 screen-off failure; later two-minute lock survival observed. Five-minute and fifteen-minute locked-screen endurance NOT TESTED. Long-duration reliability NOT VERIFIED.`
  - Ground truth cell expanded to reflect the full evidence-qualified status.
  - Section 3.1 Item 3 quotation aligned with the updated `phase9-9-dec16-owner-approval-record.md:77` wording.

### 6.4 `docs/p0-decision-specifications.md`
- **Location:** Section 6, Row 5 (Line 363).
- **Before:**
  ```markdown
  | 5 | **Runtime validation** | 75 QA rows are 100% `NOT RUN` (VERIFIED by count this pass) and the microphone items failed on build 4005 | **BLOCKED by DEC-03** — cannot start without explicit owner authorisation |
  ```
- **After:**
  ```markdown
  | 5 | **Runtime validation** | 75 QA rows are 100% `NOT RUN` (VERIFIED by count this pass); microphone items failed on build 4005 (later 2-min lock survival observed; 5m/15m locked endurance NOT TESTED; long-duration reliability NOT VERIFIED) | **BLOCKED by DEC-03** — cannot start without explicit owner authorisation |
  ```

### 6.5 Governance Registers Verification
- **Files Inspected:** `phase-9-owner-decision-register.md` and `docs/implementation/phase-9-owner-decision-register.md`.
- **Finding:** Neither register contained an inaccurate or oversimplified locked-screen summary. Line 353 accurately states: *"and the audio/microphone findings from Phase 8 remain exactly as recorded there (tested-build foreground-service microphone failure, candidate fix NOT TESTED)"*.
- **Action:** Under the Section 10 instruction ("Do not modify governance registers unless an inaccurate locked-screen claim actually exists in them"), both register files were left unmodified.
- **Byte-Identity & Hashes Preserved:**
  - `phase-9-owner-decision-register.md`: `3A5D136B0F03331A41A465962841F88651E43A10FE37D435D9CE46865122BF0F`
  - `docs/implementation/phase-9-owner-decision-register.md`: `3A5D136B0F03331A41A465962841F88651E43A10FE37D435D9CE46865122BF0F`

---

## 7. Master Decision Status Register Snapshot (DEC-01 through DEC-16)

All owner decisions remain unchanged:

| Decision ID | Description | Registered Governance Status | Owner Ruling & Authority Scope |
|---|---|---|---|
| **DEC-01** | Phase 5 Evidence Durability | **APPROVED (Choice B)** | Local-only evidence accepted. GAP DUR-01 remains OPEN. |
| **DEC-02** | Hosted Migration & Deployment Authorization | **PENDING / BLOCKED** | **P1 Release Blocker.** Stage 7 migration pair reconciled historical evidence only; 4 repository migrations (`20261030000100`, `20261030000200`, `20261030000300`, `20261103000100`), 5 preflights, and 3 Edge Functions (`account`, `family-admin`, `device-command`) unapplied. |
| **DEC-03** | Android QA Hardware Testing | **PENDING / BLOCKED** | **P1 Release Blocker.** 75/75 QA matrix rows remain strictly `NOT RUN`. Two-minute lock observation is historical only. |
| **DEC-04** | Preflight Formulation | **READY / CARRIED FORWARD** | Preflight queries formulated; execution gated by DEC-02. |
| **DEC-05** | Retention Sweep Scheduler | **APPROVED (Choice B)** | Standing on-demand policy only. Automated cron/schedulers prohibited. |
| **DEC-06–11** | Historical Architecture Records | **CARRIED FORWARD** | Retained as reviewed baseline / standby specifications. |
| **DEC-12** | Screen-Time & Bedtime Enforcement Integrity | **APPROVED (D1-B, B1-B, O1-C, P1-A, DEFER)** | Approved with 10-minute emergency pass, mode-split enforcement, and deferred remediation. |
| **DEC-13** | Device Owner & Managed Mode Strategy | **APPROVED (Option B)** | Approved with mandatory safe-exit release blocker and DA retirement. Keystore creation deferred. |
| **DEC-14** | Push Notifications / FCM Delivery | **APPROVED (Option B)** | Realtime + FCM non-authoritative wake-up transport. Parent alerts only; child push excluded. Implementation gated. |
| **DEC-15** | Website Filtering Scope & Architecture | **APPROVED (Option D: Deferred)** | Website filtering excluded from current release. Options A, B, C not selected. No implementation authorized. |
| **DEC-16** | Screen Mirroring & Recording Scope | **APPROVED (Option A: Excluded)** | Screen mirroring, recording, and screenshots formally excluded from product scope. Options B, C, D not selected. Zero code added. |

---

## 8. Remaining Unknowns & Verification Gaps

1. **Long-Duration Lock Reliability:** Long-duration locked-screen audio capture (5 minutes, 15 minutes, 30 minutes) on OEM Android builds (specifically Realme ColorOS aggressive task killing and doze modes) has never been successfully verified.
2. **Candidate FGS Fix Verification:** The candidate microphone FGS fix existed in the worktree but remains NOT TESTED in the installed APK. No successful runtime verification of the candidate fix is available in the reviewed evidence.
3. **Hardware Audibility:** RTP packet transmission was observed through packet-counter deltas. Successful human-audible playback on the parent device remains NOT TESTED / NOT VERIFIED (`mic_only_test_report.md:118`).
4. **Network Relay:** Operation across disparate networks requires a dedicated TURN relay (`F4`), which is currently absent.
5. **DEC-03 Block:** All runtime hardware verification remains strictly prohibited until explicit owner sign-off on DEC-03.

---

## 9. Implementation & Operational Boundary Confirmation

In strict compliance with the Phase 9.9.2 mandate:
- **Zero application code was modified:** No Dart, Kotlin, TypeScript, or SQL source files were edited.
- **Zero manifest or service changes occurred:** `AndroidManifest.xml` and Android services remain untouched.
- **Zero hosted Supabase mutations occurred:** No SQL was run, no schemas modified, and no Edge Functions deployed.
- **Zero Firebase provisioning occurred:** No Firebase projects or credentials were created.
- **Zero device operations occurred:** No APK was built, no Gradle task was run, no ADB command was issued, and no device was provisioned or tested.
- **Zero Git state mutations occurred:** No `git add`, `commit`, `push`, `reset`, `checkout`, `restore`, or `stash` commands were run.
- **Phase 10 was NOT started.**

**STOPPED. Locked-screen audio evidence precision correction is complete.**

