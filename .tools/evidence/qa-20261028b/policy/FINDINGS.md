# Policy enforcement audit — why rules cannot suspend apps on RMX2161 and why policy is v0 / unacked

Scope: read-only. No source, migration, hosted config, data or device was modified.
Device under discussion: realme RMX2161, ordinary device admin, `dpm list-owners` reports no owner.

## 1. Where the child "cannot suspend other apps" text comes from

The sentence on **This phone settings** is static UI copy in
`lib/features/child/tabs/child_settings_tab.dart:232-239`:

- `:233` gate — `controller.canVerifySuspension`
- `:236-238` text — "Without Device Owner control this app cannot suspend other apps. Rules stay configured but are not described as enforced."

The same card also prints `controller.enforcementLabel` at `:230`
(`child_shell_controller.dart:109-118`; for an active admin with no owner this is
"Device admin only — app blocking is not available", `:115`).

Gate chain:

- `child_shell_controller.dart:90` — `bool get canVerifySuspension => isManaged;`
- `child_shell_controller.dart:89` — `isManaged => capabilities.value?.isFullyManaged`
- `lib/data/models/device.dart:666` — `bool get isFullyManaged => isDeviceOwner && canSuspendPackages;`
- `android/app/src/main/kotlin/com/parentcontrol/parent_control/NativeBridge.kt:127-148`
  builds capabilities; `:134` sets `"canSuspendPackages" to owner`.

Because `canSuspendPackages` is literally `owner`, the effective gate is
**Device Owner only**. Device admin is not sufficient; there is no accessibility
service anywhere in the Kotlin/Dart source (repo-wide search for
`AccessibilityService`/`accessibility` returns nothing), so accessibility is not
an enforcement path either.

Wording accuracy for a non-Device-Owner admin:

- Accurate on capability: `PolicyApplier.kt:94-101` refuses and adds
  "Device Owner provisioning is required to suspend apps on this device. No apps
  were suspended."; `:105-117` only calls suspend/restore inside `if (isOwner)`;
  `:236-244` calls `DevicePolicyManager.setPackagesSuspended`, which requires
  owner/profile-owner. An ordinary admin cannot do this.
- Inaccurate/incomplete on state: the card is unconditional (`child_settings_tab.dart:58`)
  and is shown even when `policy.value == null` (`child_shell_controller.dart:191,221-224,296-306`).
  "Rules stay configured" therefore claims rules exist when none may have arrived.
- Contradicted by another badge: the same policy's server status can render a green
  "Enforced on device" chip (`policy_summary_card.dart:65-70`,
  `lib/data/models/device.dart:234`) even while this card says it cannot suspend.

Also note the card's chip shows "Not managed" for an active device admin
(`child_settings_tab.dart:223-226` via `isManaged`), which is technically true for
full management but easy to read as "device admin is off".

## 2. Full policy lifecycle and where it breaks for a freshly re-enrolled device

### 2.1 Normal path

1. Parent saves: `lib/features/app_restrictions/app_restrictions_controller.dart:375-412`;
   `:393-401` calls `updatePolicy`.
2. Repository calls the `device-policy` edge function:
   `lib/data/repositories/supabase_policy_repository.dart:34-61`.
3. Edge validates and calls `apply_policy_version`:
   `supabase/functions/device-policy/index.ts:46-48,59-66`.
4. RPC computes `max(version)+1` **for that device only** and inserts:
   `supabase/migrations/20260101000100_functions.sql:147-150` (max),
   `:152-158` (policy row), `:160-176` (pending `apply_policy` command),
   `:174` (expiry `now() + 900 seconds`).
5. Device polls commands every 20 s: `GuardianService.kt:37-38,195-212,226-238`;
   server poll expires stale commands first and returns delivered commands:
   `functions.sql:596-651` (expiry `:614-618`, pick/deliver `:620-635`).
6. Device applies: `GuardianService.kt:267-281` -> `PolicyApplier.kt:31-153`.
   Suspension only under owner `:94-101,105-117`; result success is
   `errors.isEmpty()` `:137`.
