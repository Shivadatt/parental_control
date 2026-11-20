# Phase 3.6 — Report 08: Cleanup & Recovery Architecture Design

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Audit Date:** 2026-11-20  

---

## 1. Cleanup Architecture & Mission-Critical Principles

To ensure that the creation of ephemeral test tenants never clutters the production database, leaves lingering credentials, or poses an ongoing security liability, a formal teardown and recovery engine is designed.

```
┌─────────────────────────────────────────────────────────────┐
│ 1. TARGET IDENTIFICATION (Strict Correlation Predicate)     │
│  - Select entities matching EXACT metadata->>'test_run_id'  │
│  - Blacklist check: Assert NOT IN (protected_accounts)      │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ 2. DRY-RUN SIMULATION (Pre-Execution Audit)                 │
│  - Output exact list of target UUIDs and tables affected    │
│  - Require operator confirmation if executed interactively  │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ 3. SURGICAL TEARDOWN CASCADE (Ordered Execution)            │
│  - Step A: Delete paired test devices                       │
│  - Step B: Delete family memberships                        │
│  - Step C: Delete ephemeral families                        │
│  - Step D: Delete ephemeral profiles                        │
│  - Step E: Delete GoTrue Auth users (auth.admin.deleteUser) │
│  - Step F: Purge orphaned audit_logs (test_run_id tagged)   │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│ 4. POST-CLEANUP VERIFICATION (Zero-State Proof)             │
│  - Verify 0 rows remain across all tables for correlation ID│
│  - Generate signed cleanup audit manifest                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Surgical Teardown Sequence & Pseudocode

```ts
interface CleanupTarget {
  correlationId: string;
  dryRun?: boolean;
}

const PROTECTED_ACCOUNTS = new Set([
  "spg7753@gmail.com",
  "ankit@gmail.com",
  "ankit1@gmail.com",
]);

export async function executeEphemeralCleanup(
  db: SupabaseClient,
  target: CleanupTarget,
): Promise<CleanupSummary> {
  const { correlationId, dryRun = false } = target;

  if (!correlationId || !correlationId.startsWith("run-")) {
    throw new Error("Invalid correlation ID. Must begin with 'run-'");
  }

  // 1. Discover all profiles created under this test run
  const profilesResult = await db
    .from("profiles")
    .select("id, display_name")
    .contains("metadata", { test_correlation_id: correlationId });
  const profiles = profilesResult.data ?? [];

  // SAFETY ASSERTION: Confirm zero protected accounts match
  for (const profile of profiles) {
    const userRes = await db.auth.admin.getUserById(profile.id);
    if (userRes.data.user?.email && PROTECTED_ACCOUNTS.has(userRes.data.user.email)) {
      throw new Error(`CRITICAL ABORT: Protected account matched: ${userRes.data.user.email}`);
    }
  }

  if (dryRun) {
    console.log(`[DRY-RUN] Would delete ${profiles.length} profiles and cascaded families.`);
    return { dryRun: true, profilesFound: profiles.length };
  }

  // 2. Cascade: Deleting families removes members, devices, telemetry
  const familiesResult = await db
    .from("families")
    .delete()
    .contains("metadata", { test_correlation_id: correlationId });

  // 3. Remove profiles
  for (const profile of profiles) {
    await db.from("profiles").delete().eq("id", profile.id);
    // 4. Remove GoTrue Auth user
    await db.auth.admin.deleteUser(profile.id);
  }

  // 5. CRITICAL: Sweep orphaned audit logs (since audit_logs ON DELETE SET NULL)
  const auditPurge = await db
    .from("audit_logs")
    .delete()
    .contains("metadata", { test_correlation_id: correlationId });

  return {
    deletedProfiles: profiles.length,
    deletedAuditLogs: auditPurge.count ?? 0,
    correlationId,
  };
}
```

---

## 3. Resolving the `audit_logs` Orphan Invariant

As uncovered in Report 02, `public.audit_logs` specifies:
```sql
family_id uuid references public.families (id) on delete set null,
actor_user_id uuid references public.profiles (id) on delete set null,
```
Because deleting a family or profile sets these foreign keys to `NULL` rather than deleting the log rows, a standard database cascade leaves test audit records in the database.

### Resolution Protocol
1. **Mandatory Metadata Tagging:** Every audit event emitted by or on behalf of an ephemeral test tenant must include:
   ```json
   "metadata": {
     "test_correlation_id": "<RUN_ID>",
     "is_ephemeral_test": true
   }
   ```
2. **Explicit Audit Log Purge Step:** The cleanup engine explicitly executes:
   ```sql
   DELETE FROM public.audit_logs 
   WHERE metadata->>'test_correlation_id' = '<RUN_ID>';
   ```
3. **Safety Guarantee:** Real operational audit records do not contain `test_correlation_id` matching this pattern, ensuring zero operational audit logs can ever be touched.

---

## 4. Emergency Recovery & Dead-Man's Switch

If a test execution terminates unexpectedly (e.g., CI worker killed, network partition, process abort):
1. **Time-To-Live (TTL):** Every ephemeral entity carries `metadata->>'expires_at'`.
2. **Scheduled Sweep Script:** An automated sweeper inspects for expired ephemeral entities:
   ```sql
   SELECT id FROM public.profiles 
   WHERE (metadata->>'expires_at')::timestamptz < now() 
     AND metadata->>'is_ephemeral_test' = 'true';
   ```
3. **Owner Notification:** If an expired test entity persists beyond 2 hours, an alert is dispatched to `spg7753@gmail.com`.
