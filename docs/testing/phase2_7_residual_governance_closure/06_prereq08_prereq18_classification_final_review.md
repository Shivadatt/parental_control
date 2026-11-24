# Phase 2.7 — PREREQ-08 & PREREQ-18 Classification Final Review

**Document ID:** `HAVEN-GOV-PHASE2-7-PREREQ-JUSTIFICATION`  
**Phase:** Phase 2.7 — Final Residual Governance Corrections & Owner Authorization Lock Audit  
**Workspace:** `D:\parentcontrol_app`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Authoritative Prerequisite Necessity & Applicability Justification  
**Execution Posture:** STRICTLY READ-ONLY  
**Classification Verdict:** PREREQ-08: UNIVERSAL SAFETY GUARDRAIL; PREREQ-18: DEFERRABLE STAGING PREREQUISITE  

---

## 1. Executive Purpose & Governance Inquiries

In Phase 2.6 Deliverable 02, the 18 prerequisites were reconciled into exact integer counts:
- 8 Universal
- 8 Category-Specific
- 1 Deferrable
- 1 Not Required by Current Baseline
- Total: Exactly 18.

During the Phase 2.6 review, specific justification was requested regarding why **`PREREQ-08`** (*Global Retention Sweep Safety Boundaries*) is classified as `UNIVERSAL`, and why **`PREREQ-18`** (*Legacy Migration Verification*) is classified as `DEFERRABLE`.

Phase 2.7 provides the definitive architectural and operational justification for both items.

---

## 2. In-Depth Justification: `PREREQ-08` (Global Retention Sweep Safety Boundaries)

### 2.1 The Two Perspectives on `PREREQ-08`
1. **The Narrow Test-Dependency Perspective**:
   - Only a single test case in the 99-test suite directly exercises the scheduled retention sweep: **`TC-EXP-48`** (*Scheduled Retention Sweep Execution* in Tier 5 Isolated Backend).
   - From this narrow lens, one might argue that `PREREQ-08` only blocks `TC-EXP-48` and should be categorized as `CATEGORY_SPECIFIC`.
2. **The Holistic Environmental Safety Perspective**:
   - Source inspection of `public.run_retention_sweep()` ([20261030000300_retention_sweep.sql:115–250](file:///d:/parentcontrol_app/supabase/migrations/20261030000300_retention_sweep.sql#L115-L250)) confirms that it deletes WebRTC signals (>7d) and audit logs (>365d) globally across **all families**.
   - If testers or automated cron runners trigger this function on a shared backend (Pathway B), it causes catastrophic, irreversible data loss across real customer records.
   - Therefore, the **formal prohibition of `AUD04` on shared backends is a mandatory negative safety boundary that must be established and signed off before ANY test batch is executed**.
   - You cannot safely execute Batch 1 (Safe Read-Only) tests in an environment where an unquarantined cron job or test script might trigger a global sweep.

### 2.2 Authoritative Classification for `PREREQ-08`
- **Primary Classification**: **`UNIVERSAL`** (Mandatory Negative Environmental Safety Guardrail).
- **Epistemological Status**: **`SOURCE_VERIFIED / PROCEDURE_DOCUMENTED`**.
- **Justification**: A universal prerequisite is not merely a feature required by every test; it is an **environmental condition precedent** required to ensure that running any test will not destroy production data.

---

## 3. In-Depth Justification: `PREREQ-18` (Legacy Migration Verification)

### 3.1 What `PREREQ-18` Entails
- The repository contains 14 SQL migration files in `supabase/migrations/`:
  - `20260101000100_initial_schema.sql` through `20261030000300_retention_sweep.sql`.
- Static AST inspection has already confirmed that all 14 files exist and use idempotent DDL (`CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`).
- `PREREQ-18` requires verifying that applying all 14 migrations from a clean PostgreSQL instance replays cleanly without dependency or syntax errors.

### 3.2 Why `PREREQ-18` is `DEFERRABLE`
1. **Existing Database Already Migrated**: If Pathway B (existing Supabase project) is selected, all 14 migrations are already active in the deployed schema. Testing does not require replaying historical migrations.
2. **Non-Blocking for Initial Safe Testing**: A fresh migration replay test is only required at the moment a new staging instance (Pathway A) or local Docker container (Pathway C) is provisioned.
3. **Deferrable Boundary**: Batch 1 (Safe Read-Only UI inspection) does not depend on proving migration replay idempotency; it only requires that the active backend matches the application model.
4. **Epistemological Distinctions**:
   - *Migration files existing*: **SOURCE VERIFIED**.
   - *Migration files statically inspected*: **STATICALLY VERIFIED**.
   - *Migrations replayed from blank database*: **RUNTIME UNVERIFIED / DEFERRED**.

### 3.3 Authoritative Classification for `PREREQ-18`
- **Primary Classification**: **`DEFERRABLE`** (Staging Provisioning Prerequisite).
- **Epistemological Status**: **`SOURCE_VERIFIED (STATIC CODE) / RUNTIME UNVERIFIED (REPLAY)`**.
- **Justification**: Does not block initial test batch planning; can be deferred until the Owner selects Pathway A or C and authorizes backend infrastructure provisioning.

---

## 4. Synthesis of Authoritative Classifications

```
====================================================================================================
                        PREREQUISITE JUSTIFICATION SUMMARY
====================================================================================================
PREREQ-08 (Retention Safety Boundary):
  • Primary Classification:       UNIVERSAL (Mandatory Safety Guardrail)
  • Evidentiary Basis:            SQL code proves global multi-tenant deletion risk; AUD04 ban
                                  is a universal environmental prerequisite for all 99 tests.

PREREQ-18 (Legacy Migration Replay):
  • Primary Classification:       DEFERRABLE (Staging Provisioning Prerequisite)
  • Evidentiary Basis:            14 migrations are statically verified in source; clean replay
                                  is only needed when spinning up fresh databases (Pathway A/C).
====================================================================================================
```
