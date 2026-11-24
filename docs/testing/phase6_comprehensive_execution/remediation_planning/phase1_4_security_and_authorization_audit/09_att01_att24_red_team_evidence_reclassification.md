# Phase 1.4: ATT-01 Through ATT-24 Red-Team Evidence Reclassification

**Document ID:** `HAVEN-AUD-009-PHASE1.4`  
**Phase:** Phase 1.4 — Independent Security Clarification & Final Authorization Gate Audit  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Strict Epistemological Integrity & Adversarial Validation  
**Reference Document:** `docs/testing/phase6_comprehensive_execution/remediation_planning/phase1_3_independent_audit/08_red_team_attack_scenarios_and_stress_tests.md`  

---

## 1. Executive Summary & Epistemological Correction

In Phase 1.3 report `08_red_team_attack_scenarios_and_stress_tests.md`, all 24 red-team scenarios (ATT-01 through ATT-24) were classified with the test status **`PASS`**. 

This Phase 1.4 independent security audit formally challenges and corrects this classification. In a strictly planning-only, read-only phase where:
1. Zero lines of remediation source code have been implemented,
2. Zero database migrations have been applied to PostgreSQL,
3. Zero Edge Functions have been deployed to Deno Deploy,
4. Zero automated integration tests or unit tests have been run, and
5. Zero physical or virtual devices have executed the recovery flows,

**labeling theoretical design analyses as "PASS" is an epistemological category error.** Conflating a sound theoretical architecture on paper with empirical runtime verification misleads stakeholders into believing the software has successfully resisted live adversarial attacks.

### Corrected Status Taxonomy
Phase 1.4 establishes a rigorous, evidence-based status taxonomy:
- **`RUNTIME VERIFIED`**: Empirically executed against live software running in a test harness or staging environment with captured logs, network traces, and state assertions. **Current Count: 0**.
- **`STATICALLY VERIFIED`**: Validated by static analysis, AST inspection, or direct compile-time inspection of existing code in the repository.
- **`DESIGN VERIFIED`**: Validated through formal logic, state-machine analysis, mathematical proof, or architectural modeling against the proposed remediation design.
- **`DOCUMENTATION VERIFIED`**: Validated through reconciliation of documented specifications and schema definitions.
- **`NOT EXECUTED`**: No empirical runtime execution has occurred.

---

## 2. Comprehensive 24-Scenario Reclassification Matrix

The table below reclassifies all 24 scenarios evaluated in Phase 1.3, specifying the evidence basis, identified design conditions, missing verification, and required future authorization gate.

