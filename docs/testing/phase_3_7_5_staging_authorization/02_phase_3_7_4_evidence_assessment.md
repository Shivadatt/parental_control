# Phase 3.7.5 — Report 02: Phase 3.7.4 Evidence Assessment & Live Verification Limitations

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target Function:** `account` Edge Function  
**Baseline Evidence:** `docs/testing/phase_3_7_4_offline_isolation_harness/`  
**Execution Mode:** EVIDENCE ASSESSMENT / READ-ONLY  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

Phase 3.7.4 strengthened the offline test harness to exercise adversarial scenarios CT-01 through CT-10 against an enhanced in-memory `FakePostgrest` mock. While Phase 3.7.4 conclusively demonstrated that the application's TypeScript query-building logic is safe from cross-tenant leakage, **offline testing does not substitute for live Supabase environment verification**.

This report assesses what Phase 3.7.4 accomplished, categorizes its evidence under formal taxonomy classifications, and documents the technical boundaries that separate offline mock execution from live cloud behavior.

---

## 2. Phase 3.7.4 Verification Accomplishments

Phase 3.7.4 delivered three verified technical assets in commit `9f266e7`:
1. **Mock Enhancements:** Enhanced `supabase/functions/_shared/fake_postgrest.ts` with multi-token authentication (`authTokens`, `setTokenUser`), PostgREST `.or()` clause evaluation, and compound sorting (`orderSpecs`).
2. **Adversarial Test Suite:** Implemented `supabase/functions/account/cross_tenant_isolation_test.ts` with 10 deterministic adversarial test cases.
3. **Execution Results:** All 55 account Edge Function tests passed cleanly in 649ms with zero regressions.

| Component | Tested Aspect | Evidence Category | Verified Outcome |
|---|---|---|:---:|
| **CT-01** | Baseline Export Isolation | `OFFLINE TEST VERIFIED` | Zero foreign tenant rows returned |
| **CT-02** | Injected Family ID in Export | `OFFLINE TEST VERIFIED` | Body parameter ignored; zero foreign rows |
| **CT-03** | Injected Family ID in Retention | `OFFLINE TEST VERIFIED` | Body parameter ignored; zero foreign metrics |
| **CT-04** | Inactive/Suspended Membership | `OFFLINE TEST VERIFIED` | Scope fails closed to `not_reported`; 0 rows |
| **CT-05** | Child Role Boundary | `OFFLINE TEST VERIFIED` | Device scope; parent audit logs excluded |
| **CT-06** | Multi-Family Parent Scope | `OFFLINE TEST VERIFIED` | Sees own families; foreign family excluded |
| **CT-07** | Empty Scope Fail-Closed | `OFFLINE TEST VERIFIED` | `NO_MATCH_UUID` activated; 0 rows returned |
| **CT-08** | Injected Device ID in Export | `OFFLINE TEST VERIFIED` | Body parameter ignored; bounds to own device |
| **CT-09** | Audit Log & Sweep Marker | `OFFLINE TEST VERIFIED` | Global sweep marker (`family_id: null`) hidden |
| **CT-10** | Pagination Isolation (1,050 rows) | `OFFLINE TEST VERIFIED` | Interleaved foreign rows never bleed across pages |

---

## 3. Inherent Limitations of Offline Mock Verification

Despite the high fidelity of `FakePostgrest`, offline execution has five structural limitations that can only be resolved by live cloud infrastructure:

### 3.1 Absence of Live GoTrue Auth Verification
- **Offline:** The mock resolves tokens via an in-memory dictionary lookup (`authTokens[token]`).
- **Live Cloud:** Supabase Auth (GoTrue) verifies cryptographic JWT signatures (using `JWT_SECRET` / EdDSA keys), enforces token expiry (`exp`), validates issuer/audience claims (`iss`, `aud`), checks user confirmation flags in `auth.users`, and manages session revocation.
- **Evidence State:** Live GoTrue verification of CT scenarios is `NOT TESTED`.

### 3.2 Absence of Real PostgREST Engine Execution
- **Offline:** PostgREST `.or()` and `.in()` filtering is simulated in JavaScript memory.
- **Live Cloud:** PostgREST translates REST calls into complex SQL parameterized queries (e.g., `WHERE (actor_user_id = $1 OR device_id IN ($2, $3))`), executes them against PostgreSQL, and parses table relationships based on PostgreSQL schema foreign keys.
- **Evidence State:** Live PostgREST SQL generation is `NOT TESTED`.

### 3.3 Absence of Real PostgreSQL Database Engine & Triggers
- **Offline:** In-memory arrays do not enforce SQL column types, check constraints, foreign key referential integrity on cascade delete, or PostgreSQL trigger execution (e.g. `on_auth_user_created`).
- **Live Cloud:** Database operations run within transactional boundaries (`BEGIN ... COMMIT`) under active connection pools (Supavisor / PgBouncer).
- **Evidence State:** Live PostgreSQL constraint and trigger enforcement is `NOT TESTED`.

### 3.4 Absence of Deno Deploy Edge Function Runtime
- **Offline:** Tests execute in local Deno CLI (`deno test`) on Windows with direct module imports.
- **Live Cloud:** Edge Functions execute on Supabase's hosted Deno Deploy infrastructure in Seoul (`ap-northeast-2`), subject to cold-start CPU limits, memory constraints (150MB - 250MB), wall-clock execution deadlines (50s - 150s), and real network latency.
- **Evidence State:** Live hosted Edge Function execution is `NOT TESTED`.

### 3.5 Absence of Staging-to-Production Equivalence Proof
- **Offline:** Mocks assume parity with the intended application behavior.
- **Live Cloud:** Mocks cannot prove that a future staging deployment has identical migration versions, RLS policies, table grants, and environment variables as `parent-control-prod`.
- **Evidence State:** Cloud environment equivalence is `UNKNOWN`.

---

## 4. Conclusion & Decision Catalyst

$$\mathbf{Offline\ Result} = \mathbf{CODE\ LOGIC\ VERIFIED\ SAFE\ (55/55\ PASSED)}$$
$$\mathbf{Live\ Cloud\ Isolation} = \mathbf{NOT\ TESTED\ IN\ REAL\ ENVIRONMENT}$$

Because offline tests cannot definitively prove live cloud behavior, the project must make an explicit environment decision: deploy a dedicated staging project to achieve live cloud verification, test in production under extreme restrictions, or formally accept offline-only evidence.
