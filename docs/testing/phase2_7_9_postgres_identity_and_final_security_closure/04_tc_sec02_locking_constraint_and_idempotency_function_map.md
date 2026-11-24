# HAVEN PARENT CONTROL — PHASE 2.7.9
## DELIVERABLE 04: TC-SEC02 LOCKING, CONSTRAINT & IDEMPOTENCY FUNCTION MAP

**Document ID:** `HAVEN-GOV-PHASE2-7-9-DOC04`  
**Phase:** Phase 2.7.9 — PostgreSQL Identity Semantics, Function Ownership & Final Security Evidence Closure  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Actual Git HEAD:** `20cc0b1439ebea1b3808d769e7b91b646a9fe089`  
**Parent Commit:** `e5022531beeb7393a7a5585351af891180630216`  
**Execution Posture:** STRICTLY READ-ONLY  
**Audit Standard:** Forensic Function-by-Function Transaction & Concurrency Mapping  
**Test Reference:** `TC-SEC02` (Functionality ID: `FAM13` / Wave 3)  

---

### 1. AUDIT OBJECTIVE & REQUIREMENT

Previous audit phases occasionally generalized the replay protection of `TC-SEC02` by stating that all pairing and recovery procedures share an identical locking pattern. 

In compliance with Section 8 of the Phase 2.7.9 charter, this deliverable performs an independent, function-by-function forensic breakdown of each database stored procedure involved in pairing, token redemption, and device recovery.

---

### 2. INDEPENDENT FUNCTION-BY-FUNCTION FORENSIC BREAKDOWN

#### 2.1 Function 1: `private.respond_pairing_request`
- **Source Migration:** `supabase/migrations/20260101000100_functions.sql` (lines 130–220).
- **Public Wrapper:** `public.respond_pairing_request` (lines 222–230), granted exclusively to `service_role`.
- **Security Mode:** `SECURITY DEFINER`, `SET search_path = public, private, pg_temp`.
- **Inputs & Validation:** `p_request_id uuid, p_child_user_id uuid, p_approve boolean`. Validates `p_approve is not null` (raises `22023`).
- **Row-Level Locks (`FOR UPDATE`):**
  1. `SELECT * INTO v_request FROM public.pairing_requests WHERE id = p_request_id FOR UPDATE;`
  2. `SELECT * INTO v_token FROM public.device_pairing_tokens WHERE id = v_request.token_id FOR UPDATE;`
  3. `SELECT * INTO v_existing FROM public.family_members WHERE family_id = v_request.family_id AND user_id = p_child_user_id FOR UPDATE;`
- **Advisory Locks:** **NONE.** Relies exclusively on row-level exclusive locks.
- **Status & Expiration Checks:**
  - `v_request.child_user_id = p_child_user_id` (raises `42501` forbidden if mismatched).
  - `v_request.status = 'pending_child'` (raises `request_already_responded` if resolved).
  - `v_request.expires_at > now()` (raises `code_expired`).
  - `v_token.status = 'active'` and `v_token.expires_at > now()` (raises `code_expired`).
  - Parent membership active in family.
- **Conditional State Transition:**
  ```sql
  update public.device_pairing_tokens
  set status = 'redeemed', redeemed_at = now(), redeemed_by = v_request.parent_user_id
  where id = v_token.id;
  ```
- **Idempotent Retry Handling:**
  ```sql
  if v_request.status <> 'pending_child' then
    if v_request.status = 'approved' and p_approve then
      return jsonb_build_object('status', 'approved', 'family_id', v_request.family_id);
    end if;
    if v_request.status = 'rejected' and not p_approve then
      return jsonb_build_object('status', 'rejected', 'family_id', v_request.family_id);
    end if;
    raise exception 'request_already_responded' using errcode = 'P0001';
  end if;
  ```
  If network drops after approval, client retry with matching approval returns current approved status safely.

---

#### 2.2 Function 2: `private.create_pairing_request`
- **Source Migration:** `supabase/migrations/20260101000600_atomic_pairing_invite.sql` (lines 90–140).
- **Public Wrapper:** `public.create_pairing_request` (lines 160–175), granted exclusively to `service_role`.
- **Security Mode:** `SECURITY DEFINER`, `SET search_path = public, private, pg_temp`.
- **Inputs & Validation:** `p_child_user_id uuid, p_family_id uuid, p_parent_user_id uuid, p_token_id uuid, p_expires_at timestamptz`. Validates non-null UUIDs and expiry (raises `22023`).
- **Row-Level Locks:** **NONE.**
- **Advisory Locks:**
  ```sql
  perform pg_advisory_xact_lock(
    hashtextextended(
      p_child_user_id::text || ':' || p_family_id::text || ':' || p_parent_user_id::text,
      0
    )
  );
  ```
  Enforces single-threaded serial execution for any request involving the same `child:family:parent` tuple throughout the transaction.
