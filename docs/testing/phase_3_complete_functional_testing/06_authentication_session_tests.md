# 06 — Authentication and Session Tests

**Date:** 2026-11-21  
**Statuses:** PASS / FAIL / BLOCKED / NOT_TESTED / AUTHORIZATION_REQUIRED

---

## 1. Live/session tests

| Test ID | Test | Expected | Actual | Status |
|---|---|---|---|---|
| A01 | Parent existing session restore | Parent shell without login | Dashboard restored; family `demo` | PASS |
| A02 | Child existing session restore | Child shell without login | Child Home restored; family `demo` | PASS |
| A03 | Parent role resolution | Parent shell only | Dashboard/Devices/Alerts/Settings | PASS |
| A04 | Child role resolution | Child shell only | Home/Rules/Requests/Settings | PASS |
| A05 | Parent fresh password login | Sign in with owner-entered password | Not performed | NOT_TESTED |
| A06 | Child fresh password login | Sign in with owner-entered password | Not performed | NOT_TESTED |
| A07 | Registration | New account with intended role | Not performed | NOT_TESTED |
| A08 | Email verification | Verification flow and deep link | Not performed | NOT_TESTED |
| A09 | Expired/invalid session | Safe redirect to login, no data leak | Not performed | NOT_TESTED |
| A10 | Unauthorized cross-role navigation | Access denied | Not performed | NOT_TESTED |
| A11 | Sign out | Local session cleared, service stopped | Would change session state | AUTHORIZATION_REQUIRED |
| A12 | Parent background/resume | Session survives | Resumed signed in | PASS |
| A13 | Child background/resume | Session survives | Relaunched signed in | PASS |
| A14 | Session after process restart | No unexpected identity loss | Child relaunched; family/device still resolved | PASS |
| A15 | Wrong-password message | Specific safe error | Not retested | NOT_TESTED |

No password was requested, typed, logged or stored. The owner would have to enter credentials manually for A05–A09.

---

## 2. Automated auth coverage (not a live-device substitute)

Existing Flutter tests:

- `test/features/auth/auth_session_flow_test.dart`
- `test/features/auth/login_controller_test.dart`
- `test/features/child/child_session_lifetime_test.dart`
- `test/features/child/child_settings_gating_test.dart`
- `test/features/settings/account_privacy_controller_test.dart`

These passed as part of the **493/493** Flutter suite. They verify role routing, session resolution and gating logic, but do not prove hosted Auth behavior or password entry.

---

## 3. Findings

- Existing sessions and role resolution work on both devices.
- No authentication failure was observed.
- Fresh login, registration, email verification, expired-session handling and sign-out remain unverified.
- No account/credential state was changed.

---

## 4. Auth verdict

**PASS** — persisted-session authentication and role resolution on both devices.  
**NOT_TESTED** — fresh credential flows and expiry handling.  
No auth-related defect was found in this pass.
