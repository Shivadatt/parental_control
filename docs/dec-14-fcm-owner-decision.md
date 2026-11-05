# DEC-14 Owner Decision: Push Notifications / FCM Delivery

**Document class:** Owner Decision Record (Governance, Architecture & Requirements).  
**Decision ID:** DEC-14.  
**Decision Title:** Out-of-band delivery of safety alerts (Firebase Cloud Messaging).  
**Registered Governance Status:** **APPROVED — Option B (Realtime + FCM Non-Authoritative Wake-Up Transport).**  
**Approval Date:** 2026-11-05 (Phase 9.5).  
**Target System:** HAVEN / `parentcontrol_app` (Flutter parent/child client, Kotlin Android native services, Supabase hosted backend `parent-control-prod` / `hhqgreaoqulmfwfwarhc`).  
**Implementation Authorization:** **NONE.** This document records architectural approval only. It does not authorize Firebase project creation, credential provisioning, schema migrations, Edge Function deployments, code modifications, APK builds, or hardware testing.

---

## 1. Decision Identification and Governance Status

- **Decision ID:** DEC-14
- **Title:** Out-of-band delivery of safety alerts (Firebase Cloud Messaging / Push Delivery)
- **Status:** **APPROVED — Option B** (Approved by Project Owner on 2026-11-05)
- **Approved Architecture Choice:** **Option B: Realtime + FCM Non-Authoritative Wake-Up Transport**
- **Governing Phase:** Phase 9.5
- **Preceding Decisions:**
  - DEC-01: **APPROVED** — Choice B (Local-only client diagnostics; DUR-01 remains OPEN).
  - DEC-02: **PENDING / BLOCKED** — Hosted Supabase mutations gated; historical Stage 7 pair reconciled; no new migrations or deployments authorized.
  - DEC-03: **PENDING / BLOCKED** — 75/75 controlled Android QA test rows remain NOT RUN; device testing, ADB, and APK builds prohibited.
  - DEC-05: **APPROVED** — Choice B (On-demand execution only; `pg_cron` absent hosted).
  - DEC-12: **APPROVED** — Choices D1-B, B1-B, O1-C, P1-A, DEFER (Screen-time and bedtime enforcement; implementation gated).
  - DEC-13: **APPROVED** — Option B (Managed Mode required for full device enforcement; safe-exit release blocker; implementation gated).
  - DEC-14: **APPROVED — Option B** (Subject of this document; implementation gated).
  - DEC-15: **PROPOSED** (Website filtering scope and mechanism).
  - DEC-16: **PROPOSED — Scope Exclusion Confirmed** (Screen recording/mirroring excluded from core scope).

---

## 2. Exact Approved Architecture (Option B)

The project owner has formally approved **Option B** with the following ten binding architectural rules:

1. **Dual-Transport Separation:** Supabase Realtime delivers live, low-latency alert updates while the parent application is connected and running in the foreground. FCM HTTP v1 acts strictly as an out-of-band, best-effort background notification and wake-up transport.
2. **Authoritative Source of Truth:** **Supabase remains the single authoritative source for alerts, permissions, family membership, and authorization.** FCM is strictly a non-authoritative notification pipe.
3. **Opaque Payloads (Privacy Enforcement):** FCM payloads must remain completely opaque and contain only the minimum identifiers required:
   - `alert_id` (UUID)
   - `family_id` (UUID)
