# 01 — Repository and Device Baseline

Phase: 6 — Fresh APK Build & Comprehensive Manual Parent–Child Testing  
Date: 2026-11-21  
Workspace: `D:\parentcontrol_app`

## Repository preflight

| Item | Result |
|---|---|
| Git root | `D:/parentcontrol_app` |
| Branch | `main` |
| HEAD | `bbd3c213721fd6ebd3de2871822ddd7fbda4fc1f` |
| Tracked source diff | None (`lib`, `android`, `supabase`, `test`, `pubspec.yaml` unchanged) |
| New commits | None |
| Build configuration | Single application ID `com.parentcontrol.parent_control` |
| Architecture | One APK, role selected in-app (Parent or Child) |
| Pinned Flutter | 3.44.6 via `.fvmrc`; executed through `.fvm/flutter_sdk/bin/flutter` |
| Standalone `fvm` on PATH | Not available; the FVM-pinned SDK link was used instead |

Initial untracked evidence packages were present and were not modified:
`device_heartbeat_root_cause_investigation`, `phase_3_complete_functional_testing`,
`phase_4_device_recredentialing_design`, `phase_5_recredentialing_implementation_plan`,
`phase_5_1_owner_decision_reconciliation`, `phase_5_2_owner_approval_documentation`,
`two_device_end_to_end_testing`.

### Git index observation

At the start of Phase 6 these packages were untracked (`??`). During the session an
external process placed 83 documentation files into the Git index (`A `). No Git
add/commit/reset command was executed by this testing run. HEAD did not change and
no application source or backend file was staged or modified. The index change is
reported as an observed environment anomaly, not as a testing action.

## Devices

| Item | Child | Parent |
|---|---|---|
| ADB serial | `5HXWRGQ4IFU8WS4T` | `emulator-5554` |
| Model | Realme RMX2161 (physical) | AVD `Pixel_9a` |
| Reported product model | RMX2161 | `sdk_gphone64_x86_64` |
| Type | Physical | Emulator |
| Android release | 12 (reported by app device detail) | 17 |
| API level | 31 (Android 12) | 37 |
| Package | `com.parentcontrol.parent_control` | `com.parentcontrol.parent_control` |
| Pre-test version | 1.0.0 (code 1) | 1.0.0 (code 1) |
| Pre-test last update | 2026-11-18 09:46 | 2026-11-18 13:55 |

The emulator reports the AVD name `Pixel_9a`; its Android product string is the
generic emulator image, not a physical Pixel 9a. It was treated as the designated
Parent emulator.

## Account/session baseline

Both devices were already signed in when Phase 6 began:

- Parent: `ankit@gmail.com`, role Parent, family `demo`.
- Child: `ankit1@gmail.com`, linked Child account, device `realme RMX2161`.

No password was supplied in the Phase 6 instruction text. Therefore no sign-out,
re-login, password change, account creation, or credential entry was performed.
Authentication was verified only through existing persisted sessions.

## Initial application state

Parent dashboard showed two rows for the same child/device:

1. `realme RMX2161` — **Revoked** — last seen 197 h ago.
2. `realme RMX2161` — **Offline** — last seen 190 h ago, policy v4.

Child settings showed:

- Background protection service running.
- `Usage upload failed: Device credentials are not valid.`
- Parent-visible device stayed Offline.

This matched the previously documented credential/online-status defect before any
new APK was installed.

## Safety boundaries observed

No source, migration, RLS, RPC, Edge deployment, account, family membership, device
pairing, unlink, revoke, recovery, or credential-rotation action was performed.
No destructive UI action was confirmed.
