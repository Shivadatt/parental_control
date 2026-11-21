# 07 — Edge Function / API Contract and Orchestration Proposal

**Scope:** Proposed HTTP contracts for Gate B. No endpoint is added or changed in this phase.

---

## 1. Placement and auth model

| Operation | Function | Action | Auth |
|---|---|---|---|
| Parent creates challenge | `family-admin` | `request_device_recredential` | user JWT, parent, verified email, active parent in device family |
| Parent status (optional) | `family-admin` | `credential_recovery_status` | parent |
| Parent cancel (optional) | `family-admin` | `cancel_device_recredential` | parent |
| Child redeems | `device-register` | `recovery_redeem` | user JWT, child, verified email, active child membership |

`family-admin` and `device-register` both have `verify_jwt = true` (`supabase/config.toml`), so no new function/config entry is needed.

No device headers are used: the device credential is what is being replaced.

---

## 2. Envelope (existing convention)

Success: `{ "ok": true, "data": {...} }`  
Error: `{ "ok": false, "error": { "code", "message", "details?" } }`  
Source: `supabase/functions/_shared/envelope.ts:31-55`.

---

## 3. Parent request

`POST /functions/v1/family-admin`

```json
{
  "action": "request_device_recredential",
  "device_id": "<uuid>"
}
```

| Field | Required | Validation |
|---|---|---|
| `device_id` | yes | `readUuid` |
| `family_id`, `child_user_id` | no | ignored; server derives from the device |

**Server orchestration**
1. `requireUser(req, db, {requireVerifiedEmail:true})`; `requireRole('parent')`.
2. `readUuid`.
3. Load device; `assertFamilyParent(auth.user.id, device.family_id)`; require active/not revoked.
4. Generate code in the Edge layer (crypto random, 8 chars from the existing 30-symbol alphabet), compute SHA-256, pass hash + expiry to the RPC.
5. RPC supersedes pending, inserts challenge, audits.
6. Return code/expiry to Parent only.

**Success 200**
```json
{
  "ok": true,
  "data": {
    "challenge_id": "<uuid>",
    "code": "<8-char>",
    "expires_at": "<iso8601>",
    "attempts_remaining": 5,
    "device": { "id": "<uuid>", "family_id": "<uuid>", "child_user_id": "<uuid>",
                "display_name": "<name>", "platform": "android", "status": "active",
                "last_seen_at": "<iso8601|null>" }
  }
}
```

**Errors:** 400 validation, 401 unauthorized, 403 forbidden/email_not_verified, 404 device_not_found, 409 device_not_active/child_not_active, 429 rate_limited, 503 recovery_disabled.

**Retry:** re-request supersedes; only one pending challenge per device.
**Audit:** `device_recredential_requested`.

---

## 4. Child redeem

`POST /functions/v1/device-register`

```json
{
  "action": "recovery_redeem",
  "code": "<8-char>",
  "device_id": "<uuid>",
  "installation_id": "<string>",
  "secret_hash": "<64-hex>",
  "platform": "android",
  "android_version": "12",
  "app_version": "1.0.0"
}
```

| Field | Required | Validation |
|---|---|---|
| `code` | yes | normalize + 8-char alphabet |
| `device_id` | yes | must equal challenge device (defence in depth) |
| `installation_id` | yes | `readInstallationId` 8–128, `[A-Za-z0-9._:-]+` |
| `secret_hash` | yes | `readHex64` |
| `platform`/versions | no | existing limits |
| `display_name` | no | ignored (D7) |

**Never accepted as authority:** raw `secret`, `family_id`, `child_user_id`, `status`, `credential_revoked_at`, `policy_version`, `last_seen_at`.

**Server orchestration**
1. `requireUser(verified)`; `requireRole('child')`.
2. Validate fields.
3. Normalize code, hash it, locate challenge.
4. Apply committed attempt accounting (`record_device_recredential_attempt`).
5. Call atomic `redeem_device_recredential` with challenge id, child id, device id, installation id, hash, platform/versions.
6. Return public device projection.

**Success 200**
```json
{
  "ok": true,
  "data": {
    "status": "recredentialed",
    "device": { "id":"<uuid>", "family_id":"<uuid>", "child_user_id":"<uuid>",
                "display_name":"<name>", "platform":"android",
                "android_version":"12", "app_version":"1.0.0",
                "status":"active", "credential_issued_at":"<iso8601>",
                "last_seen_at":"<iso8601|null>" }
  }
}
```
No `secret_hash`, no `installation_id`.

**Errors:** 400, 401, 403, 404 `recovery_not_found`, 409 `recovery_already_used`/`device_not_active`/`installation_conflict`, 410 `challenge_expired`, 429, 503.

**Idempotency (D9):** if consumed and installation id + hash match the current row → 200 same device; otherwise 409. Never rotate twice.

**Audit:** `device_recredentialed` (in the same transaction).

---

## 5. Optional status/cancel

### Status
```json
{ "action": "credential_recovery_status", "device_id": "<uuid>" }
```
Response: `state` (`none|pending|consumed|expired|superseded|cancelled`), `expires_at`, `attempts_remaining`, `completed_at`. Never returns the code/hash.

### Cancel
```json
{ "action": "cancel_device_recredential", "challenge_id": "<uuid>" }
```
Parent of the challenge family only; `pending` only; audit `device_recredential_cancelled`.

These depend on decision **I3** (report 14).

---

## 6. Service-role-only RPC calls

| RPC | Caller | Purpose |
|---|---|---|
| `request_device_recredential` | `family-admin` | supersede + insert + audit |
| `record_device_recredential_attempt` | `device-register` | D8 committed attempt |
| `redeem_device_recredential` | `device-register` | atomic rotate |
| `device_recredential_status` (opt) | `family-admin` | read state |
| `cancel_device_recredential` (opt) | `family-admin` | cancel |

No `anon`/`authenticated` execute privilege; details in report 08.

---

## 7. Contract invariants

1. Parent request carries no secret/hash.
2. Child completion carries only `secret_hash`, never the raw secret.
3. Responses never include `secret_hash` or `installation_id`.
4. `family_id`/`child_user_id` are derived from the device/challenge, never trusted from the body.
5. The code is returned once to the Parent; status never re-returns it.
6. Existing `register` behaviour/errors are unchanged for old clients.
7. A server-side feature flag can disable both actions.

---

## 8. Evidence

- Envelope: `_shared/envelope.ts`.
- Auth helpers: `_shared/auth.ts:124-253`.
- Validation: `_shared/validation.ts:149-241`.
- Existing actions: `family-admin/index.ts:57-123`, `device-register/index.ts:106-239`.
- Function JWT config: `supabase/config.toml`.
