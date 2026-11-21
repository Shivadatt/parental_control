# 02 — Installed Build and Source Revision

**Date:** 2026-11-21  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. What is installed

| Item | Child | Parent |
|---|---|---|
| APK version | `1.0.0` (`versionCode 1`) | `1.0.0` (`versionCode 1`) |
| Build type | Debuggable | Debuggable |
| First install | 2026-11-17 12:44:28 | 2026-11-13 15:05:52 |
| Last update | 2026-11-18 09:46:33 | 2026-11-18 13:55:28 |

The observed runtime behavior therefore belongs to a **debug build last updated on 2026-11-18**, not to HEAD `bbd3c21` (2026-11-20).

---

## 2. Can the installed APK be tied to a commit?

**No.** The repository does not embed a git commit hash in the APK, and the available package metadata exposes only version name/code and install timestamps. There is no build-provenance file that binds the installed APK bytes to `bbd3c21` or any other commit.

**Do not claim:** “the installed APK is HEAD.”  
**Do claim:** the installed APK was built after the source files below were last modified, so the current source is a plausible but unproven description of its behavior.

---

## 3. Relevant source-file history

| File | Last source commit | Date | Before installed build? |
|---|---|---|---|
| `SecureStore.kt` | `5a39747` | 2026-11-06 | Yes |
| `GuardianService.kt` | `2a77943` | 2026-11-16 | Yes |
| `child_shell_controller.dart` | `31e366f` | 2026-10-30 | Yes |
| `child_enrollment_controller.dart` | `2771283` | 2026-10-28 | Yes |
| `supabase_device_repository.dart` | `2771283` | 2026-10-28 | Yes |
| `NativePermissions.kt` | `a580d36` | 2026-10-26 | Yes |
| `device-register/index.ts` | `a580d36` | 2026-10-26 | Yes |
| `_shared/auth.ts` | `0badc13` | 2026-11-18 | Same day as build; ordering unknown |
| `devices_controller.dart` | `953b337` | 2026-11-02 | Yes |
| `dashboard_controller.dart` | `953b337` | 2026-11-02 | Yes |
| `device_presentation.dart` | `2a77943` | 2026-11-16 | Yes |

**Interpretation:**

- The credential and heartbeat logic in HEAD predates the installed build, so it is very likely present in the APK.
- `_shared/auth.ts` changed on the same day as the build; whether the installed Edge Function bundle and/or APK included that change cannot be determined from local evidence.
- A source-level defect identified below is therefore a strong candidate for the runtime behavior, but it is **not cryptographically proven** to be the exact installed revision.

---

## 4. Build/install status this phase

| Operation | Result |
|---|---|
| Rebuild APK | Not performed (prohibited by phase) |
| Install/update APK | Not performed (prohibited by phase) |
| Clear app data | Not performed |
| Deploy Edge Function | Not performed |
| Change database | Not performed |

---

## 5. Source attribution verdict

**PASS** — installed version and timestamps recorded.  
**BLOCKED** — exact source revision cannot be established from the available metadata.  
**Conclusion:** findings are valid for the **installed 2026-11-18 `1.0.0` debug build**, with the current source used as the traceable implementation reference.