7. Device acks: `GuardianService.kt:341-347` -> `device-command` ack
   `supabase/functions/device-command/index.ts:242-364`; policy row update
   `:318-335` (`succeeded` -> `enforced`, else `failed`), device version bump
   `:337-349`.
8. Parent polls the policy row for up to 6 x 5 s:
   `app_restrictions_controller.dart:453-480`.

### 2.2 Where re-enrolment breaks it

Policies are strictly per-device:

- `device_policies.device_id` FK + unique `(device_id, version)`:
  `core.sql:176-189` (`:178`, `:188`).
- `apply_policy_version` derives the next version only from rows for that
  `p_device_id`: `functions.sql:147-150`.

Enrolment (`supabase/functions/device-register/index.ts`):

- Same installation id: the existing device row is updated and keeps its id,
  so its old policies survive — `:143-195`.
- New installation id (app reinstall, new phone, cleared data): a **new device
  row** is inserted — `:197-223` — with `policy_version` default 0
  (`core.sql:102`) and **no** `device_policies` and **no** `device_commands`.
  There is no copy/inherit step. `device_policies` is referenced in edge code
  only for ack updates (`device-command/index.ts:323`) and the heartbeat max
  version (`device-telemetry/index.ts:47`); no function reads a previous
  device's policy to seed a new one.

Parent surfaces then legitimately show "nothing":

- Version falls back to `device.policyVersion` = 0:
  `device_detail_page.dart:248-251`.
- Acknowledged is null -> "Not yet acknowledged": `:257-262`.
- No command rows -> "No commands have been sent to this device yet.":
  `:378-388`.
- Parent App restrictions loads `fetchLatestPolicy(newDeviceId)` -> null, sets
  `policyReady=true`, and an empty draft (`app_restrictions_controller.dart:158-174`),
  so the old rules are not visible or preserved.

Command expiry is a second, independent break: `apply_policy` lives 900 s
(`functions.sql:174`), poll marks it `expired` (`:614-618`), and an ack after
expiry is refused (`device-command/index.ts:272-289`). A phone offline longer
than 15 minutes at save time never receives that version; nothing re-issues it.
The heartbeat's `pending_policy_version` only wakes the poller
(`GuardianService.kt:385-388`; `device-telemetry/index.ts:150-154`); it does not
create a replacement command.

On the child side, `null` is rendered as "No rules on this phone yet"
(`child_restrictions_page.dart:84-98`) / "No rules have arrived yet"
(`child_rules_tab.dart:81-95`), with no distinct "rules exist server-side but
this device has none / could not be loaded" state. `policyError` is only set on
an exception (`child_shell_controller.dart:296-306`), not on an empty result.

## 3. Is "Version 0 / not acknowledged" expected after re-enrolment?

Yes for a **new device row**, and it is not a device fault:

- `devices.policy_version` defaults to 0 (`core.sql:102`).
- No policy row exists for the new id, so the parent card shows 0 and null ack
  (`device_detail_page.dart:248-262`).
- No command exists, so "No commands have been sent" is also literal
  (`:378-388`).

It is **not** expected when re-registering the **same installation id**: that
path updates the same row (`device-register/index.ts:143-195`), so version and
history are retained. Version 0 therefore identifies a new installation/new
device row, not a device that refused a policy.

The app never asks the server to issue/materialise a fresh policy:

- Child read is a direct PostgREST select on `device_policies`
  filtered by `device_id` (`supabase_policy_repository.dart:22-31`),
  invoked from `child_shell_controller.dart:296-306`.
- The only policy edge action is `update`, and it is parent-only
  (`device-policy/index.ts:46-48,50-54`). There is no device-authenticated
  "latest policy" endpoint.
- Native `sync_policy` does **not** fetch anything: `GuardianService.kt:283-298`
  calls `applier.applyStoredPolicy()`; `PolicyApplier.kt:155-177` reads
  `store.policyJson()` and fails with "No policy has been stored on this device
  yet." if absent. `tick()` likewise replays the local JSON
  (`PolicyApplier.kt:180-183`).
- `sync_policy` is only created by the parent's "request sync" button
  (`app_restrictions_controller.dart:430-451`). Its ack updates no
  `device_policies` row because it has no `policy_id`
  (`device-command/index.ts:318-319`).

