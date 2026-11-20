# Phase 3.5 — Report 03: Entrypoint & Action Inventory Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target File:** `docs/testing/phase_3_4_3_browser_package/staging/account/index.ts` (and `deletion.ts`)  
**Audit Date:** 2026-11-20  

---

## 1. HTTP Entrypoint & Routing Architecture

The `account` Edge Function serves as the unified privacy and account lifecycle gateway for the Parent Control system. It handles data portability (GDPR Art. 20 export), right-to-be-forgotten (GDPR Art. 17 deletion), and retention reporting.

### Request Routing Matrix

```mermaid
flowchart TD
    Req[Incoming HTTP Request] --> MethodCheck{HTTP Method?}
    MethodCheck -- OPTIONS --> Preflight[Return 200 OK + CORS Headers]
    MethodCheck -- POST --> BodyParse[Parse JSON via readJson]
    MethodCheck -- GET / PUT / DELETE / PATCH --> MNA[Return 405 Method Not Allowed]
    
    BodyParse --> ActionCheck{body.action}
    ActionCheck -- "export" --> ExportAction[requireUser -> exportAccount -> 200 Attachment Stream]
    ActionCheck -- "delete" / "delete_account" --> DeleteAction[requireAuthUser -> deleteAccount -> 200 Result]
    ActionCheck -- "retention_report" --> RetentionAction[requireUser -> retentionReport -> 200 JSON]
    ActionCheck -- Missing / Invalid --> ActionError[Return 400 unknown_action]
```

### Detailed Method Dispatch Specifications

| Method | Response Status | Handler Behavior | Headers Returned |
|---|---|---|---|
| `OPTIONS` | `200 OK` | Evaluates CORS preflight via `preflightResponse()` | `Access-Control-Allow-Origin: *`, `Access-Control-Allow-Methods: POST, OPTIONS`, `Access-Control-Allow-Headers: authorization, x-client-info, apikey, content-type` |
| `POST` | Variable (`200`, `400`, `401`, `403`, `409`, `500`) | Extracts body via `readJson(req)`, validates `action`, delegates to corresponding business logic | Application standard JSON envelope or attachment |
| `GET` | `405 Method Not Allowed` | Rejection via `ApiError("method_not_allowed", "Use POST.", 405)` | Standard JSON error envelope |
| `PUT` | `405 Method Not Allowed` | Rejection via `ApiError("method_not_allowed", "Use POST.", 405)` | Standard JSON error envelope |
| `DELETE` | `405 Method Not Allowed` | Rejection via `ApiError("method_not_allowed", "Use POST.", 405)` | Standard JSON error envelope (action is triggered via POST body) |
| `PATCH` | `405 Method Not Allowed` | Rejection via `ApiError("method_not_allowed", "Use POST.", 405)` | Standard JSON error envelope |

---

## 2. Action Handlers Inventory

### Action 1: `export` (GDPR Data Portability)
- **Dispatched Actions:** `"export"`
- **Authentication Requirement:** `requireUser(req, db)` (Strict JWT validation + active `profiles` row).
- **Scope Resolution:** Computes scope via `resolveRetentionScope`.
  - If `family` scope (Parent): exports family profile, active members, family devices, and family-wide logs.
  - If `device` scope (Child) or `not_reported`: exports strictly caller's own profile, own devices (`child_user_id = caller`), and audit logs where caller was actor or device owner.
- **Paging & Safety Caps:**
  - Hard safety limit: `EXPORT_ROW_CAP = 20,000` rows per table.
  - PostgREST chunking: `EXPORT_PAGE_SIZE = 1,000` rows per request with deterministic order (`orderColumn DESC, id DESC`).
- **Tables Exported:**
  1. `location_events`
  2. `usage_daily`
  3. `safety_alerts`
  4. `audit_logs`
  5. `devices` (explicitly sanitizing `secret_hash` and revocation secrets)
  6. `families` and `family_members`
- **Output Format:** Directly streamed HTTP attachment:
  - `Content-Type: application/json; charset=utf-8`
  - `Content-Disposition: attachment; filename="parent-control-export-YYYY-MM-DD.json"`
  - `Cache-Control: no-store`

### Action 2: `delete` / `delete_account` (Right to Be Forgotten)
- **Dispatched Actions:** `"delete"`, `"delete_account"`
- **Authentication Requirement:** `requireAuthUser(req, db)` (Strict JWT validation; **exempt from `profiles` existence** to ensure retry-safety).
- **Request Body Contract:**
  ```json
  {
    "action": "delete",
    "confirm": "DELETE",
    "email": "caller@example.com"
  }
  ```
- **Execution Lifecycle:**
  1. Validates affirmative confirmation word `"DELETE"` (case-sensitive) and caller email match.
  2. Checks for deletion blockers (other active family members, active devices).
  3. Audits request start: `account_deletion_requested`.
  4. Cascades deletion: `family_members` -> empty owned `families` -> `profiles`.
  5. Removes identity from Supabase Auth via `db.auth.admin.deleteUser(userId)`.
  6. Audits completion: `account_deleted`.
- **Response Format:**
  ```json
  {
    "ok": true,
    "data": {
      "deleted": true,
      "memberships_removed": 1,
      "families_removed": 1,
      "retry": false
    }
  }
  ```

### Action 3: `retention_report` (Privacy & Retention Audit)
- **Dispatched Actions:** `"retention_report"`
- **Authentication Requirement:** `requireUser(req, db)` (Strict JWT validation + active `profiles` row).
- **Request Body Contract:**
  ```json
  {
    "action": "retention_report"
  }
  ```
- **Computation Rules:**
  - Evaluates `location_retention_days` (default 30) and `usage_retention_days` (default 90) from family settings.
  - Clamps custom window values defensively to `[1, 3650]` days.
  - Returns counts of records older than window: `location_events_older_than_window`, `usage_days_older_than_window`.
  - Redacts project-wide sweep markers from children and non-owner parents.
- **Response Format:**
  ```json
  {
    "ok": true,
    "data": {
      "generated_at": "2026-11-20T14:40:00.000Z",
      "scope": "family",
      "defaults": {
        "location_retention_days": 30,
        "usage_retention_days": 90,
        "webrtc_signals_days": 7,
        "audit_logs_days": 365
      },
      "last_sweep_at": "2026-11-20T00:00:00.000Z",
      "last_sweep": { "location_events_purged": 142, "usage_daily_purged": 18 },
      "families": [...]
    }
  }
  ```

---

## 3. Deliberate Absence of `retention_cleanup` Action

A critical security and architectural finding of this audit is that **`retention_cleanup` is NOT supported in the `account` Edge Function router**.
- Line 460–476 of `index.ts` explicitly supports only `export`, `delete` / `delete_account`, and `retention_report`.
- Any invocation attempting `action: "retention_cleanup"` hits the default switch branch and throws `400 unknown_action`.
- **Architectural Rationale:** Destructive purging of telemetry and usage records is reserved exclusively for the scheduled `cron` Edge Function / automated database maintenance tasks. By omitting `retention_cleanup` from the client-facing `account` function, the architecture prevents any malicious or unauthorized actor from triggering high-volume bulk deletions on demand.
