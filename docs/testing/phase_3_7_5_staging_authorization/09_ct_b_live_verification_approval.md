# Phase 3.7.5 — Report 09: Gate CT-B — Live Adversarial Verification Authorization Package

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target Environment:** Staging `account` Edge Function Endpoint Only  
**Gate Status:** `PENDING — NO LIVE TESTING AUTHORIZED`  
**Prerequisite:** Full completion and independent verification of Gate CT-A  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report defines the standalone authorization specification for **Gate CT-B (Live Adversarial Isolation Testing)**. Gate CT-B authorizes executing the 10 adversarial cross-tenant isolation scenarios (**CT-01 through CT-10**) against the live staging Edge Function endpoint using authenticated synthetic test identities.

$$\mathbf{Gate\ CT-B\ Initial\ State} = \mathbf{PENDING\ —\ NO\ LIVE\ TESTING\ AUTHORIZED}$$
$$\mathbf{Scope\ Boundary} = \mathbf{READ-ONLY\ ADVERSARIAL\ TESTING\ ONLY\ (NO\ DELETIONS)}$$

---

## 2. Gate CT-B Formal Scope & Boundaries

### 2.1 Permitted Test Scenarios (CT-01 through CT-10)
Upon explicit owner approval of Gate CT-B, the following 10 test scenarios are authorized:
1. **CT-01:** Baseline export by User A asserting 100% Tenant A data and 0% Tenant B data.
2. **CT-02:** Adversarial body parameter injection (`family_id: FAMILY_B_ID`) in export request.
3. **CT-03:** Adversarial body parameter injection (`family_id: FAMILY_B_ID`) in retention-report request.
4. **CT-04:** Inactive/suspended user export request verifying fail-closed `not_reported` scope.
5. **CT-05:** Child role export request verifying device-only scope and parent audit log exclusion.
6. **CT-06:** Multi-family parent export request verifying access to authorized families while foreign family is excluded.
7. **CT-07:** Stranger user export request verifying `NO_MATCH_UUID` fail-closed zero-row response.
8. **CT-08:** Adversarial body parameter injection (`device_id: DEVICE_B_ID`) in export request.
9. **CT-09:** Export query audit log isolation verifying global retention sweep markers (`family_id: null`) are excluded.
10. **CT-10:** Multi-page pagination verification (1,000-row page boundary) across interleaved records.

### 2.2 Request Budget & Strict Guardrails
- **Maximum Request Budget:** Strictly capped at **30 total HTTP requests** to the staging function.
- **Allowed HTTP Actions:** Exclusively `POST` with `{"action": "export"}` or `{"action": "retention_report"}`.
- **Prohibited Actions:** No `delete_account` or `delete` actions authorized under Gate CT-B.
- **Zero Production Calls:** All requests must target the staging URL. Any request to `hhqgreaoqulmfwfwarhc` is strictly forbidden.

---

## 3. Copy-Ready Gate CT-B Approval Document

```text
================================================================================
GATE CT-B APPROVAL: LIVE ADVERSARIAL ISOLATION TESTING
================================================================================

Project: Parent Control App
Target Staging Endpoint: https://[STAGING_REF].supabase.co/functions/v1/account
Protected Production Ref: hhqgreaoqulmfwfwarhc (STRICTLY PROHIBITED)

PREREQUISITE VERIFICATION:
- Gate CT-A Provisioning Completed: YES / NO
- Exactly 40 Synthetic Staging Records Verified: YES / NO
- Production Endpoint Verification Passed (Zero Prod Touches): YES / NO

AUTHORIZED ADVERSARIAL SCOPE:
- Target Identities: Synthetic User A, User B, Child A, Stranger (@internal-test.local)
- Scenarios Authorized: CT-01 through CT-10 (Read-only Export and Retention Report)
- Request Budget: Maximum 30 HTTP requests total
- Permitted Payloads: Export and Retention Report requests including adversarial 
  foreign family_id and device_id body injections
- Allowed HTTP Methods: POST only

EXPLICIT BOUNDARIES:
- Account Deletion Actions: STRICTLY PROHIBITED under Gate CT-B.
- Production Endpoint Requests: STRICTLY PROHIBITED.
- Record Mutations / Cleanup: STRICTLY PROHIBITED under Gate CT-B.

APPROVAL STATUS:
[  ] APPROVED — Authorize Gate CT-B Live Testing
[X] PENDING — NOT AUTHORIZED (Default)

Authorized By: __________________________   Date: ____________________
================================================================================
```
