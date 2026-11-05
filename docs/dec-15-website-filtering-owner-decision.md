# DEC-15 Owner Decision: Website Filtering Scope & Architecture

**Document class:** Owner Decision Record (Governance, Architecture & Technical Comparison).  
**Decision ID:** DEC-15.  
**Decision Title:** Website Filtering Scope & Architecture on the Child Device.  
**Registered Governance Status:** **APPROVED — Option D (Website Filtering Deferred for Current Release).**  
**Approval Date:** 2026-11-05 (Phase 9.7).  
**Target System:** HAVEN / `parentcontrol_app` (Flutter parent/child client, Kotlin Android native services, Supabase hosted backend `parent-control-prod` / `hhqgreaoqulmfwfwarhc`).  
**Implementation Authorization:** **STRICTLY PROHIBITED / NONE.** This document records architectural approval of Option D (scope exclusion). It does not authorize writing or modifying code, adding Android services/permissions, deploying Edge Functions, applying migrations, building APKs, issuing ADB commands, or testing on hardware.

---

## 1. Decision Identification and Governance Status

- **Decision ID:** DEC-15
- **Title:** Website Filtering Scope & Architecture
- **Status:** **APPROVED — Option D** (Approved by Project Owner on 2026-11-05, Phase 9.7)
- **Approved Architectural Choice:** **Option D: Defer website filtering for the current release.**
- **Governing Phase:** Phase 9.7
- **Exact Owner Ruling:**
  > **DEC-15 owner decision: Option D — Defer website filtering for the current release.**
- **Approved Interpretation & Scope Boundaries:**
  1. Website filtering is excluded from the current release scope.
  2. No DNS-based filtering implementation is authorized.
  3. No local VPN-based filtering implementation is authorized.
  4. No dedicated managed browser implementation is authorized.
  5. Existing product claims must accurately disclose that website filtering is not implemented.
  6. No device-wide website filtering capability may be claimed.
  7. No URL blocking, domain blocking, safe browsing or HTTPS content inspection capability may be advertised as available.
  8. Existing app package suspension must not be represented as website filtering.
  9. Website filtering may be reconsidered in a future milestone through a separate explicit owner decision.
  10. This decision does not authorize Phase 10 or any future implementation.
- **Preceding Decisions & System Governance Context:**
  - **DEC-01:** **APPROVED — Choice B** (Local-only client diagnostics; DUR-01 remains OPEN; remote log harvesting prohibited).
  - **DEC-02:** **PENDING / BLOCKED** (Hosted Supabase mutations and deployments strictly prohibited; Stage 7 migration pair reconciled historical evidence only; 4 migrations and all Edge Function deployments remain unapplied).
  - **DEC-03:** **PENDING / BLOCKED** (75/75 controlled Android QA rows remain `NOT RUN`; APK builds, ADB commands, and device hardware testing strictly prohibited).
  - **DEC-05:** **APPROVED — Choice B** (On-demand execution only; `pg_cron` absent hosted).
  - **DEC-12:** **APPROVED — Choices D1-B, B1-B, O1-C, P1-A, DEFER** (Screen-time and bedtime enforcement; hard suspension via Device Owner; child emergency override 10-min pass; implementation gated).
  - **DEC-13:** **APPROVED — Option B** (Managed Mode required for full enforcement; mandatory non-destructive in-app exit as release blocker; Device Administrator retired; implementation gated).
  - **DEC-14:** **APPROVED — Option B** (Realtime primary + FCM non-authoritative wake-up transport; opaque payloads only; implementation gated).
  - **DEC-15:** **APPROVED — Option D** (Subject of this document; website filtering deferred for current release).
  - **DEC-16:** **PROPOSED — Scope Exclusion Confirmed** (Screen recording, mirroring, and remote capture excluded from core product scope).

*No implementation authorization may be inferred from any approved architecture decision.*

---

## 2. Problem Statement

Commercial parental control products frequently promise "web filtering", "safe browsing", and "website restrictions". However, delivering network or web content filtering on modern Android devices presents fundamental architectural, privacy, security, and OS-level constraints:

1. **HTTPS / TLS Encryption:** Over 95% of modern web traffic is encrypted via TLS 1.2/1.3. A device or network filter inspecting traffic at the transport layer can only observe the unencrypted IP address, port, and Server Name Indication (SNI) during the TLS handshake. Full URL paths (e.g., `example.com/harmful/page`), query parameters, search queries, HTTP headers, cookies, and page bodies are completely invisible unless an application performs TLS Man-in-the-Middle (MITM) decryption with a trusted custom root certificate.
2. **TLS Decryption is Infeasible and Harmful:** Installing a root CA certificate breaks certificate pinning in banking, medical, authentication, and Google services. It creates severe security vulnerabilities, violates user privacy, and directly conflicts with HAVEN's core privacy posture ("never reads messages or captures passwords").
3. **Encrypted DNS (DoT / DoH):** Android 9+ includes Private DNS (DNS-over-TLS / DoT), and modern browsers (Chrome, Firefox) support DNS-over-HTTPS (DoH). These protocols bypass standard UDP/TCP port 53 DNS filters.
4. **Android VPN Slot Constraint:** Android permits only one active `VpnService` at any time. Implementing local VPN-based filtering prevents families from using any other VPN (commercial privacy VPNs, school/corporate VPNs, or network security tools).
5. **Zero Implementation in Codebase:** The HAVEN codebase currently contains zero lines of code for web filtering, VPN routing, DNS resolution, or browser controls. Any user-facing claim of "web filtering" in current collateral is factually unsupported.