4. **Zero PII or Telemetry in Transit:** No child personally identifiable information (PII), child names, GPS coordinates, application package names, device telemetry details, or human-readable alert text may ever be placed in push payloads. Google and intermediary push networks see only opaque UUID metadata.
5. **Mandatory Authenticated Re-fetch:** Receiving or tapping a push notification must launch the parent application into an authenticated state. The application must present its valid Supabase JWT to retrieve the authoritative alert details directly from `public.safety_alerts` via Row-Level Security (RLS).
6. **No Proof of Action:** FCM delivery, push receipt, or lock-screen display must **never** be treated as proof that an alert was seen, read, or acted upon by a guardian. Alert acknowledgement requires an explicit, authenticated mutation in Supabase.
7. **Failure Non-Destructiveness:** Delivery failure, FCM push throttling, or token expiration must **never** delete, invalidate, drop, or alter the enforcement status of an alert.
8. **Reconnection Reconciliation:** Missed alerts must be reconciled directly from Supabase upon app reconnect or foreground resume via authenticated REST/Realtime queries.
9. **Zero Authorization Authority:** FCM is not an authorization channel and must **never** execute privileged actions or alter device policy states.
10. **Scope Limitation:** The approved architecture is strictly limited to out-of-band alert delivery to parent devices. Child-side push notifications remain excluded to prevent announcing monitoring state.

---

## 3. Implementation Status vs. Approved Architecture

To maintain absolute governance transparency, the status of every component is classified below:

| Architectural Component | Approval Status | Provisioning / Implementation Status |
|---|---|---|
| **Realtime + FCM Dual Architecture** | **APPROVED (Option B)** | Realtime code exists; FCM **NOT IMPLEMENTED** |
| **Opaque Payload Design Rule** | **APPROVED** | Specification only; **NO CODE MODIFIED** |
| **Firebase Project (`parent-control`)** | Architecture approved | **NOT PROVISIONED** (Zero external projects created) |
| **Android App in Firebase** | Architecture approved | **NOT REGISTERED** (Package `com.parentcontrol.parent_control` not registered in Firebase) |
| **`google-services.json`** | Architecture approved | **NOT GENERATED / ABSENT** (Preserved in `.gitignore:10`) |
| **FCM Service Account Secret** | Architecture approved | **NOT PROVISIONED** (`FIREBASE_SERVICE_ACCOUNT_JSON` absent from hosted secrets) |
| **`push_tokens` Table** | Architecture approved | **NOT CREATED** (Gated by DEC-02; absent hosted) |
| **`push-register` Edge Function** | Architecture approved | **NOT DEPLOYED** (Gated by DEC-02; absent hosted) |
| **Outbound FCM HTTP v1 Sender** | Architecture approved | **NOT IMPLEMENTED** (No outbound HTTP dispatch in repo) |
| **Flutter FCM Client (`push_service.dart`)** | Architecture approved | **NOT IMPLEMENTED** (Zero `firebase_*` dependencies in `pubspec.yaml`) |
| **Parent `POST_NOTIFICATIONS` Prompt** | Architecture approved | **NOT IMPLEMENTED** (Kotlin bridge exists; no parent-side caller) |
| **End-to-End Push Verification** | Architecture approved | **NOT TESTED** (Gated by DEC-03; 75/75 QA rows remain NOT RUN) |

---

## 4. Problem Statement (Historical Baseline)

In the current implementation of HAVEN, safety alerts (such as critical battery depletion, geofence boundary crossings, and device heartbeat timeouts) are delivered to parents **exclusively via an active Supabase Realtime WebSocket connection** while the parent application is running in the foreground:

1. **Foreground-Only Visibility:** If the parent application is closed, terminated, suspended in the background by the Android operating system, or disconnected due to network instability, **no notification or alert banner is delivered to the parent**.
2. **Silent Failure to Alert:** The guardian remains completely unaware of child safety events until they manually reopen the application and force a refresh of the alerts screen.
3. **Absence of Push Transport:** There is currently zero out-of-band notification transport (no Firebase Cloud Messaging, no UnifiedPush, no Apple Push Notification service).
4. **Architectural Dilemma:** A parental control application that fails to alert parents when backgrounded leaves a major safety gap. However, introducing push infrastructure introduces external cloud dependencies (Google Cloud/Firebase), token management overhead, battery/OEM delivery quirks, and significant privacy and security attack surfaces.

