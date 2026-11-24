# Phase 1.5: Policy State Model Reconciliation

**Document ID:** `HAVEN-AUD-007-PHASE1.5`  
**Phase:** Phase 1.5 — Independent Final Consistency & Security Closure Review  
**Workspace:** `D:\parentcontrol_app`  
**Baseline HEAD:** `0101c16d161824fd726018f1188e1a2b17c653d3`  
**Audit Standard:** Relational Schema & State Projection Architecture  

---

## 1. Executive Summary

This document authoritatively reconciles the policy state models across the HAVEN Parent Control platform. Previous planning documentation conflated persisted database lifecycle states, transport command states, runtime enforcement diagnostics, and policy versioning into an inconsistent single-enum representation. 

By inspecting the physical PostgreSQL schema (`supabase/migrations/20260101000000_core.sql`), Edge Functions, and client controllers, this assessment decouples the architecture into four distinct, non-overlapping operational layers.

---

## 2. Root Cause Analysis: The Conflation of "Active" vs "Enforced"

In earlier planning documents (Phases 1.1, 1.2, and 1.4), documentation repeatedly referred to policy states as `'active'`. 
Direct inspection of `supabase/migrations/20260101000000_core.sql` reveals that:
1. `'active'` exists **ONLY** in table `devices.status` (along with `'revoked'` and `'pending'`). It represents device enrollment lifecycle.
2. In table `device_policies`, the column is named `enforcement_status`, and its allowed values are strictly:
   ```sql
   check (enforcement_status in ('pending', 'enforced', 'failed', 'unsupported'))
   ```
3. Forcing `'active'` into the policy enforcement domain created confusion in client presentation code (`HAVEN-QA-006`), leading to inconsistent status labels between the Dashboard and Devices tabs.

---

## 3. Four-Layer Decoupled Policy Model

```
+--------------------------------------------------------------------------------------------------+
|                                  FOUR-LAYER DECOUPLED ARCHITECTURE                               |
|                                                                                                  |
|  [ LAYER 1: DEVICE LIFECYCLE ] (Table: devices.status)                                           |
|  Allowed Values: 'active' | 'revoked' | 'pending'                                                |
|  Scope: Device enrollment, family membership, administrative pairing                             |
|                                                                                                  |
|  [ LAYER 2: POLICY ENFORCEMENT DIAGNOSTIC ] (Table: device_policies.enforcement_status)           |
|  Allowed Values: 'pending' | 'enforced' | 'failed' | 'unsupported'                               |
|  Scope: Result of applying a specific policy version on the child handset                         |
|                                                                                                  |
|  [ LAYER 3: COMMAND TRANSPORT LIFECYCLE ] (Table: device_commands.status)                        |
|  Allowed Values: 'pending' | 'delivered' | 'succeeded' | 'failed' | 'expired'                    |
|  Scope: Wire delivery of the policy payload from server to handset                               |
|                                                                                                  |
|  [ LAYER 4: VERSION ACKNOWLEDGMENT TRIAD ]                                                       |
|  1. Desired Version: Max(version) in device_policies                                             |
|  2. Reported Version: devices.policy_version (reported by telemetry)                             |
|  3. Acknowledged Version: Version where acknowledged_at is NOT NULL and status = 'enforced'      |
+--------------------------------------------------------------------------------------------------+
```

---

## 4. Comprehensive Canonical State Specification Table

The table below defines every policy-related state across the four operational layers:

| State Name | Operational Layer | Storage Mechanism | Database Table & Field | Architectural Meaning | Allowed Transitions | Transition Owner | Source Evidence Ref |
|---|---|---|---|---|---|---|---|
| **`pending`** | Device Lifecycle | Persisted DB | `devices.status` | Device pairing token generated; waiting for child handset initial handshake. | $\to$ `active`<br/>$\to$ `revoked` | Parent / Child Handshake | `core.sql:91-92` |
| **`active`** | Device Lifecycle | Persisted DB | `devices.status` | Device successfully paired and authorized to send telemetry and receive commands. | $\to$ `revoked` | Parent Admin / Unlink | `core.sql:91-92` |
| **`revoked`** | Device Lifecycle | Persisted DB | `devices.status` | Device unlinked by parent or replaced; all commands and telemetry rejected. | *Terminal* | Parent Admin / Recovery | `core.sql:91-92` |
| **`pending`** | Policy Enforcement | Persisted DB | `device_policies.enforcement_status` | Policy version created by parent; not yet acknowledged or applied by handset. | $\to$ `enforced`<br/>$\to$ `failed`<br/>$\to$ `unsupported` | Edge Function / Device Sync | `core.sql:185-186` |
| **`enforced`** | Policy Enforcement | Persisted DB | `device_policies.enforcement_status` | Handset native policy engine successfully applied all restrictions. | *Terminal for this version* | Child Daemon (`PolicyApplier.kt`) | `core.sql:185-186` |
| **`failed`** | Policy Enforcement | Persisted DB | `device_policies.enforcement_status` | Handset failed to apply policy rules (e.g., Knox/Admin error; `last_error` populated). | $\to$ `enforced` (on retry)<br/>$\to$ `failed` | Child Daemon (`PolicyApplier.kt`) | `core.sql:185-186` |
| **`unsupported`** | Policy Enforcement | Persisted DB | `device_policies.enforcement_status` | Handset OS or device admin tier lacks capability for specified restriction. | *Terminal for this version* | Child Daemon (`PolicyApplier.kt`) | `core.sql:185-186` |
| **`pending`** | Command Transport | Persisted DB | `device_commands.status` | Command created in queue; waiting for device poll. | $\to$ `delivered`<br/>$\to$ `expired` | Edge Function | `core.sql:205-206` |
| **`delivered`** | Command Transport | Persisted DB | `device_commands.status` | Handset polled and downloaded command payload. | $\to$ `succeeded`<br/>$\to$ `failed` | Child Daemon Poll | `core.sql:205-206` |
| **`succeeded`** | Command Transport | Persisted DB | `device_commands.status` | Handset executed command and returned positive ACK. | *Terminal* | Child Daemon ACK | `core.sql:205-206` |
| **`failed`** | Command Transport | Persisted DB | `device_commands.status` | Handset reported execution error. | *Terminal* | Child Daemon ACK | `core.sql:205-206` |
| **`expired`** | Command Transport | Persisted DB | `device_commands.status` | Command TTL expired before device polled. | *Terminal* | Background Cleanup Cron | `core.sql:205-206` |

---

## 5. Policy Version Acknowledgment & Presentation Matrix

To permanently resolve `HAVEN-QA-006` (DEF-603), the Parent Dashboard and Devices tabs must evaluate the version acknowledgment triad synchronously:

```
Version Delta Calculation:
Delta = Desired_Version - Reported_Version
```

| Desired vs Reported Version | Policy Enforcement Status | Sync Health Indicator | User-Facing UI Badge (Dashboard) | User-Facing UI Badge (Devices Tab) | Semantic Meaning |
|---|---|---|---|---|---|
| `Desired == Reported` | `enforced` | Healthy (Heartbeat < 5m) | **"Active Protection"** (Green) | **"Policy Enforced (v{N})"** (Green) | Handset is fully synchronized and enforcing latest policy rules. |
| `Desired == Reported` | `enforced` | Stale (Heartbeat > 5m) | **"Sync Delayed"** (Amber) | **"Enforced (Offline)"** (Amber) | Policy is applied locally, but device telemetry has stalled. |
| `Desired > Reported` | `pending` | Any | **"Updating Rules..."** (Blue) | **"Sync Pending (v{N-1} -> v{N})"** (Blue) | New policy created; command in flight or pending handset poll. |
| `Desired == Reported` | `failed` | Any | **"Enforcement Failed"** (Red) | **"Error: {last_error}"** (Red) | Handset rejected policy; parent intervention required. |
| `Desired == Reported` | `unsupported`| Any | **"Feature Unsupported"** (Amber) | **"Hardware Incompatible"** (Amber) | Restriction not supported on this Android OS version. |
| Any | Any | Revoked (`devices.status`) | **"Disabled"** (Neutral) | **"Device Revoked"** (Neutral) | Device unlinked; policy no longer active. |

---

## 6. Conclusion & Implementation Boundaries

1. **Zero Database Changes**: The existing PostgreSQL schema in `core.sql` already provides the exact tables and columns required. Zero DDL migrations are needed for policy states.
2. **Client Presentation Scope (Wave 2)**: Remediation for `HAVEN-QA-006` is strictly constrained to the presentation layer in Flutter (`lib/features/devices/device_presentation.dart`).
3. **No Mixed Enums**: The client code must never combine device lifecycle (`active`) and policy enforcement (`enforced`) into a single enum.
