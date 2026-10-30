# Pairing recovery baseline — 2026-10-29

Phase A of the "Restore Pairing + Complete Two-Device E2E Testing" brief.
This file records only what was observed in the current tree, the current hosted
project and the currently attached device. Nothing was changed to produce it.

**Headline:** the pairing backend is currently healthy — the parent invite, the
child approval and the persisted family/device link all exist on the hosted
project, and the most recent request was approved today. The reproducible
"pairing looks broken" behaviour is client-side state freshness, not a backend
or RLS failure. Those client defects are listed in §6.

---

## 1. Repository and toolchain

| Item | Observed |
|---|---|
| Branch | `main` |
| HEAD | `79f4962 feat: implement remote audio assistance and child session management features` |
| Working tree | Large uncommitted set from Stages 4–7: 28 tracked files staged (12 Dart, 1 SQL migration, 2 SQL test files, 13 test files, Android bridge/service), all Stage 4–7 evidence PNGs and reports, plus untracked Stage 7 evidence/logs. No unstaged source edits. |
| Flutter | 3.44.6 (revision `ee80f08bbf`), Dart 3.12.2, via `.fvm/flutter_sdk/bin/flutter` |
| Android build | single applicationId `com.parentcontrol.parent_control`, no product flavors; release currently signed with the debug key |

No file was reverted, reset or cleaned to produce this baseline.

## 2. Accounts and hosted membership (read-only SQL, today)

Hosted project `parent-control-prod` (`hhqgreaoqulmfwfwarhc`), read-only
`select` inside a `do` block that was rolled back by the exception itself.

| Fact | Observed |
|---|---|
| Families | `QA Family A`, `QA Family B`, `demo` (`4b97ad74-6032-48f4-a705-bef60f2c7a75`) |
| `demo` owner | `d8c7ee6a-6380-43bf-8205-ad448cfdc6e3` — the brief's parent account |
| `demo` child member | `a29448c5-23ee-461c-bdac-2f7daab4bbae` — the brief's child account, role `child`, status `active` |
| Child's device | `fd79ee34-c6fe-4abd-a3ae-39f9b16ed628` ("realme RMX2161"), status `active`, `last_seen_at = 2026-10-29T08:54:56Z` |
| Latest pairing request | `c0c70473-55d4-4bd5-a3b2-e6a0b6407c76`, status `approved`, created `05:46:57Z`, responded `05:47:15Z` |
| Other families | two unrelated QA families, both healthy; no cross-family membership for the child account |

The Stage 7 report's "child signed out / unlinked" state was accurate when it was
written and is **superseded**: the operator re-paired the account at 05:46Z today
through the normal invite + child-approval flow. The end-to-end
invite → pending → approve → membership path therefore demonstrably works on the
current deployed code.

## 3. Schema, migrations and RLS

Applied through the Dashboard on 2026-10-29 (no CLI), verified after apply:
`expires_at` nullable, `remote_sessions_pending_expiry_check` present,
`remote_sessions_transition_guard` trigger present,
`public.request_remote_session(uuid,uuid,text)` present,
`webrtc_signals` policies free of the `expires_at > now()` predicate and still
limited to the two participants plus `status in ('accepted','active')`.
Positive participant signaling insert succeeded; non-participant insert failed
`42501`; terminal revival failed `session_terminal`. All probes rolled back.
See `docs/stage7_hosted_migration_apply_2026-10-29.md`.

Caveats carried forward:

* `20261028000200` is **not idempotent** (`add constraint` is unguarded). It has
  been applied once; do not replay the file as-is.
* Hosted migration history still reads "No migrations" (out-of-band history).
* `pg_cron` is absent, so no scheduled sweep runs on hosted; expiry of pending
  requests is lazy.
* Policy counts for `profiles/families/family_members/devices/pairing_requests/
  remote_sessions` matched the local migrations; an earlier subagent claim of
  hosted "default-deny drift" was checked and is false.

## 4. Edge Function deployment state

| Function | Local | Deployed | Verdict |
|---|---|---|---|
| `pairing` | sha256 `ac4dcef…`, 33,999 B | same hash | current |
| `remote-session` | calls `db.rpc("request_remote_session")`, parent-only end, no `expires_at` on accept | older minified bundle: direct insert, sets `expires_at`, no RPC guard | **stale** |

The stale `remote-session` bundle is not a pairing blocker. It is a deployment
gap for session concurrency and expiry handling and is gated in Phase G.

## 5. Session state (read-only, today)

