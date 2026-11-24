# 07 — Staging and Environment Readiness Review

**Document ID:** `HAVEN-VER-007`  
**Phase:** Phase 2.1 — Independent Consistency & Coverage Verification  
**Workspace:** `D:\parentcontrol_app`  
**Audited Claim:** Phase 2 Decision 4: "DESIGNATE Staging Supabase Environment as the authoritative execution target"  
**Audit Standard:** Documentary Verification & Multi-Tenant Infrastructure Audit  
**Execution Posture:** STRICTLY READ-ONLY — ZERO NETWORK CALLS — ALL TESTS `NOT TESTED`  

---

## 1. Audit Target & Problem Statement

In `docs/testing/phase2_coverage_gap_audit/12_phase2_final_coverage_and_owner_readiness.md` (§5), Phase 2 asks the Product Owner to approve:
> `[ ] DECISION 4: DESIGNATE Staging Supabase Environment as the authoritative execution target.`

Furthermore, throughout Phase 2 reports (e.g. `10_test_safety_and_prerequisite_register.md`), repeated references are made to configuring `STAGE_SUPABASE_URL`, isolating staging auth, and executing destructive tests (`TC-SEC01`, `TC-SEC02`, `TC-EXP-47`, `TC-EXP-48`) against "Staging".

The purpose of this audit is to independently verify whether a staging Supabase project actually exists in the workspace documentation and whether designating it is safe and actionable.

---

## 2. Documentary Evidence Audit: Does Staging Exist?

### 2.1 Explicit Codebase Documentation Finding
An adversarial inspection of repository documentation reveals an explicit, direct contradiction in `docs/backend.md:327–332`:

> [!CRITICAL]
> **Authoritative Source Citation (`docs/backend.md:327–332`)**:  
> *"**No staging project exists**: the only project reachable by this workstation's CLI login is `irlqctcddjmkwqdvsdsm`, while the app targets `hhqgreaoqulmfwfwarhc`. The owner directed on 2026-10-27 that the reviewed change set be deployed to that existing production project and that **no second project be created**. The apply and redeploy are recorded above; the Phase 4 and Phase 5 checks ran against it with dedicated QA accounts."*

### 2.2 Analysis of the Documentary Record
1. **No Staging Project Ever Created**: The owner explicitly prohibited creating a second Supabase project on 2026-10-27.
2. **Workstation CLI Project vs App Target**:
   - Workstation CLI reaches: `irlqctcddjmkwqdvsdsm` (historical/management project).
   - Application targets: `hhqgreaoqulmfwfwarhc` (production deployment project).
3. **Staging is Architectural Fiction in Phase 2**: Phase 2 assumed that a dedicated staging environment was ready and reachable via `STAGE_SUPABASE_URL`. This assumption is completely refuted by `docs/backend.md`.

---

## 3. Operational Risk of Designating a Non-Existent Staging Target

If the Product Owner approves Decision 4 as currently drafted, severe operational hazards will arise during Phase 3 execution:

```
+----------------------------------------------------------------------------------------------------+
|                                    STAGING CONFLATION HAZARDS                                      |
+----------------------------------------------------------------------------------------------------+
| Hazard 1: Immediate Test Failure / Workstation Stall                                               |
|   Testers attempting to configure STAGE_SUPABASE_URL will find no project credentials, causing     |
|   the Phase 3 test launch to stall immediately at Phase 3.1.                                       |
+----------------------------------------------------------------------------------------------------+
| Hazard 2: Catastrophic Production Data Destruction                                                 |
|   If testers mistakenly substitute the production project credentials (hhqgreaoqulmfwfwarhc)       |
|   into the "staging" configuration slot believing it is an isolated sandbox, executing             |
|   TC-EXP-47 (Audit Purge), TC-EXP-48 (Retention Sweep), or TC-A09 (Account Deletion) could         |
|   permanently wipe real user accounts, family relationships, and device pairings.                  |
+----------------------------------------------------------------------------------------------------+
| Hazard 3: Production Keystore Invalidations                                                        |
|   Executing TC-EXP-17 (Device Revocation) or TC-FAM10 (Unlinking) against production would sever     |
|   active child hardware supervision.                                                               |
+----------------------------------------------------------------------------------------------------+
```

---

## 4. Documentary Classification Verdict

In accordance with Section 9 of the Phase 2.1 Audit Standard:

```
====================================================================================================
                        STAGING ENVIRONMENT READINESS VERDICT
====================================================================================================
Classification:         NOT VERIFIED / ARCHITECTURALLY NON-EXISTENT
Supporting Evidence:    docs/backend.md:327 ("No staging project exists...")
Operational Status:     BLOCKED PENDING OWNER INFRASTRUCTURE DECISION
====================================================================================================
```

---

## 5. Owner Decision Framework: The Two Viable Pathways

The Product Owner must choose between two mutually exclusive operational pathways before Phase 3 can be authorized:

### Pathway A: Provision Genuine Staging Infrastructure (Recommended for Enterprise QA)
If the owner desires true physical isolation for Phase 3 testing:
1. **Owner Action**: Create a second Supabase project (e.g. `haven-staging-eu`).
2. **Apply Migrations**: Apply all database migrations up to `20261030000300_retention_sweep.sql`.
3. **Deploy Edge Functions**: Set `PAIRING_HASH_PEPPER` secret and deploy `/pairing`, `/account`, `/remote-session`, `/device-telemetry`.
4. **Compile Test Builds**: Build Flutter Parent and Child APKs using `--dart-define=SUPABASE_URL=https://haven-staging.supabase.co`.
5. **Advantage**: Allows full, unrestricted execution of destructive tests (`AUD03`, `A09`, `FAM10`, `SEC01`, `SEC02`) with zero risk to production.

### Pathway B: Single-Project QA Isolation (Strict In-Project Governance)
If the owner reaffirms the 2026-10-27 decision that **no second project be created**:
1. **Decision Revision**: Formally amend Decision 4 to designate the **Existing Production Project with Strict In-Project QA Account Quarantine**.
2. **Dedicated QA Namespace**: All test accounts must strictly use the prefix `qa_isolated_*@haven.test`.
3. **Destructive Operation De-Authorization**:
   - `TC-EXP-47` (Historical Audit Purge) and `TC-EXP-48` (Retention Sweep) must be **PROHIBITED** from running on the live database.
   - `TC-A09` (Account Deletion) must be strictly verified on newly created disposable QA accounts only.
   - `TC-SEC01` (Cross-Tenant RLS) must be verified between two freshly created QA families (`QA-Family-A` and `QA-Family-B`).
4. **Advantage**: Requires zero new cloud infrastructure costs or deployment overhead.

---

## 6. Readiness Conclusion

Phase 2's recommendation to designate Staging Supabase **CANNOT BE APPROVED AS WRITTEN**.  
The Product Owner must select either **Pathway A (Provision Staging)** or **Pathway B (In-Project QA Quarantine)** before any backend testing begins.
