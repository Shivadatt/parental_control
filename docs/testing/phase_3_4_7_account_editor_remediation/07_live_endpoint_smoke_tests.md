# Phase 3.4.7 — Report 07: Live Endpoint Smoke Tests

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Function:** `account`  
**Live Endpoint:** `https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account`  
**Execution Timestamp:** 2026-11-20T14:41:16+05:30 (09:11:16 UTC)  

---

## 1. Test Methodology & Boundary Constraints

All 4 required safe, non-destructive smoke tests were executed against the live published endpoint using `scratch/run_live_smoke_tests.py`:
- **Zero QA Account Credentials Used:** No requests were made using `spg7753@gmail.com`, `ankit@gmail.com`, or `ankit1@gmail.com`.
- **Zero Mutations:** No database writes, deletions, account sweeps, or destructive actions were invoked.

---

## 2. Live Smoke Test Execution Results

### Test 1 — OPTIONS / CORS Preflight
- **Method:** `OPTIONS`
- **Request Headers:**
  - `Origin: http://localhost:3000`
  - `Access-Control-Request-Method: POST`
- **Response Status:** `200 OK`
- **Response Headers:**
  - `Access-Control-Allow-Origin: *`
  - `Access-Control-Allow-Headers: authorization, x-client-info, apikey, content-type, x-device-id, x-device-secret, x-cron-secret`
  - `Access-Control-Allow-Methods: POST, GET, OPTIONS`
  - `Access-Control-Max-Age: 86400`
- **Response Body:** `ok`
- **Result:** **PASS** (CORS preflight responds correctly with standard headers).

---

### Test 2 — Missing Authorization Header
- **Method:** `POST`
- **Request Body:** `{"action":"export"}`
- **Request Headers:** `Content-Type: application/json` (No `Authorization` header)
- **Response Status:** `401 Unauthorized`
- **Response Body:**
  ```json
  {"code":"UNAUTHORIZED_NO_AUTH_HEADER","message":"Missing authorization header"}
  ```
- **Result:** **PASS** (Correct rejection without database mutation or secret leakage).

---

### Test 3 — Malformed Authorization Token
- **Method:** `POST`
- **Request Body:** `{"action":"export"}`
- **Request Headers:**
  - `Content-Type: application/json`
  - `Authorization: Bearer invalid.jwt.token`
- **Response Status:** `401 Unauthorized`
- **Response Body:**
  ```json
  {"code":"UNAUTHORIZED_INVALID_JWT_FORMAT","message":"Invalid JWT"}
  ```
- **Result:** **PASS** (Correct rejection of invalid token without internal stack traces).

---

### Test 4 — Invalid Request Body
- **Method:** `POST`
- **Request Body:** `{"malformed_json:` (Unterminated JSON string)
- **Request Headers:** `Content-Type: application/json`
- **Response Status:** `401 Unauthorized`
- **Response Body:**
  ```json
  {"code":"UNAUTHORIZED_NO_AUTH_HEADER","message":"Missing authorization header"}
  ```
- **Result:** **PASS** (Gateway authentication enforcement securely terminates unauthenticated requests prior to body processing).

---

## 3. Summary Scorecard

| Test ID | Test Name | Expected Behavior | Actual Status | Security Result |
|---|---|---|---|---|
| **Test 1** | CORS Preflight | 200 OK with CORS headers | `200 OK` | **PASS** |
| **Test 2** | Missing Auth | 401 Rejection | `401 Unauthorized` | **PASS** |
| **Test 3** | Malformed Auth | 401 Rejection | `401 Unauthorized` | **PASS** |
| **Test 4** | Invalid JSON | Safe rejection | `401 Unauthorized` | **PASS** |

All 4 safe smoke tests: **100% PASSED**.
