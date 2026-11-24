# Phase 1.5: Six Findings Closure Register

**Document ID:** `HAVEN-AUD-002-PHASE1.5`  
**Phase:** Phase 1.5 — Independent Final Consistency & Security Closure Review  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Formal Closure & Evidentiary Reconciliation  

---

## 1. Executive Summary

This register records the formal, evidence-backed closure analysis for all six mandatory findings identified during the Phase 1.4 audit cycle. Each finding is analyzed against the physical codebase, schema migrations, documentation history, and runtime security realities, providing unambiguous determinations and mandatory conditions for downstream implementation waves.

---

## 2. Comprehensive Finding Analysis & Closure Records

### 2.1 Finding 1 — Wave Assignment Inconsistency
- **Finding Description**: Phase 1.4 documents contained contradictory Wave assignments and mismatched defect titles (e.g., swapping QA-001 and QA-002, and swapping QA-004 and QA-005), diverging from the master defect register.
- **Root Cause Analysis**: During Phase 1.4 authoring, defect IDs were conflated with their internal priority order rather than their historical identifiers established in the authoritative Phase 6 QA execution defect register (`09_defect_register.md`).
- **Evidence Inspected**:
  - `docs/testing/phase6_comprehensive_execution/09_defect_register.md:11-19` (Authoritative defect definitions).
  - `docs/testing/phase6_comprehensive_execution/remediation_planning/08_implementation_order_and_rollback_plan.md:21-42` (Original sequencing).
- **Authoritative Canonical Assignment Established**:
  - **Wave 1 (Client Hardening)**: 
    - `HAVEN-QA-001`: Action button text truncated ("Create acc...") on Role Selection screen.
    - `HAVEN-QA-002`: Password input exposes plaintext / lacks secure input hardening (SEC-001).
    - `HAVEN-QA-004`: Notification permission reports false-positive "Granted" (DEF-604).
  - **Wave 2 (Client Query & State Presentation)**:
    - `HAVEN-QA-005`: Revoked devices duplicated in Parent dashboard and device list (DEF-602).
    - `HAVEN-QA-006`: Policy version inconsistency between Dashboard and Devices tab (DEF-603).
  - **Wave 3 (Distributed Identity Protocol)**:
    - `HAVEN-QA-003`: Device re-credentialing failure breaks heartbeat, usage & location uploads (DEF-601).
- **Evidentiary Category**: `Verified by documentation inspection`.
- **Closure Determination**: **CLOSED BY DESIGNATION**. (Reconciled in documentation; implementation requires owner Gate 2/3 approval).

---

### 2.2 Finding 2 — PostgreSQL Constant-Time Comparison Claim
- **Finding Description**: Phase 1.4 claimed that a custom PL/pgSQL function (`constant_time_equals`) iterating byte-by-byte guarantees constant-time comparison in PostgreSQL, mitigating side-channel timing leaks.
- **Independent Security Challenge**:
  - The PostgreSQL query engine executes PL/pgSQL interpreted via `pl_exec.c`.
  - Operations like `substr(p_a, v_i, 1)` allocate `text` slices in PostgreSQL `MemoryContext`, invoke character encoding decoders, and undergo branch evaluation on each loop iteration.
  - The function includes an early-exit branch (`if length(p_a) <> length(p_b) then return false; end if`).
  - CPU micro-architecture, branch prediction buffers, and LLVM JIT compilation (if enabled) can introduce microsecond timing variations.
  - The proposed function has **NOT been implemented or deployed** in any migration file.
- **Evidence Inspected**:
  - PostgreSQL source documentation for `texteq()` and PL/pgSQL interpreter execution.
  - Directory `supabase/migrations/` (confirms zero implementation of `constant_time_equals` in repository).
- **Authoritative Determination**:
  - **Choice**: **`NOT VERIFIED — REQUIRES PROVEN PRIMITIVE`**.
  - **Design Safeguard**: Note that because the input is hashed with SHA-256 before comparison and locked after 5 attempts, an attacker cannot conduct statistical timing attacks across network jitter. However, theoretical constant-time behavior cannot be claimed without a verified C-level extension or benchmarked primitive.
- **Closure Determination**: **CLOSED WITH CONDITIONS**. (Classified as design requirement; requires security testing in Gate 4/6).

---

