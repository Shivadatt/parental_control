# Phase 9.7: DEC-15 Owner Approval Recording & Scope Exclusion Report

**Document class:** Owner Decision Record & Governance Consolidation.  
**Decision Reference:** DEC-15 (Website Filtering Scope & Architecture).  
**Owner Ruling:** **APPROVED — Option D (Defer Website Filtering for the Current Release).**  
**Approval Date:** 2026-11-05 (Phase 9.7).  
**Repository:** `D:\parentcontrol_app` (`main`).  
**Backend Project:** Supabase `parent-control-prod` (`hhqgreaoqulmfwfwarhc`).  
**Companion Documents:**
- Detailed Ratified Specification: [`docs/dec-15-website-filtering-owner-decision.md`](dec-15-website-filtering-owner-decision.md)
- Decision Readiness Audit: [`docs/phase9-6-dec15-website-filtering-decision-readiness.md`](phase9-6-dec15-website-filtering-decision-readiness.md)
- Governance Registers: [`phase-9-owner-decision-register.md`](../phase-9-owner-decision-register.md) and [`docs/implementation/phase-9-owner-decision-register.md`](implementation/phase-9-owner-decision-register.md)
- P0 Specifications: [`docs/p0-decision-specifications.md`](p0-decision-specifications.md)

---

## 1. Owner Decision and Exact Ruling

On 2026-11-05, during Phase 9.7, the project owner reviewed the technical audit, architectural evaluation, and comparison matrix in `docs/dec-15-website-filtering-owner-decision.md` and explicitly recorded the following ruling:

> **DEC-15 Owner Decision: APPROVED — Option D: Defer website filtering for the current release.**

---

## 2. Approved Interpretation and Scope Boundaries

The approved ruling establishes ten binding architectural, product, and governance boundaries:

1. **Current Release Scope Exclusion:** Website filtering (including URL blocklists, domain filtering, category filtering, SafeSearch parameter enforcement, and browsing history collection) is formally excluded from the scope of the current production release.
2. **Options A, B, and C Unselected:**
   - **Option A (DNS-based filtering):** Not selected. No upstream DNS resolver integration or Private DNS (DoT) management is authorized.
   - **Option B (Local VPN-based filtering):** Not selected. No Android `VpnService` loopback or packet-filtering implementation is authorized.
   - **Option C (Managed browser-only filtering):** Not selected. No dedicated browser, WebView wrapper, or custom browsing Activity is authorized.
3. **No Implementation Authorization:** This ruling authorizes documentation, claim qualification, and governance updates only. It does **NOT** authorize writing code, creating database tables, modifying policies, adding Android permissions, building APKs, or testing on hardware.
4. **Product Claim Restrictions:** Existing product claims, marketing materials, app store descriptions, and UI copy must accurately disclose that website filtering is not implemented.
5. **No False Enforcement Advertising:** No device-wide website filtering capability, URL blocking, domain blocking, safe browsing, or HTTPS content inspection may be advertised as available.
6. **Package Suspension Boundary:** Existing application package suspension (`PolicyApplier.kt` via Device Owner `setPackagesSuspended`) must not be represented as website filtering. Suspending a browser package (e.g. `com.android.chrome`) is an application restriction, not a web filter.
7. **Alternative Evaluations Preserved:** The technical assessments of Options A, B, and C in `docs/dec-15-website-filtering-owner-decision.md` are retained as historical evaluations and unselected options. Option D is not an approval of Option A or a future DNS architecture.
8. **Future Reconsideration Prerequisites:** Website filtering may only be reconsidered in a future milestone through a separate, explicit owner decision supported by dedicated scope, threat analysis, and resource planning.
9. **No Release Blocker Interference:** Engineering resources remain concentrated on active P0 release blockers (DEC-02 hosted migrations, DEC-03 Android QA rows, DEC-12 screen time execution, and DEC-13 release signing / safe exit).
10. **Phase 10 Boundary:** This decision does not authorize Phase 10 or any subsequent development phase.

---

## 3. Existing Implementation Audit Summary

The read-only audit completed in Phase 9.6 confirmed that website filtering is **0% implemented** across the repository:

