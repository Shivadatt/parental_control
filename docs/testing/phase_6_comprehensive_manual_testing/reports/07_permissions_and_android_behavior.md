# 07 — Permissions and Android Behavior

## Child device (Realme RMX2161, Android 12 / API 31)

Observed with `dumpsys package` and `appops`; no permission was granted or revoked
by this testing run.

| Permission/capability | Android state | App display | Verdict |
|---|---|---|---|
| Fine location | `granted=true` | Granted | Match |
| Coarse location | `granted=true` | Granted (precise) | Match |
| Background location | `granted=true` | Granted | Match |
| Camera | `granted=true` | Granted | Match |
| Microphone | `granted=true` | Granted | Match |
| Usage access | `GET_USAGE_STATS: allow` | Granted | Match |
| Notifications | `POST_NOTIFICATIONS` not in granted runtime list; app-op default allow | **Granted** | **Mismatch** |
| Device admin | Active | Granted | Match |
| Device Owner | Not Device Owner | "Device admin only" | Match |

### Notification mismatch

The app and the parent device-detail screen both report notifications as granted,
but Android does not list `POST_NOTIFICATIONS` among the granted runtime
permissions. This matters because the child screen itself says notifications are
required for the visible background and location services.

Impact: a user can believe background/location notifications are permitted when the
OS grant is absent. This is consistent with the child's earlier warning that the
location service was not running, although fine/background location themselves are
granted.

No permission dialog was triggered during Phase 6. No special access was granted.

## Parent emulator

The parent app requested no new runtime permission during the tested flows. Local
notification and location-reminder switches are local preferences and were not
treated as OS grants.

## Android enforcement behavior

- Child device is **not** a Device Owner. App suspension/blocking is not available.
- The child UI correctly states that a database flag does not block apps and that
  enforcement cannot be claimed on this phone.
- Parent App restrictions correctly says suspension is unsupported without Device
  Owner.
- No attempt was made to provision Device Owner or change managed-device state.

## App identity and compatibility

| Item | Parent | Child |
|---|---|---|
| Target SDK | 36 | 36 |
| Min SDK | 24 | 24 |
| Installed build | x86_64 debug | arm64 debug |
| Launch after correct ABI | Success | Success |
| Crash at launch | Only with wrong arm64 artifact on x86_64 emulator | None observed |

No OS-level crash, ANR, or permission-loop was observed after the correct ABI was
installed.
