# 05 — In-Depth Audit of REV-006 & REV-007: Device Repository Filtering & Policy Presentation Lifecycle

**Document ID:** HAVEN-AUD-005  
**Target Defects:** HAVEN-QA-005 (Duplicate Revoked Device Cards), HAVEN-QA-006 (Policy Version Inconsistency Across Parent Screens)  
**Target Findings:** REV-006 (MEDIUM — Pending Device Leakage & Repository Filtering), REV-007 (MEDIUM — Policy Presentation Semantics & Sync Model)  
**Phase:** Phase 1.3 — Independent Closure Verification & Owner Approval Readiness Audit (Strictly Read-Only)  
**Date:** 2026-11-24  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  

---

## 1. Executive Summary

This audit evaluates the data access contracts, domain invariants, and presentation semantics governing `Wave 2`. It verifies the elimination of duplicate device cards on Parent screens (`HAVEN-QA-005`) and the harmonization of policy version strings (`HAVEN-QA-006`).

During source verification, the audit uncovered a **critical documentation discrepancy** in Phase 1.2 report `07_rev006_rev007_repository_and_policy_correction.md`: the report referred to `enforcement_status` as `'active'`, whereas the database check constraint and Dart enum strictly require `'enforced'`.

---

## 2. Section 11: In-Depth Audit of REV-006 & REV-012 (Device Repository Architecture)

### Answers to the 10 Mandatory Audit Questions:

#### 1. What are the database check constraints on `devices.status`?
**Citation:** `supabase/migrations/20260101000000_core.sql:91-92`
```sql
status text not null default 'pending'
  check (status in ('pending', 'active', 'revoked'))
```
Additional relational constraints:
- `core.sql:112-114`: `constraint devices_revoked_credential_consistency check (status <> 'revoked' or secret_hash is null)`
- `core.sql:117-119`: `create unique index devices_one_active_per_child on public.devices (child_user_id) where status = 'active';`

#### 2. What are the exact domain semantics of each status? Can `status` ever be `NULL` or unknown?
- **`pending`**: Device pairing token redeemed or enrollment handshake initiated, but initial device registration is incomplete.
- **`active`**: Fully enrolled and actively monitored hardware. Exactly one active device allowed per child (`devices_one_active_per_child`).
- **`revoked`**: Retired or unlinked device row preserved strictly for historical audit retention. `secret_hash` is strictly NULL.
- **`NULL` / Unknown string**: **STRICTLY IMPOSSIBLE**. The database schema enforces `not null` and a restricted `check (status in ('pending', 'active', 'revoked'))`. Any invalid status is rejected at the PostgreSQL storage engine level with error code `23514 (check_violation)`.

#### 3. What was the original defect in `fetchDevices()`?
**Citation:** `lib/data/repositories/supabase_device_repository.dart:31-40`
```dart
@override
Future<List<Device>> fetchDevices(String familyId) => _guard(() async {
      final rows = await _supabase.client
          .from('devices')
          .select(_deviceColumns)
          .eq('family_id', familyId)
          .order('created_at', ascending: true);
      return rows
          .map((row) => Device.fromJson(jsonMap(row)))
          .toList(growable: false);
    });
```
The query had zero status filtering. It indiscriminately returned all `pending`, `active`, and `revoked` device rows.

#### 4. Why was the original Phase 1 remediation proposal (`.neq('status', 'revoked')`) flawed?
Filtering `.neq('status', 'revoked')` returns both `active` AND `pending` devices. It failed to recognize that the domain model is ternary (`pending`, `active`, `revoked`), not binary.

#### 5. How does abandoned device enrollment lead to ghost pending device rows?
When a parent creates a pairing token and a child scans it, a device row is created in `status = 'pending'`. If the child closes the app, loses network, or cancels setup, the row sits in `devices` as `pending`. While `devices_one_active_per_child` allows only 1 active device per child, unlimited `pending` rows are permitted. Under `.neq('status', 'revoked')`, a child with 3 abandoned setups would render 4 device cards (1 active + 3 ghost pending cards) on the Parent Dashboard!

#### 6. How does `fetchActiveDevices()` querying `.eq('status', 'active')` align with `fetchMyDevice()`?
**Citation:** `lib/data/repositories/supabase_device_repository.dart:59-69`
```dart
@override
Future<Device?> fetchMyDevice() => _guard(() async {
      final userId = _supabase.currentUser?.id;
      if (userId == null || userId.isEmpty) return null;
      final row = await _supabase.client
          .from('devices')
          .select(_deviceColumns)
          .eq('child_user_id', userId)
          .eq('status', 'active')
          .maybeSingle();
      return row == null ? null : Device.fromJson(row);
    });
```
The Child device's own query (`fetchMyDevice()`) has **always** filtered strictly on `.eq('status', 'active')`. Aligning Parent queries with `.eq('status', 'active')` establishes architectural symmetry between Parent and Child projections.

#### 7. What is the impact of duplicate/pending rows on the Parent Dashboard, and how does `.eq('status', 'active')` prevent duplicate cards?
Duplicate and pending rows cause `DashboardController` and `DevicesController` to instantiate multiple card widgets for a single child, cluttering the UI with degraded cards (pending rows have null telemetry). Filtering strictly by `.eq('status', 'active')` guarantees that exactly one active device card is returned per enrolled child.

