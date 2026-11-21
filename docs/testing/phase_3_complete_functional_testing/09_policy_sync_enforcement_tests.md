# 09 — Policy Sync and Enforcement Tests

**Date:** 2026-11-21  
**Statuses:** PASS / FAIL / BLOCKED / NOT_TESTED / AUTHORIZATION_REQUIRED / PLATFORM_LIMITED / NOT_IMPLEMENTED

---

## 1. Policy state model in the repository

| Concept | Field | Meaning |
|---|---|---|
| Saved policy | `device_policies.version` (latest row) | Parent saved/published a policy |
| Applied/acknowledged version | `devices.policy_version` | Device successfully applied and acknowledged |
| Ack status | `device_policies.enforcement_status` | pending / enforced / failed / unsupported |
| Ack timestamp | `device_policies.acknowledged_at` | When the child acknowledged |
| Last error | `device_policies.last_error` | Safe enforcement failure reason |

The UI must not treat “saved” as “applied.” The detail screen distinguishes them; the Devices list does not.

---

## 2. Tests

| Test ID | Test | Expected | Actual | Status |
|---|---|---|---|---|
| Y01 | Devices list policy label | One clear version | `Policy v2` (applied number) | FAIL (P2) |
| Y02 | Device detail latest policy | Latest saved version | `Version 4`, “Waiting for device” | PASS |
| Y03 | Saved vs applied distinction | Both shown explicitly | Only detail distinguishes; list is ambiguous | **FAIL (P2)** |
| Y04 | Pending acknowledgement | “Not yet acknowledged”, no active restriction claim | Correct copy shown | PASS |
| Y05 | Child policy download | Child receives latest policy | Not observed; command poll auth-dependent | BLOCKED |
| Y06 | Child policy presentation | Rules tab shows policy | Tab not opened | NOT_TESTED |
| Y07 | Enforcement truthfulness | Never claim blocked without proof | “Not enforced”; Device Owner banner | PASS |
| Y08 | Device Owner suspension | Suspend blocked apps | Requires managed device | PLATFORM_LIMITED |
| Y09 | Daily quota enforcement | Suspend after limit | Code exists; requires Device Owner | PLATFORM_LIMITED |
| Y10 | Bedtime enforcement | Hard suspension overnight | Informational only (`bedtime_active`) | **NOT_IMPLEMENTED** |
| Y11 | 10-minute emergency pass | Grant temporary access | No implementation | **NOT_IMPLEMENTED** |
| Y12 | Save policy | Write new version | Not executed | AUTHORIZATION_REQUIRED |
| Y13 | Sync now command | Create `sync_policy` command | Not executed | AUTHORIZATION_REQUIRED |
| Y14 | Policy save validation | Server validation and versioning | Source/offline tests | PASS (offline) |
| Y15 | Ack updates applied version | Only on successful apply | Source: `device-command` ack path | PASS (source) |
| Y16 | Failed apply reporting | `failed` + error, no version advance | Source: ack path | PASS (source) |
| Y17 | Stale policy after reinstall | New policy reaches child | Blocked by credential/heartbeat | BLOCKED |

---

## 3. Observed inconsistency

- Dashboard: “Policy v4 · Waiting for device”.
- Device detail: Version 4, waiting, not acknowledged.
- Devices list: “Policy v2”.

The list uses `DevicesController.policySummaryFor()`, which reads `device.policyVersion` and omits status. Detail/dashboard use `policySummary()` with the latest `DevicePolicy` and its status. Both values are real but represent different stages. The list label is the defect.

---

## 4. Enforcement reality

- The child is **not** Device Owner. App suspension is unavailable.
- The parent UI correctly says so.
- Quota enforcement exists in code but cannot be proven on this device.
- Bedtime is stored and echoed as `bedtime_active`; it does not suspend apps.
- No emergency pass exists.

---

## 5. Policy verdict

**PASS:** honest enforcement reporting, pending-ack copy, server-side ack semantics.  
**FAIL (P2):** policy-version presentation inconsistency.  
**BLOCKED:** child policy download after credential repair.  
**PLATFORM_LIMITED:** suspension/quota.  
**NOT_IMPLEMENTED:** bedtime hard suspension and emergency pass.
