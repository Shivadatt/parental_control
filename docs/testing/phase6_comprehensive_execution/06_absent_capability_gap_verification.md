# 06 — Absent Capability Gap Verification Report

**Audit Execution Date:** 2026-11-23  
**Audit Phase:** Phase 6 Comprehensive End-to-End Execution  
**Auditor:** HAVEN QA Security & Gaps Audit Team (Subagent 4)  
**Target Application:** HAVEN Parent Control (`com.parentcontrol.parent_control`)  
**Baseline Git Commit:** `5ffc5c170add4bfafd236beb633f00b6fe86243b` (HEAD on `main`)  
**Scope:** Exhaustive Verification of the 10 Absent Capabilities (M01 through M10)

---

## 1. Executive Summary & Scope Declaration

The **10 Absent Capabilities (M01 through M10)** represent industry-standard parental control features that are **entirely missing from the codebase**. 

### Critical Architecture & Matrix Distinctions:
1. **Separate from the 80 Inventoried Functionalities:** These 10 items are intentionally tracked outside the 80 primary functionality IDs (`FAM01–FAM14`, `MON01–MON06`, `USE01–USE08`, `APP01–APP07`, `LOC01–LOC06`, `GEO01–GEO06`, `REM01–REM08`, `AUD01–AUD04`, `A01–A10`, `SET01–SET04`, `SYS01–SYS03`). They are not counted among the 69 full, 7 partial, 2 UI-only, or 2 backend-only items.
2. **Absence is Not a Runtime Test Failure:** A missing feature cannot have an executed test case, nor can it receive a `FAIL` verdict. Absence is an **architectural scope gap** that requires explicit executive/product decisions.
3. **Exhaustive Code Proof Required:** Each gap documented below has been verified across four distinct engineering planes:
   - Client-side Dart / Flutter UI and domain layers (`lib/`).
   - Android Native Kotlin bridge, manifests, and background services (`android/`).
   - Supabase Edge Functions (`supabase/functions/`).
   - PostgreSQL schema migrations and RLS policies (`supabase/migrations/`).

---

## 2. Comprehensive Absent Capability Register (M01 – M10)

---

### M01: Website / Internet / Content Filtering

#### 1. Industry Standard & Expected Parental Control Behavior
A primary value proposition of modern parental control applications is the ability to safeguard children from adult content, gambling, violence, and malicious websites. Expected capabilities include:
- Category-based domain blocking (Adult, Violence, Social Media, Gaming).
- Custom URL blocklists and allowlists.
- Enforced SafeSearch on Google, Bing, and YouTube.
- Protocol-level interception via local VPN (`VpnService`), DNS-over-HTTPS (DoH), or browser extensions.

#### 2. Code Proof of Total Absence
- **Android Manifest & Native Layer:**
  - `android/app/src/main/AndroidManifest.xml` contains **no declaration** of `android.net.VpnService` or network extension services.
  - No subclass of `VpnService` exists anywhere in `android/app/src/main/kotlin/`.
- **Flutter / Dart Layer:**
  - No URL filtering, web categories, or proxy configuration models exist in `lib/data/models/` or `lib/features/`.
  - No HTTP proxy, DNS redirector, or browser inspection components exist.
- **Backend / Policy Schema:**
  - `supabase/migrations/20260101000000_core.sql` defines `device_policies` with `blocked_packages` (array of Android package names) and `time_limits` (JSONB). It contains **no columns or tables** for URLs, domains, categories, or web filters.

#### 3. Real-World Product Impact
Children can use any installed web browser (Chrome, Samsung Internet, Firefox, Opera) without restriction. Adult material, inappropriate search queries, and phishing websites are completely unmonitored and unfiltered.

#### 4. Classification & Recommendations
- **Classification:** Architectural Feature Gap (Native OS / Network Layer).
- **Product Recommendation:** Prioritize implementing a local Android `VpnService` that routes DNS queries through a filtering resolver (e.g., Cloudflare 1.1.1.3 for Families or NextDNS API) with configurable category policies.

---

### M02: Push Notifications & Background Alert Delivery

#### 1. Expected Behavior
When an emergency or safety event occurs (e.g., Geofence exit, child SOS trigger, critical low battery, or tampering alert), parents must receive **immediate push notifications** on their mobile device even when the HAVEN application is closed or running in the background.

