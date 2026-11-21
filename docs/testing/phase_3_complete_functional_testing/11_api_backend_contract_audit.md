# 11 — API and Backend Contract Audit

**Date:** 2026-11-21  
**Mode:** source + offline test verification; **no production endpoint invoked**  
**Statuses:** PASS (contract/offline) / NOT_TESTED (live) / AUTHORIZATION_REQUIRED (live write)

---

## 1. Edge Functions and actions

| Function | Action | Caller auth | Read/write | Client caller | Contract status | Live status |
|---|---|---|---|---|---|---|
| `auth-bootstrap` | `set_role` | User JWT | Write | `supabase_auth_repository.dart` | PASS | NOT_TESTED |
| `auth-bootstrap` | `create_family` | User JWT | Write | `supabase_family_repository.dart` | PASS | NOT_TESTED |
| `pairing` | `get_contact_id` | User JWT | Read | `supabase_pairing_repository.dart` | PASS | NOT_TESTED |
| `pairing` | `create` | User JWT | Write | Pairing repository | PASS | NOT_TESTED |
| `pairing` | `redeem` | User JWT | Write | Pairing repository | PASS | NOT_TESTED |
| `pairing` | `invite` | User JWT | Write | Pairing repository | PASS | NOT_TESTED |
| `pairing` | `pending_child` | User JWT | Read | Pairing repository | PASS | NOT_TESTED |
| `pairing` | `respond` | User JWT | Write | Pairing repository | PASS | NOT_TESTED |
| `pairing` | `cancel` | User JWT | Write | Pairing repository | PASS | NOT_TESTED |
| `pairing` | `list_family` | User JWT | Read | Pairing repository | PASS | NOT_TESTED |
| `pairing` | `unlink` | User JWT | Write | Pairing repository | PASS | NOT_TESTED |
| `device-register` | `register` | Child user JWT | Write | `supabase_device_repository.dart` | PASS | NOT_TESTED |
| `device-policy` | `update` | Parent user JWT | Write | `supabase_policy_repository.dart` | PASS | NOT_TESTED |
| `device-command` | `create` | Parent user JWT | Write | Policy repository | PASS | NOT_TESTED |
| `device-command` | `poll` | Device headers | Write/read | GuardianService | PASS | BLOCKED by credential |
| `device-command` | `ack` | Device headers | Write | GuardianService | PASS | BLOCKED by credential |
| `device-telemetry` | `heartbeat` | Device headers | Write | GuardianService | PASS | BLOCKED by credential |
| `device-telemetry` | `apps_upload` | Device headers | Write | GuardianService | PASS | BLOCKED by credential |
| `device-telemetry` | `usage_upload` | Device headers | Write | GuardianService | PASS | BLOCKED by credential |
| `device-telemetry` | `location_upload` | Device headers | Write | GuardianService | PASS | BLOCKED by credential |
| `family-admin` | `revoke_device` | Parent user JWT | Write | Device repository | PASS | AUTHORIZATION_REQUIRED |
| `family-admin` | `recover_device` | Parent user JWT | Write | Device repository | PASS | AUTHORIZATION_REQUIRED |
| `family-admin` | `ack_alert` | Parent user JWT | Write | Alert repository | PASS | NOT_TESTED |
| `family-admin` | `delete_zone` | Parent user JWT | Write | Location repository | PASS | NOT_TESTED |
| `family-admin` | `update_retention` | Parent user JWT | Write | Family/audit repositories | PASS | NOT_TESTED |
| `family-admin` | `purge_data` | Parent user JWT | Write | Audit repository | PASS | AUTHORIZATION_REQUIRED |
| `remote-session` | `request` | Parent user JWT | Write | Session repository | PASS | AUTHORIZATION_REQUIRED |
| `remote-session` | `session_state` | Participant JWT | Read | Session repository | PASS | NOT_TESTED |
| `remote-session` | `pending_child` | Child JWT | Read | Session repository | PASS | NOT_TESTED |
| `remote-session` | `respond` | Child JWT | Write | Session repository | PASS | AUTHORIZATION_REQUIRED |
| `remote-session` | `start` | Participant JWT | Write | Session repository | PASS | AUTHORIZATION_REQUIRED |
| `remote-session` | `end` | Parent JWT | Write | Session repository | PASS | NOT_TESTED |
| `remote-session` | `ice` | Participant JWT | Write | Session repository | PASS | NOT_TESTED |
| `account` | `export` | User JWT | Read/export | Account privacy repo | PASS | AUTHORIZATION_REQUIRED |
| `account` | `retention_report` | User JWT | Read | Account privacy repo | PASS | NOT_TESTED |
| `account` | `delete_account` | User JWT + confirmation | Write | Account privacy repo | PASS | AUTHORIZATION_REQUIRED |
| `cron` | `expire_sessions` / `detect_offline` / `sweep_sessions` / `retention_sweep` | Cron secret | Write | Scheduler/owner | PASS | NOT_TESTED |

---

## 2. Device authentication contract

- `device-telemetry`, `device-command` poll/ack, and `device-register` are the device-authenticated paths.
- Device calls use `x-device-id` + `x-device-secret`; no user JWT is required for telemetry.
- `requireDevice()` validates header presence, UUID/length, SHA-256 hash equality, `status=active` and `credential_revoked_at IS NULL`.
- Failure codes: `device_auth_required` (401), `invalid_device_credentials` (401), `device_revoked` (403).
- The raw secret is never stored server-side; only the hash.

---

## 3. Error envelope and validation

Shared helpers (`_shared/envelope.ts`, `_shared/validation.ts`) provide:

- standard `{ ok, data }` / `{ ok: false, error: { code, message } }` envelope,
- bounded integer/string/date/enum/package validation,
- CORS preflight,
- no stack traces or database internals in responses.

Offline/unit tests cover these contracts; live production behavior was not invoked.

---

## 4. Database entities touched

`profiles`, `families`, `family_members`, `devices`, `device_policies`, `device_commands`, `device_apps`, `device_pairing_tokens`, `pairing_requests`, `pairing_attempts`, `safe_zones`, `safe_zone_states`, `location_events`, `usage_daily`, `safety_alerts`, `audit_logs`, `remote_sessions`, `webrtc_signals`, `child_contact_ids`.

All 19 tables are RLS-enabled; the local SQL chain executed 33 files with zero errors.

---

## 5. Contract verdict

**PASS (source/offline)** — all discovered actions have a clear caller, auth mechanism, validation and error mapping; the 209-test Deno suite and 33-file SQL chain support the contracts.

**NOT TESTED (live)** — no production API was invoked. A passing offline test does not prove the deployed function matches the repository.

**BLOCKED (device telemetry)** — the three device actions cannot be exercised until the credential mismatch is repaired.

**AUTHORIZATION REQUIRED** — all live write actions listed above.
