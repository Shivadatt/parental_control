# Parent Control

A single Android application with two modes — **Parent** and **Child** — built with
Flutter, GetX and Supabase. One package, one authentication system, two dashboards.
Nothing sensitive is enforced on the client: pairing, roles, family membership,
device commands and session authorization are decided by PostgreSQL RLS and Edge
Functions.

> Verification status is recorded in [docs/verification-report.md](docs/verification-report.md).
> This README does not claim that anything was deployed or tested unless that report
> says so with a status label.

## Architecture

- **Flutter 3.44.6 (FVM) / Dart 3.12.2**, Material 3, GetX controllers and bindings.
- **Supabase**: Auth, PostgreSQL with RLS, Edge Functions, private (RLS-protected)
  Realtime for commands, alerts, sessions and WebRTC signaling.
- **Native Android (Kotlin)**: Device Admin / Device Owner, app suspension,
  foreground guardian service, UsageStatsManager, location service, permissions.
- **WebRTC**: parent-initiated, child-consented sessions; TURN credentials are
  issued server-side and never shipped in the APK.

```
lib/
  app/            routes, bindings, app shell
  core/           config, errors, theme, widgets, utilities
  data/           models, repositories, services (Supabase, native bridge)
  features/       auth, role_selection, family, pairing, dashboard, devices,
                  app_restrictions, screen_time, location, safe_zones,
                  safety_alerts, remote_assistance, audit_logs, settings, child
supabase/
  migrations/     version-controlled SQL including RLS
  functions/      Edge Functions (pairing, devices, policy, telemetry, sessions)
  tests/          local SQL/RLS authorization tests
android/          Kotlin device-management implementation
docs/             contract, backend guide, verification and bug reports
```

## Prerequisites

- Android SDK 36, JDK 17, an Android 7.0+ (API 24+) device or emulator.
- Flutter 3.44.6 pinned via FVM (`.fvmrc`).
- A Supabase project for real use. See [docs/backend.md](docs/backend.md).

On this workstation the FVM launcher is unreliable inside Git Bash, so invoke the
pinned SDK by absolute path. The `set PATH=... && flutter` form silently falls back
to a different Flutter installation and must not be used:

```bash
cmd //c "C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat --version"
cmd //c "C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat doctor -v"
```

## Configuration

The client accepts only the project URL and a **publishable/anon** key:

```bash
cmd //c "C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat run ^
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY"
```

Keep values in a local, gitignored file or CI secret; `.env.example` contains
placeholders only. Service-role keys, TURN secrets and the cron secret belong in
Supabase Edge Function secrets, never in the app, the repository or logs.

If the backend is not configured, the app opens a setup screen and disables
account features. It does not simulate a login or display sample data.

## Backend setup

Apply `supabase/migrations`, deploy the Edge Functions in `supabase/functions`,
and set the server-side secrets as described in [docs/backend.md](docs/backend.md).
The project owner must perform project creation and deployment; this repository
does not contain credentials and the implementation agents never deployed anything.

Local SQL/RLS tests can be run against a plain PostgreSQL 16 instance using the
instructions in `supabase/tests/README.md`. They do not require a live Supabase
project.

## Android device management

A normal Play Store installation is **not** a Device Owner and cannot suspend
packages such as Instagram. Full app blocking requires a fully managed, provisioned
device (factory reset + Device Owner provisioning), documented in
[docs/device-enrollment.md](docs/device-enrollment.md). On any other device the app
must report `Unsupported` for suspension and must not claim an app is blocked.

The Child app also requires the user to grant Usage Access, location and (for
assistance sessions) camera/microphone permissions through the official Android
flows. Permission denial is displayed honestly and never bypassed.

## Remote assistance and privacy

Assistance sessions are parent-requested and child-consented, visible while active,
short-lived and end when either side ends them, when the session expires, or when
the device credential is revoked. There is no hidden recording, covert capture,
keylogging or interception of messages/passwords/OTPs. See
[docs/remote-assistance.md](docs/remote-assistance.md).

## Build and test

```bash
cmd //c "C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat analyze"
cmd //c "C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat test"
cmd //c "C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat build apk --debug"
```

The bare `build apk` above produces a client with no Supabase config. Use the
validated wrappers instead (they pass `--dart-define-from-file` and refuse
service-role keys): see [docs/release-build.md §7](docs/release-build.md).

```bash
bash scripts/build_debug_apk.sh
bash scripts/build_release_apk.sh
```

Install the debug APK on the test device with:

```bash
"%LOCALAPPDATA%/Android/Sdk/platform-tools/adb.exe" install -r \
  build/app/outputs/flutter-apk/app-debug.apk
```

## Documentation

- [docs/api-contract.md](docs/api-contract.md) — schema, Edge Functions, routes,
  ownership and toolchain contract used during implementation.
- [docs/backend.md](docs/backend.md) — owner-side Supabase deployment steps.
- [docs/device-enrollment.md](docs/device-enrollment.md) — Device Owner provisioning
  and recovery.
- [docs/app-restrictions.md](docs/app-restrictions.md) — how blocking works, what
  the acknowledgement means, and Instagram-specific limits.
- [docs/remote-assistance.md](docs/remote-assistance.md) — consent, permissions,
  retention and forbidden capabilities.
- [docs/verification-report.md](docs/verification-report.md) — commands actually run,
  PASS/BLOCKED/UNVERIFIED labels, device-versus-build evidence.
- [docs/bug-report.md](docs/bug-report.md) — defects, severity, reproduction and status.

## Legacy scaffolds

The repository history contains two earlier Flutter scaffolds under `apps/`. They
were removed and the child scaffold was moved to the repository root by the
repository owner's commit `52fb907`, before this build's implementation work began.
This build adds to that single root application and did not delete user files. The
earlier scaffolds remain available in Git history (`c162f8e`).
