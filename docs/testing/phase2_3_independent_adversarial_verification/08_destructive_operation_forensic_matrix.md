# Phase 2.3 — Destructive Operation Forensic Matrix & Hazard Analysis

**Document ID:** `HAVEN-GOV-PHASE2-3-DEST`  
**Phase:** Phase 2.3 — Independent Adversarial Governance Closure & Backend Isolation Verification  
**Workspace:** `D:\parentcontrol_app`  
**Branch:** `main`  
**Starting HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Forensic Database, Cascade & Backend Mutation Audit  
**Execution Posture:** STRICTLY READ-ONLY  

---

## 1. Forensic Audit Scope & Hazard Methodology

Destructive testing operations possess irreversible potential to corrupt database state, sever device management, purge historical telemetry, or delete production customer records.

This forensic audit analyzes the exact source code, SQL functions, Edge Function handlers, and foreign key cascades for the eight primary destructive operations identified in the HAVEN test suite:
- `TC-A09`: Parent Account Deletion with Cascade
- `TC-FAM10`: Unlink Child Account from Parent Dashboard
- `TC-FAM12`: Revoke Device Access from Dashboard
- `TC-EXP-17`: Permanent Account Deletion Verification
- `TC-EXP-18`: Child Record Removal & Orphan Cleanup
- `TC-EXP-47`: On-Demand Historical Audit Log Purge (`AUD03`)
- `TC-EXP-48`: Database Scheduled Retention Sweep (`AUD04`)
- `TC-EXP-55`: Device Admin Revocation & Tamper Handling

---

## 2. Table-by-Table Foreign Key Cascade Forensic Analysis

Inspection of `supabase/migrations/20260101000000_core.sql` reveals extensive `ON DELETE CASCADE` constraints across the relational schema:

```
+--------------------------------------------------------------------------------------------------+
|                               FOREIGN KEY CASCADE RISK TOPOLOGY                                  |
+--------------------------------------------------------------------------------------------------+
                                        [ families ]
                                             |
                   +-------------------------+-------------------------+
                   | (ON DELETE CASCADE)                               | (ON DELETE CASCADE)
                   v                                                   v
          [ family_members ]                                     [ devices ]
                   |                                                   |
                   v (ON DELETE CASCADE)                               v (ON DELETE CASCADE)
             [ profiles ]                                   [ device_policies ]
                                                            [ device_commands ]
                                                            [ location_events ]
                                                            [ usage_daily ]
                                                            [ safe_zones ]
                                                            [ safety_alerts ]
+--------------------------------------------------------------------------------------------------+
```

### 2.1 Cascade Impact Findings
- Deleting a row from `families` triggers hard cascading deletes across `family_members`, `devices`, `device_policies`, `device_commands`, `location_events`, `usage_daily`, `safe_zones`, and `safety_alerts`.
- Deleting a parent user from `auth.users` via `db.auth.admin.deleteUser()` triggers profile deletion and cascades to all child devices enrolled by that parent.
- **Recovery Feasibility**: None. Rows deleted by `ON DELETE CASCADE` cannot be restored without a full point-in-time database backup restore.

---

## 3. Deep Forensic Inspection: The Retention Sweep Hazard (`AUD04` / `TC-EXP-48`)

Inspection of `supabase/migrations/20261030000300_retention_sweep.sql:116–250` reveals the exact execution logic of `public.run_retention_sweep()`:

```sql
-- 1. WebRTC Signaling Deletion (GLOBAL - NO FAMILY FILTER)
delete from public.webrtc_signals w
where w.id = any (
  select id from public.webrtc_signals
  where created_at < v_now - interval '7 days'
  limit v_batch
);

-- 2. Audit Log Deletion (GLOBAL - NO FAMILY FILTER)
delete from public.audit_logs a
where a.id = any (
  select id from public.audit_logs
  where created_at < v_now - interval '365 days'
  limit v_batch
);

-- 3 + 4. Per-Family Sweep (LOOPS THROUGH EVERY SINGLE FAMILY IN DATABASE)
for v_family in select f.id, f.settings from public.families f order by f.id loop
  -- Deletes location_events older than family retention setting
  delete from public.location_events le where family_id = v_family.id ...;
  -- Deletes usage_daily older than family retention setting
  delete from public.usage_daily u where family_id = v_family.id ...;
end loop;
```