#### 2. Code Proof of Total Absence
- **Dependencies (`pubspec.yaml`):**
  - Search for `firebase_core`, `firebase_messaging`, or third-party push plugins (OneSignal, Pusher):
    ```yaml
    # Exhaustive scan of dependencies in pubspec.yaml:
    cupertino_icons, get, supabase_flutter, shared_preferences, flutter_secure_storage,
    qr_flutter, mobile_scanner, flutter_webrtc, intl, connectivity_plus, crypto, uuid.
    ```
    **Result:** Zero push notification packages are included.
- **Android Native Configuration:**
  - `android/app/build.gradle.kts` lacks `google-services` plugin and Firebase SDK dependencies.
  - `AndroidManifest.xml` declares no Firebase Messaging service (`FirebaseMessagingService`).
- **Backend Architecture:**
  - Supabase Edge Functions (`device-telemetry`, `pairing`, `remote-session`) emit events to Supabase Realtime channels and insert rows into `safety_alerts`. However, there is **no webhook or Edge Function** that dispatches messages to FCM (Firebase Cloud Messaging) or Apple APNs.
  - No `push_tokens` or `fcm_tokens` table/column exists in the database.

#### 3. Real-World Product Impact
Parents **only receive alerts** if the HAVEN app is actively open and connected to the Supabase Realtime WebSocket. If the parent's phone is locked, asleep, or the app process is terminated, critical safety notifications are silently queued in the database and **never alerted to the parent**.

#### 4. Classification & Recommendations
- **Classification:** Infrastructure & Critical Safety Gap.
- **Product Recommendation:** Integrate Firebase Cloud Messaging (FCM). Add a `device_push_tokens` table in Supabase, register tokens on login, and trigger push dispatches via Supabase Database Webhooks calling a server-side FCM dispatcher Edge Function.

---

### M03: Password Reset & Forgot-Password Recovery Flow

#### 1. Expected Behavior
Users who forget their account password must have a self-service recovery mechanism: clicking "Forgot Password?", entering their registered email, receiving a secure recovery link, and resetting their password.

#### 2. Code Proof of Total Absence
- **UI / Client Layer:**
  - `lib/features/auth/login_page.dart` (lines 150–190): Only renders `"Sign in"` button and `"New here? Create an account"` link. There is **no "Forgot password?"** button or link.
  - `lib/app/routes/app_routes.dart`: Declares `login`, `register`, `roleSelection`, `parentShell`, `childShell`, etc. Contains **no reset password route** (e.g., `forgotPassword`, `resetPassword`).
- **Repository Layer:**
  - `lib/data/repositories/supabase_auth_repository.dart`: Implements `signIn`, `signUp`, `signOut`, `resendEmailVerification`. Contains **no invocation** of `SupabaseClient.auth.resetPasswordForEmail()`.

#### 3. Real-World Product Impact
Any parent or child who forgets their password is permanently locked out of their account. They cannot regain access to their linked family or child devices without direct administrator intervention in the Supabase backend.

#### 4. Classification & Recommendations
- **Classification:** Essential Authentication Lifecycle Gap.
- **Product Recommendation:** Add `resetPasswordForEmail()` to `AuthRepository`, create `ForgotPasswordPage`, and configure the Supabase Auth email recovery template with deep link handler `parentcontrol://auth-reset`.

---

### M04: Device Owner Provisioning from Application

#### 1. Expected Behavior
To achieve true system-level control (hard app suspension, preventing app uninstallation, disabling safe mode, locking status bar), Android parental control apps either provide a guided Device Owner provisioning flow (via QR code provisioning during initial device setup) or enterprise EMM enrollment.

#### 2. Code Proof of Total Absence
- **Native Implementation:**
  - In `android/app/src/main/kotlin/com/parentcontrol/parent_control/ParentControlDeviceAdminReceiver.kt` (lines 8–17):
    ```kotlin
    /**
     * Device Administrator alone does not allow app suspension. Suspension requires
     * Device Owner provisioning, which a normal Play installation does not have.
     * A device owner can be provisioned only on a factory-reset device without
     * accounts, for example:
     *   adb shell dpm set-device-owner \
     *     com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver
     * This app never attempts the provisioning command programmatically.
     */
    ```
  - The application provides **no in-app provisioning wizard**, no NFC provisioning payload, and no QR setup generator for Android Setup Wizard.

