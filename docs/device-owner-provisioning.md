# Device Owner provisioning for a dedicated test device

Status: **PROCEDURE ONLY — NOT EXECUTED, NOT VERIFIED.**

Nothing in this document has been executed. No adb command was run against the
attached realme RMX2161 (`5HXWRGQ4IFU8WS4T`). That phone was not factory-reset,
rooted, unlocked, provisioned, or otherwise modified. Device Owner provisioning,
Instagram suspension, restoration, reboot persistence, expiry restore and QR
provisioning all remain **BLOCKED / NOT TESTED** and **NOT IMPLEMENTED** as
described below. The existing verification report is unchanged
([verification-report.md](verification-report.md), rows 22, 23 and 30, and the
residual-gap list).

This document describes what an operator would do on an authorized, dedicated,
disposable test device. It is not evidence that any step works.

## 0. Scope and what the code already supports

Scope of this document: read-only analysis of the repository plus a proposed
procedure. Only this file is new. No code, manifest, Gradle, migration, config or
other document was changed.

### 0.1 Implemented native and Flutter behavior

| Capability | Status in code | Evidence |
|---|---|---|
| Device admin receiver declared, exported, protected by `BIND_DEVICE_ADMIN` | Present | `android/app/src/main/AndroidManifest.xml:85-95` |
| Device admin policy XML requests no legacy password/lock policies | Present (`<uses-policies />`) | `android/app/src/main/res/xml/device_admin.xml:2-5` |
| Device Owner detection | Present (`isDeviceOwnerApp`) | `PolicyApplier.kt:222-227`; exposed to Flutter at `NativeBridge.kt:127-148` |
| Admin-active detection | Present (`isAdminActive`) | `PolicyApplier.kt:229-234` |
| User-visible enforcement state | Present: `device_owner`, `device_admin`, `none` | `GuardianService.kt:534-540`; heartbeat sends it at `GuardianService.kt:365-394` |
| `setPackagesSuspended(..., true)` | Present | `PolicyApplier.kt:236-244` |
| Restore via `setPackagesSuspended(..., false)` | Present | `PolicyApplier.kt:246-254` |
| Suspension confirmed with `isPackageSuspended(admin, pkg)` | Present; success is not inferred from the void setter call | `PolicyApplier.kt:119-134`, `PolicyApplier.kt:209-220` |
| Restore list when a rule/window is removed or expires | Present (`previous - desired`) | `policy/PolicyEvaluator.kt:13-15`; applied at `PolicyApplier.kt:103-117` |
| Protected packages (self, launcher, IME, Settings, System UI, phone, permission controller, Play Store, GMS) | Present | `policy/PolicyEvaluator.kt:27-76` |
| Policy and applied version stored locally | Present, encrypted preferences | `SecureStore.kt:162-179` |
| 60-second policy tick and 20-second command poll | Present | `GuardianService.kt:37-41`, `GuardianService.kt:184-193` |
| Policy command acknowledgement and version advance | Present | `GuardianService.kt:240-363`; server at `supabase/functions/device-command/index.ts:319-349` |
| Restart guardian after reboot / package replace | Present, with an Android 15 limitation | `BootReceiver.kt:17-52`; `android/app/src/main/AndroidManifest.xml:97-105` |
| Restore everything on unlink/sign-out | Present through `clearBackgroundSync` → `restoreAll` | `NativeBridge.kt:288-303`; `child_shell_controller.dart:836-846`, `871-891` |
| In-app Device Owner relinquish (`clearDeviceOwnerApp`) | **Absent** | Repo-wide search for `clearDeviceOwner` returns no call |
| QR/NFC provisioning entry point | **Absent** | Manifest has only the admin receiver's `DEVICE_ADMIN_ENABLED` filter; no provisioning mode/compliance activities or NFC permission |
| Realme/ColorOS Instagram variant or Android multi-user handling | **Absent** | Only the exact string `com.instagram.android` is matched; `InstalledAppsProvider` queries the current user only |
| Exact-alarm scheduling for window expiry | **Absent**; only the 60-second service tick | No `AlarmManager`/`WorkManager`/`JobScheduler` usage; `GuardianService.kt:184-193` |

Terminology note: there is no Kotlin `android.app.admin.DeviceAdminService`
subclass in this project. The Kotlin administration pieces are
`ParentControlDeviceAdminReceiver` (the receiver), `PolicyApplier` and
`PolicyEvaluator`. `DeviceAdminService` in `lib/data/services/device_admin_service.dart:16`
is the Dart MethodChannel facade, not an Android service.

### 0.2 The missing pieces relevant to this procedure

1. No provisioning-mode or policy-compliance activity, so modern QR provisioning
   has no entry point.
2. No release signing configuration: `release` uses the debug keystore
   (`android/app/build.gradle.kts:28-34`).
3. No hosted APK, APK checksum or signing-certificate checksum.
4. No `android:testOnly` flag, which matters for the only shell-based rollback
   (section 7.3).
5. No `clearDeviceOwnerApp` call, so the app cannot relinquish Device Owner by
   itself.
6. No handling for secondary Android users, app clones or OEM clone profiles.

## 1. Prerequisites

### 1.1 Device, account and OS state

Use a **spare device that may be factory-reset without losing anyone's data**.
The current build has no reliable non-reset rollback (section 7.3), so the device
must be treated as disposable for the duration of the test.