The owner must formally decide whether HAVEN should pursue DNS-based filtering (Option A), local VPN-based filtering (Option B), a dedicated managed browser (Option C), or explicitly defer website filtering from the roadmap (Option D).

---

## 3. Read-Only Repository Audit & Baseline Implementation

A comprehensive, read-only inspection of the repository was conducted across Kotlin Android sources, AndroidManifest declarations, Flutter application code, and Supabase backend schemas.

### 3.1 Capability Classification Matrix

Every capability relevant to website filtering is classified according to the 6 strict governance states:
1. *Implemented and verified*
2. *Implemented but not runtime-verified*
3. *Partially implemented*
4. *Configuration/model only*
5. *Missing*
6. *Unknown*

| Capability Area | Component / Subsystem | Repository Evidence & Source Location | Classification | Detailed Findings |
|---|---|---|---|---|
| **VPN Service** | Android `VpnService` Subclass | `android/app/src/main/kotlin/` | **Missing** | Zero matches for `VpnService`, `Builder`, or `establish()` across Kotlin codebase. |
| **VPN Permission** | Manifest VPN Binding | `android/app/src/main/AndroidManifest.xml:4-29` | **Missing** | No declaration of `android.permission.BIND_VPN_SERVICE`. |
| **VPN Foreground Type** | Foreground Service Type | `AndroidManifest.xml:79-94` | **Missing** | Services declared: `GuardianService` (`dataSync`), `LocationTrackingService` (`location`), `AudioAssistanceService` (`microphone`). No `connectedDevice` or `specialUse`. |
| **DNS Resolution** | DNS Resolver / Interceptor | `android/`, `lib/` | **Missing** | Zero DNS query parsing, socket interception, or DNS-over-HTTPS/TLS client code. |
| **Private DNS Control** | DPM Private DNS API | `android/.../PolicyApplier.kt` | **Missing** | `DevicePolicyManager.setGlobalPrivateDnsModeSpecifiedHost` is not called anywhere. |
| **Accessibility Filtering** | Accessibility Service | `AndroidManifest.xml`, `android/` | **Missing** | Zero accessibility services declared or implemented; no window-content inspection or URL bar scraping. |
| **Managed Browser** | Custom WebView Activity | `AndroidManifest.xml:47-77`, `pubspec.yaml` | **Missing** | Only `MainActivity` exists; no `WebView` dependency or custom browser activity declared. |
| **Policy Data Model** | Kotlin Policy Model | `android/.../policy/PolicyModels.kt:37-46` | **Missing** | `ChildPolicy` contains only package lists, daily limit, and bedtime. Zero web/domain fields. |
| **Policy JSON Parser** | Kotlin Policy Parser | `android/.../policy/PolicyJson.kt:10-19` | **Missing** | `PolicyJson.parse` reads only 8 app/bedtime fields; ignores any web keys. |
| **Client Dart Model** | Flutter Policy Model | `lib/data/models/device.dart:118-125` | **Missing** | `PolicyPayload` contains only package lists, daily limit, and bedtime. Zero web fields. |
| **Backend Whitelist** | Edge Function Validator | `supabase/functions/_shared/policy.ts:49-58` | **Configuration/model only** (Blocks Web) | `POLICY_KEYS` is a closed whitelist of 8 fields. Lines 67-77 (`rejectUnknownKeys`) throw HTTP 400 `validation_error` if any web key is supplied. |
| **Database Schema** | Migrations / Tables | `supabase/migrations/20260101000000_core.sql` | **Missing** | No `websites`, `domains`, `web_policies`, or `browsing_history` tables in any migration. |
| **App Suspension** | DPM Package Suspension | `android/.../policy/PolicyApplier.kt:299-311` | **Implemented but not runtime-verified** | `dpm.setPackagesSuspended` exists for entire app packages (Managed Mode only). Not tested on hardware (DEC-03). |
| **Critical Protection** | Safety-Critical Guard | `android/.../policy/PolicyEvaluator.kt:28-62` | **Implemented but not runtime-verified** | `PolicyGuard.CRITICAL_PACKAGES` protects dialer, system UI, and settings from suspension. |
| **Feature Inventory** | Canonical Feature Rows | `audit/01_COMPLETE_FEATURE_INVENTORY.md` | **Missing** (25 rows) / **Not Applicable** (1 row) | Rows `FD-001` through `FD-014` and `FD-016` through `FD-026` are all explicitly marked `MISSING`. `FD-015` is `NOT APPLICABLE` (iOS-only). |

