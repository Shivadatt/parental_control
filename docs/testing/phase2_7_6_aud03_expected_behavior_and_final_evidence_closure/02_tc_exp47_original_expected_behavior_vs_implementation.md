# HAVEN PARENT CONTROL — PHASE 2.7.6
## DELIVERABLE 02: TC-EXP-47 ORIGINAL EXPECTED BEHAVIOR VS IMPLEMENTATION

**Document ID:** `HAVEN-GOV-PHASE2-7-6-DOC02`  
**Phase:** Phase 2.7.6 — AUD03 Expected Behavior, TC-EXP-48 Execution Separation & Final Evidence Closure  
**Workspace:** `D:\parentcontrol_app`  
**Git Branch:** `main`  
**Git HEAD:** `e5022531beeb7393a7a5585351af891180630216`  
**Parent Commit:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Execution Posture:** STRICTLY READ-ONLY  

---

### 1. EXECUTIVE SUMMARY & OBJECTIVE

The objective of this deliverable is to perform an adversarial, source-level audit of test case `TC-EXP-47` (mapped to functionality ID `AUD03`). Specifically, this audit resolves whether:
1. `TC-EXP-47`'s original specification was accurate and the implementation differs (Outcome A);
2. `TC-EXP-47`'s original specification contains a factual mismatch with Haven's deliberate architecture (Outcome B); or
3. `TC-EXP-47` was incorrectly mapped to `AUD03` (Outcome C).

Based on rigorous cross-examination of the primary specification, Flutter UI code, Riverpod controllers, data repositories, Edge Functions, and PostgreSQL database triggers, **Outcome B is definitively established**.

---

### 2. ORIGINAL SPECIFICATION EVIDENCE (`TC-EXP-47`)

The authoritative original specification for `TC-EXP-47` is located in `docs/testing/phase2_coverage_gap_audit/05_additional_manual_test_cases.md` at lines 1151–1168:

```markdown
### TC-EXP-47: Manual Audit Log Purge with Confirmation
- **Category:** Audit & Compliance
- **Target Component:** `features/audit_logs/` + Supabase Edge Function `family-admin`
- **Priority:** Medium
- **Prerequisites:** PREREQ-01, PREREQ-04, historical audit log entries (>60 days old) exist
- **Steps:**
  1. Navigate to Audit Logs screen as Parent.
  2. Tap Settings/Overflow icon -> select "Purge Old Logs".
  3. Dialog appears showing retention threshold (e.g., 60 days) and confirmation input.
  4. Enter confirmation keyword ("PURGE") and tap "Confirm Purge".
  5. Observe loading indicator, then success notification.
  6. Refresh audit log list.
- **Expected Result:**
  - Backend deletes historical logs older than 60 days while retaining recent logs.
  - Success notification shows count of purged records.
  - Audit log list reflects deletion; total count decreases.
  - Action itself is logged as an immutable audit event (meta-audit).
```

---

### 3. COMPLETE REPOSITORY IMPLEMENTATION EVIDENCE

To independently verify the reality of the implementation, every tier of the Haven architecture supporting this feature was audited against the codebase.

#### 3.1 Tier 1: Flutter Client UI (`lib/features/audit_logs/audit_logs_page.dart`)
Lines 310–355 of `lib/features/audit_logs/audit_logs_page.dart` define the purge dialog and user notification:

```dart
// lib/features/audit_logs/audit_logs_page.dart:321-330
final confirmed = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Purge Historical Data'),
    content: Text(
      'The server deletes this family\'s location events older than '
      '$locationCutoff days and usage records older than $usageCutoff days. '
      'The audit log is append-only, so it is not purged. '
      'Only the count the server reports is shown afterwards. '
      'This cannot be undone. Type PURGE to proceed.',
    ),
    // ... confirmation text field requiring "PURGE" ...
```

**Key Client Observation:**
The UI dialog explicitly warns the parent user:
> *"The audit log is append-only, so it is not purged. Only the count the server reports is shown afterwards."*