Consequence: a reinstall with lost app data can never recover the old policy by
itself. Even a surviving local JSON (SecureStore `policyJson`,
`SecureStore.kt:161-180`) can be replayed by the 60 s tick after the identity is
switched to the new device id, but that produces no server command/ack and the
server stays at version 0. That is also a stale cross-enrolment replay risk.

## 4. What "cannot be enforced" looks like end-to-end; badges

DB states (`core.sql:185-186`): `pending`, `enforced`, `failed`, `unsupported`.
Model labels (`device.dart:212-241`): "Waiting for device", "Enforced on device",
"Enforcement failed", "Not supported on device".

There is no `synced` or `applied` policy state. `device_commands.status`
(`pending/delivered/succeeded/failed/expired`, `core.sql:205-206`) carries
delivery/apply, but `device_policies` collapses it:

- `succeeded` -> `enforced`, anything else -> `failed`
  (`device-command/index.ts:321-330`).
- `unsupported` is never written by any function. Grep shows it only in the DB
  check/default (`core.sql:186`) and read-only model/UI. Therefore the
  "Unsupported on this device" branches (`device_detail_page.dart:281-292`,
  `app_restrictions_page.dart:298-309`) are unreachable via the server path.
- `unsupported_packages` exists only inside `device_commands.result`
  (`PolicyApplier.kt:294`), not in the policy status.

False-enforcement badge is possible. `PolicyApplier` sets
`success = errors.isEmpty()` (`:137`). If the device is not Device Owner but the
desired suspend set is empty (no named blocks, a schedule window inactive at
apply time, or only uninstalled/protected packages — `:50-101`), no error is
added, the ack is `succeeded` (`GuardianService.kt:274-275`), and the server
writes `enforcement_status='enforced'`. The child summary then renders the green
"Enforced on device" chip with a shield (`policy_summary_card.dart:65-70`), and
the card has no local verification gate when used without `enforcementApps`
(`child_rules_tab.dart:98`). The same page simultaneously shows "Not enforceable
on this phone" (`child_rules_tab.dart:66-78`). Parent has a similar green banner
on `enforced` (`app_restrictions_page.dart:279-288`, caveated text) and a green
status chip on the device screen (`device_detail_page.dart:238-245`).
`PolicyEnforcementStatus.unsupported` is neutral only if it ever arrived.

Conversely, a non-owner policy with at least one desired app becomes `failed`
with the owner-required error (`PolicyApplier.kt:94-99`), not `unsupported`.
So "failed" currently mixes "OS refused" with "not capable".

## 5. Device Owner provisioning requirements, and would it fix suspension?

`docs/device-owner-provisioning.md` is explicit:

- Status: procedure only, not executed/verified (`:1-15`; `:778-797`).
- adb path requires a factory-reset, dedicated, no-account, single-user device
  (`:66-132`; preflight `:162-183`; `dpm set-device-owner` `:205-235`).
- The manifest declares only the admin receiver
  (`android/app/src/main/AndroidManifest.xml:85-95`) with an empty policy set
  (`android/app/src/main/res/xml/device_admin.xml:2-5`).
- QR/NFC managed provisioning is not implemented: no provisioning-mode,
  policy-compliance, PROVISION_MANAGED_DEVICE or NFC entry points (`:260-280`).
- Current APKs lack `android:testOnly` and the app has no
  `clearDeviceOwnerApp`; factory reset is the reliable teardown (`:707-755`).

Native code:

- Owner check `DevicePolicyManager.isDeviceOwnerApp` — `PolicyApplier.kt:222-227`.
- Actual suspend/restore — `PolicyApplier.kt:236-254` (`setPackagesSuspended`).
- Verification via `isPackageSuspended` — `:209-220`, required before ack success
  (`:119-134`).

If a device is legitimately provisioned as Device Owner, `isOwner` is true, the
desired set is suspended, and success requires DPM confirmation. So yes, DO
provisioning is the intended fix for suspension, subject to protected packages
(`:58-68`) and the app only seeing the current Android user. Note the app does
not detect profile-owner capability at all; its gate is strictly
`isDeviceOwnerApp`.

