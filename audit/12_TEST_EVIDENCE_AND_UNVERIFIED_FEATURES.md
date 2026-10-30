# 12 — Test evidence and unverified features

Read-only audit. No test was executed as part of this audit unless explicitly stated; every
"result" below is a **historical** result quoted from the repository's own reports, with its date.
Nothing here was re-run, so no green status is asserted for the current working tree.

Evidence is graded in four tiers and never collapsed:

| Tier | Meaning | Counts as "works"? |
|---|---|---|
| **C** — code | The implementation exists and reads correctly | No |
| **T** — automated test | A test exists and is *known to pass* (historical or observed) | Partial — proves logic, not device behaviour |
| **R** — runtime | Observed on real hardware/emulator with captured artefacts | Yes, for the scenarios exercised |
| **D** — deployment | Verified against the live hosted project | Yes, for the observed object |

A feature reaches `FULLY IMPLEMENTED — VERIFIED` in the inventory only with C + T + R (and D where
the backend is involved). This document explains where that bar was and was not met.

---

## 1. Test suite inventory (counted from the working tree)

| Suite | Location | Files | What it can prove | What it cannot |
|---|---|---|---|---|
| Flutter unit/widget | `test/` | **38** `*_test.dart` across 19 subdirectories + root, ~10.8k LOC incl. integration | Controller/state/model logic, widget rendering with mocked repositories | Anything involving a real device, real WebRTC, real Supabase |
| Flutter integration | `integration_test/` | **4** (`child_media_selftest_test.dart`, `child_signin_test.dart`, `device_capabilities_test.dart`, `parent_ui_journey_test.dart`) | One-device journeys on an emulator/device with a real backend | Two-device media, background/lock behaviour, network loss |
| Deno (Edge Functions) | `supabase/functions/**` | **5** (`remote-session/guard_test.ts`, `_shared/{enrollment,policy,turn,validation}_test.ts`) | Function logic in isolation | Deployed behaviour; deployment parity |
| SQL | `supabase/tests/` | **12** `.sql` + **2** runners (`run_pairing_invite_race.sh`, `run_remote_session_race.sh`) | Schema invariants, RLS, function authorization, concurrency | Application behaviour; the hosted copy |
| Kotlin (Android) | `android/app/src/test/...` | **4** (`AudioAssistanceRecreationTest`, `AudioAssistanceSessionWatchdogTest`, `AudioAssistanceStartGateTest`, `policy/PolicyEvaluatorTest`) | Service lifecycle decisions, policy evaluation | Media, permissions, OEM behaviour |

Flutter test-file distribution: `features/child` 8, `features/remote_assistance` 7, `features/auth`
2, `features/devices` 2, `features/family` 2, `features/pairing` 2, `core` 2, and one each for
app_restrictions, audit_logs, dashboard, location, parent_shell, role_selection, safe_zones,
safety_alerts, screen_time, settings, `data/`, `core/config/`.

Notable shape: **remote assistance is the best-tested feature** (7 controller tests + the most
runtime evidence), while **the features with the largest user-visible surface — dashboard,
screen time, location — have one test file each.**

---

## 2. Historical automated results

Source: `docs/runtime-mic-test-report.md:237-246`, recorded **2026-10-29**. These are the last
known results and were **not** re-run in this audit.

| Suite | Result | Evidence line | Confidence now |
|---|---|---|---|
| `flutter test` | **275 passed, 0 failed**, exit 0 | `:241` | Medium — tree has changed since; not re-run |
| `flutter analyze` | No issues found | `:242` | Medium — same caveat |
| `deno test` | **47 passed, 0 failed** | `:243` | Medium — same caveat |
| Kotlin `testDebugUnitTest` | **BLOCKED (environment)** — cross-drive Gradle roots, zero tests executed | `:244`; `docs/runtime-failure-analysis.md:124-142` | None — the Android unit suite has never run on this workstation |
| SQL suites | No pass/fail row recorded in §6 | — | None — green is an assumption, not a fact |

Two consequences that matter for the verdicts in the inventory:

1. **The Kotlin suite has never executed here.** All four Android tests — the ones that would
   cover service restart, watchdog and policy evaluation — are unproven. Any claim resting on them
   is `CODE EXISTS — NOT TESTED`, not verified.
2. **The SQL suites are inventoried, not certified.** The 12 `.sql` files encode exactly the
   invariants this audit cares most about (RLS, session concurrency, lifetime, signaling). Their
   existence proves intent; only a run proves the hosted policies behave as written.

---

## 3. Runtime evidence ledger

Runtime artefacts live in `docs/evidence/stage4` … `stage8`; `stage8` alone holds 68 files.
The only two-device campaign with a documented matrix is the 2026-10-29 microphone run
(`docs/runtime-mic-test-report.md`, `docs/runtime-device-matrix.md`).

What that run actually proves:

| Proven at runtime | Evidence |
|---|---|
| Child→parent one-way audio reaches live media, three separate sessions | `media-verified-11-55Z.txt`; S1/S2/S3 with RTP counters (4,185 packets in S3) |
| Media survives child backgrounding (5 min), screen lock (2 min), Recents swipe | report §4 (A/B/C families) |
| Force-stop kills capture and services; permission revoke stops capture, grant restores it | report D/E families; `f5-child-permission-*.png` |
| Parent End works with the child online and after force-stop | S2/S3, `ended_by` parent, audit row present |
| Consent gate works (two-step accept on child) | A1/A3/A4 |
| Session restore after child re-launch | `f6-child-relaunch.png` |
| Presence/last-seen pipeline works when the scheduler ticks | `runtime-failure-analysis.md:76-84` |

What it explicitly does **not** prove:

- **Human audibility.** No independent listener; the evidence is packet and track counters.
- **Duration.** Every session was killed by the hosted 30-minute expiry (F1); the longest run was
  8m14s. The 15-minute endurance scenario failed *for a deployed-code reason*, not a media reason.
- **Video.** Every scenario requested `kind: audio`. No front/rear camera, no video track, no
  flashlight, no camera switching has ever run.
- **Location, geofence, app suspension, unlink-in-session.** Stage 8 is session- and
  permission-focused; these have code and unit tests but no runtime row.

---

## 4. The two BROKEN features

| ID | Feature | Why it is BROKEN, not "partial" |
|---|---|---|
| **FB-046** | Session lifetime (parent-controlled until End) | Reproduced failure with a timestamped artefact: session flipped to `expired` at 12:16:38.393Z, media closed 144 ms later, while the parent UI still promised "Until you end the session". Code at HEAD fixes it; the deployed function does not. Code ≠ deployed. |
| **FA-009** | Online/offline presence | Two independent runtime defects: a healthy child shows "Offline" for ~2 min of every 5-min heartbeat cycle (BUG-038, still open), and a single stalled scheduler tick froze presence for 42 minutes (F2). Presence feeds parent decisions, so it cannot be called partially working. |

Both are **deployment/implementation** failures with runtime proof — the strongest evidence tier
in this audit, and the reason neither is downgraded to "partially verified".

---

## 5. The 13 `CODE EXISTS — NOT TESTED` features

These have implementation (and sometimes unit tests) but **no runtime observation** in any
evidence set. They are the highest-risk unknowns because they look finished.

| ID | Feature | Why unverified |
|---|---|---|
| FB-001 | Front camera capture on child | No video-kind session ever requested; `kind: audio` in every stage-8 row |
| FB-006 | Live video streaming to parent | Same; plus no `camera` FGS type, so background video is impossible (SC-03) |
| FB-007 | Audio during a video session | No video session exists to test it |
| FA-034 | Geofence alerts | Zone CRUD is unit-tested; the server insert path (`device-telemetry` enter/exit) has never fired in a runtime run |
| FA-044 | Realtime delivery (family channel) | A generic subscribe test passed on 2026-10-27; no runtime assertion that a real event reached a real parent within a bound |
| FC-002 | Block all restricted apps | Requires Device Owner; no provisioning run exists |
| FC-003 | Always-allowed apps | Same |
| FC-007 | Offline behaviour (blocking) | No device test with the child offline while a block is active |
| FC-026 | DST / time-change behaviour | No clock-manipulation test |
| FC-032 | Always-allowed apps (downtime) | Same as FC-003 |
| FC-033 | Auto-block new apps | No install-during-policy test |
| FD-029 | Background location | Location FGS exists; no stage-8 fix recorded with app backgrounded |
| FD-054 | Geofence background monitoring | Depends on FD-029 and FA-034, both unproven |