| Scenario ID | Attack / Stress Scenario Name | Phase 1.3 Claim | Phase 1.4 Reclassified Status | Evidence Basis & Verification Analysis | Missing Verification for Runtime "PASS" | Future Gate Mapping |
|---|---|---|---|---|---|---|
| **ATT-01** | Token Space Exhaustion / Brute-Force Attack | PASS | **DESIGN VERIFIED** (Not Executed) | Crockford Base32 entropy math proves $32^6 = 1,073,741,824$ states. At 5 attempts, $P = 4.65 \times 10^{-9}$. Rate limiting prevents large-scale guessing. | Empirical automated test sending 1,000 invalid tokens against staging Edge Function; verify hard lock at attempt 5. | **Gate 6** (Staging Integration) |
| **ATT-02** | Concurrent Redemption Race Condition | PASS | **DESIGN VERIFIED** (Not Executed) | Relational locking via `SELECT ... FOR UPDATE` serializes challenge consumption. `UPDATE ... WHERE status = 'active'` is atomic. | Multi-threaded test runner submitting simultaneous redemption requests with identical token; verify exactly 1 succeeds. | **Gate 6** (Staging Integration) |
| **ATT-03** | Lost Response & Client Key Promotion Deadlock | PASS | **DESIGN VERIFIED** (Not Executed) | 7-state KeyStore machine and idempotent `verify_device_rotation` protocol resolve lost HTTP 200 without re-issuing credentials. | Network-drop simulation (SIGKILL client immediately post-commit); verify client restarts into `RECOVERY_REQUIRED` and resolves via `verify_device_rotation`. | **Gate 6** (Staging Integration) |
| **ATT-04** | Stolen Derived Verifier Replay Attack | PASS | **DESIGN VERIFIED** (Not Executed) | `candidate_secret_hash` stored in DB is a derived SHA-256 verifier, not a bearer credential. Bearer header `x-device-secret` requires pre-image. | Penetration test attempting to invoke `/device-telemetry` using captured `candidate_secret_hash`; verify HTTP 401. | **Gate 6** (Staging Integration) |
| **ATT-05** | Expired / Superseded Token Injection | PASS | **DESIGN VERIFIED** (Not Executed) | SQL predicate `WHERE expires_at > now() AND status = 'active'` invalidates expired or superseded challenges. | Test script submitting expired token (15m01s) and token from superseded challenge; verify rejection. | **Gate 4 / Gate 6** |
| **ATT-06** | KeyStore Key Generation Hardware Failure | PASS | **DESIGN VERIFIED** (Not Executed) | Catch blocks in `SecureStore.kt` catch `KeyStoreException` and `GeneralSecurityException`, rolling back candidate state to `STABLE_OLD`. | Fault-injection unit test in Android Robolectric harness simulating KeyStore crypto engine provider failure. | **Gate 2** (Client Unit Test) |
| **ATT-07** | Client Hardware Keystore Corruption / Loss | PASS | **DESIGN VERIFIED** (Not Executed) | Missing/corrupt keys trigger `RECOVERY_REQUIRED` or clean unpairing path; app does not crash loop. | Simulated unrecoverable hardware key loss (delete SharedPreferences XML while DB active); verify graceful error UI. | **Gate 2 / Gate 8** |
| **ATT-08** | SQL Injection in RPC Parameter Boundary | PASS | **STATICALLY VERIFIED** & **DESIGN VERIFIED** | Supabase RPC passes typed parameters (`UUID`, `TEXT`) through parameterized PostgreSQL query plan; no dynamic SQL concatenation. | Staging Deno test submitting SQL payloads (`' OR 1=1; --`) in token, device_id, and installation_id fields; verify validation failure. | **Gate 4 / Gate 6** |
| **ATT-09** | Constant-Time Equality & Timing Attack | PASS | **DESIGN VERIFIED WITH CONDITIONS** (Not Executed) | PostgreSQL `texteq` is NOT constant-time. Phase 1.4 requires custom `constant_time_equals` function in SQL migration. Avalanche effect mitigates timing leaks. | Differential timing benchmark measuring comparison latency distribution across varying byte prefixes over 100,000 samples. | **Gate 4** (Staging DB) |
| **ATT-10** | Distributed Denial of Service (Challenge Exhaustion) | PASS | **DESIGN VERIFIED WITH CONDITIONS** (Not Executed) | Multi-tier rate limiting (10/parent/hr, 3/device/hr) and DB partial unique index prevent DB bloat. Stateless isolates require DB queries. | Load test flooding `/family-admin` with challenge generation requests; verify HTTP 429 after threshold. | **Gate 6** (Staging Integration) |
| **ATT-11** | Deadlock Under High-Concurrency Edge Operations | PASS | **DESIGN VERIFIED** (Not Executed) | Ordered locking hierarchy (Lock Challenge first, Lock Device second) prevents cyclic lock dependency with `revoke_device`. | Concurrent stress script interleaving `rotate_device_secret` and `revoke_device` across 50 concurrent transactions; verify zero deadlocks. | **Gate 4** (Staging DB) |
| **ATT-12** | Database Host Crash During Key Rotation | PASS | **DESIGN VERIFIED** (Not Executed) | PostgreSQL ACID WAL commit guarantees atomicity. If crash occurs before commit, transaction rolls back cleanly. If after commit, changes persist. | Chaos engineering test: abrupt termination (`kill -9 postgres`) during transaction execution; verify DB recovery consistency. | **Gate 4** (Staging DB) |
| **ATT-13** | Edge Function Isolate Termination Mid-RPC | PASS | **DESIGN VERIFIED** (Not Executed) | Edge Function failure post-RPC triggers client timeout, moving client to `RECOVERY_REQUIRED`. Client resolves state via `verify_device_rotation`. | Deno isolate crash injection immediately following `supabase.rpc()` return; verify client recovers on next launch. | **Gate 6** (Staging Integration) |
| **ATT-14** | Rapid Successive Rotation Storm | PASS | **DESIGN VERIFIED** (Not Executed) | Device rate limit (3/device/hr) and partial unique index physically prevent rapid successive rotation minting. | Automation script issuing back-to-back challenge creation requests; verify 4th request blocked by rate limiter. | **Gate 6** (Staging Integration) |
| **ATT-15** | Cross-Family Device Re-credentialing Hijack | PASS | **DESIGN VERIFIED** (Not Executed) | `request_recredential_challenge` strictly enforces `devices.family_id = parent.family_id`. Redemption verifies device ownership. | Adversarial parent JWT attempting to initiate challenge for a `device_id` belonging to a different `family_id`; verify HTTP 403. | **Gate 6** (Staging Integration) |
| **ATT-16** | Schema Down-Migration State Invalidation | PASS | **DOCUMENTATION VERIFIED** & **DESIGN VERIFIED** | Schema down-migrations are strictly prohibited. Forward-only remediation strategy governed by Wave 3 Gate 3. | Verification that no down-migration script exists or can be applied; test forward recovery runbook. | **Gate 3** (Migration Review) |
| **ATT-17** | Asymmetric Feature Flag Toggling During In-Flight Rotation | PASS | **DESIGN VERIFIED** (Not Executed) | Asymmetric guard keeps `verify_device_rotation` active when `FEATURE_RECREDENTIALING_ENABLED = false`, preventing device stranding. | Disable feature flag while client is in `SERVER_ROTATION_UNKNOWN`; verify client calls `verify_device_rotation` and succeeds. | **Gate 6** (Staging Integration) |
| **ATT-18** | Client Process Termination During Staging Key Write | PASS | **DESIGN VERIFIED** (Not Executed) | `SecureStore.kt` commits staging keys atomically using `editor.commit()`. Atomic commit succeeds or fails as a unit. | Android process kill during `stageNewCredentials`; verify SharedPreferences XML is either fully written or untouched. | **Gate 2** (Android Native Test) |
| **ATT-19** | Android Device Reboot During Recovery Flow | PASS | **DESIGN VERIFIED** (Not Executed) | On system boot, `HAVEN` background worker checks `SecureStore` staging state. If staged keys exist, transitions to `RECOVERY_REQUIRED`. | Device reboot simulation during recovery; verify app state machine on cold start correctly invokes `verify_device_rotation`. | **Gate 6 / Gate 8** |
| **ATT-20** | Network Transition During Redemption Handshake | PASS | **DESIGN VERIFIED** (Not Executed) | Mobile data to Wi-Fi transition causes TCP RST/timeout; handled by `DeviceHttpClient` timeout retry and 7-state recovery machine. | Interrupted socket connection during `POST /device-register`; verify idempotent retry or verification recovery. | **Gate 6** (Staging Integration) |
| **ATT-21** | Rapid Successive Authentication Pin Attempts (UI Brute Force) | PASS | **DESIGN VERIFIED** (Not Executed) | Client PIN entry enforces 5-attempt delay/lockout locally and syncs with backend auth rate limits. | Automated UI test entering rapid incorrect PINs; verify UI disablement and lockout timer. | **Gate 2** (Client Unit Test) |
| **ATT-22** | ObscureText Toggle State Leakage (Password Visibility) | PASS | **STATICALLY VERIFIED** & **DESIGN VERIFIED** | `HAVEN-REV-003` decouples `isPassword: true` from `obscureText: false`. Password input remains masked by default; toggle state is local. | Flutter widget test inspecting `EditableText.obscureText` property toggle; verify text is masked on initialization. | **Gate 2** (Flutter Widget Test) |
| **ATT-23** | Text Scaling Distortion & Layout Overflow Under Max Accessibility | PASS | **DESIGN VERIFIED** (Not Executed) | `HAVEN-REV-004` & `REV-011` implement `LayoutBuilder` with 420dp breakpoint and modern `TextScaler.scale(1.0) > 1.15` wrap threshold. | Flutter widget test rendering `QuickActionsCard` at `textScaleFactor = 2.0` on 320dp, 360dp, 400dp screens; verify 0 overflow exceptions. | **Gate 2** (Flutter Widget Test) |
| **ATT-24** | Notification Channel State Desynchronization Under API 34+ | PASS | **DOCUMENTATION VERIFIED** & **DESIGN VERIFIED** | `HAVEN-REV-008` queries native `NotificationManager.getNotificationChannel("guardian_status")` and handles null gracefully. | Integration test on Android API 34+ device/emulator deleting channel via adb; verify app detects `REQUIRED_CHANNEL_NOT_CREATED`. | **Gate 2 / Gate 8** |

