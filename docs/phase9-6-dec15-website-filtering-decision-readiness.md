# Phase 9.6: DEC-15 Website Filtering Decision Readiness Report

**Document class:** Technical Audit & Decision Readiness Consolidation.  
**Decision Reference:** DEC-15 (Website Filtering Scope & Architecture).  
**Current Governance Status:** **PROPOSED — AWAITING EXPLICIT OWNER SELECTION.**  
**Authored Date:** 2026-11-05 (Phase 9.6).  
**Repository:** `D:\parentcontrol_app` (`main`).  
**Backend Reference:** Supabase `parent-control-prod` (`hhqgreaoqulmfwfwarhc`).  
**Primary Deliverable:** [`docs/dec-15-website-filtering-owner-decision.md`](dec-15-website-filtering-owner-decision.md).

---

## 1. Executive Summary & Audit Baseline

Phase 9.6 conducted an exhaustive, read-only technical audit of the HAVEN repository to establish the baseline for **DEC-15 (Website Filtering Scope & Architecture)**.

### Key Audit Findings:
1. **0% Implementation Across All Layers:**
   - **Android Native:** Zero lines of VPN code (`VpnService`), DNS resolvers, accessibility scrapers, or browser components exist. Neither `BIND_VPN_SERVICE` nor `BIND_ACCESSIBILITY_SERVICE` is declared in `android/app/src/main/AndroidManifest.xml`.
   - **Flutter Application:** Zero Dart models, UI pages, controllers, or route constants exist for website filtering.
   - **Supabase Backend:** No database tables (`websites`, `domains`, `web_policies`) exist in `supabase/migrations/`.
   - **Active Rejection in Backend Policy Engine:** `supabase/functions/_shared/policy.ts:49-58` enforces a strict whitelist of 8 policy keys. Lines 67-77 (`rejectUnknownKeys`) explicitly reject any web/domain filtering parameters with an HTTP 400 `validation_error`.
   - **Canonical Feature Inventory:** `audit/01_COMPLETE_FEATURE_INVENTORY.md` explicitly lists 25 feature rows (`FD-001` through `FD-014` and `FD-016` through `FD-026`) as `MISSING`, with `FD-015` being `NOT APPLICABLE` (iOS-only).
2. **App Suspension vs. Web Filtering:**
   - The codebase possesses the capability to suspend entire application packages (e.g., suspending `com.android.chrome` via `PolicyApplier.kt:299-311` using `DevicePolicyManager.setPackagesSuspended`).
   - This is a binary application block, not a website, URL, or domain filter. Suspending Chrome does not filter web traffic inside other installed apps, embedded WebViews, or sideloaded browsers.
3. **Strict Privacy Posture Intact:**
   - The application displays explicit privacy promises to the minor (`child_settings_tab.dart:67-70`, `child_session_page.dart:147`): *"This app never records audio or video, takes screenshots, reads messages, or captures passwords."*
   - Any architectural option attempting TLS decryption (Man-in-the-Middle certificate forging) would directly violate this core product commitment and is rejected.

---

## 2. Four Architecture Options Under Review

| Option | Architecture | Key Advantages | Critical Risks & Blockers |
|---|---|---|---|
| **Option A** | **DNS-Based Filtering** (Private DNS / DoT) | - Negligible battery drain.<br/>- Zero VPN slot conflict.<br/>- Native OS support in Android 9+.<br/>- Enforceable via Device Owner. | - Hostname/domain level only; zero HTTPS URL path visibility.<br/>- Bypassed by DNS-over-HTTPS (DoH) in browsers.<br/>- Easily disabled by child in Standard Mode. |
| **Option B** | **Local VPN Service** (`VpnService` Loopback) | - Device-wide packet interception.<br/>- SNI domain inspection for HTTPS.<br/>- Blocks raw IP leaks and DoH endpoints. | - **Fatal VPN Conflict:** Android allows only 1 VPN; breaks family's commercial/school VPNs.<br/>- **Safety Hazard:** VPN crash severs all phone connectivity (black hole), blocking emergency calls and location.<br/>- High battery drain and CPU wakeups.<br/>- Zero URL/content visibility beyond unencrypted SNI. |
| **Option C** | **Managed Browser Only** (HAVEN WebView) | - Full visibility into complete URLs, queries, and page content.<br/>- Direct SafeSearch enforcement.<br/>- Rich custom block pages. | - **Trivially Bypassed:** Child opens Chrome or any other browser unless suspended.<br/>- Zero protection for in-app WebViews (Instagram, TikTok, Discord, Reddit).<br/>- Prohibitive engineering overhead to maintain a secure browser engine. |
| **Option D** | **Defer Website Filtering** (Recommended) | - 100% honest product claims.<br/>- Zero battery or connectivity risk.<br/>- Zero new privacy exposure.<br/>- Allows 100% focus on resolving P0 release blockers. | - Competitors advertise web filtering; HAVEN will not have URL filtering in initial release.<br/>- Parents must use whole-app suspension or home router DNS. |

