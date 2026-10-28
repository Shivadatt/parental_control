# Integrations setup and on-device verification

Status date: 2026-10-27. Workspace `D:\parentcontrol_app`, hosted project
`hhqgreaoqulmfwfwarhc`, test phone realme RMX2161 (Android 12 / API 31,
`5HXWRGQ4IFU8WS4T`).

**SMTP and FCM are not configured** (no credentials and no code path for FCM);
their sections are plans to be executed later, not observed results. **Usage
Access and location sharing have since been verified on the phone** (see
[verification-report.md](verification-report.md), functional matrix items 19 and
20) and their sections below now record the observed result as well as the
procedure. The evidence labels in
[verification-report.md](verification-report.md) are **NOT CONFIGURED** for SMTP
and FCM, and **PASS — LIVE VERIFIED** for Usage Access and location.

This file is documentation only. No app code, migration, config or device
setting was changed to produce it.

## 0. Status at a glance

| Integration | Status | Why | Unblocking action (owner) | Verification |
|---|---|---|---|---|
| SMTP (confirmation / reset email) | **NOT CONFIGURED** | No provider credentials; `docs/backend.md:20` | Configure custom SMTP in the Supabase dashboard (section 1.2) and keep `parentcontrol://auth-callback` allowlisted | One real sign-up email opened on the phone (section 1.6); `auth.users.email_confirmed_at` set (section 7.3) |
| FCM push | **NOT CONFIGURED** | No Firebase project, no `google-services.json`, no token table, no send code | Create the Firebase Android app, add the Gradle/Dart pieces, store the service account as an Edge secret, **and implement token registration + send** (section 2) | Firebase console test message to a registered parent token; `select count(*) from public.push_tokens` (section 7.3) |
| Usage Access | **PASS — LIVE VERIFIED** | Granted with `appops set … GET_USAGE_STATS allow`; 32 UsageStats rows returned for 24 h and uploaded | (done) keep the grant when re-testing | `adb shell appops get com.parentcontrol.parent_control GET_USAGE_STATS` → `allow`; observed in `integration_test/device_capabilities_test.dart` |
| Location sharing | **PASS — LIVE VERIFIED** | Granted fine/coarse/background location; a real fused fix was returned and tracking started/stopped cleanly | (done) keep the grants when re-testing | `integration_test/device_capabilities_test.dart` printed `LOCATION FIX: source=fused mock=false accuracyM=100.0` |

Detailed unblock/verify commands are repeated in section 5 and collected in
section 7.

## 1. SMTP for Supabase Auth email

### 1.1 What the app already does

| Behaviour | Evidence |
|---|---|
| Redirect target is `parentcontrol://auth-callback` | `lib/core/config/env.dart:13` |
| Sign-up sends `emailRedirectTo` | `lib/data/repositories/supabase_auth_repository.dart:70-75` |
| Resend sends the same redirect | `lib/data/repositories/supabase_auth_repository.dart:99-104` |
| Sign-up without a session goes to the verify screen (confirmation required) | `lib/features/auth/controllers/register_controller.dart:88-96` |
| Android intent filter for the scheme | `android/app/src/main/AndroidManifest.xml:63-72` |
| Verify screen reacts to the SDK's auth-state change (PKCE exchange) | `lib/features/auth/controllers/verify_email_controller.dart:59-66`, `68-84` |
| Manual "I verified" re-check | `lib/features/auth/controllers/verify_email_controller.dart:129-157` |
| Fallback when the link was opened on another device | `lib/features/auth/controllers/verify_email_controller.dart:159-166` |
| Supabase client is initialised with URL + publishable key only | `lib/data/services/supabase_service.dart:28-31` |

`supabase_flutter` 2.18.0 (`pubspec.yaml:38`) uses PKCE by default and runs a
deep-link observer that exchanges any incoming link carrying `code`,
`access_token` or `error`. No extra initialiser option is needed for this
scheme. The PKCE verifier lives in this installation's SharedPreferences, so the
confirmation link must be opened on the phone where sign-up happened; opening it
elsewhere confirms the account server-side but yields no app session, which is
what the fallback at `verify_email_controller.dart:159-166` is for.

**There is no password-reset UI.** A repository-wide search finds no
`resetPasswordForEmail`, no `updateUser(password:)` and no "Forgot password"
entry; `lib/features/auth/login_page.dart:100-150` only has email/password and
sign-in. See 1.7.

### 1.2 Supabase dashboard configuration

Dashboard for project `hhqgreaoqulmfwfwarhc`:

1. **Authentication → Emails → SMTP Settings** (older dashboards: Authentication
   → Settings → SMTP Settings). Turn **Enable custom SMTP** on.
2. Fill the form. All values are supplied by the mail provider; never paste real
   credentials into this repository or a chat.

| Field | Value |
|---|---|
| Host | Provider SMTP host (`smtp.resend.com`, `smtp.sendgrid.net`, `smtp.postmarkapp.com`, …) |
| Port | `465` (implicit TLS) or `587` (STARTTLS). Use 465 or 587; do not rely on port 25 |
| Username | Provider-specific (Resend: literal `resend`; SendGrid: literal `apikey`; Postmark: the server token) |
| Password | Provider API key / server token (a secret) |
| Sender email | `no-reply@<verified-domain>` — must be on a domain verified at the provider |
| Sender name | `Parent Control` |
| Minimum interval | Keep the default (about 60 s). The app already enforces a 60 s resend cooldown (`verify_email_controller.dart:209-220`) |

