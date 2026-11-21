# 16 — Final Acceptance Scorecard

**Date:** 2026-11-21  
**Scope:** 126 discovered features (123 implemented), two devices, source + offline + limited live testing  
**Final verdict:** **C — MAJOR FUNCTIONAL GAPS**

---

## 1. Final verdict

# C — MAJOR FUNCTIONAL GAPS

The app has a broad, coherent implementation and a strong static/offline test floor, but the core two-device promise fails: a running child is shown Offline with 187-hour-old data because of a device-credential mismatch and the absence of a re-credentialing path. Multiple secondary features are blocked by that same fault, and two visible consistency defects remain.

This is not D (blocked by safety/environment) because enough was executed to establish major functional gaps. It is not B (partially verified) because core synchronization and several controls are not merely unverified — they are broken or missing.

---

## 2. Feature coverage (primary)

Coverage = tested features / implemented features × 100.  
Tested includes PASS and FAIL; BLOCKED, NOT_TESTED, AUTHORIZATION_REQUIRED, PLATFORM_LIMITED and NOT_IMPLEMENTED are not counted as tested.

| Category | Implemented | Tested | Pass | Fail | Blocked | Not tested | Auth required | Platform limited | Coverage |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Parent features | 64 | 21 | 17 | 4 | 0 | 27 | 16 | 0 | **32.8%** |
| Child features | 41 | 20 | 15 | 5 | 6 | 10 | 3 | 2 | **48.8%** |
| Shared/backend | 18 | 17 | 17 | 0 | 0 | 1 | 0 | 0 | **94.4%** |
| **Total** | **123** | **58** | **49** | **9** | **6** | **38** | **19** | **2** | **47.2%** |

Not implemented: 3 (C11 re-credentialing, C30 bedtime enforcement, C31 emergency pass).  
Shared/backend “tested” means source + offline contract/SQL verification, **not** live production calls.

### Live/direct-runtime coverage

| Metric | Value |
|---|---:|
| Live/direct-runtime tested features (Parent + Child) | 41 |
| Implemented features | 123 |
| Live coverage | **33.3%** |

This deliberately excludes the 17 shared/backend contract features, which were not exercised against production.

---

## 3. Cross-cutting probe coverage (secondary)

These are independent probe counts from reports 06–13; do not add them to the feature totals.

| Area | Probes defined | Executed (PASS+FAIL) | Pass | Fail | Coverage |
|---|---:|---:|---:|---:|---:|
| Authentication/session | 15 | 7 | 7 | 0 | 46.7% |
| Device identity/heartbeat | 14 | 12 | 7 | 5 | 85.7% of implemented |
| Permissions/capabilities | 12 | 11 | 9 | 2 | 91.7% |
| Policy sync/enforcement | 17 | 8 | 6 | 2 | 53.3% of implemented |
| Location/usage/alerts | 30 | 6 | 4 | 2 | 23.1% of implemented |
| Cross-device | 15 | 12 | 6 | 6 | 80.0% |
| Lifecycle/reliability | 10 | 6 | 4 | 2 | 60.0% |
| API/backend contracts | 37 | 0 live (37 static) | 37 static | 0 | live 0% / contract 100% |

---

## 4. Scenario execution summary

Defined probe rows across parent, child, cross-device, auth, identity, permissions, policy, location/usage/alerts, API and lifecycle: **195**.  
Executed scenario rows: **107** (54.9%). Of those:

| Result | Count |
|---|---:|
| PASS | 77 |
| FAIL | 30 |

The 30 failures include both genuine defects and expected stale/permission checks that the product did not satisfy. A passing feature summary never overrides a failed scenario.

Notable failed scenarios:

- stale child presence shown as Offline;
- duplicate revoked device row;
- policy version v2 vs v4;
- permission warning contradicts Android grants;
- location service not running;
- no re-credentialing after reinstall;
- no bedtime enforcement;
- no emergency pass;
- no push delivery.

---

## 5. Category scorecard

| Category | Result | Notes |
|---|---|---|
| Parent features | **Major gaps** | 17 pass / 4 fail / 27 untested / 16 gated |
| Child features | **Major gaps** | 15 pass / 5 fail / 6 blocked / 10 untested / 2 platform-limited / 3 not implemented |
| Cross-device | **Fail** | Identity/family agree; presence, freshness, policy, permissions do not |
| Authentication/session | **Partial** | Existing sessions pass; fresh login/expiry untested |
| Device identity/heartbeat | **Fail (P1)** | Credential mismatch blocks all device telemetry |
| Permissions | **Partial** | Most states correct; location warning inconsistent |
| Policy management | **Partial** | Honest ack reporting; version presentation inconsistent; child sync blocked |
| Location | **Blocked / fail** | Service not running; upload auth-blocked; no map |
| Screen time / app restrictions | **Partial** | Code and offline tests exist; live path blocked; Device Owner required for suspension |
| Alerts / notifications | **Partial** | Existing alerts render; no push; no new alert generation tested |
| API/backend contracts | **Strong static** | 37 contract actions; 209 Deno + 33 SQL files; no live call |
| Lifecycle/reliability | **Partial** | FGS stable, no crash/ANR; network/reboot/lock untested |

---

## 6. Automated test floor

| Suite | Result |
|---|---|
| `fvm flutter analyze` | 0 issues |
| `fvm flutter test` | 493/493 |
| Deno | 209/209 (earlier in session) |
| SQL chain | 33 files, 0 errors/assertion failures, all explicit PASS notices |
| Kotlin JVM | BLOCKED (mixed-drive Gradle) |
| Integration tests | 4 files, not run |

A strong test floor does not override the live P1.

---

## 7. Release-blocking items

1. **E2E-001 / GAP-01 (P1):** device credential mismatch; no re-credentialing path.
2. **GAP-02/GAP-03:** bedtime enforcement and emergency pass absent.
3. **GAP-04:** no push notification channel.
4. **E2E-002/E2E-003/E2E-004 (P2):** revoked-device listing, policy-version presentation, permission-warning inconsistency.
5. **GAP-06:** build provenance and release signing unresolved.
6. **Device Owner hardware validation:** suspension/quota cannot be proven on the current child device.

---

## 8. What the owner can now see

- **What exists:** 126 features across parent, child and backend, with source references.
- **What was tested:** 58 features and 107 scenario probes directly executed (static, offline or live).
- **What passed:** 49 features / 77 scenarios.
- **What failed:** 9 features / 30 scenarios; the P1 is the dominant failure.
- **What remains unverified:** 38 features not tested, 6 blocked, 19 authorization-required, 2 platform-limited.
- **What requires authorization:** all production writes, re-credentialing, recovery, pairing, policy saves, remote sessions, account export/delete, network/lifecycle manipulation.
- **What must be fixed before release:** the P1 credential path, bedtime/emergency pass, push, the three P2 UI/data defects, release signing/provenance, and Device Owner validation.

---

## 9. Final statement

**C — MAJOR FUNCTIONAL GAPS.** The application is not release-ready. The core parent-visibility path is broken on the installed build, and several control features are absent or unverified. The correct next step is a separately authorized remediation phase focused first on credential re-issuance and a fresh-build two-device re-test.
