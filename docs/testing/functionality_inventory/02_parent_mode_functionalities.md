# 02 — Parent-Mode Functionalities

Companion to `01_complete_functionality_inventory.md`. Role counts follow the method in `06_functionality_count_summary.md`.

## Headline counts

| Measure | Count |
|---|---:|
| Parent-mode unique functionalities | **59** |
| Parent-only | 35 |
| Shared with Child mode | 14 |
| Parent–Child interconnected | 10 |
| Fully implemented | 54 |
| Partially implemented | 3 |
| UI only | 2 |
| Backend only (not in the 59 accessible count) | 2 |

The parent-mode total is 35 parent-only + 14 shared + 10 interconnected. The two backend-only parent-role capabilities (`FAM14`, `AUD04`) are excluded because they have no application entry point.

## Parent-only functionality (35)

| ID | Functionality | Status | Operational note |
|---|---|---|---|
| FAM01 | Link child by QR scan | IMPLEMENTED | Camera scanner accepts only `parentcontrol://pair` payloads. |
| FAM02 | Link child by Child ID/linking code | IMPLEMENTED | Dashes/spaces normalised; legacy short code supported. |
| FAM03 | Send pairing request | IMPLEMENTED | Child must approve; knowing the ID alone grants nothing. |
| FAM04 | Pairing request list and cancel | IMPLEMENTED | Pending requests are listed and cancellable. |
| FAM08 | Create family | IMPLEMENTED | One-time family setup after first parent sign-in. |
| FAM09 | Family details, members, roles | IMPLEMENTED | Parent/Child roles and owner marker are displayed. |
| FAM10 | Unlink child account/device | IMPLEMENTED | Destructive; confirmation required. |
| FAM12 | Revoke device | IMPLEMENTED | Destructive; revoked row remains visible as history. |
| FAM13 | Device recovery (lost/reinstalled phone) | IMPLEMENTED | Starts recovery request; does not restore credentials locally. |
| MON01 | Family/dashboard overview | IMPLEMENTED | Aggregates devices, policies, and family state. |
| MON02 | Device list with status cards | IMPLEMENTED | Shows policy version, online state, and last seen. |
| MON03 | Device detail: identity, battery, enforcement, last seen | IMPLEMENTED | Read-only detail plus actions. |
| MON06 | Recent command history | IMPLEMENTED | Command status from `device_commands`. |
| USE01 | Daily usage history | IMPLEMENTED | Reads uploaded `usage_daily` rows. |
| USE02 | App usage breakdown | IMPLEMENTED | Per-package usage for the selected day. |
| USE03 | Usage Access status and guidance | IMPLEMENTED | Opens Android Usage Access settings. |
| USE05 | Daily screen-time limit configuration/save | IMPLEMENTED | Saves minutes into device policy. |
| USE06 | Bedtime configuration and state | PARTIAL | Configuration and `bedtime_active` are reported; bedtime does not itself suspend apps. |
| USE07 | Remaining-time/limit-reached display | IMPLEMENTED | Computed from policy and latest usage. |
| APP01 | Block selected apps | IMPLEMENTED | Per-package block rules. |
| APP02 | Block all except allowed list | IMPLEMENTED | Global mode plus allow-list. |
| APP03 | Allowed-app list management | IMPLEMENTED | Explicit package allow-list. |
| APP04 | Per-app schedule windows | IMPLEMENTED | Windows are evaluated by native `PolicyEvaluator`. |
| APP06 | Request policy sync command | IMPLEMENTED | Queues a sync command for the child. |
| LOC01 | Latest child location | IMPLEMENTED | Latest accepted `location_events` row. |
| LOC02 | 24-hour/7-day location history | IMPLEMENTED | Bounded history query. |
| LOC05 | Safe-zone create/edit/delete/active | IMPLEMENTED | Delete is audited through an atomic RPC. |
| LOC10 | Alert list, severity filter, acknowledge | IMPLEMENTED | Realtime subscription plus acknowledge action. |
| REM01 | Parent requests audio/video session | IMPLEMENTED | Creates a remote-session request. |
| REM04 | Session history/status detail | IMPLEMENTED | Historical and live session state. |
| AUD01 | Paginated audit log | IMPLEMENTED | Family-scoped audit rows. |
| AUD02 | Retention settings view/update | IMPLEMENTED | Updates family retention policy. |
| AUD03 | Purge old data | IMPLEMENTED | Destructive; confirmation required. |
| SET01 | Local notification preference | UI ONLY | Switch persists locally; no local-notification scheduler consumes it. |
| SET02 | Location-sharing reminder preference | UI ONLY | Switch persists locally; no reminder consumer exists. |

## Shared functionality available in Parent mode (14)

| ID | Functionality | Status |
|---|---|---|
| A01 | Email/password sign-in | IMPLEMENTED |
| A02 | Account registration | IMPLEMENTED |
| A03 | Email verification, resend, refresh | IMPLEMENTED |
| A04 | Persisted session restore | IMPLEMENTED |
| A05 | Sign out | IMPLEMENTED |
| A06 | Role selection and initial role assignment | IMPLEMENTED |
| A07 | Account/profile display | IMPLEMENTED |
| A08 | Account data export | IMPLEMENTED |
| A09 | Account deletion with confirmation | IMPLEMENTED |
| A10 | Backend configuration/error screen | IMPLEMENTED |
| SET03 | App version display | IMPLEMENTED |
| SET04 | Runtime permission requests | IMPLEMENTED |
| SYS01 | Offline detection and cached-state handling | IMPLEMENTED |
| SYS02 | Manual and periodic refresh | IMPLEMENTED |

## Parent–Child interconnected functionality (10)

| ID | Functionality | Status | Dependency |
|---|---|---|---|
| MON04 | Heartbeat-derived online/offline and last-seen status | PARTIAL | Child heartbeat must authenticate with `secret_hash`; live E2E-001 failed. |
| MON05 | Child permission summary | PARTIAL | Child telemetry reports permissions; live notification value was a false positive. |
| MON07 | Installed-app snapshot | IMPLEMENTED | Child uploads installed packages; parent selects from them. |
| APP05 | Enforcement acknowledgement and applied counts | IMPLEMENTED | Child command result and policy evidence are correlated. |
| LOC06 | Geofence enter/exit alerts | IMPLEMENTED | Child location upload evaluates zones server-side. |
| LOC07 | Low-battery alerts | IMPLEMENTED | Child heartbeat carries battery state. |
| LOC08 | Offline alerts | IMPLEMENTED | Server sweep uses `last_seen_at`; depends on heartbeat health. |
| LOC09 | Permission-degradation alerts | IMPLEMENTED | Child heartbeat reports permission changes. |
| REM03 | WebRTC audio/video session | IMPLEMENTED | Parent and child must both join signaling. |
| REM05 | End session and cleanup | IMPLEMENTED | Either side can end; native audio service is cleaned up. |

## Parent-mode gaps

- `MON04`, `MON05`, and `USE06` are partial.
- `SET01` and `SET02` are UI-only preferences.
- `FAM14` and `AUD04` are backend-only and not reachable from the app.
- Website/content filtering, push notifications, password reset, and remote lock/wipe are absent; see `05_missing_and_incomplete_functionalities.md`.
