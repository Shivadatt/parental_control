# 08 — Test Environment and Dependency Register

## 1. Baseline

| Item | Value |
|---|---|
| Workspace | `D:\parentcontrol_app` |
| Branch | `main` |
| Verified baseline HEAD | `80375f518139bf922bc1b66c998691bee912af44` |
| Android package | `com.parentcontrol.parent_control` |
| Pinned Flutter SDK | `.fvm\flutter_sdk` |
| Parent device | Pixel_9a emulator, `emulator-5554` |
| Child device | Realme RMX2161, `5HXWRGQ4IFU8WS4T` |
| Parent QA account | `ankit@gmail.com` (email only; password not recorded) |
| Child QA account | `ankit1@gmail.com` (email only; password not recorded) |
| Parent expected state | Authenticated Parent dashboard, existing family `demo` |
| Child expected state | Authenticated Child session, existing family link |

Actual Phase 6 report location: `docs/testing/phase_6_comprehensive_manual_testing/reports/21_run8_ai_parent_login_result.md`. The task brief’s `docs/testing/phase6/...` path does not exist; use the existing path above. Existing evidence includes `screenshots/parent/48_run8_after_login.png` and `49_run8_settings_identity.png` under the same Phase 6 directory.

First-independent-review reports are located at `docs/testing/phase6_master_matrix_review/`, not under `docs/testing/phase6_master_matrix/`. Second-review reports are under `docs/testing/phase6_master_matrix/second_independent_review/`.

## 2. Environment preservation rules

Preserve both QA accounts, both authenticated sessions, the existing family, device pairing, registration, local app data, secure storage, and credentials. No test may uninstall, clear data, re-pair, unlink, revoke, recover, rotate credentials, replace accounts, delete the family, change roles, or modify backend data to manufacture a result.

The matrix is designed around the current environment. Cases that would break these constraints are approval-gated, not silently omitted.

## 3. Accounts and role boundaries

| Role | Account email | Device | Allowed observation | Other prohibited or approval-gated actions |
|---|---|---|---|---|
| Parent | `ankit@gmail.com` | Pixel_9a | Parent screens, family data, device status, alerts, audit | Account deletion, role change, family creation/deletion, unlink/revoke/recover |
| Child | `ankit1@gmail.com` | Realme | Child home, rules, requests, protection, permissions | Self-unlink, re-registration, credential reset, data clearing |

No password, token, API key, or `.tools/live_config.env` content appears in this register or any matrix case.

**Absolute session prohibition:** no test may sign out, replace, invalidate, or modify the preserved Parent or Child QA session. No approval gate can override this. Only read-only observation of session state and the sign-out affordance is permitted. Future authentication testing requiring a session change must use a separately approved isolated environment and is currently `BLOCKED — SEPARATE ISOLATED AUTHENTICATION ENVIRONMENT AND EXPLICIT OWNER APPROVAL REQUIRED`.

## 4. Dependency register

