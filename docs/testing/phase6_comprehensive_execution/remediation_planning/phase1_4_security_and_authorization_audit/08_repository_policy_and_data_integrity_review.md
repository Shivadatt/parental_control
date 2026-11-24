# 08 — Repository Query Architecture, Ternary Domain Invariants & Policy Presentation Lifecycle

**Document ID:** `HAVEN-AUD-008-PHASE1.4`  
**Phase:** Phase 1.4 — Independent Security Clarification, Protocol Verification & Final Owner Approval Readiness  
**Date:** 2026-11-24  
**Target Workstream:** WORKSTREAM C4, C5 (Device Repository Contracts & Policy Synchronization Semantics)  
**Target Defects:** HAVEN-QA-005 (Duplicate Revoked Device Cards), HAVEN-QA-006 (Policy Version Inconsistency Across Parent Screens)  
**Target Findings:** REV-006, REV-007, REV-012  
**Workspace:** `D:\parentcontrol_app`  
**Current HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  

---

## 1. Executive Summary

This report establishes the verified relational database check constraints, repository query methods, and policy enforcement lifecycle states governing `Wave 2`.

---

## 2. REV-006 & REV-012: Device Repository Query & Clean Contracts (`QA-005`)

### 2.1 The Ternary Domain Invariant
In `supabase/migrations/20260101000000_core.sql:91-92`:
```sql
status text not null default 'pending'
  check (status in ('pending', 'active', 'revoked'))
```
The relational database enforces a strict ternary lifecycle:
- **`pending`**: Device pairing token redeemed or enrollment handshake initiated, but initial device registration is incomplete. Unlimited pending rows allowed per child.
- **`active`**: Fully enrolled and actively monitored hardware. Exactly one active device allowed per child enforced by unique partial index `devices_one_active_per_child` (`core.sql:117-119`).
- **`revoked`**: Retired or unlinked device row preserved for historical audit retention. `secret_hash` must be strictly NULL (`core.sql:112-114`).
- **`NULL` / Unknown string**: Strictly rejected by database check constraints.

### 2.2 Flaw in `.neq('status', 'revoked')` & Ghost Device Rows
Filtering `.neq('status', 'revoked')` returns both `active` AND `pending` devices. Abandoned pairing attempts leave `pending` device rows in the database. Under `.neq('status', 'revoked')`, a child with 3 abandoned setups renders 4 device cards (1 active + 3 ghost pending cards) on the Parent Dashboard!

### 2.3 Corrected Repository Method Contracts (`repository_contracts.dart`)
Replacing the boolean flag parameter (`includeRevoked = false`, anti-pattern `REV-012`) with explicit domain methods:
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
- **Child Symmetry**: Child query `fetchMyDevice()` in `supabase_device_repository.dart:59-69` already filters strictly on `.eq('status', 'active')`. Aligning Parent queries with `.eq('status', 'active')` establishes 100% projection symmetry.

---

## 3. REV-007: Policy Lifecycle & Presentation Semantics (`QA-006`)

### 3.1 Canonical Status is Strictly `'enforced'` (NOT `'active'`)
The audit verified the exact string literals enforced across the stack:
- **Database Check Constraint** (`core.sql:186`):
  ```sql
  check (enforcement_status in ('pending', 'enforced', 'failed', 'unsupported'))
  ```
- **Edge Function Definition** (`supabase/functions/device-command/enforcement.ts:18`):
  ```typescript
  export type EnforcementStatus = "pending" | "enforced" | "failed" | "unsupported";
  ```
- **Dart Domain Model Enum** (`lib/data/models/device.dart:223-228`):
  ```dart
  enum PolicyEnforcementStatus { pending, enforced, failed, unsupported }
  ```
- **Auditor Resolution**: Phase 1.2 mistakenly used `'active'`. The presentation helper in `device_presentation.dart` must evaluate against `'enforced'`.

### 3.2 The Seven Distinct Lifecycle Concepts
1. **Desired Policy Version**: Target version committed to `device_policies.version` by parent.
2. **Downloaded Policy Version**: Staged in memory by child `GuardianService` poller.
3. **Persisted Policy Version**: Written to encrypted local SQLite/Room database.
4. **Acknowledged Policy Version**: Acknowledged to backend via HTTPS ack (`device_policies.acknowledged_at != null`).
5. **Successfully Enforced Policy Version**: Confirmed enforced by Android Device Owner APIs (`device_policies.enforcement_status == 'enforced'`).
6. **Device Connectivity**: Real-time heartbeat presence (`device.syncHealth` evaluated against `last_seen_at`).
7. **Last Synchronization Timestamp**: Wall-clock timestamp of most recent bidirectional handshake.

### 3.3 Truthful Policy Display Presentation Matrix

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                     CANONICAL POLICY DISPLAY STATUS TABLE                         │
├───────────────────┬───────────────────┬──────────────┬────────────────────────────┤
│ Policy Status     │ Connectivity      │ Status Tone  │ Rendered UI Copy           │
├───────────────────┼───────────────────┼──────────────┼────────────────────────────┤
│ 'enforced'        │ Online / Healthy  │ Success      │ "Policy v4 · Enforced"     │
│ 'enforced'        │ Offline           │ Warning      │ "Policy v4 · Enforced (Offline)" │
│ 'pending'         │ Online / Healthy  │ Info         │ "Policy v2 · Applying v4..."│
│ 'pending'         │ Offline           │ Warning      │ "Policy v2 · Update to v4 pending reconnection" │
│ 'failed'          │ Any               │ Danger       │ "Policy v2 · Update failed (v4)" (Tooltip: lastError) │
│ 'unsupported'     │ Any               │ Warning      │ "Policy v2 · Advisory only (Unmanaged)" │
│ desired == null   │ Any               │ Neutral      │ "No policy configured"     │
└───────────────────┴───────────────────┴──────────────┴────────────────────────────┘
```

**Workstream C4 & C5 Official Status:** **STATICALLY VERIFIED / CLOSED WITH CONDITIONS**. Ready for immediate owner approval in Wave 2.