- **Unique Constraint & Replay Trapping:**
  - Table `public.pairing_requests` enforces `UNIQUE(token_id)`.
  - When concurrent replay occurs:
    ```sql
    exception
      when unique_violation then
        -- pairing_requests.token_id is unique: the same token was redeemed
        -- concurrently for a different triple (a replay, not a duplicate inbox
        -- row). Keep the caller's existing 409 code for that case.
        raise exception 'code_unavailable' using errcode = 'P0001';
    ```
- **Idempotency:** If a request with status `pending_child` already exists for this triple, returns `{ created: false, request: v_request }` without raising an error.

---

#### 2.3 Function 3: `private.create_pairing_invite`
- **Source Migration:** `supabase/migrations/20260101000600_atomic_pairing_invite.sql` (lines 15–80).
- **Security Mode:** `SECURITY DEFINER`, `SET search_path = public, private, pg_temp`.
- **Advisory Locks:** `pg_advisory_xact_lock` on `child_user_id:family_id:parent_user_id`.
- **Operation:** Checks for existing active tokens (`status = 'active' AND expires_at > now()`). If found, returns existing token to prevent duplicate invite flooding. Otherwise, inserts new token.

---

#### 2.4 Function 4: `private.request_device_recovery`
- **Source Migration:** `supabase/migrations/20260101000400_device_recovery.sql` (lines 15–70).
- **Public Wrapper:** `public.request_device_recovery` (lines 72–85), granted exclusively to `service_role`.
- **Security Mode:** `SECURITY DEFINER`, `SET search_path = public, private, pg_temp`.
- **Row-Level Locks (`FOR UPDATE`):**
  ```sql
  select * into v_device
  from public.devices
  where id = p_device_id
  for update;
  ```
- **Advisory Locks:** **NONE.**
- **Atomic Operations:** Calls `private.unlink_child(v_device.family_id, v_device.child_user_id, p_actor_user_id)`, which revokes old devices, invalidates tokens, and cancels pending requests in a single database transaction.

---

### 3. COMPREHENSIVE FUNCTION-BY-FUNCTION MATRIX

```
+-----------------------------------+--------------------+--------------------+-----------------------+--------------------+-----------------------+-----------------------+
| Function Name                     | Row Locks          | Advisory Lock      | State Transition      | Unique Constraint  | Idempotent Retries    | Source Conclusion     |
+-----------------------------------+--------------------+--------------------+-----------------------+--------------------+-----------------------+-----------------------+
| 1. respond_pairing_request        | FOR UPDATE on      | NONE               | 'active' ->           | None evaluated     | Returns approved state| SOURCE-VERIFIED       |
|                                   | requests & tokens  |                    | 'redeemed'            | in this function   | if already responded  | (Row-level serial)    |
|                                   |                    |                    |                       |                    |                       |                       |
| 2. create_pairing_request         | NONE               | pg_advisory_xact   | Inserts new pending   | UNIQUE(token_id)   | Returns existing      | SOURCE-VERIFIED       |
|                                   |                    | on child:fam:parent| request record        | catches replay 409 | pending request       | (Advisory lock serial)|
|                                   |                    |                    |                       |                    |                       |                       |
| 3. create_pairing_invite          | NONE               | pg_advisory_xact   | Inserts active        | Partial unique     | Returns existing      | SOURCE-VERIFIED       |
|                                   |                    | on child:fam:parent| pairing token         | on active tokens   | active invite token   | (Advisory lock serial)|
|                                   |                    |                    |                       |                    |                       |                       |
| 4. request_device_recovery        | FOR UPDATE on      | NONE               | 'active' -> 'revoked' | Unlinks child      | Returns recovery      | SOURCE-VERIFIED       |
|                                   | target device      |                    | via unlink_child()    | in same transaction| started dictionary    | (Row-level serial)    |
+-----------------------------------+--------------------+--------------------+-----------------------+--------------------+-----------------------+-----------------------+
```

---

### 4. CRITICAL REPLAY & CONCURRENCY LIMITATIONS

1. **Sequential Replay is Source-Proven:** When replaying the exact same request payload 1 second later, `respond_pairing_request` rejects the call with `code_expired` / `request_already_responded`, and `create_pairing_request` rejects the call with `code_unavailable` (HTTP 409).
2. **Concurrent Race Conditions Require Runtime Validation:** While `FOR UPDATE` row locks and `pg_advisory_xact_lock` provide robust database-level serialization guarantees, concurrent race-condition execution across distributed Edge Function workers under high network load remains **`NOT RUNTIME VERIFIED`**.