---

## 3. Standard Mode versus Managed Mode (DEC-13 Alignment)

In strict adherence to approved **DEC-13 (Option B)**:
- **Standard Mode:**
  - Cannot enforce Private DNS (no DPM access).
  - Cannot enforce Always-On VPN (child can disconnect via notification or Settings).
  - Cannot suspend alternative browsers.
  - **Rule:** Under Standard Mode, web filtering cannot be enforced. Any UI or documentation claiming "enforced" web filtering on a Standard Mode device is false.
- **Managed Mode (Device Owner):**
  - Option A can lock Private DNS via `DevicePolicyManager.setGlobalPrivateDnsModeSpecifiedHost` and `DISALLOW_CONFIG_PRIVATE_DNS`.
  - Option B can enforce Always-On VPN via `setAlwaysOnVpnPackage` and `DISALLOW_CONFIG_VPN`.
  - Option C can suspend other browsers via `setPackagesSuspended`.
  - **Rule:** If Device Owner status is lost, capabilities must immediately downgrade to `unsupported`.

---

## 4. Product Claims & Release Accuracy Rectification

The audit identified two instances in QA and regression artifacts where "web filtering" was erroneously referenced as part of the active or planned test suite:
1. `phase-8-open-gaps.md:84`: *"Real-time policy push (web filtering, app restrictions, bedtime lock)."*
2. `phase-8-regression-matrix.md:113`: *"Web filtering, app blocking, bedtime lock, safe zones | Zero commands issued | NOT RUN"*.

**Rectification:**
- These entries conflate implemented app restrictions with non-existent web filtering.
- In all future documentation and release notes, "web filtering" must be removed or qualified as deferred.
- No public marketing, app store copy, or parent onboarding screen may promise web filtering in the upcoming release.

---

## 5. Advisory Recommendation

### Recommended Rationale
1. **Advisory Selection: Option D (Defer Website Filtering for Current Release).**
2. **Future Target (If Web Filtering is Mandatory Post-Release): Option A (DNS-Based Filtering via Managed Mode Private DNS).**

### Trade-Off Synthesis:
- Implementing Option B (VPN) introduces unacceptable stability, battery, and safety risks (crashing VPN kills device emergency communications and conflicts with other VPNs).
- Implementing Option C (Managed Browser) provides an illusion of protection that is bypassed by third-party app WebViews and requires immense browser maintenance.
- Option D preserves system integrity and focuses all engineering capacity on the four active release blockers:
  - **DEC-02:** 4 unapplied hosted migrations and Edge Function deployments.
  - **DEC-03:** 75/75 controlled Android QA rows `NOT RUN`.
  - **DEC-12:** Screen-time daily limit execution logic.
  - **DEC-13:** Production release signing key and Device Owner safe-exit mechanism.

---

## 6. Unresolved Questions Requiring Explicit Owner Selection

The project owner must review `docs/dec-15-website-filtering-owner-decision.md` and explicitly decide:

1. **Which architecture option is selected for DEC-15?**
   - Option A: DNS-based filtering.
   - Option B: Local VPN-based filtering.
   - Option C: Managed browser-only filtering.
   - Option D: Defer website filtering.
2. **If Option A is selected in the future:** Does the owner accept third-party DNS resolver integration (e.g., CleanBrowsing, Cloudflare, NextDNS) for threat and category intelligence, or is self-hosted DNS required?
3. **If Option B is selected:** Does the owner accept the fatal single-VPN slot limitation (inability of families to use commercial or school VPNs) and the battery drain penalty on budget Android devices?
4. **Product Positioning:** Does the owner approve removing all references to "web filtering" from upcoming release materials and positioning HAVEN strictly around app management, screen time, bedtime, geofencing, and safety alerts?

---

## 7. Strict Governance & Compliance Statement

- **DEC-15 remains PROPOSED.**
- No feature was implemented.
- No Kotlin, Dart, TypeScript, or SQL source file was modified.
- No Android services, permissions, or manifest entries were added.
- No Supabase migrations were created or applied.
- No Edge Functions were deployed.
- No APK was compiled, no Gradle task was run, and no ADB command was issued.
- No hardware device or emulator was accessed or provisioned.
- No git state-changing commands (`add`, `commit`, `push`, `reset`, `clean`, `checkout`, `stash`) were executed.
- Workspace integrity is 100% preserved.

**STOPPED. Awaiting explicit owner decision on DEC-15.**