#### 3. Real-World Product Impact
On ordinary retail installations from an app store, HAVEN is restricted to standard Device Administrator privileges. As proven in `P6-LIM-005` and `P6-LIM-006`, core features like app suspension and hard daily limits fail with `SecurityException` unless the parent connects the child phone to a PC via USB and runs manual ADB commands.

#### 4. Classification & Recommendations
- **Classification:** Operating System Privilege Limitation / Provisioning Architecture Gap.
- **Product Recommendation:** Develop a guided provisioning screen for parents explaining how to set up fresh devices via Android Management API or provide a companion desktop setup tool.

---

### M05: Remote Lock & Remote Device Wipe

#### 1. Expected Behavior
If a child device is lost or stolen, or during disciplinary intervention, parents should be able to trigger an instant remote screen lock (forcing PIN entry) or execute a factory data wipe from the Parent dashboard.

#### 2. Code Proof of Total Absence
- **Native Device Administrator:**
  - `DeviceAdminReceiver` in Android supports `DevicePolicyManager.lockNow()` and `wipeData()`.
  - Inspection of `NativeBridge.kt`, `GuardianService.kt`, and `ParentControlDeviceAdminReceiver.kt`:
    Neither `lockNow()` nor `wipeData()` is called or referenced anywhere in the codebase.
- **Backend Command Pipeline:**
  - `supabase/functions/device-command/handler.ts`: Supports command types `request_heartbeat`, `sync_policy`, `refresh_location`, and `ping`. Contains **no handlers** for `remote_lock` or `wipe_data`.

#### 3. Real-World Product Impact
Parents cannot remotely secure a misplaced child phone. The only recovery option is unlinking or revoking the device registration from the dashboard, which only severs app sync without securing physical access to the device.

#### 4. Classification & Recommendations
- **Classification:** Missing Security & Device Administration Feature.
- **Product Recommendation:** Add `remote_lock` action to `device-command` Edge Function and expose `devicePolicyManager.lockNow()` in `NativeBridge.kt`.

---

### M06: App Install & Uninstall Monitoring & Alerts

#### 1. Expected Behavior
Parents should receive real-time notifications when a child installs a new application (e.g., an unapproved social media app) or uninstalls existing applications.

#### 2. Code Proof of Total Absence
- **Android Manifest & Broadcast Receivers:**
  - `android/app/src/main/AndroidManifest.xml` registers `BootReceiver` (`BOOT_COMPLETED`) and `ParentControlDeviceAdminReceiver`.
  - It declares **no receiver** with an `intent-filter` for:
    - `android.intent.action.PACKAGE_ADDED`
    - `android.intent.action.PACKAGE_REMOVED`
    - `android.intent.action.PACKAGE_REPLACED`
- **Application Logic:**
  - The app only inspects installed packages during scheduled snapshot syncs via `QUERY_ALL_PACKAGES`. New installations do not trigger events.
  - In `supabase/migrations/20260101000000_core.sql`, `safety_alerts.type` check constraint permits:
    `'geofence_entry'`, `'geofence_exit'`, `'low_battery'`, `'sos_triggered'`, `'tampering_detected'`.
    It contains **no alert type** for `app_installed` or `app_uninstalled`.

#### 3. Real-World Product Impact
A child can download, install, and execute any application from the Play Store or via APK sideloading without the parent receiving an alert. The parent only discovers the new app if they manually refresh the installed apps list.

#### 4. Classification & Recommendations
- **Classification:** Real-Time Device Monitoring Gap.
- **Product Recommendation:** Register a `PackageChangeReceiver` listening to `ACTION_PACKAGE_ADDED` and `ACTION_PACKAGE_REMOVED`, and dispatch an immediate `app_installed` safety alert to the backend.

---

### M07: Multiple-Family Switching & Family Selector

#### 1. Expected Behavior
Modern families often encompass complex dynamics (e.g., blended families, co-parenting households, guardians overseeing grandparents or separate child groups). A single parent identity should be able to create, belong to, and switch between multiple family spaces.

#### 2. Code Proof of Total Absence
- **Client Storage & State:**
  - `lib/data/services/local_settings_service.dart` (lines 8, 38–45): Holds a single `_activeFamilyKey = 'active_family_id'`.
  - `lib/data/services/session_service.dart` (lines 12, 43–45): Holds a single `Rxn<Family> activeFamily`.