The owner's selection of Option B resolves the architectural direction while bounding external cloud exposure.

---

## 5. Verified Existing Architecture

Every fact below has been directly verified in the codebase and live hosted Supabase instance (`parent-control-prod` / `hhqgreaoqulmfwfwarhc`):

| Component | Repository / Hosted Source | Verified State |
|---|---|---|
| **Alert Table & Schema** | `supabase/migrations/20260101000000_core.sql:297-316` | **VERIFIED (Code & Hosted)**: Table `public.safety_alerts` exists with columns `id`, `family_id`, `device_id`, `type`, `severity`, `message`, `payload`, `created_at`, `acknowledged_at`, `acknowledged_by`. Check constraint limits `type` to `('low_battery', 'offline', 'geofence_enter', 'geofence_exit', 'app_blocked', 'permission_missing', 'other')`. 4 rows exist hosted. |
| **Alert Row-Level Security** | `supabase/migrations/20260101000200_rls.sql:173-180` | **VERIFIED (Code & Hosted)**: Policy `safety_alerts_select_parent_or_child` allows authenticated parents and children of the family to read alert rows. Client direct `INSERT`, `UPDATE`, `DELETE` are disabled. |
| **Realtime Publication** | `supabase/migrations/20260101000100_functions.sql:922-924` | **VERIFIED (Code & Hosted)**: `public.safety_alerts` is an active member of the `supabase_realtime` publication. |
| **Parent Client Alert Stream** | `lib/data/repositories/supabase_alert_repository.dart:55-124` | **VERIFIED (Code)**: Uses `_supabase.client.channel('safety-alerts:<familyId>:...')` with private channel config and Postgres change filters on `public.safety_alerts`. Reports error: *"Live alert updates disconnected. Refresh to reload alerts."* on disconnect or timeout. |
| **Parent Alerts UI & Polling** | `lib/features/safety_alerts/safety_alerts_controller.dart:40-140` | **VERIFIED (Code)**: Calls `load()` (REST `fetchAlerts`, limit 100) and `watchAlerts()` on initialization. Merges incoming Realtime events by UUID. Family-wide acknowledgment via `family-admin` (`ack_alert`). |
| **Server-Side Alert Generation** | `supabase/functions/device-telemetry/index.ts:121-148, 330-352`<br>`supabase/migrations/20260101000100_functions.sql:531-573` | **VERIFIED (Code)**: Low battery (≤15%) and geofence transitions (enter/exit) inserted by `device-telemetry`. Offline device detection (15-min heartbeat lapse) inserted by `private.detect_offline_devices()`. |
| **Android Native Notification Permission** | `android/app/src/main/kotlin/.../NativeBridge.kt:471-475`<br>`android/app/src/main/AndroidManifest.xml:11` | **VERIFIED (Code)**: `POST_NOTIFICATIONS` is declared in the manifest. Permission request plumbing exists in `NativeBridge.kt`, but it is **only invoked on the child side** for foreground service status; **no parent-side permission request exists**. |
| **Parent Settings Local Switch** | `lib/features/settings/settings_body.dart:118-135`<br>`lib/data/services/local_settings_service.dart:54-57` | **VERIFIED (Code)**: Switch *"Show local notifications"* is a local-only shared preference. It has zero effect on server alerting or push transport. |
| **Navigation & Deep Linking** | `lib/app/app.dart:18` | **VERIFIED (Code)**: App defines `initialRoute` only. Zero deep-link routing exists to open a specific alert from an OS intent. |

---

## 6. Historical Decision Options Evaluated

For governance traceability, the three evaluated options are preserved below:

### Option A — Realtime Only (In-App Delivery) [EVALUATED — NOT SELECTED]
- Safety alerts delivered strictly via Supabase Realtime WebSockets to active, foregrounded parent applications.
- No external push services or tokens.
- Fails when application is suspended, backgrounded, or terminated.

