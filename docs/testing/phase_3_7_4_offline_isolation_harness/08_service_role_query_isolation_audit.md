# Phase 3.7.4 — Report 08: Service-Role Query Isolation Architecture Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Target Function:** `account` Edge Function (`supabase/functions/account/deletion.ts`)  
**Execution Mode:** SOURCE AUDIT & ARCHITECTURAL VERIFICATION  
**Audit Date:** 2026-11-20  

---

## 1. Executive Summary

Because Edge Functions run server-side using the Supabase `service_role` key, database requests execute with administrative privileges that **bypass PostgreSQL Row-Level Security (RLS)**. Multi-tenant security therefore depends entirely on the application-level query construction in TypeScript.

This report audits the query construction in `deletion.ts` and `retention.ts`, verifying that foreign tenant data cannot be queried or exposed even when RLS is bypassed.

---

## 2. Source-Level Query Construction Audit

### 2.1 Identity Binding (`requireUser`)
In `deletion.ts:623`:
```typescript
case "export": {
  const auth = await requireUser(req, db);
  return exportResponse(await exportAccount(db, auth));
}
```
- `requireUser` verifies the caller's JWT against Supabase GoTrue Auth via `db.auth.getUser(token)`.
- The caller's identity `userId` is obtained strictly from the verified JWT `sub` (`auth.user.id`).
- Client-controlled headers, query parameters, and body fields are not used to establish identity.

### 2.2 Scope Discovery (`loadActiveMemberships`)
In `deletion.ts:217`:
```typescript
const memberships = await loadActiveMemberships(db, userId);
const familyIds = memberships.map((m) => m.family_id);
```
In `loadActiveMemberships`:
```typescript
const result = await db
  .from("family_members")
  .select("id, family_id, user_id, role, status")
  .eq("user_id", userId)
  .eq("status", "active");
```
- A user can only obtain `familyIds` for families where they have an active row in `family_members`.
- Inactive, suspended, or left memberships are excluded at the database query level.

### 2.3 Table Query Scoping (`scopeRows`)
In `deletion.ts:245-254`:
```typescript
const scopeRows = (query: AnyQuery): AnyQuery => {
  if (!familyScoped) {
    return childDeviceIds.length === 0
      ? query.eq("device_id", NO_MATCH_UUID)
      : query.in("device_id", childDeviceIds);
  }
  return familyIds.length === 0
    ? query.eq("family_id", NO_MATCH_UUID)
    : query.in("family_id", familyIds);
};
```
- For parent callers: every table query (`location_events`, `usage_daily`, `safety_alerts`, `audit_logs`) is filtered by `.in("family_id", familyIds)`.
- If `familyIds` is empty, the filter degrades to `.eq("family_id", "00000000-0000-0000-0000-000000000000")`, matching zero rows.
- For child callers: every telemetry query is filtered by `.in("device_id", childDeviceIds)`.

### 2.4 Child Audit Log Partitioning
In `deletion.ts:269-274`:
```typescript
return childDeviceIds.length === 0
  ? query.eq("actor_user_id", userId)
  : query.or(`actor_user_id.eq.${userId},device_id.in.(${childDeviceIds.join(",")})`);
```
- When a child requests an export, they never receive family-wide audit logs.
- They only receive audit events where they were the direct actor (`actor_user_id = userId`) or where the event occurred on their assigned device (`device_id in childDeviceIds`).

---

## 3. Threat Model Evaluation

| Threat Vector | Mechanism in Source | Protection Level |
|---|---|:---:|
| **Body Parameter Tampering** | Body `family_id` is never passed to `exportAccount` or `retentionReport` | **IMMUNE** |
| **Empty Scope Sweep** | `NO_MATCH_UUID` fail-closed fallback prevents unconstrained SQL | **IMMUNE** |
| **Role Escalation in Export** | Role verified from `profiles` row; scope determined by `resolveRetentionScope` | **IMMUNE** |
| **Foreign Audit Exposure** | Audit queries explicitly filter by caller's `family_id` or child's `device_id` | **IMMUNE** |

$$\mathbf{Conclusion} = \mathbf{APPLICATION-LEVEL\ SERVICE-ROLE\ QUERY\ ISOLATION\ IS\ ROBUST}$$
