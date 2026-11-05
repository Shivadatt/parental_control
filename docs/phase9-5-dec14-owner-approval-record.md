# Phase 9.5: DEC-14 Owner Approval Record

**Document class:** Governance Consolidation & Decision Record.  
**Decision ID:** DEC-14 (Push Notifications / Firebase Cloud Messaging Delivery).  
**Registered Governance Status:** **APPROVED — Option B (Realtime + FCM Non-Authoritative Wake-Up Transport).**  
**Approval Date:** 2026-11-05 (Phase 9.5).  
**Repository:** `D:\parentcontrol_app`  
**Supabase Project Context:** `parent-control-prod` / `hhqgreaoqulmfwfwarhc` (AWS Seoul, `ap-northeast-2`).  
**Implementation Authorization:** **NONE.** Architecture and product direction approval only.

---

## 1. Owner Decision and Governance Status

The project owner has reviewed the decision-preparation specification [`docs/dec-14-fcm-owner-decision.md`](dec-14-fcm-owner-decision.md) and formally rendered the binding ruling:

> **DEC-14 Owner Decision: APPROVED — Option B: Realtime + FCM Non-Authoritative Wake-Up Transport.**

This approval formally resolves the architectural direction for safety alert delivery in HAVEN. It does **not** authorize immediate implementation, provisioning, builds, or deployments.

---

## 2. Exact Approved Architecture (Option B)

The approved Option B architecture establishes ten binding rules:

1. **Dual Transport Architecture:**
   - **Supabase Realtime:** Delivers live, low-latency alert updates while the parent application is connected and running in the foreground.
   - **FCM HTTP v1:** Acts strictly as an out-of-band, best-effort background notification and wake-up transport when the parent app is closed, suspended, or terminated.
2. **Supabase as the Single Authoritative Source:**
   - Supabase PostgreSQL (`public.safety_alerts`) remains the sole source of truth for alert records, timestamps, family membership, and authorization.
   - FCM is strictly a transport pipe and carries zero authority.
3. **Opaque Payloads (Privacy by Design):**
   - Push payloads dispatched to FCM must contain only minimal non-sensitive identifiers:
     - `alert_id` (UUID)
     - `family_id` (UUID)
     - Generic notification title/body (e.g., *"HAVEN Safety Alert"*, *"New activity recorded for your family."*)
4. **Strict PII & Telemetry Exclusion:**
   - Zero child names, GPS coordinates, geofence names, app package names, device telemetry, or human-readable alert messages may ever be placed in push payloads. Google and intermediary networks see only opaque metadata.
5. **Mandatory Authenticated Re-Fetch:**
   - Tapping or receiving a push notification must launch the parent application into an authenticated state.
   - The app must present its Supabase JWT to query authoritative alert details via Row-Level Security (RLS).
6. **No Proof of Action:**
   - FCM notification delivery, receipt, or lock-screen display must never be treated as proof that an alert was read, seen, or acted upon by a guardian.
7. **Failure Non-Destructiveness:**
   - FCM delivery failures, network timeouts, or token invalidations must never delete, drop, or alter the enforcement or persistence of an alert.
8. **Reconnection Reconciliation:**
   - Missed alerts must be reconciled directly from Supabase upon app reconnect or foreground resume.
9. **Zero Authorization Authority:**
   - FCM is not an authorization channel and must never trigger remote privileged actions or modify device policy state.
10. **Target Scope:**
    - Push notifications are approved strictly for parent devices. Child-side push notifications remain excluded.

---

## 3. Realtime vs. FCM Transport Responsibilities

| Responsibility / Characteristic | Supabase Realtime (Primary Fast Path) | Firebase Cloud Messaging (Out-of-Band Wake-Up) |
|---|---|---|
| **Operational State** | Active while parent app is foregrounded and connected. | Active when parent app is suspended, backgrounded, or terminated. |
| **Connection Type** | Persistent WebSocket connection to Supabase Realtime. | Multiplexed Android system connection via Google Play Services. |
| **Delivery Latency** | Sub-second (<500ms) live streaming. | Variable best-effort latency (seconds to minutes, subject to Doze/network). |
| **Payload Content** | Authoritative Postgres row payload filtered by RLS. | Strictly opaque `{ alert_id, family_id }` with generic display text. |
| **System Tray Notification** | In-app snackbars/banners; no system tray spam when active. | System tray notification posted by OS or app background handler. |
| **Data Authority** | Direct read of database mutations. | Non-authoritative trigger; instructs client to fetch from database. |

---

## 4. Supabase Authority and RLS Requirements

- **Authoritative Database Table:** `public.safety_alerts` (verified present on hosted Supabase with 4 rows, RLS enabled).
- **Client Read Policy:** `safety_alerts_select_parent_or_child` allows authenticated parents to select alerts belonging to their family.
- **Client Write Protection:** Direct client `INSERT`, `UPDATE`, and `DELETE` remain revoked. Alerts are generated strictly by server-side processes (`device-telemetry`, `detect_offline_devices`) and acknowledged via `family-admin` (`ack_alert`).
- **Token Storage Isolation:** Future `push_tokens` table must enforce service-role only access or strict per-user RLS (`user_id = auth.uid()`). Child devices must never have read access to parent push tokens.

