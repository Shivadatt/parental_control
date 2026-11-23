# 04 — Parent Session and Environment Discrepancy Independent Investigation

**Audit Phase:** Fourth-Party Independent QA Documentation & Evidence Review  
**Auditor:** Independent Fourth-Party QA Auditor  
**Date:** 2026-11-23  
**Subject:** Investigation of Parent Session Discrepancy Between Phase 6 Run 8 and Phase 6 Comprehensive Execution  
**Evaluated Reports:** `docs/testing/phase_6_comprehensive_manual_testing/reports/21_run8_ai_parent_login_result.md`, `docs/testing/phase6_comprehensive_execution/01_qa_execution_summary.md`, `02_parent_mode_execution_report.md`, `12_environment_and_evidence_register.md`

---

## 1. The Discrepancy Statement

A major documentary discrepancy exists between the earlier Phase 6 Run 8 documentation and the Phase 6 Comprehensive Execution reports:

1. **Phase 6 Run 8 (Earlier Today, 11:03–11:07 AM)**:
   - Documented in `docs/testing/phase_6_comprehensive_manual_testing/reports/21_run8_ai_parent_login_result.md`.
   - Reported State: The Parent session was **authenticated** on the Pixel 9 emulator (`emulator-5554`) as `ankit@gmail.com` in family `demo`.
   - Supporting Evidence: `screenshots/parent/48_run8_after_login.png` (Parent dashboard) and `49_run8_settings_identity.png` (Settings identity).
   - Claimed Result: **PASS — Parent dashboard visible and identity verified**.

2. **Phase 6 Comprehensive Execution (This Afternoon, 16:22–16:47 PM)**:
   - Documented in `docs/testing/phase6_comprehensive_execution/01_qa_execution_summary.md` and `02_parent_mode_execution_report.md`.
   - Reported State: The Pixel 9 emulator was **unauthenticated**, displaying `AppRoutes.roleSelection` ("Get started — How will you use Parent Control?") with a banner reading *"Last choice on this device: Parent Mode. Sign in or create an account; the server profile still decides access."*.
   - Supporting Evidence: `docs/testing/phase6_comprehensive_execution/evidence/parent_initial.png` and `logcat_auth_signout_parent.txt`.
   - Reported Log Event: `11-23 16:23:03.074 28143 28143 I flutter : supabase.auth: INFO: Signing out user with scope: local`.
   - Consequence: All 39 Parent-role test cases were classified as `BLOCKED — EXISTING AUTHENTICATED SESSION NOT AVAILABLE. OWNER INTERVENTION REQUIRED`.

---

## 2. Independent Documentary & Artifact Inspection

### 2.1 Verification of Run 8 Artifacts
The independent auditor verified that the historical Run 8 artifacts exist on disk with the following metadata:

| Artifact Path | File Size | Timestamp | Content Verification |
|---|---|---|---|
| `docs/testing/phase_6_comprehensive_manual_testing/screenshots/parent/48_run8_after_login.png` | 192,004 bytes | 2026-11-23 11:03:13 | Genuine screenshot showing active Parent Dashboard with family `demo` and device list. |
| `docs/testing/phase_6_comprehensive_manual_testing/screenshots/parent/49_run8_settings_identity.png` | 225,060 bytes | 2026-11-23 11:07:41 | Genuine screenshot showing Settings tab with email `ankit@gmail.com`, role `Parent`, family `demo`. |
| `docs/testing/phase_6_comprehensive_manual_testing/reports/21_run8_ai_parent_login_result.md` | 2,070 bytes | 2026-11-23 11:10:00 | Authoritative Run 8 execution log detailing sign-in. |

### 2.2 Verification of Comprehensive Execution Artifacts
The independent auditor verified the new execution artifacts generated at the start of the current audit:

| Artifact Path | File Size | Timestamp | Content Verification |
|---|---|---|---|
| `docs/testing/phase6_comprehensive_execution/evidence/parent_initial.png` | 218,283 bytes | 2026-11-23 16:24:14 | Genuine screenshot of Pixel 9 emulator at `AppRoutes.roleSelection`. |
| `docs/testing/phase6_comprehensive_execution/evidence/logcat_auth_signout_parent.txt` | 110 bytes | 2026-11-23 16:32:44 | Redacted logcat: `11-23 16:23:03.074 I flutter : supabase.auth: INFO: Signing out user with scope: local`. |
| `docs/testing/phase6_comprehensive_execution/evidence/logcat_auth_signout_child.txt` | 110 bytes | 2026-11-23 16:32:44 | Redacted logcat: `11-23 16:22:48.594 I flutter : supabase.auth: INFO: Signing out user with scope: local`. |
| `shared_prefs/FlutterSharedPreferences.xml` (Pixel 9) | 125 bytes | 2026-11-23 16:23:00 | Contains `<string name="flutter.cached_role">parent</string>`. |
| `shared_prefs/FlutterSharedPreferences.xml` (Realme) | 124 bytes | 2026-11-23 16:22:00 | Contains `<string name="flutter.cached_role">child</string>`. |

---

## 3. Technical Causality Analysis: What Does "Signing out user with scope: local" Mean?

The execution report observed:
`11-23 16:23:03.074 I flutter : supabase.auth: INFO: Signing out user with scope: local`

The independent auditor analyzed the Supabase Gotrue Dart client implementation (`gotrue-dart` / `supabase_flutter`):
1. **Gotrue Sign-Out Scopes**:
   - `SignOutScope.global`: Sends an HTTP POST to `/auth/v1/logout?scope=global`, revoking the session token on the backend server across all devices.
   - `SignOutScope.others`: Revokes tokens on other devices while preserving local state.
   - `SignOutScope.local`: **Purges tokens from local storage ONLY, making NO network call to Supabase**.
2. **When Gotrue Emits `SignOutScope.local` Automatically**:
   During app startup (`_initializeAuth()`), Gotrue reads the saved refresh token from local secure storage. If:
   - The token has reached its refresh TTL and is rejected, OR
   - The refresh token is malformed, empty, or un-decryptable in KeyStore, OR
   - The token refresh network handshake fails with an unrecoverable auth error (e.g., token already revoked server-side),
   Gotrue's internal handler calls `_removeSession()`, which automatically emits:  
   `supabase.auth: INFO: Signing out user with scope: local`.
3. **Local Role Cache Persistence**:
   While the Supabase auth token was cleared, `FlutterSharedPreferences.xml` retained `flutter.cached_role = parent` on the emulator and `child` on the physical phone. When `AuthSessionFlow.resolve()` found `_auth.currentUserId == null`, it directed the app to `AppRoutes.roleSelection`. The role selection page detected `cachedRole` and displayed: *"Last choice on this device: Parent Mode"*.

---

## 4. Rigorous Categorization of Proof

In compliance with Section 7 of the Audit Mandate:

| Layer | Assessment |
|---|---|
| **Observed Fact** | The Pixel 9 emulator had an active authenticated session at 11:07 AM (Run 8). When the audit began at 16:22 PM, both the Pixel 9 emulator and the Realme phone were unauthenticated at `AppRoutes.roleSelection`. |
| **Observed Log Event** | Upon app launch/focus at 16:23:03 (Parent) and 16:22:48 (Child), the Supabase Flutter client emitted `supabase.auth: INFO: Signing out user with scope: local`. |
| **Suspected Cause** | The app was closed, restarted, or resumed after token expiration or token invalidation. On initialization, the Gotrue client failed to restore the session from secure storage, executing a local scope sign-out callback. |
| **Proven Cause** | **NOT INDEPENDENTLY PROVEN**. The available evidence proves that the session was absent and that Gotrue cleaned up local state. However, the exact initiating trigger between 11:07 AM and 16:22 PM (e.g., manual sign-out, session timeout/expiry, backend token revocation, or KeyStore decryption failure across app process restarts) was not captured in existing logcat files. |

---

## 5. Audit Finding (`AUDIT-003` — Medium Severity)

- **Issue**: The QA execution report accurately recorded the observed session absence and truthfully obeyed Rule 2.1 by refusing to enter credentials. However, in prose descriptions, the report occasionally implied that the log phrase *"Signing out user with scope: local"* proved an intentional logout event occurred on startup.
- **Auditor Correction**: The log event indicates an internal SDK cleanup triggered by an un-restorable session, not necessarily an active user logout.

### Final Discrepancy Classification: **PARTIALLY EXPLAINED**
The observed absence of the session is 100% verified by screenshots, logs, and dumpsys data. The internal SDK mechanism (`SignOutScope.local`) is technically explained. The original external trigger that invalidated the token between 11:07 AM and 16:22 PM remains unrecorded and unproven.
