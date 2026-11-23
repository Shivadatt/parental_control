# 05 — Partial, UI-only, and Backend-only Test Plan

All cases are **NOT TESTED**; actual results are **NOT EXECUTED**.

## 1. Partially implemented functionalities (7)

Each item gets a positive supported-behavior case and a limitation case. Known limitations are not new runtime failures unless valid evidence demonstrates them.

| ID | Functionality | Positive case | Limitation case | Known limitation | Confirming evidence | Dependency | Approval gate |
|---|---|---|---|---|---|---|---|
| MON04 | Heartbeat online/offline status | P6-INT-001 | P6-LIM-001 | Reinstall credential mismatch causes 401 and stale/Offline | Both screenshots; heartbeat time; redacted 401 log | Both devices; backend; credential | Reinstall/rotation: BLOCKED — REQUIRES SEPARATE OWNER APPROVAL |
| MON05 | Child permission summary | P6-INT-002 | P6-LIM-002 | Notification can report granted while OS permission is absent | Parent/child screenshots; system dump | Child; Android | None for read-only |
| USE04 | Child usage upload | P6-CHD-005 | P6-LIM-003 | Uploader can fail after credential lifecycle break | Both screenshots; last upload; logs | Child; backend; credential | None; no reset |
| USE06 | Bedtime configuration/state | P6-PAR-018 | P6-LIM-004 | Bedtime is informational; does not suspend apps | Policy state; both screenshots; app launchability | Both devices; policy | Any change: BLOCKED — EXPLICIT OWNER APPROVAL REQUIRED |
| USE08 | OS daily-limit enforcement | P6-CHD-006 | P6-LIM-005 | Requires Device Owner; otherwise advisory | Enforcement mode; quota state | Child; Device Owner | If absent: BLOCKED — DEPENDENCY NOT VERIFIED |
| APP07 | OS app suspension | P6-CHD-007 | P6-LIM-006 | Requires Device Owner | Enforcement mode; suspended state | Child; Device Owner | If absent: BLOCKED — DEPENDENCY NOT VERIFIED |
| LOC04 | Child location upload | P6-CHD-009 | P6-LIM-007 | Upload depends on valid device credential | Service state; last upload; logs | Child; backend; credential | None; no reset |

## 2. UI-only functionalities (2)

| ID | Functionality | UI visible | Can change | Persists | Real notification/reminder | Case | Status | Risk |
|---|---|---|---|---|---|---|---|---|
| SET01 | Local notification preference | Yes | Yes | Yes, local storage | No scheduler or delivery consumer found | P6-UI-001 | NOT TESTED | Medium |
| SET02 | Location-sharing reminder preference | Yes | Yes | Yes, local storage | No reminder consumer found | P6-UI-002 | NOT TESTED | Medium |

A successful toggle and persistence check is **not** proof of notification delivery. Cleanup must restore the original toggle.

## 3. Backend-only functionalities (2)

| ID | Functionality | Existing implementation | Safe verification | Write/deletion status | Case | Status |
|---|---|---|---|---|---|---|
| FAM14 | Update family settings API | `FamilyRepository.updateSettings` plus Supabase implementation | Confirm contract/implementation and absence of UI call sites; read-only route inventory | Do not invoke API or change settings | P6-BEK-001 | NOT TESTED |
| AUD04 | Scheduled retention sweep | Retention SQL/cron/Edge schedule | Inspect schedule definition and existing redacted run logs | Do not trigger sweep or delete data | P6-BEK-002 | NOT TESTED |

Both require separately authorized backend testing if a safe read-only path is unavailable. Static existence is not runtime PASS.

## 4. Count reconciliation

| Bucket | Count |
|---|---:|
| Partial functionality items | 7 |
| UI-only functionality items | 2 |
| Backend-only functionality items | 2 |
| Primary functionality items | 11 |
| Partial positive cases | 7 |
| Partial limitation cases | 7 |
| UI-only cases | 2 |
| Backend-only cases | 2 |
| Referenced test cases | 18 (7 positive + 7 limitation + 2 UI + 2 backend) |

These are counts of functionality items and referenced test cases, not unique functionality IDs across the 80-item inventory.
