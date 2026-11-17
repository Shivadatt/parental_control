# PHASE 1.7 — DEVICE RECOVERY BACKUP & ROLLBACK READINESS AUDIT REPORT

**Audit Execution Timestamp:** 2026-11-17T12:15:00+05:30  
**Project Path:** `D:\parentcontrol_app`  
**Application ID:** `com.parentcontrol.parent_control` (Single dual-role Flutter APK)  
**Supabase Backend:** Hosted Project `hhqgreaoqulmfwfwarhc` (ap-northeast-2)  
**Execution Mode:** **STRICT READ-ONLY — NO RECOVERY ACTION EXECUTED**  

---

## 1. Compliance Statement & Prohibitions

In accordance with strict read-only audit instructions, the recovery flow was **NOT** triggered, and the user explicitly declined triggering device recovery at this stage.

### Verified Inactive Prohibitions:
- `recover_device` or `request_device_recovery` was **NOT** invoked.
- No device, family membership, or user was revoked, unlinked, deleted, or disabled.
- No pairing codes were generated, approved, redeemed, or reset.
- No device was registered or re-registered.
- `devices.secret_hash` was **NOT** modified or overwritten.
- Zero SQL mutations, DDL scripts, or database migrations were executed.
- No pending commands were deleted, modified, or transferred.
- Neither device was reset, cleared, or reinstalled.
- Source code, dependencies, Gradle build scripts, and Supabase configurations remained 100% untouched.

---

## 2. Backup Inventory & Database State Snapshot

Data was extracted via authenticated read-only PostgREST queries using the existing QA credentials. All credentials, tokens, raw secrets, and GPS locations are redacted.

### 2.1 Family & Tenancy Metadata

| Parameter | Value |
| :--- | :--- |
| **Family ID** | `4b97ad74-6032-48f4-a705-bef60f2c7a75` |
| **Family Name** | `demo` |
| **Family Owner ID** | `d8c7ee6a-6380-43bf-8205-ad448cfdc6e3` (Parent QA Account: `ankit@gmail.com`) |
| **Family Creation Date** | `2026-10-29T05:46:41.475949Z` |
| **Settings** | `usage_retention_days: 90`, `location_retention_days: 30` |

### 2.2 User & Membership State

| User / Role | Auth User UUID | Family Member UUID | Membership Status | Joined Timestamp |
| :--- | :--- | :--- | :--- | :--- |
| **Parent (Owner)** | `d8c7ee6a-6380-43bf-8205-ad448cfdc6e3` | `94600e48-d9c6-43b0-af3c-5ac8a986b52f` | `active` | `2026-10-29T05:46:41.475949Z` |
| **Child** | `a29448c5-23ee-461c-bdac-2f7daab4bbae` | `d5f4ad55-e7c0-4747-bb2e-735a1ab18def` | `active` | `2026-10-29T05:47:15.752813Z` |

Both family memberships are currently `active` and intact. No member has been removed or unlinked.

---

### 2.3 Device State Inventory

#### A. Active Child Device Record (Target of Investigation)
- **Device UUID:** `a7177c84-68d6-483e-8a5a-03865982b5e4`
- **Family ID:** `4b97ad74-6032-48f4-a705-bef60f2c7a75`
- **Child User ID:** `a29448c5-23ee-461c-bdac-2f7daab4bbae`
- **Display Name:** `realme RMX2161`
- **Platform:** `android` (OS 12 / API 31)
- **App Version:** `1.0.0`
- **Device Status:** `active`
- **Credential State:** `secret_hash` is **PRESENT / NON-NULL** (stored as SHA-256 digest on server; raw value redacted).
- **Credential Issued At:** `2026-11-13T07:28:20.657Z`
- **Credential Revoked At:** `null`
- **Last Seen Timestamp:** `2026-11-13T11:53:57.531Z`
- **Reported Policy Version:** `2`
- **Enforcement Mode:** `none` (Standard unmanaged mode, truthful reporting)
- **Battery & Charging:** `100%`, `is_charging: true`
- **Permission Grants Recorded:**
  - `usage_access_granted`: true
  - `location_granted`: true
  - `background_location_granted`: true
  - `camera_granted`: true
  - `microphone_granted`: true
  - `notifications_granted`: true