| Prerequisite | Requirement | Why |
|---|---|---|
| Device | Dedicated spare, factory-reset | Removes accounts, secondary users, clones and any prior owner. Never the RMX2161 or a personal phone |
| Accounts | None: no Google, OEM cloud, carrier, work or school account | A non-test-only owner is rejected while incompatible accounts exist on any user; current APKs are non-test-only |
| Users/profiles | Single user 0; no work profile, clone profile, private profile or secondary user | Android returns `STATUS_NONSYSTEM_USER_EXISTS`; the app has no multi-user handling |
| SIM | No SIM, or a test SIM that cannot trigger carrier/OEM provisioning; use Wi-Fi | Carrier provisioning can add accounts or finalize setup before `dpm` runs |
| Screen lock | No lock is recommended; the app requests no password/lock policy. If the OEM wizard forces one, use a documented test PIN only | `device_admin.xml` has empty `<uses-policies />`; a lock is not needed by this app |
| USB debugging | Developer options enabled, USB debugging on, host RSA key authorized | Required by the adb path; the app sets no `DISALLOW_DEBUGGING_FEATURES` or other user restriction |
| Network | Wi-Fi with access to the Supabase project | Enrollment, policy delivery and acknowledgements need HTTPS |
| Notifications | Granted when requested | Guardian service is a visible foreground service and refuses to start without notification permission |
| Battery | Charged; keep the device awake during timing tests | The 60-second tick and 5-minute heartbeat are not exact alarms |
| Test backend | Dedicated QA family and child account, not a personal family | Avoid mixing test policy data with real data |
| Android version | Minimum API 24. Recommend Android 10–14 (API 29–34), AOSP-like if possible | `setPackagesSuspended` is API 24+; Android 15+ has the app's dataSync-at-boot limitation; API 36 is untested on hardware |
| OEM extras | Avoid OEM clone/app-space features and preinstalled managed profiles | They create extra users and package clones the app does not manage |

Android version detail: the app's Flutter toolchain defaults are `minSdk = 24`
and `targetSdk = 36` (`FlutterExtension.kt:26` and `:34` in the pinned SDK), while
`android/app/build.gradle.kts:22-23` inherits them. The Android 12 device used for
the earlier report is technically capable, but it is explicitly out of bounds
for this procedure.

### 1.2 Why `adb shell dpm set-device-owner` fails with accounts or SIM provisioning

AOSP `DevicePolicyManagerService` checks provisioning preconditions before it
will set a device owner. The relevant outcomes are:

| AOSP precondition | Typical output |
|---|---|
| `STATUS_ACCOUNTS_NOT_EMPTY` | `Not allowed to set the device owner because there are already some accounts on the device.` |
| `STATUS_NONSYSTEM_USER_EXISTS` | `Not allowed to set the device owner because there are already several users on the device.` |
| `STATUS_HAS_DEVICE_OWNER` | `..., but device owner ... is already set.` |
| `STATUS_USER_HAS_PROFILE_OWNER` | `..., but the user already has a profile owner.` |
| `STATUS_HAS_PAIRED` | `Not allowed to set the device owner because this device has already paired.` |
| `STATUS_USER_SETUP_COMPLETED` | `Cannot set the device owner if the device is already set-up.` (non-adb/provisioning path; some OEM adb builds also report it) |

For the adb caller on AOSP Android 12+, a completed setup wizard is not by itself
an automatic refusal when there is exactly one user and no incompatible account;
the hard blockers are accounts and extra users. The current APKs are **not
test-only**, so the account check is strict: any account on any user is
incompatible. A SIM can trigger carrier/OEM provisioning, which may add an
account or mark the device as already provisioned, so the reliable baseline is
**no SIM, no account, one user, Wi-Fi only**. Do not try to clear the flags with
`settings put`, `pm remove-user` or account-database tricks; factory-reset and
start again.

### 1.3 Why this adb path is test-only

- `dpm set-device-owner` is a shell/development command, not Android Enterprise
  managed provisioning. Google documents adb provisioning for testing, not for
  production deployment.
- It requires physical USB access and an authorized debugging host.
- It bypasses the managed-provisioning/EMM signature and checksum checks and is
  recorded as the adb provisioning entry point in AOSP.
- It does not create an EMM enrollment or a managed Play configuration.
- The app itself never calls it; the receiver comment explicitly says so
  (`ParentControlDeviceAdminReceiver.kt:5-17`).

Use it only on a lab device. Production provisioning must use QR/NFC/zero-touch or
an EMM, which this app does not currently support (section 3).

### 1.4 Exact component name

Derived from the manifest receiver name (`.ParentControlDeviceAdminReceiver`,
`AndroidManifest.xml:85-95`) and the application ID/namespace
`com.parentcontrol.parent_control` (`android/app/build.gradle.kts:8,19`):

```text
Short form:      com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver
Fully qualified: com.parentcontrol.parent_control/com.parentcontrol.parent_control.ParentControlDeviceAdminReceiver
Package:         com.parentcontrol.parent_control
```

This is also recorded in [device-enrollment.md](device-enrollment.md), but that
document's rollback advice is incomplete; see section 7.3.

## 2. Provisioning path A: adb `dpm set-device-owner` (lab path)

All commands below use a placeholder serial. The guard is intentional: it refuses
to proceed if the target is the attached RMX2161.

```bash
DEDICATED_SERIAL='<DEDICATED_SERIAL>'
if [ -z "$DEDICATED_SERIAL" ] || [ "$DEDICATED_SERIAL" = '5HXWRGQ4IFU8WS4T' ]; then
  echo 'Refusing: choose an authorized dedicated device, not the attached RMX2161'
  exit 1
fi
```

### 2.1 Preflight on the dedicated device

```bash
adb devices -l
adb -s "$DEDICATED_SERIAL" shell getprop ro.product.manufacturer
adb -s "$DEDICATED_SERIAL" shell getprop ro.product.model
adb -s "$DEDICATED_SERIAL" shell getprop ro.build.version.sdk
adb -s "$DEDICATED_SERIAL" shell pm list users
adb -s "$DEDICATED_SERIAL" shell dpm list-owners
adb -s "$DEDICATED_SERIAL" shell dumpsys account | grep -i -E 'Accounts:|Account \{'
```

