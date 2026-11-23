# 10 — Blocked and Unverified Tests Register

Audit Execution Date: 2026-11-23  
Phase: Phase 6 Comprehensive End-to-End Execution  
Audit Authority: HAVEN QA Team

---

## 1. Executive Summary of Blocked Tests

In accordance with Section 2 (Absolute Safety Rules), Section 12 (Test Execution Rules), Section 14.4 (Blocked Test Register Requirements), and Section 15 (Required Test Completion Audit):
- A blocked test is **never marked PASS**.
- A source-code implementation is **not proof of runtime success**.
- If an operation requires a prohibited persistent change or an unavailable prerequisite, it must be recorded with its exact blocker reason.
- Because both the Parent device (`emulator-5554`) and the Child device (`5HXWRGQ4IFU8WS4T`) are currently at the Get Started / Role Selection screen (`AppRoutes.roleSelection`) with no active authenticated session, all tests requiring an active authenticated Parent or Child session are blocked from full live execution under Rule 2.1:
  `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED.`

---

## 2. Categorization of Blockers

The blocked test cases fall into five distinct categories:

1. **Category BLK-AUTH (Missing Authenticated Session)**:
   - *Cause*: Neither device holds an active server session; local session sign-out occurred on startup (`supabase.auth: INFO: Signing out user with scope: local`). Under Rule 2.1, the auditor is strictly prohibited from entering credentials or attempting to replace a missing session.
   - *Impact*: In-app dashboards, settings, real-time sync, and protected endpoints cannot be reached at runtime.

2. **Category BLK-APPR (Explicit Owner Approval Required)**:
   - *Cause*: Operations that modify persistent family relationships, unlink devices, revoke registrations, delete accounts, or purge audit logs (e.g., APR-01 through APR-14).
   - *Impact*: High-risk state-mutating actions cannot be triggered.

3. **Category BLK-PROHIB (Absolute Safety Prohibitions)**:
   - *Cause*: Strictly prohibited operations including session invalidation, credential rotation, secure storage wiping, local app-data deletion, or APK reinstallation against preserved QA accounts.

4. **Category BLK-DEP (Hardware / System Privilege Missing)**:
   - *Cause*: Features requiring Device Owner mode (`APP07`, `USE08`), notification permission on Android 13+ (`MON05`), or valid device credentials (`MON04`).

5. **Category BLK-ENV (Isolated Environment / Error Fixture Missing)**:
   - *Cause*: `P6-SHR-015` (invalid credential testing) and `P6-SHR-016` (backend error fixture) require an isolated test harness to prevent QA account lockout or network tampering.

---

## 3. Comprehensive Master Blocked Register (All Blocked Cases)