- **Android Subsystem:** Zero lines of VPN code (`VpnService`), DNS resolvers, accessibility scrapers, or browser components exist. Neither `BIND_VPN_SERVICE` nor `BIND_ACCESSIBILITY_SERVICE` is declared in `android/app/src/main/AndroidManifest.xml`.
- **Flutter Client:** Zero Dart models, controllers, repositories, or routes exist for URLs, domains, categories, or web policies.
- **Supabase Backend:** No database tables (`websites`, `domains`, `web_policies`, `browsing_history`) exist in any migration.
- **Backend Policy Validator:** `supabase/functions/_shared/policy.ts:49-77` strictly rejects any web filtering parameter with an HTTP 400 `validation_error`.
- **Canonical Feature Inventory:** `audit/01_COMPLETE_FEATURE_INVENTORY.md` classifies all 25 web-related feature rows (`FD-001` through `FD-014` and `FD-016` through `FD-026`) as `MISSING`, with `FD-015` as `NOT APPLICABLE` (iOS-specific).

---

## 4. Product Claims & Documentation Accuracy Corrections

In accordance with Section 6 of the Phase 9.7 brief, documentation references that previously described website filtering alongside active policy capabilities were reviewed and corrected:

1. **`phase-8-open-gaps.md:84` & `docs/implementation/phase-8-open-gaps.md:84`:**
   - *Previous:* `- Real-time policy push (web filtering, app restrictions, bedtime lock).`
   - *Corrected:* `- Real-time policy push (app restrictions, bedtime lock; web filtering deferred/not implemented per DEC-15).`
2. **`phase-8-regression-matrix.md:113` & `docs/implementation/phase-8-regression-matrix.md:113`:**
   - *Previous:* `| Remote Management & Policy Sync | 26–40 | Web filtering, app blocking, bedtime lock, safe zones | Zero commands issued; devices isolated | **NOT RUN** |`
   - *Corrected:* `| Remote Management & Policy Sync | 26–40 | App blocking, bedtime lock, safe zones (web filtering deferred per DEC-15) | Zero commands issued; devices isolated | **NOT RUN** |`

