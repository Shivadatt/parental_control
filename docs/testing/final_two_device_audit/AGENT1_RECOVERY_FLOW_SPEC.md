# AGENT 1 — Recovery Flow Specification (two-device functional audit)

Scope: read-only source audit of `D:\parentcontrol_app`. No device commands were run, no repo file
was modified except this report. Targets: Parent `emulator-5554`, Child (RMX2161) `5HXWRGQ4IFU8WS4T`.
Bundle: `com.parentcontrol.parent_control`.

Question under test: the child app was reinstalled; `GuardianService` runs but every upload is
[REDACTED CREDENTIAL ROW]
installation identity is UNCHANGED — and a reinstall changes it by construction. Recovery (or any
unlink) plus a fresh child-approved pairing is the only path that works, and it is the only path
the child UI actually exposes.**

Three independent blockers, all in source:

1. **The reinstall invalidates the identity that the self-healing branch keys on.**
   `SecureStore.installationId()` (`android/app/src/main/kotlin/com/parentcontrol/parent_control/SecureStore.kt:86-92`)
   returns a stored value or creates a fresh `UUID.randomUUID()`; `deviceSecret()`
   (`SecureStore.kt:94-105`) creates a fresh 32-byte `SecureRandom` value. Both live in
   `EncryptedSharedPreferences` named `parent_control_secure` (`SecureStore.kt:27, 71-84`), which the
   uninstall wipes. There is no import/restore path anywhere in `lib/` or the Kotlin bridge.

2. **The child UI will not even attempt the call.**
   `ChildEnrollmentController.registerDevice()` short-circuits:
   `lib/features/child/controllers/child_enrollment_controller.dart:276-279`
   ```dart
   if (device.value != null) {
     actionMessage.value = 'This phone is already registered.';
     return true;
   }
   ```
   `device.value` comes from `SupabaseDeviceRepository.fetchMyDevice()`
   (`lib/data/repositories/supabase_device_repository.dart:59-69`), which selects
   `devices` where `child_user_id = me AND status = 'active'` — that is the **pre-reinstall** row,
   still `active`. Worse, the button is not rendered at all: `child_enrollment_page.dart:121-126`
   picks `_readyCard()` whenever `isReady == isLinked && hasDevice`
   (`child_enrollment_controller.dart:69`). The operator sees "This phone is set up" + chip
   "Registered", not "Register this phone".

3. **Even a forced call is refused server-side.**
   `supabase/functions/device-register/index.ts:143-152` looks up an existing row by
   `(family_id, installation_id)`. The new installation id matches nothing, so the **only**
   self-healing branch — the update at `index.ts:166-195`, which writes a new `secret_hash`,
[REDACTED CREDENTIAL ROW]
   ```ts
   const activeDevice = await db.from("devices").select("id")
     .eq("child_user_id", auth.user.id).eq("status", "active").maybeSingle();
   if (activeDevice.data) throw new ApiError("device_already_registered",
     "This account already has an active device.", 409);
   ```
   The database agrees: `devices_one_active_per_child` is a partial unique index on
   `devices (child_user_id) where status = 'active'`
   (`supabase/migrations/20260101000000_core.sql:117-119`).

### Exact root cause of E-1

`ChildShellController._ensureIdentityAndSync()`
(`lib/features/child/controllers/child_shell_controller.dart:570-615`) pairs the **old server device
id** with the **new local secret**:

```dart
deviceId: loadedDevice.id,        // :602  – the pre-reinstall active row
deviceSecret: identity.secret,    // :603  – freshly minted after reinstall
```

and hands it to `configureBackgroundSync` (`:599-605` →
`lib/data/services/device_admin_service.dart:180-195` → `SecureStore.saveConfig`, `SecureStore.kt:107-115`).
The native uploader then authenticates with `x-device-id` + `x-device-secret`, and
`requireDevice` (`supabase/functions/_shared/auth.ts:281-337`) resolves the row **by device id**
(`:302-308`) and compares `sha256(secret)` against `secret_hash` (`:312, 322-328`). Mismatch →
[REDACTED CREDENTIAL ROW]
`:525` (`Heartbeat failed:`), written by `SecureStore.setLastError` (`SecureStore.kt:149-156`) and
rendered at `lib/features/child/tabs/child_settings_tab.dart:287-294`.

Because the child shell re-runs `_ensureIdentityAndSync` on every load, the mismatched pair is
re-armed continuously — the failure is self-perpetuating, not transient.

### Why "just revoke the device" is also a dead end

`assertReenrollmentAllowed` (`device-register/index.ts:53-102`) fires on the insert path (`:212`)
and demands a `pairing_requests` row with `status = 'approved'` and `responded_at >` the old
[REDACTED CREDENTIAL ROW]
`device_revoked` / "This child's device was revoked. A parent must remove and re-link this child
before another device can be enrolled." A plain revoke therefore still requires a fresh approved
pairing — and `private.revoke_device` cancels any `pending_child` request for that child anyway
(`20260101000100_functions.sql:485-489`), so you cannot pre-stage the approval.

---

## 1. What "Start device recovery" actually does — full trace

### 1.1 Call chain

