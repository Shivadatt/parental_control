# Phase 4 — Android device validation plan (parent emulator + child physical device)

Workstream: **F (device validation plan)**. This file is the **only** Phase-4 deliverable owned by
this workstream. The coordinator owns the other four `phase-4-*.md` documents. This is a **PLAN, not
an execution**: no APK was installed, no physical-device run was started, and no build was created
(builds remain the build owner's). Per the brief, device execution must not begin without explicit
authorization.

---

## 0. How to read this document, and the evidence discipline

**This plan asserts nothing about device behaviour as verified.** Every matrix row's *Actual result*
is intentionally **BLANK** and every *Status* is **`NOT RUN`**. The honest status of every row today
is `NOT RUN`. Some rows are additionally flagged **BLOCKED today** because a precondition or a
platform/approval gate prevents them from being executed even once the run is authorized; that flag
lives in the row's `Gate` field and in §6, and never changes the Status away from `NOT RUN`.

Status vocabulary (used consistently, same as `docs/implementation/phase-3-report.md:11-17`):

| Token | Meaning in this plan |
|---|---|
| `NOT RUN` | The honest status of every row. Not executed; this is a plan. |
| `PASS` / `PASS (SCOPED)` | Reserved for the future executor; may only be written with the row's named evidence artifact captured. Never pre-filled here. |
| `MITIGATED` | Reserved. A compensating behaviour exists but the primary assertion is not proven. |
| `BLOCKED` | Reserved for the Gate column / §6 only: cannot be attempted today (approval, revoked link, missing relay, Kotlin/JVM gap). Not a device result. |
| `STOPPED` / `AWAITING OWNER` | Reserved for owner-decision rows (e.g. hosted deployment). |
| `NOT RUN (BLOCKED today: <reason>)` | Row status stays `NOT RUN`; the parenthetical names the gate. |

Any claim in this plan about **what prior phases actually observed on devices** carries a
`file:line` citation to a document I read (see §8). Prior observations are context for *why a row
exists and what a truthful failure looks like*; they are **not** results for these rows.

Grounding I read (representative): `docs/implementation/phase-3-report.md:199-217` (Kotlin/JVM
limits), `docs/implementation/_work/p3-followups.md:149-201` (§5 KOT-01, §6 KOT-02),
`android/gradle.properties:5-9` (the committed `kotlin.incremental=false` and its cause),
`docs/runtime-device-matrix.md` (device IDs, accounts, foreground-service ids, session end reasons),
`docs/stage5_background_audio_survival_report.md:141-155`, `docs/stage6_account_and_media_recovery_report.md:19-53`+`:213-250`,
`docs/stage7_two_device_end_to_end_report.md:243-289`, `docs/two-device-e2e-checklist.md`,
`docs/mic-lifecycle-test-plan.md:44-60`, `docs/verification-report.md:128-142`,
`docs/bug-report.md:191-209`, `docs/runtime-failure-analysis.md:20-143` (F0–F6, E1),
`docs/implementation/api-contract.md`, `docs/implementation/feature-ownership.md`,
`docs/implementation/_work/p3-enforcement-correlation.md`, `docs/implementation/_work/p3-audit-atomicity.md`.

---

## 1. Preflight checklist (must be satisfied before any row leaves `NOT RUN`)

Record each item's actual value in the run log; do not assume a value from this plan. Nothing here
was executed — it is the checklist a future executor fills in.

| Item | Required value | Source (read, not invented) |
|---|---|---|
| Parent device | Emulator serial `emulator-5554`; AVD model `sdk_gphone64_x86_64` (Pixel 9a AVD), Android 17 / API 37, ABI `x86_64` | `docs/runtime-device-matrix.md:11-16`, `docs/mic-lifecycle-test-plan.md:11` |
| Child device | Physical serial `5HXWRGQ4IFU8WS4T`, model `RMX2161` (realme 7), Android 12 / API 31 (ColorOS), ABI `arm64-v8a` | `docs/runtime-device-matrix.md:11-16`, `docs/runtime-failure-analysis.md:9-12` |
| Roles | Parent = emulator, Child = physical; **never swapped** | `docs/runtime-device-matrix.md:20`, `docs/mic-lifecycle-test-plan.md:14` |
| QA accounts (documented, verifiable) | Parent = QA Family A parent on `emulator-5554`; Child = `qa.child.a2.20261026@example.com` (family "QA Family A", device registered) | `docs/stage6_account_and_media_recovery_report.md:33-39` |
| QA account secret names (values NEVER read) | env keys `PARENT_A_USER/PARENT_A_PASS/PARENT_A_ID`, `CHILD_A_USER/CHILD_A_PASS/CHILD_A_ID` (B/C variants exist) | `.tools/qa_accounts.env` (key names only; passwords never printed) |
| Requested `ankit` accounts | `ankit@gmail.com` / `ankit1@gmail.com` — **BLOCKED/unverified**, not present in the repo, Dashboard-only | `docs/stage6_account_and_media_recovery_report.md:19-28`; `docs/mic-lifecycle-test-plan.md:11-12` records them signed-in at run time only |
| Dart-defines / config | Build must inject `SUPABASE_URL` + `SUPABASE_ANON_KEY` via `--dart-define-from-file`; the ONLY required client keys | `scripts/check_live_config.sh:27`, `scripts/build_debug_apk.sh:60`, `docs/verification-report.md:147-149` |
| Build command (owned by build owner — do not run here) | `bash scripts/build_debug_apk.sh`; verify the `hhqgreaoqulmfwfwarhc` config literal is present in `kernel_blob.bin` before install | `docs/runtime-failure-analysis.md:25-28` (F0: an unconfigured APK silently invalidated a window) |
| Backend under test | Hosted `parent-control-prod` (ref `hhqgreaoqulmfwfwarhc`); `remote-session` bundle is the **pre-fix** build — accepted sessions still get `expires_at = accepted_at + 30 min` | `docs/runtime-failure-analysis.md:35-56` (F1); `docs/implementation/phase-3-report.md:221` |
| Deployed-vs-repo skew | `20261028000200` + `20261028000300` (nullable expiry + signaling) and the three `20261030000*` Phase-1 migrations are **repo-only, not deployed** | `docs/stage6_account_and_media_recovery_report.md:152-160`; `docs/implementation/phase-3-report.md:231-237` |
| Device links state | At last record **all three QA devices were `Revoked`**, last seen ~2 days ago → no active session could be created | `docs/stage6_account_and_media_recovery_report.md:221-228` |
| Notification channels | `guardian_status` id 4101 (child `GuardianService`, `START_STICKY`); `audio_assistance_channel` id 4303 (child `AudioAssistanceService`) | `android/.../GuardianService.kt:36-37,170`; `android/.../AudioAssistanceService.kt:76-77`; `docs/runtime-device-matrix.md:73-74` |
| realme channel importance | `audio_assistance_channel` observed importance `NONE` → ongoing notification not visible though the FGS ran; **do not change silently** | `docs/stage5_background_audio_survival_report.md:175-178`; `docs/stage6_account_and_media_recovery_report.md:259-263` |
| Power state | Battery optimisation NOT whitelisted; battery saver off; standby bucket ACTIVE(5) on child — left at defaults | `docs/runtime-device-matrix.md:66-68`; `docs/mic-lifecycle-test-plan.md:35` |
| Orphan row hygiene | Pre-existing open session `e84ba35e-d8c6-4573-a5a5-c02fa849a9f9` must be closed by parent **End session** from a device that lists it; never edit/delete in SQL | `docs/mic-lifecycle-test-plan.md:39-42`; `docs/two-device-e2e-checklist.md:65-67` |
| Evidence folder | New artifacts to `docs/evidence/phase4/<section>/<row>-<actor>-<state>.png` (naming pattern follows `docs/two-device-e2e-checklist.md:90`) | `docs/two-device-e2e-checklist.md:82-95` |
| Logcat filter | Sanitized `adb logcat` filtered `parent_control|RemoteSession|WebRtc|AudioAssist`; **never** paste tokens/JWTs/keys | `docs/mic-lifecycle-test-plan.md:55`; `docs/two-device-e2e-checklist.md:92-93` |
| Service state capture | `adb -s 5HXWRGQ4IFU8WS4T shell dumpsys activity services com.parentcontrol.parent_control` and `dumpsys audio` (capture client must name the package) | `docs/mic-lifecycle-test-plan.md:49-51` |
| DB inspection | Supabase Dashboard SQL Editor, **read-only only**; no writes, no `supabase` CLI | `docs/implementation/feature-ownership.md:65-69`; `docs/two-device-e2e-checklist.md:73-80` |

**Ownership note.** The Kotlin enforcement/watchdog files and the two native services are owned by
the presence/enforcement/audio/android workstreams (`docs/implementation/feature-ownership.md:16-21`).
This plan exercises them only through the app UI and read-only server rows; it proposes no code
change. Kotlin JVM test results remain `BLOCKED — environment` and must not be claimed as a pass
(`docs/implementation/feature-ownership.md:82-84`, `phase-3-report.md:199-217`).

---

## 2. Privacy and safety invariants (a row that needs a bypass is invalid by definition)

These are absolute. If executing a row would require any of the following, **STOP the row and mark
it invalid / AWAITING OWNER** — do not find a workaround.

1. **Permission prompts are never bypassed.** `RECORD_AUDIO`, `FOREGROUND_SERVICE_MICROPHONE`,
   `POST_NOTIFICATIONS`, location, and any device-admin/device-owner grant are requested through the
   real Android system dialog. The app has no path that skips them
   (`android/.../AudioAssistanceService.kt:83,254` refuses mic capture when notifications are not
   granted — `notification_permission_required`). A row must exercise that refusal, not defeat it.
2. **Android privacy indicators are never suppressed.** The green mic indicator and the ongoing FGS
   notification are OS-owned. The app must not fake, delay past the OS gate, or hide them
   (`docs/stage5_background_audio_survival_report.md:99-106,175-178`). Truthful UI is required even
   when the realme channel importance hides the notification shade.
3. **Force-stop and process-death semantics are never worked around.** Force Stop, Recents kill,
   OEM task cleaners and process death **end media** and this app does not and cannot bypass them;
   the session correctly stays open server-side for an explicit rejoin
   (`docs/stage5_background_audio_survival_report.md:186-193`; `docs/stage6_...:252-253`;
   `docs/runtime-failure-analysis.md:100-108` F5). `AudioAssistanceService` is `START_NOT_STICKY` by
   design so no zombie microphone is left (`stage5:84-95`).
4. **User controls are never overridden.** The child's *Stop sharing* (withdraw consent) is honoured
   immediately and releases mic/FGS without ending the server session; only the **parent** can end a
   session (`docs/implementation/api-contract.md:136`; `remote-session end` is parent-only, `403` for
   child). The child cannot be denied the stop, and the parent cannot be silently disallowed from
   ending. The background service must not end media on a user's behalf
   (`android/.../GuardianService.kt:456-460`: `end_session` returns `failed` — media is owned by the
   visible assistance screen).
5. **No silent settings changes.** Channel importance, battery optimisation, OEM auto-start/freeze,
   and lock-screen state are left at their defaults or restored after being used as a temporary test
   aid; any change is recorded (`docs/stage5_...:173-182`; `docs/mic-lifecycle-test-plan.md:35`).
6. **No credential/token handling.** Passwords, JWTs, device secrets, anon/service keys, TURN secrets
   are never read, printed, logged, committed, or pasted into evidence
   (`docs/mic-lifecycle-test-plan.md:14-15`; `docs/stage6_...:53`; `docs/two-device-e2e-checklist.md:93`).
7. **No hosted mutation to "make a test pass".** No Edge Function deploy, no `supabase db push`, no
   dashboard DDL, no secret/auth edit; SQL Editor is read-only
   (`docs/implementation/feature-ownership.md:65-69`). If a row cannot pass without a deploy, the row
   is `BLOCKED` / `AWAITING OWNER`, not forced green.
8. **A report must never prove enforcement for the wrong policy.** Correlation is by
   `payload.policy_id` only; mismatched reports are shown only for the policy they name; absent/empty
   ids are labelled uncorrelated and `proves_enforcement == false`
   (`docs/implementation/_work/p3-enforcement-correlation.md:38-70`).

---

## 3. Ten brief-listed coverage areas → matrix section map

| # | Brief coverage area | Matrix section | Row prefix |
|---|---|---|---|
| 1 | Parent/child authentication and family association | §A | `AUTH-` |
| 2 | Pairing and unlinking | §B | `PAIR-` |
| 3 | Device presence and stale-device handling | §C | `PRES-` |
| 4 | Device command creation / delivery / acknowledgement / failure | §D | `CMD-` |
| 5 | Policy enforcement reporting and `payload.policy_id` correlation | §D | `ENF-` |
| 6 | Remote-session consent and visible-microphone foreground-service behaviour | §E | `SESS-` |
| 7 | Network interruption and reconnection (incl. TURN refresh) | §F | `NET-` |
| 8 | Permission revocation, notification visibility, user-controlled session stopping | §G | `PERM-` |
| 9 | Safe Zone create/delete incl. audit-write and compensation-failure path | §H | `ZONE-` |
| 10 | Backgrounding, process termination (recents, force stop) and restart | §I | `LIFE-` |

---

## §A — Parent/child authentication and family association (AUTH)

Context: `auth-bootstrap` actions `set_role` (write-once, `409` on re-set) and `create_family`
(`docs/implementation/api-contract.md:63-68`); role is server-verified, a local role field never
grants access (`docs/stage6_...:46-49`).

| ID | Preconditions | Steps | Expected result (falsifiable) | Actual result | Evidence required | Status |
|---|---|---|---|---|---|---|
| AUTH-01 | Parent emulator, no session, `SUPABASE_URL`/`ANON_KEY` compiled in; network up | 1. Launch app. 2. Sign in as parent QA account. 3. Reach Home. | Splash→login→Home completes; Home shows the family; **no "Connect the backend / SUPABASE_URL not set"** state (contrast F0 `runtime-failure-analysis.md:24`). |  | screenshot `AUTH-01-parent-home.png`; logcat filter §1 | NOT RUN |
| AUTH-02 | Child physical device, no session | 1. Launch. 2. Sign in as `qa.child.a2.20261026@example.com`. 3. Reach child Home. | Child Home restores the signed-in child; Requests tab reachable; account is not silently switched. (Baseline for this login seen in `stage6:218`.) |  | screenshot `AUTH-02-child-home.png` | NOT RUN |
| AUTH-03 | A brand-new (unset-role) account | 1. Register/sign in. 2. Choose role parent via existing flow. 3. Create family (name). | `set_role` succeeds first call; `create_family` returns a family row; role becomes visible server-side. |  | screenshot + read-only `profiles` row (role), `families` row | NOT RUN |
| AUTH-04 | Role already set on the account used in AUTH-03 | 1. Sign in. 2. Attempt to set a **different** role through the flow. | The second `set_role` is rejected (`409` write-once, `api-contract.md:67`); UI shows the existing role, does not lock the user out, does not corrupt the profile. |  | Edge Function log for `auth-bootstrap/set_role` (`409`) + screenshot | NOT RUN |
| AUTH-05 | Two devices, one family; email NOT yet verified | 1. Sign in on an unverified account. 2. Attempt a parent action that needs verified email. | `requireUser` (verified email) blocks the action; a `verify-email` path is shown; no family data leaks before verification (`api-contract.md:58-60`). |  | screenshot + read-only `profiles` | NOT RUN |
| AUTH-06 | Child in family A only | 1. Child signs in. 2. Inspect family/membership view. | Child sees exactly one family association; cannot read family B rows (RLS parent-or-child only, `api-contract.md:155-160`). |  | screenshot + read-only `family_members` | NOT RUN |

Section §A = **6 rows**, all `NOT RUN`.

---

## §B — Pairing and unlinking (PAIR)

Context: pairing freshness fixes D1/D2/D3 and the invite/pending flow are the documented matrix
(`docs/two-device-e2e-checklist.md:33-52`); `pairing` actions at `api-contract.md:70-83`; Child ID is
permanent, `PC-XXXXXXXX`, service-role only (`api-contract.md:161`).

| ID | Preconditions | Steps | Expected result (falsifiable) | Actual result | Evidence required | Status |
|---|---|---|---|---|---|---|
| PAIR-01 | Parent signed in (AUTH-01), active family, **no** device links yet; **Gate:** requires re-pairing — links were `Revoked` (`stage6:221-228`) | 1. Devices tab → invite. 2. Note Child ID / invite form. | Child ID shown; invite form accepts a `PC…` id (`api-contract.md:74-77`). |  | screenshot `PAIR-01-parent-invite.png` | NOT RUN (BLOCKED today: all QA device links revoked — re-pairing needs owner/link decision `stage6:226-228`) |
| PAIR-02 | Child signed in, on Home, **no pull-to-refresh** | 1. Open child app. 2. Read Child ID on child screen. | Child's displayed Child ID equals the one the parent typed (`two-device-e2e-checklist.md:39`). |  | child screenshot within window | NOT RUN (BLOCKED today: same revoked-link gate) |
| PAIR-03 | Parent submitted invite; child does nothing | 1. Wait up to **20 s** on child Home without refreshing. | Pending invite appears automatically (D1 fix); no manual refresh needed (`two-device-e2e-checklist.md:41`). |  | screenshot timestamped <20 s; read-only `pairing_requests` row `pending_child` | NOT RUN |
| PAIR-04 | Invite pending on child | 1. Child taps Approve. | Child shows linked + confirmation; server records membership + device state via `respond` RPC (`api-contract.md:79`). |  | screenshot + read-only `family_members`,`devices` | NOT RUN |
| PAIR-05 | Child approved; parent on Devices tab, **no refresh** | 1. Wait up to **60 s**. 2. Watch pairing card up to **10 s**. | Device list shows child linked (D2) and pairing card auto-moves to approved (D3) (`two-device-e2e-checklist.md:43-44`). |  | two timestamped screenshots | NOT RUN |
| PAIR-06 | Linked; both apps force-stopped and relaunched | 1. Force-stop both. 2. Relaunch, sign in if needed. | Both show the same linked/approved state; **no re-pairing, no duplicate invite** (`two-device-e2e-checklist.md:45`). |  | screenshots both devices; read-only `pairing_requests` (one live row) | NOT RUN |
| PAIR-07 | Active linked child | 1. Parent → family/member → **Unlink child**. 2. Confirm. | `pairing.unlink` RPC runs (`api-contract.md:83`); child loses the link and any live session releases per §I; device row not orphaned active; re-pairing requires a fresh invite (`stage6:227-228`). |  | screenshot + read-only `family_members.status='removed'`,`devices.status` | NOT RUN |
| PAIR-08 | Stale/expired invite | 1. Let a pending invite exceed its `expires_at` untouched. 2. Child attempts to approve. | Expired invite cannot be approved (`pairing_requests` `expired`, `api-contract.md:217`); clear UI message; no half-linked membership. |  | screenshot + read-only `pairing_requests` | NOT RUN |

Section §B = **8 rows**, all `NOT RUN`.

---

## §C — Device presence and stale-device handling (PRES)

Context: `Device.syncHealth` `healthy`<12 min, `stalled`<30 min, `offline` otherwise
(`lib/data/models/device.dart:371,376,394,399`); `onlineWindow = 12 min`, `stalledWindow = 30 min`;
F3 fixed a 3-min window that structurally forced "Offline" (`runtime-failure-analysis.md:76-85`); F2
showed a poll/heartbeat freeze where `last_seen_at` froze while the FGS record stayed alive
(`runtime-failure-analysis.md:60-73`). Heartbeat cadence 5 min, command poll 20 s
(`android/.../GuardianService.kt:39,41`).

| ID | Preconditions | Steps | Expected result (falsifiable) | Actual result | Evidence required | Status |
|---|---|---|---|---|---|---|
| PRES-01 | Freshly linked child, foreground, network up | 1. On child Home read presence line. 2. On parent Devices read same device. | Child shows "Online · Last seen ~1 min ago"; `devices.last_seen_at` advances across ≥2 heartbeats (F3 runtime proof `runtime-failure-analysis.md:83`). |  | screenshots + read-only `devices.last_seen_at` at two times | NOT RUN |
| PRES-02 | Healthy device (last seen <12 min) | 1. Observe parent badge/label. | `syncHealth==healthy` → not stalled, not offline (`device.dart:394,399`); label "synced N min ago" (`device.dart:410`). |  | screenshot | NOT RUN |
| PRES-03 | Device with last seen between 12 and 30 min | 1. Observe parent label. | Shown as **"Sync stalled"** (its own visible state), **not** "Offline" (`device.dart:49,52,401,411`; `device_detail_controller.dart:49`). |  | screenshot + read-only row with engineered `last_seen_at` | NOT RUN |
| PRES-04 | Device last seen >30 min | 1. Observe parent label. | Shown **Offline** / "last seen N h ago" (`device.dart:412`); a stale "Session active" is never co-shown as live with Offline without the honest banner (contrast F2 `runtime-failure-analysis.md:66`). |  | screenshot + read-only row | NOT RUN |
| PRES-05 | `last_seen_at` IS NULL (registered, never synced) | 1. Inspect device card. | Shows **"Never synced"** — not a fake age, not "0 min ago" (`device.dart:407,423`; `device_detail_page.dart:212`). |  | screenshot | NOT RUN |
| PRES-06 | Guardian poll/heartbeat freeze simulation | 1. Note "Last command check" in child Settings and `last_seen_at`. 2. Compare to a live `ServiceRecord`. | If heartbeat stops, presence must go stalled/offline honestly rather than "Online with a stale row"; FGS `isForeground=true` alone must NOT be reported as presence-fresh (F2 `runtime-failure-analysis.md:60-67`). |  | read-only `devices.last_seen_at` + `dumpsys activity services` + child Settings screenshot | NOT RUN (Kotlin-side root cause unverifiable — see §6) |

Section §C = **6 rows**, all `NOT RUN`.

---

## §D — Device commands + policy enforcement correlation (CMD / ENF)

Context: `device-command` actions `create`/`poll`/`ack`; ack body is exactly
`{action, command_id, status, result}` with **no** `policy_id` (`android/.../GuardianService.kt:sendAck`
`api-contract.md:111`); only `payload.policy_id` (written by `apply_policy_version`) identifies a
policy (`p3-enforcement-correlation.md:38-46`); server gates on `isUuid(policyId)` before marking
(`:24`). Client correlates matched/mismatched/uncorrelated (`lib/data/models/policy_enforcement.dart:117-125,174-185`);
banner strings at `lib/features/app_restrictions/app_restrictions_page.dart:298,337-347,355,373`.
Command types: `apply_policy|sync_policy|request_usage|request_location|end_session|custom`
(`api-contract.md:113`).

| ID | Preconditions | Steps | Expected result (falsifiable) | Actual result | Evidence required | Status |
|---|---|---|---|---|---|---|
| CMD-01 | Parent saves an app-restriction policy for a linked device | 1. Toggle apps → Save. | `device-policy update` → `apply_policy_version` inserts one `device_policies` row **and** one `apply_policy` command with `payload.policy_id/version` in one txn (`p3-enforcement-correlation.md:9-12`). |  | read-only `device_commands` row (`payload.policy_id`), `device_policies` row | NOT RUN |
| CMD-02 | Command pending; device online | 1. Wait up to ~20 s (one poll). | `poll` marks the command `delivered`; `pollCommands` runs then `handleCommand` (`android/.../GuardianService.kt:360-372`). |  | read-only `device_commands.status='delivered'`; sanitized logcat | NOT RUN |
| CMD-03 | Delivered `apply_policy` | 1. Device applies. 2. Observe ack. | `ack` posts `{action,command_id,status,result}` (`api-contract.md:111`); `result` carries `applied_count/desired_count/failed_count/enforcement_supported/enforcement_mode` (`api-contract.md:232,245`). |  | read-only `policy_ack.result` JSON | NOT RUN |
| CMD-04 | Command that will fail (e.g. unsupported enforcement / device-admin absent) | 1. Save a policy requiring suspension without device owner. | Device returns `failed` ack with an `errors[]`/reason; server sets `device_policies.enforcement_status` honestly (no `enforced` on failure) (`api-contract.md:111,209`). |  | read-only `device_commands.status='failed'`, `device_policies.enforcement_status` | NOT RUN |
| CMD-05 | `end_session` command in queue | 1. Enqueue `end_session` while a session is NOT open on the visible assistance screen. | Background service **cannot** end media: it acks `failed` with the "managed by the visible assistance screen" message (`android/.../GuardianService.kt:456-460`) — no silent teardown. |  | read-only failed ack + logcat | NOT RUN |
| CMD-06 | Command past its TTL/expires_at | 1. Create a command with a short `ttl_seconds`, keep device offline past `expires_at`. | Device `handleCommand` skips an already-expired command (`GuardianService.kt:379-380`); status `expired` not `succeeded` (`api-contract.md:211`). |  | read-only `device_commands.status='expired'` | NOT RUN |
| CMD-07 | Duplicate delivery (idempotency) | 1. Force the same command to be seen twice (re-poll / handled-set). | `store.handledCommands()` short-circuits a second execution (`GuardianService.kt:377`); unique `(device_id,idempotency_key)` prevents a second enqueue (`api-contract.md:109`). |  | read-only: one command row, one ack | NOT RUN |
| ENF-01 | Device acked `apply_policy`; `payload.policy_id == policy on screen` | 1. Open that policy in App restrictions. | Correlation `matched` (`policy_enforcement.dart:119,184`); **green/verified "confirmed suspended" badge appears ONLY when** counts also prove it (`enforcement_supported==true`,`failed_count==0`,`applied==desired`) (`app_restrictions_page.dart:316-322`, `p3-enforcement-correlation.md:66-68`). |  | screenshot + read-only `device_commands.payload.policy_id` vs `device_policies.id` | NOT RUN |
| ENF-02 | A newer command exists; the newest ack names a **previous** policy (mismatched) | 1. Save policy v2 while v1's ack is the newest on file. 2. Open v2. | For v2 the newest ack is `mismatched` → **never shown as v2's proof**; v2 shows "Pending device acknowledgement", no counts/badge (`app_restrictions_page.dart:298-303`, `p3-enforcement-correlation.md:76-78`); it stays visible only for the policy it names. |  | screenshot + read-only command payload id vs displayed id | NOT RUN |
| ENF-03 | A legacy/empty `policy_id` ack (absent, empty, or whitespace) | 1. Select a policy whose only report lacks a usable id. | Correlation `uncorrelated` (`policy_enforcement.dart:122,181`); banner **"Device report not linked to this policy"** shown, counts visible for reference, **`provesEnforcement==false`** (no green badge) (`app_restrictions_page.dart:337-347`). |  | screenshot + read-only ack with empty payload id | NOT RUN |
| ENF-04 | `enforced` status but device did not report counts (`countsKnown==false`) | 1. Load a policy whose ack predates counts or has counts disabled. | Banner **"Enforcement not proven by counts"**; **no** verified badge (`app_restrictions_page.dart:350-360`, `p3-enforcement-correlation.md:66-70`). |  | screenshot + read-only ack without `*_count` | NOT RUN |
| ENF-05 | Unsupported enforcement (no device owner) | 1. Open the policy the device refused. | Banner **"Unsupported on this device"**; explicit unsupported state, nothing claimed blocked (`app_restrictions_page.dart:305-314`). |  | screenshot + read-only `enforcement_status='unsupported'` | NOT RUN |
| ENF-06 | Late/slow ack racing a save | 1. Save a new policy while an older report load is in flight. | Generation guard drops the superseded load (no overwrite, incl. error path) (`_reportRequest`, `p3-enforcement-correlation.md:80-85`); no false proof. Residual: version *number* may briefly lag (report still guarded) — record, do not treat as a pass (`p3-enforcement-correlation.md:117-122`). |  | logcat/UI sequence + read-only `created_at/acked_at` | NOT RUN |
| ENF-07 | Per-app confirmation-failure wording | 1. Trigger an app the device could not confirm suspended. | Header reads exactly **"Apps the device could not confirm as suspended"** (confirmation failure, not proof of failed suspend) (`app_restrictions_page.dart:373`; `PolicyApplier.kt:151`; WORD-01 `p3-enforcement-correlation.md:87-96`). |  | screenshot | NOT RUN |
| ENF-08 | Cross-device scoping | 1. Craft/observe an ack whose `device_id` differs from the selected device. | Report from another device is ignored (device-id scope only) (`p3-enforcement-correlation.md:46`). |  | read-only two `device_commands` rows | NOT RUN |

Section §D = **15 rows** (CMD 7, ENF 8), all `NOT RUN`.

---

## §E — Remote-session consent + visible-microphone foreground service (SESS)

Context: `remote-session` actions and consent gating (`api-contract.md:127-137`); child FGS
`AudioAssistanceService` id 4303, non-dismissible notification with a **Stop** action, mic FGS type,
`START_NOT_STICKY`, capture heartbeat 10 s / 45 s stop, parent-end watchdog 15 s
(`stage5:82-95`, `android/.../AudioAssistanceService.kt:77,90,114,493,534`); UI truthfulness derives
`isMediaFlowing` from RTP deltas, never "Microphone live" without evidence (`stage5:99-106`).

| ID | Preconditions | Steps | Expected result (falsifiable) | Actual result | Evidence required | Status |
|---|---|---|---|---|---|---|
| SESS-01 | Linked child, parent requesting | 1. Parent starts audio assistance for the device. | `request` → session `requested`; parent shows "Waiting for consent" (`remote_session_page.dart:301`; `api-contract.md:131`); no media opened yet. |  | parent screenshot + read-only `remote_sessions.status='requested'` | NOT RUN |
| SESS-02 | Pending request on child; mic **not yet** used | 1. Child opens Requests; taps Accept. | `respond accept` records `consent_recorded`, `status='accepted'`, `expires_at=null` (`api-contract.md:134`); only after consent does the FGS/mic notification appear; capture client names the package in `dumpsys audio` (`mic-lifecycle-test-plan.md:49`). |  | child screenshot + `dumpsys activity services` (id 4303) + `dumpsys audio` | NOT RUN |
| SESS-03 | `consent_recorded`, accepted session | 1. Participant calls `ice`. | `ice` requires `accepted|active` **and** `consent_recorded`, else `409/403` (`api-contract.md:137`); consent precedes any ICE/capture. |  | Edge Function log (`403` when no consent) + screenshot | NOT RUN |
| SESS-04 | Active audio session | 1. Parent observes 5 min continuous. 2. Read media chips. | Parent RTP deltas positive; UI shows "Audio live"/"One-way audio live" **only** with packet deltas (`stage5:99-106`, `stage7:249`); badge alone is NOT accepted as proof. |  | `dumpsys audio` both devices + RTP UI logcat + screenshot | NOT RUN |
| SESS-05 | Notification-permission gate (Android 13+ path) | 1. On a device where `POST_NOTIFICATIONS` not granted, child attempts to accept. | Mic capture refused with reason `notification_permission_required` — the app does not start a mic FGS it cannot show (`AudioAssistanceService.kt:83,254`). |  | screenshot + logcat reason token | NOT RUN |
| SESS-06 | realme channel importance `NONE` | 1. With channel hidden, run a consented session. | The FGS **runs** (mic live) while the ongoing notification may be invisible; UI/leave-note must **not** claim a visible notification it cannot show (`stage5:175-178`; `stage6:259-263`). No setting changed to "fix" it. |  | `dumpsys activity services` + shade screenshot | NOT RUN |
| SESS-07 | Parent-end watchdog | 1. Parent taps **End session** while child app is backgrounded. | Server session → `ended`, `ended_by=parent`; within ≤15 s watchdog stops the mic FGS on the child **without** the child app being foreground; no zombie mic (`stage5:93-95`; `api-contract.md:136`). |  | `dumpsys activity services` before/after + read-only session row | NOT RUN |
| SESS-08 | Child declines | 1. Child taps Decline on a pending request. | `status='declined'` (`api-contract.md:134`); no media, no FGS, parent sees terminal declined state. |  | read-only `remote_sessions.status` + screenshot | NOT RUN |
| SESS-09 | Second concurrent request for the same device | 1. Parent requests while one open session exists. | `request` returns `409 session_in_progress` (`api-contract.md:131`); one open session per device (`stage7:235`). |  | Edge Function log `409` + read-only (one open row) | NOT RUN |

Section §E = **9 rows**, all `NOT RUN`.

---

## §F — Network interruption, reconnection and TURN refresh (NET)

Context: bounded ICE recovery 3 s grace + 2 restarts (2 s/5 s backoff, 20 s each) then `_exhaustIceRecovery`
(`stage6:123-135`); automatic recovery after loss is **not** implemented — both sides must rejoin the
same session (`stage5:189-194`); rejoin creates a new offer (`stage6:132-134`); signaling re-arms
after the five-attempt terminal state (`stage6:100-103`); TURN is **not configured** (STUN-only) and
TURN credentials are refreshed before every restart (`stage7:119`, `remote_session_controller.dart:481`,
`remote_session_page.dart:199`).

| ID | Preconditions | Steps | Expected result (falsifiable) | Actual result | Evidence required | Status |
|---|---|---|---|---|---|---|
| NET-01 | Active session, parent + child | 1. Child turns Wi‑Fi + mobile off ~60 s. 2. Restore same network. | Parent shows truthful "Reconnecting"/"Live updates interrupted", session stays **open**; never claims "live" while offline (`stage5:147`, `stage7:256`); **D5 auto-clear on restore is a known gap** (`two-device-e2e-checklist.md:61`, `stage7:257` FAIL P9) — record banner clearing without a manual refresh as expected-vs-actual, not a pass. |  | two parent screenshots + `dumpsys` + read-only session row | NOT RUN |
| NET-02 | Reconnection exhausted (~45–50 s) | 1. Keep offline past ICE-recovery budget. 2. Restore. | `_pauseMediaAfterConnectionLoss` stops capture + tears peer; server session stays open; UI shows failed-recovery **with Stop sharing still visible** (`stage6:65-94`); no "Microphone live" claim (`stage5:99-106`). |  | screenshot (Stop sharing present) + `dumpsys audio` (no capture) | NOT RUN |
| NET-03 | Exhausted recovery, same open session | 1. Parent taps "Join with explicit consent" (new offer). 2. Child taps "Reconnect microphone" (answers). | Manual rejoin re-establishes live audio on the **same** session id; no duplicate session, no server `end` from the client (`stage5:149`, `stage6:132-134`). |  | read-only one open session + RTP UI logcat + screenshots both | NOT RUN |
| NET-04 | Signaling hit the 5-attempt terminal state | 1. Trigger repeated signal failures. 2. Tap refresh/join. | An explicit refresh/join **re-arms** signaling instead of leaving the session permanently unable to answer (`stage6:100-103`). |  | logcat + screenshot | NOT RUN |
| NET-05 | STUN-only network (no relay configured today) | 1. Read the ICE candidate types gathered. | UI shows **"Relay not configured — No TURN relay is configured"** (`remote_session_page.dart:199`, `remote_session_controller.dart:481`); candidates `host/srflx`, `relay 0` (`runtime-failure-analysis.md:91`). On same-NAT both devices media still connects; do NOT claim restrictive-network success. |  | candidate-type logcat + screenshot | NOT RUN |
| NET-06 | TURN refresh before restart | 1. Force an ICE restart with a (hypothetical) TURN config. | ICE restart refreshes TURN credentials before every restart (`stage7:119`). **Today there is no relay, so the refreshed-credential path cannot be exercised** — see §6. |  | (needs relay) logcat of `ice` response | NOT RUN (BLOCKED today: no TURN relay; provisioning not authorized — `stage5:154`, `stage6:250`) |
| NET-07 | 15-minute endurance on same network | 1. Hold a consented session 15 min; watch for silent death. | Expected: continuous audio. **Known hosted defect F1**: the pre-fix `remote-session` stamps `expires_at=accepted_at+30 min` and expires the session on the next `media/ice` call past the deadline, tearing media silently (`runtime-failure-analysis.md:35-56`; the 15-min leg actually died at 8m14s, `runtime-device-matrix.md:106`). The UI "Until you end the session" copy contradicts the hosted deadline — record honestly. |  | timestamped parent screenshots + read-only session flip to `expired` | NOT RUN (BLOCKED for the fix — new lifetime semantics need hosted deploy approval `runtime-failure-analysis.md:49`) |

Section §F = **7 rows**, all `NOT RUN`.

---

## §G — Permission revocation, notification visibility, user-controlled stopping (PERM)

Context: mic revocation stops the FGS with no auto-restart (`stage5:153`, `stage6:249`); permission
revocation is consent-independent and the parent-end watchdog also stops the service (`stage5:93-95`);
child Stop sharing is idempotent and never ends the server session (`stage6:85-93`); only parent ends
sessions (`api-contract.md:136`).

| ID | Preconditions | Steps | Expected result (falsifiable) | Actual result | Evidence required | Status |
|---|---|---|---|---|---|---|
| PERM-01 | Active consented session, mic running | 1. System Settings → revoke `RECORD_AUDIO` on the child. | FGS + mic capture stop; **no auto-restart**; no zombie microphone; server session state handled honestly (`stage5:153`, `stage6:249`). |  | `dumpsys audio` (capture gone) + screenshot + read-only session row | NOT RUN |
| PERM-02 | Active session | 1. Child taps **Stop sharing** and confirms. | Withdraw consent releases mic/FGS locally and sets `sharingStopped`; **does NOT** call server `end` — only parent ends (`stage6:87-93`; `api-contract.md:136`). |  | screenshot (Sharing stopped, `child_session_page.dart:89`) + `dumpsys audio` | NOT RUN |
| PERM-03 | Session with no live peer/capture (recovery exhausted) | 1. Confirm Stop sharing is still shown & tappable. | `canStopSharing` is true for any `accepted/active` non-expired child session independent of peer state (`stage6:85-90`); idempotent success with no capture (`stage6:89`). |  | screenshot + logcat | NOT RUN |
| PERM-04 | Active session | 1. Revoke `POST_NOTIFICATIONS` on the child (Android 13+). | Mic FGS cannot proceed with no visible notification → reason `notification_permission_required` (`AudioAssistanceService.kt:83,254`); no silent capture behind a hidden indicator. |  | screenshot + logcat reason | NOT RUN |
| PERM-05 | Active session, shade + privacy indicators | 1. Observe ongoing notification + Android mic indicator during live capture. | The ongoing notification and the OS mic indicator are present when the channel importance allows; UI never suppresses either (privacy invariant §2.2); if the channel hides the notification, UI does not falsely claim it is visible (`stage5:175-178`). |  | shade screenshot + `dumpsys notification` | NOT RUN |
| PERM-06 | Consent truthfulness under revocation | 1. After PERM-01 revocation, inspect child dashboard copy. | Dashboard must NOT say "Microphone sharing in progress / guardian can hear" once permission is revoked or the service stopped (fixed defect `stage5:110-113`). |  | screenshot | NOT RUN |
| PERM-07 | Parent authority vs child control | 1. Child taps Stop; 2. then Parent taps End on the same session. | Child stop releases local capture but session stays open for parent; parent End is the only terminal action by a party and sets `ended_by=parent` (`stage6:248`; `api-contract.md:136`). |  | read-only session `status='ended'`,`ended_by` + screenshots | NOT RUN |

Section §G = **7 rows**, all `NOT RUN`.

---

## §H — Safe Zone creation/deletion, audit-write failure, compensation-failure (ZONE)

Context: create/update are client RLS writes; delete goes through `family-admin` `delete_zone`
(`api-contract.md:123,142,170,242`); Phase-3 compensation in `family-admin`: audit retried ≤3, then
**compensating restore** of the exact pre-delete row (`zone_delete_reverted:<id>`), then if restore
**also** fails an explicit `audit_failed`/500 naming the zone as **deleted but not recorded**
(`zone_delete_unaudited:<code>:<zone id>`) — never `{deleted:true}` silently
(`docs/implementation/_work/p3-audit-atomicity.md:54-75`); the client renders `error.message` verbatim
(`safe_zones_page.dart:77,315`; `edge_api.dart:111-116`).

| ID | Preconditions | Steps | Expected result (falsifiable) | Actual result | Evidence required | Status |
|---|---|---|---|---|---|---|
| ZONE-01 | Active parent, family present | 1. Safe zones → Create (name, lat/lng, radius, active). | Zone row created via client insert; appears in list (`api-contract.md:170`). |  | screenshot + read-only `safe_zones` row | NOT RUN |
| ZONE-02 | Existing zone | 1. Edit radius/active → Save. | `upsertSafeZone` updates in place; list reflects the edit (`safe_zones_controller.dart` upsert path). |  | screenshot + read-only row | NOT RUN |
| ZONE-03 | Existing zone | 1. Delete → confirm. | `family-admin delete_zone` → `{deleted:true}` **and** one `zone_deleted` `audit_logs` row (`api-contract.md:123,170`; `p3-audit-atomicity.md:19-27`). |  | screenshot + read-only `safe_zones`(gone) & `audit_logs.event_type='zone_deleted'` | NOT RUN |
| ZONE-04 | Non-parent / revoked actor tries to manage zones | 1. Attempt delete/edit as a child or non-owner. | Rejected `forbidden` — "An active parent of this family is required to change safe zones" (`safe_zones_controller.dart:156-159`); client gate + server `assertFamilyParent` both deny (`p3-audit-atomicity.md:13`). |  | screenshot + Edge Function log `403` | NOT RUN |
| ZONE-05 | Delete of a zone that vanished (concurrent/404) | 1. Attempt delete of a non-existent/zero-row zone. | `zone_not_found`/404 on pre-read; zero-row delete skips audit and answers truthfully; no fabricated `zone_deleted` (`p3-audit-atomicity.md:11-18`). |  | screenshot + read-only (no new audit row) | NOT RUN |
| ZONE-06 | **Audit INSERT fails but compensation succeeds** (transient audit outage) | 1. Force audit insert to fail (all retries) while restore succeeds. | Client shows `audit_failed`/500 wording that **the safe zone was kept**; Edge log `zone_delete_reverted:<id>`; `safe_zones` row **present again**; **no** `{deleted:true}` (`p3-audit-atomicity.md:61-64,73-74`). |  | screenshot (verbatim error) + read-only `safe_zones`(still present) + Edge log token `zone_delete_reverted` | NOT RUN (BLOCKED today: fault injection needs a real outage/RPC — mitigated path only, `p3-audit-atomicity.md:87-90`) |
| ZONE-07 | **Audit INSERT fails AND compensating restore also fails** | 1. Force both audit insert and restore to fail simultaneously. | Client shows `audit_failed`/500 stating the zone **was deleted but not recorded**; Edge log `zone_delete_unaudited:<code>:<zone id>`; UI must NOT show a success/deleted-confirmed state; retry via API is impossible (pre-read 404) — surface that honestly (`p3-audit-atomicity.md:64-68,29-31`). |  | screenshot (verbatim "deleted but not recorded") + read-only `safe_zones`(gone) + Edge log token `zone_delete_unaudited` | NOT RUN (BLOCKED today: needs real DB-fault injection + deployed `family-admin`; repo compensation not deployed) |
| ZONE-08 | Residual duplicate-audit risk | 1. Retry after a commit-then-lost-response audit insert. | May **duplicate** a `zone_deleted` row (over-recording, append-only-safe) — record the count; must never under-record (`p3-audit-atomicity.md:94-97`; `phase-3-report.md:193`). |  | read-only `audit_logs` (≥1 `zone_deleted`, note duplicates) | NOT RUN |

Section §H = **8 rows**, all `NOT RUN`.

---

## §I — Backgrounding, process termination (recents/force stop) and restart (LIFE)

Context: process-scoped cached engine + app-scoped controller registry keep capture alive across UI
teardown (`stage5:38-71`); `onClose()` is detach-only, `releaseActive()` only on logout/unlink
(`stage5:72-78`); a **Recents swipe is not a stop request** (`onTaskRemoved` emits non-terminal
`audio_assistance_detached`) and FGS survives on the emulator, but OEM task-removal **kills** the
process on realme (`stage5:88-90`; `stage7:285`; `runtime-failure-analysis.md:100-108` F5);
Force Stop / process death / OEM cleaners end media, not bypassed (`stage5:186-193`; `stage6:252-253`).

| ID | Preconditions | Steps | Expected result (falsifiable) | Actual result | Evidence required | Status |
|---|---|---|---|---|---|---|
| LIFE-01 | Active session | 1. Child presses Home ~30 s. 2. Return. | pid unchanged; session Active; elapsed continues (`stage7:250-251`); audio survives. |  | `dumpsys activity services` + before/after screenshots | NOT RUN |
| LIFE-02 | Active session | 1. Lock screen ~2 min. 2. Unlock. | Session Active; no end; audio continues (`stage7:252`, `stage5:144`). |  | `dumpsys` + screenshots + read-only session | NOT RUN |
| LIFE-03 | Active session | 1. Swipe the app from Recents (emulator parent). | Parent process + FGS survive; reopening restores the session page (`stage5:145-146`, `stage7:255`); `onTaskRemoved` is non-terminal (`stage5:88-90`). |  | `dumpsys activity services` after swipe + screenshots | NOT RUN |
| LIFE-04 | Active session, **child physical realme** | 1. Swipe child app from Recents. | OEM behaviour: realme may **kill the task** (`signal 9` / `remove task`) → process + mic FGS die, capture stops (`stage7:285`; `runtime-failure-analysis.md:102-105`). Parent must go truthful ("Connection setup failed"/audio not live) while the **server session stays open** for an explicit rejoin; record as a truthful failure, not a pass (`stage5:151`, `stage6:247`). |  | `dumpsys`/logcat (task removed) + parent screenshot + read-only session (still open) | NOT RUN |
| LIFE-05 | Active session | 1. Parent (or child via app-info) **Force Stop** the child app. | Process + both services gone; mic indicator gone; parent shows media not live; session stays open server-side; **nothing auto-restarts** (`stage5:151,186-193`; `stage6:252-253`). Force stop is NOT bypassed. |  | `dumpsys activity services` (gone) + read-only session row + screenshot | NOT RUN |
| LIFE-06 | After LIFE-04/LIFE-05 | 1. Child relaunches app. 2. Parent joins with consent; child reconnects. | Explicit rejoin restores audio on the **same** session; single service, single controller (`stage5:146,149`; `stage6:132-134`). Note: on realme a task-kill relaunch came back **signed-out** and unreachable in one run (`stage7:286`) — record the login/restore outcome honestly. |  | screenshots both + read-only (one open session) | NOT RUN |
| LIFE-07 | Session open, child app closed via back | 1. On the assistance screen press back/leave. | Confirms "End the session and leave?" with **Stay**; Stay keeps session + server state; leaving the route does not tear capture via `onClose()` (detach-only, `stage5:72-78`; `stage7:253`). |  | screenshot of confirm dialog + read-only session | NOT RUN |
| LIFE-08 | Logout / unlink with a live session | 1. While a session is open, log the child out (or unlink). | `releaseActive()` tears down capture + releases mic/FGS locally; **does not** end the server session by itself (`stage5:64-65`); a re-login restores a consistent, non-zombie state. |  | `dumpsys activity services` + read-only session | NOT RUN |
| LIFE-09 | Guardian restart (boot / START_STICKY) | 1. Reboot the child device; wait for `GuardianService` to resume; check heartbeat/command poll resume. | `GuardianService` `START_STICKY` restarts after OS kill (`android/.../GuardianService.kt:170`; boot path `BootReceiver.kt`); presence resumes advancing `last_seen_at`; a **frozen poll** must surface as stalled/offline, not silent-Online (F2 `runtime-failure-analysis.md:60-73`). |  | `dumpsys` + read-only `last_seen_at` across boot | NOT RUN (Kotlin-side root cause unverifiable — §6) |

Section §I = **9 rows**, all `NOT RUN`.

---

## 5. Row count summary

| Section | Area | Rows | Prefix range |
|---|---|---|---|
| §A | Auth & family association | 6 | AUTH-01..06 |
| §B | Pairing & unlinking | 8 | PAIR-01..08 |
| §C | Presence & stale device | 6 | PRES-01..06 |
| §D | Commands (CMD) + enforcement correlation (ENF) | 15 | CMD-01..07, ENF-01..08 |
| §E | Remote consent + visible-mic FGS | 9 | SESS-01..09 |
| §F | Network interruption / reconnect / TURN refresh | 7 | NET-01..07 |
| §G | Permission revocation / notification visibility / user stop | 7 | PERM-01..07 |
| §H | Safe zones + audit/compensation failure | 8 | ZONE-01..08 |
| §I | Backgrounding / process death / restart | 9 | LIFE-01..09 |
| **Total** | | **75 rows** | all `NOT RUN` |

Every row: Actual result **BLANK**, Status **`NOT RUN`**.

---

## 6. Rows BLOCKED today (cannot be executed even once the run is authorized) and why

These are gates, not device results. Status remains `NOT RUN` for every affected row.

**A. Kotlin / JVM verifiability gap (KOT-01).** The five native test files under
`android/app/src/test/kotlin/**` were **not run** in Phase 3 and "no JVM test is claimed as passing"
(`phase-3-report.md:199-205`). All-modules `testDebugUnitTest` still fails while configuring plugin
test tasks due to the cross-drive incremental-cache error — `this and base files have different roots`
— mitigated (not eliminated) by `android/gradle.properties:9` `kotlin.incremental=false`
(`bug-report.md:196-209`, `runtime-failure-analysis.md:124-142` E1). The precise unblock
`cd /d/parentcontrol_app/android && ./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks`
is a **build-owner action**; this workstream did not run Gradle and must not build
(`p3-followups.md:166-182`; `phase-3-report.md:211-212`). Rows whose *native root cause / watchdog /
heartbeat / policy-apply* proof would rest on a JVM test — **PRES-06, ENF (native `PolicyApplier`
internals), LIFE-09** — are BLOCKED from being *root-cause verified* by this plan; they can still be
exercised **behaviourally** on the real device (UI + `dumpsys` + read-only DB), but the Kotlin
explanation is `BLOCKED — environment` and no JVM pass may be cited
(`feature-ownership.md:82-84`). `KOT-02` (duplicate `enforcementMode()` in `PolicyApplier.kt:229-233`
vs `GuardianService.kt:668-674`) needs `PolicyApplierTest` that does **not** exist
(`p3-followups.md:184-201`) — ENF-05/ENF-07 native drift is unprovable here.

> **Coordinator correction, 2026-11-03 ~11:06 (after this plan was written; the paragraph above is left
> untouched because it accurately reports the state at authoring time).** The KOT-01 gate in this block is
> **closed**: Phase 4 brief §4 required the scoped run, and it was executed —
> `cd android && ./gradlew :app:testDebugUnitTest --configure-on-demand --rerun-tasks` → exit **0**,
> 182 tasks executed, **35 tests / 0 failures / 0 errors / 0 skipped** across the 5 classes, fresh JUnit XML
> at `timestamp="2026-11-03T05:36:52Z"` (`.tools/p4b-gradle-coordinator.log`,
> `build/app/test-results/testDebugUnitTest/*.xml`, `_work/p4-kotlin.md`). So: (i) "no JVM pass may be cited"
> is **superseded** — a JVM pass *is* now citable, with those numbers; (ii) the cross-drive incremental-cache
> failure applies to the **all-modules** invocation, not the scoped `:app:` task, so it does not block the
> unblock command; (iii) PRES-06 / ENF native internals / LIFE-09 are still **not** covered, because the 5
> green classes are the audio-lifecycle suite plus `PolicyEvaluator` — neither `PolicyApplier` nor
> `GuardianService` is reachable from the JVM test source set, which is exactly why KOT-02 stayed BLOCKED
> (`android/app/build.gradle.kts:93` has `junit:4.13.2` only, no Robolectric/Mockito, no `testOptions`).
> The row statuses in §A–§I remain `NOT RUN`: a JVM unit-test pass is not a device observation.

**B. Missing approvals / host not deployed.**
- **NET-07 and any null-expiry / "until you end" lifetime claim** are BLOCKED for the fix: the hosted
  `remote-session` is the pre-fix build that expires consented sessions at 30 min
  (`runtime-failure-analysis.md:35-56` F1; `phase-3-report.md:221`). Exercising the corrected lifetime
  requires deploying `20261028000200` **together with** `20261028000300` — an explicit owner
  authorization; none of the Phase-1/Phase-3 SQL was applied (`stage6:152-160`,
  `phase-3-report.md:231-237`). Until then NET-07 measures the *known-failing* behaviour, not a pass.
- **ZONE-06, ZONE-07 (compensation / double-failure)** are BLOCKED: the compensation path shipped only
  in the repo `family-admin` module and is **not deployed**, and true commit-vs-response fault
  injection needs a real PostgREST/PG cluster (`p3-audit-atomicity.md:54-75,87-90,114-121`). They
  cannot be exercised on the hosted backend today.
- **NET-06 (TURN refresh)** is BLOCKED: **no TURN relay is configured** (STUN-only); relay
  provisioning is not authorized (`stage5:154`, `stage6:250`, `runtime-failure-analysis.md:88-96` F4).
  The credential-refresh-before-restart code path exists (`stage7:119`) but has no relay to exercise.

**C. Test-environment precondition gates (owner/credential decisions).**
- **PAIR-01, PAIR-02 and every row that needs an *active* link or session** (PAIR-03..08, SESS-*, NET-*,
  PERM-*, LIFE-*) are currently BLOCKED *until re-pairing*: all three QA device links were `Revoked`,
  last seen ~2 days ago, so no active session could be created (`stage6:221-228`). Re-linking is an
  owner/device decision, not a plan step to force.
- **AUTH-01/02 and any `ankit`-account row** cannot use the requested `ankit@gmail.com`/`ankit1@gmail.com`
  — they are **unverified/absent from the repo** and Dashboard-only (`stage6:19-28`). Run against the
  documented QA Family A accounts instead (`stage6:33-39`); the `ankit` identities remain
  `BLOCKED — credentials/dashboard access`.
- **No device execution / no build** without explicit authorization; this plan deliberately performs
  none (`feature-ownership.md:65-69`; brief).

---

## 7. If authorized, highest-risk scenarios to execute first (advisory order — none run here)

1. **ENF-02 + ENF-03 (wrong-policy / uncorrelated enforcement).** A mis-attributed enforcement badge is
   a P1 trust defect; proving a report cannot green-badge the wrong policy is the single most
   safety-critical assertion (`p3-enforcement-correlation.md:31-38`, `phase-3-report.md:194`).
2. **NET-07 (30-min silent expiry, F1).** Reproduce the known silent media death + UI contradiction
   before the deploy gate — it is the highest-impact live defect (`runtime-failure-analysis.md:35-56`).
3. **LIFE-04 + LIFE-05 (realme task-kill / force stop) with SESS-07 (parent watchdog).** Confirms no
   zombie microphone and that privacy/user-control semantics are honoured under process death
   (`stage7:285`, `stage5:186-193`, `runtime-failure-analysis.md:100-108`).
4. **SESS-01→SESS-03 (consent-before-mic) + PERM-01/PERM-04 (revocation, notification gate).** The
   consent-and-privacy boundary is the core compliance requirement (`api-contract.md:134-137`,
   `AudioAssistanceService.kt:83,254`, `stage5:110-113`).

---

## 8. Sources read (file:line) — no prior-phase device behaviour is asserted as verified here

- `docs/implementation/phase-3-report.md:11-17` (status vocabulary), `:185-197` (gap table),
  `:199-217` (§6 Kotlin limitations), `:221-237` (§7 hosted read-only).
- `docs/implementation/_work/p3-followups.md:149-183` (§5 KOT-01), `:184-201` (§6 KOT-02).
- `android/gradle.properties:5-9` (`kotlin.incremental=false` + cause).
- `docs/runtime-device-matrix.md:11-20,63-74,78-108` (devices, permissions, FGS ids, session end reasons).
- `docs/stage5_background_audio_survival_report.md:82-95,99-106,141-155,173-193`.
- `docs/stage6_account_and_media_recovery_report.md:19-53,85-103,123-135,152-160,213-253,259-263`.
- `docs/stage7_two_device_end_to_end_report.md:108-135,243-289`.
- `docs/two-device-e2e-checklist.md:8-95`. `docs/mic-lifecycle-test-plan.md:11-60`.
- `docs/verification-report.md:128-142`. `docs/bug-report.md:191-209`.
- `docs/runtime-failure-analysis.md:20-56 (F0,F1),60-85 (F2,F3),88-108 (F4,F5),124-142 (E1)`.
- `docs/implementation/api-contract.md:56-148,150-234,235-261`.
- `docs/implementation/feature-ownership.md:16-21,61-84`.
- `docs/implementation/_work/p3-enforcement-correlation.md:9-70,76-96,117-122`.
- `docs/implementation/_work/p3-audit-atomicity.md:11-31,54-75,87-104,114-121`.
- Code: `android/.../GuardianService.kt:36-41,170,360-380,456-460,sendAck`;
  `android/.../AudioAssistanceService.kt:28-57,76-114,254,493,534`; `android/.../PolicyApplier.kt:151,229-233`;
  `lib/data/models/device.dart:313-314,371,376,394-412,423`; `lib/data/models/policy_enforcement.dart:117-125,174-189`;
  `lib/features/app_restrictions/app_restrictions_page.dart:298-322,337-360,373`;
  `lib/features/safe_zones/safe_zones_controller.dart:156-186` + `safe_zones_page.dart:77`;
  `lib/features/remote_assistance/remote_session_page.dart:199,301,375`; `remote_session_controller.dart:481`;
  `lib/features/child/child_session_page.dart:89,116-130`; `lib/features/dashboard/parent_dashboard_tab.dart:51-55,256`;
  `lib/features/devices/device_detail_page.dart:86-156,212`; `lib/data/models/remote_session.dart:14-48`.
- Build/env (read-only, not run): `scripts/build_debug_apk.sh:60`, `scripts/check_live_config.sh:27`,
  `.env.example`, `.tools/qa_accounts.env` (key names only).
