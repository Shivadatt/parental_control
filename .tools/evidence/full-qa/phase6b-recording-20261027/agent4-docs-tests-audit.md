# Agent 4 — Docs & Tests audit: screen recording product intent (2026-10-27)

READ-ONLY audit. Sources: `docs/`, `README.md`, `test/`, `integration_test/`, `lib/` UI strings, git history, `.tools/*.log`.

## VERDICT: OUT OF SCOPE BY DESIGN

Recording (screen capture of the child device) has never been a specified requirement. Every
contract, doc and user-facing string asserts the opposite — an explicit "no capture / no
recording" privacy promise — and the app-only constraint makes MediaProjection a documented
design conflict. "Implement recording" would be a product-direction change requiring owner
approval, not a gap-fill.

## 1. Quotes — no-capture promises (file:line)

### Contract / docs
- `docs/api-contract.md:545-546` — "No accessibility abuse, no root, **no hidden capture**, no
  permission bypass, no keylogging, no screenshots, no reading private messages/OTP, **no recording**."
- `docs/api-contract.md:542` — manifest lists `camera, record audio` only (audio = live WebRTC mic; no screen-capture permission).
- `docs/remote-assistance.md:83-89` — "Explicitly not implemented: **Hidden or automatic recording.** Covert camera/microphone activation. Silent background surveillance, screenshots, keylogging…"
- `docs/remote-assistance.md:94` — "**No recording feature is present**, therefore no recording retention policy applies."
- `docs/remote-assistance.md:119` — self-test evidence: "main + front camera live, 1280×720 frames, mute, stop — **preview only, never recorded**".
- `docs/verification-report.md:43` — "Audio/video recording | NOT IMPLEMENTED | **Intentionally excluded**; no recording UI, `MediaProjection`, `VirtualDisplay`, `ImageReader` or `MediaRecorder` code".
- `docs/verification-report.md:44` — "Child screen recording | NOT IMPLEMENTED | No screen-recording option exists; MediaProjection would capture other apps, which is **out of scope** for this app-only test".
- `docs/verification-report.md:428` — row 29 "Child screen-recording option | NOT IMPLEMENTED".
- `docs/verification-report.md:470-472` — "Child screen recording does not exist in this app. Android MediaProjection captures the entire display (including other apps), so it was not added under the 'this app only' constraint."
- `docs/bug-report.md:776-783` — section "Screen recording (child) — **NOT IMPLEMENTED, intentionally**": repo search finds no MediaProjection/VirtualDisplay/ImageReader/MediaRecorder; "adding it would also enable invisible surveillance of third-party content. The app therefore reports the feature as absent rather than shipping a partial or covert version."
- `docs/integrations-setup.md:645-647` — "there is no recording, screenshot, keylogging or MediaProjection code (`docs/verification-report.md:39-40`, bug-report 'Screen recording' section)."
- `docs/integrations-setup.md:448` — usage upload: "No content, keystrokes, URLs, screenshots or per-session timelines are collected."
- `README.md:98-100` — "There is **no hidden recording**, covert capture, keylogging or interception of messages/passwords/OTPs."
- `docs/two-device-webrtc-test-plan.md:374` — "Expected from the documentation: **no capture outside the visible session**."
- No root-level `bug-report.md` exists (only `docs/bug-report.md`).

### Child-facing consent / UI strings (Dart)
- `lib/features/child/child_session_page.dart:94-96` — "Nothing is recorded. Camera and microphone are used only during this session…"
- `lib/features/child/child_session_page.dart:209-211` — consent card: "Accepting records your consent… camera and microphone stay off until you tap Join… Nothing is recorded."
- `lib/features/child/child_session_page.dart:376-377, 391-394` — accept/join dialogs: "Nothing is recorded."
- `lib/features/child/tabs/child_settings_tab.dart:65-68` — "This app **never records audio or video, takes screenshots**, reads messages, or captures passwords…"
- `lib/features/child/tabs/child_settings_tab.dart:205` — "not recorded, saved, or sent."
- `lib/features/child/widgets/media_self_test_sheet.dart:15` — "…recorded, stored, or sent to the guardian or any server." (negated promise)
- `lib/features/child/widgets/media_self_test_sheet.dart:255` — "…preview on this screen. It is **not recorded, saved, or sent**."
- `lib/features/child/widgets/media_self_test_sheet.dart:307` — status row label `Recording` (value "Off — preview only").
- `lib/features/child/child_requests_page.dart:178-180` — "…recorded. …stays off until you tap Join there. Nothing is recorded."
- `lib/features/remote_assistance/remote_session_page.dart:120` — "This app does not record audio or video, take screenshots…"
- `lib/features/remote_assistance/remote_session_page.dart:367-369` — "The child has already accepted. Nothing is recorded."
- `lib/features/remote_assistance/remote_session_controller.dart:19` — "…recorded, captured, or sent before that tap." (negation)
- `lib/features/remote_assistance/remote_assistance_page.dart:70` — "…Nothing is recorded, and no screenshots…"
- `lib/features/settings/settings_body.dart:197` — parent-side: "Assistance sessions never **record or capture the child's screen**."