### 2.3 Finding 3 — Candidate Secret Hash Bearer-Credential & Replay Risk
- **Finding Description**: Phase 1.4 argued that because `candidate_secret_hash` is a derived SHA-256 verifier, it is not a bearer credential and cannot be replayed or abused.
- **Independent Security Challenge**:
  - Does possession of `candidate_secret_hash` authorize rotation? **No**. The rotation RPC requires: (1) an active challenge record, (2) the valid 6-char Base32 token, (3) matching `device_id`, and (4) authenticated Child JWT.
  - Can the redemption request be replayed? **No**. Upon redemption, the challenge is immediately updated to `status = 'redeemed'`, and subsequent requests fail.
  - Can `verify_device_rotation` be abused? `verify_device_rotation` is read-only and requires a Child JWT matching the device owner. It returns `confirmed: true/false` without modifying state.
  - Can intercepted candidate hashes authorize telemetry? **No**. Telemetry requires the raw plaintext `x-device-secret`. SHA-256 is pre-image resistant.
  - Residual Risk: If error logs or telemetry capture candidate hashes, it does not leak the secret, but logging verifiers violates zero-leakage hygiene.
- **Evidence Inspected**:
  - `supabase/functions/_shared/auth.ts:297-343` (Header extraction and hash comparison).
  - `docs/testing/phase_4_device_recredentialing_design/02_protocol_state_machine.md`.
- **Authoritative Determination**:
  - **Choice**: **`DESIGN-ONLY — REQUIRES SECURITY TESTING`**.
  - Protocol architecture is sound on paper, but implementation in Edge Functions and RPC must be tested against replay, race conditions, and error logging leakage in disposable staging.
- **Closure Determination**: **CLOSED WITH CONDITIONS**. (Design verified; runtime security validation required at Gate 6).

---

### 2.4 Finding 4 — KeyStore Crash-Recovery Claims
- **Finding Description**: Phase 1.4 claimed that 15 crash points (CP-01 through CP-15) were "VERIFIED PASS" under the 7-state KeyStore machine, citing `editor.commit()` atomic writes.
- **Independent Security Challenge**:
  - `SharedPreferences.Editor.commit()` is atomic on the filesystem level (writing to XML flash), preventing truncated files.
  - However, filesystem atomicity does **NOT** prove protocol crash recovery across the network boundary (e.g., if the client crashes *after* DB commit but *before* HTTP 200 is parsed).
  - The 7-state machine (`STABLE_OLD` $\to$ `NEW_CREDENTIAL_STAGED` $\to$ `SERVER_ROTATION_UNKNOWN` $\to$ `SERVER_ROTATION_CONFIRMED` $\to$ `STABLE_NEW_CREDENTIAL`, with `RECOVERY_REQUIRED` and `RECOVERY_FAILED`) logically accounts for all 15 crash points.
  - However, no automated crash tests, process kill injections, or power loss simulations have been executed on physical or emulator devices.
- **Evidence Inspected**:
  - `android/app/src/main/kotlin/com/parentcontrol/parent_control/SecureStore.kt:71-105` (KeyStore initialization and prefs storage).
  - `docs/testing/phase6_comprehensive_execution/remediation_planning/phase1_4_security_and_authorization_audit/05_rev002_keystore_crash_recovery_and_idempotency_review.md`.
- **Authoritative Determination**:
  - The 15 crash points must remain **`DESIGN VERIFIED (REQUIRES RUNTIME CRASH TESTING)`**.
  - Calling paper crash scenarios "verified" is an epistemological overstatement that is formally retracted.
- **Closure Determination**: **CLOSED WITH CONDITIONS**. (Design validated; runtime fault injection required under Gate 6/8).

---

### 2.5 Finding 5 — Policy Lifecycle State vs Enforcement Diagnostic State
- **Finding Description**: Earlier planning documentation conflated database persistence states with runtime enforcement diagnostics, mixing `'enforced'`, `'active'`, and version tracking into an inconsistent state model.
- **Independent Schema & Source Inspection**:
  - Inspected `supabase/migrations/20260101000000_core.sql`:
    - Table `devices.status` (line 91-92): strictly `('active', 'revoked', 'pending')`.
    - Table `device_policies.enforcement_status` (line 186): strictly `('pending', 'enforced', 'failed', 'unsupported')`.
    - Table `device_commands.status` (line 206): strictly `('pending', 'delivered', 'succeeded', 'failed', 'expired')`.
  - Discovered that `'active'` is a **device lifecycle status**, while `'enforced'` is a **policy enforcement diagnostic status**. Conflating them created documentation contradictions.