Proceed only when all of the following are true:

- The model/manufacturer is the intended spare, not RMX2161.
- `pm list users` shows only user 0.
- `dpm list-owners` reports no owner.
- No Google/OEM/carrier/work account is listed.
- No work profile, clone profile or app clone exists.

If any of these is not true, factory-reset the dedicated device and redo setup
without accounts. Do not modify accounts or users on a used device.

### 2.2 Install the APK

Build or select the APK to test. The debug APK is more observable (debuggable,
logcat), while the release APK has the same Device Owner behavior but is not
debuggable. Both current artifacts are **not** `android:testOnly`, so neither has
the shell rollback described in section 7.3.

```bash
# Example build; record the resulting hash before install.
fvm flutter build apk --debug --dart-define-from-file=.tools/live_config.env

adb -s "$DEDICATED_SERIAL" install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s "$DEDICATED_SERIAL" shell pm list packages | grep parent_control
```

Caution: the `app-debug.apk` currently in `build/app/outputs/flutter-apk/` is
older than the final debug build recorded in the verification report. Rebuild and
record size/SHA-256 before using it. Do not assume an existing file is the
verified artifact.

### 2.3 Set the Device Owner

Run this only after the preflight in 2.1, before adding any account:

```bash
adb -s "$DEDICATED_SERIAL" shell dpm set-device-owner --user 0 \
  com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver
```

Expected success output (wording varies slightly by Android version):

```text
Success: Device owner set to package ComponentInfo{com.parentcontrol.parent_control/com.parentcontrol.parent_control.ParentControlDeviceAdminReceiver}
Active admin set to component {com.parentcontrol.parent_control/com.parentcontrol.parent_control.ParentControlDeviceAdminReceiver}
```

Verify immediately:

```bash
adb -s "$DEDICATED_SERIAL" shell dpm list-owners
adb -s "$DEDICATED_SERIAL" shell dumpsys device_policy > dumpsys-device_policy.txt
```

Expected `dpm list-owners` line:

```text
User  0: admin=com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver,DeviceOwner
```

If the command prints any of the account/user/owner errors in section 1.2, stop.
Factory-reset the dedicated device; do not attempt a workaround.

### 2.4 First launch, enrollment and background service

1. Launch Parent Control on the dedicated device.
2. Sign in as the dedicated QA **child** account, create/redeem the pairing code
   and approve the guardian request as documented in
   [device-enrollment.md](device-enrollment.md).
3. Grant notification permission; grant Usage Access only if the test needs it
   (not required for Instagram suspension).
4. Start background protection. The guardian service must show its visible
   notification.
5. Confirm the child UI reports Device Owner (section 4.2), not merely Device
   Admin.

### 2.5 If the phone was previously enrolled without Device Owner

The app stores the last policy JSON locally before checking Device Owner
(`PolicyApplier.kt:37-39`). If a policy was saved while the device was not
Device Owner, it can be applied by the 60-second tick after provisioning, but
there will be no server command/ack and the parent policy row can remain
`failed`. After provisioning, **save a fresh policy version from the parent**
so a new `apply_policy` command is created and acknowledged. Do not conclude
from an old failed row that enforcement is broken.

## 3. Provisioning path B: QR/NFC managed provisioning

### 3.1 Honest current status

**QR and NFC provisioning are NOT SUPPORTED by the current manifest and build,
and have not been tested.** The only relevant declaration is the admin receiver's
`DEVICE_ADMIN_ENABLED` filter (`AndroidManifest.xml:85-95`). The manifest does
**not** declare:

- an activity for `android.app.action.GET_PROVISIONING_MODE`;
- an activity for `android.app.action.ADMIN_POLICY_COMPLIANCE`;
- a `android.app.action.PROVISION_MANAGED_DEVICE` entry point;
- an NFC permission or an `ACTION_NDEF_DISCOVERED` handler for
  `DevicePolicyManager.MIME_TYPE_PROVISIONING_NFC`;
- any code that parses a provisioning payload or admin extras.

A legacy QR payload can, on some Android versions, name the existing admin
component and set it as owner without those activities. That is not a supported
claim for this repository: there is no release-signed APK, no HTTPS-hosted APK,
no APK/certificate checksums, no QR generator and no device test. Do not use the
legacy path for this test.

### 3.2 Code/manifest changes needed before QR can work (not implemented)

1. **Release signing.** Create an organizational release keystore and configure a
   real `signingConfig`; the current release build uses the debug keystore
   (`android/app/build.gradle.kts:28-34`). Keep the keystore out of the repo.