## 6. Proposed minimal fixes (not implemented)

1. **Inherit policy on re-enrolment (server, atomic).** In the new-device insert
   path (`device-register/index.ts:197-223`), copy the newest
   `device_policies` row for the same `child_user_id`/`family_id` from the prior
   device as version 1 of the new device, and create one pending `apply_policy`
   command. Put both in one RPC so no device is active without a policy. Mark it
   in audit as inherited so the parent can review/resave.
2. **Re-issue expired policy commands (server).** In the heartbeat handler
   (`device-telemetry/index.ts:68-155`), when
   `pending_policy_version > devices.policy_version` and no
   pending/delivered `apply_policy` exists, enqueue one. Alternatively lengthen
   the 900 s TTL (`functions.sql:174`). This closes the offline >15 min hole.
3. **Explicit "rules could not be loaded / none assigned" state.**
   - Child: when `policy == null`, distinguish "never configured" from
     "this enrolment has no policy" (e.g. expose a `policy_count` or
     `policy_inherited` flag from register/device read). Do not render
     "No rules on this phone yet" for a re-enrolled device with an older policy
     elsewhere (`child_restrictions_page.dart:84-98`,
     `child_rules_tab.dart:81-95`).
   - Settings copy: only say "Rules stay configured" when a policy actually
     exists (`child_settings_tab.dart:232-239`).
   - Parent: warn on the App restrictions/device screen when `latestPolicy ==
     null && device.policyVersion == 0` that this device has no assigned policy
     and previous rules were not inherited (`app_restrictions_controller.dart:158-174`,
     `device_detail_page.dart:248-262`).
4. **Accurate enforcement status.**
   - Ack handler: write `enforced` only when command succeeded, the device's
     `enforcement_mode` is `device_owner`, `result.unsupported_packages` is
     empty, and the confirmed suspended set covers the desired set. Otherwise
     write `unsupported` (with `last_error`) instead of a misleading `enforced`.
   - `PolicyApplier`: do not return `success=true` for a non-owner when the
     policy contains block candidates, even if the current window makes the
     desired set empty; include `unsupported_packages` in failure.
   - UI: gate the green "Enforced on device" chip on local Device Owner /
     confirmed suspension, or relabel it "Acknowledged by device" so it does not
     claim OS enforcement (`policy_summary_card.dart:65-70`,
     `device.dart:234`).

These are minimal: one enrolment RPC change, one heartbeat re-issue, explicit
empty/unknown copy, and one ack-status rule. No device-owner workaround is
possible without real provisioning.

## Key references

| Topic | File:line |
|---|---|
| Child settings wording / gate | `lib/features/child/tabs/child_settings_tab.dart:230-239` |
| Capability gate | `lib/features/child/controllers/child_shell_controller.dart:89-90`; `lib/data/models/device.dart:666` |
| capabilities `canSuspendPackages=owner` | `android/app/src/main/kotlin/com/parentcontrol/parent_control/NativeBridge.kt:127-148` |
| Non-owner refusal | `android/app/src/main/kotlin/com/parentcontrol/parent_control/PolicyApplier.kt:94-101` |
| Actual suspension | `PolicyApplier.kt:236-244`; confirmation `:209-220` |
| Policy save / version+command | `app_restrictions_controller.dart:375-412`; `functions.sql:147-176` |
| Per-device key | `supabase/migrations/20260101000000_core.sql:176-189` |
| Device insert / no inheritance | `supabase/functions/device-register/index.ts:197-223` |
| Command expiry | `functions.sql:174,614-618`; `device-command/index.ts:272-289` |
| Ack -> policy status | `supabase/functions/device-command/index.ts:318-349` |
| sync_policy is local only | `GuardianService.kt:283-298`; `PolicyApplier.kt:155-177` |
| Child fetch by device id | `lib/data/repositories/supabase_policy_repository.dart:22-31` |
| False "enforced" success | `PolicyApplier.kt:137`; `policy_summary_card.dart:65-70` |
| DO procedure | `docs/device-owner-provisioning.md:1-15,149-235,260-280,707-797` |