3. **Authentication → URL Configuration**: Site URL may stay as the current
   development value (`docs/backend.md:16`), but **Redirect URLs** must contain
   exactly `parentcontrol://auth-callback` — lowercase, no trailing slash, no
   query string. A mismatch makes the link open a browser instead of the app.
4. **Authentication → Emails → Templates**: keep the default *Confirm signup*
   and *Reset password* templates. Their `{{ .ConfirmationURL }}` honours the
   `redirect_to` the app sends. Do not replace it with a static URL.
5. **Authentication → Rate Limits**: note the current "email sent" value before
   testing (default is 30 per hour; confirm in the dashboard).
6. Send one test message from the provider console to your own address, then
   check the provider's "delivered" log before testing the app.

### 1.3 Sender and domain verification (minimum viable setup)

The provider must be allowed to send as your domain, or mailbox providers will
spam-folder or reject the message. Publish the exact records the provider shows;
the shapes are:

```text
TXT   @                     "v=spf1 include:<PROVIDER_SPF_INCLUDE> ~all"
TXT   <selector>._domainkey "<PROVIDER_DKIM_PUBLIC_KEY>"
TXT   _dmarc                "v=DMARC1; p=none; rua=mailto:<DMARC_REPORT_ADDRESS>"
```

| Provider | SMTP host / port | Username | Password | Verification minimum | Published free tier |
|---|---|---|---|---|---|
| Resend | `smtp.resend.com` / `465` or `587` | `resend` | `<RESEND_API_KEY>` | Add domain, publish SPF (`include:amazonses.com`) + DKIM (`resend._domainkey`); DMARC recommended | 100/day, 3,000/month |
| SendGrid | `smtp.sendgrid.net` / `587` | `apikey` | `<SENDGRID_API_KEY>` | Authenticate the domain (SPF `include:sendgrid.net`, DKIM CNAMEs) or verify a Single Sender | 100/day |
| Postmark | `smtp.postmarkapp.com` / `587` or `2525` | `<POSTMARK_SERVER_TOKEN>` | `<POSTMARK_SERVER_TOKEN>` | Verify a DKIM domain and Return-Path; transactional only | Trial credits |

The free-tier numbers are the providers' published plans at the time of
writing; confirm them at signup. Provider reputation throttling still applies
to a brand-new domain. Start with a low volume and a warmed-up domain.

### 1.4 Rate limits that will be hit during testing

| Layer | Limit | Where it is enforced |
|---|---|---|
| Supabase Auth email sends | Default 30/hour (confirm the live value) | Authentication → Rate Limits |
| Supabase built-in email service | Test only, heavily throttled, generally restricted to project team addresses; not for real users | Supabase dashboard |
| App resend button | 60 s cooldown | `verify_email_controller.dart:209-220` |
| Provider plan | e.g. Resend 100/day, SendGrid 100/day | Provider dashboard |
| Recipient mailbox | Gmail/Yahoo bulk-sender and spam rules | Recipient side |

The app maps `over_email_send_rate_limit` / HTTP 429 to a "wait a moment"
message (`lib/data/repositories/supabase_auth_repository.dart:234-240`). A 429
during testing is a rate limit, not a broken configuration. Repeated sign-ups
also create real `auth.users` rows; use a dedicated test mailbox and delete the
test accounts afterwards.

### 1.5 Redirect allowlist (exact value)

```text
parentcontrol://auth-callback
```

Also present in `supabase/config.toml` (`additional_redirect_urls`) for local
CLI use, in `env.dart:13`, and in the manifest. All four must agree. If the
allowlist is wrong, Supabase silently falls back to the Site URL and the email
link opens `http://localhost:3000` in a browser.

### 1.6 End-to-end test script

Preconditions: custom SMTP saved, domain verified, redirect allowlist contains
the scheme, "Confirm email" still ON (`docs/backend.md:16`), the app installed
on the phone with the hosted build.

| # | Step | Expected result | Current state |
|---|---|---|---|
| 1 | Register in the app with a fresh address (`Register` screen: name, email, password, confirm) | No session is created; the app opens the **Verify your email** screen; no role is assigned (`register_controller.dart:88-96`) | The screen is reached, but with no custom SMTP no real confirmation message is expected (the built-in service is throttled and restricted) |
| 2 | Receive the email | Arrives at the test mailbox from the configured sender; SPF/DKIM pass; link host is `hhqgreaoqulmfwfwarhc.supabase.co` and contains `redirect_to=parentcontrol%3A%2F%2Fauth-callback` | **BLOCKED** — no SMTP provider |
| 3 | Open the link on the phone | Android opens Parent Control (`singleTop`, manifest `launchMode`); `adb shell dumpsys activity activities \| grep -i parentcontrol` shows `MainActivity` resumed; the SDK exchanges the PKCE `code`; the verify screen navigates to role selection (`verify_email_controller.dart:63-65`) | **BLOCKED** — depends on step 2 |
| 4 | "Set password" | Not a separate step in this app: the password is chosen during registration (`register_page.dart`). The equivalent post-email password change exists only as the reset flow, which is missing (1.7) | **BLOCKED at the app layer** |
| 5 | Sign in with the confirmed address and the chosen password | Sign-in succeeds; a server-derived destination is opened (`auth_session_flow.dart:35-81`). If the account is still unconfirmed the app shows the `email_not_confirmed` message (`supabase_auth_repository.dart:188-194`) | Testable today with the dashboard-confirmed QA accounts only |
| 6 | Sign-up with the link opened on a desktop browser | The account is confirmed server-side, but the custom scheme cannot open on desktop; the app's "Already verified? Sign in" fallback is the supported path | Not testable without SMTP |

