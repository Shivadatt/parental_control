# 06 — Safety and Destructive Operation Verification

**Document ID:** `HAVEN-VER-006`  
**Phase:** Phase 2.1 — Independent Consistency & Coverage Verification  
**Workspace:** `D:\parentcontrol_app`  
**Audited Document:** `docs/testing/phase2_coverage_gap_audit/10_test_safety_and_prerequisite_register.md`  
**Audit Standard:** Operational Risk, Destructive Quarantine & Permission Authorization Audit  
**Execution Posture:** STRICTLY READ-ONLY — ALL TESTS `NOT TESTED`  

---

## 1. Audit Target & Discrepancy Formulation

In `docs/testing/phase2_coverage_gap_audit/10_test_safety_and_prerequisite_register.md` (§2), Phase 2 presents the following safety breakdown:

| Claimed Category | Claimed Count | Claimed % |
|:---|:---:|:---:|
| **`SAFE`** | 38 | 44.7% |
| **`SAFE_REVERSIBLE`** | 24 | 28.2% |
| **`REQUIRES_DISPOSABLE_ACCOUNT`** | 6 | 7.1% |
| **`REQUIRES_DISPOSABLE_DEVICE`** | 7 | 8.2% |
| **`REQUIRES_ISOLATED_BACKEND`** | 5 | 5.9% |
| **`SPECIALIST_TEST`** | 5 | 5.9% |
| **Claimed Total** | **85** | **100.0%** |

### Independent Audit Finding:
1. **The Claimed Total of 85 is an Under-Count**: The actual unique test suite contains **99 test cases** (41 baseline + 58 expansion).
2. **Specialist Tests Severely Under-Reported**: Phase 2 claimed only 5 specialist tests, but in `05_additional_manual_test_cases.md` alone there are **12 specialist tests**, plus **4 specialist tests** in the baseline suite, yielding a true total of **16 SPECIALIST_TEST cases**.
3. **Safe Tests Under-Reported**: The true number of non-mutating `SAFE` test cases across the 99-test suite is **46** (19 baseline + 27 expansion).

---

## 2. Reconciled Safety Taxonomy Breakdown (99 Unique Test Cases)

Every single one of the 99 unique test cases was independently inspected and categorized based on its actual operations, device impacts, and database mutations:

| Safety Category | Baseline Count (41) | Expansion Count (58) | Reconciled Total (99) | Reconciled % | Core Impact Definition |
|:---|:---:|:---:|:---:|:---:|:---|
| **`SAFE`** | 19 | 27 | **46** | **46.5%** | Read-only UI, navigation, inspection, validation helper text. Zero state mutation. |
| **`SAFE_REVERSIBLE`** | 7 | 9 | **16** | **16.2%** | Modifies settings, schedules, safe zones; completely reversed by teardown. |
| **`REQUIRES_DISPOSABLE_ACCOUNT`** | 5 | 3 | **8** | **8.1%** | Irreversibly alters or deletes user account; permanent role binding. |
| **`REQUIRES_DISPOSABLE_DEVICE`** | 4 | 3 | **7** | **7.1%** | Enrolls hardware, unlinks devices, revokes cryptographic tokens. |
| **`REQUIRES_ISOLATED_BACKEND`** | 2 | 4 | **6** | **6.1%** | Database purges, retention sweeps, cross-tenant RLS checks, token replays. |
| **`SPECIALIST_TEST`** | 4 | 12 | **16** | **16.2%** | Hardware WebRTC camera/mic, background GPS tracking, Device Owner MDM. |
| **TOTAL** | **41** | **58** | **99** | **100.0%** | **Mathematically Exact and Fully Reconciled.** |

---

## 3. Mandatory Destructive Operation Review

Five operations in the HAVEN testing suite possess catastrophic destructive potential if executed against production accounts or live family records:

```
+----------------------------------------------------------------------------------------------------+
|                                 DESTRUCTIVE OPERATION QUARANTINE REGISTER                          |
+----------------------------------------------------------------------------------------------------+
| Op 1: TC-A09 — Permanent Account Deletion with Cascade                                             |
|   - Target: Supabase auth.users & public.profiles, families, devices cascade                      |
|   - Risk: Irreversibly purges parent account and all paired child devices from database.           |
|   - Mandatory Quarantine: Must ONLY be executed on disposable account disposable_01@haven.test.   |
|   - Gate: Requires explicit Owner Disposable Account Authorization.                                |
+----------------------------------------------------------------------------------------------------+
| Op 2: TC-FAM10 — Unlink Child Account from Parent Dashboard                                        |
|   - Target: devices row and child local Keystore credentials                                      |
|   - Risk: Removes child from family, breaks communication, resets child client to enrollment.      |
|   - Mandatory Quarantine: Must be scheduled at the END of child testing on disposable test phone. |
|   - Gate: Requires explicit Device Unlinking Approval.                                             |
+----------------------------------------------------------------------------------------------------+
| Op 3: TC-EXP-17 — Cryptographic Device Revocation from Dashboard                                   |
|   - Target: devices.status set to 'revoked'; Keystore JWT invalidated                              |
|   - Risk: Child device is permanently locked out of family; daemons halt.                          |
|   - Mandatory Quarantine: Must be executed only after all telemetry & WebRTC tests complete.      |
|   - Gate: Requires explicit Device Revocation Approval.                                            |
+----------------------------------------------------------------------------------------------------+
| Op 4: TC-EXP-47 — On-Demand Historical Audit Log Purge                                             |
|   - Target: public.audit_events table                                                              |
|   - Risk: Permanently deletes all audit events older than retention period via keyword confirmation.|
|   - Mandatory Quarantine: Must ONLY be run against seeded staging data. PROHIBITED ON PROD.       |
|   - Gate: Requires explicit Database Purge Authorization.                                          |
+----------------------------------------------------------------------------------------------------+
| Op 5: TC-EXP-18 — Device Re-Credentialing Recovery Challenge                                       |
|   - Target: devices.public_key and pairing challenge redemption                                    |
|   - Risk: Modifies cryptographic public key in database; could brick device if key mismatch.       |
|   - Mandatory Quarantine: Requires staging database and disposable test device.                    |
|   - Gate: Requires explicit Cryptographic Recovery Approval.                                       |
+----------------------------------------------------------------------------------------------------+
```

---

## 4. Mandatory OS Permission Review & Separate Approval Flag

Phase 2 grouped tests modifying Android system permissions under `REQUIRES_DISPOSABLE_DEVICE` or `SPECIALIST_TEST`. However, **disposable device classification does not automatically authorize changing Android OS settings**.

Modifying Android OS-level permissions alters the security posture of the hardware bench and can interfere with device management. Therefore, this audit establishes an explicit **Permission Approval Flag**:

| Test ID | Functionality | Android OS Permission | System Level Impact | Separate Approval Required |
|:---|:---|:---|:---|:---:|
| `TC-SET05` | `SET05` | Android Device Administrator | Binds app as Device Admin; blocks uninstallation | **YES** |
| `TC-APP07` | `APP07` | Device Owner (`setPackagesSuspended`) | Requires ADB provisioning; Linux-level app freeze | **YES** |
| `TC-EXP-27` | `USE03` | `PACKAGE_USAGE_STATS` | Grants access to read private app usage across OS | **YES** |
| `TC-EXP-37` | `LOC04` | `ACCESS_BACKGROUND_LOCATION` | Grants continuous "Allow all the time" GPS polling | **YES** |
| `TC-EXP-08` | `REM03` | `CAMERA` & `RECORD_AUDIO` | Grants live hardware video and microphone capture | **YES** |
| `TC-CHD04` | `CHD04` | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Bypasses Android Doze power management | **YES** |
| `TC-EXP-55` | `SET08` | Device Admin Deactivation | Attempts to remove administrative binding | **YES** |

> [!IMPORTANT]
> **Owner Governance Mandate**:  
> In Phase 3 execution planning, testers must NOT alter any of the 7 OS-level permissions listed above without an explicit **System Permission Authorization Sign-Off** from the Product Owner.
