# Phase 9.9.2.1: Microphone FGS Candidate Fix Evidence Wording Correction Report

**Document class:** Evidence Accuracy Precision & Governance Report.  
**Task Reference:** Phase 9.9.2.1 (Microphone FGS Candidate Fix Evidence Wording Correction).  
**Repository:** `D:\parentcontrol_app` (`main`).  
**Backend Project:** Supabase `parent-control-prod` (`hhqgreaoqulmfwfwarhc`).  
**Date:** 2026-11-05.  
**Companion Documents:**
- Ratified Decision Record: [`docs/phase9-9-dec16-owner-approval-record.md`](phase9-9-dec16-owner-approval-record.md)
- Ratified Detailed Specification: [`docs/dec-16-screen-mirroring-recording-owner-decision.md`](dec-16-screen-mirroring-recording-owner-decision.md)
- Locked-Screen Evidence Report: [`docs/phase9-9-2-locked-screen-audio-evidence-correction-report.md`](phase9-9-2-locked-screen-audio-evidence-correction-report.md)
- Evidence Accuracy Report: [`docs/phase9-9-1-evidence-accuracy-correction-report.md`](phase9-9-1-evidence-accuracy-correction-report.md)
- Governance Registers: [`phase-9-owner-decision-register.md`](../phase-9-owner-decision-register.md) and [`docs/implementation/phase-9-owner-decision-register.md`](implementation/phase-9-owner-decision-register.md)
- P0 Specifications: [`docs/p0-decision-specifications.md`](p0-decision-specifications.md)
- Historical Physical Evidence Reports:
  - [`docs/mic_only_test_report.md`](mic_only_test_report.md)
  - [`docs/runtime-mic-test-report.md`](runtime-mic-test-report.md)
  - [`docs/runtime-failure-analysis.md`](runtime-failure-analysis.md)
  - [`phase-8-android-qa-report.md`](../phase-8-android-qa-report.md)

---

## 1. Objective & Purpose

This report formalizes a narrowly scoped documentation-only correction to improve the evidentiary accuracy of statements regarding the candidate microphone Foreground Service (FGS) fix and human audibility verification.

Earlier documentation contained overly broad assertions claiming that the candidate fix "has never been compiled into a testable APK". Such statements exceeded the verified empirical record by speculating on compilation states across all potential APKs, rather than grounding the finding strictly in the tested artifacts. 

Phase 9.9.2.1 replaces these unverified broad claims with precise, evidence-grounded statements:
1. **Candidate FGS Fix Status:** The candidate microphone FGS fix existed in the worktree but remains **NOT TESTED in the installed APK**. No successful runtime verification of the candidate fix is available in the reviewed evidence.
2. **Human Audibility Status:** RTP packet transmission was observed through packet-counter deltas on LAN STUN. Successful human-audible playback on the parent device remains **NOT TESTED / NOT VERIFIED**.

**Strict Governance Invariant:** Zero implementation, zero device operations, zero APK builds, zero ADB commands, zero hosted Supabase mutations, and zero Git state mutations occurred during this pass.

---

## 2. Evidence Grounding & The Four Evidence States

To maintain forensic rigor, repository documentation must strictly distinguish between four distinct technical states:

```
[1. Worktree Presence]
     │  - `AudioAssistanceService.kt` and `FOREGROUND_SERVICE_MICROPHONE` present in source.
     │  - VERIFIED in working tree during Phase 8 report authoring.
     ▼
[2. APK Compilation & Inclusion]
     │  - Fix included in a compiled APK artifact binary.
     │  - Build 4005 did NOT include the candidate fix (installed prior to edits).
     │  - Subsequent compilation state across other builds: NOT CLAIMED / UNVERIFIED.
     ▼
[3. Device Installation]
     │  - APK containing candidate fix installed on physical test hardware.
     │  - Build 4005 installed on Realme 7 lacked the fix (`MIC-01`).
     │  - Installation of candidate fix: NOT ESTABLISHED by reviewed test logs.
     ▼
[4. Runtime Verification]
        - Candidate fix executed and verified functional under physical test conditions.
        - Status: NOT TESTED / NOT VERIFIED.
```

