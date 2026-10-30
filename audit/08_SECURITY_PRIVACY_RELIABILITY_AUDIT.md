# 08 — Security, privacy and reliability audit

Read-only audit. No application source, migration, Edge Function, hosted object, secret or
database record was modified. Supabase was inspected **only** through the web dashboard
(`SELECT`-only SQL Editor + metadata pages); the Supabase CLI was never invoked.

Primary evidence: `audit/_work/s10-security-platform-evidence.md` (full finding set with line
citations), `audit/_work/s5-hosted-supabase.md` (live dashboard state), the runtime reports in
`docs/`, and spot re-verification of the claims that drive a verdict in this document.

Severity scale used below is impact × likelihood on the current deployed state, not on repo HEAD:
**Critical** = already causing user-visible failure in production; **High** = exploitable or
data-destructive with a plausible path; **Medium** = real but conditional; **Low** = defence
hygiene; **Info** = context.

---

## 1. Findings

| # | Sev | Area | Finding |
|---|---|---|---|
| SC-01 | **Critical** | Session lifetime | Hosted `remote-session` is the pre-fix build running against the post-fix schema. Consent writes `expires_at = accepted_at + 30 min`; the next `start`/`ice`/`media` call evaluates the deadline and returns HTTP 410 `session_expired`. Reproduced end-to-end on 2026-10-29 (F1: flip at 12:16:38.393Z, media torn down 144 ms later). The parent UI simultaneously says "Until you end the session". |
| SC-02 | **High** | Session lifetime | No upper bound and no watchdog for accepted/active rows. `expire_stale_sessions()` only touches `status='requested'`; `request_remote_session()` refuses to clean up a consented row; pg_cron is absent on the host so nothing sweeps. An abandoned session (parent crash, network loss, child process kill — F5 left a row `active`) blocks new requests for that device indefinitely and keeps the child mic service eligible to run. |
| SC-03 | **High** | Capability honesty | "Request video" is offered and the consent sheet promises the camera opens, but the only foreground service is typed `microphone`; there is no `FOREGROUND_SERVICE_CAMERA` permission or `camera` FGS type. With targetSdk 36, camera capture outside the foreground is blocked by Android, so video can only work while the child keeps the session screen visible. Zero runtime evidence for video in any stage. |
| SC-04 | **High** | Authorization | `purge_data` irreversibly deletes `location_events` and `usage_daily` for the whole family, but is authorized with `assertFamilyParent`, not owner. Any second parent can destroy history down to the retention floor; only `update_retention` requires the owner. |
| SC-05 | **Medium** | Privacy lifecycle | No account-deletion and no data-export path exists. The only auth teardown is `signOut()`; nothing calls `auth.admin.deleteUser` or deletes a family. Deletion is only implicit through the `profiles → auth.users` cascade, which no client can trigger. Play and GDPR both require an in-app route. |
| SC-06 | **Medium** | Privacy lifecycle | Retention is policy text, not enforcement. `purge_data` is manual, only covers two tables, and has no scheduler. `safety_alerts`, `audit_logs`, `remote_sessions` and `webrtc_signals` are never purged, so raw coordinates and audit rows accumulate indefinitely. |
| SC-07 | **Medium** | Accountability | Audit trail gaps on every automatic transition. `expire_stale_sessions()` and the hosted expiry path write no `audit_logs` row; neither does `detect_offline_devices()`. The F1 session has only requested/accepted/started — a parent cannot prove when or why a session ended. |
| SC-08 | **Medium** | Authorization depth | `SECURITY DEFINER` RPCs take the acting parent as a **parameter** and perform no authorization of their own: `request_remote_session(p_parent_user_id)` inserts whatever id is passed without checking that the id is a parent of `device.family_id`. Same pattern for `revoke_device`, `unlink_child`, `apply_policy_version`. Mitigated today by service-role-only grants; one server-side bug or leaked service key yields direct impersonation. |
| SC-09 | **Medium** | Alerting | Permission revocation is visible on the child UI but never raises an alert. `safety_alerts.type` allows `permission_missing` yet no producer exists, so a parent keeps seeing a healthy device after location/mic/usage access is withdrawn. |
| SC-10 | **Medium** | Token storage | Session tokens persist through `supabase_flutter` defaults (SharedPreferences, unencrypted). `flutter_secure_storage: ^11.2.0` is declared at `pubspec.yaml:40` but has **zero** references in `lib/`; no `authOptions`/`autoRefreshToken` configuration exists. `allowBackup=false` limits extraction, but a rooted device or debug backup exposes refresh tokens. |
| SC-11 | **Low** | Signaling privacy | `webrtc_signals` rows (SDP + ICE, up to 16 KB, containing local/public IPs) are readable by **any** family parent, not only the two participants, because `remote_sessions` SELECT is family-parent-wide and the realtime topic predicate is `is_family_parent`. A co-parent can subscribe to `webrtc-signals:<session>` for another parent's call in the same family. |
| SC-12 | **Low** | Repo hygiene | Two `.tools/` artefacts are tracked despite `.gitignore:16` (`.tools/`): `.tools/live_config.env` (contains `SUPABASE_URL` and `SUPABASE_ANON_KEY` key names only — publishable by design) and `.tools/deploy/remote-session.ts` (the stale production bundle). A GitHub remote is configured (`https://github.com/Shivadatt/parental_control.git`); **repository visibility was not verified**, so treat the anon key as public until confirmed. No service-role key, TURN secret or JWT literal was found in tracked files. |
| SC-13 | Info | Auth surface | Otherwise sound: JWT verified server-side for every user action, verified email required, role checked against `profiles.role`, device identity is `x-device-id` + `x-device-secret` compared with a constant-time SHA-256, revoked devices rejected, `secret_hash`/`installation_id` excluded from client column grants, and parent-only Edge actions re-check family parent membership. |
| SC-14 | Info | Reliability | No TURN relay is configured (`relay 0`), so sessions rely on host/srflx candidates and fail on CGNAT/strict firewalls. Not a security defect; a hard limit on every remote-media feature. |

