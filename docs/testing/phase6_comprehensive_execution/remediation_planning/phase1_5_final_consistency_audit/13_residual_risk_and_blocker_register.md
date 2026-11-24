# Phase 1.5: Residual Risk and Blocker Register

**Document ID:** `HAVEN-AUD-013-PHASE1.5`  
**Phase:** Phase 1.5 — Independent Final Consistency & Security Closure Review  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Comprehensive Risk Management & Blocker Governance  

---

## 1. Executive Summary

This register consolidates all active blockers and residual technical, operational, and cryptographic risks associated with the HAVEN Parent Control Phase 1 remediation package. It clearly delineates strict production blockers from managed operational risks, establishing concrete mitigation strategies and monitoring mechanisms required across the Canonical 8-Gate Lifecycle.

---

## 2. Active Blocker Register (BLK-01 Through BLK-03)

The following blockers represent mandatory architectural firewalls that prevent unauthorized implementation or deployment activities:

| Blocker ID | Blocker Title | Affected Scope | Governing Gate | Blocker Rationale & Policy | Unblocking Prerequisite |
|---|---|---|---|---|---|
| **BLK-01** | **Production Infrastructure Deployment Blocker** | Production Supabase Database & Deno Functions | **Gate 7** | Zero changes may be deployed to the production environment until all remediation code has achieved a 100% pass rate in disposable staging. | 1. 100% pass rate on Gate 6 E2E integration suite.<br/>2. Verified forward-recovery runbook.<br/>3. Explicit, standalone written owner authorization. |
| **BLK-02** | **Live Hardware QA Device Blocker** | Physical Realme (`5HXWRGQ4IFU8WS4T`) & Pixel 9 Emulator (`emulator-5554`) | **Gate 8** | Test devices hold active enrolled sessions and hardware-bound credentials. Zero ADB commands or manual QA execution permitted during remediation planning. | 1. Gate 7 production deployment verified.<br/>2. Explicit owner test authorization.<br/>3. Verified session backup and rollback plan. |
| **BLK-03** | **Staging Migration & Edge Deployment Blocker** | Disposable Staging Containers & Projects | **Gates 4, 5, 6** | Staging execution cannot proceed until Gate 2 client code is implemented and Gate 3 SQL migration script is authored and peer-reviewed. | 1. Owner approval of Gate 2 and Gate 3.<br/>2. Completion of Wave 1 and Wave 2 client implementations.<br/>3. Provisioning of ephemeral staging environment. |

---

## 3. Master Residual Risk Register (RSK-001 Through RSK-010)

The table below documents all residual risks that persist despite theoretical design closure, along with their associated mitigations:

| Risk ID | Risk Description | Severity | Likelihood | Impact Area | Inherent Score | Residual Score | Mitigation & Architectural Control | Monitoring & Verification Strategy |
|---|---|---|---|---|---|---|---|---|
| **RSK-001** | **Clock Skew Challenge Expiration**: Skew between parent, server, and child clocks causes challenge premature timeout. | Medium | Low | Recovery Redemption | 6 | 2 | Server enforces `expires_at` using authoritative PostgreSQL DB `now()`. Client clocks are untrusted. | Monitor challenge rejection rate where client-server delta exceeds 60s. |
| **RSK-002** | **Transient DB Disconnection During RPC**: Network drop while executing `rotate_device_secret`. | High | Low | Token Rotation | 8 | 2 | Supabase RPC executes in single atomic transaction; rolls back cleanly. Client 7-state machine resolves via `verify_device_rotation`. | PostgreSQL pool metrics; alert on RPC 500/503 spikes. |
| **RSK-003** | **OEM Background Process Termination**: Custom Android ROMs kill daemon during rotation. | High | Medium | Android Native Daemon | 9 | 4 | Synchronous `editor.commit()` ensures keys persisted before network call. Cold boot enters `RECOVERY_REQUIRED`. | Crashlytics background service termination logs. |
| **RSK-004** | **Hardware Keystore Provider Failure**: Crypto engine exception on legacy or buggy devices. | High | Very Low | Android Encryption | 8 | 2 | Catch `KeyStoreException` and `GeneralSecurityException`; graceful rollback to unauthenticated state with user prompt. | Client-side error telemetry for `KEYSTORE_CRYPTO_FAILURE`. |
| **RSK-005** | **Corporate / ISP TLS Interception**: Custom proxy strips `x-device-secret` header. | Medium | Low | Telemetry | 6 | 2 | Standard HTTPS transport; missing header triggers typed HTTP 401 with explicit error code. | Telemetry failure rate alerts grouped by ASN. |
| **RSK-006** | **App Data Wipe Mid-Challenge**: User clears storage while challenge is active. | Low | Low | Recovery | 3 | 1 | SharedPreferences wiped; client boots into fresh pairing flow. Orphaned challenge expires harmlessly in 15 mins. | Challenge expiration audit logs in DB. |
| **RSK-007** | **Staging / Production Schema Drift**: Manual SQL edits cause staging divergence from prod. | High | Very Low | Deployment | 9 | 1 | CI/CD pipeline enforces `supabase db diff` verification; zero manual database mutations permitted. | Automated schema checksum verification in CI. |
| **RSK-008** | **Legacy Handset Text Scaling Distortion**: Dynamic scaling clips text on low-DPI screens. | Low | Very Low | UI Accessibility | 4 | 1 | `LayoutBuilder` with 420dp breakpoint and modern `TextScaler` dynamic wrapping guarantees multi-line layout. | Golden widget test suite across 5 screen geometries. |
| **RSK-009** | **PL/pgSQL Comparison Timing Variation**: Micro-architectural timing leaks in interpreted loop. | Medium | Low | Cryptography | 6 | 2 | SHA-256 avalanche completely randomizes digest; 5-attempt hard lockout prevents statistical sampling. | Differential timing benchmark in Gate 4; native primitive. |
| **RSK-010** | **Candidate Hash Logging Exposure**: Edge Function or Sentry debug logs capture candidate hashes. | Medium | Low | Log Hygiene | 6 | 1 | Implement strict sanitization middleware in Edge Functions redacting `candidate_secret_hash` and headers. | Static analysis check for logger statements in Edge code. |

---

## 4. Risk Mitigation Governance & Sign-Off

All 10 residual risks are managed by deterministic technical controls. No risk represents an unmitigated vulnerability that would block proceeding with **Gate 2 (Client Implementation)** or **Gate 3 (SQL Design Review)**.

The active blockers (**BLK-01**, **BLK-02**, **BLK-03**) provide complete institutional assurance that no production system or hardware device can be accidentally compromised.