#### 3.2 Tier 2: Riverpod Controller (`lib/features/audit_logs/audit_logs_controller.dart`)
Line 239 of `lib/features/audit_logs/audit_logs_controller.dart` handles the execution:

```dart
// lib/features/audit_logs/audit_logs_controller.dart:238-249
Future<PurgeResult> purgeHistoricalData(int olderThanDays) async {
  state = state.copyWith(isPurging: true);
  try {
    final result = await _auditRepository.purgeOldData(
      familyId: state.familyId,
      olderThanDays: olderThanDays,
    );
    // ...
    return result;
  } finally {
    state = state.copyWith(isPurging: false);
  }
}
```

#### 3.3 Tier 3: Repository Implementation (`lib/data/repositories/supabase_audit_repository.dart`)
Line 64 of `lib/data/repositories/supabase_audit_repository.dart` invokes the backend Edge Function:

```dart
// lib/data/repositories/supabase_audit_repository.dart:64-77
@override
Future<PurgeResult> purgeOldData({
  required String familyId,
  required int olderThanDays,
}) async {
  final response = await _edgeApi.invokeMap(
    'family-admin',
    action: 'purge_data',
    body: {
      'family_id': familyId,
      'older_than_days': olderThanDays,
    },
  );
  return PurgeResult.fromJson(response);
}
```

#### 3.4 Tier 4: Edge Function (`supabase/functions/family-admin/index.ts`)
Lines 265–345 of `supabase/functions/family-admin/index.ts` implement the `purge_data` action:

```typescript
// supabase/functions/family-admin/index.ts:265-345
case "purge_data": {
  await assertFamilyOwner(db, familyId, actorUserId);
  const allowed = await canPurge(db, familyId);
  if (!allowed) {
    return jsonError(403, "Purge not allowed under active retention policy");
  }

  const cutoff = new Date(Date.now() - olderThanDays * 86400 * 1000).toISOString();

  // 1. Delete telemetry data: location events
  const { count: locCount, error: locErr } = await db
    .from("location_events")
    .delete({ count: "exact" })
    .eq("family_id", familyId)
    .lt("recorded_at", cutoff);
  if (locErr) throw locErr;

  // 2. Delete telemetry data: daily app usage records
  const { count: usageCount, error: usageErr } = await db
    .from("usage_daily")
    .delete({ count: "exact" })
    .eq("family_id", familyId)
    .lt("day", cutoff.substring(0, 10));
  if (usageErr) throw usageErr;

  // 3. Record immutable meta-audit log
  await recordAudit(db, {
    familyId,
    actorUserId,
    eventType: "data_purged",
    details: {
      older_than_days: olderThanDays,
      purged_location_count: locCount ?? 0,
      purged_usage_count: usageCount ?? 0,
      timestamp: new Date().toISOString(),
    },
  });

  return jsonOk({
    purged_location_count: locCount ?? 0,
    purged_usage_count: usageCount ?? 0,
  });
}
```

**Key Backend Observations:**
1. Only `location_events` and `usage_daily` tables are subjected to `delete()`.
2. Both deletions are strictly filtered by `.eq("family_id", familyId)`.
3. No delete operation is ever executed against `audit_logs`.
4. A new audit event of type `"data_purged"` is inserted into `audit_logs`.

#### 3.5 Tier 5: PostgreSQL Database Trigger (`supabase/migrations/20260101000000_core.sql`)
Lines 543–565 of `supabase/migrations/20260101000000_core.sql` establish the database-level security policy for `audit_logs`:

```sql
-- supabase/migrations/20260101000000_core.sql:543-565
CREATE OR REPLACE FUNCTION private.audit_logs_append_only()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'audit_logs is append-only'
      USING ERRCODE = '42501';
  ELSIF TG_OP = 'DELETE' THEN
    -- Only postgres, service_role, or supabase_admin can execute hard sweeps
    IF current_user IN ('postgres', 'service_role', 'supabase_admin') THEN
      RETURN OLD;
    END IF;
    RAISE EXCEPTION 'audit_logs is append-only'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER audit_logs_append_only_trigger
BEFORE UPDATE OR DELETE ON public.audit_logs
FOR EACH ROW EXECUTE FUNCTION private.audit_logs_append_only();
```

---

### 4. COMPREHENSIVE SPECIFICATION VS IMPLEMENTATION MATRIX

| Dimension | TC-EXP-47 Original Specification | Actual Production Implementation | Alignment Status |
| :--- | :--- | :--- | :--- |
| **Feature Title** | "Manual Audit Log Purge with Confirmation" | "Purge Historical Data" (in Audit Logs view) | Minor Name Difference |
| **Location in App** | Audit Logs screen Settings/Overflow menu | `lib/features/audit_logs/audit_logs_page.dart` menu | **ALIGNED** |
| **Confirmation UI** | Modal dialog with threshold and "PURGE" input | Modal dialog requiring exact "PURGE" typing | **ALIGNED** |
| **Caller Role** | Authenticated Parent | Authenticated Family Owner (`assertFamilyOwner`) | **ALIGNED** |
| **Backend Route** | Edge Function `family-admin` | Edge Function `family-admin` (`action: "purge_data"`) | **ALIGNED** |
| **Location Data Purged** | Unspecified | Purged (`public.location_events < cutoff`) | Extended Capability |
| **Usage Data Purged** | Unspecified | Purged (`public.usage_daily < cutoff`) | Extended Capability |
| **Audit Logs Purged** | **"Deletes historical logs older than 60 days"** | **NEVER PURGED (`audit_logs is append-only`)** | **MISMATCH (ARCHITECTURAL)** |
| **Audit Trail List UI** | "Audit log list reflects deletion; count decreases" | Audit list retains logs; new `data_purged` log appears | **MISMATCH (ARCHITECTURAL)** |
| **Meta-Audit Logging** | Action logged as immutable meta-audit event | Logged via `recordAudit(..., "data_purged", ...)` | **ALIGNED** |

---

### 5. EVALUATION OF OUTCOMES & DEFINITIVE CONCLUSION

#### Outcome A Evaluation: Accurate Specification, Differing Implementation
*Hypothesis:* The implementation is defective because it failed to implement audit log deletion.  
*Refutation:* This hypothesis is invalid. Haven's security and compliance posture mandates that the audit trail is legally immutable and tamper-evident. The database trigger `private.audit_logs_append_only()` raises SQLSTATE `42501` to prevent deletion. Deleting audit logs via a client button would violate child safety audit compliance.

#### Outcome C Evaluation: Incorrect Mapping
*Hypothesis:* `TC-EXP-47` was mapped to `AUD03`, but `AUD03` is a completely different feature.  
*Refutation:* This hypothesis is invalid. The UI button in `audit_logs_page.dart`, the controller in `audit_logs_controller.dart`, and the backend endpoint `family-admin/purge_data` represent the single, unique manual purge feature in the application.

#### Outcome B Evaluation: Specification vs. Implementation Mismatch (CONFIRMED)
*Finding:* The original test author named the test *"Manual Audit Log Purge with Confirmation"* because the purge action is initiated from the Audit Logs screen. The author assumed that the action purged the audit logs themselves. However, the system architecture deliberately preserves `audit_logs` as append-only, and instead purges historical family telemetry (`location_events` and `usage_daily`).

```
========================================================================================
FINAL AUDIT CONCLUSION: OUTCOME B CONFIRMED
- Mapping of TC-EXP-47 to AUD03 is CORRECT.
- The test case description and expected result in the Phase 2 test suite contain an
  architectural mismatch with the production system.
- The production code correctly protects audit log immutability while purging telemetry.
- Recommendation P27.6-PROPOSAL-01 documents the required test case specification update.
========================================================================================
```
