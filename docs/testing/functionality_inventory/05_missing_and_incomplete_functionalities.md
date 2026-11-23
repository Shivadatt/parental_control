# 05 — Missing and Incomplete Functionalities

This report separates three different gaps:

1. **Partially implemented** — code exists but the complete outcome is unavailable.
2. **UI only / backend only** — a control or API exists without the other half.
3. **Absent capabilities** — no implementation was found. These are *not* included in the 80-item inventory because there is no application feature to count.

## 1. Partially implemented (7)

| ID | Functionality | What works | What is missing / blocked | Source evidence |
|---|---|---|---|---|
| MON04 | Heartbeat-derived online/offline status | Presence model, stale thresholds, UI indicators | After reinstall the new device secret no longer matches the active row's `secret_hash`; heartbeat is rejected 401 and the child stays Offline | `device.dart:394-458`; `_shared/auth.ts:297-353`; `SecureStore.kt:86-105` |
| MON05 | Child permission summary | Permission fields are uploaded and displayed | Live notification permission was reported granted while `POST_NOTIFICATIONS` was absent from `dumpsys` | `device-telemetry/index.ts:96-146`; `device_admin_service.dart:161-166` |
| USE04 | Child usage collection/upload | `UsageReporter` and `usage_upload` exist | Upload depends on the broken device credential; usage stops reaching the parent after reinstall | `UsageReporter.kt`; `device-telemetry/index.ts`; live E2E |
| USE06 | Bedtime | Parent can configure and read bedtime | Bedtime is informational only; it does not itself suspend apps | `PolicyApplier.kt:502-503` |
| USE08 | OS-level daily-limit enforcement | Quota evaluator and policy plan exist | Suspension only works under Device Owner; a normal install reaches device-admin only | `QuotaEvaluator.kt`; `EnforcementMode.kt` |
| APP07 | OS app suspension | Suspension/restore code exists | Requires Device Owner; partial failure is surfaced in UI | `PolicyApplier.kt`; `NativeBridge.kt` |
| LOC04 | Child location tracking/upload | Foreground service and upload path exist | Upload depends on the broken device credential; location stops after reinstall | `LocationTrackingService.kt`; `device-telemetry/index.ts` |

## 2. UI-only preferences (2)

| ID | Functionality | Why it is UI only |
|---|---|---|
| SET01 | Local notification preference | The switch is persisted in `SharedPreferences` (`local_settings_service.dart`) but no local-notification scheduler or notification plugin reads it. |
| SET02 | Location-sharing reminder preference | The switch is persisted but no reminder/notification consumer exists. |

## 3. Backend-only capabilities (2)

| ID | Functionality | Why it is backend only |
|---|---|---|
| FAM14 | Family settings update API | `FamilyRepository.updateSettings` and the Supabase implementation exist, but no UI/controller calls them. |
| AUD04 | Scheduled retention sweep | Cron/Edge/SQL sweep exists; it has no in-app entry point and runs server-side. |

## 4. Absent capabilities (10)

These are capabilities users would reasonably expect from a parental-control product but that are not present in this checkout. Source searches covered `lib/`, Kotlin, manifests, migrations, and Edge Functions.

| ID | Missing capability | Evidence of absence | Impact |
|---|---|---|---|
| M01 | Website/internet/content filtering (DNS, VPN, proxy, safe search, category blocking) | No DNS/VPN/accessibility/WebView content-filter implementation; keyword search returned no functional code | Cannot restrict web content or specific sites |
| M02 | Push notifications / background alert delivery | No Firebase/FCM dependency or push-token registration; alerts are realtime only while a parent app is connected | Parent can miss alerts when the app is closed |
| M03 | Password reset / forgot-password flow | No `resetPassword`, forgot-password screen, or recovery call | Locked-out users have no in-app recovery path |
| M04 | Device Owner provisioning from the app | `ParentControlDeviceAdminReceiver.kt` explicitly states provisioning is not attempted; normal Play install cannot become Device Owner | Core enforcement remains partial on ordinary installs |
| M05 | Remote lock / wipe | No `lockNow` or `wipeData` call in `NativeBridge`/device-admin code | Lost-device response is limited to revoke/recovery |
| M06 | App install/uninstall monitoring and alerts | Installed apps are snapshotted; no package-add/remove receiver or alert type | Parent is not notified when apps are installed or removed |
| M07 | Multiple-family switching / family selector | Session holds one `activeFamily`; no family-switch UI or multi-family query path | One parent identity cannot manage separate families in-app |
| M08 | Accessibility service / accessibility-based enforcement | No `AccessibilityService` subclass or service declaration in the manifest | No accessibility-driven app/site control |
| M09 | Family owner transfer, family deletion, or parent leave-family | No RPC/UI for ownership transfer or family deletion; only child unlink exists | Family lifecycle cannot be completed by the owner |
| M10 | Additional parent/guardian invitation | No co-parent invite flow or role-assignment UI beyond the initial parent | Both parents cannot independently administer the family |

## 5. Top 10 incomplete or missing items for QA readiness

1. **MON04 / device credential lifecycle** — heartbeat, usage, and location all depend on it; this is the highest-impact blocker.
2. **M01 website/content filtering** — a core parental-control capability is absent.
3. **M02 push notifications** — alerts are not reliable when the parent app is closed.
4. **USE06 bedtime enforcement** — configuration exists but does not enforce.
5. **USE08 / APP07 Device Owner enforcement** — quota and suspension are only partial on normal installs.
6. **M04 Device Owner provisioning** — no supported path to reach full enforcement.
7. **M03 password reset** — account recovery gap.
8. **MON05 permission reporting** — false-positive notification status undermines trust.
9. **M06 app install/uninstall monitoring** — common parental-control expectation is absent.
10. **M07/M09/M10 family lifecycle** — multi-family, owner transfer/deletion, and co-parent invitations are absent.

## 6. Count reconciliation

| Bucket | Count |
|---|---:|
| Inventoried functionalities | 80 |
| Fully implemented | 69 |
| Partially implemented | 7 |
| UI only | 2 |
| Backend only | 2 |
| Planned (explicitly planned in code) | 0 |
| Unverified | 0 |
| Absent capabilities tracked separately | 10 |
