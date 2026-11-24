# 04 — In-Depth Audit of REV-005: Rollout Strategy, Forward Recovery & Feature Flag Architecture

**Document ID:** HAVEN-AUD-004  
**Target Workstream:** HAVEN-QA-003 (`DEF-601` / `MON04`)  
**Target Finding:** REV-005 (HIGH — The Down-Migration Fallacy & Forward Recovery Architecture)  
**Phase:** Phase 1.3 — Independent Closure Verification & Owner Approval Readiness Audit (Strictly Read-Only)  
**Date:** 2026-11-24  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  

---

## 1. Executive Summary

In Phase 1 report `08_implementation_order_and_rollback_plan.md:104-118`, the proposed rollback procedure for Wave 3 (`HAVEN-QA-003`) stated that if an operational defect occurred post-deployment, operators should execute a schema down-migration:
```sql
DROP FUNCTION IF EXISTS public.rotate_device_secret(uuid, text, text, text, uuid);
DROP TABLE IF EXISTS public.device_recovery_challenges CASCADE;
```

This audit independently assesses the systemic consequences of that rollback design, validates the Phase 1.2 replacement architecture (dynamic feature-flag ingress disablement via `FEATURE_RECREDENTIALING_ENABLED = false`), and evaluates all 10 deployment skew scenarios.

---

## 2. Section 10: In-Depth Audit of the Down-Migration Fallacy

### 2.1 The Technical Breakdown of the Down-Migration Fallacy
A database schema down-migration drops or alters structural objects (tables, functions, views, triggers). However, **it cannot roll back persistent data mutations committed to table heaps**:

1. **The Irreversible State Mutation**:
   When `rotate_device_secret` runs, it updates `devices.secret_hash = new_hash` and `devices.installation_id = new_installation_id`.
   If 50 devices complete re-credentialing during a production canary or release window, their hardware KeyStores and the database `devices` table now share new, rotated cryptographic keys.
2. **The Result of Dropping Objects**:
   If an operator executes `DROP FUNCTION rotate_device_secret` and `DROP TABLE device_recovery_challenges CASCADE`:
   - The table `devices` still holds `new_hash` on those 50 rows.
   - If the Edge Functions are rolled back to earlier code, the older Edge Function code does not possess the endpoints required to communicate with the new client state machine.
   - Dropping `device_recovery_challenges CASCADE` permanently destroys the audit trail, in-flight challenge tokens, and rate-limiting history.
   - Worse, those 50 devices cannot authenticate via `/device-telemetry` if client versions are mismatched, and they **CANNOT** re-credential again because the table and RPC are gone!
3. **Audit Determination**: Schema down-migration is a catastrophic anti-pattern for cryptographic identity systems. It guarantees widespread device bricking and violates compliance retention standards.

---

## 3. The Corrected Architecture: Dynamic Ingress Gating & Forward Recovery

### 3.1 Feature Flag Specification: `FEATURE_RECREDENTIALING_ENABLED`
Phase 1.2 replaces down-migrations with dynamic server-side ingress disablement:
- **Flag Name**: `FEATURE_RECREDENTIALING_ENABLED`
- **Location**: Supabase Vault / Edge Function Environment Variables.
- **Fail-Safe Default**: `false` (Disabled until verified post-migration).
- **Ingress Enforcement**:
  - In `/family-admin`: If flag is `false`, `request_recredential_challenge` immediately returns HTTP 503 `service_temporarily_unavailable`.
  - In `/device-register`: If flag is `false`, `redeem_recredential_challenge` immediately returns HTTP 503.
- **The Critical Asymmetry Guard**:
  `verify_device_rotation` remains **ACTIVE** even when `FEATURE_RECREDENTIALING_ENABLED == false`. This ensures that any device that completed rotation immediately prior to emergency shutdown can still verify its status and promote candidate keys, preventing stranded clients!

### 3.2 Non-Interference Invariant: `/device-telemetry`
`FEATURE_RECREDENTIALING_ENABLED` gates **challenge creation and redemption only**. It does **NOT** gate `/device-telemetry` heartbeats. As a result, handsets that completed rotation continue reporting telemetry and uploading location/usage data without interruption during an operational pause.

---

## 4. Audit of the 10 Mandatory Rollout & Version Skew Scenarios

The audit evaluated system behavior across all 10 deployment, version-skew, and recovery scenarios:

| Scenario | Architectural Subsystem State | Client & Server Behavior | Resilience & Recovery Evaluation |
|---|---|---|---|
| **Scenario 1: DB deployed, Client not deployed** | DB schema and RPC exist. Client runs legacy code. | Re-credentialing objects sit completely dormant. Legacy clients continue telemetry unaffected. | **PASS**. Zero risk; database migration is non-breaking. |
| **Scenario 2: RPC deployed, Edge Function not deployed** | Database has RPC. Edge Functions lack re-credentialing endpoints. | Requests to re-credential return HTTP 404. Normal telemetry operates uninterrupted. | **PASS**. Deploy Edge Functions when ready. |
| **Scenario 3: Edge deployed, Client not deployed** | Endpoints live behind `FEATURE_RECREDENTIALING_ENABLED = false`. | Inbound requests return HTTP 503. Legacy clients continue normal operations. | **PASS**. Flag protects system until mobile release. |
| **Scenario 4: Parent client updated, Child client old** | Parent app displays "Reconnect" UI. Child app lacks code entry screen. | Parent generates 6-char code. Child cannot enter it. Code naturally expires after 10m. | **PASS**. Parent prompted to update Child app via app store. |
| **Scenario 5: Child client updated, Parent client old** | Child app prompts for recovery code. Parent lacks issuance button. | Child waits. Parent has no generation UI. Relationship remains preserved. | **PASS**. Parent updates app to issue challenge code. |
| **Scenario 6: Feature enabled but RPC unavailable** | Flag is `true`, but RPC was dropped or failed migration. | Edge Function catches database exception, logs alert, returns HTTP 500 cleanly without crashing. | **PASS**. Zero data corruption; deploy missing RPC. |
| **Scenario 7: Feature disabled after devices rotated** | Flag toggled `false` after 50 devices completed re-credentialing. | Already-rotated devices continue sending telemetry to `/device-telemetry` without issue! | **PASS**. Active devices protected; zero bricking. |
| **Scenario 8: Rotation partially completed (in-flight drop)** | Network drop occurs after DB commit before client receives HTTP 200. | Client reconnects, calls `verify_device_rotation`, server confirms match, client promotes keys. | **PASS**. REV-002 state machine resolves automatically. |
| **Scenario 9: New secret stored, telemetry fails (401)** | Client promoted secret, but telemetry rejected due to key desync. | Client classifies 401 as unconfirmed secret, surfaces recovery UI, allows fresh challenge. | **PASS**. Self-healing recovery path available. |
| **Scenario 10: Interrupted device requires recovery** | Child user clears app data again post-rotation. | App returns to clean unconfirmed state; parent issues fresh challenge; system completes clean cycle. | **PASS**. Cyclic recovery operates reliably. |

---

## 5. Forward Recovery Runbook & Audit Logging Verification

### 5.1 Emergency Triage & Forward Hotfix Runbook
1. **Immediate Pause (< 2 min)**: Set `FEATURE_RECREDENTIALING_ENABLED = false` in Supabase Edge Function environment variables. New challenges are blocked immediately without restarting the database.
2. **DO NOT Run Down-Migrations**: Under no circumstances should tables or functions be dropped.
3. **Active Challenge Drainage**: Active challenges expire naturally within 10 minutes (`expires_at < now()`).
4. **Forward Patching**: Author and test bug fix in disposable staging containers (Edge Function handler or PL/pgSQL logic patch).
5. **Forward Deployment**: Deploy patch to production and re-enable flag (`FEATURE_RECREDENTIALING_ENABLED = true`).

### 5.2 Audit Event Immutability & Completeness
The design enforces immutable audit logging in `public.audit_events` for all lifecycle events:
- `device_recredential_challenge_issued`: Recorded on issuance (includes `challenge_id`, `device_id`, `actor_user_id`).
- `device_recredential_failed`: Recorded on invalid attempt (includes `challenge_id`, `attempt_number`).
- `device_recredential_exhausted`: Recorded on 5th failed attempt (includes `challenge_id`).
- `device_recredentialed`: Recorded on successful rotation (includes `device_id`, `credential_issued_at`).
- `device_rotation_verified`: Recorded on lost-response verification handshake.
Zero secrets, raw tokens, or hashes are ever logged in audit payloads.

**REV-005 Official Status:** **VERIFIED CLOSED BY DESIGN**