### Empirical Facts from Historical Reports:
- **`docs/mic_only_test_report.md:46-47`:**  
  `These changes are not in the installed 4005 APK (installed 11:28, before the edits)... This audit did not build, install, execute or review these changes, and did not modify them. All live findings below describe build 4005; where the untested worktree contains a candidate fix, the status is NOT TESTED (fix present, unverified).`
- **`docs/mic_only_test_report.md:86-87`:**  
  `Case 3.6: Foreground-service type for microphone — tested build 4005: FAIL — NOT CONFIGURED... Case 3.6b: Foreground-service type for microphone — current worktree: NOT TESTED (fix present).`
- **`docs/mic_only_test_report.md:166`:**  
  `Defect MIC-01: No microphone foreground-service type in build 4005... Fix present in worktree — NOT TESTED (not in the APK under test; not built or exercised).`

---

## 3. Human Audibility Evidence Boundary

Earlier documentation noted that signal-level track packet transmission was observed during tests. Phase 9.9.2.1 reinforces the strict boundary separating network packet transmission from actual audible perception by humans:

- **Empirical Grounding (`docs/mic_only_test_report.md:117-118`):**  
  `Case 5.3: Child audio reaches the parent (actual track statistics): PASS — LIVE VERIFIED. Child ADM level: 5637... Parent ADM: level 14928... Case 5.4: Audible on the parent speaker / stated phrase understood: NOT TESTED. No human listener in this remote run; only signal-level statistics are available. The phrase content cannot be inferred from levels.`
- **Ratified Wording:**  
  > **RTP packet transmission was observed through packet-counter deltas. Successful human-audible playback on the parent device remains NOT TESTED / NOT VERIFIED.**

---

## 4. Exact Before-and-After Wording Corrections

### 4.1 In `docs/phase9-9-2-locked-screen-audio-evidence-correction-report.md`

#### Item A: Section 8, Item 2 (Line 193)
- **Before:**
  ```markdown
  2. **Post-Fix Build Verification:** The worktree candidate fix in `AudioAssistanceService.kt` and `AndroidManifest.xml` has never been compiled into a testable APK and executed against physical hardware under controlled lock-screen conditions.
  ```
- **After:**
  ```markdown
  2. **Candidate FGS Fix Verification:** The candidate microphone FGS fix existed in the worktree but remains NOT TESTED in the installed APK. No successful runtime verification of the candidate fix is available in the reviewed evidence.
  ```

#### Item B: Section 8, Item 3 (Line 194)
- **Before:**
  ```markdown
  3. **Hardware Audibility:** Track packet transmission and signal level deltas (ICE/ADM) have been observed, but human audibility on parent speakers remains unverified (`NOT TESTED`, `mic_only_test_report.md:118`).
  ```
- **After:**
  ```markdown
  3. **Hardware Audibility:** RTP packet transmission was observed through packet-counter deltas. Successful human-audible playback on the parent device remains NOT TESTED / NOT VERIFIED (`mic_only_test_report.md:118`).
  ```

#### Item C: Section 1 (Line 29), Section 2.1 (Line 46), Section 3 Diagram (Line 64), Section 4 Table (Line 96)
- **Adjustments:** Replaced generic "untested" or "not tested on build 4005" with explicit wording: `existed in worktree; NOT TESTED in installed APK (runtime unverified)`.

---

### 4.2 In `docs/phase9-9-dec16-owner-approval-record.md`

#### Section 5, Item 1 (Line 77)
- **Before:**
  ```markdown
  ...A candidate build fix existed in the tree but was **NOT TESTED**. Regarding locked-screen operation: Build 4005 failed immediately upon screen-off in the tested environment...
  ```
- **After:**
  ```markdown
  ...The candidate microphone FGS fix existed in the worktree but remains **NOT TESTED in the installed APK**; no successful runtime verification of the candidate fix is available in the reviewed evidence. Regarding locked-screen operation: Build 4005 failed immediately upon screen-off in the tested environment. A later Stage 8 test survived a two-minute locked-screen interval. Five-minute and fifteen-minute locked-screen endurance tests remain NOT TESTED as isolated locked-screen acceptance criteria. The separate fifteen-minute endurance run failed at 8 minutes 14 seconds due to hosted Edge Function clock expiry. Long-duration locked-screen audio reliability remains NOT VERIFIED. Furthermore, while RTP packet transmission was observed through packet-counter deltas, successful human-audible playback on the parent device remains NOT TESTED / NOT VERIFIED. Overall end-to-end assistance remains unexecuted on physical hardware with all 75 QA rows **NOT RUN** under DEC-03.
  ```