### Option B — FCM as Non-Authoritative Wake-Up Transport [SELECTED & APPROVED]
- Dual-transport architecture: Realtime in foreground, FCM HTTP v1 for background wake-up.
- Supabase authoritative; opaque payloads; no child PII; best-effort delivery.
- Comprehensive security and privacy controls enforced.

### Option C — Defer FCM [EVALUATED — NOT SELECTED]
- Postpone all FCM architectural decisions and provisioning to Phase 10+.

---

## 7. Detailed 20-Criteria Comparison Matrix (Historical Record)

| # | Evaluation Criterion | Option A: Realtime Only | Option B: FCM Non-Authoritative Wake-Up (APPROVED) | Option C: Defer FCM |
|---|---|---|---|---|
| **1** | **Foreground delivery** | Fast (<500ms) direct streaming over Supabase Realtime WebSocket while app is active. | Fast streaming over Realtime. FCM foreground messages suppressed in-app to prevent duplicates. | Fast (<500ms) direct streaming over Supabase Realtime WebSocket while app is active. |
| **2** | **Background delivery** | **ZERO.** WebSocket is killed or paused by Android OS within seconds of backgrounding. | **Supported (Best-Effort).** FCM wakes device or displays system tray notification via Play Services. | **ZERO.** Backgrounded parent app receives no alerts. |
| **3** | **Terminated-app behavior** | **ZERO.** Process is dead; no background socket exists. | **Supported.** Android system displays notification from FCM payload; tap launches app to alert screen. | **ZERO.** Terminated app receives no alerts. |
| **4** | **Offline behavior** | **ZERO.** Connection drops; missed alerts only fetched on manual reconnect. | **Queued Delivery.** FCM servers buffer notifications up to TTL (e.g., 4 weeks max); delivered when device reconnects. If dropped, Supabase retains alert. | **ZERO.** Missed alerts fetched only upon manual reconnect. |
| **5** | **Delivery reliability & limitations** | 100% dependent on continuous WebSocket connection. Unreliable if network blips or screen turns off. | **Best-Effort.** Subject to OEM battery managers (ColorOS, MIUI, EMUI), Android Doze mode, and Google Play Services health. No delivery guarantee. | 100% dependent on continuous WebSocket connection. |
| **6** | **Battery impact** | Minimal when idle (socket closed), but keeping app open in foreground to monitor alerts drains battery. | **Minimal.** Leverages shared Google Play Services connection; negligible battery overhead on parent phone. | Minimal when idle; requires foreground operation for monitoring. |
| **7** | **Android permission requirements** | Standard `INTERNET` and `ACCESS_NETWORK_STATE` only. No runtime prompt. | Requires runtime `POST_NOTIFICATIONS` permission prompt on Android 13+ (API 33+) for parent app. | Standard `INTERNET` and `ACCESS_NETWORK_STATE` only. |
| **8** | **Android notification permission behavior** | Not affected by notification settings (in-app UI only). | If parent denies `POST_NOTIFICATIONS`, system banners are blocked; app must explain need and fall back to in-app alerts. | Not affected by notification settings. |
| **9** | **Token lifecycle** | **None.** No device tokens exist. | **Complex.** Token generation (`getToken`), registration in Supabase, rotation (`onTokenRefresh`), invalidation on logout/unlink, cleanup of stale tokens. | **None.** Token lifecycle deferred. |
| **10** | **Token security** | **N/A.** | **Critical.** Tokens stored in Supabase `push_tokens` with strict RLS (service-role only; parent-scoped access). Tokens must never leak across family boundaries. | **N/A.** |
| **11** | **Privacy & payload sensitivity** | **High Privacy.** Data flows strictly between Supabase and parent device over TLS. No third-party data transit. | **Protected via Opaque Payloads.** Payloads carry zero PII, zero child locations, zero app names. Google servers see only metadata IDs (`alert_id`). | **High Privacy.** No third-party data transit. |
| **12** | **Duplicate notification handling** | Handled in memory by `SafetyAlertsController` matching `alert.id`. | Requires FCM collapse keys / notification tags so identical alert IDs update rather than spamming system tray. | Handled in memory by `SafetyAlertsController`. |
| **13** | **Retry & reconciliation** | In-app REST query (`load(refresh: true)`) queries up to 100 past alerts from `public.safety_alerts`. | Dual-layer: FCM handles transport retries; parent app reconciles unread/unacknowledged alerts from Supabase on resume. | In-app REST query queries up to 100 past alerts from `public.safety_alerts`. |
| **14** | **Supabase Realtime dependency** | **100% Critical Path.** Sole mechanism for live updates. | **Dual-Path.** Realtime handles fast in-app updates; FCM handles out-of-band wakeups. Not mutually exclusive. | **100% Critical Path.** Sole mechanism for live updates. |
| **15** | **Firebase project dependency** | **ZERO.** Supabase only. | **Mandatory External Dependency.** Requires Firebase project, Android app registration, `google-services.json`, and service account keys. | **ZERO.** No external provider dependency now. |
| **16** | **Operational complexity** | **Lowest.** Single cloud backend (Supabase). No cross-cloud credentials or API deprecations. | **High.** Two cloud providers (Supabase + Google Cloud/Firebase). Service account rotation, secret management, Gradle plugin maintenance. | **Lowest.** Defers multi-cloud operational burden. |
| **17** | **Testing requirements** | Unit tests for controller and repository; Realtime subscription unit tests (already present). | **Extensive.** Edge Function Deno tests, token lifecycle integration tests, push payload tests, Android physical device testing (Play Services, Doze, killed state). | Existing unit test suite only. |
| **18** | **Cost & maintenance implications** | $0 additional cost. | $0 for FCM messaging (free tier). Marginal Supabase Edge Function compute. Ongoing developer maintenance for SDK/API updates. | $0 additional cost, zero maintenance overhead now. |
| **19** | **Failure monitoring** | In-app channel error reporting (`RealtimeSubscribeStatus.channelError`). | Edge Function outbound logging (FCM HTTP status codes), token invalidation metrics, delivery failure counters in Supabase. | In-app channel error reporting only. |
| **20** | **Security implications** | Attack surface limited to Supabase Auth & RLS. | Expanded attack surface: third-party transit (Google), potential token leakage, service account key security. Requires non-authoritative boundary. | Attack surface limited to Supabase Auth & RLS. |

