# Phase 3.5 — Report 06: Retention Architecture & Scope Isolation Audit

**Project:** Parent Control App  
**Workspace:** `D:\parentcontrol_app`  
**Supabase Project:** `parent-control-prod` (`hhqgreaoqulmfwfwarhc`)  
**Target Module:** `docs/testing/phase_3_4_3_browser_package/staging/account/retention.ts`  
**Audit Date:** 2026-11-20  

---

## 1. Retention Policies & Window Calculation

The retention subsystem in `account` allows families to review their automated data lifecycle parameters.

### Standard Retention Constants
- `DEFAULT_LOCATION_RETENTION_DAYS = 30` (Location breadcrumbs retained for 30 days)
- `DEFAULT_USAGE_RETENTION_DAYS = 90` (Application usage aggregates retained for 90 days)
- `SWEEP_DEFAULT_DAYS.webrtc_signals_days = 7` (WebRTC signaling records retained for 7 days)
- `SWEEP_DEFAULT_DAYS.audit_logs_days = 365` (Compliance audit trail retained for 365 days)
- `MAX_RETENTION_DAYS = 3650` (Defensive upper bound cap of 10 years)

### Defensive Parsing (`parseRetentionDays`)
- Accepts either positive integers or numeric strings (e.g. `30` or `"30"`).
- Invalid values (negative numbers, floats, null, malformed strings) automatically fall back to the schema defaults.
- Values are clamped to `[1, MAX_RETENTION_DAYS]`, ensuring a corrupted settings row can never specify `0` days (which would trigger accidental mass deletion) or negative values.

---

## 2. Three-State Scope Isolation Architecture (PRIV-01)

To protect children's privacy and enforce multi-tenant family boundaries, `retention.ts` implements a three-state deterministic scope resolver (`resolveRetentionScope`).

```
                    ┌────────────────────────────┐
                    │ resolveRetentionScope()    │
                    └─────────────┬──────────────┘
                                  │
         ┌────────────────────────┼────────────────────────┐
         ▼                        ▼                        ▼
  role = 'parent'          role = 'child'             Unresolved /
  & active member          & active member             Mismatched
         │                        │                        │
  ┌──────┴──────┐                 │                        │
  ▼             ▼                 │                        │
Owner        Member               │                        │
  │             │                 │                        │
  ▼             ▼                 ▼                        ▼
"family"     "family"          "device"             "not_reported"
(All counts, (All counts,     (Only own devices,    (Zero counts,
 + sweep)     no sweep)        no sweep)             no queries)
```

### Scope Capabilities Matrix

| Caller Identity & Context | Assigned Scope | Location & Usage Counts | Sweep Marker Access | Rationale |
|---|---|---|---|---|
| **Parent (Family Owner)** | `"family"` | Family-wide aggregates | **Included** (`last_sweep` metadata) | The family owner administers retention and must see system sweep metrics. |
| **Parent (Member)** | `"family"` | Family-wide aggregates | **Redacted** (`last_sweep = null`) | Standard parents monitor family telemetry but do not manage project-wide sweep state. |
| **Child (Member)** | `"device"` | Scoped strictly to caller's own paired devices | **Redacted** (`last_sweep = null`, `last_sweep_at = null`) | A minor child may only inspect data concerning their own personal device. |
| **Unknown / Misaligned** | `"not_reported"` | Zero counts | **Redacted** | Prevents data leakage when profile role disagrees with membership table. |

---

## 3. Query Construction & Empty Filter Protection

To guarantee that count queries never accidentally perform unindexed full-table scans or throw SQL syntax errors, `retentionCountFilter` constructs explicit filter definitions:

```ts
export interface RetentionCountFilter {
  run: boolean;
  family_id: string;
  device_ids: readonly string[] | null;
}
```

- When `scope === "not_reported"`: `run = false`, preventing any query from reaching Postgres.
- When `scope === "device"`:
  - If the child has active devices: queries filter with `WHERE family_id = ... AND device_id IN (...)`.
  - If the child has zero devices: `run = false`, short-circuiting immediately without issuing an invalid `IN ()` clause.
- When `scope === "family"`: `device_ids = null`, querying cleanly with `WHERE family_id = ...`.

---

## 4. Separation of Concerns: Audit vs Destruction

A cornerstone of the system's security architecture is the total separation between **retention reporting** and **retention purging**:

1. **`account` Function:** Read-only calculation of data eligible for future cleanup. Contains **zero delete queries** against `location_events` or `usage_daily`.
2. **`cron` Scheduled Job / Background SQL:** The actual execution of purges occurs through automated scheduled jobs utilizing `event_type = 'retention_sweep'`, isolated from public HTTP triggers.

This invariant guarantees that calling the `account` function can never lead to data loss.
