# 09 — Authentication, Authorization, RLS, Grants and Threat Model

**Scope:** Security boundary for the implementation. Planning only. No property is claimed as implemented.

---

## 1. Authentication layers (existing evidence)

| Layer | Mechanism | Source |
|---|---|---|
| Parent/Child JWT | Supabase Auth `getUser(token)` | `_shared/auth.ts:88-118` |
| Verified email | `email_confirmed_at` | `_shared/auth.ts:108,150-162` |
| Profile role | `profiles.role` | `_shared/auth.ts:124-173` |
| Family membership | active `family_members` row | `_shared/auth.ts:207-253` |
| Device credential | `x-device-id` + `x-device-secret`, SHA-256 constant time | `_shared/auth.ts:297-353` |
| Edge gateway | `verify_jwt` per function | `supabase/config.toml` |

Recovery uses **user JWTs only**; it does not use device headers because the device credential is being replaced.

---

## 2. Authorization matrix

| Action | Parent | Child | Service role |
|---|---|---|---|
| Request challenge | ✅ active parent in device family | ❌ | via Edge only |
| Read status | ✅ same family | ❌ | via Edge only |
| Cancel | ✅ same family | ❌ | via Edge only |
| Redeem/rotate | ❌ | ✅ active child in challenge family | via Edge only |
| Read challenge table | ❌ no policy/grant | ❌ | ✅ |
| Execute RPC | ❌ | ❌ | ✅ |

**No client** can read `code_hash`, `secret_hash` or `installation_id` through the API.

---

## 3. RLS and grants

Existing patterns to reuse:
- Devices column grants exclude `secret_hash`/`installation_id` (`rls.sql:255-266`).
- `device_pairing_tokens` is service-only with no policies (`rls.sql:73`).
- RPCs are service-role-only with `REVOKE ALL` from public/anon/authenticated (e.g. `20260101000400_device_recovery.sql:85-88`).

New table requirements:
- RLS enabled.
- No `anon`/`authenticated` policies.
- `REVOKE ALL` from `public`, `anon`, `authenticated`.
- `GRANT SELECT, INSERT, UPDATE` to `service_role`.
- No delete grant required.

New RPC requirements:
- `SECURITY DEFINER`, trusted owner, safe `search_path`.
- Execute to `service_role` only.
- Explicit membership/device checks inside the body.
- No dynamic SQL.

**SECURITY DEFINER is not sufficient by itself**; ownership, search_path, execute grants and in-body authorization are all required.

---

## 4. Threat model

| ID | Threat | Protection | Enforcement | Residual |
|---|---|---|---|---|
| T1 | Unauthorized parent | role + active parent membership | Edge + RPC | none |
| T2 | Foreign-family device | derive family from device; re-check | Edge + RPC | none |
| T3 | Wrong Child account | challenge bound to child; active membership | RPC | none |
| T4 | Revoked device | `status='active'` guard; existing re-link gate | RPC + Edge | none |
| T5 | Suspended membership | active membership filter | Edge + RPC | none |
| T6 | Stolen Child session | Parent approval + code required | Edge + RPC | **partial** |
| T7 | Challenge guessing | 30^8 code, hash-only, 5 attempts, rate limit | Edge + DB | low |
| T8 | Challenge replay | consumed status; D9 match check | RPC | none |
| T9 | Compromised Parent session | TTL, single-use, target confirmation, audit | Edge + RPC | **residual (D10)** |
| T10 | Concurrent redeem | `FOR UPDATE` on challenge | RPC | none |
| T11 | Concurrent requests | device lock + partial unique pending | RPC + DB | none |
| T12 | Expired challenge | `expires_at` under lock | RPC | none |
| T13 | Brute force | committed attempts + rate limits | RPC + Edge | low |
| T14 | Credential leakage | no secrets in logs/audit/responses | all layers | low |
| T15 | Partial transaction | one transaction; audit rollback | RPC | none |
| T16 | Response loss | heartbeat oracle + D9 retry | RPC + client | low |
| T17 | Old credential reuse | hash replaced atomically | RPC + `requireDevice` | none |
| T18 | Installation collision | uniqueness check + 409 | RPC + DB | low |
| T19 | Process death during persistence | stable secret + `config()==null` recovery | client | low |

### Explicit non-claims
- Physical possession is **not** proven after secret loss.
- A stolen Parent session can authorize rotation within its family (D10 defers step-up).
- A stolen Child session plus a deceived Parent can complete recovery.
- Out-of-band code delivery is a human channel, not confidential.

---

## 5. RLS leak checks

Required tests:
1. `authenticated`/`anon` select on `device_recredential_challenges` → denied.
2. `authenticated` cannot execute any new RPC.
3. Devices select still cannot see `secret_hash`/`installation_id`.
4. Parent/Child API responses contain no hash/installation id.
5. Audit metadata contains no secret/code.

---

## 6. Audit and failure posture

- Request/completion audit is inside the RPC transaction; audit failure rolls back.
- Denial audit is best-effort and never grants access.
- Rate-limit query failure fails closed.
- Response bodies for 404/403 are uniform enough not to confirm another family's device.

---

## 7. Evidence vs proposal

| Claim | Class |
|---|---|
| Existing auth/RLS/grants | VERIFIED (source) |
| New table/RPC security requirements | DESIGN PROPOSAL (Gate C) |
| Residual risks | OWNER-ACCEPTED in Phase 5 brief? **Not explicitly signed in Phase 4 file** |
| Threat controls | DESIGN, not implemented |

---

## 8. Security verdict

The design is defensible for the stated model, with documented residual risks. All 14 Phase 4 required properties have an enforcement point (Phase 4 report `05_security_threat_model.md`). No control is implemented in this phase.