Counts: **Critical 1, High 3, Medium 6, Low 2, Info 2 = 14.**

---

## 2. Authentication and authorization boundary

What holds (verified in code and consistent with hosted grants):

- **Transport of identity.** Every user action goes through an Edge Function that verifies the
  Supabase JWT server-side; the `anon` role has **zero** table privileges on the hosted project,
  and `authenticated` has `SELECT` on 15 tables plus `INSERT` on `webrtc_signals` and `DELETE` on
  `safe_zones` only.
- **Role lock.** A child cannot promote itself: `profiles.role` is written by `auth-bootstrap`,
  parent-only Edge actions call `requireRole(auth.profile, "parent")`, and the role is re-read
  from the database rather than trusted from the token.
- **Device identity.** The child device presents `x-device-id` and `x-device-secret`; the server
  hashes and compares in constant time, rejects revoked devices, and never returns `secret_hash`
  or `installation_id` to clients.
- **RLS coverage.** 19/19 tables have RLS enabled and 22 policies, all scoped `TO authenticated`.
  Family-scoped policies consistently route through `private.is_family_parent` /
  `private.is_family_member` / `private.shares_active_family`.

What does not hold:

- **Defence in depth on RPCs (SC-08).** Mutating RPCs are service-role-only, so the app cannot
  abuse them directly — but they trust a caller-supplied parent id. This is a single-fault
  design: the day a function forwards a spoofable id, impersonation is direct. The authorization
  that actually protects these actions lives entirely in TypeScript (`_shared/auth.ts`).
- **Destructive-action symmetry (SC-04).** Read/write split by role is right; destroy-by-any-parent
  is not. A guardian invited as a peer parent has the same purge power as the owner over data
  they did not create.
- **Session scope vs. family scope (SC-11).** `remote_sessions` and `webrtc_signals` are scoped to
  the family, not to the two participants, for parent readers. That is defensible for session
  metadata, questionable for raw ICE candidates.