2. **Host the APK.** Publish the exact signed APK at a stable HTTPS URL reachable
   during setup (or use the EMM's APK hosting).
3. **Compute checksums.** Compute the base64url SHA-256 of the APK bytes
   (`PROVISIONING_DEVICE_ADMIN_PACKAGE_CHECKSUM`) and of the signing certificate
   (`PROVISIONING_DEVICE_ADMIN_SIGNATURE_CHECKSUM`). Verify both against the
   hosted bytes.
4. **Add the Android 12+ DPC-in-the-loop entry points:**
   - an exported activity with the intent filter
     `android.app.action.GET_PROVISIONING_MODE`, returning the fully managed
     device mode;
   - an exported activity with the intent filter
     `android.app.action.ADMIN_POLICY_COMPLIANCE`, returning success after
     initial setup;
   - choose exported/permission attributes according to Android's current DPC
     docs; the provisioning controller launches these before any user login.
5. **Handle first-run state without a session.** The provisioning activities run
   before the child signs in; the current app has no such flow.
6. **Optional NFC.** Add `<uses-permission android:name="android.permission.NFC" />`
   and an `ACTION_NDEF_DISCOVERED` activity for the provisioning MIME type if NFC
   bump provisioning is required.
7. **Generate the QR offline or through an EMM.** Do not upload a QR containing a
   Wi-Fi password or test network details to a public service.

### 3.3 Future QR payload template (placeholders only)

```json
{
  "android.app.extra.PROVISIONING_DEVICE_ADMIN_COMPONENT_NAME": "com.parentcontrol.parent_control/com.parentcontrol.parent_control.ParentControlDeviceAdminReceiver",
  "android.app.extra.PROVISIONING_DEVICE_ADMIN_PACKAGE_DOWNLOAD_LOCATION": "https://<APK_HOST>/<PATH>/<SIGNED_APK>.apk",
  "android.app.extra.PROVISIONING_DEVICE_ADMIN_PACKAGE_CHECKSUM": "<BASE64URL_SHA256_OF_APK>",
  "android.app.extra.PROVISIONING_DEVICE_ADMIN_SIGNATURE_CHECKSUM": "<BASE64URL_SHA256_OF_SIGNING_CERT>",
  "android.app.extra.PROVISIONING_MODE": "android.app.extra.PROVISIONING_MODE_FULLY_MANAGED_DEVICE",
  "android.app.extra.PROVISIONING_WIFI_SSID": "<TEST_WIFI_SSID>",
  "android.app.extra.PROVISIONING_WIFI_PASSWORD": "<TEST_WIFI_PASSWORD>",
  "android.app.extra.PROVISIONING_WIFI_SECURITY_TYPE": "WPA"
}
```

The checksum values are placeholders; generate them from the exact hosted APK and
signing certificate with the EMM tooling or Android's documented base64url
SHA-256 procedure. Do not guess them. QR provisioning also requires a
factory-reset device with no account; on Android 12+ the QR scan is started from
the setup wizard's welcome screen (OEM gesture: usually several taps on the same
spot, then "Scan QR code"). Play Protect may block a newly signed DPC; do not
disable security on a production or personal phone.

## 4. Post-provisioning verification

### 4.1 adb checks

```bash
adb -s "$DEDICATED_SERIAL" shell dpm list-owners
adb -s "$DEDICATED_SERIAL" shell dumpsys device_policy > dumpsys-device_policy.txt
adb -s "$DEDICATED_SERIAL" shell dumpsys package com.parentcontrol.parent_control > dumpsys-dpc.txt
```

Look for:

- `dpm list-owners` → `User  0: admin=.../ParentControlDeviceAdminReceiver,DeviceOwner`.
- The device policy dump contains the Parent Control admin component and a
  Device Owner entry. Exact `dumpsys` formatting varies by OEM/API; do not use it
  alone.
- The package dump confirms the installed package and its flags.

### 4.2 App checks

| Screen | Expected after successful provisioning |
|---|---|
| Child Settings → Android control on this phone | `Device admin`: `Active`; `Device Owner`: `Provisioned`; enforcement label `Managed by Device Owner` |
| Child home | The warning `App blocking is not enforced on this phone` disappears (`child_home_tab.dart:98-110`) |
| Child Rules | `Not enforceable on this phone` disappears (`child_rules_tab.dart:66-78`) |
| Child restrictions | `Enforcement cannot be verified on this phone` disappears and `Device Owner` shows `Provisioned` (`child_restrictions_page.dart:124-137`, `251-258`) |
| Parent App restrictions | `App suspension unsupported on this device` disappears, but only after the server has the new heartbeat (`app_restrictions_page.dart:126-136`) |
| Parent device list/detail | Enforcement is `Device Owner` rather than normal install/device admin |

The child screens read native capabilities directly. The parent banner reads
`devices.enforcement_mode` from the server, which the heartbeat updates
(`supabase/functions/device-telemetry/index.ts:89-92`). The guardian heartbeat is
scheduled every 5 minutes (`GuardianService.kt:39`), though the first tick after
service start can send immediately. If the parent still shows unsupported, do
not assume provisioning failed: refresh, wait for a heartbeat, and check the SQL
in 4.3.

Generic, non-Device-Owner notices deliberately remain and are not failures:

- `A database flag does not block an app` on the parent restrictions screen.
- The generic "Rules apply after acknowledgement" text.
- The enrollment page's static note that a normal install is not a Device Owner
  (`child_enrollment_page.dart:307-311`); that page is not shown after enrollment.

### 4.3 Server checks (read-only SQL in the Supabase SQL editor)

Use placeholders; do not paste keys into shell commands. These are SELECTs.

```sql
select id, display_name, status, enforcement_mode, policy_version, last_seen_at
from public.devices
where id = '<DEVICE_ID>';

select version, enforcement_status, acknowledged_at, last_error,
       policy -> 'blocked_packages' as blocked_packages,
       policy -> 'app_rules' as app_rules
from public.device_policies
where device_id = '<DEVICE_ID>'
order by version desc
limit 3;

select id, type, status, acked_at, error_message,
       result -> 'suspended_packages' as suspended_packages,
       result -> 'unsupported_packages' as unsupported_packages,
       result -> 'errors' as errors
from public.device_commands
where device_id = '<DEVICE_ID>' and type = 'apply_policy'
order by created_at desc
limit 5;
```

Expected after a successful provisioning heartbeat:

- `devices.enforcement_mode = 'device_owner'`.
- `devices.last_seen_at` is recent.
- `devices.policy_version` matches the last **successfully acknowledged**
  policy (`supabase/functions/device-command/index.ts:319-349`).

## 5. Instagram suspension and restoration

### 5.1 Exact package names and variants

The parent shortcut matches exactly one package:

```dart
static const instagramPackage = 'com.instagram.android';
```

(`lib/features/app_restrictions/app_restrictions_controller.dart:19`; shortcut
selection at `:298-307`; availability test at `:104-107`.)