- **UI Architecture:**
  - In `lib/features/parent_shell/` and `lib/features/settings/parent_settings_tab.dart`, the UI displays the active family name as static text (`familyName.value = family?.name ?? 'No active family'`). There is **no family picker modal, dropdown, or switch affordance**.

#### 3. Real-World Product Impact
A parent cannot participate in more than one family. If a guardian needs to manage devices across two separate contexts, they must register separate email accounts and repeatedly sign out and sign in.

#### 4. Classification & Recommendations
- **Classification:** Domain Modeling & Account Multi-Tenancy Limitation.
- **Product Recommendation:** Update `FamilyRepository` to fetch `getFamiliesForUser()`, store multiple active memberships in `SessionService`, and provide an App Bar family switcher dropdown.

---

### M08: Accessibility Service & Accessibility-Based Enforcement

#### 1. Expected Behavior
Because full Device Owner provisioning is complex for non-technical parents, parental control apps widely utilize an **Android Accessibility Service** as an effective alternative. An Accessibility Service enables:
- Monitoring currently active window titles and URLs.
- Detecting incognito/private browsing mode in browsers.
- Preventing access to Android System Settings (stopping children from revoking permissions).
- Displaying an instant full-screen blocking overlay over restricted applications.

#### 2. Code Proof of Total Absence
- **Android Manifest:**
  - `android/app/src/main/AndroidManifest.xml` contains **zero declarations** of `<service android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">`.
- **Native Implementation:**
  - An exhaustive search across `android/app/src/main/kotlin/` for `AccessibilityService` confirms **no class** extends `android.accessibilityservice.AccessibilityService`.
  - While `P6-CHD-015` tests an informational screen about accessibility guidance (`PER01`), no functional accessibility service exists in the APK.

#### 3. Real-World Product Impact
Without an Accessibility Service, HAVEN cannot enforce app restrictions on non-Device Owner devices, cannot inspect browser activity, and cannot prevent the child from opening Android Settings and tampering with app permissions.

#### 4. Classification & Recommendations
- **Classification:** Native Android Capability Gap.
- **Product Recommendation:** Implement `HavenAccessibilityService` with `AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED` handling to provide fallback application blocking via system overlays (`TYPE_APPLICATION_OVERLAY`).

---

### M09: Family Lifecycle Management (Transfer Ownership, Delete Family, Leave Family)

#### 1. Expected Behavior
A complete family lifecycle architecture must provide options to:
- Transfer family ownership from the primary parent to another co-parent.
- Delete a family entirely once children reach adulthood.
- Allow secondary parents or guardians to voluntarily leave a family.

#### 2. Code Proof of Total Absence
- **Edge Functions (`family-admin`):**
  - In `supabase/functions/family-admin/index.ts`:
    Supported actions are: `get_family`, `update_retention`, `delete_zone`, `unlink_child`, `remove_member`.
    There are **no actions** for `delete_family`, `transfer_ownership`, or `leave_family`.
- **Database Schema:**
  - `families` table in PostgreSQL has an `owner_id` foreign key. There are no stored procedures or triggers to handle ownership transfer cascades or safe family deletion cascades.
- **UI Screens:**
  - `ParentSettingsPage` provides account deletion for the current user (`A09`), but contains **no UI** to delete the family unit or transfer its ownership.

#### 3. Real-World Product Impact
Families are permanent entities in the database. If a family creator wants to hand over administrative duties to a spouse or dissolve the family, there is no in-app or backend path to accomplish this.

#### 4. Classification & Recommendations
- **Classification:** Backend Lifecycle & Administrative Domain Gap.
- **Product Recommendation:** Add `transfer_ownership` and `delete_family` actions to `family-admin` Edge Function, backed by atomic PostgreSQL transactions that cleanly clean up children, devices, and policies.

---

### M10: Additional Parent / Guardian Invitation (Co-Parenting)

#### 1. Expected Behavior
Both parents should be able to monitor their children independently from their own personal phones and accounts. The family creator should be able to send an invitation (via QR code or invite link) to a spouse or guardian, assigning them the **Parent** role within the family.

