# 05 — Backend Authentication and Update Path

**Date:** 2026-11-21  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED  
**No production endpoint was invoked in this phase.**

---

## 1. Deployment context

`device-telemetry` is declared with `verify_jwt=false` in the repository contract. It is designed to be called by the Android background service using **device credentials**, not a user JWT.

The repository’s deployment documentation records the device functions as deployed, but this investigation did **not** query the hosted project. Local source is the implementation reference; deployed runtime equality is **not re-verified** in this phase.

---

## 2. Authentication mechanism

`supabase/functions/_shared/auth.ts` → `requireDevice(req, db)`

| Check | Behavior on failure |
|---|---|
| `x-device-id` present | `401 device_auth_required` |
| `x-device-secret` present | `401 device_auth_required` |
| Device ID is a UUID | `401 invalid_device_credentials` |
| Secret length 16–512 | `401 invalid_device_credentials` |
| Row exists for ID and has `secret_hash` | `401 invalid_device_credentials` |
| `sha256(secret)` constant-time-equals `secret_hash` | `401 invalid_device_credentials` |
| `status == active` and `credential_revoked_at == null` | `403 device_revoked` |

On success it returns the device row with `id`, `family_id`, `child_user_id`, `policy_version`, `last_seen_at`, etc.

**Security properties:**

- The raw secret is never stored server-side; only the SHA-256 hash.
- Secret values are never logged by this path.
- Unknown IDs still perform a comparison to reduce timing differences.

---

## 3. Heartbeat update query

`supabase/functions/device-telemetry/index.ts`, `case "heartbeat"`:

1. `requireDevice(req, db)` — fail here means no update.
2. Builds a patch:
   - `last_seen_at = new Date().toISOString()`
   - optional `battery_level`, `is_charging`
   - optional `enforcement_mode` and permission flags from `capabilities`
   - **never** advances `policy_version`
3. Executes:

```ts
db.from("devices")
  .update(patch)
  .eq("id", device.id)
  .select("id")
  .maybeSingle()
```

4. `ensureNoError(updated)` turns SQL errors into a 500.
5. Low-battery alert creation is a separate branch.
6. Returns `server_time` and `pending_policy_version`.

**Service-role filter:** the update is by primary key from the authenticated device row, not by caller-supplied family/device data. There is no client-controlled WHERE clause beyond the authenticated ID.

---

## 4. What would each failure look like?

| Failure | Result | Would parent see old data? |
|---|---|---|
| Missing/mismatched device credential | **401**, no update | Yes |
| Device revoked / credential revoked | **403**, no update | Yes |
| Invalid `capabilities` payload | **400**, no update | Yes |
| Valid auth, SQL update error | **500**, no update | Yes |
| Valid auth, update succeeds | **200**, `last_seen_at` updated | No |
| Auth succeeds but device row not found | Should be caught by `requireDevice` | N/A |

There is no heartbeat retry queue server-side and no partial update.

---

## 5. Why this points to authentication, not database failure

- The device row is still readable by the parent and by the child (`fetchMyDevice` returns it), so the row exists and is `active`.
- The child app is a fresh install with a new secret; the server hash is from the older install.
- The parent’s `last_seen_at` is frozen at the last pre-reinstall value, which is exactly where a successful update would have changed it.
- An SQL/DB failure would be a 500 and would also affect other writes; no such pattern is observed.
- A revoked status is not shown for the active row (the separate old row is the revoked one).

The evidence is therefore most consistent with `401 invalid_device_credentials` and inconsistent with “database update silently failed.”

---

## 6. Backend verdict

**PASS (source)** — the authentication and update path is fully implemented, fail-closed, and uses the correct device row.

**NOT VERIFIED (deployed runtime)** — this phase did not invoke the hosted endpoint or read its logs.

**Most likely outcome for the observed install:** the heartbeat is rejected before the update because the request’s secret does not match the stored `secret_hash`.
