# Toolchain / test verification — 2026-10-28 (qa-20261028b)

Read-only run. No source files edited, no `adb`, no Supabase/hosted calls, no integration tests.
All commands run from `D:\parentcontrol_app` in Git Bash on Windows. Logs: this directory.

## Tool versions

| Tool | Version |
|---|---|
| `fvm` | 4.3.2 |
| Flutter | 3.44.6 (channel `[user-branch]`, revision `ee80f08bbf`, 2026-07-08) |
| Dart | 3.12.2 (DevTools 2.57.0) |
| Deno | 2.9.4 (V8 15.0.245.2, TypeScript 6.0.3) |

Every `fvm` invocation prints `Can't load Kernel binary: Invalid kernel binary format version
(expected 125, found 130).` on stderr. It comes from the FVM wrapper and did not affect any exit
code (all Flutter commands exited 0). `flutter --version` log: `flutter-version.log`.

## 1. `cmd //c fvm flutter analyze`

- Exit: **0** — `No issues found! (ran in 56.5s)`
- Zero analyzer issues (0 errors / 0 warnings / 0 infos / 0 lints).
- Wall time: **67 s**.
- Log: `analyze.log`.

## 2. `cmd //c fvm flutter test`

- Exit: **0** — `00:17 +150: All tests passed!`
- Result: **150 passed, 0 failed, 0 skipped**; no `[E]` / "Some tests failed" lines.
- Wall time: **31 s**.
- Log: `test.log` (169 lines).
- Integration tests intentionally not run (require devices).

## 3. `deno check` — nine Edge Function entrypoints

Exact invocation from `docs/backend.md` §"Local checks":

```
deno check supabase/functions/auth-bootstrap/index.ts \
  supabase/functions/pairing/index.ts \
  supabase/functions/device-register/index.ts \
  supabase/functions/device-command/index.ts \
  supabase/functions/device-policy/index.ts \
  supabase/functions/device-telemetry/index.ts \
  supabase/functions/family-admin/index.ts \
  supabase/functions/remote-session/index.ts \
  supabase/functions/cron/index.ts
```

- Exit: **0**, 9/9 files `Check …` with no diagnostics, **5 s**.
- Log: `deno-check.log`.

## 4. `deno test supabase/functions/_shared/`

- Exit: **0** — `ok | 36 passed | 0 failed (735ms)`, **1 s** wall.
- Suites: 3 tests (identifier/revocation dates) + 8 policy + 8 turn + 17 validation.
- Log: `deno-test.log`.

## 5. APK artefacts on host

| Artefact | Bytes | SHA-256 | versionName / versionCode |
|---|---:|---|---|
| `app-release.apk` (universal) | 110,313,302 | `d83aa3807e2728b6c031f62d629f32a7082cfca2dc341cfdd18308a9a6e6572c` | 1.0.0 / **4002** |
| `app-arm64-v8a-release.apk` | 39,910,018 | `e5b7355c60b8165d34f53fc0e1785d449748200ffb28e60000a08ddf9684a4b8` | 1.0.0 / 2001 |
| `app-armeabi-v7a-release.apk` | 30,340,342 | `4b03dc580384bebb3da18d019096682ebb23ec92bd11b4a08a09bb04f0d15f1d` | 1.0.0 / 1001 |
| `app-x86_64-release.apk` | 46,250,618 | `537f2152db8cf50e61f43d005eec2db3d0f69165396ebab1d73adbdca7de3611` | 1.0.0 / 4001 |
| `app-debug.apk` | 242,217,994 | `8c0c7d12ae081ba460a9efaf010d414e4bc1fc65b0b3e8cd1d5081d297a22b52` | 1.0.0 / 1 |

Version provenance: `aapt2 dump badging`, `build/app/outputs/apk/release/output-metadata.json`,
merged release manifest, `android/local.properties` (`flutter.versionCode=4002`).
Details: `apk-sha256.txt`.

**Version mismatch note:** `pubspec.yaml` declares `version: 1.0.0+1`, so a default build would be
versionCode 1 (as the debug APK is). The universal release APK carries **versionCode 4002** — the
last release build used a `--build-number 4002` style override (recorded in
`docs/verification-report.md`), which also left `flutter.versionCode=4002` in
`android/local.properties`. The split-per-ABI APKs predate that and use Flutter's
`base*1000 + ABI` scheme (1001/2001/4001). The universal release hash matches the one recorded in
the verification report (`d83aa380…6572c`); the split-arm64 hash differs from the report's earlier
`ec15b5e2…634e` because those files were rebuilt on 2026-10-27 17:17.

## Status

All four suites passed; no failures and no commands skipped.