### 3.1 Forensic Evidence Summary
1. **Zero Arguments**: `run_retention_sweep()` takes **zero parameters**. A caller cannot pass a `family_id` to restrict the sweep to a QA family.
2. **Global Deletion**: Steps 1 and 2 delete WebRTC signaling and audit logs **across all families globally**.
3. **Unfiltered Family Loop**: Steps 3 and 4 iterate across **every family in `public.families`**, applying retention cutoffs to real customers.
4. **Conclusion**: Running `TC-EXP-48` in the shared production project (Pathway B) will permanently delete customer telemetry and signaling records. It is **STRICTLY PROHIBITED on Pathway B**.

---

## 4. Operation-by-Operation Forensic Safety Matrix

The following matrix documents the exact technical mechanics and safety boundaries for all destructive operations:

| Test ID | Operation Name | Triggering Entry Point | Calling Backend Handler | Tables Directly & Indirectly Affected | Scoping Mechanism | Quarantine Requirement | Pathway B Compatibility |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| **`TC-A09`** | Parent Account Deletion | App UI `/account/delete` | `account` Edge Function action `delete_account` | `profiles`, `families`, `family_members`, `devices`, all telemetry | User-scoped via verified JWT (`caller.user.id`). | Disposable Account mandatory (`qa-destroy-*`). | **PROHIBITED** (High risk to production tables). |
| **`TC-FAM10`**| Unlink Child Account | App UI Device Detail | `family-admin` action `revoke_device` / RPC | `devices` (status set to revoked), local Keystore credentials | Scoped via `assertFamilyParent(family_id)`. | Disposable Device mandatory. Must run at end. | Compatible on dedicated test device. |
| **`TC-FAM12`**| Revoke Device Access | App UI Device Detail | `family-admin` action `revoke_device` | `devices.status`, `devices.credential_revoked_at` | Scoped via `assertFamilyParent(family_id)`. | Disposable Device mandatory. | Compatible on dedicated test device. |
| **`TC-EXP-17`**| Account Hard Deletion | App UI Settings | `account/deletion.ts` (`executeAccountDeletion`) | `auth.users`, `profiles`, cascades to `devices` | User-scoped via JWT. Blocked if active members exist. | Disposable Account mandatory. | **PROHIBITED** on Pathway B. |
| **`TC-EXP-18`**| Child Record Removal | App UI Family Members | `family-admin` action `remove_member` | `family_members`, `devices`, associated rules | Scoped via `assertFamilyOwner(family_id)`. | Disposable Fixtures mandatory. | Compatible on dedicated test family. |
| **`TC-EXP-47`**| Audit Purge (`AUD03`) | In-App Audit Settings | Backend gap: `family-admin` purges location/usage, not audit logs | `location_events`, `usage_daily` | Scoped via `assertFamilyOwner(family_id)`. | Requires isolated test family. | Compatible (Only purges QA family data). |
| **`TC-EXP-48`**| Retention Sweep (`AUD04`)| Scheduled cron / API | `cron` action `retention_sweep` -> SQL RPC | `webrtc_signals`, `audit_logs`, `location_events`, `usage_daily` | **UNSCOPED / GLOBAL** (Deletes across ALL families). | **ISOLATED BACKEND MANDATORY.** | **STRICTLY PROHIBITED** on Pathway B. |
| **`TC-EXP-55`**| Device Admin Revoke | Android OS Settings | Local `ParentControlDeviceAdminReceiver` | Local OS admin rights; triggers alert to backend | Local handset only. | Dedicated test phone mandatory. | Compatible on dedicated test device. |

---

## 5. Destructive Testing Governance Rules

1. **Pathway B Hard Quarantine**: Under Pathway B, `TC-EXP-48` is permanently locked and excluded from execution runs.
2. **Account Deletion Protocol**: `TC-A09` and `TC-EXP-17` must never be run with credentials matching active developer or customer accounts.
3. **Execution Sequencing**: All destructive tests must execute strictly at the terminal stage of a test cycle.
