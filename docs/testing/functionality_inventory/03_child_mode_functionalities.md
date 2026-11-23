# 03 — Child-Mode Functionalities

Companion to `01_complete_functionality_inventory.md`.

## Headline counts

| Measure | Count |
|---|---:|
| Child-mode unique functionalities | **43** |
| Child-only | 19 |
| Shared with Parent mode | 14 |
| Parent–Child interconnected | 10 |
| Fully implemented | 37 |
| Partially implemented | 6 |
| UI only | 0 |
| Backend only (child role) | 0 |

## Child-only functionality (19)

| ID | Functionality | Status | Operational note |
|---|---|---|---|
| FAM05 | Child approves/declines pairing | IMPLEMENTED | Pairing requests are actionable in the Requests tab. |
| FAM06 | Child ID/contact ID and QR display | IMPLEMENTED | Permanent Child ID is displayed as QR and copyable text. |
| FAM07 | Child enrollment/device registration | IMPLEMENTED | Registers install identity with `device-register`. |
| FAM11 | Child self-unlink | IMPLEMENTED | Removes the child's link after confirmation. |
| USE04 | Child usage collection/upload | PARTIAL | Collector and uploader exist; live upload did not authenticate after reinstall. |
| USE08 | OS-level daily-limit enforcement | PARTIAL | Quota suspension requires Device Owner; otherwise enforcement is advisory. |
| APP07 | OS app suspension | PARTIAL | Uses `setPackagesSuspended`; requires Device Owner. |
| LOC03 | Child location-sharing toggle | IMPLEMENTED | Starts/stops native location tracking. |
| LOC04 | Child location tracking/upload | PARTIAL | Foreground service exists; live upload did not authenticate after reinstall. |
| REM02 | Child accepts/declines remote session | IMPLEMENTED | Consent is required before media starts. |
| SET05 | Device-admin activation | IMPLEMENTED | Requests Android device-admin; does not provision Device Owner. |
| SET06 | Background-location settings launcher | IMPLEMENTED | Opens the Android app settings page. |
| CHD01 | Child home summary | IMPLEMENTED | Family, device, protection, and connection summary. |
| CHD02 | Rules/policy display | IMPLEMENTED | Shows active policy and enforcement status. |
| CHD03 | Pairing/assistance requests inbox | IMPLEMENTED | Combined request inbox with accept/decline. |
| CHD04 | Guardian foreground service | IMPLEMENTED | Persistent enforcement/polling service. |
| CHD05 | Camera/microphone self-test | IMPLEMENTED | Verifies media permission and capture. |
| CHD06 | Native enforcement verification | IMPLEMENTED | Checks suspended packages against policy. |
| CHD07 | Background sync retry | IMPLEMENTED | Reconfigures native background sync after failures. |

## Shared functionality available in Child mode (14)

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

| ID | Functionality | Status | Child-side dependency |
|---|---|---|---|
| MON04 | Heartbeat-derived online/offline and last-seen status | PARTIAL | Heartbeat authentication fails after reinstall; parent sees Offline. |
| MON05 | Child permission summary | PARTIAL | Permission report is uploaded; notification flag was wrong on live device. |
| MON07 | Installed-app snapshot | IMPLEMENTED | Guardian service uploads installed packages. |
| APP05 | Enforcement acknowledgement and applied counts | IMPLEMENTED | Child reports applied/suspended package results. |
| LOC06 | Geofence enter/exit alerts | IMPLEMENTED | Location upload is evaluated against safe zones. |
| LOC07 | Low-battery alerts | IMPLEMENTED | Heartbeat includes battery level/charging state. |
| LOC08 | Offline alerts | IMPLEMENTED | Server detects stale `last_seen_at`. |
| LOC09 | Permission-degradation alerts | IMPLEMENTED | Heartbeat reports missing permissions. |
| REM03 | WebRTC audio/video session | IMPLEMENTED | Child joins signaling and runs audio service. |
| REM05 | End session and cleanup | IMPLEMENTED | Child stops native audio and releases session. |

## Child-mode gaps

- Credential lifecycle failure after reinstall blocks `MON04`, `USE04`, and `LOC04` in live conditions.
- `USE08` and `APP07` need Device Owner; a normal Play install only reaches device-admin mode.
- Bedtime is configured by the parent but does not itself suspend apps (`USE06`).
- No accessibility service, push notification channel, or password-reset flow exists; see `05_missing_and_incomplete_functionalities.md`.