### 3.2 Key Audit Finding
**Website filtering is completely unstarted (0% implemented).**
- There is no network interception, DNS proxy, VPN tunnel, accessibility scraper, or browser component anywhere in the application.
- The existing policy pipeline (`policy.ts`) actively rejects any web filtering fields.
- The app restrictions system (`PolicyApplier.kt`) can suspend entire installed application packages (such as `com.android.chrome`), but this is an all-or-nothing binary application block, not a website, domain, or URL filter.

---

## 4. Website Filtering Architecture Options

Four architectural paths are evaluated objectively:

```
+----------------------------------------------------------------------------------------------------+
|                                    DEC-15 ARCHITECTURE OPTIONS                                     |
+------------------------------------+----------------------------------+----------------------------+
| Option A: DNS-Based Filtering      | Option B: Local VPN Service      | Option C: Managed Browser  |
| - OS-level Private DNS (DoT)       | - On-device VpnService loopback  | - Dedicated HAVEN WebView  |
| - Third-party family DNS upstream  | - Inspects SNI in TLS handshake  | - Suspends other browsers  |
| - Low battery, zero payload tap    | - High battery, single VPN slot  | - No in-app WebView reach  |
+------------------------------------+----------------------------------+----------------------------+
| Option D: Defer Website Filtering (Recommended)                                                    |
| - Retain existing non-web scope; qualify/remove inaccurate marketing claims                        |
| - Focus engineering & testing on P0 release blockers (keystore, migrations, Android QA, DEC-12)    |
+----------------------------------------------------------------------------------------------------+
```

---

### Option A — DNS-Based Filtering

#### Description
The device's DNS queries are routed to a protective family DNS resolver (e.g., CleanBrowsing, Cloudflare 1.1.1.3 for Families, NextDNS, or AdGuard DNS). In Managed Mode (Device Owner), Android 9+ allows the Device Owner to configure and enforce Private DNS (DNS-over-TLS) via `DevicePolicyManager.setGlobalPrivateDnsModeSpecifiedHost(admin, "family-dns.example.com")`.

#### Technical Mechanisms
- **DNS Resolver Selection:** Leverages existing specialized secure resolvers providing domain-level categorization and malware/adult blocking.
- **Domain Allow/Block Lists:** Resolution blocks domains at the FQDN level (returning `NXDOMAIN` or `0.0.0.0`).
- **Category Filtering Feasibility:** Highly feasible if outsourced to established threat intelligence DNS providers maintaining categorizations for hundreds of millions of domains.

#### Critical Limitations & Vulnerabilities
- **No HTTPS Page or URL Visibility:** Operates solely on hostnames (`example.com`). Completely blind to paths (`example.com/blocked_page`), search terms, and page content.
- **DoH / Browser Bypass:** Web browsers with hardcoded DNS-over-HTTPS (DoH) or custom resolvers (e.g., Chrome Secure DNS) can bypass system DNS unless DoH bootstrap IP addresses are blocked or browser policies are enforced.
- **Hardcoded IP Bypass:** Any application connecting directly to raw IP addresses bypasses DNS filtering entirely.
- **Standard Mode Inefficacy:** In Standard Mode (without Device Owner), Android provides no API to lock Private DNS. A child can disable Private DNS in Android Settings in under 5 seconds.

---

### Option B — Local VPN-Based Filtering

#### Description
HAVEN registers an Android `VpnService` that establishes a local loopback TUN interface on the device. All outgoing device IP traffic passes through a local packet handler running in the app. The handler inspects DNS queries (UDP/TCP 53) and TLS ClientHello packets (TCP 443) to extract the Server Name Indication (SNI).

#### Technical Mechanisms
- **Local Packet Routing:** Raw IP packets are read from a `ParcelFileDescriptor` using a user-space network stack (e.g., lwIP or a lightweight Kotlin/C++ packet parser).
- **SNI Extraction:** For TCP port 443, the filter parses the unencrypted TLS ClientHello extension to identify the requested domain name before the TLS handshake completes. If the domain is blocked, the TCP connection is reset (`RST`) or dropped.
- **Local DNS Sinkholing:** Intercepts port 53 packets and responds with `NXDOMAIN` or local sinkhole IP for blocked domains.

#### Critical Limitations & Vulnerabilities
- **Single VPN Slot Conflict:** Android permits exactly **one** active VPN connection. If the child or parent enables another VPN (commercial privacy VPN, school VPN, corporate profile, or local ad blocker), HAVEN's VPN is forcibly disconnected by the OS.
- **Severe Battery & Performance Overhead:** Passing every network packet (including high-throughput video streams, system downloads, and background sync) through user-space context switches wakes the CPU continuously, significantly accelerating battery drain and introducing latency.
- **Network Black Hole on Failure:** If the VPN background process crashes, encounters memory pressure, or hangs, all network routing on the phone ceases. The child's phone becomes completely disconnected from the internet, blocking safety alerts, location tracking, and emergency communications.
- **Strict User-Visible Disclosure:** Android mandates an unremovable key icon in the status bar and an OS notification stating: *"Connected to HAVEN. Network may be monitored."*
- **No TLS Payload Inspection:** SNI reveals only the target hostname. Full URLs, queries, and content remain fully encrypted. Attempting TLS decryption via forged certificates is blocked by certificate pinning, creates major security liabilities, and is strictly rejected by HAVEN privacy rules.

