# 05 — Child Manual Testing

Device: Realme RMX2161 (physical, `5HXWRGQ4IFU8WS4T`), Android 12 / API 31  
Role: Child (`ankit1@gmail.com`), family `demo`  
Build: fresh arm64 debug APK, SHA-256 `cc621bf6eefc6ee6d8093da11fc6727abe62f3114ba38ef19886ed9c0fc5ff5a`

## Installation and launch

The arm64 APK was installed in place. Existing account, family and device identity
were preserved. On first launch the app displayed "Checking this phone…" and then
returned to the child home, still signed in.

| Test | Expected | Actual | Status |
|---|---|---|---|
| C01 | Home loads | `demo` / child home loaded | PASS |
| C02 | Identity and link state | `ankit1@gmail.com`, Linked, Registered, RMX2161 | PASS |
| C17 | Session survives install/relaunch | Still signed in | PASS |

## Status and credential behavior

| Test | Expected | Actual | Status |
|---|---|---|---|
| C03 | Online when service/network active | Home shows **Offline** | FAIL |
| C04 | Refresh recovers status | Refresh leaves Offline and credential error | FAIL |
| C12 | Heartbeat authenticated | `Usage upload failed: Device credentials are not valid.` | FAIL |
| C13 | Usage uploads | No recent usage reaches parent | FAIL |
| C14 | Location service running when sharing on | Home earlier reported location/notification permission missing and service not running | FAIL |
| C11 | Background protection | Service running with visible notification | PASS |
| C16 | Android control capability | Device admin only; app blocking unavailable | PASS |

The credential failure persisted after a fresh build was installed. This confirms
that reinstalling the client alone does not repair the server-side credential
mismatch identified in Phases 4–5.

## Rules

| Test | Expected | Actual | Status |
|---|---|---|---|
| C05 | Rules screen opens | "Rules from your guardian" | PASS |
| C06 | Policy version | Version 4, received Nov 17, 2026 11:21 AM | PASS |
| C07 | Honest enforcement language | "Not enforceable on this phone" / Device Owner warning | PASS |

Rules displayed: app blocking On, selected apps only, no named blocked apps,
bedtime 10:00 PM–7:00 AM, waiting for device.

## Requests

| Test | Expected | Actual | Status |
|---|---|---|---|
| C08 | Empty state when none pending | "No pending requests" + refresh timestamp | PASS |
| C18 | Accept a request | Not executed; no pending request | NOT TESTED |

## Settings and permissions

| Test | Expected | Actual | Status |
|---|---|---|---|
| C09 | Account/settings display | Name, email, family, device correct | PASS |
| C10 | Permission state matches Android | Notifications shown **Granted** while `POST_NOTIFICATIONS` is not granted in `dumpsys` | FAIL |
| C15 | Camera/microphone self-test | Not exercised | NOT TESTED |
| C19 | Sign out / unlink | Not executed; destructive | NOT TESTED |

The settings screen reports Usage access, precise/background location, camera,
microphone, notifications and device admin as Granted. Android grants fine and
background location plus camera/microphone, but `POST_NOTIFICATIONS` does not appear
in the granted runtime-permission list. This is a user-visible false-positive.

## Blocked final lifecycle test

An explicit force-stop/relaunch was attempted after the manual screen review. The
physical device dropped from `device` to `unauthorized`; the USB-debugging
authorization dialog could not be accepted from ADB. C18 is therefore BLOCKED, not
a product failure. The earlier install/relaunch already demonstrated session
persistence (C17).

Evidence: `screenshots/child/`, `logs/child_*.xml`.
