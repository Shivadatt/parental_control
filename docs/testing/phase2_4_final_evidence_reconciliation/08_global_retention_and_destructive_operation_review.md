# Phase 2.4 — Global Retention Sweep & Destructive Operation Forensic Review

**Document ID:** `HAVEN-GOV-PHASE2-4-DEST`  
**Phase:** Phase 2.4 — Final Evidence Reconciliation & Governance Correction Audit  
**Workspace:** `D:\parentcontrol_app`  
**Branch:** `main`  
**Starting HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Audit Standard:** Forensic Database, Cascade & Destructive Operation Verification  
**Execution Posture:** STRICTLY READ-ONLY  

---

## 1. Scope & Adversarial Forensics

Destructive operations carry permanent, irreversible consequences. This forensic review investigates the exact mechanics of destructive backend operations in HAVEN Parent Control, with primary focus on:
1. `public.run_retention_sweep()` in `supabase/migrations/20261030000300_retention_sweep.sql` (`AUD04`).
2. The critical operational distinction between `AUD03` (On-Demand Purge) and `AUD04` (Scheduled Retention Sweep).
3. The foreign key cascading delete risks associated with account deletion (`TC-A09`, `TC-EXP-17`).

---

## 2. Deep Forensic Inspection: `public.run_retention_sweep()` (`AUD04` / `TC-EXP-48`)

Source inspection of `supabase/migrations/20261030000300_retention_sweep.sql:116–250` establishes the following verified facts:

```sql
CREATE OR REPLACE FUNCTION public.run_retention_sweep()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
...
```

### 2.1 Function Signature & Security Attributes
- **Signature**: `public.run_retention_sweep() RETURNS jsonb` (Takes **zero arguments**; cannot accept a `family_id` target parameter).
- **Privilege**: `SECURITY DEFINER` (Executes with database owner / superuser privileges).
- **Search Path**: Explicitly hardened (`SET search_path = public, pg_temp`).
- **Grants**: Revoked from `anon` and `authenticated`; granted strictly to `service_role`.

### 2.2 Table-by-Table Deletion Logic
1. **`webrtc_signals` (Global / Unfiltered)**:
   ```sql
   delete from public.webrtc_signals where created_at < v_now - interval '7 days';
   ```
   *Forensic Impact*: Deletes signaling records across **all families and all users globally**.
2. **`audit_logs` (Global / Unfiltered)**:
   ```sql
   delete from public.audit_logs where created_at < v_now - interval '365 days';
   ```
   *Forensic Impact*: Deletes administrative audit logs older than 365 days across **all families globally**.
3. **`location_events` & `usage_daily` (Unfiltered Loop Over All Families)**:
   ```sql
   for v_family in select f.id, f.settings from public.families f order by f.id loop
     ...
     delete from public.location_events where family_id = v_family.id and recorded_at < cutoff;
     delete from public.usage_daily where family_id = v_family.id and day < cutoff;
   end loop;
   ```
   *Forensic Impact*: Iterates through **every single row in `public.families`** and applies retention cutoffs to real production customer families!

---

## 3. Critical Distinction: `AUD03` vs `AUD04`

Prior audit documents occasionally blurred `AUD03` and `AUD04`. Phase 2.4 establishes their definitive separation:

```
+--------------------------------------------------------------------------------------------------+
|                                OPERATIONAL SEPARATION: AUD03 VS AUD04                            |
+--------------------------------------------------------------------------------------------------+
| ATTRIBUTE                AUD03 (TC-EXP-47)                 AUD04 (TC-EXP-48)                     |
|--------------------------------------------------------------------------------------------------|
| Operation Name           On-Demand Historical Data Purge   Scheduled Global Retention Sweep      |
| Triggering Entity        Family Owner via App Settings     External HTTPS Cron / GitHub Actions  |
| Backend Entry Point      family-admin action `purge_data`  cron action `retention_sweep`         |
| Execution Target         Deno service-role query           PostgreSQL RPC run_retention_sweep()  |
| Scoping Mechanism        Strictly scoped (.eq("family_id"))Unscoped loop across ALL families   |
| Tables Affected          location_events, usage_daily      webrtc_signals, audit_logs,           |
|                                                            location_events, usage_daily          |
| Audit Log Deletion?      NO (Does not delete audit logs)   YES (Deletes logs older than 365d)    |
| Pathway B Compatibility  PERMITTED (On dedicated QA family)STRICTLY PROHIBITED (Deletes prod)   |
+--------------------------------------------------------------------------------------------------+
```

---

## 4. Foreign Key Cascading Delete Risks (`TC-A09`, `TC-EXP-17`)

Source inspection of `supabase/functions/account/deletion.ts:282–355` (`executeAccountDeletion`) reveals:
1. When a parent account is deleted, the backend deletes the user's row from `public.families` where `owner_id = userId`.
2. Under PostgreSQL schema constraints (`20260101000000_core.sql:48–65`), `families` has `ON DELETE CASCADE` on:
   - `family_members` (child memberships severed).
   - `devices` (child paired device records permanently deleted).
   - `device_policies`, `device_commands`, `location_events`, `usage_daily`, `safe_zones`, `safety_alerts`.
3. In addition, GoTrue `db.auth.admin.deleteUser(userId)` is executed.
4. **Recovery Feasibility**: Irreversible. Data cannot be recovered without a complete database snapshot restore.

---

## 5. Destructive Operation Safety Verdict

```
====================================================================================================
                        DESTRUCTIVE OPERATION SAFETY VERDICT
====================================================================================================

   1. TC-EXP-48 (Retention Sweep / AUD04):
      - Pathway A: PERMITTED on dedicated staging project with automated seed scripts.
      - Pathway B: STRICTLY PROHIBITED. Executing run_retention_sweep() on production is 
        catastrophic and would delete customer telemetry and signaling globally.

   2. TC-EXP-47 (On-Demand Data Purge / AUD03):
      - Pathway A & B: PERMITTED exclusively on dedicated QA family fixture.

   3. TC-A09 & TC-EXP-17 (Account Hard Deletion):
      - Pathway A: PERMITTED on staging disposable accounts.
      - Pathway B: PROHIBITED on production (to prevent rate limits and accidental cascade).

====================================================================================================
```