| Test Case ID | Functionality ID | Feature Name | Primary Blocker Reason | Missing Prerequisite | Approval Required? | Required Test Environment / Future Action |
|---|---|---|---|---|---|---|
| **P6-PAR-001** | FAM01 | Link child by QR scan | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session; active camera | Owner Intervention | Provide authenticated parent session; physical camera feed with synthetic QR |
| **P6-PAR-002** | FAM02 | Link child by Child ID/code | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session; input field validation harness |
| **P6-PAR-003** | FAM03 | Send pairing request | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED & SESSION MISSING` | Parent authenticated session; owner write approval (APR-06) | Yes (Owner) | Staging environment with active QA parent & child accounts |
| **P6-PAR-004** | FAM04 | Pairing request list (read-only) | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-005** | FAM08 | Create family guard | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED & SESSION MISSING` | Parent authenticated session; owner write approval | Yes (Owner) | Isolated non-family parent account fixture |
| **P6-PAR-006** | FAM09 | Family details & members | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session with existing family `demo` |
| **P6-PAR-007** | FAM10 | Unlink child account/device | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED (APR-03) & SESSION MISSING` | Parent authenticated session; owner approval for destructive unlink | Yes (Owner) | Dedicated throwaway family fixture |
| **P6-PAR-008** | FAM12 | Revoke device | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED (APR-04) & SESSION MISSING` | Parent authenticated session; owner approval for destructive revoke | Yes (Owner) | Dedicated throwaway device fixture |
| **P6-PAR-009** | FAM13 | Device recovery entry point | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED (APR-07) & SESSION MISSING` | Parent authenticated session; owner approval | Yes (Owner) | Isolated device recovery test harness |
| **P6-PAR-010** | MON01 | Family / dashboard overview | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-011** | MON02 | Device list with status cards | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-012** | MON03 | Device detail view | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-013** | MON06 | Recent command history | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-014** | USE01 | Daily usage history | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session; child usage uploads | Owner Intervention | Provide authenticated parent session; working child upload pipeline |
| **P6-PAR-015** | USE02 | App usage breakdown | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session; child usage uploads | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-016** | USE03 | Usage Access status & guidance | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-017** | USE05 | Daily screen-time limit configuration | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-018** | USE06 | Bedtime configuration display | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-019** | USE07 | Remaining-time / limit display | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-020** | APP01 | App blocking policy configuration | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-021** | APP02 | Block all except allowed list | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED & SESSION MISSING` | Parent authenticated session; owner write approval | Yes (Owner) | Staging environment with non-production policy |
| **P6-PAR-022** | APP03 | Allowed app list management | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED & SESSION MISSING` | Parent authenticated session; owner write approval | Yes (Owner) | Staging environment with non-production policy |
| **P6-PAR-023** | APP04 | App schedule configuration | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED & SESSION MISSING` | Parent authenticated session; owner write approval | Yes (Owner) | Staging environment with non-production policy |
| **P6-PAR-024** | LOC01 | Current child location map | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session; child location fixes | Owner Intervention | Provide authenticated parent session; active location pipeline |
| **P6-PAR-025** | LOC02 | Location history display | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session; historical fixes | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-026** | LOC03 | Safe zone configuration / list | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-027** | ALT01 | Safety alerts list | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-028** | ALT02 | Alert filter by severity | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-029** | ALT03 | Acknowledge alert (read-only list) | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-030** | REM01 | Request remote assistance session | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session; WebRTC signaling | Owner Intervention | Provide authenticated parent & child sessions |
| **P6-PAR-031** | REM04 | Remote session history | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-032** | AUD01 | Audit log pagination & filters | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-033** | AUD02 | Retention settings view/update | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED (APR-11) & SESSION MISSING` | Parent authenticated session; owner approval for retention changes | Yes (Owner) | Staging family with configurable retention |
| **P6-PAR-034** | AUD03 | Purge old audit data | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED (APR-11) & SESSION MISSING` | Parent authenticated session; destructive purge approval | Yes (Owner) | Staging database fixture with dummy audit data |
| **P6-PAR-035** | SET03 | App version & build information | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session (Parent Settings tab) | Owner Intervention | Provide authenticated parent session |
| **P6-PAR-036** | FAM04 | Pairing request cancel action | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED (APR-06) & SESSION MISSING` | Parent authenticated session; pending pairing request; owner write approval | Yes (Owner) | Staging environment with active pending pairing |
| **P6-PAR-037** | ALT02 | Alert acknowledge write execution | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED & SESSION MISSING` | Parent authenticated session; existing alert; owner write approval | Yes (Owner) | Staging environment with unacknowledged alert |
| **P6-STATE-001**| MON01; MON02; SYS01 | Cross-cutting Parent loading/empty/cached states | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-STATE-002**| FAM09; USE01; LOC01; LOC10; AUD01 | Cross-cutting Parent empty/error/retry states | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Parent authenticated session | Owner Intervention | Provide authenticated parent session |
| **P6-CHD-001** | FAM05 | Child redeem pairing code | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED (APR-06) & SESSION MISSING` | Child authenticated session; owner pairing approval | Yes (Owner) | Staging environment with pending linking code |
| **P6-CHD-002** | FAM06 | Child pairing consent dialog | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session; incoming pairing request | Owner Intervention | Staging environment with active pairing push |
| **P6-CHD-003** | FAM07 | Child device registration identity | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED (APR-05) & SESSION MISSING` | Child authenticated session; owner approval for identity re-registration | Yes (Owner) | Isolated child registration test fixture |
| **P6-CHD-004** | CHD01 | Child home dashboard | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-CHD-005** | CHD02 | Rules & restrictions viewer | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-CHD-006** | CHD03 | Child time-extension request | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-CHD-007** | CHD04 | Guardian foreground service display | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-CHD-008** | CHD05 | Child permission health checklist | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-CHD-009** | CHD06 | Child device status card | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-CHD-010** | REM02 | Child incoming remote assistance request | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session; parent remote call | Owner Intervention | Provide authenticated parent & child sessions |
| **P6-CHD-011** | APP05 | Child app restriction enforcement view | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-CHD-012** | APP06 | Blocked app access attempt notice | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session; applied app policy | Owner Intervention | Provide authenticated child session; blocked app |
| **P6-CHD-013** | LOC06 | Child background location transmission | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session; working device credential | Owner Intervention | Provide authenticated child session; credential fix |
| **P6-CHD-014** | ALT04 | SOS / emergency alert trigger | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-CHD-015** | PER01 | Accessibility service guidance | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-CHD-016** | PER02 | Device Admin activation flow (read-only) | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-CHD-017** | PER03 | Usage Access permission guidance | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-CHD-018** | CHD07 | Child local settings & profile | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-CHD-019** | SYS02 | Background sync retry (`retryBackgroundSync`) | `BLOCKED — PROHIBITED PERSISTENT OPERATION (Rule 2.3 & Matrix Rule)` | Child authenticated session; idempotency verification | Yes (Owner) | Isolated sync test harness with telemetry logging |
| **P6-CHD-020** | CHD04 | Guardian foreground service restart | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED & SESSION MISSING` | Child authenticated session; owner service restart approval | Yes (Owner) | Controlled restart verification fixture |
| **P6-STATE-003**| CHD01; CHD02; SYS01 | Cross-cutting Child permission/offline/error states | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Child authenticated session | Owner Intervention | Provide authenticated child session |
| **P6-SHR-001** | A01 | Email/password sign-in positive flow | `BLOCKED — ABSOLUTE SESSION PRESERVATION & SEPARATE AUTH ENVIRONMENT REQUIRED` | Isolated authentication test fixture; owner credential strategy | Yes (Owner) | Isolated non-preserved account environment |
| **P6-SHR-002** | A02 | Account registration flow | `BLOCKED — ABSOLUTE PROHIBITION AGAINST PRESERVED QA ACCOUNTS` | Dedicated disposable email fixture; approval | Yes (Owner) | Isolated staging auth environment |
| **P6-SHR-003** | A03 | Email verification resend/refresh | `BLOCKED — ABSOLUTE PROHIBITION AGAINST PRESERVED QA ACCOUNTS` | Unverified disposable account fixture | Yes (Owner) | Isolated staging auth environment |
| **P6-SHR-004** | A04 | Persisted session auto-restore | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Pre-existing valid persistent session token | Owner Intervention | Restored valid QA session token on device |
| **P6-SHR-005** | A05 | Sign out affordance (execution) | `BLOCKED — ABSOLUTE PROHIBITION AGAINST SIGNING OUT PRESERVED ACCOUNTS` | Read-only observation completed; execution prohibited | Prohibited | Dedicated throwaway account fixture |
| **P6-SHR-006** | A06 | Initial role selection & lock | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Freshly authenticated user with unset role | Owner Intervention | Isolated unassigned-role account fixture |
| **P6-SHR-007** | A07 | Profile / account details display | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Active authenticated session | Owner Intervention | Provide authenticated session |
| **P6-SHR-008** | A08 | Account data export request | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Active authenticated session | Owner Intervention | Provide authenticated session |
| **P6-SHR-009** | A09 | Account deletion confirmation & execute | `BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED (APR-01) & SESSION MISSING` | Active session; destructive account loss approval | Yes (Owner) | Dedicated throwaway account fixture |
| **P6-SHR-011** | SET03 | App version display in Settings | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Authenticated session (Settings route) | Owner Intervention | Provide authenticated session |
| **P6-SHR-012** | SET04 | Runtime permission request flows | `BLOCKED — PROHIBITED PERMISSION MUTATION (Rule 2.2)` | Permission alteration prohibited without approval | Yes (Owner) | Clean emulator instance with revoked permissions |
| **P6-SHR-013** | SYS01 | Network transition & offline banner | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Active authenticated session | Owner Intervention | Provide authenticated session; naturally occurring offline transition |
| **P6-SHR-015** | A01 | Invalid-credential error handling | `BLOCKED — REQUIRES SEPARATE AUTHENTICATION TEST ENVIRONMENT APPROVAL (D18)` | Separate approved test harness; no lockout risk | Yes (Owner) | Isolated auth environment |
| **P6-SHR-016** | SYS02 | Refresh error handling & backend failure | `BLOCKED — REQUIRES SEPARATE SAFE TEST ENVIRONMENT (D19)` | Approved backend error fixture; no network blocking | Yes (Owner) | Staging mock backend error fixture |
| **P6-INT-001** | PAIR01 | End-to-end pairing request & approval | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Both Parent and Child authenticated sessions; owner approval | Yes (Owner) | Staging environment with unlinked test devices |
| **P6-INT-002** | PAIR02 | Pairing rejection & cancellation | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Both Parent and Child authenticated sessions; owner approval | Yes (Owner) | Staging environment with unlinked test devices |
| **P6-INT-003** | PAIR03 | Pairing expiration lifecycle | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Both Parent and Child authenticated sessions; owner approval | Yes (Owner) | Staging environment with TTL timing harness |
| **P6-INT-004** | MON01 | Heartbeat transmission & online status | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Both Parent and Child authenticated sessions; working credential (`MON04`) | Owner Intervention | Credential lifecycle fix; active sessions |
| **P6-INT-005** | MON02 | Battery level & charging telemetry | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Both Parent and Child authenticated sessions; heartbeat upload | Owner Intervention | Credential lifecycle fix; active sessions |
| **P6-INT-006** | REST01| App block policy synchronization | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Both Parent and Child authenticated sessions; realtime channel | Owner Intervention | Staging policy fixture |
| **P6-INT-007** | REST02| Screen-time limit synchronization | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Both Parent and Child authenticated sessions; realtime channel | Owner Intervention | Staging policy fixture |
| **P6-INT-008** | LOC01 | Live location upload & map rendering | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Both Parent and Child authenticated sessions; GPS fixes; credential | Owner Intervention | Credential fix; GPS signal |
| **P6-INT-009** | LOC02 | Geofence crossing alert delivery | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Both Parent and Child authenticated sessions; location sweep | Owner Intervention | Credential fix; geofence test fixtures |
| **P6-INT-010** | REM01 | WebRTC remote assistance session | `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED` | Both Parent and Child authenticated sessions; ICE/TURN servers | Owner Intervention | Complete WebRTC staging signaling infrastructure |
| **P6-SEC-001** | SEC01 | Plaintext password exposure in Sign-in | `BLOCKED — REQUIRES SEPARATE SESSION-PRESERVATION APPROVAL` | Isolated credential test fixture; synthetic credentials | Yes (Owner) | Isolated authentication test environment |

---

## 4. Total Blocked Test Reconciliation

- **Total Planned Matrix Cases**: **98**
- **Directly Executed / Safely Verified Cases**: 
  - `P6-SHR-010` (A10 — Backend configuration screen / Supabase readiness / offline banner observed on startup): **PASS**
  - `P6-SHR-014` (SET01/SET02 — Local settings switch persistence in shared prefs verified): **PASS**
  - `P6-LIM-001` through `P6-LIM-007` (7 Partial Limitation audits verified against source & runtime state): **7 VERIFIED / PASS AS LIMITATION**
  - `P6-UIO-001` & `P6-UIO-002` (2 UI-Only features verified as stored but unconsumed): **2 VERIFIED / PASS AS UI-ONLY**
  - `P6-BKO-001` & `P6-BKO-002` (2 Backend-Only features verified as uninvoked by UI): **2 VERIFIED / PASS AS BACKEND-ONLY**
- **Total Blocked Cases Recorded**: **85**
  - Parent-role cases blocked: **39 / 39**
  - Child-role cases blocked: **21 / 21**
  - Shared cases blocked: **14 / 16** (P6-SHR-010 and P6-SHR-014 executed/verified)
  - Interconnected cases blocked: **10 / 10**
  - Security case blocked: **1 / 1** (P6-SEC-001 approval-gated)
  - Sum: 39 + 21 + 14 + 10 + 1 = **85**
- **Reconciliation**: 85 blocked + 13 safely audited/verified = **98 / 98 cases fully accounted for**.