#### 2. Code Proof of Total Absence
- **Pairing Architecture (`supabase/functions/pairing/index.ts`):**
  - Action `create_invite` unconditionally creates an invite for a **child**:
    ```typescript
    const invite = await db.from("pairing_requests").insert({
      family_id: familyId,
      parent_user_id: auth.user.id,
      pairing_code: code,
      ...
    });
    ```
  - The pairing engine has **no role parameter** (`role: 'parent' | 'child'`). It only pairs child devices.
- **Registration Flow:**
  - A user who selects "Parent Mode" during registration is forced to create a **brand new family** (`FAM08`). There is no flow to "Join an Existing Family as a Parent".

#### 3. Real-World Product Impact
Co-parenting is unsupported. Both parents must share the single email and password of the family creator to access the dashboard on multiple parent devices, which violates account security best practices.

#### 4. Classification & Recommendations
- **Classification:** User Onboarding & RBAC Collaboration Gap.
- **Product Recommendation:** Extend the pairing service to support `role: 'parent'` invitations, allowing secondary parents to join an existing family with full or customized parental permissions.

---

## 3. Product Impact & Architectural Gap Classification Matrix

| Gap ID | Capability Name | Domain / Subsystem | Architectural Complexity | Security / Safety Severity | Product Priority Recommendation |
|---|---|---|---|---|---|
| **M01** | Website / Content Filtering | Native Network / DNS | High (Local VPN Engine) | High (Child Safety) | P1 — Essential for competitive parity |
| **M02** | Push Notifications (FCM) | Infrastructure / Cloud Messaging | Medium (FCM + Webhooks) | **Critical** (Real-time alerting) | **P0 — Urgent Blocker for Release** |
| **M03** | Password Reset Flow | Auth / Identity Lifecycle | Low (Supabase Auth API) | High (Account Lockout) | **P0 — Urgent Blocker for Release** |
| **M04** | Device Owner Provisioning | Native Android / Deployment | High (Android EMM / Setup) | High (Core Enforcement) | P2 — Guided enterprise setup |
| **M05** | Remote Lock / Wipe | Device Admin / Security | Low (DPM API Call) | Medium (Lost Device Protection) | P2 — Quality of life |
| **M06** | App Install/Uninstall Alerts | Native OS Monitoring | Low (BroadcastReceiver) | High (Parent Awareness) | P1 — High parent value |
| **M07** | Multi-Family Switching | Client State / Domain Model | Medium (UI + Local Storage) | Medium (User Experience) | P3 — Future roadmap |
| **M08** | Accessibility Enforcement | Native Android Accessibility | High (Accessibility Service) | High (Enforcement Alternative)| P1 — Essential fallback for retail APK |
| **M09** | Family Lifecycle Management| Backend Admin / RLS | Medium (Atomic Cascade RPC) | Medium (Data Hygiene) | P2 — Operational requirement |
| **M10** | Co-Parent / Guardian Invites| Pairing / RBAC Engine | Medium (Invitation Flow) | High (Security / Shared Creds) | P1 — Core family expectation |

---

## 4. Engineering & Product Roadmap Recommendations

### Phase 7A: Release-Blocking Functional Additions (Immediate)
1. **Push Notifications (M02):** Implement Firebase Cloud Messaging (FCM) to ensure parents receive background alerts when emergency geofence, SOS, or battery events occur.
2. **Password Reset Flow (M03):** Wire `resetPasswordForEmail` in `LoginPage` and add deep-link handling for password recovery to prevent permanent account lockouts.

### Phase 7B: Core Parental Protection Enhancements (Fast-Follow)
1. **App Install/Uninstall Monitoring (M06):** Add `PackageChangeReceiver` in Android to capture package events in real time.
2. **Accessibility Enforcement Service (M08):** Implement Android Accessibility Service to provide reliable app restriction and settings tampering protection on standard non-Device Owner retail installations.
3. **Co-Parent Invitation Flow (M10):** Update the pairing engine to allow secondary parents to join the family cleanly without credential sharing.

### Phase 7C: Advanced Platform Expansion
1. **Website & Content Filtering (M01):** Build a local DNS filtering `VpnService` with category blacklists.
2. **Remote Device Lock (M05):** Add remote lock capabilities through `DevicePolicyManager`.
3. **Family Lifecycle Expansion (M07, M09):** Enable multi-family switching and clean ownership transfer / dissolution workflows.