There is **no Realme/ColorOS-specific Instagram package mapping and no Android
multi-user handling** in this repository. The protected-package list contains
`com.oppo.launcher` for Realme/Oppo launchers
(`policy/PolicyEvaluator.kt:53`), but that is unrelated to Instagram. The
following are not handled automatically:

| App/variant | Package | Behavior |
|---|---|---|
| Instagram | `com.instagram.android` | Exact match; shortcut appears only if the child's app snapshot contains it |
| Instagram Lite | `com.instagram.lite` | Not in the shortcut; cannot be added from the current parent UI unless it appears in the reported app list and is toggled/typed, but there is no manual package field in the page |
| Threads | `com.instagram.barcelona` | Same limitation |
| Realme/ColorOS app clone | Same package in a secondary Android user | Not listed by `InstalledAppsProvider` (current user only) and not suspended by a user-0 Device Owner; outside this procedure |
| Other OEM clone/space packages | OEM-specific | No special casing |

Preflight the dedicated device:

```bash
adb -s "$DEDICATED_SERIAL" shell pm list packages | grep -i instagram
```

Expected for this test: only `package:com.instagram.android` in user 0. Install
Instagram in the primary user; do not create an app clone. If the Realme launcher
reports a different package, do not guess: use the exact reported package and
record it; suspension of clones in other users is not covered.

`com.instagram.android` is not in `PolicyGuard.CRITICAL_PACKAGES` and is not the
default home/IME, so it is eligible when installed
(`policy/PolicyEvaluator.kt:27-76`; `PolicyApplier.kt:51-74`).

### 5.2 Prepare the device and policy

1. Confirm Device Owner in section 4.
2. Confirm the guardian service is running with its visible notification.
3. Keep the dedicated device unlocked/awake for the timing test; the app has no
   exact-alarm scheduler.
4. Make sure `Block all except allowed` is **off**. Enabling it would suspend many
   unrelated user apps, not just Instagram (`app_restrictions_page.dart:411+`).
5. The parent needs a reported app snapshot. The guardian uploads apps every
   30 minutes (`GuardianService.kt:40`, `217-219`), and a successful
   `apply_policy` also triggers an upload (`GuardianService.kt:277-280`). The
   simplest bootstrap is:
   - Save a benign policy (no blocked packages) as version 1.
   - Wait for the child to acknowledge it; the parent should show it enforced.
   - Refresh App restrictions; the installed-app snapshot should now be present.
   - If it is still missing, wait for the next upload or request a device sync;
     do not assume "no apps installed."

### 5.3 Save the Instagram blocking policy

1. Parent → select the child device → **App restrictions**.
2. In the Instagram card, tap **Add** (`app_restrictions_page.dart:382-405`).
   The card only appears when the snapshot contains `com.instagram.android`.
3. Alternatively toggle Instagram in the installed-app list; either way it is
   added to `blocked_rules`.
4. Tap **Save restrictions**. The server creates a new `device_policies` version
   and an `apply_policy` command (API contract:
   [api-contract.md](api-contract.md), `device-command` section).
5. The child guardian polls every 20 seconds (`GuardianService.kt:37`), applies
   the policy, and acknowledges it.

What the code does on apply:

- `setPackagesSuspended(admin, ["com.instagram.android"], true)` is called for
  the eligible desired set (`PolicyApplier.kt:236-244`).
- Android's setter returns no value. The app then calls
  `isPackageSuspended(admin, "com.instagram.android")` for every desired and
  previously suspended package (`PolicyApplier.kt:119-134`, `209-220`).
- `success` is true only if there are no errors, including "Could not confirm
  that ... is suspended."
- The ack `result.suspended_packages` is the confirmed list, not the requested
  list. Never treat the policy row alone as proof.

### 5.4 Confirm suspension

Run after the parent reports `Policy v2 enforced` or the command status is
`succeeded`:

```bash
adb -s "$DEDICATED_SERIAL" shell dumpsys package com.instagram.android \
  > dumpsys-instagram.txt
grep -i -E 'suspended|enabled|stopped' dumpsys-instagram.txt

adb -s "$DEDICATED_SERIAL" shell dumpsys device_policy \
  | grep -i -E 'suspended|parent_control|Device Owner'

adb -s "$DEDICATED_SERIAL" shell dumpsys activity services \
  com.parentcontrol.parent_control
```

Expected, allowing for OEM/API wording differences:

- The package dump shows a suspended state (`suspended=true` or a `SUSPENDED`
  flag) and the package remains installed.
- The device policy dump mentions the Parent Control admin/owner and, on builds
  that print it, a suspended-packages section.
- The guardian service is running.

App/UI checks:

- Child → Rules/Restrictions: the app shows the Android-confirmed state. If every
  configured app is suspended, the child restrictions banner says
  `Android confirms the configured blocks` (`child_restrictions_page.dart:155-167`).
  If it says not every block is confirmed, do not claim suspension.
- Launcher: Instagram should be greyed/marked unavailable; tapping it should
  show Android's suspended-app dialog and must not open Instagram. OEM launchers
  differ, so icon appearance alone is not proof.
- Recents: no Instagram task should open.
- Notifications: Instagram notifications should stop; previously posted ones may
  be removed by the OS.
- Optional automated launch attempt:
  `adb -s "$DEDICATED_SERIAL" shell monkey -p com.instagram.android 1`.
  A monkey exit code of 0 is not proof; read its output and use the package dump
  and app UI as the authority.

Logcat filters:

```bash
adb -s "$DEDICATED_SERIAL" logcat -c
adb -s "$DEDICATED_SERIAL" logcat -v threadtime \
  | grep -i -E 'AndroidRuntime|DevicePolicyManager|PackageManager|suspended|parent_control|flutter'
```