| Step | File:line | Detail |
|---|---|---|
| Button | `lib/features/devices/device_detail_page.dart:176-184` | `AppButton(label: 'Start device recovery', icon: Icons.settings_backup_restore, outlined: true)` inside `SectionCard(title: 'Lost or reinstalled phone')` at `:163-187`; helper copy at `:168-174`; disabled once `controller.recoveryStarted` (`:181-183`) |
| Confirm | `device_detail_page.dart:470-484` | `ConfirmDialog` title `'Start device recovery?'` (`:473`), message (`:474-478`), `confirmLabel: 'Start recovery'` (`:479`), `destructive: true` |
| Controller | `lib/features/devices/device_detail_controller.dart:156-175` | `recoverDevice()` → sets `isRecovering`, awaits repository, then `recoveryStarted = true` and `load()` (`:163-164`) |
| Repository | `lib/data/repositories/supabase_device_repository.dart:114-121` | Edge Function `family-admin`, `action: 'recover_device'`, `body: {'device_id': deviceId}` |
| EF action | `supabase/functions/family-admin/index.ts:92-122` | `requireUser(..., { requireVerifiedEmail: true })` `:93`; `requireRole(profile, "parent")` `:94`; `readUuid(body.device_id)` `:95`; then `db.rpc("request_device_recovery", { p_device_id, p_actor_user_id })` `:96-99` |
| SQL wrapper | `supabase/migrations/20260101000400_device_recovery.sql:73-88` | `public.request_device_recovery` SECURITY DEFINER → `private.request_device_recovery`; `revoke ... from public, anon, authenticated` / `grant execute ... to service_role` |
| SQL body | `20260101000400_device_recovery.sql:15-71` | `select * ... for update` `:28-31`; `device_not_found` `:33`; active-parent-in-that-device's-family check `:36-44` (`forbidden`); **delegates to `private.unlink_child(v_device.family_id, v_device.child_user_id, p_actor_user_id)`** `:46-50`; audit `device_recovery_started` `:52-64`; returns `v_result || {recovery:'started', old_device_id}` `:66-69` |
| Privilege hardening | `supabase/migrations/20261030000200_phase1_authorization.sql:448-463` | revokes default PUBLIC EXECUTE on `private.request_device_recovery(uuid,uuid)` |
| Behaviour proof | `supabase/tests/45_device_recovery.sql:79-144` | asserts `status='unlinked'`, `devices_revoked>=1`, `family_members.status='removed'`, old device `status='revoked'` and `secret_hash is null`, pending requests cancelled, exactly one audit row, no secrets in audit metadata, repeat call `already_removed=true` |

### 1.2 What it mutates — `private.unlink_child` (`20260101000100_functions.sql:325-427`)

| Object | Statement | Effect |
|---|---|---|
| `family_members` | `:375-377` | `status='removed', removed_at=now()` — **UPDATE, not DELETE**; the row id survives |
[REDACTED CREDENTIAL ROW]
| `device_pairing_tokens` | `:398-401` | every `active` token for that child → `revoked` |
| `pairing_requests` | `:403-406` | every `pending_child` request for that child → `cancelled, responded_at=now()` |
| `audit_logs` | `:408-416` | `member_removed` |

Guard rails: actor must be the child or an active parent of that family (`:340-353`); the membership
row must exist (`:361-363`, `membership_not_found`); already-removed returns
`{already_removed: true, devices_revoked: 0}` (`:364-373`) — **idempotent**.

Note the `devices_revoked_consistency` check `status <> 'revoked' or secret_hash is null`
(`20260101000000_core.sql:112-113`) pins the invariant the telemetry guard relies on.

### 1.3 Answering the question literally

[REDACTED CREDENTIAL ROW]
* **Delete the `devices` row?** **No.** The row survives with its `id` and `installation_id`
  (`devices_family_installation_key`, `core.sql:111`), keeping the old device permanently listed on
  the parent Devices tab and keeping its history joins intact.
* **Remove the family link?** Yes — the child's `family_members` row flips to `removed`.
* **Unlink/delete the child account?** **No.** `auth.users`, `profiles`, `child_contact_ids` are
  untouched. The Child ID is unchanged.
* **Scope:** recovery is keyed on `v_device.child_user_id` (`20260101000400:46-50`), **not** on the
  device. Pressing it on one device revokes *every* non-revoked device that child owns and removes
  the child from the family entirely.

### 1.4 What survives

`devices` rows (old id, installation_id, created_at, all history columns), every `location_events`,
`usage_daily`, `device_apps`, `policy`/`device_commands`, `safe_zones`, `alerts`, all `audit_logs`,
the `family` row, the parent's membership, the child's auth account + profile + Child ID.

### 1.5 Is it reversible?

Yes, and by design: `private.respond_pairing_request` reactivates **the same** `family_members` row
— `update public.family_members set status='active', removed_at=null where id = v_existing.id`
(`20260101000100_functions.sql:264-270`) — because `unlink_child` only flipped `status`, and
`removed_at` is nulled to satisfy `family_members_removed_consistency` (`core.sql:64-65`).
Not reversible: the nulled `secret_hash`, and there is no in-app "undo".

---

## 2. Exact required sequence, both devices

Strings below are verbatim from source. Route/tab is given so you can find the widget; tap by the
label, not the route.

### 2.0 Baseline evidence before you start

