# PHASE 3.1 — STAGE F, G, H, I: DEPLOYMENT & POST-DEPLOYMENT SMOKE TEST PLAN

**Target Function:** `account`  
**Target Project Reference:** `hhqgreaoqulmfwfwarhc`  
**Region:** `ap-south-1`  
**Execution Mode:** PREPARE ONLY — NO DEPLOYMENT EXECUTED  
**Audit Date:** 2026-11-18  

---

## 1. CONTROLLED DEPLOYMENT SPECIFICATION (PREPARE ONLY)

```
DEPLOYMENT_EXECUTED = NO
```

### Reference Deployment Command (DO NOT EXECUTE WITHOUT AUTHORIZATION)
```powershell
supabase functions deploy account --project-ref hhqgreaoqulmfwfwarhc
```

### Deployment Prerequisites
1. **Tooling:** Supabase CLI >= v1.140.0 (Installed version: `v2.109.0`).
2. **Authentication:** The deployment environment must be authenticated with access to project `hhqgreaoqulmfwfwarhc` via:
   ```powershell
   supabase login
   # OR set environment variable:
   $env:SUPABASE_ACCESS_TOKEN = "<PROJECT_ADMIN_TOKEN>"
   ```
3. **Execution Directory:** `D:\parentcontrol_app`
4. **Target Subdirectory:** `supabase/functions/account/`
5. **Secrets & Config:** Handled natively by Supabase platform (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`).

### Rollback Strategy
If runtime errors or unexpected behavior occur following deployment:
```powershell
supabase functions delete account --project-ref hhqgreaoqulmfwfwarhc
```
Deleting the function safely reverts the remote state to the pre-deployment 404 state, which the Flutter client already handles gracefully without crashing.

---

## 2. POST-DEPLOYMENT SMOKE TEST PLAN (NON-DESTRUCTIVE)

These tests may be executed ONLY after explicit deployment authorization:

### Smoke Test 1 — OPTIONS / CORS Preflight
- **Method:** `OPTIONS`
- **URL:** `https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account`
- **Expected Status:** `200 OK` (with `Access-Control-Allow-Origin: *` and `Access-Control-Allow-Methods: POST, OPTIONS`).

### Smoke Test 2 — Unauthenticated Request Rejection
- **Method:** `POST`
- **URL:** `https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account`
- **Headers:** None (No Bearer token)
- **Expected Status:** `401 Unauthorized` with JSON envelope `{"ok": false, "error": {"code": "unauthorized"}}`.

### Smoke Test 3 — Invalid Authentication Token
- **Method:** `POST`
- **Headers:** `Authorization: Bearer invalid_jwt_token_12345`
- **Expected Status:** `401 Unauthorized` (Session rejected by `db.auth.getUser`).

### Smoke Test 4 — Parent Retention Report (Pixel 9a Emulator)
- **Environment:** Pixel 9a Emulator logged in as Parent `ankit@gmail.com`.
- **Navigation:** Open Parent Shell -> Tap Settings Tab (Tab 3).
- **Expected Result:**
  - Defect E-15 error banner (`Retention report unavailable: Requested function was not found`) disappears.
  - Retention cards load displaying Location and Daily Usage retention windows.

### Smoke Test 5 — Retention Policy Default Values
- **Verification:** Inspect loaded retention card on Parent Settings.
- **Expected Values:**
  - Location Retention Window: **30 days**.
  - Daily Usage Retention Window: **90 days**.

### Smoke Test 6 — Child Device Access Restrictions
- **Verification:** Safe, non-mutating check using Child JWT (`ankit1@gmail.com`).
- **Expected Result:** Function resolves `scope: "device"`. Project-wide sweep totals and other members' records are excluded.

### Smoke Test 7 — Error Handling on Unknown Action
- **Method:** `POST` with valid JWT and body `{"action": "unsupported_action"}`.
- **Expected Status:** `400 Bad Request` with error code `unknown_action`.

### Smoke Test 8 — Delete Account Safety Rejection (Non-Destructive)
- **Verification:** Open Delete Account dialog in Parent Settings.
- **Action:** Enter incorrect text (e.g. `CANCEL`) or wrong email and submit.
- **Expected Result:** Request rejected with `confirmation_required` or `email_mismatch`.
- **CRITICAL RULE:** **NEVER ENTER THE TRUE CONFIRMATION (`DELETE` + `ankit@gmail.com`).**

---

## 3. DEVICE VERIFICATION SPECIFICATION

### Parent Device: Pixel 9a Emulator (Android 15)
1. Verify Parent session remains active without forced re-login.
2. Verify Parent Dashboard metrics load normally.
3. Verify Settings tab loads retention report cleanly.
4. Verify no UI crashes or memory leaks occur.

### Child Device: Realme RMX2161 (Android 12)
1. Verify Child session remains active without forced re-login.
2. Verify `GuardianService` continues running in background.
3. Confirm that no device credentials or Keystore secrets are modified.

---

## 4. REGRESSION & INTEGRITY VERIFICATION

This deployment is surgically scoped to the `account` Edge Function and preserves all previous fixes:
- **E-16 (Device Recovery):** Keystore secret and desync recovery remain untouched.
- **E-11 (Policy Acknowledgement):** Policy versioning and acknowledge loop remain untouched.
- **E-13 (Safe Zone Atomic RPC):** `delete_safe_zone_audited` remains untouched.
- **E-17 (Realtime Reconnect):** `WidgetsBindingObserver` backoff on `SafetyAlertsController` remains untouched.
- **E-18 (Advisory Mode):** Non-Device Owner advisory reporting on `PolicyApplier.kt` remains untouched.
