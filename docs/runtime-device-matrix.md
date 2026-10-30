# Runtime device matrix — Pixel parent / realme child

Recorded during the real-device run on 2026-10-29. All times are IST (UTC+5:30)
unless marked `Z`. Read-only facts only; no credential, token or key is included.

## 1. Devices and roles

| | Parent | Child |
|---|---|---|
| Role (fixed by master prompt) | Parent | Child |
| Serial | `emulator-5554` | `5HXWRGQ4IFU8WS4T` |
| Type | **Emulator** (Pixel 9a AVD) | **Physical device** |
| Model / product | `sdk_gphone64_x86_64` | `RMX2161` (realme 7) |
| OS | Android 17, API 37 | Android 12, API 31 (ColorOS) |
| Build fingerprint | `google/sdk_gphone64_x86_64/emu64xa:17/CE2A.260420.051.A2/16418371:user/release-keys` | `realme/RMX2161/RMX2161L1:12/SP1A.210812.016/Q.d5ef75_5f7:user/release-keys` |
| ABI | `x86_64` | `arm64-v8a` |
| Time zone | `Asia/Calcutta` (UTC+5:30) | `Asia/Kolkata` (UTC+5:30) |
| Device clock vs host | aligned, <1 s | aligned, <1 s |

Roles were never swapped. Both apps are `com.parentcontrol.parent_control`.

## 2. Accounts and pairing

| | Parent | Child |
|---|---|---|
| Account shown by the app | `ankit@gmail.com` | `ankit1@gmail.com` |
| Family | `demo` | `demo` |
| Role in family | Owner / parent | Child member |
| Device link | — | linked to the parent's family, device row present |

Identity was read from the app UI and from read-only server rows. Passwords,
tokens and keys were never read, printed or stored.

## 3. Build under test

| | Parent | Child |
|---|---|---|
| Package | `com.parentcontrol.parent_control` | same |
| versionName / versionCode | 1.0.0 / 1 | 1.0.0 / 1 |
| targetSdk | 36 | 36 |
| Installed APK sha256 | `cea48c11aba351e3fbb25f3e10b0ec661ac0c3ee06fb281484c3d5970af3eb06` | `7ee501fa0e1c4d8fb93e7e941d415be5e76d360bee6b2adefc0ea9f622569ed7` |
| APK size (installed) | 243,815,303 B | 243,869,900 B |
| Install time | first 16:07:31, last update 16:54:41 | first 2026-10-27 12:55:41, last update 17:22:51 |
| `SUPABASE_URL` compiled in | yes (literal present in `kernel_blob.bin`) | yes (same check) |
| Presence-window fix compiled in | yes (`onlineWindow`, `_refreshDeviceRow` symbols present) | yes |

The two devices carry **different APK bytes** because they were built at
different times from the same source (HEAD `79f4962` plus staged working-tree
changes). The parent's copy was verified post-hoc by pulling the installed APK
and checking the compiled config literal and the presence-fix symbols, so it is
not an unconfigured build. Both are debug/JIT builds (`kernel_blob.bin`, no
`libapp.so`).

An earlier install on the child at 17:18 was an **unconfigured** APK that had
overwritten `build/app/outputs/flutter-apk/app-debug.apk`; it was replaced at
17:22:51 with the preserved `7ee501fa` build. See failure analysis F0.

## 4. Permission and power state (measured 17:40 IST)

| Item | Parent | Child |
|---|---|---|
| `RECORD_AUDIO` | granted (never used by parent) | granted, `flags=USER_SET` |
| `RECORD_AUDIO` app-op | `foreground` | **`allow` — running**, `time=+4m` |
| `FOREGROUND_SERVICE*` | granted (service, location, dataSync, microphone) | granted |
| `POST_NOTIFICATIONS` | **not granted** (app-op `ignore`) | not granted as runtime perm (API 31: notifications on unless blocked) |
| Battery optimisation whitelist | not whitelisted | not whitelisted |
| Battery saver | off (`low_power=0`) | off (`low_power=0`) |
| Standby bucket | 10 (never used) | **5 (ACTIVE)** |
| Screen | Awake | Awake |

Foreground services on the child at the same moment:

* `GuardianService` — `isForeground=true`, `foregroundId=4101`, channel `guardian_status`, `START_STICKY`.
* `AudioAssistanceService` — `isForeground=true`, `foregroundId=4303`, channel `audio_assistance_channel`, `stopIfKilled=true`, mic FGS type.

Both run in the same process, pid 11906, `u0a1312` (uid 11312).

## 5. Sessions exercised

| # | Session id | Accepted | Ended | End reason |
|---|---|---|---|---|
| S1 | `1bd26a84-137d-4e87-84ed-80190bfbea3e` | 11:27:25Z | 12:16:38Z | `expired` by hosted function (F1), `ended_by=NULL` |
| S2 | `af0b39b9-d453-4d4c-8b5b-5a6b4df77f4a` | 12:48:46Z | 13:36:40Z | parent End while child force-stopped, `ended_by` parent, audit row present |
| S3 | `d1a04614-36e0-4b69-8e6e-88282f79d948` | 13:46:31Z | 13:53:02Z | parent End while child live, `ended_by` parent |
| S4 | `1a728cff-4d9f-40f5-932d-0a77dc89de9e` | never | 14:12:57Z | parent canceled the pending request |

At the end of the run no session was left open. The orphan
`e84ba35e-d8c6-4573-a5a5-c02fa849a9f9` was already `expired` (11:21:35Z) and was
not modified or deleted.

**Note on the deadline.** The hosted `remote-session` Edge Function is still the
pre-fix build; it stamps `expires_at = accepted_at + 30 min` on accept even
though the UI promises "Until you end the session". S1 ran 19 minutes past that
deadline and was flipped to `expired` at the next client call (12:16:38.393Z),
tearing media down 144 ms later. S2 was still `active` at 13:24Z despite
`expires_at = 13:18:46Z` because that particular reconnect reused cached ICE
config and made no expiring call; the parent ended it normally at 13:36Z. This
path-dependence is failure analysis F1.

## 6. Evidence location

All runtime artifacts are under `docs/evidence/stage8/`:

* `media-verified-11-55Z.txt` — first packet-level proof of one-way audio.
* `f1-expiry-12-16Z.txt` — server flip to `expired` and the 144 ms media teardown.
* `e1-15min.txt` — 15-minute endurance sample (ended at 8m14s by F1).
* `rmx-08-settings.txt` — child diagnostics while the session looked "Offline".
* `rmx-*.png`, `emu-*.png` — UI states referenced by the test report.
* `e2-*` … `j4-*.png` — per-test screenshots for sessions S2/S3.