On Windows PowerShell, replace the host-side pipe with
`Select-String -Pattern 'AndroidRuntime|DevicePolicyManager|PackageManager|suspended'`.
The app deliberately contains no `Log.*` calls for policy internals, so absence
of app log lines proves nothing. Use `dumpsys`, the child UI and the server ack.

Server checks for suspension (same SQL as 4.3):

- Latest `device_policies`: `enforcement_status = 'enforced'`,
  `acknowledged_at` set, `last_error` null, policy `blocked_packages` contains
  `com.instagram.android`.
- Corresponding `device_commands`: `status = 'succeeded'`,
  `result -> 'suspended_packages'` contains `com.instagram.android`,
  `unsupported_packages` and `errors` empty (or explain any entry).
- `devices.policy_version` equals the enforced policy version.
- `device_apps`: after the next app upload,
  `is_suspended = true` for `com.instagram.android` (`api-contract.md`,
  `device_apps`). This snapshot is refreshed every 30 minutes or on a successful
  policy apply, so it can lag the real suspension.

### 5.5 Remove the restriction and verify restoration

1. Parent → App restrictions → Instagram card/list → remove Instagram from the
   blocked list (or toggle it off).
2. Tap **Save restrictions**. This creates a new policy version and command.
3. Child guardian applies it. `PolicyApplier` computes
   `restoreList(previousSuspended, desiredSuspended)` and calls
   `setPackagesSuspended(admin, ["com.instagram.android"], false)`
   (`policy/PolicyEvaluator.kt:13-15`; `PolicyApplier.kt:103-117`, `246-254`).
4. Confirm with the same package dump, launcher tap and child UI checks:
   Instagram opens normally; the package dump no longer reports suspended; the
   child restrictions banner no longer claims Instagram is suspended.
5. Server checks:
   - Latest policy `enforcement_status = 'enforced'`, `devices.policy_version`
     advanced.
   - Latest command `result.suspended_packages` is empty.
   - Next `device_apps` upload has `is_suspended = false`.
6. Also test switching `enforce_app_blocks` off or removing all rules; both
   should produce an empty desired set and restore previously suspended packages.

Restoration is only claimed when `isPackageSuspended` returns false and the
launcher/app check agrees. Exact error strings that mean **not restored**:

- `Could not restore <package>.`
- `Previously suspended apps could not be restored because this app is no longer Device Owner.`
- `The system refused to restore apps: Device Owner access is missing.`

### 5.6 Timing and failures to expect in this test

- Parent ack polling is six attempts at five-second intervals
  (`app_restrictions_controller.dart:453-480`); the child poll can take 20 seconds.
  If the parent stops polling, tap **Refresh state**.
- Policy commands use a 900-second expiry (API contract). A device offline longer
  than that gets an `expired` ack; no suspension is applied.
- A benign policy is acknowledged as enforced only if the device is actually the
  owner. On a non-Device-Owner device the ack is `failed` with
  `Device Owner provisioning is required to suspend apps on this device. No apps
  were suspended.` (`PolicyApplier.kt:94-101`).
- If the child reports `unsupported_packages` containing Instagram, check that it
  is installed in the current user and is not an OEM clone in another user.

## 6. Reboot persistence and expiry restore

### 6.1 Reboot with Instagram suspended

Only on the dedicated device:

```bash
adb -s "$DEDICATED_SERIAL" reboot
adb -s "$DEDICATED_SERIAL" wait-for-device
# Repeat until it prints 1, then continue.
adb -s "$DEDICATED_SERIAL" shell getprop sys.boot_completed
```

After boot, before opening the app:

```bash
adb -s "$DEDICATED_SERIAL" shell dpm list-owners
adb -s "$DEDICATED_SERIAL" shell dumpsys package com.instagram.android \
  | grep -i -E 'suspended|enabled|stopped'
```

Expected:

- Device Owner persists.
- Android retains the suspended package state across reboot.
- On Android 14 and earlier, `BootReceiver` starts the guardian service if the
  guardian was configured, notification permission is granted and the app was
  not force-stopped (`BootReceiver.kt:29-51`). The service's first tick applies
  the stored policy.
- On Android 15+, `BootReceiver` deliberately refuses to start a `dataSync`
  foreground service from `BOOT_COMPLETED` and stores an error
  (`BootReceiver.kt:31-37`). Suspension remains, but policy re-application and
  schedule expiry do not resume until the app is opened and the service starts.
  This is a documented platform limitation, not a pass.
- `devices.last_seen_at` advances after the next heartbeat; `policy_version`
  should not change merely because of a reboot.

Do not treat a reboot as an enforcement test unless the package remains suspended
and the child UI can still verify it.

### 6.2 Schedule-window expiry restore

1. While Instagram is suspended by a plain block (no window), add a schedule
   window to the Instagram rule in the parent UI: include today, set the start to
   the current device-local time and the end to 2-3 minutes later.
   `PolicyWindow` uses ISO weekdays (Monday = 1) and local device time; a window
   can span midnight (`policy/PolicyModels.kt:3-22`).
2. Save the policy; the child applies it and confirms suspension.
3. Keep the device awake and the guardian service running. At the window end, the
   60-second `tick()` computes an empty desired set for Instagram and restores it
   (`GuardianService.kt:184-193`; `PolicyApplier.kt:103-117`).
4. Verify restoration with the package dump and launcher. Allow up to about one
   tick plus scheduling delay; Doze or battery optimization can delay the
   executor. There is no exact alarm in this build.
5. Check that the policy version did **not** change merely because the window
   expired: expiry is evaluated locally, not by a new server command. The parent
   UI may still show the same enforced version while Instagram is restored by
   schedule. Use the child UI/package state, not just the policy status, to judge
   a schedule.

### 6.3 Expiry/removal through policy change or unlink

- Saving a policy without Instagram produces a new version and an explicit
  restore.