Optional routing smoke test (does not prove email): with the app installed,
`adb -s 5HXWRGQ4IFU8WS4T shell am start -a android.intent.action.VIEW -d "parentcontrol://auth-callback?code=invalid"`.
Expected: the app comes to the front and the exchange fails without a crash.
This must never be recorded as email verification.

**Current truth:** the confirmation round-trip is **untestable without SMTP**.
The four QA accounts in the hosted project were confirmed manually through the
dashboard (`docs/backend.md:16`, `docs/backend.md:527-529`), so sign-in is
verified but the email step is not.

### 1.7 Password reset — expected vs blocked

| Step | Expected with SMTP | Actual |
|---|---|---|
| Request reset from the app | A "Forgot password?" action calls `resetPasswordForEmail(email, redirectTo: 'parentcontrol://auth-callback')` | **No such call and no screen** — repo search finds no `resetPasswordForEmail`/`updateUser` |
| Receive the reset email | Reset template is delivered | Could only be triggered by a manual Auth API call |
| Open the deep link | Recovery session established in this installation | Even a manual API call cannot complete: no PKCE verifier exists in the app, so the SDK exchange fails |
| Choose a new password | A screen calls `updateUser(password:)` | Does not exist |

So reset is **blocked at the app layer, not only at SMTP**. Do not configure
SMTP and then claim password reset works. Fixing it requires a reset request
screen, a recovery deep-link route, and a new-password screen — out of scope for
this documentation task.

## 2. FCM push for safety alerts

### 2.1 What exists today

| Fact | Evidence |
|---|---|
| No Firebase Dart dependency | `pubspec.yaml:30-47` |
| No Firebase initialisation | `lib/main.dart:13-33` |
| No Google Services Gradle plugin | `android/settings.gradle.kts:20-24`, `android/app/build.gradle.kts:1-5` |
| No `google-services.json` | absent on disk; ignored by `.gitignore:10` |
| `POST_NOTIFICATIONS` is declared (needed for FCM display on Android 13+) | `android/app/src/main/AndroidManifest.xml:11` |
| No Firebase messaging service, no notification-display code | `AndroidManifest.xml:75-105` declares only guardian, location, admin and boot receivers |
| Alerts are created server-side | `supabase/functions/device-telemetry/index.ts:121-148` (low battery), `:277-351` (geofence) |
| Parents receive alerts only through private Realtime while the app is open | `lib/data/repositories/supabase_alert_repository.dart:60-111`, `lib/features/safety_alerts/safety_alerts_controller.dart:78-93` |
| A local notification toggle exists but only stores a SharedPreferences flag | `lib/data/services/local_settings_service.dart:54-56`, `lib/features/settings/settings_body.dart:110-128` |
| Alerts target parents, but `devices` rows belong to child phones | `supabase/migrations/20260101000000_core.sql:79-114` (requires `child_user_id`) |

The parent settings screen is honest about this: the toggle is labelled local
only and says alerts are still recorded server-side
(`lib/features/settings/settings_body.dart:110-118`). No delivery claim is made.

### 2.2 Create and authorise the Firebase Android app

1. Firebase console → **Add project** (or reuse an owner project). Do not
   attach it to the Supabase project.
2. **Add app → Android**, package name **`com.parentcontrol.parent_control`**
   (must equal `applicationId` in `android/app/build.gradle.kts:19`). Give it a
   nickname; the Android nickname is not security-relevant.
3. Register SHA-1 (and SHA-256) fingerprints. Get the debug fingerprint with
   `cd android && ./gradlew signingReport`; the current release build type signs
   with the debug keystore (`android/app/build.gradle.kts:28-34`), so the
   fingerprint will change when a production key is added. Fingerprints are
   required for some Firebase features and for restricting the API key.
4. Download **`google-services.json`** and place it at
   `android/app/google-services.json`.
5. In Google Cloud console → APIs & Services → Credentials, restrict the
   Firebase Android API key to package `com.parentcontrol.parent_control` plus
   the SHA-1s. The key is not a server secret, but an unrestricted key is
   unnecessary exposure.

Note: `.gitignore:10-11` already ignores `google-services.json` and
`firebase_options.dart`. A fresh clone therefore cannot build once the Gradle
plugin is added (the Google Services plugin fails the build when the file is
missing). Decide explicitly: commit the file, or inject it in the build
pipeline. Either way, provide it on the build machine before enabling the
plugin.

### 2.3 Gradle requirements

Not applied today. When applied:

- `android/settings.gradle.kts` plugins block (currently lines 20-24): add
  `id("com.google.gms.google-services") version "<VERSION_COMPATIBLE_WITH_AGP_9.0.1>" apply false`.
  The `google()` repository is already declared (`settings.gradle.kts:13-17`).
- `android/app/build.gradle.kts` plugins block (lines 1-5): add
  `id("com.google.gms.google-services")`.

Pin a plugin version that supports the project's AGP 9.0.1 / Kotlin 2.3.20
(`settings.gradle.kts:22-23`); verify the plugin's compatibility notes rather
than guessing. Adding the plugin without `google-services.json` breaks
`flutter build`.

### 2.4 Dart side

Also not present. Minimum additions (do not add them as part of this doc):

