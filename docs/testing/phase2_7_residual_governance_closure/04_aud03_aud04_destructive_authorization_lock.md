# Phase 2.7 — AUD03 & AUD04 Destructive Testing Authorization Lock

**Document ID:** `HAVEN-GOV-PHASE2-7-DESTRUCTIVE-LOCK`  
**Phase:** Phase 2.7 — Final Residual Governance Corrections & Owner Authorization Lock Audit  
**Workspace:** `D:\parentcontrol_app`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Forensic Operation Scope Verification & Explicit Authorization Locking  
**Execution Posture:** STRICTLY READ-ONLY  
**Authorization Verdict:** AUD03: PROPOSED CONTROLLED TEST — NOT AUTHORIZED; AUD04: PROHIBITED ON SHARED BACKEND  

---

## 1. Executive Purpose & Governance Rectification

In Phase 2.6 Deliverables 01, 04, and 12, narrative summaries included the following statement:  
> *"AUD03 (family-scoped purge) is permitted under controlled disposable fixtures."*

### 1.1 The Premature Authorization Defect
An adversarial review reveals that this statement was **premature and unauthorized**:
1. The Project Owner has **not yet signed or approved Decision Gate `P25-OWNER-03`** (*Destructive Testing Policy*).
2. The disposable test accounts (`qa-destroy-*@haven.internal`) required for `AUD03` have **not been created or allocated** under Decision Gate `P25-OWNER-04`.
3. Phase 3 test execution is **strictly locked** under Decision Gate `P25-OWNER-07`.
4. Therefore, no audit report has the legal or technical authority to declare `AUD03` "permitted". It must be classified strictly as a **`PROPOSED CONTROLLED TEST — NOT AUTHORIZED FOR EXECUTION`**.

---

## 2. Granular Source Code Scope Audit: `AUD03` vs `AUD04`

```
+---------------------------------------------------------------------------------------------------------------------------------------------------+
|                                            DESTRUCTIVE OPERATION FORENSIC COMPARISON MATRIX                                                       |
+---------------------------------------------------------------------------------------------------------------------------------------------------+
```

| Dimension | `AUD03`: Scoped Family Data Purge | `AUD04`: Global Cron Retention Sweep |
| :--- | :--- | :--- |
| **Operational Definition** | Deletion of location events, app usage, and telemetry for a single specific family. | Automated periodic sweep of expired WebRTC signals, audit logs, and telemetry across all families. |
| **Trigger Mechanism** | Parent UI action in Settings $\to$ `family-admin` (`action: "purge_data"`) or GDPR account deletion. | Scheduled Cron runner calling `cron` Edge Function $\to$ `public.run_retention_sweep()`. |
| **Source Implementation** | [supabase/functions/family-admin/index.ts:240–280](file:///d:/parentcontrol_app/supabase/functions/family-admin/index.ts#L240-L280) and `account/deletion.ts`. | [supabase/migrations/20261030000300_retention_sweep.sql:115–250](file:///d:/parentcontrol_app/supabase/migrations/20261030000300_retention_sweep.sql#L115-L250). |
| **Database Query Scoping** | **Strictly Scoped**: Filters with `.eq("family_id", familyId)` and verifies caller is family owner. | **Completely Unscoped**: Purges `webrtc_signals` (>7d) and `audit_logs` (>365d) globally across all tenants. |
| **Family Loop Scope** | Affects **only the target family** identified by authenticated caller. | Iterates over `SELECT f.id, f.settings FROM public.families f`, sweeping **every customer family**. |
| **Production Contamination Risk**| **Low** (if executed strictly against dedicated disposable fixtures; high if caller targets real family). | **CATASTROPHIC** on Pathway B (permanently purges real customer telemetry and audit records). |
| **Test Case Mapping** | Exercised in `TC-FAM10` (*Parent Data Purge*) and `TC-A09` (*GDPR Account Deletion*). | Exercised exclusively in `TC-EXP-48` (*Scheduled Retention Sweep Execution*). |
| **Owner Gate Dependency** | Depends on Gate `P25-OWNER-03` (Option 3-A) and Gate `P25-OWNER-04` (Disposable Accounts). | Governed by Gate `P25-OWNER-03` (Strict Prohibition on Shared Backends). |
| **Current Epistemological Status** | **`PROPOSED CONTROLLED TEST — NOT AUTHORIZED FOR EXECUTION`** | **`GLOBAL DESTRUCTIVE OPERATION — PROHIBITED ON SHARED BACKEND PATHWAY`** |

---

## 3. Strict Five-Tier Authorization Boundary Separation

To prevent future misinterpretations, Phase 2.7 establishes five distinct layers of governance separation:

```
+----------------------------------------------------------------------------------------------------+
|                               FIVE-TIER GOVERNANCE SEPARATION MODEL                                |
+----------------------------------------------------------------------------------------------------+
| Layer 1: Source-Level Operation Scope (Verified Architectural Reality)                             |
|   • AUD03 is family-scoped in TypeScript code; AUD04 is multi-tenant global in PostgreSQL SQL.     |
+----------------------------------------------------------------------------------------------------+
| Layer 2: Proposed Testing Policy (Audit Recommendation Only)                                       |
|   • Proposed Policy: Prohibit AUD04 on Pathway B; permit AUD03 on disposable accounts.             |
|   • Status: Advisory only. Conveys zero operational authority.                                     |
+----------------------------------------------------------------------------------------------------+
| Layer 3: Owner Policy Decision (Awaiting Owner Signature)                                          |
|   • Decision Gate P25-OWNER-03. Until signed by Owner, NO destructive testing policy is active.    |
|   • Status: PENDING OWNER DECISION.                                                                |
+----------------------------------------------------------------------------------------------------+
| Layer 4: Infrastructure & Credential Isolation (Pre-Execution Prerequisite)                         |
|   • Dedicated disposable accounts (qa-destroy-*) must be provisioned and isolated.                 |
|   • Status: UNPROVISIONED / BLOCKED.                                                               |
+----------------------------------------------------------------------------------------------------+
| Layer 5: Operational Execution Authorization (Final Phase 3 Activation Gate)                       |
|   • Decision Gate P25-OWNER-07 must be formally signed by Project Owner.                           |
|   • Status: STRICTLY LOCKED AND NOT AUTHORIZED.                                                    |
+----------------------------------------------------------------------------------------------------+
```

---

## 4. Final Lock Directive

```
====================================================================================================
                        DESTRUCTIVE TESTING FINAL GOVERNANCE LOCK
====================================================================================================
AUD03 (Scoped Family Purge):     PROPOSED CONTROLLED TEST — NOT AUTHORIZED FOR EXECUTION
                                 • Execution is strictly prohibited until Owner signs Gate P25-OWNER-03,
                                   disposable fixtures are provisioned under Gate P25-OWNER-04, and
                                   Phase 3 is activated under Gate P25-OWNER-07.

AUD04 (Global Retention Sweep):  GLOBAL DESTRUCTIVE OPERATION — PROHIBITED ON SHARED BACKEND
                                 • Execution of public.run_retention_sweep() on Pathway B (shared
                                   production project hhqgreaoqulmfwfwarhc) is PERMANENTLY BANNED.
                                 • Test case TC-EXP-48 may only be executed if Pathway C (Local Docker)
                                   or Pathway A (Dedicated Staging) is provisioned and authorized.
====================================================================================================
```
