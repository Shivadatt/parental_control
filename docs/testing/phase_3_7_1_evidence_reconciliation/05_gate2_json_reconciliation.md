# Phase 3.7.1 — Report 05: Gate 2 Machine-Readable Telemetry Reconciliation

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Correlation ID:** `run-20261120-e7f1`  
**Audit Execution Mode:** STRICTLY AUDIT-ONLY / READ-ONLY  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

This report performs a field-by-field validation of the machine-readable telemetry artifact `gate2_results.json` against the narrative and quantitative claims in Phase 3.7 Reports 06, 07, 08, and 12.

$$\mathbf{Telemetry\ Reconciliation\ Status} = \mathbf{100\%\ FIELD-LEVEL\ CONCORDANCE}$$

The machine-readable telemetry is valid JSON, strictly conforms to sanitized reporting requirements, and completely matches the narrative documentation without leaking sensitive credentials, session tokens, or unhashed personal data.

---

## 2. Field-by-Field Reconciliation Matrix

The table below reconciles each key field from `gate2_results.json` against the corresponding report values:

| JSON Key / Path | Value in `gate2_results.json` | Value in Phase 3.7 Reports (06, 07, 08, 12) | Match Status | Source Evidence |
|---|---|---|:---:|---|
| `phase` | `"3.7"` | Phase 3.7 | **MATCH** | Report 12 Section 1 |
| `correlation_id` | `"run-20261120-e7f1"` | `run-20261120-e7f1` | **MATCH** | All Report Headers |
| `timestamp` | `"2026-11-20T10:20:46.736Z"` | `2026-11-20T10:20:46Z` | **MATCH** | Report 07 Header |
| `project_ref` | `"hhqgreaoqulmfwfwarhc"` | `hhqgreaoqulmfwfwarhc` | **MATCH** | All Report Headers |
| `region` | `"ap-northeast-2"` | `ap-northeast-2` (Seoul) | **MATCH** | All Report Headers |
| `status` | `"PASSED"` | PASSED | **MATCH** | Report 12 Section 1 |
| `auth_login.status` | `200` | HTTP 200 OK | **MATCH** | Report 06 Section 2 |
| `auth_login.user_id` | `"22a1dbb7-c4d9-4a3a-8481-e0d44871146d"` | `22a1dbb7-c4d9-4a3a-8481-e0d44871146d` | **MATCH** | Report 03, 04, 06 |
| `auth_login.email` | `"ephemeral-parent-run-20261120-e7f1@internal-test.local"` | `ephemeral-parent-run-20261120-e7f1@internal-test.local` | **MATCH** | Report 03, 04, 06 |
| `auth_login.email_confirmed` | `true` | Auto-confirmed true | **MATCH** | Report 04 Step 1 |
| `action_export.status` | `200` | HTTP 200 OK | **MATCH** | Report 06 Section 2 |
| `action_export.content_disposition_present` | `true` | Present (`attachment; filename=...`) | **MATCH** | Report 06 Section 2 |
| `action_export.scope` | `"family"` | `scope: "family"` | **MATCH** | Report 06 Section 3 |
| `action_export.family_id` | `"cd5e2b6e-1a84-4bc6-a757-cd79600cd523"` | `cd5e2b6e-1a84-4bc6-a757-cd79600cd523` | **MATCH** | Report 06 Section 3 |
| `action_export.family_name` | `"Ephemeral QA Family run-20261120-e7f1"` | `Ephemeral QA Family run-20261120-e7f1` | **MATCH** | Report 06 Section 3 |
| `action_export.owner_id` | `"22a1dbb7-c4d9-4a3a-8481-e0d44871146d"` | `22a1dbb7-c4d9-4a3a-8481-e0d44871146d` | **MATCH** | Report 06 Section 3 |
| `action_export.foreign_families_exposed` | `0` | 0 foreign records exposed | **MATCH** | Report 06 Section 3 |
| `action_export.sanitized_summary.families_count` | `1` | 1 family returned | **MATCH** | Report 06 Section 3 |
| `action_export.sanitized_summary.devices_count` | `0` | 0 devices (`[]`) | **MATCH** | Report 06 Section 3 |
| `action_export.sanitized_summary.tables.location_events` | `0` | `row_count: 0` | **MATCH** | Report 06 Section 3 |
| `action_export.sanitized_summary.tables.usage_daily` | `0` | `row_count: 0` | **MATCH** | Report 06 Section 3 |
| `action_export.sanitized_summary.tables.safety_alerts` | `0` | `row_count: 0` | **MATCH** | Report 06 Section 3 |
| `action_export.sanitized_summary.tables.audit_logs` | `0` | `row_count: 0` | **MATCH** | Report 06 Section 3 |
| `action_retention_report.status` | `200` | HTTP 200 OK | **MATCH** | Report 07 Section 2 |
| `action_retention_report.ok` | `true` | `ok: true` | **MATCH** | Report 07 Section 3 |
| `action_retention_report.family_id` | `"cd5e2b6e-1a84-4bc6-a757-cd79600cd523"` | `cd5e2b6e-1a84-4bc6-a757-cd79600cd523` | **MATCH** | Report 07 Section 3 |
| `action_retention_report.windows.location_retention_days` | `30` | 30 days | **MATCH** | Report 07 Section 3 |
| `action_retention_report.windows.usage_retention_days` | `90` | 90 days | **MATCH** | Report 07 Section 3 |
| `action_retention_report.windows.webrtc_signals_days` | `7` | 7 days | **MATCH** | Report 07 Section 3 |
| `action_retention_report.windows.audit_logs_days` | `365` | 365 days | **MATCH** | Report 07 Section 3 |
| `action_retention_report.counts.location_events_older_than_window` | `0` | 0 events | **MATCH** | Report 07 Section 3 |
| `action_retention_report.counts.usage_days_older_than_window` | `0` | 0 events | **MATCH** | Report 07 Section 3 |
| `action_retention_report.foreign_families_exposed` | `0` | 0 foreign families exposed | **MATCH** | Report 07 Section 3 |
| `cross_tenant_rejection.unauthenticated_status` | `401` | HTTP 401 Unauthorized | **MATCH** | Report 08 Section 2 |
| `cross_tenant_rejection.tampered_token_status` | `401` | HTTP 401 Unauthorized | **MATCH** | Report 08 Section 2 |
| `cross_tenant_rejection.invalid_action_status` | `400` | HTTP 400 Bad Request | **MATCH** | Report 08 Section 2 |