---

### Option C — Managed Browser-Only Filtering

#### Description
HAVEN provides an in-app browser (built with Android `WebView` or an embedded engine). All website filtering, allowlists, blocklists, category checks, and SafeSearch enforcements are applied strictly inside this dedicated browser.

#### Technical Mechanisms
- **Direct HTTP/HTTPS Control:** Full visibility into complete URLs, request headers, query strings, and HTML document content inside the controlled WebView.
- **SafeSearch Integration:** Enforces SafeSearch parameter injection (`safe=active`, `&safe=strict`) on major search engines (Google, Bing, DuckDuckGo).
- **Custom Interstitial Pages:** Can display user-friendly blocked-content screens with parent-override request options.

#### Critical Limitations & Vulnerabilities
- **Complete Bypass via Other Browsers:** Unless every other browser (Chrome, Firefox, Edge, Opera, Samsung Internet) is removed or suspended, the child will simply use another browser.
- **Standard Mode Inefficacy:** In Standard Mode, HAVEN cannot hide or suspend other browsers. The filtering is trivial to bypass.
- **In-App WebViews Unprotected:** Embedded browsers and WebViews inside social media apps (Instagram, TikTok, Reddit, Discord) are completely unaffected by the managed browser.
- **Massive Maintenance Burden:** Maintaining a secure, modern web browser requires ongoing patches for web standards, rendering vulnerabilities, and security exploits.

---

### Option D — Defer Website Filtering (Recommended)

#### Description
Acknowledge that website filtering is completely unstarted, fraught with severe technical trade-offs (battery drain, VPN conflicts, network black holes, and encryption blind spots), and not viable for the current release. Formally remove web filtering from immediate release scope, qualify/remove inaccurate claims in documentation, and retain HAVEN's proven focus on application restrictions, screen time, bedtime, geofencing, and safety alerts.

#### Technical Mechanisms
- **Scope Exclusion:** Mark `FD-001` through `FD-026` as deferred to a future, separately authorized milestone.
- **Documentation Cleanup:** Audit and qualify all marketing, QA, and documentation claims that imply web filtering is active or verified.
- **Resource Concentration:** Direct all engineering and verification resources toward closing the active P0 release blockers: DEC-02 (hosted migrations), DEC-03 (75/75 Android QA rows), DEC-12 (screen time enforcement), and DEC-13 (release signing identity and Device Owner safe-exit).

#### Critical Limitations & Trade-Offs
- **Feature Parity Gap:** Commercial competitors (e.g., Qustodio, Bark) advertise web filtering. HAVEN will not compete on URL filtering in the current release.
- **Guardian Expectation Management:** Guardians seeking domain blocking must rely on device-level app suspension (blocking entire browser apps) or network-level home router controls.

---

## 5. Technical Comparison Matrix (24 Criteria)

Every option is systematically evaluated across the 24 technical comparison criteria:

| # | Comparison Criterion | Option A: DNS-Based | Option B: Local VPN | Option C: Managed Browser | Option D: Defer Filtering | Repository Evidence & Architectural Basis |
|---|---|---|---|---|---|---|
| **1** | **Device-Wide Coverage** | `PARTIAL` | `SUPPORTED` | `UNSUPPORTED` | `UNSUPPORTED` | Opt A covers OS DNS but misses raw IP/DoH; Opt B routes all device packets; Opt C is isolated to one app. |
| **2** | **Browser Coverage** | `PARTIAL` | `SUPPORTED` | `UNSUPPORTED` | `UNSUPPORTED` | Opt A is bypassed by browsers using private DoH; Opt B intercepts all browser sockets; Opt C covers only itself. |
| **3** | **In-App WebView Coverage** | `PARTIAL` | `SUPPORTED` | `UNSUPPORTED` | `UNSUPPORTED` | Opt B catches all app network sockets; Opt C cannot inspect third-party app WebViews. |
| **4** | **HTTPS Visibility** | `UNSUPPORTED` | `PARTIAL` (SNI Only) | `SUPPORTED` (Full URL) | `UNSUPPORTED` | Opt A sees only DNS names; Opt B sees TLS SNI; Opt C sees complete URL paths and query parameters. |
| **5** | **DNS-over-HTTPS Bypass** | `UNSUPPORTED` | `SUPPORTED` | `SUPPORTED` | `UNSUPPORTED` | Opt A is easily bypassed by DoH clients; Opt B can intercept/drop TCP/UDP 443 traffic to known DoH IPs. |
| **6** | **DNS-over-TLS Bypass** | `PARTIAL` | `SUPPORTED` | `SUPPORTED` | `UNSUPPORTED` | Opt A can enforce DoT only in Managed Mode via DPM; Opt B can block port 853 traffic. |
| **7** | **VPN Conflict Behavior** | `SUPPORTED` (No conflict) | `UNSUPPORTED` (Fatal) | `SUPPORTED` (No conflict) | `SUPPORTED` (No conflict) | Android allows only 1 active VPN. Opt B breaks if family uses another VPN; Opts A, C, D have zero VPN conflict. |
| **8** | **Standard Mode Capability** | `UNSUPPORTED` | `PARTIAL` | `UNSUPPORTED` | `SUPPORTED` | In Standard Mode, child can toggle off DNS (Opt A), disconnect VPN (Opt B), or use Chrome (Opt C). Opt D is honest. |
| **9** | **Managed Mode Capability** | `SUPPORTED` | `SUPPORTED` | `PARTIAL` | `SUPPORTED` | Device Owner locks Private DNS (Opt A), enforces Always-On VPN (Opt B), or suspends other browsers (Opt C). |
| **10** | **Device Owner Dependency** | `PARTIAL` | `PARTIAL` | `PARTIAL` | `UNSUPPORTED` | Strong bypass prevention across A, B, and C requires Device Owner; Opt D has zero DO dependency. |
| **11** | **Battery Consumption** | `SUPPORTED` (Negligible) | `UNSUPPORTED` (High) | `SUPPORTED` (Low) | `SUPPORTED` (Zero) | Opt B parses every packet in user space, causing heavy wakeups; Opt A incurs zero packet-processing overhead. |
| **12** | **Network Performance** | `SUPPORTED` (High) | `UNSUPPORTED` (Latency/Jitter) | `SUPPORTED` (Normal) | `SUPPORTED` (Native) | Opt B introduces packet queueing and user-space overhead; Opt A uses standard network paths. |
| **13** | **Offline Behavior** | `PARTIAL` | `PARTIAL` | `SUPPORTED` | `SUPPORTED` | Opt A fails if local DNS cache expires; Opt B needs local offline rules; Opt C evaluates local rule list. |
| **14** | **Reboot Recovery** | `SUPPORTED` | `PARTIAL` | `SUPPORTED` | `SUPPORTED` | Opt A OS preserves Private DNS across reboots; Opt B requires Always-On VPN lockdown to avoid early boot leaks. |
| **15** | **Child Transparency / Consent** | `SUPPORTED` | `SUPPORTED` (Mandatory OS key) | `SUPPORTED` | `SUPPORTED` | Opt B triggers Android's mandatory VPN key icon and monitoring notification; Opt A is visible in Settings. |
| **16** | **Privacy Implications** | `SUPPORTED` (Minimal) | `PARTIAL` (High surface) | `PARTIAL` (History collected) | `SUPPORTED` (Zero risk) | Opt B network stack technically inspects all outgoing traffic destinations; Opt D creates zero privacy liability. |
| **17** | **Data Minimization** | `SUPPORTED` | `PARTIAL` | `PARTIAL` | `SUPPORTED` | Opt D collects zero web data; Opt A delegates to DNS; Opts B and C require storing domain block events. |
| **18** | **Bypass Resistance** | `PARTIAL` (Managed Mode) | `SUPPORTED` (Managed Mode) | `PARTIAL` | `SUPPORTED` (N/A) | Opt B with Managed Mode Always-On VPN is the hardest to evade; Opt A can be bypassed by raw IP connections. |
| **19** | **Maintenance Complexity** | `SUPPORTED` (Low) | `UNSUPPORTED` (Very High) | `UNSUPPORTED` (High) | `SUPPORTED` (Zero) | Opt B requires maintaining a custom low-level network stack across diverse Android kernel versions and OEMs. |
| **20** | **Runtime Testing Requirements** | `SUPPORTED` (Simple) | `UNSUPPORTED` (Complex matrix) | `PARTIAL` | `SUPPORTED` (Zero) | Opt B requires deep testing across Wi-Fi/LTE handovers, roaming, captive portals, IPv6, and battery modes. |
| **21** | **Android Compatibility** | `SUPPORTED` (API 28+) | `SUPPORTED` (API 21+) | `SUPPORTED` (API 21+) | `SUPPORTED` (All) | Opt A requires Android 9+ (API 28) for Private DNS DPM APIs; Opt B works from API 21+. |
| **22** | **OEM-Specific Limitations** | `PARTIAL` | `UNSUPPORTED` (Severe) | `SUPPORTED` | `SUPPORTED` | Aggressive OEM battery killers (Xiaomi MIUI, Samsung, Realme) terminate long-running VPN sockets. |
| **23** | **Failure Behavior** | `PARTIAL` (Fails open/closed) | `UNSUPPORTED` (Black hole) | `SUPPORTED` (Page error) | `SUPPORTED` (Zero risk) | If Opt B VPN crashes, the phone loses all internet connectivity, breaking safety alerts and emergency calls. |
| **24** | **Product Claim Accuracy** | `SUPPORTED` (Honest FQDN) | `PARTIAL` (Honest SNI) | `PARTIAL` (Honest in-app) | `SUPPORTED` (100% honest) | Opt D eliminates all false claims; Opts A and B must strictly disclaim full URL or content inspection. |