* Child **Settings** tab → "Background protection" card
  (`child_settings_tab.dart:267-306`): chip "Running"/"Not running", rows `Service`,
  `Last command check`, and the warning `InfoBanner` holding the E-1 string (`:287-294`).
* Parent **Devices** tab → the device card's presence chip (`parent_devices_tab.dart:168`) and
  `Last seen` row (`:172-177`).

### 2.1 PARENT — start recovery

1. Bottom navigation **`Devices`** (`lib/features/parent_shell/parent_shell_page.dart:37`).
   AppBar title `Devices`; refresh action tooltip `Refresh devices` (`parent_devices_tab.dart:19-25`).
2. On the child's card, TextButton.icon **`Open device`** (`parent_devices_tab.dart:205-212`).
3. Scroll to section card **`Lost or reinstalled phone`** (`device_detail_page.dart:164`). Body copy
   `:168-174`. Tap **`Start device recovery`** (`:177`).
4. Dialog **`Start device recovery?`** — body: "This revokes the current credential and removes the
   child from the family. The child must sign in, create a new linking code and approve the new
   pairing before this phone can report again. Only start recovery for a phone you still control or
   that was reinstalled." Tap **`Start recovery`** (`:473-480`).
5. Confirm it took: info banner **`Recovery started on the server`** appears **above** the card
   (`:150-162`), and `Start device recovery` greys out. Copy is at `:155-159`. On failure you get
   **`Could not start recovery`** (`:145-146`).
   > The banner's instruction "create a new linking code" is **not actionable** — see §4.1. Use the
   > Child ID.
6. Optional cross-check: the old row's chip now reads **`Revoked`**
   (`lib/data/models/device.dart:434`), and reopening it shows the danger banner **`Device revoked`**
   (`device_detail_page.dart:82-92`). The child disappears from Family → **`Children`**
   (`lib/features/family/family_page.dart:353`).

### 2.2 CHILD — surface the Child ID

7. **Home** tab (`child_shell_page.dart:30`, label `Home`). The enrollment card title becomes
   **`Link this phone`** and the button **`Set up linking`**
   (`lib/features/child/tabs/child_home_tab.dart:212, 228`, both open `/child/enrollment`).
   If the card still claims the phone is registered, pull-to-refresh or force-restart the app;
   the child polls membership on shell load only.
8. Tap **`Set up linking`** → AppBar **`Set up this phone`**
   (`lib/features/child/child_enrollment_page.dart:47`), refresh tooltip
   `Refresh setup state` (`:50`).
9. Card **`Your Child ID`** (`:185`) with trailing chip **`Not linked`** (`:187`), status line
   **`Status: Not linked to a parent`** (`:182`), and the large selectable ID
   (form `[REDACTED CHILD ID]`, `:223-232`). Buttons **`Copy ID`** (`:248`) and **`Show QR`** (`:262`); QR
   content is `parentcontrol://pair?id=<canonical>&v=2`
   (`supabase/functions/pairing/index.ts:270`). Caption `:290`.
10. Optional: **`Check for requests`** (`:301`) refreshes the inbox.
    Until the parent acts you'll see the info banner "No guardian request has arrived yet. Your
    guardian needs to enter your Child ID in the parent app. Keep this screen open or check again."
    (`:342-348`).

### 2.3 PARENT — open the pairing request

11. Easiest route: **`Settings`** tab → card **`Family`** → **`Family details`**
    (`lib/features/settings/settings_body.dart:88-111`). Then card **`Family actions`**
    (`family_page.dart:301`) → **`Link a child`** (`:307`). (Dashboard → Family → Family details
    reaches the same page, `parent_dashboard_tab.dart:169-176`.)
12. AppBar **`Link a child`** (`lib/features/pairing/pairing_redeem_page.dart:94`). Two controls:
    * **`Scan the child’s QR code`** (`:142`) — live viewfinder, caption
      `Point the camera at the child’s QR code` (`:561`). Accepts both
      `parentcontrol://pair?id=…&v=2` and `…?code=…&v=1` (`:144-147`). Camera-denied panel offers
      **`Start camera`** (`:536`).
    * **`Or enter the Child ID or linking code`** (`:175`) — field label
      **`Child ID or linking code`**, hint **`[REDACTED CHILD ID] or 4K9M2QRT`** (`:184-185`) → button
      **`Send pairing request`** (`:193`). **This is the reliable one for the emulator.**
13. Result: card **`Server response`** (`:270`) with rows `Child`, `Family`, `Status`, `Requested`,
    `Expires` (`:274-291`), plus banner **`Waiting for child approval`** (`:241`). While pending the
    screen polls `list_family` every 10 s (`pairing_redeem_controller.dart:17, 153-168`); manual
    button **`Check status`** (`:301`).
    Expected error titles if it misfires: `Child ID or code not recognised`, `Child already linked`,
    `Too many attempts` (`pairing_redeem_page.dart:334-353`).

### 2.4 CHILD — approve, then register

14. Back on **`Set up this phone`**: card **`Waiting for your approval`**, subtitle "Approve only if
    you recognise the guardian and family below." (`child_enrollment_page.dart:326-330`), row
    `<family>` / `From <guardian> · expires <relative>` (`:376-386`), buttons **`Decline`** (`:398`)
    and **`Approve`** (`:409`).
    Equivalent surface: **Requests** tab (`child_shell_page.dart:48`) → card `Linking requests`
    (`child_requests_tab.dart:81-83`) → **`Review and respond`** (`:141`) → `/child/requests` →
    card `Linking requests` (`child_requests_page.dart:92`) → `Approve`.