### Audit of Remaining Marketing, UI, and Onboarding Claims
- **Child Privacy Disclosure ([`child_settings_tab.dart:67-70`](../lib/features/child/tabs/child_settings_tab.dart#L67-L70), [`child_session_page.dart:147`](../lib/features/child/child_session_page.dart#L147)):**
  *"This app never records audio or video, takes screenshots, reads messages, or captures passwords."*
  - **Verdict:** Accurate and compliant. Retained verbatim.
- **Internal Gap Tracking ([`docs/implementation/remaining-gaps.md:59`](implementation/remaining-gaps.md#L59), [`docs/implementation/feature-ownership.md:49`](implementation/feature-ownership.md#L49)):**
  Both files explicitly state that web filtering is "0% implemented / NOT STARTED".
  - **Verdict:** Accurate and compliant. Retained as evidence.

---

## 5. Comprehensive Decision Governance Status Snapshot (Phase 9.7)

| Decision ID | Description | Registered Governance Status | Owner Ruling & Authority Scope |
|---|---|---|---|
| **DEC-01** | Phase 5 Evidence Durability | **APPROVED (Choice B)** | Local-only evidence accepted. GAP DUR-01 remains OPEN. |
| **DEC-02** | Hosted Migration & Deployment Authorization | **PENDING / BLOCKED** | P1 Release Blocker. Stage 7 migrations verified applied hosted. Remaining 4 migrations, preflights, and Edge Functions unapplied. |
| **DEC-03** | Android QA Hardware Testing | **PENDING / BLOCKED** | P1 Release Blocker. 75/75 QA matrix rows remain strictly NOT RUN. |
| **DEC-04** | Preflight Formulation | **READY / CARRIED FORWARD** | Preflight queries formulated; execution gated by DEC-02. |
| **DEC-05** | Retention Sweep Scheduler | **APPROVED (Choice B)** | Standing on-demand policy only. Automated cron/schedulers prohibited. |
| **DEC-06–11** | Historical Architecture Records | **CARRIED FORWARD** | Retained as reviewed baseline / standby specifications. |
| **DEC-12** | Screen-Time & Bedtime Enforcement Integrity | **APPROVED (D1-B, B1-B, O1-C, P1-A, DEFER)** | Approved with 10-minute emergency pass, mode-split enforcement, and deferred remediation. |
| **DEC-13** | Device Owner & Managed Mode Strategy | **APPROVED (Option B)** | Approved with mandatory safe-exit release blocker and DA retirement. |
| **DEC-14** | Push Notifications / FCM Delivery | **APPROVED (Option B)** | Realtime + FCM non-authoritative wake-up transport. Implementation gated. |
| **DEC-15** | Website Filtering Scope & Architecture | **APPROVED (Option D: Deferred)** | Website filtering excluded from current release. Options A, B, C not selected. No implementation authorized. |
| **DEC-16** | Screen Mirroring & Recording Scope | **PROPOSED (Scope Exclusion Confirmed)** | P3 Scope Hygiene. Exclusion confirmed; 3 N/A canonical vs 16 N/A parity preserved. |

---

## 6. Future Website-Filtering Reconsideration Requirements

If the project owner decides to reconsider website filtering in a post-release milestone, the following prerequisites must be fulfilled before any code is authored:

1. **Separate Explicit Owner Decision:** A dedicated written proposal specifying the target architecture (e.g. Option A: DNS-Based via Managed Mode Private DNS).
2. **P0 Prerequisites Resolved:** Closure of DEC-02 (hosted migrations), DEC-03 (Android QA), DEC-12 (screen time enforcement), and DEC-13 (release signing and Device Owner safe-exit).
3. **Upstream Threat Intelligence Evaluation:** Contractual and technical evaluation of upstream DNS filtering providers (CleanBrowsing, Cloudflare, NextDNS).
4. **Policy Schema Migration:** Authoring a dedicated Supabase migration for domain allow/block lists, reviewed and applied under DEC-02.
5. **Privacy Impact Assessment:** Verification that no TLS decryption or payload inspection is introduced, preserving HAVEN's child privacy invariants.

---

## 7. Files Created or Updated in Phase 9.7

| File Path | Action | Description |
|---|---|---|
| `docs/phase9-7-dec15-owner-approval-record.md` | **Created** | Phase 9.7 consolidation report recording owner approval of DEC-15 Option D. |
| `docs/dec-15-website-filtering-owner-decision.md` | **Updated** | Updated status to APPROVED — Option D; recorded ratified ruling, scope exclusions, and unselected options. |
| `phase-9-owner-decision-register.md` | **Updated** | Appended Phase 9.7 addendum recording DEC-15 APPROVED — Option D. |
| `docs/implementation/phase-9-owner-decision-register.md` | **Updated** | Appended byte-identical Phase 9.7 addendum. |
| `docs/p0-decision-specifications.md` | **Updated** | Updated preamble and Section 4 to reflect DEC-15 APPROVED (Option D). |
| `phase-8-open-gaps.md` | **Updated** | Minimal correction to line 84 clarifying web filtering as deferred per DEC-15. |
| `docs/implementation/phase-8-open-gaps.md` | **Updated** | Minimal correction to line 84 mirroring root file. |
| `phase-8-regression-matrix.md` | **Updated** | Minimal correction to line 113 clarifying web filtering as deferred per DEC-15. |
| `docs/implementation/phase-8-regression-matrix.md` | **Updated** | Minimal correction to line 113 mirroring root file. |

---

## 8. Governance Register SHA-256 Verification

Both governance register files were verified to be **100% byte-identical**:

- `phase-9-owner-decision-register.md`
- `docs/implementation/phase-9-owner-decision-register.md`

**Verified SHA-256 Digest:**  
`2810E023EDD167D83CFD12A4F9346B85E7AF951B1B6108216444C40A69884C09`

---

## 9. Strict Implementation Authorization Boundary & Compliance Confirmation

- **DEC-15 is APPROVED — Option D (Scope Exclusion & Deferral).**
- **Zero application code was implemented or modified:** No Kotlin, Dart, TypeScript, or SQL application code was authored.
- **Zero Android services or permissions were added:** No `VpnService`, DNS proxy, or Accessibility Service was introduced.
- **Zero hosted Supabase mutations occurred:** No migrations were run, no tables created, and no Edge Functions deployed.
- **Zero Firebase provisioning occurred:** No Firebase project was created, and no secrets were configured.
- **Zero device operations occurred:** No APK was built, no Gradle task was run, no ADB command was issued, and no device was provisioned or tested.
- **Zero git mutations occurred:** No `git add`, `commit`, `push`, `reset`, `clean`, `checkout`, `restore`, or `stash` commands were run.
- **Phase 10 was NOT started.**

**STOPPED. Awaiting separate explicit owner authorization for any future milestone work.**

