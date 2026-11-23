# 11 — Updated Test Plan & Implementation Wave Readiness

**Document ID:** HAVEN-COR-011  
**Phase:** Phase 1.2 — Remediation Plan Correction & Closure (Strictly Planning-Only)  
**Date:** 2026-11-23  
**Status:** COMPLETE TEST PLAN & READINESS ASSESSMENT  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `56636f62d5144610ae12c89d02d582feb48217fc`  

---

## 1. Overview & Verification Philosophy

This document delivers an updated, rigorous test plan incorporating all edge cases, negative tests, concurrency tests, and accessibility validations identified during Phase 1.1 review.

### Strict Safety & Preservation Invariants:
1. **Tests are specified, NOT executed.** Zero builds, test runs, or runtime executions are performed during this planning phase.
2. **Preserved QA Sessions**: Automated test specifications require mock authentication or isolated test containers; never use live preserved QA accounts.
3. **Zero Credentials in Evidence**: All tests use synthetic test passwords (`'TestPass123!'`) or random hex strings; zero real passwords or API keys are ever included.

---

## 2. Updated Comprehensive Test Specifications by Defect

---

### 2.1 HAVEN-QA-001 (Role Selection Adaptive Layout)

| Test ID | Test Preconditions | Action / Configuration | Expected Result | Required Evidence | Fixture Type |
|---|---|---|---|---|---|
| `TEST-QA001-01` | Phone Portrait (360dp width, scale 3.0, 480dpi) | Pump `RoleSelectionPage` | Adaptive vertical `Column` active; `"Create account"` and `"Sign in"` rendered at 100% width; zero ellipses; text size = 16sp. | RenderParagraph dump (`didExceedMaxLines == false`) | Isolated Widget Test |
| `TEST-QA001-02` | Small Display (320dp width) | Pump `RoleSelectionPage` | Vertical `Column` active; full labels visible; zero horizontal overflow warnings. | Layout overflow check | Isolated Widget Test |
| `TEST-QA001-03` | Accessibility Font Scaling (1.3x) | Set `textScaleFactor = 1.3` | Text expands comfortably inside full-width button; button height expands cleanly; zero truncation. | RenderBox height assertion ($\ge 52\text{ dp}$) | Isolated Widget Test |
| `TEST-QA001-04` | Accessibility Font Scaling (1.5x) | Set `textScaleFactor = 1.5` | Text wraps to second line if necessary without clipping; zero overflow. | RenderParagraph layout assertion | Isolated Widget Test |
| `TEST-QA001-05` | Touch Target Height Assertion | Measure button bounds | Both buttons report physical touch target height $\ge 48\text{ dp}$ per WCAG 2.5.5. | `tester.getSize().height >= 48.0` | Isolated Widget Test |
| `TEST-QA001-06` | Tablet / Landscape (600dp width) | Set display width to 600dp | Adaptive layout switches to horizontal `Row`; both buttons side-by-side with full labels. | Widget hierarchy inspection | Isolated Widget Test |
| `TEST-QA001-07` | Visual Hierarchy Symmetry | Inspect Parent and Child cards | Both buttons share identical 16sp font and symmetric styling; zero visual asymmetry. | Style property assertion | Isolated Widget Test |

---

### 2.2 HAVEN-QA-002 (Password Security & Input Hardening / SEC-001)

| Test ID | Test Preconditions | Action / Configuration | Expected Result | Required Evidence | Fixture Type |
|---|---|---|---|---|---|
| `TEST-QA002-01` | Form rendered in default state | Inspect `AppTextField` with `isPassword: true` | `obscureText == true`, `enableSuggestions == false`, `autocorrect == false`, `textCapitalization == none`. | EditableText properties | Isolated Widget Test |
| `TEST-QA002-02` | Eyeball toggle tapped to visible | Tap `Icons.visibility_outlined` | `obscureText` switches to `false`; `enableSuggestions` and `autocorrect` **REMAIN FALSE**; `Semantics.password` remains `true`. | EditableText & Semantics Node | Isolated Widget Test |
| `TEST-QA002-03` | Repeated toggle stress test | Tap eyeball toggle 10 times | Hardening flags remain permanently `false` across every transition. | Flag assertion loop | Isolated Widget Test |
| `TEST-QA002-04` | Autofill hint inference | Pass `autofillHints: [AutofillHints.password]` without `isPassword` | `isPassword` is automatically inferred as `true`; suggestions suppressed. | EditableText inspection | Isolated Widget Test |
| `TEST-QA002-05` | Registration Confirm Password | Pump `RegisterPage` | Both Password and Confirm Password fields enforce permanent suggestion suppression. | Multi-field inspection | Isolated Widget Test |
| `TEST-QA002-06` | Zero Plaintext Logging | Enter password and submit form | Logcat / debug console inspected; password string is completely absent from logs. | Log buffer capture assertion | Isolated Mock Test |