- `pubspec.yaml`: `firebase_core`, `firebase_messaging`.
- `lib/main.dart`: `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
  before `runApp` (or run `flutterfire configure`, which writes the
  gitignored `lib/firebase_options.dart`).
- A new service, e.g. `lib/data/services/push_service.dart`, that:
  - requests notification permission (the native path already exists:
    `DeviceAdminService.requestPermissions(notifications: true)` →
    `NativeBridge.kt:348-383`),
  - calls `FirebaseMessaging.instance.getToken()` and registers it,
  - subscribes to `onTokenRefresh` and re-registers,
  - handles foreground messages (FCM does not display notifications while the
    app is foregrounded unless the app shows them).
- Android 13+ needs the runtime `POST_NOTIFICATIONS` grant; it is already
  declared and requested for the guardian/location services.

### 2.5 OAuth service account for HTTP v1

FCM legacy server keys are retired; use HTTP v1 with a service account.

1. Firebase console → **Project settings → Service accounts → Generate new
   private key**. A JSON file downloads. **This JSON is a secret.**
2. Store it as an Edge Function secret through the dashboard: **Project
   Settings → Edge Functions → Secrets → Add new secret**, name
   `FIREBASE_SERVICE_ACCOUNT_JSON`, value = the entire JSON. The CLI equivalent
   is `supabase secrets set --env-file firebase.secrets.env` with a gitignored
   `*.secrets.env` file (`docs/backend.md:155-169`, BUG-020). Never pass the
   JSON as a command-line argument and never place it in `docs/`, the APK, or
   `google-services.json`.
3. Add `FIREBASE_PROJECT_ID` (the Firebase project id, not the Supabase ref) as
   a second secret, or read `project_id` from the JSON.
4. Token acquisition: sign a JWT with the service account private key and
   exchange it at `https://oauth2.googleapis.com/token` with scope
   `https://www.googleapis.com/auth/firebase.messaging`, or use
   `npm:google-auth-library`'s `JWT`/`GoogleAuth` inside the Edge Function.
   Cache the access token for about 55 minutes.
5. Send:

```text
POST https://fcm.googleapis.com/v1/projects/<FIREBASE_PROJECT_ID>/messages:send
Authorization: Bearer <OAUTH2_ACCESS_TOKEN>
Content-Type: application/json

{
  "message": {
    "token": "<PARENT_DEVICE_TOKEN>",
    "notification": { "title": "Safety alert", "body": "<ALERT_MESSAGE>" },
    "data": { "alert_id": "<ALERT_UUID>", "family_id": "<FAMILY_UUID>" },
    "android": { "priority": "high", "notification": { "channel_id": "safety_alerts" } }
  }
}
```

Use the notification payload for display when the app is backgrounded; a
data-only message needs a background handler in the app. The
`safety_alerts` channel in the example does not exist yet: either create it in
the app (or the Android FCM service) or omit `channel_id` and let FCM use its
fallback channel.

### 2.6 Device token registration — the code gap

There is no token registration anywhere. `device-register` accepts only
`register` (`supabase/functions/device-register/index.ts:111-116`), no migration
creates a token table, and no Dart code calls `getToken`. Exact additions:

| # | File / function to add | Why |
|---|---|---|
| 1 | New migration `supabase/migrations/<timestamp>_push_tokens.sql`: `public.push_tokens(id uuid pk, user_id uuid references profiles(id) on delete cascade, token text unique, platform text, app_version text, created_at, last_seen_at, revoked_at)`, RLS enabled, **no** client grants/policies (service-role only) | `devices` is child-only (`core.sql:79-114`); alerts go to parents, so tokens must be keyed by `user_id` |
| 2 | New Edge Function `supabase/functions/push-register/index.ts` (`verify_jwt = true`) with actions `register` / `unregister`, calling `requireUser(..., { requireVerifiedEmail: true })`, validating token length, upserting on `token`, and auditing `push_token_registered` | Device-authenticated paths cannot represent a parent phone |
| 3 | Optionally an action in `supabase/functions/device-register/index.ts` for child-device tokens (child alerts are not currently sent) | Same pattern, `x-device-id` + `x-device-secret` |
| 4 | New `lib/data/services/push_service.dart` + call after sign-in and after `SupabaseService.init` (`lib/main.dart:13-33`); register in `ChildShellController._resumeBackgroundWork` only if child pushes are wanted (`child_shell_controller.dart:438-487`) | Get/refresh the FCM token and call the function |
| 5 | New send helper, e.g. `supabase/functions/_shared/fcm.ts`, invoked after each alert insert in `supabase/functions/device-telemetry/index.ts:138` and `:349` | Actually deliver the alert |
| 6 | Unregister on sign-out (`verify_email_controller.dart:168-207`) and on device revoke | Stop sending to a stale token |

Also note: `safety_alerts.type` allows `app_blocked` and `permission_missing`
(`core.sql:297-311`), but no code inserts those types; only low battery and
geofence transitions create alerts today. A push test can therefore only use
those two triggers unless more alert creation is added.

### 2.7 How alerts would be delivered

1. The child phone uploads telemetry; `device-telemetry` inserts a
   `safety_alerts` row (low battery / geofence).
2. The new send helper looks up active `push_tokens` for every parent of
   `family_id` (join `family_members` where `role = 'parent'` and
   `status = 'active'`, `core.sql:55-66`).
3. One HTTP v1 request per token; delete or `revoked_at` tokens that return
   `UNREGISTERED`/`INVALID_ARGUMENT`.
4. The parent phone displays the notification; tapping it opens the alerts
   screen, which already reads `safety_alerts` through RLS
   (`supabase_alert_repository.dart:25-57`).

Realtime remains the in-app path when the parent app is open; FCM covers the
closed-app case. Neither is verified.

### 2.8 FCM verification plan (future)