---

## 8. Security, Privacy and Architectural Requirements

The following requirements are binding design constraints for future implementation:

1. **Supabase Authority:** PostgreSQL (`public.safety_alerts`) is the sole authoritative record of safety events.
2. **Payload Sanitization (Approved Schema):** Push payloads dispatched through FCM HTTP v1 must strictly adhere to the following schema:
   ```json
   {
     "message": {
       "token": "<FCM_TOKEN>",
       "notification": {
         "title": "HAVEN Safety Alert",
         "body": "New activity recorded for your family."
       },
       "data": {
         "alert_id": "<UUID>",
         "family_id": "<UUID>",
         "type": "safety_alert"
       },
       "android": {
         "priority": "high",
         "notification": {
           "channel_id": "haven_safety_alerts",
           "visibility": "private"
         }
       }
     }
   }
   ```
3. **In-App Authorization Re-validation:** Tapping a notification must authenticate the parent session and query `public.safety_alerts` via RLS.
4. **Lock-Screen Privacy:** Android notification channel must enforce `NotificationCompat.VISIBILITY_PRIVATE`.
5. **Token Lifecycle Requirements (Future Design Work):**
   - **Storage:** Table `public.push_tokens` keyed to `user_id uuid references profiles(id) on delete cascade`, strictly service-role accessible.
   - **Registration:** Edge Function `push-register` requiring verified parent JWT.
   - **Rotation:** Client listener on `FirebaseMessaging.instance.onTokenRefresh` updating Supabase.
   - **Revocation:** Explicit token deletion on logout or device unlinking.
   - **Stale Token Pruning:** Automated pruning when FCM returns `UNREGISTERED` or `NOT_FOUND`.

