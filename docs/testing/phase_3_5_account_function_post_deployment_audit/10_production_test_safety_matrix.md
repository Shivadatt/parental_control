# Phase 3.5 — Report 10: Production Test Safety Classification Matrix

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Audit Date:** 2026-11-20  

---

## 1. Safety Classification Framework

To protect operational user accounts, database integrity, and production stability, all testing and verification activities are categorized into four standardized safety tiers.

```
┌─────────────────────────────────────────────────────────────┐
│ Category A: Offline & Unit Testing (100% Non-Destructive)    │
│  - Executed entirely locally via Deno test harness          │
│  - Zero network calls to Supabase production               │
│  - AUTHORIZED FOR IMMEDIATE EXECUTION                       │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ Category B: Production Read-Only Probes (Safe Verification)  │
│  - OPTIONS CORS preflights, unauthenticated 401 checks      │
│  - Read-only queries using dedicated test credentials        │
│  - AUTHORIZED WITH PASSIVE INSPECTION ONLY                   │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ Category C: Production State Mutations (Controlled Writes)  │
│  - Creating ephemeral test users, families, or pairings     │
│  - REQUIRES EXPLICIT APPROVAL + ISOLATED TEST TENANTS        │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ Category D: Destructive / Irreversible Operations           │
│  - Account deletions, user drops, retention sweeps          │
│  - STRICTLY PROHIBITED IN PRODUCTION AUDIT PHASES           │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Test Operations Classification Table

| Category | Operation / Test Case | Execution Environment | Safety Impact & Risk Profile | Phase 3.5 Status |
|:---:|---|---|---|:---:|
| **A** | **Local Staged Unit Tests (46 tests)**<br>Exercising validation, scope, error mapping, and deletion logic with mocks. | Local Machine (`deno test`) | **Zero Risk:** No network access, no production interaction. | **EXECUTED (PASS)** |
| **A** | **Full Backend Test Suite (199 tests)**<br>Exercising all 10 Edge Function test suites across workspace. | Local Machine (`deno test`) | **Zero Risk:** In-memory testing and mock clients. | **EXECUTED (PASS)** |
| **A** | **Cryptographic Hash Verification**<br>SHA-256 auditing of local staging package. | Local Machine (Python script) | **Zero Risk:** Read-only filesystem operations. | **EXECUTED (PASS)** |
| **B** | **Live CORS Preflight (`OPTIONS`)**<br>Validating CORS headers against production endpoint. | Live Supabase Gateway (`curl` / HTTPS) | **Negligible Risk:** Gateway responds directly; zero database queries executed. | **EXECUTED (PASS)** |
| **B** | **Live Unauthenticated Probes (`POST`)**<br>Sending requests with missing auth or invalid JWT formats. | Live Supabase Gateway (`curl` / HTTPS) | **Negligible Risk:** Rejected at auth barrier; zero database reads or writes. | **EXECUTED (PASS)** |
| **B** | **Live Read-Only Invocations (`retention_report`)**<br>Calling retention audit using an ephemeral test user. | Live Supabase Function | **Low Risk:** Read-only aggregation; cannot alter data. | **PLANNED (Future)** |
| **B** | **Live Data Export (`export`)**<br>Streaming export attachment for an ephemeral test user. | Live Supabase Function | **Low Risk:** Read-only SELECT; strictly scoped to test user. | **PLANNED (Future)** |
| **C** | **Provisioning Ephemeral Test Tenant**<br>Creating a disposable test parent, family, and child in production. | Supabase Auth + Database | **Moderate Risk:** Adds rows; requires cleanup plan to prevent clutter. | **BLOCKED (Future)** |
| **C** | **Pairing Ephemeral Test Device**<br>Registering a mock device under ephemeral test family. | Edge Function (`device-register`) | **Moderate Risk:** Creates test device record; strictly isolated. | **BLOCKED (Future)** |
| **D** | **Executing Live Account Deletion (`delete`)**<br>Deleting user profile, family memberships, and GoTrue Auth account. | Live Supabase Function (`account`) | **HIGH RISK / DESTRUCTIVE:** Permanently destroys user data. Permitted ONLY on ephemeral test users. | **STRICTLY BLOCKED** |
| **D** | **Triggering Deletion on Operational Accounts**<br>Any deletion attempt targeting `spg7753@gmail.com`, `ankit@gmail.com`, or `ankit1@gmail.com`. | Any Environment | **CATASTROPHIC RISK:** Permanent loss of production accounts. | **ABSOLUTELY FORBIDDEN** |
| **D** | **Executing Database Schema / RLS Alterations**<br>Running DDL migrations or altering RLS policies. | Supabase SQL Editor / CLI | **HIGH RISK:** Can compromise system-wide security policies. | **STRICTLY BLOCKED** |

---

## 3. Strict Boundary Rules for Phase 3.5

1. **Only Category A operations** have been actively executed during this audit session.
2. **Category B live smoke checks** from Phase 3.4.7 were re-evaluated and confirmed non-intrusive.
3. **Category C & Category D operations** are strictly prohibited and deferred to future, approval-gated qualification phases.