1. Firebase console → Cloud Messaging → **Send test message**, paste the token
   shown by the app's debug-only registration path. Expected: notification when
   the app is backgrounded; no duplicate when foregrounded (app handles it).
2. Trigger an alert without inventing data: create a safe zone far from the
   phone (`Safe zones`), then let one location fix arrive; the geofence exit
   creates the row. Expected: `safety_alerts` row plus one push per parent
   token.
3. Check `select count(*) from public.push_tokens where revoked_at is null;` and
   the function logs (error codes only; no token values in logs).

Do not claim FCM works until a real message is observed.

## 3. Usage Access

**Observed result (2026-10-27).** After granting with `appops set … GET_USAGE_STATS
allow` on the RMX2161, `integration_test/device_capabilities_test.dart` reported
`USAGE ROWS (24h): 32`, all with non-empty package names, and the guardian
service uploaded the app/usage cycle. Status is **PASS — LIVE VERIFIED**. The
sections below remain the procedure and rationale.

### 3.1 What the code does

| Behaviour | Evidence |
|---|---|
| Detection via AppOps `OPSTR_GET_USAGE_STATS` (API 29+ `unsafeCheckOpNoThrow`) | `android/app/src/main/kotlin/.../NativePermissions.kt:34-55` |
| Declared but not granted by manifest (correct) | `AndroidManifest.xml:16-20` |
| Reported as a capability | `NativeBridge.kt:140-146` |
| Included in the heartbeat as `usage_access_granted` | `GuardianService.kt:365-394`, stored at `device-telemetry/index.ts:96-111` |
| Settings shortcut opens the usage-access list (no package extra) | `NativeBridge.kt:324-331` |
| Query returns real `UsageStatsManager` data only, or throws | `UsageReporter.kt:16-97` |
| Upload refuses to fabricate when denied | `GuardianService.kt:424-428` |
| Parent-side labels and warning | `lib/features/devices/device_detail_page.dart:286-289`, `lib/features/devices/device_presentation.dart:47-56`, `lib/features/screen_time/screen_time_controller.dart:52-53,155-165`, `screen_time_page.dart:81-93` |

### 3.2 Exact on-device grant path (Android 12 / realme RMX2161)

Use this app only; the toggle is per-package and changes nothing for other
apps.

1. Child phone → **Settings → Apps → Special app access → Usage access**.
   On realme UI 3.x the path is usually
   **Settings → Apps → Special app access → Usage access**; if it is not there,
   try **Settings → Privacy → Special app access → Usage access**.
2. Tap **Parent Control**.
3. Choose **Permit usage tracking** / **Allow**.
4. Return to the app. In the child shell open **Settings → Android permissions**
   and tap the refresh icon (top right). The **Usage access** tile must read
   granted and lose its "Open settings" action
   (`lib/features/child/tabs/child_settings_tab.dart:134-140`).

The in-app **Open settings** button opens the same list
(`NativeBridge.kt:324-331`); if the OEM activity is missing, the code falls
back to the app details page.

The app does **not** observe lifecycle resume (no `WidgetsBindingObserver`
anywhere under `lib/`), so the tile stays stale until the refresh icon is
tapped or the shell reloads. Expect "not granted" immediately after returning
from Settings; that is a UI-refresh gap, not a failed grant.

### 3.3 Test-only adb grant

```bash
adb -s 5HXWRGQ4IFU8WS4T shell appops set com.parentcontrol.parent_control GET_USAGE_STATS allow
adb -s 5HXWRGQ4IFU8WS4T shell appops get com.parentcontrol.parent_control GET_USAGE_STATS
# expected: GET_USAGE_STATS: allow
```

Revoke for a clean test:

```bash
adb -s 5HXWRGQ4IFU8WS4T shell appops set com.parentcontrol.parent_control GET_USAGE_STATS default
```

`appops` affects only this package. It is a test shortcut, not a setup the app
may rely on; the shipped flow must use the Settings screen.

### 3.4 What the app does after a grant

1. **Capabilities**: the child shell re-reads AppOps only when refreshed; the
   guardian heartbeat reports `usage_access_granted` at most every 5 minutes
   (`GuardianService.kt:39,214-216`), which updates
   `devices.usage_access_granted` server-side.
2. **Upload timing**: usage is uploaded at most hourly
   (`GuardianService.kt:41,220-222`) and only when a query returns rows. The
   in-memory `lastUsageUploadAt` starts at 0 on service start, so a service
   start uploads immediately.
3. **Force an upload without waiting**: parent → device → **App restrictions →
   Request device sync**. That creates a `sync_policy` command
   (`lib/features/app_restrictions/app_restrictions_controller.dart:430-450`);
   the child polls within about 20 s (`GuardianService.kt:37`) and runs
   `uploadApps` + `uploadUsage` in the same command
   (`GuardianService.kt:283-298`). The parent Screen time banner points to the
   same action (`screen_time_page.dart:89-91`).
4. **Failure state**: with the grant missing, the service stores
   "Usage Access is not granted; usage cannot be uploaded."
   (`GuardianService.kt:424-428`), the parent Screen time screen shows "No usage
   numbers available" (`screen_time_page.dart:81-93`), and no numbers are
   invented.

Expected parent UI after a successful grant + sync: Screen time rows with app
labels and durations, a last-upload timestamp, and no permission banner; device
detail shows Usage access granted.

### 3.5 What is uploaded, and retention