Common thread: **every one of them depends on a capability the current build cannot demonstrate**
— video, Device Owner, background location, or a time/network condition nobody has reproduced.

---

## 6. Features with neither runtime evidence nor tests

These are `MISSING` in the inventory (111 rows), so listing them individually is redundant; what
matters is the pattern:

- **No code at all** — screen mirroring, notification reading, social/text detection, image
  detection, calls/SMS, website restrictions, web time limits, browsing history, route playback,
  cellular data, notification counts, trends, activity timeline, push notifications, account
  deletion, data export. There is nothing to test and nothing to verify.
- **Code but no enforcement path** — bedtime/downtime and block-all (Device Owner), always-allowed
  lists, auto-block-new-apps (FC-014, FC-002/003/032/033).
- **Backend-only rows** — two features exist server-side with no parent UI: bedtime schedule
  (FC-014) and parent-side fresh-fix/live-share controls (FD-038). `BACKEND ONLY` is the honest
  label; they are not user-reachable.

---

## 7. Cross-cutting evidence gaps

| Gap | Impact on verdicts | Unblock |
|---|---|---|
| Kotlin suite never runs on this workstation | All Android service/policy tests unproven | Fix Gradle root layout (cross-drive), then `testDebugUnitTest` |
| SQL suites never executed in this audit | RLS/lifetime/concurrency claims rest on reading, not running | Run `run_*.sh` against a disposable database |
| No deployment-parity check exists | A fixed function can stay broken in production (this is exactly SC-01) | CI step comparing deployed bundle hash/version against HEAD |
| No human audibility check | "Audio works" means "RTP flows", not "a person hears it" | Human listener on one live session |
| No two-device run for anything except audio | Video/location/geofence/suspension all rest on code | A device matrix per capability, same rigour as stage 8 |
| No push channel | Every "realtime" claim is polling latency | Feature work |
| Automated results dated 2026-10-29 | Tree has moved since | Re-run the four suites and record date + commit |

---

## 8. BLOCKED — could not be verified in this audit

| Item | Reason | Status |
|---|---|---|
| Kotlin unit test result | Environment (cross-drive Gradle), no test executed | **BLOCKED — ACCESS REQUIRED** (build environment) |
| SQL suite green status | Not executed here; no historical pass row | **BLOCKED — ACCESS REQUIRED** (disposable DB) |
| Hosted-vs-HEAD parity for all 9 Edge Functions | Only `remote-session` was read line-by-line from the dashboard; the other eight were compared by deploy timestamp only | **BLOCKED — DASHBOARD ACCESS REQUIRED** for byte-level comparison |
| Human audibility | No listener | **BLOCKED — ACCESS REQUIRED** (human) |
| Scheduler configuration for the `cron` function | pg_cron absent; no external scheduler visible in the dashboard | **BLOCKED — DASHBOARD ACCESS REQUIRED** (external scheduler, if any) |
| Repository visibility of the configured GitHub remote | No authenticated GitHub access | **BLOCKED — ACCESS REQUIRED** |

All six are marked BLOCKED rather than guessed. None of them is counted as a pass anywhere in
this audit.

---

## 9. Verdict on the evidence base

The repository has an unusually strong **audio** evidence chain — three live sessions, packet
counters, lifecycle matrix, failure analysis with timestamps — and an unusually weak chain
everywhere else. The honest summary:

- **One feature family (one-way audio) is runtime-verified**, and even it fails the endurance test
  for a deployment reason.
- **Thirteen features look complete and have never been seen working** on a device.
- **Two features are provably broken** in production right now.
- **111 subfeatures have no implementation at all**, verified by absence of code rather than by
  a failing test.

Any statement that the product "works except for bugs" would be unsupported. The defensible
statement is: *the microphone path works and is broken by deployment drift; nearly everything else
is either untested or absent.*