15. Dialog **`Join <family>?`** → **`Approve`** (`child_enrollment_page.dart:428-432`; the Requests
    page variant is `:156-163`).
16. Success banner **`Done`** / **`Family linked. Finish registering this phone below.`**
    (`child_enrollment_controller.dart:251-253`).
17. The screen now swaps to **`Register this phone`**, subtitle `Family: <name>`
    (`child_enrollment_page.dart:442-443`), body copy `:447-451`, field **`Phone name`** hint
    **`For example: Sam’s phone`** (`:466-468`), button **`Register this phone`** (`:479`).
    **Tap it.** (Also fired by keyboard "done" on the field, `:472-475`.)
18. Expected success banner: **`This phone is registered. Open My phone to review rules,
    permissions and requests.`** (`child_enrollment_controller.dart:315-317`). Card becomes
    **`This phone is set up`** with chip **`Registered`** (`:141-146`) → **`Open My phone`** (`:167`).
    Expected failures: `Link a family before registering this phone.` (`:270-273`),
    `Device registration is available only in the Android app.` (`:289-293`),
    `This account already has an active device.` / `This child's device was revoked…` from the EF.
19. If a **`Skip for now`** (`:506`) or **`Back`** (`:130`) is pressed before step 17, the device row
    is never created and E-1 persists as "no device at all".

### 2.5 CHILD — re-arm the uploader

20. **Settings** tab → AppBar `This phone settings` (`child_settings_tab.dart:18`) →
    **`Android permissions`** card: re-grant anything still missing (`:129-207`).
21. **`Background protection`** card (`:267-306`) → **`Retry background protection`** (`:297`).
    This runs `retryBackgroundSync()` (`child_shell_controller.dart:839+`), which re-reads the
    identity, re-invokes `configureBackgroundSync` with the NEW device id + NEW secret and restarts
    `GuardianService` — do not wait for the 5-minute scheduler tick.

### 2.6 PARENT — confirm the new device

22. **Devices** tab → `Refresh devices`. Expect **two** cards: the old one chipped `Revoked`, and a
    new one starting at `Never synced`.
23. **`Open device`** on the new row: no `Device revoked` banner; `Device identity`
    (`device_detail_page.dart:193-196`) fills in as heartbeats land.

---

## 3. Verification checklist (ordered; each item is UI text or a DB column)

### 3.1 Child-side, in order

| # | What changes | Source | Proof value |
|---|---|---|---|
| V1 | Home card `Family linked — finish this phone` + `Finish phone setup` (not `Link this phone`) | `child_home_tab.dart:212, 228` | pairing approved, device row not yet created |
| V2 | Done banner `Family linked. Finish registering this phone below.` | `child_enrollment_controller.dart:252` | `respond_pairing_request` returned `approved` |
| V3 | Done banner `This phone is registered. Open My phone…` + card `This phone is set up` + chip `Registered` | `child_enrollment_controller.dart:315-317`; `child_enrollment_page.dart:141-146` | EF returned the new device row; `_session.setActiveDevice`/`setDeviceIdentity` applied (`:310-314`) |
[REDACTED CREDENTIAL ROW]

### 3.2 Parent-side, in order

| # | What changes | Source |
|---|---|---|
| V6 | `Devices` list grows a second card; new card's chip goes `Never synced` → `Offline` → **`Online`**; old card pinned at **`Revoked`** | `parent_devices_tab.dart:80-99, 168`; `device.dart:384, 404-410, 433-447` |
| V7 | New device detail has **no** `Device revoked` banner; `Device identity` permission/battery rows populate; `Policy` row stops being `No policy applied yet` after the next apply | `device_detail_page.dart:82-92, 193+`; `device_presentation.dart:23-31` |
| V8 | Location page replaces the empty state **`No location reported yet`** | `lib/features/location/location_page.dart:263` |
| V9 | Family → **`Audit log (read-only)`** (`family_page.dart:321`) contains, in this order: **`Device recovery started`** (`device_recovery_started`, `lib/data/models/audit.dart:48-49`) → **`Child account unlinked`** (`member_removed`, `:34-35`) → **`Pairing approved`** (`:40-41`) → **`Device enrolled`** (`device_registered`, `:44-45`). `Linking code redeemed` (`:38-39`) appears only on the legacy-code path; the Child ID path writes `pairing_invited`, which falls through to the raw `pairing invited` label (`audit.dart:72-73`) |

### 3.3 What proves a FRESH heartbeat landed

* **Table/column: `public.devices.last_seen_at`.** It is the only presence write in the system:
  `device-telemetry/index.ts:68-119` — `requireDevice(req, db)` first (`:69`), then
  `const patch = { last_seen_at: new Date().toISOString() }` (`:79-81`) and
  `db.from("devices").update(patch).eq("id", device.id)` (`:113-118`). Battery/charging and the
  `capabilities` booleans (`usage_access_granted`, `location_granted`,
  `background_location_granted`, `camera_granted`, `microphone_granted`, `notifications_granted`,
  `enforcement_mode`) ride the same write (`:82-111`) — so a parent card showing fresh permission
  flags is a second, independent confirmation that the NEW credential authenticates.
  `policy_version` is deliberately **not** heartbeat-writable (`:84-85`).