---

## 3. Session lifetime and reliability

The central defect is deployment drift, not design. Three independent sources agree:

| Evidence | State |
|---|---|
| Schema (dashboard) | `remote_sessions.expires_at` nullable; `remote_sessions_pending_expiry_check` requires a deadline only while `status='requested'`; transition guard blocks only terminal→live; `expire_stale_sessions()` updates only `status='requested'`; signaling RLS has no `expires_at` test |
| Repo HEAD | `remote-session/index.ts` matches the schema (no 30-min stamp, no 410 on `ice`/`start`) |
| Hosted function (dashboard Code tab) | Old bundle: `Q = 30*60*1e3`, accept writes `expires_at = accepted + 30 min`, `active`/`ice` throw 410 `session_expired`, `end` is participant-only |
| Live data (dashboard) | 45 rows, 10 newest shown: **all 35 `ended` rows carry a non-NULL `expires_at`**, 9 of 10 `expired` rows too; last activity 2026-10-29 13:46Z |

Consequence chain: every consented session gets a 30-minute deadline written by a function whose
schema partner no longer honours deadlines → the next client call after the deadline (or, for a
NULL deadline, the next call at all under the `new Date(null) <= now()` evaluation) kills media
mid-session → the UI claims the session runs until the parent ends it.

Compounding reliability defects, all observed rather than hypothesised:

| ID | Failure | Observed |
|---|---|---|
| F1 | Hosted 30-min expiry | Session flipped to `expired` at 12:16:38Z, media down 144 ms later; 15-minute endurance run ended at 8m14s |
| F2 | Guardian scheduler stall | Presence frozen for 42 minutes; single scheduler tick, no watchdog escalation |
| F3 | Presence window | Healthy child shows "Offline" for ~2 min of every 5-min heartbeat cycle (BUG-038, still open) |
| F4 | No TURN | `relay 0`; host/srflx only |
| F5 | OEM task removal | ColorOS swipe-away left a session row `active`; cap on orphan lifetime is SC-02 |
| F6 | Biometric lock | Child re-launch after screen lock required re-entry before media could resume |

With no pg_cron and no watchdog, F1/F2/F5 failures are all *silent*: nothing in the system
escalates a stalled or orphaned session, and the only recovery is the parent manually ending it
or the child force-stopping the app.

---

## 4. Privacy and data lifecycle

| Data class | Where it lives | Retention today | Deletion path | Concern |
|---|---|---|---|---|
| Location fixes | `location_events` (1,633 rows at audit time) | `location_retention_days` (default 30) as a *policy value*; purge is manual | `purge_data` (any parent, SC-04) | Raw coordinates accumulate if nobody runs purge; no scheduler (SC-06) |
| App usage | `usage_daily` | `usage_retention_days` (default 90), same manual path | `purge_data` | Same |
| Safety alerts | `safety_alerts` | none | none | Never purged |
| Session metadata | `remote_sessions` (45 rows) | none | none | Never purged; includes `session_nonce` |
| Signaling payloads | `webrtc_signals` (1,292 rows) | none | none | SDP/ICE retained indefinitely, contains IPs (SC-11) |
| Audit trail | `audit_logs` (236 rows) | none | none | Append-only trigger prevents edits, but nothing ages rows out |
| Device secret | `devices.secret_hash` + on-device EncryptedSharedPreferences | until revoke | revoke writes `credential_revoked_at` | Correct |
| Auth identity | `auth.users` / `profiles` | none | **no path** (SC-05) | No account deletion, no export |

Consent handling is a genuine strength and should be preserved: `consent_recorded` is set only by
the child's accept, `ice`/`start` refuse without it, and the child sees a microphone foreground
notification while capture is live. The weakness is what happens *after* consent — lifetime,
alerting on revocation (SC-09), and the promise made in the video consent sheet (SC-03).

Privacy gaps that are product-blocking rather than cosmetic:

1. **No account deletion** (SC-05). Required by Google Play for any app with accounts.
2. **No data export** (SC-05). Required by GDPR/DPDP-style regimes on request.
3. **Retention not enforced** (SC-06). The settings screen offers a retention window that the
   system does not actually apply without a human pressing purge.
4. **Audit blindness on automatic transitions** (SC-07). The trail a parent would use to verify
   "who ended my child's session" has no row for the most common ending.

---

## 5. Build, deployment and secret hygiene

| Item | State | Risk |
|---|---|---|
| Release signing | `signingConfig = signingConfigs.getByName("debug")` (`android/app/build.gradle.kts:28-34`) | **Not shippable.** Debug key is publicly known; any build can impersonate updates |
| `allowBackup` | `false` (`AndroidManifest.xml:43`) | Correct for a monitoring app |
| Auth callback activity | Exported with a custom `parentcontrol://auth-callback` scheme, no signature/package verification (`AndroidManifest.xml:46-48,68-75`) | Any installed app can deliver a crafted auth redirect |
| Certificate pinning | none; no `network_security_config` | MITM exposure limited to user-installed CAs; acceptable for now, worth pinning before public release |
| Cleartext | HTTPS enforced in code (`DeviceHttpClient.kt:19-30`) | OK |
| Logging of secrets | repo-wide zero `Log.` calls; device secret never printed | Good |
| Tracked secrets | `.tools/live_config.env` (URL + anon key only) and `.tools/deploy/remote-session.ts` (old bundle) are tracked | Anon key is publishable by design; the stale bundle is exactly how SC-01 escaped review |
| Service role key | not present in any tracked file; `env.dart:50-55` rejects `service_role` keys at build time | Good |
| Edge JWT verification | `remote-session` has `verify_jwt` ON (dashboard Settings page); the other eight enforce auth in code, their platform toggle state was not read | Low — code-level checks are present |
| CORS | wildcard `Access-Control-Allow-Origin: *` (`supabase/functions/_shared/cors.ts:3`) | Low — auth is a bearer token, not a cookie, so CSRF-style abuse is not possible; any web origin can still call the functions with a stolen token |

The tracked stale bundle is worth calling out as a process finding: the file that proves the
deployed function is wrong was committed to the repository, and no CI check compares deployed
code against HEAD. That is the mechanism behind SC-01, and it will reproduce for any future
function unless a deploy-parity check exists.

---

## 6. Android platform security and capability honesty

Every capability claim must survive two tests: the permission exists, **and** the OS allows it in
the state the feature runs in.

| Claim | Permission present | Runtime actually possible | Verdict |
|---|---|---|---|
| Background microphone | `RECORD_AUDIO` + `FOREGROUND_SERVICE_MICROPHONE` + `microphone` FGS type | Yes; proven up to 8m14s, killed only by SC-01 | Holds (subject to SC-01) |
| Background camera / "request video" | `CAMERA` present; **no** `FOREGROUND_SERVICE_CAMERA`, no `camera` FGS type | Only while the child keeps the session UI foregrounded | **Overstated** (SC-03) |
| Screen mirroring | no `MediaProjection`, no mediaProjection FGS type | Not possible | Absent (correctly absent from UI) |
| App blocking | Device Owner `setPackagesSuspended` only | Requires provisioning that no flow performs; without it the app reports "no longer Device Owner" and cannot restore | **Partially honest** — the ack path can claim enforcement it cannot guarantee |
| Bedtime / downtime | none (policy JSON only) | Not enforced; child UI says "informational only" | Honest in child UI, misleading in parent copy |
| Notifications read | `BIND_NOTIFICATION_LISTENER_SERVICE` absent | Not possible | Absent |
| Call/SMS | no `READ_CALL_LOG`/`READ_SMS` | Play-restricted even if added | Absent |
| Web filtering | no `VpnService` | Not possible | Absent |