---

### 2.3 HAVEN-QA-003 (Distributed Credential Re-credentialing Protocol)

| Test ID | Test Preconditions | Action / Configuration | Expected Result | Required Evidence | Fixture Type |
|---|---|---|---|---|---|
| `TEST-QA003-01` | Active challenge in DB | Submit invalid challenge token | RPC commits `attempts = 1`; returns `attempts_remaining: 4`. (REV-001 verified). | SQL `attempts` column check | Disposable PostgreSQL |
| `TEST-QA003-02` | 4 prior failed attempts | Submit 5th invalid challenge token | RPC commits `attempts = 5`, sets `status = 'exhausted'`, `consumed_at = now()`. | SQL `status == 'exhausted'` | Disposable PostgreSQL |
| `TEST-QA003-03` | Exhausted challenge | Submit valid challenge token | RPC rejects request with `max_attempts_exceeded`. | JSON return check | Disposable PostgreSQL |
| `TEST-QA003-04` | Expired challenge ($t > 10\text{m}$) | Submit valid challenge token | RPC sets `status = 'expired'`, `consumed_at = now()`; returns `challenge_expired`. | JSON return check | Disposable PostgreSQL |
| `TEST-QA003-05` | Concurrent redemption race | Send 2 simultaneous redemption HTTP requests | Row lock (`FOR UPDATE`) serializes execution; first succeeds; second returns `already_consumed`. | Deno parallel test | Disposable PostgreSQL |
| `TEST-QA003-06` | Issuance Rate Limiting | Parent requests 4 challenges within 1 hour for same device | 4th request rejected with HTTP 429 `rate_limit_exceeded`. (REV-013 verified). | HTTP response check | Disposable Edge Test |
| `TEST-QA003-07` | Issuance Single-Active Invariant | Parent requests 2nd challenge | 1st challenge automatically marked `status = 'superseded'`. | SQL status check | Disposable PostgreSQL |
| `TEST-QA003-08` | Foreign Child Isolation | Child from Family B redeems challenge for Family A | Server rejects with HTTP 403 `unauthorized`. | HTTP response check | Disposable Edge Test |
| `TEST-QA003-09` | Revoked Device Rejection | Child attempts to re-credential device with `status = 'revoked'` | Server strictly rejects with HTTP 403 `device_revoked`. | HTTP response check | Disposable PostgreSQL |
| `TEST-QA003-10` | Lost HTTP Response Recovery | Network dropped after DB commit; client calls `verify_device_rotation` | Server returns `{ confirmed: true }`; client promotes candidate secret. (REV-002 verified). | KeyStore staging inspection | Native Android Test |
| `TEST-QA003-11` | Client KeyStore Staging Crash | Process killed while candidate keys staged before HTTP call | App restarts; detects staged keys; verifies server never rotated; safely retries redemption. | State machine transition log | Native Android Test |
| `TEST-QA003-12` | Telemetry Resumption | Successful rotation completed | Child sends heartbeat with new `x-device-secret`; server returns HTTP 200; `last_seen_at` advances. | Edge Telemetry log | End-to-End Test Container |
| `TEST-QA003-13` | Emergency Disablement | Set `FEATURE_RECREDENTIALING_ENABLED = false` | Endpoint returns HTTP 503; already-rotated devices continue syncing telemetry normally. | HTTP response check | Disposable Edge Test |

---

### 2.4 HAVEN-QA-004 (Native Notification Permission & Channel Inspection)

| Test ID | Test Preconditions | Action / Configuration | Expected Result | Required Evidence | Fixture Type |
|---|---|---|---|---|---|
| `TEST-QA004-01` | Android 12 (API 31), Notifications ON, Channel Active | Invoke `hasNotifications(context)` | Returns `true`. | Unit test assertion | Robolectric API 31 |
| `TEST-QA004-02` | Android 12 (API 31), Master Switch OFF | Disable app notifications in system settings | Returns `false`. | Unit test assertion | Robolectric API 31 |
| `TEST-QA004-03` | Android 9 (API 28), Master Switch ON, Channel Blocked | Set `guardian_service_channel` importance to `NONE` | Returns `false` (REV-008 verified). | Unit test assertion | Robolectric API 28 |
| `TEST-QA004-04` | Android 14 (API 34), POST_NOTIFICATIONS Denied | Deny runtime `POST_NOTIFICATIONS` | Returns `false`. | Unit test assertion | Robolectric API 34 |
| `TEST-QA004-05` | Android 14 (API 34), POST_NOTIFICATIONS Granted | Grant runtime `POST_NOTIFICATIONS` and channel active | Returns `true`. | Unit test assertion | Robolectric API 34 |