- **Record Created At:** `2026-11-13T07:28:21.305537Z`
- **Record Updated At:** `2026-11-13T11:53:57.64314Z`

#### B. Historical Revoked Device Record (Prior Pairing)
- **Device UUID:** `fd79ee34-c6fe-4abd-a3ae-39f9b16ed628`
- **Status:** `revoked`
- **Credential Issued At:** `2026-10-29T05:47:22.321Z`
- **Credential Revoked At:** `2026-11-13T07:22:42.063574Z`
- **Credential State:** `secret_hash` is `null` (enforced by `devices_revoked_credential_consistency` constraint).

---

### 2.4 Pending Command State Inventory

The `device_commands` table was inspected for all commands assigned to the active device UUID `a7177c84-68d6-483e-8a5a-03865982b5e4`.

#### Active Pending Command (Policy v4 — E-11 Bedtime-Only):
- **Command UUID:** `0b61ada9-1333-4b6c-95fb-37836864b736`
- **Target Device UUID:** `a7177c84-68d6-483e-8a5a-03865982b5e4`
- **Family ID:** `4b97ad74-6032-48f4-a705-bef60f2c7a75`
- **Command Type:** `apply_policy`
- **Policy Version:** `4`
- **Status:** `pending`
- **Creation Timestamp:** `2026-11-17T05:51:41.317287Z`
- **Expires At:** `2026-11-17T06:06:41.317287Z`
- **Delivered At:** `null`
- **Acknowledged At:** `null`
- **Attempts:** `0`
- **Created By:** `d8c7ee6a-6380-43bf-8205-ad448cfdc6e3` (Parent QA)
- **Payload Configuration:**
  - `bedtime_start_minutes`: `1320` (10:00 PM)
  - `bedtime_end_minutes`: `420` (7:00 AM)
  - `daily_screen_time_limit_minutes`: `null` (No daily limit)
  - `app_rules`: `[]` (Empty)
  - `allowed_packages`: `[]`
  - `blocked_packages`: `[]`
  - `enforce_app_blocks`: `true`
  - `block_all_except_allowed`: `false`

> [!WARNING]
> **CRITICAL ARCHITECTURAL BINDING NOTE:**
> This pending command is explicitly bound via foreign key to target device UUID `a7177c84-68d6-483e-8a5a-03865982b5e4`. If recovery is triggered and a new device record is created upon re-linking, this command will **NOT** automatically transfer to the new device record. The command will remain archived under the old device UUID.

#### Historical Commands on Same Device Record:
1. **Policy v3 Command:** `24979567-cd83-4770-9ac9-e94043ac8f6a`  
   - Status: `pending` | Created: `2026-11-16T10:34:40.583853Z` | Version: 3 | Attempts: 0
2. **Policy v2 Command:** `b3a19cf6-5b5b-467c-b6e3-b1ddcf6b21c8`  
   - Status: `succeeded` | Created: `2026-11-13T10:00:55.404764Z` | Acked: `2026-11-13T10:00:59.154Z` | Version: 2 | Attempts: 1
3. **Policy v1 Command:** `bcb3e4b1-9282-47b9-842d-545664064b82`  
   - Status: `succeeded` | Created: `2026-11-13T07:41:13.05116Z` | Acked: `2026-11-13T07:41:34.121Z` | Version: 1 | Attempts: 1

---

### 2.5 Screen-Time & Bedtime Policy State

Inspected from `device_policies` table for target device `a7177c84-68d6-483e-8a5a-03865982b5e4`:

- **Policy Row UUID (Version 4):** `17b10879-a1ac-40e7-ab98-c912ba63c809`
- **Version Number:** `4`
- **Enforcement Status:** `pending`
- **Bedtime Window:** `10:00 PM (1320m)` to `7:00 AM (420m)` (Crosses midnight)
- **Daily Quota:** `null` (None)
- **App Restrictions:** 0 packages (Empty restriction list)
- **Created At:** `2026-11-17T05:51:41.317287Z`
- **Acknowledged At:** `null`

---

### 2.6 Pairing State Inventory

Inspected from `pairing_requests` table:

- **Latest Approved Pairing Request UUID:** `339df8d3-bf4c-4dd3-88f7-d507d8348c34`
- **Token UUID:** `4ac46bba-5211-45af-a4a4-6ed469926edb`
- **Status:** `approved`
- **Created At:** `2026-11-13T07:26:43.323903Z`
- **Responded / Approved At:** `2026-11-13T07:28:03.306382Z`
- **Token / Code Values:** Redacted per security guidelines.

---

### 2.7 Audit Log Evidence

Inspected from `audit_logs` table:

| Event ID | Event Type | Target Type | Target ID | Actor User ID | Timestamp |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `7af32313-7872-42ca-99e4-f79f58c81565` | `policy_updated` | `device_policy` | `17b10879-a1ac-40e7-ab98-c912ba63c809` | Parent (`d8c7ee...`) | `2026-11-17T05:51:41.612434Z` |
| `73184883-b540-4688-a2ca-47617a93e540` | `policy_updated` | `device_policy` | `8408a71d-161e-4ce6-9365-ac0b900a0ac6` | Parent (`d8c7ee...`) | `2026-11-16T10:34:40.819047Z` |
| `114ae9b9-e645-4945-aad8-5438c37aed04` | `session_ended` | `remote_session` | `98c68da3-b0cb-46ac-bbcd-5a6a6f173762` | Parent (`d8c7ee...`) | `2026-11-13T11:01:43.161335Z` |
| `fbeb42d4-8ae5-44c6-a566-48745797ff4d` | `command_acked` | `device_command` | `b3a19cf6-5b5b-467c-b6e3-b1ddcf6b21c8` | System / Device | `2026-11-13T10:00:59.897762Z` |
| `b218a6c7-f50e-46c4-8309-1fdd0b480dc3` | `policy_updated` | `device_policy` | `270877e9-5f98-4b4e-9166-c1ad27bab251` | Parent (`d8c7ee...`) | `2026-11-13T10:00:55.643517Z` |

---

## 3. Rollback Readiness & Outcome Risk Assessment

### Scenario Analysis:

#### Scenario A — Recovery Request Not Submitted (Current State)
- **Status:** Setup remains completely stable and intact.
- **Outcome:** Parent session, Child session, Family membership, and Device rows are unaffected. The Child device continues to encounter HTTP 401 on polling due to local secret divergence, but no data loss or tenancy corruption occurs.

#### Scenario B — Old Device Revoked and Child Unlinked
- **Trigger:** Calling `family-admin` (`recover_device`).
- **Effect:** 
  1. `devices.status` becomes `revoked`, `devices.secret_hash` becomes `null`.
  2. `family_members.status` becomes `removed`.
- **Safe Response:** 
  - **NEVER** attempt manual SQL updates or back-door credential injection to resurrect the revoked record.
  - The revoked state is irreversible by design. Continue strictly through the supported mutual re-pairing flow (linking code / Child ID invite + physical Child consent).

#### Scenario C — New Child Pairing Fails or Times Out
- **Risk:** Child is unlinked and pairing code expires without parent redemption.
- **Safe Response:** 
  - Both old and new device records remain preserved in database history.
  - Do not create rapid duplicate pairing requests.
  - Wait for user interaction: Child generates fresh linking code from Child UI, Parent redeems on Parent UI.