* **Presence is computed, never stored.** `Device.onlineWindow = Duration(minutes: 12)`
  (`lib/data/models/device.dart:384`), `stalledWindow = 30 min` (`:389`);
  `syncHealth` (`:404-410`) → `healthy` iff `now - last_seen_at < 12 min`, `stalled` < 30 min, else
  `offline`. `statusLabel` (`:433-447`) renders `Online` / `Sync stalled` / `Offline` /
  `Never synced` / `Revoked`. The 12-minute window is 2× the 5-minute `HEARTBEAT_MS` tick plus 2
  minutes of scheduling grace (comment at `:379-383`; cadence in `GuardianService.kt`).
  Therefore: **`Online` on the parent for the NEW device id is only reachable if a heartbeat
  authenticated with the new secret arrived within the last 12 minutes.** There is no local
  optimistic override — `presenceChip` is shared by every screen (`device_presentation.dart:35-56`)
  and the controller docstring refuses to treat local flags as proof
  (`device_detail_controller.dart:132-133, 152-155`).
  Note `private.detect_offline_devices` (`20260101000100_functions.sql:531`) is a cron helper and
  `pg_cron` is absent on hosted (`docs/pairing-recovery-baseline.md` §3), so nothing but
  `last_seen_at` + the client window decides the label.

### 3.4 Confirming the OLD credential is now rejected

* **Server rule:** after `unlink_child`, the old row has `status='revoked'` **and**
  `secret_hash IS NULL` (`20260101000100_functions.sql:379-385`). `requireDevice` therefore fails at
[REDACTED CREDENTIAL ROW]
[REDACTED CREDENTIAL ROW]
* **Observable without touching either device:** the parent's old device detail page shows banner
  `Device revoked` with message "This device credential is revoked and it can no longer report or
  receive policies. The child must link the device again." (`device_detail_page.dart:83-90`) and the
  chip reads `Revoked`; `Revoke device` is disabled (`:129`). Audit rows `Device recovery started` +
  `Child account unlinked` exist exactly once per press (`45_device_recovery.sql:117-120`).
* **Why no stale uploader can keep reporting:** step 21 overwrote the native `SyncConfig` with the
  new `deviceId`/`deviceSecret` (`child_shell_controller.dart:599-605`), `GuardianService` notices
  via `configChanged` (`GuardianService.kt:291-297`) and discards the old pair, and
  `SecureStore.clearConfig()` drops the credential keys entirely
  (`SecureStore.kt:133-142`) on unlink/sign-out. Even a restored old pair would hit a nulled
  `secret_hash`.
* **Residual risk to watch:** `fetchDevices(familyId)` has **no status filter**
  (`supabase_device_repository.dart:31-40`), so the revoked row stays on the Devices tab forever with
  a live-looking `Open device` button. See §6.1.

---

## 4. Pairing: one-time code vs permanent Child ID

### 4.1 One-time linking code — implemented server-side, **absent from the child UI**

* Generation: `pairing` action `create`, `supabase/functions/pairing/index.ts:465-554`. Requires a
  **child** JWT with a verified email (`:466-467`) and refuses if the child is in any active family
  (`:469-483`, `child_already_linked`).
* Format: `generatePairingCode()` = **8 characters** from `23456789ABCDEFGHJKMNPQRSTVWXYZ`
  (Crockford-style, no `0O1I`), `_shared/validation.ts:12-14, 261-280`.
* Expiry: **10 minutes** — `CODE_TTL_MINUTES = 10` (`index.ts:42`, applied `:489-491`).
* Storage: `device_pairing_tokens` row `{child_user_id, code_hash = sha256(code), purpose:'code',
  status:'active', expires_at, created_by}` (`:493-513`). The plaintext code is returned **once** in
  the response together with `parentcontrol://pair?code=<CODE>&v=1` (`:549-553`).
  Minting a new code revokes the child's previous `purpose='code'` active tokens (`:517-525`) and
  cancels the `pending_child` requests attached to those replaced tokens only (`:533-540`).
* Limits: ≤5 live `code` tokens per 24 h, ≤10 creations per rolling hour
  (`_shared/rate_limit.ts:16-18, 116-160`).
* Redemption: action `redeem` (`index.ts:556-774`), **parent** role + `assertFamilyParent`
  (`:557-561`). `normalizePairingCode` strips non-alphanumerics and uppercases (`validation.ts:236-238`);
  token found by `code_hash` (`:584-588`); status/expiry re-checked and lazily flipped to `expired`
  (`:595-609`); child must not be active elsewhere (`:612-636`); replay-safe if a request already
  exists for this token (`:638-672`); then `db.rpc("create_pairing_request")` (`:678-684`) →
  `20260101000600_atomic_pairing_invite.sql:96-156`, advisory-locked on
  `(child, family, parent)`, inserting `pairing_requests (token_id, family_id, parent_user_id,
  child_user_id, status='pending_child', expires_at)`. Brute-force caps: 5 failed lookups per parent
  / 10 per identifier per 10 min (`rate_limit.ts:12-14, 51-88`).