- Child unlink or sign-out calls `clearBackgroundSync`, which calls
  `restoreAll()` and clears stored policy state
  (`NativeBridge.kt:288-303`; `child_shell_controller.dart:836-846`, `871-891`).
- If the guardian service is stopped without clearing the policy, the local
  suspension is not automatically restored and schedule expiry stops. The
  `stopGuardian` bridge method only stops the service; it does not call
  `restoreAll` (`NativeBridge.kt:257-262`). Do not use "stop the service" as a
  rollback while apps are suspended.

## 7. Failure modes and rollback

### 7.1 Provisioning failures

| Symptom | Likely cause | Action |
|---|---|---|
| `Not allowed to set the device owner because there are already some accounts on the device.` | Any account on any user; current APK is non-test-only | Factory-reset the dedicated device; skip all accounts |
| `... already several users on the device.` | Secondary user, work/clone/private profile, app clone | Factory-reset; do not delete users as a workaround |
| `... device owner ... is already set.` | Another Device Owner | Factory-reset or deprovision through the existing owner/EMM |
| `... already has a profile owner.` | Work profile or prior provisioning | Factory-reset |
| `Cannot set the device owner if the device is already set-up.` | OEM/adb path refuses after setup | Factory-reset; do not fake setup flags |
| `Invalid component ...` / `Not active admin` | Wrong class name, package not installed, receiver removed | Re-check the exact component in 1.4 and `pm list packages` |
| `dpm list-owners` empty after a reported success | Wrong user/serial; command targeted another device | Re-run with the dedicated serial and `--user 0` |
| `SecurityException` from `set-device-owner` | OEM policy, wrong user | Capture the full output; do not attempt bypasses |

### 7.2 Enforcement/ack failures

| Symptom | Likely cause | Action |
|---|---|---|
| Policy `failed` with `Device Owner provisioning is required ...` | `isDeviceOwnerApp` false | Check `dpm list-owners`; the parent heartbeat may be stale |
| `unsupported_packages` contains Instagram | Not installed in current user, clone in another user, or protected package | Check `pm list packages --user 0`; use the primary user's package |
| `Could not confirm that com.instagram.android is suspended.` | OS refused or package changed during apply | Capture logcat/dumpsys; do not claim suspension |
| Parent still shows `App suspension unsupported` | Heartbeat has not updated `devices.enforcement_mode` | Wait for heartbeat (up to 5 minutes), refresh, check SQL |
| No ack / policy remains pending | Guardian stopped, notification permission missing, network failure, command expired | Check child guardian status and `device_commands.status`; start the service and resave the policy |
| Instagram still opens | Clone in another user, Instagram Lite/Threads, or stale launcher icon | Re-check the exact package; only the primary-user `com.instagram.android` is covered |
| Restore error `Could not restore ...` | Service stopped or Device Owner lost | Re-start the service while still Device Owner; do not remove the owner first |
| `dpm remove-active-admin` refuses with `Attempt to remove non-test admin` | Current APK is not `android:testOnly` | Expected; factory-reset the dedicated device (7.3) |

### 7.3 Removing Device Owner and uninstalling on a test device

**Critical finding for the current build:** `dpm remove-active-admin` is not a
general escape hatch. AOSP's `dpm` help states that the admin "must have declared
`android:testOnly` in the application in its manifest" and that the command also
removes device/profile owners. The implementation calls
`forceRemoveActiveAdmin`, which throws
`SecurityException: Attempt to remove non-test admin ...` for a non-test-only
package. This repository's manifest has no `android:testOnly`, and a read-only
`aapt2` inspection of the current `app-debug.apk` and `app-release.apk` found
`debuggable=true` on debug but no `testOnly` on either artifact. Therefore:

- The recommendation in [device-enrollment.md](device-enrollment.md:89-94) to use
  `dpm remove-active-admin` is **not reliable for these APKs**.
- There is no `clearDeviceOwnerApp` call in the app.
- A Device Owner app cannot be normally uninstalled; `adb uninstall` is expected
  to fail with `DELETE_FAILED_DEVICE_POLICY_MANAGER`.
- **Factory reset is the only reliable teardown for the current build.**

Safe teardown order, if a test must end:

1. In the parent UI, remove Instagram / switch enforcement off and verify
   restoration (section 5.5).
2. Child unlink or sign-out, which calls `clearBackgroundSync` → `restoreAll`
   (`NativeBridge.kt:288-303`). Verify no package remains suspended.
3. Stop the app and confirm the guardian service is stopped.
4. Only if the installed APK was deliberately built with
   `android:testOnly="true"`, run:

   ```bash
   adb -s "$DEDICATED_SERIAL" shell dpm remove-active-admin --user 0 \
     com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver
   ```

   Expected on a test-only build: `Success: Admin removed ...` and then
   `dpm list-owners` reports no owner. This has **not** been executed here.
5. If step 4 throws `SecurityException: Attempt to remove non-test admin`, do not
   try `pm uninstall`, `pm clear`, disabling the admin in Settings, or deleting
   accounts/users. Factory-reset the dedicated device.
6. Factory reset from Settings or recovery. This removes the owner, the app, the
   suspended state and all local data. It must be an explicit owner decision and
   is acceptable only because the device is dedicated.

If a shell rollback is required for future lab work, the needed changes are
outside this document's scope: either build a dedicated test-only APK (add
`android:testOnly="true"` to a debug/test manifest; install with
`adb install -t`) or add an owner-only deprovision action that calls
`DevicePolicyManager.clearDeviceOwnerApp(packageName)` after restoring
suspensions. Neither is implemented.

### 7.4 What NOT to do

- Do **not** run any command in this document against the RMX2161
  (`5HXWRGQ4IFU8WS4T`) or any personal/production phone.
- Do not factory-reset, root, unlock the bootloader or disable verified boot on
  the RMX2161; the procedure does not require root.