---

## 9. Required Acceptance Criteria for Future Implementation

When implementation is explicitly authorized, it must satisfy:

- **AC-14-1 (Dedicated Firebase Project):** Dedicated Firebase project created; `google-services.json` injection strategy documented and verified not to break clean git checkouts.
- **AC-14-2 (Token Schema & RLS):** Hosted `push_tokens` table created with strict RLS (service-role only; parent-scoped access). Migration tested and applied strictly in accordance with DEC-02.
- **AC-14-3 (Zero Client Service Secrets):** Firebase service account private key stored exclusively as an Edge Function secret (`FIREBASE_SERVICE_ACCOUNT_JSON`). Zero service keys in Flutter code, Kotlin code, or client-side storage.
- **AC-14-4 (Payload Privacy Compliance):** Automated unit tests verify that push payloads contain zero child names, GPS coordinates, application packages, or sensitive alert messages.
- **AC-14-5 (Non-Authoritative Enforcement):** Automated tests prove that push delivery success or failure has zero effect on `device_policies`, `device_commands`, or session state.
- **AC-14-6 (Parent Permission UX):** Parent application explicitly requests Android 13+ `POST_NOTIFICATIONS` permission with user-facing rationale and graceful fallback.
- **AC-14-7 (Token Invalidation):** Signing out or revoking a device immediately invalidates and deletes the associated push token in Supabase.
- **AC-14-8 (Real-Device End-to-End Verification):** A real safety alert (e.g., low battery or geofence exit) is triggered and observed delivering a background push notification on a physical Android device (conducted only when DEC-03 is cleared). Status remains `NOT TESTED` until observed.

---

## 10. Implementation and Provisioning Gates

> [!CAUTION]
> **STRICT GOVERNANCE GATES IN FORCE**
>
> Approval of DEC-14 Option B constitutes **architecture and product direction approval only**.
> 
> The following restrictions remain strictly binding:
> - **Firebase Provisioning Gate:** No Firebase project may be created, no Android app registered, and no service account credentials generated without explicit written authorization.
> - **Database / Hosted Gate (DEC-02):** No `push_tokens` table, migrations, or Edge Functions may be applied while DEC-02 is pending.
> - **Hardware Verification Gate (DEC-03):** No APK builds, Gradle executions, ADB commands, or device runs may be performed while DEC-03 is pending.
> - **Phase 10 Gate:** Implementation is strictly deferred to an authorized implementation phase. Phase 10 has not started.

---

## 11. Owner Approval Record

```text
================================================================================
DEC-14 OWNER APPROVAL RECORD
================================================================================
Date: 2026-11-05
Owner Ruling: APPROVED — OPTION B
Selection: Realtime + FCM Non-Authoritative Wake-Up Transport

Approved Architecture:
1. Supabase Realtime delivers live updates while parent app is connected.
2. FCM HTTP v1 acts as a best-effort background notification/wake-up transport.
3. Supabase remains the single authoritative source for alerts, permissions, and authorization.
4. FCM payloads must remain opaque ({ alert_id, family_id }).
5. Zero child PII, names, coordinates, telemetry details, or alert text in push payloads.
6. Parent app authenticates with Supabase and retrieves alert details via RLS.
7. FCM delivery or receipt is never treated as proof an alert was read or acted upon.
8. Delivery failure never deletes, invalidates, or changes enforcement status.
9. Missed alerts reconciled from Supabase after reconnection.
10. FCM is not an authorization channel and never executes privileged actions.

Implementation Authorization: NONE (Architecture Approval Only; Implementation Gated)
================================================================================
```

---

*Document consolidated and ratified under Phase 9.5.*