* **UNVERIFIED-BUT-DECISIVE: no child-side caller exists.**
  `PairingRepository.createLinkingCode()` is declared (`lib/data/repositories/repository_contracts.dart:51`)
  and implemented (`supabase_pairing_repository.dart:72-88`) but a full-tree grep of `lib/features`
  returns **zero** call sites; `/child/enrollment` renders only the Child ID card
  (`child_enrollment_page.dart:176-362`). Consequence: the recovery banner text
  "…sign in, create a new linking code, then open Link a child here, redeem the code…"
  (`device_detail_page.dart:155-159`) and the confirm-dialog copy ("create a new linking code",
  `:476-477`) **describe a step that cannot be performed in the shipped app.** Do not hunt for that
  button. What you *can* type into the parent's "Child ID or linking code" field is a legacy code
  only if some other build produced one; otherwise use the Child ID. To settle: deploy a build with
  the `create` action wired, or read the hosted Edge Function version to confirm it matches
  `supabase/functions/pairing/index.ts`.

### 4.2 Permanent Child ID + QR (`parentcontrol://pair?id=…&v=2`) — **use this**

* Assignment: `pairing` action `get_contact_id` (`index.ts:456-463`), child role + verified email,
  calling `ensureContactId` (`:231-264`) which inserts into `child_contact_ids` once and is
  idempotent under the 23505 race.
* Format: `PC` + 8 unambiguous chars (`validation.ts:20-22, 283-285`), canonical
  `PCXXXXXXXX`, displayed `[REDACTED CHILD ID]` via `formatChildContactId` (`:255-259`). Client regex
  matches exactly (`lib/core/utils/validators.dart:7-8`), normalizer at `:61-62`.
* QR payload: `parentcontrol://pair?id=<canonical>&v=2` (`index.ts:266-273`), rendered by
  `QrImageView(data: contact.qrPayload)` (`child_enrollment_page.dart:280-284`). The parent scanner
  parses `?id=…&v=2` and legacy `?code=…&v=1` (`pairing_qr_payload.dart:35-46`).
* Opening a request: the parent's input is routed **by format** — `redeem` detects a Child ID at
  `index.ts:568-570` and calls `handleInvite` (`:283-443`); the explicit `invite` action (`:776-792`)
  is the same handler. It resolves `child_contact_ids → child_user_id` (`:292-302`), refuses
  non-child profiles (`:305-314`), refuses children already in an active family (`:316-340`),
  returns a **live** request for the same triple instead of spending quota (`:348-378`), then calls
  `db.rpc("create_pairing_invite")` (`:385-391`) → `20260101000600:25-90`, which under the same
  advisory lock mints an internal `purpose='invite'` token with a throwaway random `code_hash` and
  the request together.
* Expiry: **24 hours** — `INVITE_TTL_MINUTES = 24 * 60` (`index.ts:43-44`, applied `:382-384`), vs
  10 min for codes. Inbox caps: ≤3 pending, ≤10 per 24 h per child
  (`rate_limit.ts:20-21, 169-210`).
* Audit: `pairing_invited` with `metadata.via = "child_id"`, never the ID itself (`:414-428`).
* **Why it is the right choice for re-linking an already-known child:** `unlink_child` does not touch
  `child_contact_ids` (`20260101000100_functions.sql:375-406`), so the ID survives recovery
  unchanged; it needs no child-side action to mint anything (and §4.1 shows the child *cannot*
  mint); the 24 h window tolerates a two-device audit where you walk between handsets; and it is the
  documented fallback — "Use the child's permanent Child ID instead"
  (`pairing_redeem_page.dart:362-364`).

### 4.3 Approval and resulting state transitions

Child approves via `PairingRepository.respond()` (`supabase_pairing_repository.dart:147-165`) →
`pairing` action `respond` (`index.ts:828-843`, child role) →
`public.respond_pairing_request` → `private.respond_pairing_request`
(`20260101000100_functions.sql:189-320`), which locks the request (`:208-211`), verifies ownership
(`:215-217`), is replay-idempotent for `approved`/`rejected` (`:218-226`), enforces
`expires_at > now()` on both request and token (`:227-237`), requires the requesting parent to still
be active in the family (`:239-247`), then on approve:

| Table | Transition | Line |
|---|---|---|
| `family_members` | existing `(family, child)` row `removed` → **`status='active', removed_at=null`** (else INSERT) | `:259-274` |
| `pairing_requests` | `pending_child` → `approved`, `responded_at = now()` | `:276-278` |
| `device_pairing_tokens` | → `redeemed`, `redeemed_at`, `redeemed_by = parent` | `:280-282` |
| `audit_logs` | `pairing_approved` | `:284-292` |

Guard: a child active in **any** family raises `child_already_linked` (`:250-257`, plus the
`unique_violation` handler `:316-318` against
`family_members_one_active_child_family`, `core.sql:69-71`) → EF maps to 409
(`index.ts:200-206`).

Net effect of one full recovery cycle:

```
family_members      (same row id)  active -> removed -> active
devices  OLD row                   active -> revoked, secret_hash NULL, credential_revoked_at set
devices  NEW row                   INSERT active, new installation_id, new secret_hash,
                                   credential_issued_at = now, last_seen_at NULL until first beat
device_pairing_tokens              old active -> revoked; new 'invite' -> redeemed
pairing_requests                   pending_child -> approved (responded_at > old credential_revoked_at)
remote_sessions                    open -> ended (member_unlinked)
audit_logs                         member_removed, device_recovery_started,
                                   pairing_invited | pairing_redeemed, pairing_approved,
                                   device_registered
UNCHANGED                          families, profiles, auth.users, child_contact_ids,
                                   location_events, usage_daily, device_apps, safe_zones, policies
```

