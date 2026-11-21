# 12 — Final Investigation Verdict

**Date:** 2026-11-21  
**Repository:** `D:\parentcontrol_app` — `main` — HEAD `bbd3c21`  
**Installed build examined:** `1.0.0` debug, last updated 2026-11-18  
**Mode:** strictly read-only, no remediation performed  
**Evidence labels:** PASS / FAIL / BLOCKED / NOT TESTED / NOT IMPLEMENTED / REPORTED

---

## 1. Final classification

# A. CONFIRMED DEVICE CREDENTIAL MISMATCH

**Confidence: HIGH (~0.9).**

The child’s current installation (first installed 2026-11-17) generated a new device secret and installation ID. The server still holds the active device row and `secret_hash` from the earlier installation (last successful heartbeat 2026-11-13). On normal shell startup, the child reuses the old server device ID with the new local secret, and there is no re-registration path. `device-telemetry` therefore rejects the heartbeat before updating `devices.last_seen_at`.

---

## 2. Exact failure point

```text
SecureStore: new installation ID + new secret (fresh install)
        │
fetchMyDevice(): old active device row (old ID + old secret_hash)
        │
_ensureIdentityAndSync():
  deviceId = old server UUID
  deviceSecret = new local secret
        │
GuardianService heartbeat every 5 min (retry every 60 s on failure)
        │
requireDevice():
  sha256(new secret) != old secret_hash
  → 401 invalid_device_credentials
        │
devices.last_seen_at unchanged
        │
parent computes age ~8 days → "Offline"
```

The failure is **credential verification**, before the database update. It is not the scheduler, the parent threshold, the parent query, or the UI.

---

## 3. Why this is the cause

- Child current install date is **after** the last successful heartbeat.
- A fresh install necessarily deletes the encrypted credential store and generates a new secret.
- `android:allowBackup="false"` prevents Android backup from restoring the old secret.
- The child shell skips registration when any active device row exists.
- `registerDevice()` explicitly returns “already registered” in that case.
- `device-register` cannot re-credential an active device with a new installation ID.
- The backend requires an exact hash match and performs no automatic migration.
- The heartbeat failure is retried every 60 seconds, so it is persistent, not transient.
- The parent re-queries the same stale `last_seen_at` on every refresh.

---

## 4. What was ruled out

| Hypothesis | Ruling |
|---|---|
| B. Another authentication rejection | Not supported: active row is not revoked; IDs/secret formats are valid; no other rejection mechanism fits the fresh-install state |
| C. Heartbeat not scheduled | Ruled out: service alive, config gates passed, tick loop and watchdog running |
| D. Backend accepts but DB update fails | Ruled out: update is by primary key with error checking; a failure would be a 500, not a silent old value |
| E. Parent query/cache stale | Ruled out: parent polls every 60 s and shows the same old DB value across screens; PostgREST does not cache for eight days |
| F. Multiple interacting causes | The P2s are independent UI/query defects; the heartbeat failure has one coherent cause |
| G. Insufficient evidence | Rejected: install timing + credential code + auth code form a complete mechanism; only the literal 401 body is unobserved |

---

## 5. What remains unobserved

1. The exact `401` response body and the child’s stored `guardian_lastError` text.
2. The exact installed APK source revision (no commit hash in package metadata).
3. The server-side log line for the rejected heartbeat (not queried).

These do not change the mechanism. They should be confirmed during the remediation phase through a safe diagnostic (status code + safe error text, never secrets).

---

## 6. Related findings

| ID | Finding | Priority |
|---|---|---|
| E2E-002 | Revoked devices are not filtered from the parent’s current-device list (`fetchDevices` has no status filter; both rows render) | P2 |
| E2E-003 | Devices list shows `devices.policy_version` (applied v2); detail/dashboard show latest `device_policies.version` (saved v4 pending) | P2 |
| E2E-004 | Child location warning says permission missing although Android reports fine/background location granted; stale capability snapshot or build/source mismatch, not established | P2 |

These are independent of the heartbeat root cause and are not fixed in this phase.

---

## 7. Security and preservation

**PASS** — no code, build, install, app data, account, credential, pairing, database, RLS, Edge Function or Supabase configuration was changed. No secret was read or exposed. The `demo` parent/child relationship remains intact.

---

## 8. Required next step

No remediation is authorized by this report.

The recommended next step is a **separately authorized** phase to:

1. Confirm the 401 and safe `guardian_lastError` non-destructively.
2. Implement a child-session-authorized re-credentialing path for an existing active device, with audit and rate limiting.
3. Add regression tests for fresh install + existing device row + heartbeat success.
4. Build, install and re-run the two-device E2E test, verifying a fresh parent `last_seen` within one heartbeat window.
5. Address E2E-002/003/004 as separate UI/query fixes.

An alternative is the existing owner-approved `recover_device` + re-pair flow, which restores a working credential but destroys the current relationship.

---

## 9. Final verdict statement

**The child is not offline because it is dead, disconnected or unscheduled. It is offline because the running app is presenting a credential the server no longer recognizes, and the app has no path to re-register that credential without re-pairing. The exact failure point is the mismatch between the fresh local secret and the stale server `secret_hash`, before `last_seen_at` is updated.**
