# PHASE 3.1 — STAGE A: ACCOUNT SOURCE SECURITY AUDIT

**Project:** Parent Control App  
**Local Function Path:** `supabase/functions/account/`  
**Target Project Reference:** `hhqgreaoqulmfwfwarhc`  
**Execution Mode:** STRICT READ-ONLY AUDIT  
**Audit Date:** 2026-11-18  

---

## 1. SOURCE AUDIT SCOPE & METHODOLOGY

A line-by-line static inspection was performed across all source files comprising the `account` Edge Function:
- `supabase/functions/account/index.ts` (581 lines)
- `supabase/functions/account/retention.ts` (300 lines)
- `supabase/functions/account/validation.ts` (117 lines)
- `supabase/functions/_shared/auth.ts`
- `supabase/functions/_shared/envelope.ts`
- `lib/features/settings/account_privacy_repository.dart`
- `lib/features/settings/parent_settings_controller.dart`

---

## 2. SOURCE INSPECTION & VERIFICATION TABLE

| Check Identifier | Security & Functional Check | Expected Behavior | Actual Implementation Behavior | Status | Evidence (File & Line) |
|---|---|---|---|---|---|
| **SRC-01** | Function Entrypoint & Method Gating | Rejects non-POST methods with HTTP 405; supports OPTIONS preflight | Checks `req.method !== "POST"` after OPTIONS; returns 405 `method_not_allowed` | **PASS** | `index.ts:551-555` |
| **SRC-02** | CORS & Header Security | Exposes safe headers; caches preflight 24h; no sensitive credentials returned | Returns `corsHeaders` with `authorization, x-client-info, apikey, content-type` | **PASS** | `_shared/cors.ts:1-9`, `index.ts:552` |
| **SRC-03** | JSON Body Parsing & Size Bounds | Safe parsing of JSON body; handles malformed syntax | `readJson(req)` safely extracts object; throws 400 `invalid_json` on syntax errors | **PASS** | `_shared/envelope.ts:31-45`, `index.ts:557` |
| **SRC-04** | Action Dispatch Routing | Only supports documented actions (`retention_report`, `export`, `delete_account`) | `requireAction(body)` throws 400 `unknown_action` on unsupported values | **PASS** | `index.ts:558, 568-577` |
| **SRC-05** | Authentication Enforcement | Every protected request requires valid Supabase Auth Bearer JWT | `requireUser(req, db)` extracts token and validates via `db.auth.getUser(token)` | **PASS** | `_shared/auth.ts:80-99`, `index.ts:566` |
| **SRC-06** | Identity Non-Spoofability | Client-supplied user IDs or family IDs cannot override JWT identity | Scoping strictly uses `auth.user.id`; ignores client body user IDs | **PASS** | `index.ts:227, 346, 481` |
| **SRC-07** | Three-State Privacy Scoping (PRIV-01) | Child restricted to own device rows; Parent restricted to active families | `resolveRetentionScope` yields `device`, `family`, or `not_reported` | **PASS** | `retention.ts:122-175`, `index.ts:480` |
| **SRC-08** | Sweep Marker Redaction | Non-owner parents and children cannot read project-wide sweep totals | `includeSweepTotals` is true ONLY for family owner; redacted to `null` otherwise | **PASS** | `retention.ts:151-175`, `index.ts:495` |
| **SRC-09** | Retention Days Clamping | Clamps absurd retention windows; falls back safely to defaults | Clamped to [1, 3650] days; defaults to 30 days location, 90 days usage | **PASS** | `retention.ts:25-37` |
| **SRC-10** | Export Sensitive Column Exclusion | Device secrets, hashes, and pairing codes excluded from SQL queries | `DEVICE_COLUMNS` strictly excludes `secret_hash`, `device_secret`, and tokens | **PASS** | `index.ts:30-46, 251-260` |
| **SRC-11** | Export Memory Capping & DoS Guard | Prevents memory exhaustion on large exports | `EXPORT_PAGE_SIZE = 1,000`, hard cap `EXPORT_ROW_CAP = 20,000` with `truncated: true` | **PASS** | `index.ts:48-49, 107-110` |
| **SRC-12** | Delete Confirmation Requirements | Requires exact literal `"DELETE"` and caller email match | `validateDeleteAccountInput` strictly enforces case-sensitive confirmation & email | **PASS** | `validation.ts:36-66`, `index.ts:347` |
| **SRC-13** | Family Owner Orphan Blocker | Owner cannot delete account if other members or active devices exist | `findDeletionBlocker` blocks deletion with 409 `account_deletion_blocked` | **PASS** | `validation.ts:95-116`, `index.ts:396` |
| **SRC-14** | Pre-Deletion Audit Trail | Irreversible deletion must be audited before records are purged | Inserts `account_deleted` audit log prior to deleting memberships and profile | **PASS** | `index.ts:410-421` |
| **SRC-15** | Idempotent Self-Healing Retry | Incomplete deletions (Auth delete failure) recoverable on retry | `requireUser` creates stub profile (`role: 'unset'`); subsequent retry succeeds | **PASS** | `_shared/auth.ts:105-115`, `index.ts:448` |
| **SRC-16** | Service Role Credential Isolation | High-privilege service-role key never sent to client | Confined strictly to Deno backend; zero exposure in envelopes or logs | **PASS** | `_shared/auth.ts:49-65` |

---

## 3. AUDIT CONCLUSION & CODE QUALITY ASSESSMENT

- **Verdict:** **PASS (16/16 Checks Verified)**
- **Code Modifications:** **NONE**
- **External Dependencies:** Fully resolved via `npm:@supabase/supabase-js@2`. No broken paths.
- **Client Contract Compatibility:** Wire envelope matches `lib/features/settings/account_privacy_repository.dart` identically.
