# PHASE 3.1 — STAGE E: DEPLOYMENT READINESS CHECKLIST

**Project Reference:** `hhqgreaoqulmfwfwarhc`  
**Edge Function:** `account`  
**Region:** `ap-south-1`  
**Execution Mode:** STRICT READ-ONLY AUDIT  
**Audit Date:** 2026-11-18  

---

## 1. 18-POINT DEPLOYMENT READINESS CHECKLIST

| # | Readiness Requirement | Status | Verification Evidence | Operational Risk & Notes |
|---|---|---|---|---|
| **1** | Function Source Completeness | **PASS** | `index.ts`, `retention.ts`, `validation.ts`, and test files present | Low. Source is fully authored. |
| **2** | Import Resolution | **PASS** | Deno npm specifiers (`npm:@supabase/supabase-js@2`) resolve cleanly | Low. Verified by Deno compile pass. |
| **3** | Deno Runtime Compatibility | **PASS** | `Deno.serve` syntax compliant with Supabase Edge Runtime v1.x/v2.x | Low. Matches active project functions. |
| **4** | Supabase SDK Compatibility | **PASS** | Supabase JS SDK v2.x client initialization in `_shared/auth.ts` | Low. Standard project client structure. |
| **5** | Required Environment Variables | **PASS** | Names only: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY` | Low. Automatically provided by Supabase platform. |
| **6** | Secret Handling Hygiene | **PASS** | Zero hardcoded keys; no credential logging; constant-time comparisons | Low. Verified by static security audit. |
| **7** | CORS Preflight Handling | **PASS** | OPTIONS method handled immediately with 24-hour cache max-age | Low. Supports web, emulator, and mobile clients. |
| **8** | Authentication Enforcement | **PASS** | `requireUser` verifies Bearer JWT with `db.auth.getUser` on every action | Low. Unauthenticated callers receive 401. |
| **9** | Authorization & Scoping | **PASS** | Three-state scope (`family`, `device`, `not_reported`) strictly enforced | Low. Cross-family queries fail closed to 0 rows. |
| **10** | Error Handling & Envelope | **PASS** | Standard `{ok, error: {code, message}}` envelope | Low. Matches `EdgeApi` and Flutter client expectations. |
| **11** | Request Payload Validation | **PASS** | JSON parsing catches syntax errors; actions restricted to whitelist | Low. Malformed payloads return 400. |
| **12** | Pagination & Memory Caps | **PASS** | `EXPORT_PAGE_SIZE = 1,000`, `EXPORT_ROW_CAP = 20,000` | Low. Prevents memory exhaustion during export. |
| **13** | Delete-Account Protections | **PASS** | Strict `"DELETE"` + email match + family owner blockers | Low. Cannot delete while members/devices remain. |
| **14** | Retention-Report Behavior | **PASS** | Reads retention windows [1, 3650] days; sweep totals owner-only | Low. Directly resolves Defect E-15. |
| **15** | Client Wire Compatibility | **PASS** | Verified matching `lib/features/settings/account_privacy_repository.dart` | Low. Response models map 1:1. |
| **16** | Unit Test Baseline | **PASS** | 30/30 account tests passed; 184/184 full backend tests passed | Low. Comprehensive offline regression suite. |
| **17** | Target Project Identity | **PASS** | Target project verified as `hhqgreaoqulmfwfwarhc` | Low. Project reference confirmed. |
| **18** | Risk of Overwriting Hosted State | **PASS** | Target endpoint currently returns 404 (Function not deployed) | **Zero**. No existing function will be overwritten. |

---

## 2. CLI ACCESS CONDITION & PREREQUISITE NOTE

- **CLI Tool Check:** Supabase CLI v2.109.0 is installed locally.
- **Access Privilege Requirement:** An inspection using `supabase functions list --project-ref hhqgreaoqulmfwfwarhc` revealed that the currently cached CLI session does not possess management privileges for project `hhqgreaoqulmfwfwarhc` (returns 403).
- **Condition for Deployment:** Prior to running the deploy command, the operator must authenticate with the account holding deploy privileges for `hhqgreaoqulmfwfwarhc` (via `supabase login` or by exporting `SUPABASE_ACCESS_TOKEN`).

---

## 3. FINAL READINESS VERDICT

```
DEPLOYMENT_READINESS = READY WITH CONDITIONS
```

### Mandatory Conditions:
1. **Explicit User Authorization:** Deployment must not be executed without separate, explicit user approval.
2. **CLI Authentication:** The operator must authenticate the Supabase CLI with credentials authorized for project `hhqgreaoqulmfwfwarhc`.
3. **Execution Guard:** Destructive operations (`delete_account` and device recovery) remain strictly prohibited during deployment and smoke testing.
