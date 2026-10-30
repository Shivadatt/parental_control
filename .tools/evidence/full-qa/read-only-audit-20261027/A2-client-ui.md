# A2 — Client UI audit: linking-code creation and the 5-per-24h quota

READ-ONLY audit; no file modified. Paths absolute, line numbers from the working
tree at D:\\parentcontrol_app.

Scenario audited: child on a realme, "Set up this phone" → "Create linking code"
→ `Action failed — You have created too many linking codes today. Try again
later.` Server: `supabase/functions/_shared/rate_limit.ts:8`
(`CODE_CREATIONS_PER_24H = 5`), enforced at `:70-88` — every `create` inserts a
NEW `device_pairing_tokens` row (`supabase/functions/pairing/index.ts:221-246`)
and the counter counts all rows for that child in the last 24h whatever their
status (the create revokes its own predecessors, `index.ts:240-249`), so an
unused or lost code costs the same as a redeemed one.

## 1. The screen, its controller, and what a tap does

- Screen: `D:\\parentcontrol_app\\lib\\features\\child\\child_enrollment_page.dart`
  — AppBar title "Set up this phone" (line 46), card "Link to your family"
  (line 178), button label "Create linking code" / "Create a new code"
  (lines 189-199).
- Controller: `D:\\parentcontrol_app\\lib\\features\\child\\controllers\\child_enrollment_controller.dart`
  `createCode()` (lines 133-150) → `PairingRepository.createLinkingCode()`
  → `SupabasePairingRepository.createLinkingCode()`
  (`D:\\parentcontrol_app\\lib\\data\\repositories\\supabase_pairing_repository.dart:25-41`)
  → `EdgeApi.invokeMap('pairing', action: 'create')` (same file, lines 155-169).
- Double-tap safety is real, twice over: `createCode` returns immediately when
  `isCreatingCode` is already true (controller line 134, set synchronously at 141
  before any `await`), and the button passes
  `onPressed: isCreatingCode ? null : createCode` plus `isLoading` (page
  195-198); `AppButton` itself forces `onPressed: isLoading ? null : onPressed`
  (`D:\\parentcontrol_app\\lib\\core\\widgets\\app_button.dart:48,58`).
- A rebuild cannot re-fire it: the only rebuild driver is the 15s poll
  (controller lines 40, 68-76) which calls `checkRequests(silent: true)` — a
  read-only `pending_child` call (lines 152-178). It never calls `createCode`.
- Auto-retry on failure: NONE. The failure branch only stores
  `actionError` (line 146); there is no re-post, no queue, no connectivity hook
  (`D:\\parentcontrol_app\\lib\\data\\services\\connectivity_service.dart:21-23`
  only flips a bool), and a repo-wide search for `WidgetsBindingObserver`,
  `AppLifecycleListener`, `didChangeAppLifecycleState`, `lifetimeWatcher`
  returns zero matches in `lib/`.
- No retry wrapper in transport either: `EdgeApi.invoke`
  (`D:\\parentcontrol_app\\lib\\data\\services\\edge_api.dart:19-57`) does a
  single `functions.invoke(...).timeout(30s)`, no loop, no re-invoke.
- CAVEAT (the one real double-spend): the 30s client timeout
  (`edge_api.dart:24`) turns a *successful-but-slow* create into
  `AppException.timeout` → "The request timed out. Try again."
  (`app_exception.dart:54-58`), while the server already inserted a token.
  The retry then burns a second unit. Same shape for `SocketException`
  "network is unavailable … try again" (`app_exception.dart:48-52`) when the
  request actually reached the edge. There is no idempotency key and no way for
  the client to look the created code up again (see §2).

## 2. Is a generated code cached? Where does it live?

- It lives ONLY in memory: `Rxn<PairingCode> linkingCode` (controller line 50),
  assigned at line 143. `code`, `qr_payload`, `expires_at` are parsed into
  `PairingCode` (`D:\\parentcontrol_app\\lib\\data\\models\\pairing.dart:3-24`).
- Not persisted anywhere: `D:\\parentcontrol_app\\lib\\data\\services\\local_settings_service.dart`
  contains no pairing/code/link key (grep for `code|pair|link` → no match), and
  nothing writes it to `SharedPreferences`/files.
- Popping the page and coming back: the code SURVIVES, because the controller is
  a `Get.lazyPut(..., fenix: true)` instance
  (`D:\\parentcontrol_app\\lib\\features\\child\\child_enrollment_binding.dart:12-23`)
  and there is not a single `Get.delete` in `lib/` (grep → no matches). The page
  just re-`Get.find`s it (`child_enrollment_page.dart:27`).