---

## 3. Detailed Technical Analysis of Critical Scenario Clusters

### 3.1 Cluster 1: Credential Brute-Force & Side Channels (ATT-01, ATT-09, ATT-10)
- **Phase 1.3 Vulnerability**: Relied on theoretical network jitter to mask timing attacks and claimed in-memory rate limiting was adequate.
- **Phase 1.4 Hardening**: 
  - Proved Crockford Base32 delivers exactly 30.0 bits of true entropy ($1.074 \times 10^9$ codes).
  - Reclassified ATT-09 as `DESIGN VERIFIED WITH CONDITIONS`, requiring the physical deployment of `constant_time_equals` in SQL migration script to eliminate early-exit leaks in `texteq`.
  - Reclassified ATT-10 as requiring persistent database checks and the unique partial index `idx_device_recovery_single_active`.

### 3.2 Cluster 2: Lost Response, Concurrency & Crash Recovery (ATT-02, ATT-03, ATT-11, ATT-12, ATT-13)
- **Phase 1.3 Vulnerability**: Conflated design diagrams with verified concurrency resistance.
- **Phase 1.4 Hardening**:
  - Expanded client state model from 5 states to **7 authoritative states**, explicitly defining recovery transitions for `SERVER_ROTATION_UNKNOWN` and `RECOVERY_REQUIRED`.
  - Identified that PostgreSQL transaction isolation and row locking (`SELECT FOR UPDATE`) prevent deadlocks with device revocation, but runtime proof requires Gate 4 / Gate 6 stress execution.