### Recording-promising statements: NONE
No doc, string, TODO, backlog or roadmap item anywhere in `docs/`, `README.md`, `lib/`, `test/`
promises or plans screen recording. `grep -i "phase 6|roadmap|backlog"` finds nothing
("phase6b" exists only as this QA evidence folder name `.tools/evidence/full-qa/phase6b-recording-20261027`).

## 2. Architecture stance

Recording is documented as **explicitly excluded**, not planned/deferred:
- `docs/api-contract.md:545-546` (contract prohibitions) and
  `docs/remote-assistance.md:83-94` ("Explicitly not implemented" list) treat it as a
  privacy boundary of the design. `docs/bug-report.md:776` marks it "NOT IMPLEMENTED,
  intentionally". No doc lists it as planned, deferred, or a roadmap item.

## 3. Test inventory (media / camera / mic / remote assistance / consent)

Totals: **102 Flutter unit/widget tests pass** (`docs/verification-report.md:88, :112`
`+102: All tests passed!`; earlier logs `.tools/fvm-test.log`, `test-final2.log`,
`test-run-final.log` show 93 before BUG-029 tests were added). Plus 13 Kotlin policy tests,
26 Deno Edge tests (incl. `turn_test.ts`), and the SQL/RLS suite (verification-report.md:88-112).
27 Dart test files under `test/` + 4 under `integration_test/`.

Relevant tests:
- `test/features/remote_assistance/remote_child_session_test.dart:104` — "accepting only records consent and **opens no media or negotiation**".
- `test/features/remote_assistance/remote_session_controller_test.dart` — 11 total in the two files (`remote-assistance.md:44,126`): permission-before-getUserMedia, ICE buffering, "stops local media even when the server end call fails".
- `test/features/child/child_requests_controller_test.dart:110` — "accepting an assistance request **only records consent**".
- `integration_test/child_media_selftest_test.dart:174-177` — asserts the **`Recording` preview-only state row exists** ("the preview-only recording state is missing") and that frames flow on one phone.
- `integration_test/device_capabilities_test.dart`, `child_signin_test.dart`, `parent_ui_journey_test.dart` — enrollment/telemetry/UI journey; no capture behavior.

**No test asserts any screen-recording behavior.** Every recording-adjacent assertion proves
the *absence* of capture (consent-only, preview-only, media-not-opened).

## 4. Git history

- `git log --oneline --all`: 5 commits on `main` only (c162f8e baseline scaffolds → b3f1e20 backend/tests). No other branches (`main`, `origin/main`).
- `git log -S "MediaProjection" --oneline --all`: **empty** — MediaProjection never appeared in any diff.
- `git log -S "recording" -i`: 52fb907 (api-contract prohibitions) and a580d36 (verification/remote-assistance/README — the no-recording docs). **No commit ever added and later removed a recording feature.**

## 5. Baseline open items (verification + bug reports)

No open P0/P1/P2 (`docs/bug-report.md:795` "Open / not tested"). BUG-001…029 are fixed;
BUG-029 (WebRTC ICE/start) fixed+unit-tested 2026-10-27. Standing blockers, all labeled
NOT TESTED/BLOCKED/NOT CONFIGURED, not passes:
- **Device Owner**: RMX2161 (the single realme test phone, Android 12) is not Device Owner;
  `setPackagesSuspended()` app blocking BLOCKED — provisioning needs a factory reset that
  was **not authorized** (`verification-report.md` residual gaps; `bug-report.md:786-793`;
  `app-restrictions.md:67`).
- **TURN**: NOT CONFIGURED (no `TURN_URL`/`TURN_SECRET`); STUN-only ICE; relayed calls
  BLOCKED (`remote-assistance.md:121`, `verification-report.md:41`).
- **Two-device WebRTC media**: NOT TESTED — one physical phone, no emulator
  (`remote-assistance.md:120`, bottom line :271-278). Realme's camera/mic/usage/location
  paths are LIVE VERIFIED on that one phone.
- Open gaps G5–G10 (`remote-assistance.md:143-148`): no in-session mute/camera-off (G5),
  no lifecycle handling/foreground service for background capture (G6, privacy-relevant),
  no ICE restart (G7), no push (G8, FCM not configured), expiry status nuance (G9),
  unreachable banner (G10). Hosted email (no SMTP) and hosted backup/PITR untested.

## 6. The "recording" confusion source

Yes — docs explicitly describe the child camera/mic self-test as the feature most likely to
be mistaken for recording. It shows a UI row literally labeled "Recording" with value
"Off — preview only" (`media_self_test_sheet.dart:307`; `bug-report.md:753-774` "Camera and
microphone self-test (new, device verified)"; `verification-report.md:226` "Always | Recording |
Off — preview only"). It opens both cameras, decodes 1280×720 frames, mute/stop — live
preview only, no capture code (`remote-assistance.md:119`). A phase-6b "recording" task was
very plausibly derived from seeing this screen.

## Conclusion

Product intent is unambiguous: recording was consciously excluded and a no-capture promise is
shipped to both parent and child UIs and asserted by tests. Implementing child-screen
recording = product-direction change; needs owner approval and would require revising
api-contract §7 prohibitions, remote-assistance.md, README, the child consent copy, and the
preview-only assertions in `child_media_selftest_test.dart` — and conflicts with the app-only
scope constraint (MediaProjection captures all apps).