- App kill / cold relaunch (the realme Doze-and-kill case): the controller dies
  with the process, `linkingCode` is gone, `load()` (lines 78-119) restores
  family/device/pending-requests but has no code-restoration path, so the UI
  shows "Create linking code" again (page line 191) even though a valid token is
  still `active` server-side for up to 10 minutes. The child must burn a new
  unit to see a code again.
- The server exposes no "read my current code" action
  (`supabase/functions/pairing/index.ts` cases: `create` 199, `redeem` 277,
  `pending_child` 428, `respond` 462, `cancel` 479, `list_family` 537,
  `unlink` 555). The client also never calls the available `cancel`
  (`supabase_pairing_repository.dart:117-129` has no caller in `lib/features`),
  so an orphan code cannot be retired from the child's UI.
- Server exposes no "read my current code" action (`pairing/index.ts` cases:
  `create` 199, `redeem` 277, `pending_child` 428, `respond` 462, `cancel` 479,
  `list_family` 537, `unlink` 555); `cancel` cancels a *request*
  (`pairing_requests_controller.dart:128`), never a token, so an orphan code
  cannot be retired from the child UI.
- Cross-account residue: sign-out (`child_shell_controller.dart:871-908`) clears
  session/settings but never disposes `ChildEnrollmentController`; a previous
  child's code stays displayed for the next sign-in in the same process. Only
  `respondTo()` clears it deliberately (controller line 201).

## 3. Countdown / expiry UI

- No countdown, no ticker. Expiry recomputed lazily on rebuild:
  `PairingCode.isExpired` (`pairing.dart:14`) read at page lines 189, 200, 208;
  rebuilds come only from the 15s poll's `pendingRequests.assignAll` (controller
  lines 70-74, 130), so the flip is up to ~15s late and never happens offline —
  a dead QR keeps showing as live.
- The expiry label is broken: page line 239 renders
  `'Expires ${relativeTime(code.expiresAt)}'`, but `relativeTime` returns
  `'Just now'` for any future timestamp (`formatters.dart:18-27`,
  `difference.isNegative` line 21). Every fresh code reads "Expires Just now".
  Same bug in the request tile (page 337-338); the parent screen uses
  `formatDateTime` correctly (`pairing_redeem_page.dart:269-273`).
- On expiry the UI pushes re-creation with no friction: "Create a new code"
  (page 193) plus "This code has expired. Create a new one to continue."
  (200-207). No remaining-quota display, no confirm, no cooldown, no lockout
  after the first 429 — an impatient child (or an agent walking
  create → wait → expired → create) can spend all 5 units in minutes.
- Nothing tells the child that creation itself is capped: copy is only page
  182-187, and "Codes expire after 10 minutes" exists only on the parent screen
  (`pairing_redeem_page.dart:174-175`).

## 4. How the 429 is surfaced to the child

- Transport mapping: a `rate_limited` payload code wins over status mapping
  (`edge_api.dart:111-116`, `_codeForStatus` case 429 at lines 132-133); the
  server sends code `rate_limited`, HTTP 429 and the exact message
  ("You have created too many linking codes today. Try again later.",
  `supabase/functions/_shared/rate_limit.ts:81-87`).
- Child rendering: `child_enrollment_page.dart:99-107` shows a generic
  `BannerTone.danger` titled **"Action failed"** with `actionError.message`
  verbatim and a single "Dismiss" action. It is truthful but:
  - it never says WHEN to retry (no reset timestamp),
  - it never says the limit is 5 per 24h or that the current attempt is #N,
  - it never says a code may already exist from an earlier tap/relaunch,
  - the generic "Action failed" title makes an everyday quota block look like a
    crash, which is exactly what drives retry-spam by a child,
  - the child side has NO code→guidance mapping at all, unlike the parent side
    `_errorTitle`/`_errorGuidance` (`pairing_redeem_page.dart:320-362`).
- Machine-readable hints don't exist and would be dropped anyway: the 429 body
  carries only `code`/`message` (grep `remaining|reset_at|retry_after` under
  `supabase/functions` → none), and `_errorFromPayload` reads just those two
  fields (`edge_api.dart:111-116`); `AppException.statusCode`
  (`app_exception.dart:26-31`) is unread by any UI and `isRateLimited` (line 40)
  has no consumer in `lib/features`.

## 5. Parent side ("Link a child")

- Screen `pairing_redeem_page.dart:93`; controller `lib\\features\\pairing\\controllers\\pairing_redeem_controller.dart`.

- Manual normalisation: `Validators.normalizePairingCode` trims, uppercases,
  strips non-alphanumerics (`D:\\parentcontrol_app\\lib\\core\\utils\\validators.dart:49-50`)
  and validates `^[A-Z0-9]{8,12}$` (line 5, used 40-47). Codes are exactly 8
  chars (`_shared/validation.ts:13`), so 9-12 char junk is sent to the server and
  costs a parent attempt instead of failing locally
  (`pairing_redeem_controller.dart:59-64`;
  `supabase_pairing_repository.dart:48-52`).