Ordering matters: `pairing_requests.responded_at` must be **later** than the old
[REDACTED CREDENTIAL ROW]
(`device-register/index.ts:212`). Approval-before-registration is therefore mandatory, not advisory.

---

## 5. Registration internals you are relying on

`device-register` (`supabase/functions/device-register/index.ts`) accepts only action `register`
(`:114-116`). Requires a **child** JWT with verified email (`:118-119`), then
`assertChildMembership(db, auth.user.id, familyId)` (`:141`, defined
`_shared/auth.ts:207-222`) — **so after recovery the child cannot register until the pairing is
approved**, since `unlink_child` removed the active membership. Payload rules: `family_id` UUID,
`installation_id` matching `^[A-Za-z0-9._:-]+$` len 8-128 (`validation.ts:10, 224-234`),
`secret_hash` 64-hex (`readHex64`), `display_name` 1-60 (`:121-139`).

Two outcomes, decided by whether `(family_id, installation_id)` already exists (`:143-152`):

[REDACTED CREDENTIAL ROW]
[REDACTED CREDENTIAL ROW]
  (`publicDevice`, `:44-49`). *This is the self-healing branch — unreachable after a reinstall,
  because the installation id is new.*
* **Insert** (`:197-245`) — refuses a second active device (`device_already_registered`, 409),
  refuses until a post-revoke approval exists (`device_revoked`, 403), then inserts
  `{family_id, child_user_id, installation_id, ...patch}` and audits `device_registered`.
  `23505` maps to `device_already_registered` (`:224-231`).

Uniqueness surfaces, all live in `core.sql`: `devices_family_installation_key`
`(family_id, installation_id)` unique `:111`; `devices_one_active_per_child` partial unique
[REDACTED CREDENTIAL ROW]

[REDACTED CREDENTIAL ROW]
raw fallback "device credentialed" — a cheap way to tell the two registration outcomes apart from
the parent UI alone.

---

## 6. Risks, irreversibility, and the least destructive choice

### 6.1 Path A — parent "Start device recovery" (RECOMMENDED, and the only one that works)

**Irreversible:** the old `secret_hash` (set to NULL), the identity of the old credential, and any
open remote-assistance session for that child (`ended`, `member_unlinked`). The old `devices` row
can never report again.

**Reversible / preserved:** the family link comes back on the *same* `family_members` row via
approval (§4.3); all telemetry history, the Child ID, zones, policies, the family itself.

**Specific hazards for this audit:**

1. **Blast radius is the child, not the device.** `request_device_recovery` passes
   `v_device.child_user_id` to `unlink_child`, whose device UPDATE is scoped
   `family_id AND child_user_id AND status <> 'revoked'` (`20260101000100_functions.sql:379-385`).
   Any second device enrolled for `a29448c5-23ee-461c-bdac-2f7daab4bbae` is revoked too
   (`docs/pairing-recovery-baseline.md` §2 records device `fd79ee34-c6fe-4abd-a3ae-39f9b16ed628`
   "realme RMX2161" in family `demo`). Confirm no other active device exists for that child before
   pressing.
2. **Do not touch the revoked row afterwards.** Because `fetchDevices` omits a status filter
   (`supabase_device_repository.dart:31-40`), the old row remains on the Devices tab with a working
   `Open device` → `Start device recovery` control. The guard `onPressed: controller.recoveryStarted
   ? null : …` (`device_detail_page.dart:181-183`) is a **per-page-instance** flag reset by
   `DeviceDetailController.onInit` (`device_detail_controller.dart:37-41`). Once the child is
   re-linked, tapping recovery on the stale row would call `unlink_child` again and tear down the
   new link. Prefer to keep the old row's detail page closed after step 21.
3. **It also cancels any in-flight pairing work** — every `active` token → `revoked` and every
   `pending_child` request → `cancelled` (`:398-406`). Start recovery **before** opening the invite,
   never after, or you destroy the very request you are about to approve. Sequence
   §2.1 → §2.2 → §2.3 is therefore load-bearing.
4. **A 24 h invite is durable, a code is not.** If you interleave other tests, the Child ID request
   survives the day (4.2); a `v=1` code dies in 10 minutes.
5. **EF error mapping gap:** `family-admin/index.ts:100-120` handles `device_not_found` and
   `forbidden` only. `unlink_child`'s `membership_not_found` (`functions.sql:361-363`) falls to
   `internal_error / "Device recovery could not be started."` (HTTP 500) with
   `console.error("request_device_recovery_rpc_failed:…")`. A 500 here most likely means the child
   was already removed from that family — not a server outage. Flag as a cosmetic contract gap, not
   a blocker.

### 6.2 Path B — parent "Revoke device" only (`device_detail_page.dart:123-140`)