---

### 2.5 HAVEN-QA-005 (Device Repository Active Filtering)

| Test ID | Test Preconditions | Action / Configuration | Expected Result | Required Evidence | Fixture Type |
|---|---|---|---|---|---|
| `TEST-QA005-01` | DB contains 1 active, 1 pending, 1 revoked device | Call `fetchActiveDevices(familyId)` | Returns exactly 1 device (`status == 'active'`). Zero pending or revoked devices returned. | Repository unit test | Mock PostgREST Client |
| `TEST-QA005-02` | DB contains 1 active, 1 revoked device | Call `fetchDeviceHistory(familyId)` | Returns both devices. Revoked device retains `status == DeviceStatus.revoked`. | Repository unit test | Mock PostgREST Client |
| `TEST-QA005-03` | Multi-Child Family | Child A active, Child B revoked | Dashboard renders Child A card only; zero duplicate cards. | Controller unit test | Mock PostgREST Client |

---

### 2.6 HAVEN-QA-006 (Policy Version & Enforcement Presentation)

| Test ID | Test Preconditions | Action / Configuration | Expected Result | Required Evidence | Fixture Type |
|---|---|---|---|---|---|
| `TEST-QA006-01` | `applied: 2, desired: 4, status: 'active'` | Call `resolvePolicyStatus()` | `"Policy v4 · Enforced"`, tone: `success`. | Presentation unit test | Pure Dart Test |
| `TEST-QA006-02` | `applied: 2, desired: 4, status: 'pending', online: true` | Call `resolvePolicyStatus()` | `"Policy v2 · Applying v4..."`, tone: `info`. | Presentation unit test | Pure Dart Test |
| `TEST-QA006-03` | `applied: 2, desired: 4, status: 'pending', online: false` | Call `resolvePolicyStatus()` | `"Policy v2 · Update to v4 pending reconnection"`, tone: `warning`. | Presentation unit test | Pure Dart Test |
| `TEST-QA006-04` | `applied: 2, desired: 4, status: 'failed'` | Call `resolvePolicyStatus()` | `"Policy v2 · Update failed (v4)"`, tone: `danger`. | Presentation unit test | Pure Dart Test |
| `TEST-QA006-05` | `applied: 2, desired: 4, status: 'unsupported'` | Call `resolvePolicyStatus()` | `"Policy v2 · Advisory only (Device unmanaged)"`, tone: `warning`. | Presentation unit test | Pure Dart Test |

---

## 3. Reassessed Implementation Wave Readiness

Following the complete resolution of all 13 Phase 1.1 findings:

```
[Wave 1: Client UI, Security & Native Detection]
├── HAVEN-QA-001 (RoleSelectionPage Adaptive Layout)
├── HAVEN-QA-002 (AppTextField isPassword Hardening)
└── HAVEN-QA-004 (NativePermissions Channel Inspection)
STATUS: READY FOR OWNER APPROVAL (Zero Backend / Zero Migration Dependencies)

[Wave 2: Repository Filtering & State Presentation]
├── HAVEN-QA-005 (fetchActiveDevices Query Isolation)
└── HAVEN-QA-006 (Comprehensive Policy Presentation Model)
STATUS: READY FOR OWNER APPROVAL (Zero Database Migrations; Clean Projection Fixes)

[Wave 3: Distributed Credential Recovery Protocol]
└── HAVEN-QA-003 (Re-credentialing Protocol, KeyStore Staging & RPC)
STATUS: READY FOR OWNER APPROVAL (Gated behind Staging Verification)
```

### Readiness Summary:
- **Wave 1**: **READY FOR OWNER APPROVAL**. Low risk, isolated to client widgets and native bridge.
- **Wave 2**: **READY FOR OWNER APPROVAL**. Low risk, resolves duplicate cards and misleading sync labels.
- **Wave 3**: **READY FOR OWNER APPROVAL (Gated)**. The architecture is now 100% sound. Implementation must be gated behind Gate C (Migration deployment to disposable staging) and Gate D (Edge Function integration tests).