#### Scenario D — New Device Registration Succeeds, but Policy Sync Fails
- **Risk:** New device is enrolled with new UUID, but pending Policy v4 command is bound to old UUID `a7177c84-68d6-483e-8a5a-03865982b5e4`.
- **Safe Response:**
  - Do **NOT** execute SQL mutations to alter `device_commands.device_id`.
  - Use the standard Parent UI: Open Screen Time, verify Policy v4, and tap "Save screen-time policy". This dispatches a fresh `apply_policy` command directly to the new active device UUID.
  - The old command remains intact in history as an immutable audit record.

#### Scenario E — Partial Recovery Failure
- **Risk:** Network drops after `unlink_child` but before re-enrollment.
- **Safe Response:**
  - Query server state to identify the exact last completed stage.
  - If Child is `removed`, app displays onboarding/linking screen. Proceed with linking without attempting manual rollback.

---

## 4. Recovery Prerequisites Checklist

- [x] **Safe Backup Report Exists:** Complete state captured outside the application database (`docs/testing/PHASE_1_7_DEVICE_RECOVERY_BACKUP_AND_READINESS_REPORT.md`).
- [x] **Old Device UUID Recorded:** `a7177c84-68d6-483e-8a5a-03865982b5e4`.
- [x] **Pending Command ID Recorded:** `0b61ada9-1333-4b6c-95fb-37836864b736` (Version 4).
- [x] **Current Policy Snapshot Available:** Bedtime `10:00 PM – 7:00 AM`, 0 daily limit, 0 app restrictions.
- [x] **Recovery Consequences Documented:** Acknowledged that recovery revokes the existing device record and unlinks child membership, requiring mutual re-pairing.
- [x] **Child Physical Approval Required:** Confirmed that re-pairing strictly requires in-app physical approval on the Child handset.
- [x] **No Unsupported Rollback Proposed:** Confirmed that no secret copying, SQL overwrite, or back-door injection is attempted.
- [x] **Hardware & Build Identified:**
  - Parent: Pixel 9a Emulator (`emulator-5554`), Android 17, `com.parentcontrol.parent_control` v1.0.0.
  - Child: Realme RMX2161 (`5HXWRGQ4IFU8WS4T`), Android 12, `com.parentcontrol.parent_control` v1.0.0.

---

## 5. Summary & Final Verdict

1. **Backup Status:** **COMPLETED** (Full database state exported and verified).
2. **Evidence Locations:**
   - Raw Backup JSON: `scratch/backup_raw.json`
   - Scrolled UI Dump: [parent_device_detail_scroll_recovery.xml](file:///d:/parentcontrol_app/docs/testing/evidence/parent_device_detail_scroll_recovery.xml)
   - Parent Screen Capture: [p16_parent_device_detail_recovery.png](file:///d:/parentcontrol_app/docs/testing/evidence/p16_parent_device_detail_recovery.png)
3. **Pre-Recovery State:** 
   - Family `demo` (`4b97ad74...`) active.
   - Child `ankit1` (`a29448c5...`) active.
   - Active Device UUID: `a7177c84-68d6-483e-8a5a-03865982b5e4`.
4. **Pending Command:** `0b61ada9-1333-4b6c-95fb-37836864b736` (Policy v4).
5. **Rollback Feasibility:** Revocation is irreversible by architectural design; rollback relies entirely on standard re-pairing rather than database tampering.
6. **Recovery Risks:** Queued command will remain on old device UUID; Parent must re-save policy to dispatch to the newly enrolled device.
7. **Prerequisites:** All verified.

---

### Strict Confirmation Statement

> **CONFIRMATION:**  
> **NO recovery, revocation, unlinking, pairing, SQL mutation, credential modification, device reset, or source code change occurred during this phase.**  
> Execution was strictly read-only. ant-gravity assistant is currently stopped and waiting for explicit user instructions.