Native-side positives worth keeping: device secret in `EncryptedSharedPreferences`, no plaintext
logging anywhere, `allowBackup=false`, foreground-service notification is the real consent
indicator, and the guardian/heartbeat design survives task removal (only force-stop kills it).

Native-side negatives beyond SC-03: `QUERY_ALL_PACKAGES` (`AndroidManifest.xml:28`) is a
Play-restricted permission that will require a declared justification at review; and the
`PACKAGE_USAGE_STATS` grant is a special access the app can only request, never self-grant.

---

## 7. Reliability posture by subsystem

| Subsystem | Current guarantee | Worst observed failure | Silent? |
|---|---|---|---|
| Remote audio | Duration unbounded in schema, 30 min in deployed function | Killed mid-call at deadline (F1) | No — parent sees "ended" |
| Session cleanup | Pending requests expire in SQL; consented rows never | Orphan row `active` blocks device (F5/SC-02) | **Yes** |
| Presence | 5-min heartbeat + 6-min client window | 42-min freeze (F2); 2-min false Offline (F3) | **Yes** |
| Command delivery | 20-s poll from guardian; realtime for some tables | Stalled tick delays policy/app commands | **Yes** |
| Location | FGS upload, server-side geofence evaluation | No runtime fix recorded in stage 8 | **Yes** (no alert) |
| Alerts | Inserts + realtime + ack | Only low battery, geofence, offline producers | **Yes** (missing types) |
| Push notifications | none — everything is polling | Parent learns of requests only while the app is open | **Yes** |
| Data retention | manual purge only | Data never ages out | **Yes** |

The pattern is consistent: the system degrades by going quiet. There is no watchdog that turns a
stalled subsystem into a visible, audible or alertable state, and there is no push channel that
could deliver one while the app is closed.

---

## 8. BLOCKED — verification that could not be completed

| Item | Why blocked | What would unblock |
|---|---|---|
| Auth protection toggles beyond what the dashboard surfaces (leaked-password protection, redirect allowlist, refresh-token reuse interval) | The dashboard Auth pages show providers, user sessions and JWT keys, but the protection toggles were not all read | Not asserted; re-check in Auth → Settings |
| Repository visibility of the configured GitHub remote | No authenticated GitHub API access in this audit | `gh repo view --json visibility` by the owner |
| Kotlin unit suite result | Cross-drive Gradle roots on this workstation; no test executes | Fix Gradle root layout, then `testDebugUnitTest` |
| SQL test suite green status | Suites exist but were not executed in this audit and no historical pass row exists | Run `supabase/tests/run_*.sh` against a disposable database |
| Human audibility of the audio session | No independent listener in the runtime run | A human on the parent device during a live session |
| Video, screen mirroring, notification, web-filter runtime behaviour | No code (mirroring/filtering) or no runtime run (video) | Feature work first, then device tests |

Everything else in this document is either code-cited or dashboard-observed.

---

## 9. Summary

**Strengths.** RLS is complete and correctly shaped; client grants are column-scoped; every
mutating RPC is service-role-only; device authentication is constant-time and revocable; consent
is enforced before capture; no secret leaks into logs, backups or the client; the schema's new
session-lifetime model is sound.

**The four things that actually matter, in order:**

1. **SC-01 — deploy the fixed `remote-session`.** One deployment closes the reproduced
   mid-session teardown. Nothing else in this document changes user experience as much.
2. **SC-02 — bound consented sessions.** Add a stale-session sweeper (pg_cron or a scheduled
   Edge invocation) plus a watchdog; without it every crashed call leaves the device blocked.
3. **SC-04 / SC-05 / SC-06 — make destructive and lifecycle actions safe and lawful.** Owner-only
   purge, account deletion, data export, enforced retention.
4. **SC-03 — stop promising the camera.** Either add the `camera` FGS type and a background video
   path, or change the request/consent copy to "screen must stay open".

The repository's security *design* is materially better than its deployment state. The audit's
severity distribution (1 Critical, 3 High) is driven almost entirely by drift between repo HEAD
and the hosted function, and by two Android capability claims the build cannot honour.