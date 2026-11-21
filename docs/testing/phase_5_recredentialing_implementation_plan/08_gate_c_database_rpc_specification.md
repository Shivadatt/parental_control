# 08 — Database Schema, Challenge Lifecycle and Atomic RPC Proposal

**Scope:** Behavioural specification for Gate C. **No SQL, DDL or migration is written or authorized.**  
**Existing schema evidence:** `supabase/migrations/20260101000000_core.sql`, `20260101000100_functions.sql`, `20260101000200_rls.sql`.

---

## 1. Existing schema facts used

- `devices` (`core.sql:79-123`):
  - `id`, `family_id`, `child_user_id`, `installation_id`, `secret_hash` (64-hex or null), `credential_issued_at`, `credential_revoked_at`, `status` (`pending|active|revoked`), `policy_version`, permissions, `last_seen_at`;
  - `UNIQUE (family_id, installation_id)` at 111;
  - partial unique index `devices_one_active_per_child` on `child_user_id where status='active'` at 117–119.
- `family_members` (`core.sql:55-70`) has `status` and `removed_at`; active membership is required.
- `audit_logs` (`core.sql:375-390`) accepts `event_type` 1–80 chars and object metadata.
- `remote_sessions` (`core.sql:321-350`) statuses include `requested|accepted|active|ended`.
- Devices RLS: `devices_select_parent_or_child` (`rls.sql:68-72`).
- Device column grants exclude `secret_hash`/`installation_id` (`rls.sql:255-266`).
- `private.revoke_device`/`private.unlink_child` use `FOR UPDATE` (`functions.sql:432-470`, `325-365`) and end sessions.

---

## 2. New table: `device_recredential_challenges`

### Columns
| Column | Type | Null | Default | Note |
|---|---|---|---|---|
| `id` | uuid | no | random | PK |
| `family_id` | uuid | no | — | FK families, cascade |
| `device_id` | uuid | no | — | FK devices, cascade |
| `child_user_id` | uuid | no | — | FK profiles, cascade |
| `created_by` | uuid | no | — | FK profiles, set null; approving parent |
| `code_hash` | text | no | — | 64 lowercase hex; never the code |
| `status` | text | no | `pending` | `pending|consumed|expired|superseded|cancelled` |
| `expires_at` | timestamptz | no | — | 10 min (D2) |
| `attempts` | int | no | 0 | `>=0` |
| `max_attempts` | int | no | 5 | `>0` (D2) |
| `consumed_at` | timestamptz | yes | null | success only |
| `consumed_by` | uuid | yes | null | child user id |
| `superseded_at` | timestamptz | yes | null | replaced |
| `cancelled_at` | timestamptz | yes | null | parent cancel |
| `created_at` | timestamptz | no | now | — |

No device secret, installation ID, JWT or raw code is stored.

### Constraints
- `code_hash` unique and 64-hex.
- `status` enum check.
- consistency checks: consumed/superseded/cancelled timestamps match status.
- `attempts >= 0`, `max_attempts > 0`.

### Indexes
- unique partial on `device_id where status='pending'` — one pending challenge per device.
- `(child_user_id, status)`, `(family_id, status)`, `(expires_at)`.
- unique `(code_hash)`.

### RLS/grants
- RLS enabled; **no policies** for `anon`/`authenticated`.
- `REVOKE ALL` from `public`, `anon`, `authenticated`.
- `GRANT SELECT, INSERT, UPDATE` to `service_role` only.
- RPCs `SECURITY DEFINER`, safe `search_path`, execute to `service_role` only.

This mirrors the service-only posture of `device_pairing_tokens` (`rls.sql:73`).

---

## 3. Challenge lifecycle

```
pending ──consume──► consumed
   │
   ├──expire──► expired
   ├──new request──► superseded
   └──parent cancel──► cancelled
```

