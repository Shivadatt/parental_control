# 04 — Child Functional Test Matrix

**Date:** 2026-11-21  
**Device:** Realme RMX2161, Android 12 / API 31  
**Build:** installed `1.0.0` debug (2026-11-18)  
**Statuses:** PASS / FAIL / BLOCKED / NOT_TESTED / AUTHORIZATION_REQUIRED / PLATFORM_LIMITED / NOT_IMPLEMENTED

---

## 1. Executed child tests

| Test ID | Feature | Scenarios executed | Expected | Actual | Status | Evidence |
|---|---|---|---|---|---|---|
| C01-T1 | Session restore | I, BG | Existing child session restores | Child shell loaded without login prompt | PASS | Child Home dump |
| C02-T1 | Role/family resolution | N | Child role, family `demo` | Home shows `demo`; family page lists `ankit1` as Child | PASS | Home + parent Family |
| C03-T1 | Child home status | N, S | Current status and freshness | Home rendered; “Updated 2 d ago” | PASS (rendering) / FAIL (freshness) | Home dump |
| C07-T1 | Pending requests | E | Empty state | “0 pending” | PASS | Home dump |
| C09-T1 | Existing-device handling | N | Existing device treated as linked and syncing | Treated as registered; heartbeat auth fails | **FAIL (P1)** | Source + parent stale row |
| C10-T1 | Credential storage | N | Secret stored encrypted, not exposed | Encrypted store present; no value read | PASS | `SecureStore.kt`; service config present |
| C12-T1 | Guardian FGS | N, BG | Foreground service alive | `GuardianService` `isForeground=true`, id 4101 | PASS | `dumpsys activity services` (prior E2E) |
| C13-T1 | Guardian notification | N | Visible notification | `guardian_status` notification present | PASS | service/notification dump (prior) |
| C14-T1 | Heartbeat scheduling | N | 10 s tick / 5 min heartbeat | Service alive ~37 h; tick loop configured | PASS (source + runtime) | `GuardianService.kt` |
| C15-T1 | Heartbeat authentication | N | Credential accepted, `last_seen` updates | Rejected; `last_seen` frozen | **FAIL (P1)** | Source + parent row |
| C16-T1 | Heartbeat retry | R | Retry after failure | 60 s retry path present | PASS (source) | `GuardianService.kt` |
| C20-T1 | Online/offline sync | N, S | Parent sees Online | Parent sees Offline | **FAIL (P1)** | Parent dashboard |
| C21-T1 | Location permission status | P | Accurate status | Warning says permission missing; Android grants fine/background location | **FAIL (P2)** | Home dump + dumpsys |
| C22-T1 | Location sharing toggle | I | Persisted on/off state | On; card shown | PASS | Home dump |
| C23-T1 | Location tracking service | N | Running when enabled | Not running | **FAIL** | Home warning; service list |
| C24-T1 | Usage access status | P | Granted state recognized | app-op `GET_USAGE_STATS: allow` | PASS | dumpsys appops |
| C33-T1 | Notification permission | P | API-31 mapping correct | Visible guardian notification; source returns true below API 33 | PASS | source + notification |
| C34-T1 | Local preference persistence | I, BG | Setting survives relaunch | Location sharing remains on; session remains | PASS | Home dumps |
| C36-T1 | Background execution | BG | Service survives background | Alive ~37 h | PASS | service dump |
| C39-T1 | Requests inbox | E, ER | Empty or clear error | Initial timeout banner, later “0 pending” | PASS (with timeout observation) | Home dumps |

### Defect rows directly exercised

| Test ID | Feature | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| C15-T2 | Credential mismatch | N, R | Heartbeat accepted after install | Old device row + new secret; no re-credential | **FAIL (P1)** |
| C21-T2 | Permission warning | P | Accurate permission message | Contradicts Android grants | **FAIL (P2)** |
| C23-T2 | Location service | N | Start when enabled | “Location service is not running” | **FAIL** |

---

## 2. Blocked child features

These depend on the broken device credential or were refused by the environment.

| Test ID | Feature | Blocker | Status |
|---|---|---|---|
| C17-T1 | App-list upload | Heartbeat/device auth rejected | BLOCKED |
| C18-T1 | Usage upload | Same credential path | BLOCKED |
| C19-T1 | Location upload | Same credential + service not running | BLOCKED |
| C25-T1 | App inventory collection/upload | No safe upload path | BLOCKED |
| C26-T1 | Policy download | Command poll auth failure / not observed | BLOCKED |
| C32-T1 | Safety-event reporting | Telemetry auth failure | BLOCKED |

---

## 3. Not-tested child features

| Test ID | Feature | Reason | Status |
|---|---|---|---|
| C04-T1 | Device identity display | Screen not opened | NOT_TESTED |
| C05-T1 | Enrollment / Child ID | Screen not opened | NOT_TESTED |
| C06-T1 | QR pairing display | Screen not opened | NOT_TESTED |
| C27-T1 | Policy presentation (Rules) | Tab not opened | NOT_TESTED |
| C35-T1 | Network-loss handling | Wi-Fi toggle not authorized | NOT_TESTED |
| C37-T1 | Battery-optimization guidance | Screen not opened | NOT_TESTED |
| C38-T1 | Reboot/process restart | Reboot not performed | NOT_TESTED |
| C40-T1 | Remote-assistance consent | No pending request | NOT_TESTED |
| C42-T1 | Child settings | Tab not opened | NOT_TESTED |
| C43-T1 | Restrictions/permission screen | Tab not opened | NOT_TESTED |

---

## 4. Authorization-required / platform-limited / missing

| Test ID | Feature | Classification | Status |
|---|---|---|---|
| C08-T1 | Approve/decline pairing | Creates relationship state | AUTHORIZATION_REQUIRED |
| C41-T1 | Remote session join/media | Activates camera/microphone | AUTHORIZATION_REQUIRED |
| C44-T1 | Logout | Changes session; re-login needed | AUTHORIZATION_REQUIRED |
| C28-T1 | Device Owner suspension | Needs managed device | PLATFORM_LIMITED |
| C29-T1 | Quota suspension | Needs Device Owner | PLATFORM_LIMITED |
| C30-T1 | Bedtime enforcement | Not implemented (informational only) | NOT_IMPLEMENTED |
| C31-T1 | Emergency pass | Not implemented | NOT_IMPLEMENTED |
| C11-T1 | Re-credentialing | No implementation | NOT_IMPLEMENTED |

---

## 5. Child matrix verdict

**20 features exercised, 15 pass, 5 fail.**  
Failures: C09/C15/C20 (P1 credential/heartbeat), C21 (P2 permission warning), C23 (location service).

Six telemetry features are BLOCKED by the same credential fault. No consent, camera, microphone, pairing, recovery or credential action was executed.