---

### 4.3 In `docs/dec-16-screen-mirroring-recording-owner-decision.md`

#### Section 7, Item 2 (Line 248)
- **Before:**
  ```markdown
  (Note: tested build 4005 failed foreground-service start with `MIC-01`, with immediate screen-off failure; candidate fix untested. A later Stage 8 test survived a two-minute locked-screen interval, but five-minute and fifteen-minute locked-screen endurance remain NOT TESTED; long-duration locked-screen reliability remains NOT VERIFIED).
  ```
- **After:**
  ```markdown
  (Note: tested build 4005 failed foreground-service start with `MIC-01`, with immediate screen-off failure. The candidate microphone FGS fix existed in the worktree but remains NOT TESTED in the installed APK; no successful runtime verification of the candidate fix is available in the reviewed evidence. A later Stage 8 test survived a two-minute locked-screen interval, but five-minute and fifteen-minute locked-screen endurance remain NOT TESTED; long-duration locked-screen reliability remains NOT VERIFIED).
  ```

#### Section 7, Item 5 (Line 251)
- **Before:**
  ```markdown
  (Note: runtime stream verified indirectly via ICE/ADM/RTP deltas on LAN STUN only; human audibility unproven; TURN relay absent).
  ```
- **After:**
  ```markdown
  (Note: RTP packet transmission was observed through packet-counter deltas on LAN STUN only. Successful human-audible playback on the parent device remains NOT TESTED / NOT VERIFIED; TURN relay absent).
  ```

---

### 4.4 In `docs/phase9-9-1-evidence-accuracy-correction-report.md`

#### Section 2 Table, Row 47 & Row 52; Section 3.1 Item 3 (Line 74)
- **Adjustments:**
  - Row 47: Updated to reflect that candidate fix in worktree remains `NOT TESTED in installed APK (runtime unverified)`.
  - Row 52: Ground truth and status updated to reflect: `RTP packet transmission was observed through packet-counter deltas on LAN STUN only. Successful human-audible playback on the parent device remains NOT TESTED / NOT VERIFIED`.
  - Section 3.1 Item 3: Aligned with the updated quote in `phase9-9-dec16-owner-approval-record.md:77`.

---

## 5. Files Updated in Phase 9.9.2.1