Uploaded per row: `day` (local date), `package_name`, `app_label`, `total_ms`
(foreground time), optional `last_used_at` (`GuardianService.kt:436-446`).
Window: from the start of yesterday to now, at most 500 rows per upload
(`GuardianService.kt:429-433`). No content, keystrokes, URLs, screenshots or
per-session timelines are collected. Server: `public.usage_daily`, unique on
`(device_id, day, package_name)`, upserted (`device-telemetry/index.ts:157-237`,
`core.sql:228-246`).

Retention: default 90 days in `families.settings`
(`core.sql:38`); purge is **manual** via `family-admin` action `purge_data`,
which refuses to delete inside the retention window
(`supabase/functions/family-admin/index.ts:27-42,125-195`). No cron job purges
usage (`supabase/functions/cron/index.ts:39-65` only expires sessions and
detects offline devices), so the default is a policy, not an automatic
deletion.

### 3.6 Sensitivity

Usage Access is a special access that reveals every app the child opens. It is
granted by the device user, is visible in Android Settings, and applies only to
this package. The app must keep the disclosure it already shows
(`child_settings_tab.dart:64-73`) and must not claim usage data when denied.

## 4. Location sharing

**Observed result (2026-10-27).** After granting fine/coarse/background location
on the RMX2161, `integration_test/device_capabilities_test.dart` started tracking,
read a real fused fix (`LOCATION FIX: source=fused mock=false accuracyM=100.0`,
non-null and not `(0,0)`) and stopped tracking cleanly. Status is **PASS — LIVE
VERIFIED**. Sections below remain the procedure and rationale.

### 4.1 Permission flow as implemented

1. Child toggles **Home → Location sharing**
   (`lib/features/child/tabs/child_home_tab.dart:318-367`).
2. `setLocationSharing(true)` requests **fine + coarse location** and
   **notifications**, then re-reads capabilities
   (`child_shell_controller.dart:715-790`, `NativeBridge.kt:348-383`).
3. Fine location and notifications are hard requirements; without them the
   switch does not turn on and an explicit error is shown
   (`child_shell_controller.dart:746-761`).
4. On success it stores a local preference and starts
   `LocationTrackingService` with a 60 s interval
   (`child_shell_controller.dart:762-776`, `LocationTrackingService.kt:41-50`).
5. The service refuses to run without fine location or notifications and shows
   a persistent notification while active
   (`LocationTrackingService.kt:62-81,206-253`, strings
   `location_notification_title` / `location_notification_text`).
6. The guardian uploads each new non-mock fix on its next 10 s tick
   (`GuardianService.kt:223,458-491`).

**Background location is never requested by code.** The Dart API exposes a
`backgroundLocation` flag (`lib/data/services/device_admin_service.dart:131-147`),
but `NativeBridge.requestPermissions` ignores it
(`NativeBridge.kt:348-383`), and no caller passes `true`. The
`ACCESS_BACKGROUND_LOCATION` entry in the manifest
(`AndroidManifest.xml:8`) is therefore only ever granted manually. The
"Open settings" action opens the app details page
(`NativeBridge.kt:333-346`), not the location permission page, so the user
must navigate: **App info → Permissions → Location → Allow all the time**.
The app shows a warning when background location is missing
(`child_shell_controller.dart:777-781`), which is honest: the visible foreground
service does not depend on it while it is running.

Additional behaviour worth knowing:

- Mock fixes are dropped with a throttled warning and never uploaded
  (`GuardianService.kt:462-470`); the service also flags `isMock` in the UI
  event stream (`LocationTrackingService.kt:171-186`).
- `LiveState` is process memory (`LiveState.kt:24-40`); if the process dies,
  tracking state is lost until the child reopens the app
  (`child_shell_controller.dart:438-487`).
- `BootReceiver` restarts only the guardian, not location tracking
  (`BootReceiver.kt:17-52`). After a reboot, sharing may be "on" in
  preferences while the service is not running until the child opens the app.
- `request_location` is a valid command type (`_shared/policy.ts:38-45`) and the
  guardian can answer it (`GuardianService.kt:308-321`), but **no parent UI
  creates it**; a parent cannot currently ask for an on-demand fix. Normal
  sharing uploads automatically while the switch is on.

### 4.2 `ACCESS_BACKGROUND_LOCATION` Play policy caveat

- Declaring the permission is not enough; Google Play requires a **Permissions
  Declaration Form** and a prominent in-app disclosure for background location.
  Approval is limited to apps whose core functionality needs it; a parental
  control app can qualify, but the reviewer must be able to see the disclosure
  and the visible service.
- The manifest also declares `QUERY_ALL_PACKAGES`
  (`AndroidManifest.xml:21-26`), which has its own declaration and is likewise
  restricted. Both must be justified before any Play release; the current
  builds are side-loaded test builds only (`docs/verification-report.md:163-167`).
- Usage Access (`PACKAGE_USAGE_STATS`) is a special access that Play also
  scrutinises; treat the three as one policy review item.
- On Android 14+, a location foreground service must be started while the app
  is visible and needs the `FOREGROUND_SERVICE_LOCATION` permission; both are
  already satisfied (`AndroidManifest.xml:12-14`,
  `LocationTrackingService.kt:242-253`). Starting the service from the
  background is not supported by this app anyway.
- Only this app is affected: the grant and the service are package-scoped and
  visible in the notification shade. Nothing else on the phone is monitored.

### 4.3 Test-only adb grants