Smaller blast radius (child stays in the family; only that one device is revoked; sessions ended
with `device_revoked`; pending requests cancelled — `functions.sql:467-489`). **It does not fix
E-1**: the child's `fetchMyDevice()` then returns null so `Register this phone` finally renders, but
the insert is blocked by `assertReenrollmentAllowed` → 403 `device_revoked` until a *newer* approved
pairing exists, and you cannot create one because the child is still `active` in the family
(`pairing` `create` refuses at `index.ts:469-483`; `handleInvite` refuses at `:316-340`).
**Strictly worse than Path A: same credential loss, no repair path.** Avoid.

### 6.3 Path C — child "Unlink this phone from the family"

`child_settings_tab.dart:314-321` → `ChildShellController.unlink()`
(`child_shell_controller.dart:1012-1069`) → `pairing` action `unlink` (`index.ts:945-984`), which
permits the child as actor (`:950-952`) → **the same `private.unlink_child` RPC**, so identical
server-side destruction to Path A. It additionally stops media capture, `_stopNativeServices`,
[REDACTED CREDENTIAL ROW]
puts recovery authority on the controlled handset — the opposite of the threat model
(`device-register/index.ts:51-52`: "the child cannot self-clear it"). **No advantage; avoid.** If
you want the child-initiated unlink as a *separate test case*, run it after Path A is proven.

### 6.4 Path D — direct SQL rewrite of `secret_hash` / `installation_id`

The only route that keeps the family link, the device row id and all session/policy state intact, so
it is nominally least destructive to the QA records. Rejected here: it needs the plaintext local
secret (in `EncryptedSharedPreferences`, deliberately never logged — `SecureStore.kt:21-24`), you
ruled out schema/data edits and secret exposure, and it bypasses every guard this migration set
exists to enforce. It is also **not a supported product path**, so an audit result obtained that way
would not describe real behaviour.

### 6.5 Least destructive *supported* choice

**Path A via the Child ID / QR (v2).** Nothing is deleted: `devices` rows, `family_members` rows,
telemetry history and the child's account all survive as status flips, and the family link is
restored on the same `family_members` primary key. Residual cost is one permanent `revoked` device
row plus the new `active` row (a Devices-tab duplicate) and five extra `audit_logs` rows — the
cheapest possible footprint for a genuine end-to-end proof that recovery restores telemetry. If
record tidiness matters afterwards, that duplicate is a known UI consequence of the deliberate
"never delete a device row" design (`core.sql:111`, `20260101000400_device_recovery.sql:4-5`), not a
defect you introduced.

---

## 7. Open items marked UNVERIFIED

| Item | Why it is not settled by source | What settles it |
|---|---|---|
| No child UI for the 8-char code (§4.1) | Grep of `lib/features` finds no `createLinkingCode()` caller; the EF action exists and is deployed | Read the hosted `pairing` function version, or grep a release APK's Dart snapshot for the `create` action string |
| Whether the hosted DB matches `supabase/migrations` (esp. `request_device_recovery`, `unlink_child`, `devices_one_active_per_child`) | Migrations are local files; hosted history is applied out-of-band (`docs/pairing-recovery-baseline.md` §3: "Hosted migration history still reads No migrations") | Read-only `select` on `pg_proc`/`pg_indexes` for those names — not attempted here |
| Whether the child's shell refreshes fast enough to notice the unlink (V1) | `fetchMyMembership` runs on shell/enrollment load; there is a 15 s pairing-inbox poll (`child_enrollment_controller.dart:43, 75-79`) but no membership poll | On-device observation; use `Refresh setup state` on `/child/enrollment` to force it |
| Whether a `Sync stalled` intermediate appears before `Online` | 12 min window vs 5 min `HEARTBEAT_MS` and Doze on RMX2161; realme battery optimisation can delay the tick | Timestamped screenshots of the parent chip over ~15 min, plus `Last command check` on child Settings |
| Exact guardian-service behaviour when the old config is replaced mid-cycle | `configChanged` (`GuardianService.kt:291-297`) re-reads the config; the in-flight tick's disposition is not asserted in tests | `docs/mic-lifecycle-test-plan.md` style on-device check; out of scope for this audit |

---

## 8. One-paragraph operator summary

Tap **Start device recovery** on the parent (Devices tab → `Open device` → card *Lost or reinstalled
phone*), confirm with **Start recovery**, and expect the banner **Recovery started on the server**.
That single press runs `family-admin/recover_device` → `request_device_recovery` → `unlink_child`,
[REDACTED CREDENTIAL ROW]
"create a new linking code" wording; the child app cannot do that. Instead open
**Set up linking** on the child (**Home** tab) to read the permanent **Your Child ID**
(`[REDACTED CHILD ID]`) / **Show QR**, then on the parent use **Settings → Family details → Link a child →
Send pairing request**. Back on the child, tap **Approve** in *Waiting for your approval*, then
**Register this phone** in the *Register this phone* card — this is the step that mints the new
`installation_id`/`secret_hash` pair and inserts the fresh `active` device row — and finish with
**Retry background protection** on the child's Settings tab. Proof of success is, in order: the
"Device credentials are not valid" banner disappears from child Settings, the new parent device card
reads **Online** (meaning `devices.last_seen_at` moved within 12 minutes under a credential that
passes `_shared/auth.ts:281-337`), the old card reads **Revoked** forever, and the family audit log
shows *Child account unlinked → Device recovery started → Pairing approved → Device enrolled*.