---

## 3. Payload Sanitization & Security Inspection

A dedicated security scan was conducted over `gate2_results.json` to verify that no sensitive secrets or production PII were committed:

1. **JWT Exclusion:** No raw JSON Web Tokens (access tokens, refresh tokens) exist in the file. Only sanitized boolean flags (`success: true`, `email_confirmed: true`) are recorded.
2. **Secret Header Exclusion:** No `Authorization` headers, `apikey` headers, or Supabase `service_role` keys are present.
3. **Password Exclusion:** No passwords or cryptographic hashes are stored.
4. **Data Minimization:** Response bodies are summarized strictly by entity counts (`families_count: 1`, `devices_count: 0`, `location_events: 0`). Raw user profile records or database dumps were not committed.

---

## 4. Evidence Provenance & Limitations

> [!NOTE]
> **Provenance Distinction:**
> While `gate2_results.json` perfectly mirrors the narrative reports and represents authentic recorded telemetry from the executing test harness, it is a local machine-readable document. It serves as strong corroborating evidence of the live test invocations, but in the absence of server-side audit logs (which were read-only and unqueried in Phase 3.7.1), it is classified as **LOCAL TELEMETRY ARTIFACT — STRONGLY CORROBORATING**, fully backed by the corresponding Edge Function invocation count increment (+4) verified on the Supabase Dashboard.