```bash
adb -s 5HXWRGQ4IFU8WS4T shell pm grant com.parentcontrol.parent_control android.permission.ACCESS_FINE_LOCATION
adb -s 5HXWRGQ4IFU8WS4T shell pm grant com.parentcontrol.parent_control android.permission.ACCESS_COARSE_LOCATION
adb -s 5HXWRGQ4IFU8WS4T shell pm grant com.parentcontrol.parent_control android.permission.POST_NOTIFICATIONS
adb -s 5HXWRGQ4IFU8WS4T shell pm grant com.parentcontrol.parent_control android.permission.ACCESS_BACKGROUND_LOCATION
adb -s 5HXWRGQ4IFU8WS4T shell dumpsys package com.parentcontrol.parent_control | grep -E "ACCESS_(FINE|COARSE|BACKGROUND)_LOCATION|POST_NOTIFICATIONS"
```

Grant background location only after fine location; otherwise Android rejects
it. These grants bypass the app's own dialogs, so the switch can be flipped
without a prompt — that is acceptable for a test device and must not be
described as the user flow.

### 4.4 Starting sharing from the child UI

1. Sign in as the linked child and open the **Home** tab.
2. In the **Location sharing** card, tap the switch.
3. Accept the system dialogs (precise location, then notifications) if adb did
   not grant them.
4. Expect the banner "Location sharing is on…"; the persistent notification
   **"Location sharing is on"** appears in the shade.
5. Optional: grant background location via the child **Settings → Android
   permissions → Background location → Open settings**, then App info →
   Permissions → Location → **Allow all the time**, and refresh the tile.

Do not start it as part of this audit. The instruction above is for the later
run.

### 4.5 Expected server rows

Each accepted fix inserts one `location_events` row: `device_id`, `family_id`,
`lat`, `lng`, `accuracy_m`, `recorded_at`, `received_at`, `source`
(`core.sql:251-267`, `device-telemetry/index.ts:239-276`). Expected cadence is
about one row per minute while sharing is on. The server then evaluates active
safe zones and can insert `geofence_enter` / `geofence_exit` alerts
(`device-telemetry/index.ts:277-352`).

Parent reads: `fetchLatestLocation` and `fetchHistory` (500-row cap,
`supabase_location_repository.dart:26-68`); the Location screen does not
subscribe to Realtime, so tap refresh to see the newest fix
(`lib/features/location/location_controller.dart:61-116`). A fix older than
10 minutes is labelled **STALE** (`location_page.dart:281-305`).

Retention: default 30 days (`core.sql:38`), manual purge via `purge_data`
(`family-admin/index.ts:125-195`). No automatic purge job exists.

### 4.6 Stopping and clearing

- Child **Home → Location sharing** switch off: stops the service, clears the
  warning, writes the preference off (`child_shell_controller.dart:792-815`).
- Sign-out and **Unlink this phone** both call `_stopNativeServices`, which turns
  the preference off and stops the location and guardian services
  (`child_shell_controller.dart:254-266`, sign-out at `871-880`, unlink at
  `838-846`).
- `clearBackgroundSync` also stops the location service
  (`NativeBridge.kt:288-303`).
- `adb shell am stopservice -n com.parentcontrol.parent_control/.LocationTrackingService`
  stops the service for a test but leaves the stored preference on; the next
  child-shell load will start it again. Prefer the switch.
- Existing rows are not deleted by turning sharing off. Deletion requires
  `purge_data` after the retention window, or an owner-run scoped SQL delete in
  the dashboard. Neither was performed.

## 5. Status table (exact unblocking action and verification)

| Area | Status | Exact unblocking action | Verification command / evidence |
|---|---|---|---|
| SMTP | **NOT CONFIGURED** | Dashboard → Authentication → Emails → SMTP Settings: enable custom SMTP, fill host/port/username/password/sender from a verified provider domain; keep `parentcontrol://auth-callback` in Authentication → URL Configuration → Redirect URLs; send one test message from the provider | Send a real sign-up; then in the dashboard SQL editor `select email, email_confirmed_at from auth.users where email = '<TEST_EMAIL>';` and Authentication → Logs for `user_confirmed`. No SMTP ⇒ no confirmation email can arrive |
| FCM | **NOT CONFIGURED** (and code absent) | Create Firebase Android app `com.parentcontrol.parent_control`; add `android/app/google-services.json`; add the Google Services Gradle plugin; add `firebase_core`/`firebase_messaging` + init; store the service account JSON as Edge secret `FIREBASE_SERVICE_ACCOUNT_JSON`; implement `push_tokens` + `push-register` + the send helper (section 2.6) | Firebase console "Send test message" to a registered token; `select count(*) from public.push_tokens where revoked_at is null;`; provider/FCM response 200 in function logs |
| Usage Access | **PASS — LIVE VERIFIED** | On the test phone, grant in Android Settings or with the test-only `adb -s 5HXWRGQ4IFU8WS4T shell appops set com.parentcontrol.parent_control GET_USAGE_STATS allow`. Verified 2026-10-27: 32 UsageStats rows returned for the last 24 h and uploaded | `adb -s 5HXWRGQ4IFU8WS4T shell appops get com.parentcontrol.parent_control GET_USAGE_STATS` → `GET_USAGE_STATS: allow`; `integration_test/device_capabilities_test.dart` printed `USAGE ROWS (24h): 32` |
| Location | **PASS — LIVE VERIFIED** | On the test phone, grant fine/coarse (+ optionally background) location, then start tracking. Verified 2026-10-27: a real fused fix was returned and tracking started/stopped cleanly (location upload path also verified via the harness) | `integration_test/device_capabilities_test.dart` printed `LOCATION FIX: source=fused mock=false accuracyM=100.0`; `select count(*), max(recorded_at) from public.location_events where device_id = '<DEVICE_ID>';` for the upload path |