#### 8. What is finding REV-012? Why is passing a boolean flag (`includeRevoked = false`) an anti-pattern?
**Citation:** `09_rev010_rev011_rev012_rev013_remaining_findings.md:55-68`
Passing boolean flags (flag arguments) into repository methods couples multiple distinct query requirements into a single method with conditional internal branching (`if (includeRevoked) ... else ...`). It harms readability (`fetchDevices(familyId, false)` conveys no semantic meaning) and violates Martin Fowler's Clean Code principle.

#### 9. How does replacing `includeRevoked` with explicit methods satisfy clean repository architecture?
Providing distinct methods (`fetchActiveDevices()`, `fetchDeviceHistory()`, `fetchPendingDevices()`):
- **Single Responsibility**: Each method executes one type of query for a specific consumer.
- **Type Safety**: Prevents accidental leakage of historical rows into real-time monitoring streams.
- **Self-Documenting**: Callers express their architectural intent clearly.

#### 10. What are the method signatures and consumer mappings?
**Specification in `lib/data/repositories/repository_contracts.dart`:**
```dart
abstract class DeviceRepository {
  /// Fetches currently active, enrolled devices for the family.
  /// Consumed by: DashboardController, DevicesController (Active Tab).
  /// Query: .eq('family_id', familyId).eq('status', 'active').order('created_at', ascending: true)
  Future<List<Device>> fetchActiveDevices(String familyId);

  /// Fetches all historical and revoked device records for audit retention.
  /// Consumed by: Historical audit log viewers, Archived Devices accordion.
  /// Query: .eq('family_id', familyId).order('created_at', ascending: false)
  Future<List<Device>> fetchDeviceHistory(String familyId);

  /// Fetches pending enrollment rows awaiting initial handshake.
  /// Consumed by: Pairing/Enrollment management workflows.
  /// Query: .eq('family_id', familyId).eq('status', 'pending').order('created_at', ascending: true)
  Future<List<Device>> fetchPendingDevices(String familyId);
}
```

**REV-006 & REV-012 Official Status:** **VERIFIED CLOSED BY DESIGN**

---

## 3. Section 12: In-Depth Audit of REV-007 (Policy Presentation & Lifecycle)

### 3.1 Rigorous Separation of the 7 Lifecycle Concepts
The audit verifies that HAVEN separates 7 distinct lifecycle dimensions:
1. **Desired Version ($V_{desired}$)**: Version authored by parent, stored in `device_policies.version`.
2. **Downloaded Version ($V_{downloaded}$)**: Payload received by child over network via `apply_policy` command.
3. **Persisted Version ($V_{persisted}$)**: Stored in child encrypted SQLite/Room database.
4. **Acknowledged Version ($V_{acked}$)**: Confirmed by child HTTPS ack, recorded in `device_policies.acknowledged_at`.
5. **Enforced Version ($V_{enforced}$)**: Applied via Android Device Owner APIs, stored in `devices.policy_version`.
6. **Connectivity State**: Hardware reachability (`healthy`, `stalled`, `offline`) evaluated against `device.last_seen_at`.
7. **Last Sync Timestamp**: Timestamp of most recent telemetry handshake recorded in `devices.last_seen_at`.

### 3.2 ⚠️ CRITICAL ADVERSARIAL DISCREPANCY DISCOVERY: `'active'` vs `'enforced'`
In Phase 1.2 report `07_rev006_rev007_repository_and_policy_correction.md:88` and Table 3.4 (line 121), the author wrote:
> `active: Policy downloaded, parsed, persisted, and confirmed enforced...`
> `CheckStatus -- "active && applied == desired"`

**Source Code & Database Truth:**
1. Database Check Constraint (`supabase/migrations/20260101000000_core.sql:186`):
   ```sql
   enforcement_status text not null default 'pending'
     check (enforcement_status in ('pending', 'enforced', 'failed', 'unsupported'))
   ```
2. Edge Function Definition (`supabase/functions/device-command/enforcement.ts:18`):
   ```typescript
   export type EnforcementStatus = "pending" | "enforced" | "failed" | "unsupported";
   ```
3. Dart Model Enum (`lib/data/models/device.dart:223-240`):
   ```dart
   enum PolicyEnforcementStatus { pending, enforced, failed, unsupported }
   ```
**Auditor Finding**: The report mistakenly used `'active'` instead of `'enforced'`. If an engineer implemented code matching against `'active'`, the condition would never match, causing enforced policies to render incorrectly.

### 3.3 Canonical Policy Display Table (Corrected with `'enforced'`)

| Applied Version | Desired Version | `policy.status` | Device Connectivity | Truthful Rendered String | Status Tone |
|---|---|---|---|---|---|
| `null` / `0` | `null` | N/A | Any | `"No policy configured"` | `neutral` |
| `null` / `0` | `4` | `pending` | Healthy | `"Policy v4 · Initial sync in progress..."` | `info` |
| `null` / `0` | `4` | `pending` | Offline | `"Policy v4 · Initial sync pending reconnection"` | `warning` |
| `4` | `4` | **`enforced`** | Any | `"Policy v4 · Enforced"` | `success` |
| `2` | `4` | `pending` | Healthy | `"Policy v2 · Applying v4..."` | `info` |
| `2` | `4` | `pending` | Offline | `"Policy v2 · Update to v4 pending reconnection"` | `warning` |
| `2` | `4` | `failed` | Any | `"Policy v2 · Update failed (v4)"` | `danger` |
| `2` | `4` | `unsupported` | Any | `"Policy v2 · Advisory only (Device unmanaged)"` | `warning` |

**REV-007 Official Status:** **CLOSED WITH CONDITIONS**  
*Condition:* Rectify report `07_rev006...` to reference canonical status `'enforced'` before implementing `device_presentation.dart`.
