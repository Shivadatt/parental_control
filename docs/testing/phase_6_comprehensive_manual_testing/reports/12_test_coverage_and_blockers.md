# 12 — Test Coverage and Blockers

## Coverage totals

| Metric | Value |
|---|---:|
| Total discovered features | 86 |
| Manually tested (PASS + FAIL) | 59 |
| Passed | 44 |
| Failed | 15 |
| Blocked | 5 |
| Not tested | 22 |
| Parent features tested | 33 / 50 (66%) |
| Child features tested | 16 / 19 (84%) |
| End-to-end workflows tested | 10 / 17 (59%) |
| Overall tested | 59 / 86 (68.6%) |

## Why features remain untested

### 1. No QA password in the task text

The Phase 6 instruction referenced a Project Owner-supplied password, but no
password value was present. Both devices were already signed in, so manual testing
continued without exposing, guessing or changing credentials. Login, registration,
parent sign-out/re-login, and role-selection entry remain NOT TESTED.

### 2. Child credential failure

E2E-001 prevents authenticated heartbeat, usage upload, location upload and policy
acknowledgement. App restriction and schedule propagation are therefore BLOCKED, not
silently marked failed.

### 3. Destructive/live-state actions intentionally not executed

The following were not run because they would change account, family, device, or
retention state without separate authorization:

- revoke, unlink, re-pair, recovery, credential rotation;
- account deletion, password/email changes;
- retention save/purge;
- live safe-zone create/edit/delete;
- unsolicited audio/video assistance request;
- live screen-time/app-restriction policy save.

### 4. Child USB authorization lost

The physical phone became `unauthorized` near the end. The explicit force-stop /
relaunch test and any further child interaction were blocked. This is an environment
issue (DEF-606), not evidence that the app crashed.

### 5. Automated-only checks

Dart analysis, Flutter tests, Deno Edge tests and Kotlin app tests were run. The
SQL regression chain was not run because it requires disposable database execution
outside Phase 6 authorization.

## Coverage confidence

High confidence:

- Fresh build identity and in-place installation on both devices.
- Parent navigation, dashboard, device detail, alerts, family, audit, settings.
- Stale/offline/empty/error UI states.
- Credential failure and offline/online regression.

Medium confidence:

- Permission reporting (one confirmed notification mismatch).
- Location/safe-zone/assistance read-only screens.

Low / no confidence:

- Any write path that depends on child acknowledgement or Device Owner.
- Login/logout flows.
- Child restart after the USB authorization loss.