## 6. Privacy

- **No secrets in the APK.** Only `SUPABASE_URL` and the publishable key are
  compiled in (`env.dart:15-16`); the configuration guard rejects
  `sb_secret_`/service-role JWTs (`env.dart:51-55`). The hosted APK scan found
  no service-role key, database URL/password, TURN or cron secret
  (`docs/verification-report.md:287-314`). An FCM service-account JSON must
  stay in Edge secrets; `google-services.json` may be shipped but its API key
  must be restricted to the package and signing fingerprints.
- **Service account / SMTP password handling.** Never commit, never paste into
  this document, never pass as a CLI argument (BUG-020 precedent,
  `docs/backend.md:155-169`). `secrets.env`, `*.secrets.env`,
  `google-services.json` and `firebase_options.dart` are already gitignored
  (`.gitignore:1-11`).
- **Minimal retention.** Usage is daily per-app aggregates, 90-day default;
  location is one row per fix, 30-day default; both purged only by an explicit
  parent `purge_data` (`family-admin/index.ts:27-42,125-195`). Safety alerts
  have no purge path and are only removed with the family/device cascade
  (`core.sql:297-311`) — a known retention gap, not a claim of automatic
  cleanup.
- **No covert collection.** Both background services are foreground services
  with persistent, user-visible notifications
  (`GuardianService.kt:25-32,606-617`; `LocationTrackingService.kt:23-29`);
  location is off by default and child-controlled
  (`child_home_tab.dart:322-345`); mock fixes are refused
  (`GuardianService.kt:462-470`); there is no recording, screenshot, keylogging
  or MediaProjection code (`docs/verification-report.md:39-40`, bug-report
  "Screen recording" section).
- **Scope.** Every permission discussed here is per-package and visible in
  Android Settings; nothing changes other apps on the phone. Device Owner
  suspension remains blocked and is not attempted.

## 7. Command reference for the later run

Nothing below was executed for this document.

### 7.1 Build / install (if a new build is needed)

```bash
fvm flutter build apk --debug --dart-define-from-file=.tools/live_config.env
adb -s 5HXWRGQ4IFU8WS4T install -r build/app/outputs/flutter-apk/app-debug.apk
```

`.tools/live_config.env` is gitignored and holds the hosted URL and publishable
key; do not print it. The recorded build command is in
`docs/verification-report.md:133-141`.

### 7.2 Device grants and runtime checks

```bash
# Usage Access (test shortcut)
adb -s 5HXWRGQ4IFU8WS4T shell appops set com.parentcontrol.parent_control GET_USAGE_STATS allow
adb -s 5HXWRGQ4IFU8WS4T shell appops get com.parentcontrol.parent_control GET_USAGE_STATS

# Location + notifications (test shortcut)
adb -s 5HXWRGQ4IFU8WS4T shell pm grant com.parentcontrol.parent_control android.permission.ACCESS_FINE_LOCATION
adb -s 5HXWRGQ4IFU8WS4T shell pm grant com.parentcontrol.parent_control android.permission.ACCESS_COARSE_LOCATION
adb -s 5HXWRGQ4IFU8WS4T shell pm grant com.parentcontrol.parent_control android.permission.POST_NOTIFICATIONS
adb -s 5HXWRGQ4IFU8WS4T shell pm grant com.parentcontrol.parent_control android.permission.ACCESS_BACKGROUND_LOCATION
adb -s 5HXWRGQ4IFU8WS4T shell dumpsys package com.parentcontrol.parent_control | grep -E "ACCESS_(FINE|COARSE|BACKGROUND)_LOCATION|POST_NOTIFICATIONS"

# Are the visible services actually running?
adb -s 5HXWRGQ4IFU8WS4T shell dumpsys activity services com.parentcontrol.parent_control | grep -E "GuardianService|LocationTrackingService|isForeground"

# Which screen is in front (deep-link / navigation checks)
adb -s 5HXWRGQ4IFU8WS4T shell dumpsys activity activities | grep -i parentcontrol
```

After a grant, the app must be told to re-read it: child **Settings → refresh
icon** (no lifecycle observer exists), and the guardian heartbeat reports
capabilities within 5 minutes.

### 7.3 Server checks (Supabase dashboard SQL editor, owner only)

```sql
-- Substitute the real device id and test email; never paste keys here.
select id, display_name, usage_access_granted, location_granted,
       background_location_granted, notifications_granted, last_seen_at
from public.devices
order by created_at desc;

select device_id, day, count(*) as apps, sum(total_ms) as total_ms,
       max(uploaded_at) as last_upload
from public.usage_daily
group by device_id, day
order by day desc
limit 5;

select count(*) as fixes, max(recorded_at) as newest, max(received_at) as last_received
from public.location_events
where device_id = '<DEVICE_ID>';

select type, message, created_at, acknowledged_at
from public.safety_alerts
order by created_at desc
limit 10;

select email, email_confirmed_at, last_sign_in_at
from auth.users
where email = '<TEST_EMAIL>';
```

`auth.users` is dashboard-only; do not expose it through the app.

### 7.4 Parent-side checks (no commands)

- Device detail → permission tiles: Usage access, Location, Background location,
  Notifications.
- **App restrictions → Request device sync** forces the child to poll and
  upload apps + usage within about 20 s, if the guardian is running.
- **Screen time**: rows and last-upload time; no banner when the grant is
  present.
- **Location**: latest fix, STALE badge if older than 10 minutes, 24 h/7 d
  history; **Safety alerts**: list plus acknowledgement.