- Scan auto-submits with no confirmation: `_handleCapture` → `onDetected` →
  `_onScanned` → `_redeem` (page 59-62, 394-414). One-shot per scanner (`_handled`
  line 395, `DetectionSpeed.noDuplicates` line 381), but "Scan again" bumps
  `_scannerEpoch` and rebuilds it (69-75, 154), so re-presenting a stale code is
  another attempt; the action button on a `rate_limited` banner is literally
  "Scan again" (125-126).
- Copy: `invalid_code` → "…Ask the child to generate a fresh code and enter all 8
  characters." (321-322, 343-346); `code_expired` → "…Ask the child for a new
  one." (324-325, 347-348); `child_already_linked` (328-329, 351-352) — matching
  server codes `pairing/index.ts:290,302,317`, `:507`, `:213,332`.
- The parent's budget is never explained: server is 5 per 10 min per parent
  (`rate_limit.ts:6-7,16-32`) plus 10 per code (`:33-45`); the client says only
  "Wait before trying again; the server throttles attempts." (line 350) — no
  count, no window, no reset time, despite the footer claim "Failures are shown
  exactly as reported" (212-219).
- Harm amplifier for this quota: `invalid_code`/`code_expired` guidance tells the
  guardian to have the child mint a fresh code (344-348) while the child UI cannot
  show whether a live code already exists — one mistype costs the child 1 of 5.

## 6. Does any client path create a code more than once per user action?

- No. `createCode` has exactly one caller app-wide
  (`child_enrollment_page.dart:198`); `createLinkingCode` one
  (`child_enrollment_controller.dart:143`).
- Bindings never invoke it (`child_enrollment_binding.dart:12-23` is only
  `Get.lazyPut`); `onInit` does `load()` + a read-only poll (67-76); `load()`
  (78-119) and `_loadPending` (129-131) only read.
- No pull-to-refresh on this screen: plain `ListView` (page 75);
  `RefreshIndicator` appears only on `child_home_tab.dart:42`,
  `child_requests_tab.dart:39`, `child_rules_tab.dart:39`,
  `child_restrictions_page.dart:49` — none reach `createCode`. The AppBar refresh
  (48-54) and both "Retry" banners (72, 94-95) call `load()`.
- So the only unrequested spend is the timeout/network false-negative retry of §1.
- Non-quota side effect: the 15s poll keeps running for the whole process life
  even after the page is popped, since the controller is never deleted (58,
  70-74, 281-285; no `Get.delete` in `lib/`). `pending_child` isn't rate-limited,
  so it drains battery/data on the realme, not codes.

## 7. Device registration vs linking, and the revocation trap

- Signing in as a child does NOT create a device row: `AuthSessionFlow.resolve`
  sends a verified child to the child shell and clears device state
  (`D:\\parentcontrol_app\\lib\\features\\auth\\auth_session_flow.dart:49-50,62`,
  routing 95-96/115). The only client caller of the `devices` insert is
  `registerDevice()` (controller 212-273 →
  `D:\\parentcontrol_app\\lib\\data\\repositories\\supabase_device_repository.dart:72-103`
  → `device-register`), reached only from explicit taps at
  `child_enrollment_page.dart:430,442` and gated on `family.value != null`
  (controller 216-222). No link → no device row, and no sign-in-triggered code.
- `requiresRelink()` DOES NOT EXIST here (grep `relink|Relink` in `lib/` → none).
  Equivalents: `_requireRegistered`
  (`supabase_device_repository.dart:202-210`, `unauthorized` on heartbeat/upload)
  and the `status = 'active'` filters in `fetchMyDevice` (line 66) and
  `fetchMyMembership`
  (`D:\\parentcontrol_app\\lib\\data\\repositories\\supabase_family_repository.dart:138`).
- The trap, confirmed: parent recovery (`device_detail_page.dart:150-172`;
  `recoverDevice` → `family-admin recover_device`… `request_device_recovery`,
  `supabase_device_repository.dart:115-121`) calls `private.unlink_child`, one
  transaction doing "revocation, session ending, pairing-token invalidation and
  pending-request cancellation" and removing the family link
  (`D:\\parentcontrol_app\\supabase\\migrations\\20260101000400_device_recovery.sql:1-15,41-47`).
  The child's `family` becomes null → enrollment falls back to the linking step
  (`child_enrollment_page.dart:119-124`) → a NEW code is mandatory, as the app's
  own copy says ("sign in, create a new linking code, then open Link a child",
  `device_detail_page.dart:156-160`). A re-pair inside the previous 24h window
  lands on `assertPairingCodeCreationAllowed` at once, and the child has no state
  reminding them of any code already issued.

## Verdict

Mostly (a) — legitimate consumption — materially enabled by the client; no
evidence of (b).