---

## 6. Standard Mode versus Managed Mode Enforcement

In strict compliance with approved **DEC-13 (Option B)**, filtering capabilities must honestly reflect the device management tier:

```
                      +-------------------------------------------------+
                      |           DEC-13 ENFORCEMENT HIERARCHY          |
                      +-------------------------------------------------+
                                       |
                 +---------------------+---------------------+
                 |                                           |
                 v                                           v
       +--------------------+                      +--------------------+
       |   STANDARD MODE    |                      |    MANAGED MODE    |
       |  (Non-Device Owner)|                      |   (Device Owner)   |
       +--------------------+                      +--------------------+
       | - Normal Android   |                      | - Hardware-level   |
       |   permissions only |                      |   DPM controls     |
       | - Easily toggled   |                      | - Non-bypassable   |
       |   off by child     |                      |   configuration    |
       | - Advisory status  |                      | - Hard enforcement |
       +--------------------+                      +--------------------+
```

### 6.1 Standard Mode (Normal Android Permissions)
- **Hard Enforcement is Impossible:** Standard Android permissions provide no mechanism to prevent a child from changing system settings, revoking VPN permissions, or switching web browsers.
- **Option A (DNS) in Standard Mode:** The app cannot configure Private DNS programmatically. It can only present instructions asking the child or parent to manually enter a DNS hostname in Android Settings. The child can revert or change this setting at any time without notification.
- **Option B (VPN) in Standard Mode:** The app can prompt for `VpnService.prepare()`. However, the child can tap "Disconnect" in the notification shade or Android Settings at any time. The app cannot prevent VPN disconnection or enforce Always-On mode.
- **Option C (Managed Browser) in Standard Mode:** The child can simply open Chrome, Firefox, or any other browser. HAVEN cannot suspend, hide, or uninstall alternative browsers.
- **Strict Rule:** Under Standard Mode, any website filtering implementation **must be clearly labelled as advisory and non-enforceable.** The parent UI must never report that web filtering is "enforced" on a Standard Mode device.

### 6.2 Managed Mode (Device Owner)
- **Enforceable System Policies:** Device Owner status unlocks DevicePolicyManager APIs that can enforce network controls:
  - **Option A:** `setGlobalPrivateDnsModeSpecifiedHost(admin, host)` forces all device DNS through the specified DNS-over-TLS server. Paired with `addUserRestriction(admin, DISALLOW_CONFIG_PRIVATE_DNS)` and `addUserRestriction(admin, DISALLOW_NETWORK_RESET)`, the child is completely blocked from altering or disabling DNS settings.
  - **Option B:** `setAlwaysOnVpnPackage(admin, packageName, lockdownEnabled)` locks the VPN service so that no network traffic can pass unless the VPN is connected. Paired with `addUserRestriction(admin, DISALLOW_CONFIG_VPN)`, the child cannot disconnect or alter the VPN.
  - **Option C:** `setPackagesSuspended(admin, browserPackages, true)` can suspend all alternative browsers, forcing web usage through the managed browser.
- **Downgrade Honesty:** If Device Owner status is revoked or cleared (via the mandatory non-destructive exit mandated by DEC-13), all Managed Mode web restrictions must immediately downgrade to `unsupported` and inform the parent honestly.

---

## 7. Safety, Privacy and Child Transparency Requirements

Any future website filtering architecture must strictly adhere to the following 14 design requirements:

1. **Child & Parent Full Disclosure:** The child UI and parent UI must explicitly disclose what web data is monitored (domain names only) and what is not monitored (page content, passwords, personal chats).
2. **Strict Prohibition of TLS MITM / Decryption:** The application shall **never** install a custom root CA certificate, decrypt TLS traffic, intercept HTTPS page bodies, or capture form fields.
3. **No Credential or Message Harvesting:** Authentication credentials, passwords, session tokens, personal messages, and media files must never be inspected or processed.
4. **Data Minimization:** No comprehensive browsing history may be logged or uploaded. Only blocked-domain security events (timestamp, blocked domain, category rule triggered) may be transmitted.
5. **Strict Data Retention & Purge:** Stored domain event logs must have a strict maximum retention period (e.g., 7 days) and must be purged automatically upon family unlinking or account deletion (`run_retention_sweep`).
6. **Multi-Tenant Isolation & Authorization:** All filtering policies and event logs must be isolated strictly by `family_id` using Postgres Row-Level Security (RLS). No family may ever view another family's domain logs.
7. **Fail-Open vs. Fail-Closed Safety Rule:** If the filtering engine or network service encounters an error or crashes, **the network must fail open for safety-critical communications** (emergency dialer, SOS alerts, parent-child assistance sessions) rather than black-holing device traffic.
8. **Permanent Child-Visible Filtering Status:** Whenever filtering is active, a clear, persistent visual indicator must be visible in the child application and in system notifications.
9. **Parent Enforcement Telemetry:** The parent dashboard must display the real-time operational status of web filtering (`active`, `bypassed_via_vpn`, `private_dns_disabled`, or `unsupported`).
10. **Critical Package & Emergency Protection:** Emergency dialers, phone services, system UI, and `PolicyGuard.CRITICAL_PACKAGES` must never be routed through or blocked by a web filter.
11. **False-Positive Recovery & Parent Allow-Listing:** The parent UI must provide a direct mechanism to allow-list erroneously blocked educational or family domains within 60 seconds.
12. **Captive Portal Detection:** The filtering engine must detect captive portals (hotel/school/airport Wi-Fi login pages) and temporarily permit authentication traffic to prevent stranding the child without connectivity.
13. **Battery Health Guard:** Network filtering services must continuously monitor battery impact; excessive CPU wake-locks must trigger self-throttling to prevent draining the child's battery in an emergency.
14. **Compliance & Legal Alignment:** The design must adhere to COPPA, GDPR-K, and applicable child protection frameworks regarding the processing and storage of minors' internet activities.

---

## 8. Product Claims and Release Accuracy Audit

A comprehensive review was conducted of all documentation, UI strings, and test artifacts across the repository:

| # | Current Claim / Reference | Source Location | Audit Classification | Release Recommendation | Rationale |
|---|---|---|---|---|---|
| **1** | *"Real-time policy push (web filtering, app restrictions, bedtime lock)."* | `phase-8-open-gaps.md:84` | **Inaccurate / Unsupported** | **Qualify & Correct** | Web filtering does not exist. Update text to reflect only implemented app restrictions and bedtime window sync. |
| **2** | *"Web filtering, app blocking, bedtime lock, safe zones | Zero commands issued | NOT RUN"* | `phase-8-regression-matrix.md:113` | **Inaccurate / Unsupported** | **Qualify & Correct** | Remove "Web filtering" from the test row description. Web filtering cannot be `NOT RUN` because no code exists. |
| **3** | *"Website filtering / browsing history (VpnService) | no - 0 % implemented"* | `docs/implementation/feature-ownership.md:49` | **Accurate** | **Retain as Evidence** | Correctly identifies that web filtering is 0% implemented and has no Phase 1 deliverable. |
| **4** | *"Web filtering — NOT STARTED. No WebView, VPN service, DNS interception..."* | `docs/implementation/remaining-gaps.md:59` | **Accurate** | **Retain as Evidence** | Correctly states that no code exists and that it requires a formal product decision. |
| **5** | Feature Rows `FD-001` through `FD-014` & `FD-016` through `FD-026` marked `MISSING` | `audit/01_COMPLETE_FEATURE_INVENTORY.md` | **Accurate** | **Retain as Canonical** | Accurately records that the entire web filtering and browsing history feature family is absent. |
| **6** | Child Privacy Promise: *"This app never records audio or video, takes screenshots, reads messages, or captures passwords."* | `child_settings_tab.dart:67-70`, `child_session_page.dart:147` | **Accurate & Mandatory** | **Retain & Protect** | True today. Any future web filtering option that attempts HTTPS decryption would violate this promise. |

*No marketing copy, store description, or release note may claim "Web Filtering", "Safe Browsing", or "URL Blocking" in the upcoming release.*

---

## 9. Recommendation and Architectural Synthesis

### 9.1 Recommended Option
**OPTION D — DEFER WEBSITE FILTERING FOR CURRENT RELEASE.**

If the owner determines that website filtering is an indispensable product requirement that must be included on the roadmap, the only viable target architecture for a subsequent dedicated milestone is:
**OPTION A — DNS-BASED FILTERING (MANAGED MODE ONLY).**

### 9.2 Detailed Rationale for Recommending Option D (Immediate Deferral)
1. **Zero Implementation Status:** Not a single line of code, database column, or native service exists for web filtering. Designing, implementing, testing, and hardening a network filtering stack cannot be completed safely without destabilizing the release.
2. **Active P0 Release Blockers:** The engineering team must resolve critical existing blockers:
   - DEC-02: 4 backend migrations unapplied; Edge Functions undeployed.
   - DEC-03: 75/75 controlled Android QA rows are `NOT RUN`.
   - DEC-12: Screen time daily limit enforcement lacks device execution logic.
   - DEC-13: Production release signing identity is unresolved; Device Owner non-destructive exit must be built.
3. **Severe Technical Risks of Option B (VPN):**
   - Introduces the "single VPN slot" fatal conflict.
   - Threatens child safety: a crashing VPN service severs internet connectivity completely, blocking emergency alerts and location tracking.
   - Heavy battery consumption and thermal throttling on budget devices.