| File Path | Action | Description |
|---|---|---|
| [`docs/phase9-9-2-1-microphone-fgs-evidence-wording-correction-report.md`](file:///d:/parentcontrol_app/docs/phase9-9-2-1-microphone-fgs-evidence-wording-correction-report.md) | **Created** | Comprehensive report documenting the FGS candidate fix wording correction and human audibility boundaries. |
| [`docs/phase9-9-2-locked-screen-audio-evidence-correction-report.md`](file:///d:/parentcontrol_app/docs/phase9-9-2-locked-screen-audio-evidence-correction-report.md) | **Updated** | Corrected Section 8 Items 2 & 3, Section 1, Section 2.1, Section 3, and Section 4 table. |
| [`docs/phase9-9-dec16-owner-approval-record.md`](file:///d:/parentcontrol_app/docs/phase9-9-dec16-owner-approval-record.md) | **Updated** | Refined Section 5 Item 1 to accurately qualify FGS candidate fix and human audibility. |
| [`docs/dec-16-screen-mirroring-recording-owner-decision.md`](file:///d:/parentcontrol_app/docs/dec-16-screen-mirroring-recording-owner-decision.md) | **Updated** | Refined Section 7 Items 2 & 5 with exact approved FGS fix and human audibility text. |
| [`docs/phase9-9-1-evidence-accuracy-correction-report.md`](file:///d:/parentcontrol_app/docs/phase9-9-1-evidence-accuracy-correction-report.md) | **Updated** | Synchronized table rows 47 & 52 and Section 3 quotation. |
| [`phase-9-owner-decision-register.md`](file:///d:/parentcontrol_app/phase-9-owner-decision-register.md) | **Preserved** | Checked; contains no inaccurate compilation claims. Byte-identical mirror preserved. |
| [`docs/implementation/phase-9-owner-decision-register.md`](file:///d:/parentcontrol_app/docs/implementation/phase-9-owner-decision-register.md) | **Preserved** | Byte-identical with root register (SHA-256: `3A5D136B0F03331A41A465962841F88651E43A10FE37D435D9CE46865122BF0F`). |

---

## 6. Decision Governance & Blocker Status

All owner decisions remain strictly preserved:

| Decision ID | Description | Registered Governance Status | Owner Ruling & Authority Scope |
|---|---|---|---|
| **DEC-01** | Phase 5 Evidence Durability | **APPROVED (Choice B)** | Local-only evidence accepted. GAP DUR-01 remains OPEN. |
| **DEC-02** | Hosted Migration & Deployment Authorization | **PENDING / BLOCKED** | **P1 Release Blocker.** 4 repository migrations, 5 preflights, and 3 Edge Functions unapplied. |
| **DEC-03** | Android QA Hardware Testing | **PENDING / BLOCKED** | **P1 Release Blocker.** 75/75 QA matrix rows remain strictly `NOT RUN`. |
| **DEC-05** | Retention Sweep Scheduler | **APPROVED (Choice B)** | Standing on-demand policy only. Automated cron/schedulers prohibited. |
| **DEC-06–11** | Historical Architecture Records | **CARRIED FORWARD** | Retained as reviewed baseline / standby specifications. |
| **DEC-12** | Screen-Time & Bedtime Enforcement Integrity | **APPROVED (D1-B, B1-B, O1-C, P1-A, DEFER)** | Approved with 10-minute emergency pass, mode-split enforcement, and deferred remediation. |
| **DEC-13** | Device Owner & Managed Mode Strategy | **APPROVED (Option B)** | Approved with mandatory safe-exit release blocker and DA retirement. |
| **DEC-14** | Push Notifications / FCM Delivery | **APPROVED (Option B)** | Realtime + FCM non-authoritative wake-up transport. Governs parent alerts only; child push excluded. |
| **DEC-15** | Website Filtering Scope & Architecture | **APPROVED (Option D: Deferred)** | Website filtering excluded from current release. Options A, B, C not selected. No implementation authorized. |
| **DEC-16** | Screen Mirroring & Recording Scope | **APPROVED (Option A: Excluded)** | Screen mirroring, recording, and screenshots formally excluded from product scope. |

---

## 7. Remaining Unknowns & Evidence Gaps

1. **Candidate Fix Compilation & Runtime Status:** The candidate microphone FGS fix existed in the worktree, but its inclusion in an installed APK and its runtime behavior on physical hardware are NOT VERIFIED by the reviewed evidence.
2. **Human Audibility:** RTP packet transmission was observed through packet-counter deltas on LAN STUN, but successful human-audible playback on parent speakers remains NOT TESTED / NOT VERIFIED (`mic_only_test_report.md:118`).
3. **Long-Duration Lock Reliability:** Long-duration locked-screen audio capture (5m, 15m, 30m) remains NOT TESTED / NOT VERIFIED.
4. **Relayed Audio Transport:** Operation across disparate networks requires a dedicated TURN relay (`F4`), which is currently absent.
5. **DEC-03 Block:** All runtime hardware verification remains strictly prohibited until explicit owner sign-off on DEC-03.

---

## 8. Implementation & Operational Boundary Confirmation

In strict compliance with project governance instructions:
- **Zero application code was modified:** No Dart, Kotlin, TypeScript, or SQL source files were altered.
- **Zero Android service or manifest changes occurred:** `AndroidManifest.xml` and Kotlin services remain untouched.
- **Zero hosted Supabase mutations occurred:** No SQL migrations were run, no schemas modified, and no Edge Functions deployed.
- **Zero Firebase provisioning occurred:** No Firebase projects or credentials were created.
- **Zero device operations occurred:** No APK was built, no Gradle task was executed, no ADB command was run, and no hardware was paired or tested.
- **Zero Git state mutations occurred:** No `git add`, `commit`, `push`, `reset`, `checkout`, `restore`, or `stash` operations were executed.
- **Phase 10 was NOT started.**

**STOPPED. Documentation precision correction for Phase 9.9.2.1 is complete.**