- No path creates a code without a deliberate tap: one caller
  (`child_enrollment_page.dart:198`), one guarded implementation
  (`child_enrollment_controller.dart:133-150`), no auto-invocation in bindings or
  `onInit`, no lifecycle/connectivity retry hook anywhere in `lib/`, no
  pull-to-refresh here. Each of the 5 units was spent by a real tap (child, or an
  agent walking create → expired → create).
- The client is still an accelerant: it never persists or re-displays a code and
  cannot fetch an existing one (§2), labels every fresh code "Expires Just now"
  (§3), pushes "Create a new code" with zero quota awareness (§3), renders the 429
  as an "Action failed" dead end with no reset time (§4), tells guardians to have
  the child mint new codes (§5), and turns a slow-but-successful create into
  "Try again" (§1).
- Structural trap: recovery/revocation forces a brand-new code
  (`20260101000400_device_recovery.sql:1-15` + `child_enrollment_page.dart:119-124`)
  inside the same rolling 24h window the earlier attempts already filled (§7).

## Client defects and minimal fixes

| # | Sev | Defect (evidence) | Minimal fix |
|---|-----|-------------------|-------------|
| 1 | P1 | Code is memory-only and lost on relaunch/process kill, with no read-existing path, forcing a new 1/5-unit creation (`child_enrollment_controller.dart:50,143`; `local_settings_service.dart` has no key; `pairing/index.ts:199-246` always inserts) | Persist `linkingCode` (code, qr_payload, expires_at) in local settings keyed by user id; restore it in `load()` and hide the create button while it is unexpired |
| 2 | P1 | No throttle/education around creation: label flips straight to "Create a new code" with no cost hint, no remaining count, no confirm (`child_enrollment_page.dart:189-207`) | Show "codes left today: N of 5" + a confirm sheet ("each code counts against a 5-per-day limit"); disable the button locally for the token TTL (10 min) while a valid code exists |
| 3 | P1 | Timeout/network false-negative invites a second, quota-burning create after a server-side success (`edge_api.dart:24,48-51`; `app_exception.dart:48-58`; error rendered at `child_enrollment_page.dart:99-107`) | On `timeout`/`network` from `create`, replace "Try again" with "A code may already have been created — wait a minute, then check 'Check for requests'"; send a client-generated idempotency token so a repeat `create` reuses the row |
| 4 | P2 | "Expires Just now" for all future timestamps (`formatters.dart:18-27`, used at `child_enrollment_page.dart:239,337-338`) | Add `countdownLabel(DateTime)` ("10 min left", ticking) or use `formatDateTime`; never pass a future time to `relativeTime` |
| 5 | P2 | Expiry state only recomputed on the 15s poll rebuild and never while offline, so a dead QR looks live (`pairing.dart:14`; `child_enrollment_controller.dart:70-74,130`; page 189-208) | Run a 1s `Timer` while a code is displayed to flip `isExpired` and grey the QR out with an explicit "expired" overlay |
| 6 | P2 | 429 shown as generic "Action failed", verbatim server string, no reset time, no guidance map on the child side (`child_enrollment_page.dart:99-107`; `edge_api.dart:111-164`; `AppException.isRateLimited` unused) | Add `_errorTitle/_errorGuidance` parity for the child screen; special-case `rateLimited` to "Your 5 codes for the last 24 hours are used up — try again tomorrow, or ask your guardian to check the code already shown" |
| 7 | P2 | Cross-account residue: sign-out never disposes the controller, so a previous child's code/QR is re-displayed after another sign-in (`child_shell_controller.dart:871-908`; no `Get.delete` in `lib/`; `child_enrollment_binding.dart:12-23`) | `Get.delete<ChildEnrollmentController>()` in every sign-out path and clear `linkingCode` when `_session.userId` changes |
| 8 | P2 | Parent copy steers guardians to burn the child's budget and hides the parent's own 5-per-10-min limit (`pairing_redeem_page.dart:125-126,343-352`; `rate_limit.ts:6-7,16-45`) | State "You have 5 attempts per 10 minutes" on `rate_limited`, suppress "Scan again" for that code, and change invalid/expired guidance to "check the code still on screen before asking for a new one" |
| 9 | P3 | 9-12 char inputs pass local validation and still cost a server attempt (`validators.dart:5,40-47`) | Require exactly 8 characters (`^[A-Z0-9]{8}$`) |
| 10 | P3 | The 15s poll and its banners keep running after the page is popped, for the whole process life (`child_enrollment_controller.dart:58,70-76,166-172`; `child_enrollment_binding.dart:22` `fenix: true`) | Start/stop the timer with the page (or gate it on `linkingCode != null && !isExpired`) |

No P0: nothing in the client creates a code the user did not ask for, and the
double-tap/rebuild/retry surface is genuinely closed (§1, §6).