- Do not provision a device that contains personal accounts, a personal SIM, a
  work profile, an app clone or data that cannot be wiped.
- Do not try to bypass account/user/owner checks with `settings put`,
  `pm remove-user`, account removal, or a "device already provisioned" flag.
- Do not rely on `dpm remove-active-admin` for a release/non-test-only build.
- Do not uninstall, clear data or disable the Device Owner app while packages are
  suspended. The tracked suspended list lives in encrypted preferences
  (`SecureStore.kt:162-179`); losing it prevents a controlled restore.
- Do not treat `setPackagesSuspended` as successful because the policy row says
  enforced; verify `isPackageSuspended`, the package dump and the launcher.
- Do not use QR/NFC for this app until the missing provisioning entry points,
  signing and hosting are implemented and tested.
- Do not use `adb reboot` on the RMX2161; reboot tests are for the dedicated
  device only.

## 8. Verification status statement

| Item | Status |
|---|---|
| This procedure executed on hardware | **NO** |
| RMX2161 factory-reset, rooted, provisioned or modified | **NO** |
| Device Owner set on any device in this work | **NO** |
| Instagram suspension via `setPackagesSuspended` | **BLOCKED / NOT TESTED** |
| Instagram restoration after removal | **BLOCKED / NOT TESTED** |
| Reboot persistence | **BLOCKED / NOT TESTED** |
| Schedule-window expiry restore | **BLOCKED / NOT TESTED** |
| QR/NFC provisioning | **NOT IMPLEMENTED / NOT TESTED** |
| Shell rollback (`dpm remove-active-admin`) | **EXPECTED TO FAIL on current APKs; NOT EXECUTED** |

The attached realme RMX2161 is still not a Device Owner. `dpm` was not run
against it, no package was suspended, and no factory reset or rooting was
performed. [verification-report.md](verification-report.md) rows 22, 23 and 30
and the residual gaps remain accurate; this document does not upgrade any of
them. A future device run may change these statuses only after it produces
captured evidence on an authorized dedicated serial.

## Appendix A: where the behavior lives

| Topic | File and lines |
|---|---|
| Admin receiver declaration | `android/app/src/main/AndroidManifest.xml:85-95` |
| No provisioning entry point | `android/app/src/main/AndroidManifest.xml:43-112` |
| No legacy password policies | `android/app/src/main/res/xml/device_admin.xml:2-5` |
| Admin component | `PolicyApplier.kt:28` |
| Non-owner honest failure | `PolicyApplier.kt:94-101` |
| Suspend/restore and confirmation | `PolicyApplier.kt:103-134`, `209-254` |
| Stored policy tick | `PolicyApplier.kt:180-183` |
| Restore list | `policy/PolicyEvaluator.kt:13-15` |
| Protected packages | `policy/PolicyEvaluator.kt:27-76` |
| Policy/version storage | `SecureStore.kt:162-179`, `199-205` |
| Poll/tick/heartbeat intervals | `GuardianService.kt:37-41` |
| Apply policy and ack | `GuardianService.kt:240-363` |
| Heartbeat enforcement mode | `GuardianService.kt:365-394`, `534-540` |
| App snapshot `is_suspended` | `GuardianService.kt:396-422`; `NativeBridge.kt:199-211` |
| Restore on clear/unlink | `NativeBridge.kt:288-303`; `child_shell_controller.dart:836-846`, `871-891` |
| Boot restart and Android 15 refusal | `BootReceiver.kt:17-52` |
| Instagram package | `app_restrictions_controller.dart:19`, `104-107`, `298-307` |
| Parent non-DO banner | `app_restrictions_page.dart:126-136` |
| Instagram shortcut | `app_restrictions_page.dart:151-154`, `382-405` |
| Child non-DO banners | `child_home_tab.dart:98-110`; `child_rules_tab.dart:66-78`; `child_restrictions_page.dart:124-137`, `251-258`; `child_settings_tab.dart:180-190` |
| Server ack/version | `supabase/functions/device-command/index.ts:319-349`; `api-contract.md:340-356` |
| Heartbeat enforcement mode | `supabase/functions/device-telemetry/index.ts:89-92` |
| Release signing is debug | `android/app/build.gradle.kts:28-34` |
| Current verification status | `verification-report.md:38`, `359-367`, `407-409`; `bug-report.md:709-716` |

## Appendix B: command template

All placeholders. Never substitute the RMX2161 serial.

```bash
DEDICATED_SERIAL='<DEDICATED_SERIAL>'
[ "$DEDICATED_SERIAL" != '5HXWRGQ4IFU8WS4T' ] || { echo 'Refusing RMX2161'; exit 1; }

adb -s "$DEDICATED_SERIAL" shell getprop ro.product.model
adb -s "$DEDICATED_SERIAL" shell pm list users
adb -s "$DEDICATED_SERIAL" shell dpm list-owners

adb -s "$DEDICATED_SERIAL" install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s "$DEDICATED_SERIAL" shell dpm set-device-owner --user 0 \
  com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver
adb -s "$DEDICATED_SERIAL" shell dpm list-owners

adb -s "$DEDICATED_SERIAL" shell dumpsys package com.instagram.android \
  | grep -i -E 'suspended|enabled|stopped'
adb -s "$DEDICATED_SERIAL" shell dumpsys device_policy \
  | grep -i -E 'suspended|parent_control|Device Owner'
adb -s "$DEDICATED_SERIAL" shell dumpsys activity services \
  com.parentcontrol.parent_control

# Teardown command; expected to fail on the current non-test-only APK.
adb -s "$DEDICATED_SERIAL" shell dpm remove-active-admin --user 0 \
  com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver

# Uninstall works only after the owner is gone.
adb -s "$DEDICATED_SERIAL" uninstall com.parentcontrol.parent_control
```