4. **Flawed Scope of Option C (Managed Browser):**
   - Does not protect in-app WebViews in popular social media apps.
   - Easily bypassed unless all other browsers are blocked.
   - Prohibitive engineering overhead to maintain a Chromium/WebView browser engine.
5. **Why Option A is the Best Future Target (Post-Release Milestone):**
   - Zero packet-processing battery drain.
   - Zero VPN slot conflict (coexists with commercial VPNs).
   - In Managed Mode, Device Owner can lock Private DNS cleanly via native Android OS APIs (`setGlobalPrivateDnsModeSpecifiedHost`).
   - Delegates domain categorization and threat intelligence to specialized global DNS providers rather than maintaining brittle local blocklists.

### 9.3 Release Blockers for Any Future Website Filtering Work
Before any future web filtering implementation can be authorized, the following prerequisites must be met:
1. Formal resolution and closure of DEC-02, DEC-03, DEC-12, and DEC-13.
2. Creation and owner approval of a dedicated policy schema migration for domain lists (DEC-02).
3. Selection and contractual evaluation of a family DNS partner API (e.g., CleanBrowsing, Cloudflare, NextDNS).
4. Full laboratory verification of Android 9–15 Private DNS lockdown on dedicated test hardware (DEC-03).

---

## 10. Future Acceptance Criteria (If Option A or B is Authorized Later)

If the owner subsequently authorizes website filtering in a future phase, the following acceptance criteria shall govern the implementation:

- **AC-15-01 (Domain Ceiling):** The product copy in both parent and child applications explicitly states that filtering operates at the domain name level only, with zero visibility into HTTPS page URLs or encrypted content.
- **AC-15-02 (Schema Migration):** A dedicated Supabase migration introduces `domain_rules` or extends `device_policies` with strict validation in `policy.ts`, gated by DEC-02.
- **AC-15-03 (No Decryption Verification):** Automated static analysis and build verification confirm that no custom root certificates, CA installers, or TLS decryption libraries exist in the application.
- **AC-15-04 (Emergency Exemption):** Emergency dialer, SMS, system UI, and `PolicyGuard.CRITICAL_PACKAGES` are verified to be permanently exempt from filtering.
- **AC-15-05 (Fail-Open Connectivity):** If the filtering mechanism (DNS upstream or local service) is unreachable, the device must maintain basic connectivity for location and safety alerts rather than black-holing traffic.
- **AC-15-06 (Standard Mode Honesty):** On Standard Mode devices, the UI clearly displays "Advisory Only — Bypassable" and never reports web filtering as "Enforced".
- **AC-15-07 (Managed Mode Private DNS):** In Managed Mode, `DevicePolicyManager.setGlobalPrivateDnsModeSpecifiedHost` is verified on physical hardware across Android 10, 12, 14, and 15.
- **AC-15-08 (Captive Portal Handling):** The filtering engine demonstrates successful Wi-Fi sign-in on captive portal networks without stalling connectivity.
- **AC-15-09 (Parent Allow-List Latency):** A parent domain override rule synchronizes and takes effect on the child device within 60 seconds.
- **AC-15-10 (Battery Impact Ceiling):** 24-hour hardware battery measurement demonstrates less than 3% incremental battery consumption attributable to the filtering service.

---

## 11. Implementation Authorization Boundary

**STRICT PROHIBITION IN FORCE:**
- This document records architectural approval of **Option D: Defer website filtering for the current release.**
- It does **NOT** grant authorization to write or modify application code.
- It does **NOT** authorize adding Android `VpnService`, DNS resolvers, or WebView components.
- It does **NOT** authorize schema migrations, Edge Function deployments, or hosted Supabase mutations (gated by DEC-02).
- It does **NOT** authorize hardware testing, ADB commands, or APK builds (gated by DEC-03).
- DEC-15 is formally **APPROVED — Option D (Scope Exclusion & Deferral)**. Any future website filtering implementation requires a separate explicit owner decision, specification, and implementation authorization.

---

## 12. DEC-15 Owner Decision — Ratified Ruling

The project owner has formally reviewed the DEC-15 decision package and explicitly ruled on 2026-11-05 (Phase 9.7):

- [x] **Option D: Defer website filtering.** (**APPROVED by Project Owner on 2026-11-05.** Website filtering is formally excluded from the current release; product claims must be qualified; resources remain focused on P0 release blockers).
- [ ] **Option A: DNS-based filtering.** *(Not selected; retained as historical evaluation and target architecture for potential future reconsideration).*
- [ ] **Option B: Local VPN-based filtering.** *(Not selected; retained as historical evaluation; rejected due to single VPN slot conflict, battery drain, and network failure hazards).*
- [ ] **Option C: Managed browser-only filtering.** *(Not selected; retained as historical evaluation; rejected due to in-app WebView bypass and browser maintenance burden).*

### Binding Authorization Boundary:
This approval ratifies Option D (deferral and scope exclusion). It does **NOT** authorize writing code, creating database tables, modifying AndroidManifest, provisioning devices, building APKs, or initiating Phase 10.

