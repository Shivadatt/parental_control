# App restrictions and the Instagram case

## What actually blocks an app

On Android, a parental-control app cannot block another app by writing a row to a
database. The only supported mechanism used here is **package suspension on a fully
managed device**:

- the device must be provisioned as a **Device Owner** (see
  [device-enrollment.md](device-enrollment.md));
- the Child app calls `DevicePolicyManager.setPackagesSuspended()` with the target
  package names;
- Android reports the suspended state back through `isPackageSuspended()`;
- only after that acknowledgement does the parent UI say **Enforced**.

A normal Play Store installation is not a Device Owner. On such a device the app
reports **Unsupported**, keeps the policy as pending for a managed device, and never
tells the parent that Instagram is blocked.

## Instagram

Instagram's package name is `com.instagram.android`. The restriction screen offers it
as a shortcut when the Child device has reported it in its installed-app snapshot.
Suspension is only possible if the package is installed and Android permits suspending
it. Instagram is not special-cased beyond the shortcut: the same validation, schedule
and acknowledgement rules apply.

## End-to-end flow

1. The parent edits a policy (blocked/allowed packages, per-app schedule windows,
   optional block-all-except-allowed).
2. The Flutter client calls the `device-policy` Edge Function with a new idempotency
   key. The server validates the schema, caller, family and device relationship.
3. The server atomically creates a new `device_policies` version and an
   `apply_policy` command containing the full policy (so it also works offline when
   the device reconnects).
4. The Child device's visible guardian foreground service polls, validates each
   package locally, applies the eligible rules and acknowledges the command.
5. The acknowledgement updates the policy row's `enforcement_status`, `last_error`
   and `acknowledged_at`, and the device's `policy_version`.
6. The parent UI refreshes and shows **Pending device acknowledgement**, **Enforced**,
   **Failed** (with the reported error) or **Unsupported**.

Duplicate commands are deduplicated by idempotency key and command id. Commands have
a short expiry; expired commands are not applied. If the device is offline, the
policy remains pending until it reconnects.

## Safety rails

- The Child app refuses to suspend its own package and system-critical packages
  (launcher, phone, Settings, System UI, permission controller, Play Store). These
  are reported as unsupported instead of being silently skipped.
- Removing a rule, a schedule expiring or switching enforcement off restores the
  packages that were suspended by this app.
- The app never uses Accessibility, root, hidden screens, device-owner bypasses or
  fake acknowledgements.
- A schedule window uses local device time for the Child device; the window may span
  midnight.
- `block_all_except_allowed` is deliberately a separate switch with a visible
  warning; it is not enabled by default.

## Current hardware limitation

The available test device is a realme RMX2161 on Android 12. It is **not** a Device
Owner, so package suspension cannot be executed on it. The implementation reports
that state honestly. Verifying actual Instagram suspension requires a factory-reset
device provisioned as Device Owner; that step was not performed and is recorded as
**BLOCKED / NOT TESTED** in the verification report.
