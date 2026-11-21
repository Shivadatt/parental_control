# 09 — Previous Defect Regression

## E2E-001 — Child Online/Offline mismatch

| Check | Result |
|---|---|
| Fresh build installed on child | Yes (arm64, `cc621b…`) |
| Background service running | Yes, visible notification |
| Heartbeat authentication | Failed: “Device credentials are not valid” |
| Parent online status | Offline before and after refresh |
| Last-seen update | No; stuck at Nov 13, 2026 5:23 PM |
| Old credential mismatch removed | **No** |

Status: **STILL FAILING**. Fresh installation preserves the old server device row
and its old `secret_hash`; the new client identity cannot authenticate. This is the
same root cause documented in Phases 4–5. A client reinstall alone is not a fix.

## E2E-002 — Revoked device visibility

| Check | Result |
|---|---|
| Parent dashboard/list | Revoked row and Offline row both visible for RMX2161 |
| Revoked row data | Nov 13 10:18 AM, “No device policy applied yet” |
| Offline row data | Nov 13 5:23 PM, “Policy v4 · Waiting for device” |
| Safe read-only inspection only | Yes; no revoke/unlink performed |

Status: **STILL FAILING**. The revoked entity remains presented as a duplicate
device and is not visually reconciled with the active row.

## E2E-003 — Policy version mismatch

| Surface | Version |
|---|---|
| Parent dashboard | 4 |
| Parent device detail | 4 |
| Parent Devices tab | 2 |
| Child Rules | 4 (received Nov 17) |

Status: **STILL FAILING** on the Devices tab summary. Detail and child agree on v4,
so the list projection is stale or using a different field.

## E2E-004 — Permission mismatch

| Permission | Android | Parent detail | Child settings |
|---|---|---|---|
| Fine location | Granted | Granted | Granted |
| Background location | Granted | Granted | Granted |
| Camera | Granted | Granted | Granted |
| Microphone | Granted | Granted | Granted |
| Notifications | **Not granted** | Granted | Granted |

Status: **PARTIALLY CONFIRMED / STILL FAILING for notifications**. The earlier
location-service warning was not reproduced as a location-grant mismatch; the
notification grant is falsely reported as present.

## Other previously blocked features

The following prior areas could not be regression-tested because they require a
healthy heartbeat, Device Owner, or a permitted live state change:

- App restriction propagation and enforcement — BLOCKED.
- Bedtime/schedule application — BLOCKED.
- Usage and location synchronization — FAIL (no authenticated upload).
- Recovery/re-credentialing — not authorized in Phase 6.
- Pairing, unlink, revoke, account deletion, retention purge — not executed.

No previously failed feature was marked PASS without direct evidence.
