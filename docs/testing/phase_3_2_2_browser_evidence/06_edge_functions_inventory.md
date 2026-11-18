# Phase 3.2.2 — Report 06: Supabase Edge Functions & Secrets Audit

## 1. Executive Summary

This report delivers the verified live inventory of Supabase Edge Functions deployed to project `parent-control-prod` (`hhqgreaoqulmfwfwarhc`) and documents the environment secrets configured in the Edge runtime.

Inspection was conducted directly on the Supabase Edge Functions dashboard (`/functions`) and Secrets viewer (`/functions/secrets`).

---

## 2. Deployed Edge Functions (9 Total)

The Supabase Edge Functions dashboard lists **exactly 9 deployed functions**.

- **Visual Evidence**: [P322_07_edge_functions_01.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_07_edge_functions_01.png)

| # | Function Name | Endpoint Path | Status | Execution / Purpose |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `auth-bootstrap` | `/functions/v1/auth-bootstrap` | **DEPLOYED** | Handles user initial profile onboarding and family assignment |
| 2 | `cron` | `/functions/v1/cron` | **DEPLOYED** | Periodic maintenance tasks (stale session cleanup, daily rollups) |
| 3 | `device-command` | `/functions/v1/device-command` | **DEPLOYED** | Dispatches real-time remote commands (lock, wipe, ring, message) |
| 4 | `device-policy` | `/functions/v1/device-policy` | **DEPLOYED** | Syncs and validates parental restriction policies |
| 5 | `device-register`| `/functions/v1/device-register`| **DEPLOYED** | Enrolls new physical devices into family registry |
| 6 | `device-telemetry`| `/functions/v1/device-telemetry`| **DEPLOYED** | Ingestion pipeline for battery, app usage, and status telemetry |
| 7 | `family-admin` | `/functions/v1/family-admin` | **DEPLOYED** | Administrative family management, member invites, removal |
| 8 | `pairing` | `/functions/v1/pairing` | **DEPLOYED** | Cryptographic QR/PIN handshake and pairing token resolution |
| 9 | `remote-session` | `/functions/v1/remote-session` | **DEPLOYED** | WebRTC signaling coordination and session state negotiation |

---

## 3. CRITICAL DEFECT FINDING: `account` Function Status

### Finding: `account` Edge Function is MISSING from Supabase Dashboard
- **Expected Function**: `account` (Source: `supabase/functions/account/index.ts`)
- **Dashboard Status**: **NOT DEPLOYED (ABSENT)**
- **Visual Evidence**: [P322_07_edge_functions_01.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_07_edge_functions_01.png) shows exactly 9 functions deployed. `account` does not appear in the dashboard list.

### Impact Analysis:
1. **Confirms Defect E-15**:
   - The Flutter parent application's `account_privacy_repository.dart` attempts to invoke the `account` function for account deletion and data export requests.
   - Because the function is not deployed to `hhqgreaoqulmfwfwarhc`, any client invocation receives an HTTP `404 Not Found` response.
2. **Phase 3.1 Prerequisite Confirmed**:
   - Phase 3.1 diagnosed that local implementation exists in the repository (`supabase/functions/account/`) with 10 unit tests passing, but the production project had never received the deployment.
   - This live browser inspection provides direct visual proof confirming that the function is indeed not deployed.

---

## 4. Edge Function Environment Secrets

Inspection of **Edge Functions > Secrets** (`/functions/secrets`) revealed the following secret configuration:

- **Visual Evidence**: [P322_08_edge_function_secrets.png](file:///d:/parentcontrol_app/docs/testing/phase_3_2_2_browser_evidence/P322_08_edge_function_secrets.png)

### Custom Application Secrets Present:
1. `CRON_SECRET`: Configured (Secures the `cron` function endpoint from unauthorized invocations).
2. `STUN_URL`: Configured (STUN server endpoint for WebRTC NAT traversal).
3. `PAIRING_HASH_PEPPER`: Configured (Cryptographic pepper for pairing token hashing).

### System Secrets Present:
Standard Supabase managed secrets are automatically injected into the Edge runtime:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_DB_URL`

*(All secret values remain strictly masked and unrevealed in compliance with read-only security instructions).*

---

## 5. Summary & Action Items

| Item | Live State | Verification | Action Required |
| :--- | :--- | :--- | :--- |
| **Deployed Functions** | 9 functions | **VERIFIED** | None (Operational) |
| **`account` Function** | Missing | **CONFIRMED DEFECT** | Deploy `account` function in controlled Phase 3.1 step |
| **Custom Secrets** | 3 present | **VERIFIED** | Ensure `ACCOUNT_DELETION_PEPPER` or equivalent is provisioned if required |