### 3.3 Cluster 3: Client Security & Accessibility (ATT-21, ATT-22, ATT-23, ATT-24)
- **Phase 1.3 Vulnerability**: Did not verify actual call sites or modern Flutter API deprecations.
- **Phase 1.4 Hardening**:
  - ATT-22 statically verified against 3 actual call sites (`auth_form_fields.dart`, `parent_pin_dialog.dart`, `login_page.dart`); purged non-existent `role_selection_page.dart` PIN caller.
  - ATT-23 verified modern Flutter 3.16+ `TextScaler` replacing deprecated `MediaQueryData.textScaleFactor`.
  - ATT-24 verified canonical channel ID `"guardian_status"` in `GuardianService.kt:36`.

---

## 4. Conclusion & Summary of Reclassified Totals

| Classification Status | Scenario Count | Percentage |
|---|---|---|
| **`RUNTIME VERIFIED`** | **0** | **0.0%** |
| **`DESIGN VERIFIED`** | **19** | **79.2%** |
| **`STATICALLY VERIFIED & DESIGN VERIFIED`** | **3** | **12.5%** |
| **`DOCUMENTATION VERIFIED & DESIGN VERIFIED`** | **2** | **8.3%** |
| **Total Scenarios Evaluated** | **24** | **100.0%** |

No scenario is permitted to claim runtime verification until code is implemented and verified under the Canonical 8-Gate Lifecycle.