- **Authoritative Model Reconciliation**:
  - **Layer 1: Device Persisted State**: `devices.status` (`active`, `revoked`, `pending`). Managed by parent admin & enrollment.
  - **Layer 2: Policy Persisted Diagnostic**: `device_policies.enforcement_status` (`pending`, `enforced`, `failed`, `unsupported`). Managed by device command ack.
  - **Layer 3: Command Transport State**: `device_commands.status` (`pending`, `delivered`, `succeeded`, `failed`, `expired`). Managed by sync daemon.
  - **Layer 4: Version Triad**:
    1. *Desired Version*: Max `version` in `device_policies` for device.
    2. *Reported Version*: `devices.policy_version` (reported by telemetry).
    3. *Acknowledged Version*: `device_policies.version` where `acknowledged_at IS NOT NULL` and `enforcement_status = 'enforced'`.
- **Evidentiary Category**: `Verified by source inspection`.
- **Closure Determination**: **CLOSED BY SPECIFICATION**. (Multi-layer model formally documented; zero schema edits required).

---

### 2.6 Finding 6 — Notification Diagnostic State Dimension Mixing
- **Finding Description**: Phase 1.4 grouped unrelated conditions (`ACTIVE`, `CHANNEL_BLOCKED`, `NOTIFICATIONS_DISABLED`, `REQUIRED_CHANNEL_NOT_CREATED`, `SERVICE_RUNNING`, `PERMISSION_DENIED`) into a single flat diagnostic enum, resulting in false-positive reporting on Android 12.
- **Independent Source Inspection**:
  - `NativePermissions.kt:29-32`:
    ```kotlin
    fun hasNotifications(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return granted(context, Manifest.permission.POST_NOTIFICATIONS)
    }
    ```
    On Android 12 (API 31/32), this unconditionally returned `true`, even if app notifications were disabled in system settings!
  - `GuardianService.kt:36`: `CHANNEL_ID = "guardian_status"`.
  - `GuardianService.kt:48`: `isRunning: Boolean`.
- **Authoritative 3-Dimensional Decoupled Model**:
  1. **Dimension 1: Notification Permission**:
     - Android 13+ (API 33+): `Granted` vs `Denied` (via `POST_NOTIFICATIONS`).
     - Android 12 and below: `Not Applicable` (runtime permission does not exist).
     - Global App Enablement: `Enabled` vs `Disabled` (via `NotificationManagerCompat.areNotificationsEnabled()`).
  2. **Dimension 2: Notification Channel**:
     - Android 8.0+ (API 26+): `Available` (importance > 0), `Blocked` (importance == 0), `Not Created` (null), `Not Applicable` (< API 26).
  3. **Dimension 3: Guardian Service Runtime**:
     - `Running`, `Stopped`, `Blocked By System`.
- **Evidentiary Category**: `Verified by source inspection`.
- **Closure Determination**: **CLOSED BY SPECIFICATION**. (Orthogonal 3-dimensional mapping eliminates false positives; implementation queued for Wave 1).

---

## 3. Master Findings Closure Summary Table

| Finding ID | Domain | Phase 1.4 Ambiguity | Phase 1.5 Final Resolution | Final Status | Downstream Gate |
|---|---|---|---|---|---|
| **Finding 1** | Governance | Mismatched defect titles & swapped Waves | Canonical Wave 1, 2, 3 assignment restored per defect register | **CLOSED BY DESIGNATION** | Gate 2 & Gate 3 |
| **Finding 2** | Cryptography | Claimed PL/pgSQL loop guarantees constant time | Overturned claim; classified as `NOT VERIFIED — REQUIRES PROVEN PRIMITIVE` | **CLOSED WITH CONDITIONS** | Gate 4 & Gate 6 |
| **Finding 3** | Security | Claimed SHA-256 pre-image alone prevents replay | Reconciled threat model; classified as `DESIGN-ONLY — REQUIRES SECURITY TESTING` | **CLOSED WITH CONDITIONS** | Gate 5 & Gate 6 |
| **Finding 4** | Native Android | Claimed 15 crash points "VERIFIED PASS" | Overturned claim; classified as `DESIGN VERIFIED (REQUIRES RUNTIME CRASH TESTING)` | **CLOSED WITH CONDITIONS** | Gate 6 & Gate 8 |
| **Finding 5** | Database | Conflated DB status with policy diagnostics | Decoupled into 4 orthogonal layers: Device, Policy, Command, Version | **CLOSED BY SPECIFICATION** | Gate 2 (Wave 2) |
| **Finding 6** | Native Android | Mixed permissions, channels, and service running | Decoupled into 3 independent dimensions: Permission, Channel, Runtime | **CLOSED BY SPECIFICATION** | Gate 2 (Wave 1) |

All six mandatory closure targets are formally closed with clear, evidence-based parameters.