| ID | Dependency | What must be verified | Safe verification | Affected cases | If unavailable |
|---|---|---|---|---|---|
| D01 | Parent authentication | Session active as `ankit@gmail.com` | Open Parent dashboard/settings read-only | All `P6-PAR-*`; parent side of `P6-SHR-*`, `P6-INT-*` | Mark parent cases BLOCKED — DEPENDENCY NOT VERIFIED |
| D02 | Child authentication | Session active as `ankit1@gmail.com` | Open Child home/settings read-only | All `P6-CHD-*`; child side of `P6-SHR-*`, `P6-INT-*` | Mark child cases blocked |
| D03 | Existing family relationship | Family `demo` and membership intact | Parent Family details; Child home | Family, pairing, policy, monitoring cases | Do not repair; mark blocked |
| D04 | Device pairing/registration | Existing device row matches child identity | Parent detail vs Child identity | `FAM07`, `MON04`, `USE04`, `LOC04`, `P6-INT-*` | Do not re-register; mark blocked |
| D05 | Both devices connected | Both reachable without changing state | Read-only device status | All paired cases | Mark paired cases blocked |
| D06 | Internet availability | Both devices online | Open app and refresh | All backend/sync cases | Mark blocked |
| D07 | Backend reachability | Supabase/API available | Read-only screen load/refresh | All backend cases | Mark blocked |
| D08 | API response correctness | Returned data matches schema/state | Observe UI and approved logs | Backend/sync/audit cases | INCONCLUSIVE or blocked |
| D09 | Android permissions | Notification, location, camera, mic, usage access recorded | Settings/status read-only | `MON05`, `USE03`, `USE04`, `LOC03`, `LOC04`, `CHD05`, `SET04`–`SET06` | Do not change; mark dependency missing |
| D10 | Background execution | Guardian/location services allowed to run | Child protection status | `CHD04`, `USE04`, `LOC04`, `MON04` | Mark blocked or record limitation |
| D11 | Location services | Location enabled; permission state known | Settings/status read-only | `LOC01`–`LOC09`, `P6-INT-005`–`008` | Mark location cases blocked |
| D12 | Notification permission | Actual OS notification state known | Read-only system permission dump | `MON05`, `SET01`, `SET02`, `LOC09` | Do not grant; record mismatch |
| D13 | Usage access | Actual Usage Access state known | Android settings/status read-only | `USE01`–`USE04`, `USE08` | Mark usage cases blocked |
| D14 | Device Owner availability | Whether child is Device Owner, without provisioning | Child Rules/enforcement mode | `USE08`, `APP07`, `P6-LIM-005`, `P6-LIM-006` | Mark BLOCKED — DEPENDENCY NOT VERIFIED |
| D15 | Build identity | Installed build matches baseline | Settings version vs package metadata | All cases | Record mismatch; do not treat as baseline |
| D16 | Device time/timezone | Clocks plausible and comparable | Device settings read-only | Presence, alerts, audit, usage | Timestamp cases INCONCLUSIVE |
| D17 | Device credential validity | Current credentials authenticate without rotation | Existing heartbeat/upload evidence and redacted logs | `MON04`, `USE04`, `LOC04`, `P6-LIM-*` | Do not repair; mark known limitation |
| D18 | Isolated authentication test environment | Separate approved environment exists for invalid-credential tests | Owner evidence only; do not create or use real accounts | `P6-SHR-015` | Mark BLOCKED — REQUIRES SEPARATE AUTHENTICATION TEST ENVIRONMENT APPROVAL |
| D19 | Safe backend-error fixture | An already-existing approved fixture can show backend/auth errors | Owner evidence only; do not block traffic or alter backend | `P6-SHR-016` | Mark BLOCKED — REQUIRES SEPARATE SAFE TEST ENVIRONMENT |
| D20 | Interconnected observation parameters | Provisional windows and cadence reviewed for the paired cases | Review `04_shared_and_interconnected_test_plan.md`; no polling during planning | `P6-INT-001`, `P6-INT-005`–`010` | Use INCONCLUSIVE, not FAIL, if evidence cannot distinguish delay from failure |

Timing values are **PROPOSED — OWNER REVIEW REQUIRED**. They are proposed, not approved, not application SLAs, and not validated by runtime QA; owner acceptance or revision is pending.

## 5. Dependency handling rule

If a prerequisite is unknown, the affected case remains **NOT TESTED** with an approval gate or **BLOCKED — DEPENDENCY NOT VERIFIED**. No dependency may be changed merely to force a test to run. A static source finding cannot satisfy a runtime dependency.

Interconnected timing values are **PROPOSED — OWNER REVIEW REQUIRED** and **PROVISIONAL QA OBSERVATION PARAMETERS — NOT APPLICATION SLAs**. Source-derived heartbeat and stale-window values are documented in report 04, but the matrix does not claim an application guarantee or owner approval.
