# 06 — Functionality Count Summary

Audit checkout: `80375f518139bf922bc1b66c998691bee912af44`  
Scope: Flutter app, Android Kotlin layer, Supabase migrations/RLS/Edge Functions, tests, routes, and supporting docs.  
Method: read-only inspection; no files changed, no devices driven, no backend calls made.

## 1. Primary counts

| Classification | Count |
|---|---:|
| **Total unique inventoried functionalities** | **80** |
| Implemented | 69 |
| Partially implemented | 7 |
| UI only | 2 |
| Backend only | 2 |
| Planned (explicitly planned in source) | 0 |
| Unverified | 0 |
| **Absent capabilities tracked separately** | **10** |

Reconciliation: 69 + 7 + 2 + 2 = 80. The 10 absent capabilities are not included in the 80 because there is no application feature to count; they are listed in `05_missing_and_incomplete_functionalities.md`.

## 2. Role and ownership counts

| Measure | Count | Definition |
|---|---:|---|
| Parent-only | 35 | Entry points and actions available only to the Parent role, excluding the two backend-only parent-role APIs |
| Child-only | 19 | Entry points and actions available only to the Child role |
| Shared | 14 | Same capability usable by either role (authentication, account, common settings, sync) |
| Parent–Child interconnected | 10 | Requires both devices/sides to produce the outcome |
| **Parent-mode total** | **59** | Parent-only 35 + Shared 14 + Interconnected 10 |
| **Child-mode total** | **43** | Child-only 19 + Shared 14 + Interconnected 10 |
| **Unique accessible functionalities** | **78** | 35 + 19 + 14 + 10 |
| Backend-only parent-role APIs | 2 | `FAM14`, `AUD04`; excluded from the 59 accessible parent-mode count |

No functionality is double-counted. Shared and interconnected items are counted once in the 80 total and appear in both role reports by design.

### Status by role view

| Role view | Implemented | Partial | UI only | Backend only | Total |
|---|---:|---:|---:|---:|---:|
| Parent-only accessible | 32 | 1 | 2 | 0 | 35 |
| Child-only | 15 | 4 | 0 | 0 | 19 |
| Shared | 14 | 0 | 0 | 0 | 14 |
| Interconnected | 8 | 2 | 0 | 0 | 10 |
| Backend-only | 0 | 0 | 0 | 2 | 2 |
| **All** | **69** | **7** | **2** | **2** | **80** |

Parent-mode status totals: 54 implemented, 3 partial, 2 UI only = 59.  
Child-mode status totals: 37 implemented, 6 partial = 43.

## 3. Category breakdown

| Category | Count |
|---|---:|
| Authentication | 6 |
| Account | 4 |
| Pairing | 6 |
| Device registration | 1 |
| Family | 4 |
| Device control | 2 |
| Family settings | 1 |
| Parent dashboard | 1 |
| Devices | 6 |
| Usage | 4 |
| Screen time | 4 |
| App blocking | 7 |
| Location | 5 |
| Alerts | 5 |
| Remote assistance | 5 |
| Audit | 4 |
| Settings | 3 |
| Permissions | 3 |
| Child | 7 |
| Synchronization | 2 |
| **Total** | **80** |

## 4. What the counts mean

- **69 implemented** items have real logic connected to UI and, where applicable, a backend path.
- **7 partial** items are `MON04`, `MON05`, `USE04`, `USE06`, `USE08`, `APP07`, `LOC04`. The most consequential is `MON04`: the device credential lifecycle breaks heartbeat, usage upload, and location upload after reinstall.
- **2 UI-only** items are the local-notification and location-reminder preferences; their switches are stored but unconsumed.
- **2 backend-only** items are the unused `FamilyRepository.updateSettings` API and the scheduled retention sweep.
- **10 absent capabilities** include website/content filtering, push notifications, password reset, Device Owner provisioning, and remote lock/wipe.

Important distinction: **IMPLEMENTED is an implementation classification, not a live PASS.** A feature can be fully wired and still fail at runtime due to credentials, Android policy, or backend state. Live Phase 6 evidence remains authoritative for runtime acceptance.

## 5. QA readiness

| Question | Assessment |
|---|---|
| Is there enough implemented functionality to begin structured QA? | **Yes.** 78 of 80 items are role-accessible and the core parent/child workflows are wired. |
| Is the app ready for release acceptance? | **No.** Device re-credentialing breaks heartbeat/usage/location; seven items are partial; two settings are non-functional; ten expected capabilities are absent. |
| Is the parent side usable? | **Yes, with gaps.** Authentication, family, device list, policies, usage, location, alerts, audit, and remote assistance are wired. |
| Is the child side usable? | **Partially.** Enrollment, rules, requests, guardian service, and permissions are wired; enforcement depth depends on Device Owner, and uploads depend on the broken credential. |
| What should be fixed before broad manual QA? | The device credential lifecycle (`MON04`), then the notification-permission false positive (`MON05`). |
| Recommended readiness label | **CONDITIONALLY READY FOR CONTROLLED QA — NOT RELEASE READY.** |

## 6. Reports

- `docs/testing/functionality_inventory/01_complete_functionality_inventory.md`
- `docs/testing/functionality_inventory/02_parent_mode_functionalities.md`
- `docs/testing/functionality_inventory/03_child_mode_functionalities.md`
- `docs/testing/functionality_inventory/04_shared_and_parent_child_functionalities.md`
- `docs/testing/functionality_inventory/05_missing_and_incomplete_functionalities.md`
- `docs/testing/functionality_inventory/06_functionality_count_summary.md`

## 7. Limitations

- This audit did not build, install, log in, or drive either device; runtime statuses were not re-verified here.
- `UNVERIFIED` is 0 because every inventoried item had enough static evidence to assign one of the other classifications. Platform-dependent runtime behaviour is called out under `PARTIAL`.
- “Absent” means no implementation was found in the inspected checkout; it does not prove the capability was never planned outside this repository.