| Fact | Observed |
|---|---|
| Session counts | 1 `active`, 30 `ended`, 8 `expired` |
| Open row | `e84ba35e-d8c6-4573-a5a5-c02fa849a9f9`, device `fd79ee34-…`, status `active`, `expires_at = NULL`, requested `05:48:03Z`, accepted `05:48:20Z`, never ended |
| Last signaling row | `2026-10-29T05:51:20Z` |
| Capture evidence | none since then; the child process that owned it is gone |

This row is orphaned but consistent with the parent-controlled lifetime policy.
The supported way to close it is the authenticated parent **End session** flow;
this baseline does not delete or edit the row.

## 6. Confirmed client defects (reproducible staleness)

These are the mechanisms by which a healthy backend still looks broken. Each was
traced in the current tree.

| # | Sev | Symptom | Cause | Location |
|---|---|---|---|---|
| D1 | P1 | Parent sends an invite; child app is open on its home/requests view and never sees the request | Child shell loads pending requests only inside `load()` (init, pull-to-refresh, unlink). The only periodic timer is the 20 s **active-session** poll. There is no pairing Realtime subscription anywhere in `lib/` | `lib/features/child/controllers/child_shell_controller.dart:174`, `:353-361`, `:632-661`; no `pairing_requests` channel in `lib/data/repositories/` |
| D2 | P1 | Child approves; parent's Devices list still shows the old set until a manual pull-to-refresh or restart | `DevicesController` loads once in `onInit` and never refreshes on route return or server change; `_fetch` early-returns while a load is in flight, so a route-return refresh could also be dropped | `lib/features/devices/devices_controller.dart:37-48`, `lib/features/devices/parent_devices_tab.dart:42` |
| D3 | P2 | Parent stays on "Waiting for child approval" after the child approves | `checkStatus()` is manual only; there is no poll on the result card, and the copy explicitly says status is only refreshed on request | `lib/features/pairing/pairing_redeem_page.dart:294-302`, `controllers/pairing_redeem_controller.dart:106-140` |
| D4 | P2 | "Check status" fails (offline/not-found) and the parent sees nothing | `_buildResult` renders no `error`; the error banner exists only in `_buildForm`, which is unreachable once `request != null` | `lib/features/pairing/pairing_redeem_page.dart:101-104`, `:113-129`, `:251-324` |
| D5 | P2 | "Live updates interrupted" banner never clears after reconnect or refresh (Stage 7 P9 FAIL) | `load()` re-fetches and re-subscribes but never clears `realtimeError`; it is cleared only when a session/signal row arrives | `lib/features/remote_assistance/remote_session_controller.dart:580-609`, `:645`, `:784` |
| D6 | P3 | Pairing requests list only updates while that page is open | 20 s poll lives in the page-scoped controller and is cancelled on close | `lib/features/pairing/controllers/pairing_requests_controller.dart:20-55`, `:146-147` |

The existing test suite encodes D5 rather than catching it:
`test/features/remote_assistance/remote_session_reliability_test.dart:606`
asserts `realtimeError` is non-null after a failed stream that then resubscribes
successfully.

## 7. Device and test availability

| Requirement | State today |
|---|---|
| Parent device | **unavailable** — no emulator attached, no AVDs defined |
| Child device | one physical Android device attached; currently in human use with AirDroid Kids in the foreground; `com.parentcontrol.parent_control` installed |
| Accounts | both present and linked; sign-in on the attached phone not exercised in this phase |
| Hosted admin | Dashboard reachable; SQL Editor used read-only |

Phase E (two-device E2E) is therefore **BLOCKED** on a parent device + signed-in
parent account, and on exclusive use of the child phone. It is not claimed.

## 8. Scope for the next phases (from this evidence)

* Phase B: fix D1–D4 only — freshness of pairing state and visibility of
  check-status failures. No UI redesign, no backend change.
* Phase C: verify terminal-state and duplicate-session guards against the
  current DB; document the supported parent End flow for `e84ba35e…`.
* Phase D: fix D5 and replace the test that encodes it.
* Phase F: analyze, Flutter/Kotlin/Deno/SQL suites, debug build with exact
  counts.
* Phase G: deployment plan for the stale `remote-session` bundle; no deployment
  without authorization; no replay of `20261028000200`.

## 9. Evidence index

* `docs/stage7_hosted_migration_apply_2026-10-29.md` — migrations, probes, rollback.
* `docs/stage7_two_device_end_to_end_report.md` — Stage 7 device matrix
  (corrections tracked separately; its §8(1) and §9-P1 were superseded by the
  addendum).
* `docs/evidence/stage7/` — screenshots and sanitized log excerpts.
* Hosted reads above were executed 2026-10-29 in the Dashboard SQL Editor; only
  aggregate/row facts are recorded here, no tokens, keys or passwords.
