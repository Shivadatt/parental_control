# 09 — Platform feasibility matrix

For each AirDroid capability: is it feasible on Android with the current architecture, and what platform prerequisite does it need? Justifications cite code or Android constraints. This is not a promise of capability — Google Play policy can restrict several of these.

Legend for feasibility: **Now** = feasible with current components; **Native work** = feasible but new native code required; **Special access** = needs a user-granted special permission; **Device Owner** = requires managed-device provisioning; **Restricted** = Play-policy/permission restricted; **Not reliable** = cannot be done robustly by a third-party app; **iOS-only** = not an Android requirement.

| # | Capability | Feasibility | Prerequisite | Justification in this repo |
|---|---|---|---|---|
| 1 | Parent/child auth, family, pairing | **Now** | — | implemented and runtime-verified (inventory FA rows) |
| 2 | Device registration, identity, revocation | **Now** | — | `SecureStore`, `DeviceHttpClient`, `devices` table |
| 3 | Online/offline presence | **Now** (with fix) | reliable heartbeat | presence logic fixed; F2 scheduler stall remains |
| 4 | Today's Event / usage feed | **Now** | presentation work | `usage_daily` is collected; no feed/trend UI |
| 5 | Remote camera (front) | **Now** | camera permission + consent | `flutter_webrtc` getUserMedia; never run on device |
| 6 | Remote camera (rear / torch / switch) | **Native work** | camera plumbing + camera FGS for background | front camera hard-coded; no CameraX code |
| 7 | Camera in background/locked | **Special access** | `FOREGROUND_SERVICE_CAMERA` + camera FGS | no camera FGS declared |
| 8 | Screen mirroring | **Special access** | MediaProjection consent + `FOREGROUND_SERVICE_MEDIA_PROJECTION` | absent at every layer |
| 9 | One-way audio (foreground) | **Now** | mic permission + consent | fully verified |
| 10 | One-way audio (background/locked/Recents) | **Now** | mic FGS + notification | verified 5 min background, 2 min lock, Recents swipe |
| 11 | One-way audio across force stop / reboot | **Not reliable** | user reopen | OS kills FGS; `START_NOT_STICKY` by design |
| 12 | One-way audio over carrier NAT | **Now** (needs service) | TURN relay | no relay configured; `relay 0` |
| 13 | Audio recording/storage | **Now** | storage bucket + consent UI | no recording feature and no buckets |
| 14 | Instant block (normal install) | **Restricted / Native work** | Accessibility or overlay | not implemented; Play-sensitive |
| 15 | Instant block (managed device) | **Device Owner** | factory reset / adb provisioning | `setPackagesSuspended` only; never executed |
| 16 | Downtime (all-app pause) | **Device Owner** | DO or Accessibility | bedtime stored, not enforced |
| 17 | Per-app schedules | **Device Owner** | DO | evaluated but DO-gated |
| 18 | Daily screen-time limit | **Device Owner / Special access** | DO or UsageStats + overlay | parsed but never read |
| 19 | Installed-app inventory | **Now** | `QUERY_ALL_PACKAGES` (Play declaration) | works |
| 20 | Notifications monitoring | **Special access** | NotificationListenerService grant | no listener; Play-sensitive but permitted with disclosure |
| 21 | Notification mute/block actions | **Special access** | listener + policy | not implemented |
| 22 | Social content detection | **Not reliable** | Accessibility + screen capture; no message API | no content source exists |
| 23 | Inappropriate image detection | **Native work** | MediaStore observer + on-device ML | absent; privacy review required |
| 24 | Calls & SMS monitoring | **Restricted** | default SMS/dialer role; READ_SMS/READ_CALL_LOG | absent; not possible for silent interception |
| 25 | Website restrictions | **Special access** | VpnService consent (or Accessibility) | absent; no VPN code |
| 26 | Browsing history | **Native work** | browser integration or VPN flow logging | absent |
| 27 | Web time limits | **iOS-only** (AirDroid) | — | no Android equivalent implemented |
| 28 | Location (foreground/child app open) | **Now** | fine location | works |
| 29 | Location in background | **Special access** | `ACCESS_BACKGROUND_LOCATION` granted via settings | declared but never requested |
| 30 | Route history | **Now** | offline queue + trip model | uploads drop all but newest offline fix |
| 31 | Geofence entry/exit | **Now** (server) / **Native work** (local) | location uploads; optional GeofencingClient | server evaluation verified; no local geofencing |
| 32 | Geofence during location-sharing off | **Not reliable** | child must share | parent cannot enable remotely |
| 33 | Alerts/requests realtime | **Now** (in-app) / **Native work** (push) | FCM or polling FGS | no push transport |
| 34 | Remote commands offline | **Native work** | WorkManager + durable queue | no WorkManager; 900 s TTL can drop commands |
| 35 | Screen-time reports / trends | **Now** | presentation work | data exists |
| 36 | SOS / chat / rewards / billing | **Not applicable to platform** | product decision | absent |

## Platform constraints that must be stated to users

1. **Force stop and OEM cleaners end capture and sync** — Android behavior, not a bug. The app correctly stops rather than resurrecting a mic.
2. **Android 15+ refuses `dataSync` FGS start at boot** — background recovery requires opening the app until WorkManager is added.
3. **Blocking requires Device Owner** on this architecture. Without it, the honest answer is "not supported on this phone", not a green "enforced".
4. **No background camera without a camera FGS**; no screen capture without per-session MediaProjection consent.
5. **Calls/SMS control requires being the default handler** — a parental-control app cannot silently read them.
6. **Doze/OEM freezers** (ColorOS observed) can delay polling; only FGS + user whitelisting mitigates.
7. **No TURN** means audio may fail on carrier-grade NAT; this is a deployment gap, not a device limitation.

## Feasibility verdict

Feasible now, with the current architecture: family/device management, usage collection, foreground audio, location, server-side geofencing, alerts in-app.

Feasible with native work: camera completion, mirroring, notifications, web filtering, push, durable scheduling, offline queues, image detection.

Feasible only with special access/Device Owner: blocking, downtime, limits, background camera, website filtering (VPN consent).

Not reliably feasible (and should be descoped or explicitly framed): silent call/SMS interception, social message-content detection, guaranteed survival after force stop or reboot.