- Only `consumed` means the credential changed.
- `expired`/`superseded`/`cancelled` leave the old credential valid.
- A revoked/unlinked device makes any pending challenge unusable through the device/membership guards.

---

## 4. RPC: `request_device_recredential`

**Inputs:** `p_device_id uuid`, `p_actor_user_id uuid`, `p_code_hash text`, `p_expires_at timestamptz`, `p_max_attempts int`.
**Returns:** challenge metadata (no hash/code).

**One transaction:**
1. Lock device.
2. Active parent membership in `device.family_id` (D3).
3. Device active, `credential_revoked_at IS NULL`.
4. Child membership active.
5. Supersede pending challenge for the device.
6. Insert challenge.
7. Audit `device_recredential_requested`.
8. Return metadata.

**Errors:** `device_not_found`, `forbidden`, `device_not_active`, `child_not_active`, `challenge_conflict`.

---

## 5. RPC: `record_device_recredential_attempt`

**Inputs:** `p_challenge_id uuid`, `p_child_user_id uuid`.
**Returns:** `{attempts, max_attempts, allowed, reason}`.

**Behaviour:** lock challenge; if not pending/expired → allowed false; increment and commit (D8) before secret validation; allowed when `attempts <= max_attempts`.

This is a **separate committed call**, intentionally not rolled back with a failed redeem (D8). It must not be used to mutate the credential.

---

## 6. RPC: `redeem_device_recredential` (atomic)

**Inputs:** challenge id, child id, installation id, secret hash, platform/versions.
**Returns:** public device projection.

**One transaction:**
1. Lock challenge.
2. If `consumed`, run D9 idempotency check: installation id + hash match current active device → return success; else `recovery_already_used`.
3. If not pending → expired/superseded/cancelled.
4. Expiry check; attempts check.
5. Child matches challenge and has active membership.
6. Lock device; verify same family/child, active, not revoked.
7. Installation uniqueness excluding this device.
8. Update `secret_hash`, `installation_id`, `credential_issued_at`; keep `id`, `family_id`, `child_user_id`, `status`, `policy_version`, permissions, `display_name`, `last_seen_at`.
9. End active remote sessions for the device (D5) with reason `device_recredentialed`.
10. Mark challenge consumed.
11. Audit `device_recredentialed`.
12. Commit.

**Errors:** `challenge_not_found`, `challenge_expired`, `challenge_superseded`, `challenge_cancelled`, `recovery_already_used`, `attempts_exhausted`, `forbidden`, `child_not_active`, `challenge_mismatch`, `device_not_active`, `installation_conflict`.

**Parent re-validation:** recommended **any active parent** in the family (D3); alternative is the creating parent only. Freeze before Gate C.

---

## 7. Optional RPCs

- `device_recredential_status(p_device_id, p_actor_user_id)` — parent-only read; no code/hash.
- `cancel_device_recredential(p_challenge_id, p_actor_user_id)` — parent-only; pending only; audit.

Depend on **I3**.

---

## 8. Transaction and concurrency

- Lock order: challenge → device. Existing `revoke_device` locks device; `unlink_child` locks membership then updates devices. Tests must prove no deadlock and no active device for a removed child.
- Partial unique index prevents two pending challenges.
- Concurrent redeem: one rotation; second idempotent/409.
- Audit insert failure rolls back the rotation.
- Session ending is inside the same transaction.

---

## 9. Why SECURITY DEFINER alone is not security

Each RPC must also have:
- ownership by a trusted migration owner (not a client role);
- `SET search_path = public, private, pg_temp`;
- explicit active-membership and device-state checks inside the body;
- execute revoked from `public`/`anon`/`authenticated`, granted to `service_role`;
- no dynamic SQL;
- no reliance on caller-supplied ids for family/child authority.

---

## 10. Missing capability statement

Without this Gate C surface, Gate B cannot function. A client-only or Edge-only rotation would be non-atomic and is forbidden.

No SQL or migration was written.
