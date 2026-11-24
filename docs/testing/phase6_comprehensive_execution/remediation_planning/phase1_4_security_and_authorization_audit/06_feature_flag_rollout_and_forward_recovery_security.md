# 06 — Feature Flag Rollout, Ingress Disablement & Forward Recovery Security

**Document ID:** `HAVEN-AUD-006-PHASE1.4`  
**Phase:** Phase 1.4 — Independent Security Clarification, Protocol Verification & Final Owner Approval Readiness  
**Date:** 2026-11-24  
**Target Workstream:** WORKSTREAM B5 (Feature Flag Behavior, Skew Compatibility & Forward Recovery)  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  

---

## 1. Executive Summary

This report evaluates the operational and architectural security of the feature-flagged rollout and forward-recovery mechanisms designed to replace schema down-migrations.

Phase 1.1 identified that dropping database tables or functions post-deployment permanently bricks devices that completed credential rotation during the canary window. Phase 1.2 proposed a dynamic feature flag `FEATURE_RECREDENTIALING_ENABLED`.

This audit rigorously verifies:
1. Whether emergency feature flag disablement can accidentally block or strand devices that have already rotated their credentials on the server but have not completed local KeyStore promotion.
2. The exact ingress behavior across old and new client versions.
3. The forward-recovery hotfix obligations for operations.

---

## 2. Feature Flag Specification & The Asymmetric Ingress Guard

### 2.1 The Feature Flag Invariant
- **Flag Name**: `FEATURE_RECREDENTIALING_ENABLED`
- **Storage Location**: Supabase Vault / Edge Function Environment Configuration.
- **Fail-Safe Default**: `false` (Disabled until explicitly activated post-migration).

### 2.2 The Asymmetric Ingress Guard (Preventing Stranded In-Flight Devices)
A critical flaw in standard feature-flag implementations is shutting down all related endpoints uniformly.
The audit verified the following **MANDATORY ASYMMETRIC INGRESS BEHAVIOR**:

```
When FEATURE_RECREDENTIALING_ENABLED == false:
├── POST /family-admin (request_recredential_challenge) ==> HTTP 503 Service Unavailable (BLOCKED)
├── POST /device-register (redeem_recredential_challenge) ==> HTTP 503 Service Unavailable (BLOCKED)
├── POST /device-register (verify_device_rotation)       ==> HTTP 200 Handshake Evaluation (STRICTLY ACTIVE!)
└── POST /device-telemetry (Normal Heartbeat)            ==> HTTP 200 Telemetry Normal (STRICTLY ACTIVE!)
```

### Why This Asymmetry is Mandatory:
If an operator detects an operational anomaly and sets `FEATURE_RECREDENTIALING_ENABLED = false`:
1. **New Challenges Blocked**: No parent can request a new challenge, and no child can redeem a new challenge. Table row insertion stops instantly.
2. **In-Flight Devices Protected**: Suppose Device 42 redeemed its challenge, PostgreSQL updated `devices.secret_hash`, and the radio dropped. The app restarts in `NEW_CREDENTIAL_STAGED`. When it calls `verify_device_rotation`, the endpoint **MUST REMAIN ACTIVE** to confirm the rotation and permit candidate key promotion!
3. **Telemetry Protected**: Devices that already rotated their secret continue sending heartbeats to `/device-telemetry` using their new credentials without interruption.

---

## 3. Comprehensive Deployment Skew Analysis across 10 Scenarios

The audit evaluated system stability across all 10 component version-skew permutations:

| Skew Scenario | Database Schema & RPC | Edge Functions | Mobile Clients | System Behavior & Ingress Handling | Resilience Assessment |
|---|---|---|---|---|---|
| **1. DB Only** | Deployed | Legacy | Legacy | DB objects sit completely dormant. Legacy clients communicate normally. | **PASS**. Zero regression risk. |
| **2. RPC Deployed, Edge Old** | Deployed | Legacy | Legacy | Endpoints return HTTP 404 for re-credentialing actions. Telemetry normal. | **PASS**. Safe; deploy Edge Functions next. |
| **3. Edge Live, Flag False** | Deployed | Live (Flag `false`) | Legacy | Inbound re-credentialing requests return HTTP 503. Telemetry normal. | **PASS**. Safe canary gating. |
| **4. Parent Updated, Child Old** | Deployed | Live (Flag `true`) | Parent New, Child Old | Parent issues challenge; Child app lacks entry form. Code expires in 10m. | **PASS**. Stale challenge expires harmlessly. |
| **5. Child Updated, Parent Old** | Deployed | Live (Flag `true`) | Parent Old, Child New | Child app prompts for code; Parent app has no generation button. | **PASS**. Parent updates app via store. |
| **6. Flag True, RPC Missing** | Missing | Live (Flag `true`) | New | Edge Function catches missing RPC error, returns HTTP 500, logs alert. | **PASS**. Fails closed; zero data corruption. |
| **7. Emergency Shutdown** | Deployed | Live (Flag `false`) | New (50 Rotated) | 50 rotated devices continue telemetry unaffected! In-flight devices finish verification. | **PASS**. Zero active device bricking. |
| **8. In-Flight Network Drop** | Deployed | Live (Flag `true`) | In-Flight Drop | Handset detects staged keys on boot, queries verification, promotes keys. | **PASS**. REV-002 machine self-heals. |
| **9. Telemetry Rejection (401)** | Deployed | Live (Flag `true`) | Desynchronized | Handset classifies 401 as unconfirmed secret, surfaces recovery UI for fresh code. | **PASS**. Clean recovery path. |
| **10. Cyclic Storage Wipe** | Deployed | Live (Flag `true`) | Reinstalled Again | OS sandbox deletion is clean; app starts unlinked; parent re-issues code. | **PASS**. Cyclic recovery verified. |

---

## 4. Forward-Recovery Runbook & Operational Obligations

In the event of an operational anomaly in production Wave 3:
1. **Step 1 (Immediate Ingress Throttle)**: Toggle `FEATURE_RECREDENTIALING_ENABLED = false` in Supabase Vault. Execution time: < 60 seconds. Zero database restart required.
2. **Step 2 (DO NOT Execute SQL Down-Migrations)**: Strict prohibition against `DROP TABLE` or `DROP FUNCTION`. Existing credentials and audit trails remain preserved.
3. **Step 3 (Drain In-Flight Challenges)**: Any unconsumed active challenges naturally expire within 10 minutes (`expires_at < now()`).
4. **Step 4 (Triage via Immutable Audit Logs)**: Query `public.audit_events WHERE event_type LIKE 'device_recredential%'` to determine failure points.
5. **Step 5 (Forward Patch & Deploy)**: Author fix in Edge Function or SQL logic, verify in disposable staging container, apply forward migration, and re-enable flag (`FEATURE_RECREDENTIALING_ENABLED = true`).

**Workstream B5 Official Status:** **DESIGN VERIFIED**. The asymmetric ingress guard and forward-recovery runbook eliminate the risk of bricking enrolled hardware during production releases.