---

## 5. Opaque Payload and Privacy Architecture

To ensure strict compliance with child privacy laws (COPPA, GDPR-K) and eliminate telemetry surveillance risks, the push payload schema is fixed:

```json
{
  "message": {
    "token": "<PARENT_DEVICE_FCM_TOKEN>",
    "notification": {
      "title": "HAVEN Safety Alert",
      "body": "New activity recorded for your family."
    },
    "data": {
      "alert_id": "c1f7b8a0-...",
      "family_id": "8e3d2a1b-...",
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

Intermediaries (Google, cellular carriers, push proxies) cannot infer child behavior, location, or application usage from this payload.

---

## 6. Best-Effort Delivery Limitation & Reconnection Protocol

- **No Delivery SLA:** FCM does not guarantee 100% immediate delivery. Notifications are subject to network drops, carrier filtering, Doze maintenance windows, and OEM background app killers (e.g., ColorOS/Realme UI, MIUI, EMUI).
- **Reconciliation Invariant:** The parent application must execute an authoritative sync query against Supabase on every foreground resume (`load(refresh: true)`), fetching up to 100 unacknowledged alerts. A missed push notification never results in a missed alert.

---

## 7. Token Lifecycle Requirements Awaiting Implementation

The approved architecture requires a formal token lifecycle that remains **unimplemented**:

1. **Token Generation:** Flutter client calls `FirebaseMessaging.instance.getToken()`.
2. **Registration:** Edge Function `push-register` validates parent JWT and upserts into `public.push_tokens(user_id, token, platform, last_seen_at)`.
3. **Rotation:** Client listens to `FirebaseMessaging.instance.onTokenRefresh` and dispatches new tokens to `push-register`.
4. **Revocation on Sign-Out / Unlink:** Explicit deletion of token records upon user logout or family unlinking.
5. **Stale Token Pruning:** Backend sender handles HTTP v1 `UNREGISTERED` and `NOT_FOUND` error codes by marking tokens as revoked or deleting them.

---

## 8. Remaining Security and Reliability Risks

1. **OEM Aggressive Power Management:** On devices such as the lab Realme 7 (`RMX2161`), aggressive OS task killing may delay FCM background wake-ups until the screen is turned on.
2. **Google Play Services Dependency:** Devices lacking GMS (or running custom de-Googled ROMs) cannot receive FCM notifications.
3. **Fresh-Clone Build Break Hazard:** `google-services.json` is git-ignored (`.gitignore:10`). Adding Gradle plugins without providing a mock config breaks clean checkouts.
4. **Secret Management:** The Firebase service account private key (`FIREBASE_SERVICE_ACCOUNT_JSON`) is a high-privilege credential that must be safeguarded in Supabase project secrets.

---

## 9. Firebase Provisioning Status: NOT STARTED

No external cloud resources have been provisioned:
- **Firebase Project:** None created.
- **Android App Registration:** Package `com.parentcontrol.parent_control` not registered.
- **`google-services.json`:** Not generated; absent from disk.
- **Service Account Credentials:** Not generated; absent from hosted Supabase secrets.

---

## 10. Existing Implementation Gaps

| Area | Missing Component | Blocker / Dependency |
|---|---|---|
| **Database** | Migration creating `public.push_tokens` table | Gated by **DEC-02** |
| **Backend** | Edge Function `push-register` & outbound FCM sender | Gated by **DEC-02** |
| **Secrets** | `FIREBASE_SERVICE_ACCOUNT_JSON` in hosted Supabase | Unprovisioned |
| **Flutter Client** | `firebase_core`, `firebase_messaging`, push handler | Gated by Implementation Phase |
| **Android Native** | Parent-side `POST_NOTIFICATIONS` runtime prompt | Gated by Implementation Phase |
| **App Routing** | Deep-link intent handling for alert tap navigation | Gated by Implementation Phase |
| **Verification** | Physical on-device push delivery testing | Gated by **DEC-03** |

---

## 11. Authorization Dependencies (DEC-02 and DEC-03)

- **DEC-02 Dependency:** Deploying the `push_tokens` table, updating schema RLS, or deploying Edge Function dispatchers requires resolving DEC-02. Hosted mutations remain strictly prohibited.
- **DEC-03 Dependency:** Verifying push delivery on the physical Realme 7 (`RMX2161`) or Android emulators requires resolving DEC-03. All 75 QA rows remain strictly `NOT RUN`.

---

## 12. Explicit No-Implementation Confirmation

- **Zero Source Code Edits:** No Flutter (`lib/`) or Kotlin (`android/`) files modified.
- **Zero Build / Hardware Operations:** No Gradle builds, APK compilations, ADB commands, or device pairings executed.
- **Zero Hosted Mutations:** No database tables created, no migrations applied, no Edge Functions deployed, and no secrets set in hosted Supabase (`parent-control-prod`).
- **Zero Firebase Provisioning:** No Google Cloud or Firebase resources touched.
- **Git Working Tree Preserved:** No Git state-altering commands (`add`, `commit`, `push`, `checkout`, `reset`) executed.

---

*Phase 9.5 Documentation Consolidation Complete. Awaiting separate explicit owner authorization before any implementation or provisioning begins.*

