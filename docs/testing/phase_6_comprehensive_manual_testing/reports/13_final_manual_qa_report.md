# 13 — Final Manual QA Report

**Verdict: FAIL — CRITICAL FUNCTIONAL DEFECTS**

The fresh build installed and launched on both designated devices, and most parent
read-only screens are functional. However, the core Parent–Child credential and
heartbeat path still fails, so online status, last-seen, usage and location
synchronization do not work. The app cannot be accepted as comprehensively tested
or functionally healthy.

## Build and installation

| Item | Result |
|---|---|
| FVM-pinned SDK | Flutter 3.44.6 / Dart 3.12.2 |
| Parent artifact | x86_64 debug APK, SHA-256 `7ed729f5d00b146f6840a00e382b459a496887e2789e614d208144741f93ca72` |
| Child artifact | arm64 debug APK, SHA-256 `cc621bf6eefc6ee6d8093da11fc6727abe62f3114ba38ef19886ed9c0fc5ff5a` |
| Package/version | `com.parentcontrol.parent_control`, 1.0.0 (code 1) |
| Parent install | Success, in-place, session preserved |
| Child install | Success, in-place, session preserved |
| Old APK substituted | No |
| ABI incident | arm64 first installed on x86_64 emulator crashed; corrected with x86_64 build |

## Account sign-in

Both QA accounts already had valid persisted sessions. **Fresh login was not
tested** because no password was supplied in the task text. No password, token or
device secret was printed or stored. No account setting was changed.

## Exact test counts

| Metric | Count |
|---|---:|
| Total discovered features | **86** |
| Manually tested (PASS + FAIL) | **59** |
| Passed | **44** |
| Failed | **15** |
| Blocked | **5** |
| Not tested | **22** |
| Parent manual coverage | **33 / 50** |
| Child manual coverage | **16 / 19** |
| End-to-end coverage | **10 / 17** |

## Automated results

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 493 passed, 0 failed |
| `deno test` Edge functions | 209 passed, 0 failed |
| Kotlin `:app:testDebugUnitTest` | 57 passed, 0 failed |
| Aggregate Gradle task | Failed at plugin configuration; app tests unaffected |

## Defects

| Severity | Count |
|---|---:|
| P0 | 0 |
| P1 | 2 |
| P2 | 3 |
| P3 | 1 |

P1 defects:

- **DEF-601** — child heartbeat cannot authenticate: “Device credentials are not
  valid”; parent/child remain Offline; last-seen frozen at Nov 13, 2026.
- **DEF-602** — revoked device remains visible as a duplicate active-looking row.

P2 defects:

- **DEF-603** — Devices tab shows policy v2 while dashboard/detail/child show v4.
- **DEF-604** — notifications reported Granted while Android does not grant
  `POST_NOTIFICATIONS`.
- **DEF-605** — child location service not running despite location grants.

P3: **DEF-606** — physical device lost ADB authorization, blocking the final explicit
restart test.

## Acceptance criteria assessment

| Criterion | Result |
|---|---|
| Fresh APK identity verified | PASS |
| Both devices run fresh build | PASS |
| Both accounts successfully sign in | NOT VERIFIED (no password; persisted sessions only) |
| Every discovered feature has status | PASS (86/86 listed) |
| Every accessible Parent screen tested | PASS for accessible screens |
| Every accessible Child screen tested | PASS for accessible screens |
| Parent–Child sync verified both ways | FAIL |
| Previous defects retested | PASS (E2E-001–004) |
| Failures have evidence | PASS |
| Blocked/untested explicitly counted | PASS |
| No old APK used | PASS |
| No family/device/account state destroyed | PASS |

## Git comparison

| Item | Baseline | Final |
|---|---|---|
| HEAD | `bbd3c213721fd6ebd3de2871822ddd7fbda4fc1f` | `bbd3c213721fd6ebd3de2871822ddd7fbda4fc1f` |
| Branch | `main` | `main` |
| Tracked source diff | None | None |
| New commits | None | None |

An external process staged 83 pre-existing documentation files during the session;
no Git mutation command was run by this testing run and no source file changed. This
index anomaly is documented in report 01.

## Bottom line

The APK is fresh and installed, and the UI read-only surface is largely sound. The
re-credentialing defect is not fixed: a fresh install does not restore authenticated
heartbeats. Until the child credential/server device row is reconciled, Parent–Child
testing cannot pass regardless of UI polish. No defect fix or implementation was
started.
