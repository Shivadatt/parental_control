# IA / UI-UX / design-system findings (subagent 2)

## 1. Scope actually covered (files/dirs read; anything skipped and why)

Read at source level (no app execution, no sign-in, no device state changes):

- Routing: `lib/app/routes/app_routes.dart`, `lib/app/routes/app_pages.dart`, `lib/app/app.dart`, `lib/main.dart`
- Parent shell + tabs: `lib/features/parent_shell/parent_shell_page.dart`, `lib/features/dashboard/parent_dashboard_tab.dart`, `lib/features/devices/parent_devices_tab.dart`, `lib/features/safety_alerts/parent_alerts_tab.dart`, `lib/features/safety_alerts/alerts_body.dart`, `lib/features/settings/parent_settings_tab.dart`, `lib/features/settings/settings_body.dart`
- Parent feature screens: `lib/features/devices/device_detail_page.dart` (+ rest listed in §2)
- Child shell + tabs: `lib/features/child/child_shell_page.dart`, `lib/features/child/tabs/*.dart`
- Design system: `lib/core/theme/app_theme.dart`, `lib/core/widgets/*.dart`
- Screenshots: **no new screenshots taken** (no app launch, no sign-in). Two pre-existing
  stage-8 captures were read as visual evidence: `docs/evidence/stage8/e2-parent-remote-assistance.png`
  and `docs/evidence/stage8/emu-02-parent-signin.png`.

Numbers in this file are line-verified against the files as read on 2026-10-30.

## 2. Findings

### 2.1 Route table (source of truth)

`AppRoutes` declares 26 route constants (`lib/app/routes/app_routes.dart:4-31`) and `AppPages.routes`
registers exactly one `GetPage` per constant (`lib/app/routes/app_pages.dart:56-186`). `/parent` and
`/child` each host four tabs inside a single route rather than one route per tab (see tree). Two distinct shells exist — parent and child — selected at
`/role-selection` and persisted in the session.

Route constants (`lib/app/routes/app_routes.dart`):

| # | Constant | Path | Screen class | Registration |
|---|----------|------|--------------|--------------|
| 1 | `splash` | `/` | `SplashPage` | `app_pages.dart:57-61` |
| 2 | `configuration` | `/configuration` | `ConfigurationPage` | `app_pages.dart:62-65` (no binding) |
| 3 | `roleSelection` | `/role-selection` | `RoleSelectionPage` | `app_pages.dart:66-70` |
| 4 | `login` | `/auth/login` | `LoginPage` | `app_pages.dart:71-75` |
| 5 | `register` | `/auth/register` | `RegisterPage` | `app_pages.dart:76-80` |
| 6 | `verifyEmail` | `/auth/verify-email` | `VerifyEmailPage` | `app_pages.dart:81-85` |
| 7 | `parentShell` | `/parent` | `ParentShellPage` (4 tabs) | `app_pages.dart:86-90` |
| 8 | `familySetup` | `/parent/family-setup` | `FamilySetupPage` | `app_pages.dart:91-95` |
| 9 | `family` | `/parent/family` | `FamilyPage` | `app_pages.dart:96-100` |
| 10 | `pairingRedeem` | `/parent/pairing/redeem` | `PairingRedeemPage` | `app_pages.dart:101-105` |
| 11 | `pairingRequests` | `/parent/pairing/requests` | `PairingRequestsPage` | `app_pages.dart:106-110` |
| 12 | `deviceDetail` | `/parent/devices/detail` | `DeviceDetailPage` | `app_pages.dart:111-115` |
| 13 | `appRestrictions` | `/parent/app-restrictions` | `AppRestrictionsPage` | `app_pages.dart:116-120` |
| 14 | `screenTime` | `/parent/screen-time` | `ScreenTimePage` | `app_pages.dart:121-125` |
| 15 | `location` | `/parent/location` | `LocationPage` | `app_pages.dart:126-130` |
| 16 | `safeZones` | `/parent/safe-zones` | `SafeZonesPage` | `app_pages.dart:131-135` |
| 17 | `alerts` | `/parent/alerts` | `SafetyAlertsPage` | `app_pages.dart:136-140` |
| 18 | `remoteAssistance` | `/parent/assistance` | `RemoteAssistancePage` | `app_pages.dart:141-145` |
| 19 | `remoteSession` | `/parent/assistance/session` | `RemoteSessionPage` | `app_pages.dart:146-150` |
| 20 | `auditLogs` | `/parent/audit` | `AuditLogsPage` | `app_pages.dart:151-155` |
| 21 | `parentSettings` | `/parent/settings` | `ParentSettingsPage` | `app_pages.dart:156-160` |
| 22 | `childShell` | `/child` | `ChildShellPage` (4 tabs) | `app_pages.dart:161-165` |
| 23 | `childEnrollment` | `/child/enrollment` | `ChildEnrollmentPage` | `app_pages.dart:166-170` |
| 24 | `childRestrictions` | `/child/restrictions` | `ChildRestrictionsPage` | `app_pages.dart:171-175` (reuses `ChildShellBinding`) |
| 25 | `childSession` | `/child/session` | `ChildSessionPage` | `app_pages.dart:176-180` |
| 26 | `childRequests` | `/child/requests` | `ChildRequestsPage` | `app_pages.dart:181-185` |

### 2.2 Parent navigation tree (reachable from launch)

`ParentShellPage` is a 4-destination `NavigationBar` over an `IndexedStack`
(`lib/features/parent_shell/parent_shell_page.dart:16-50`): Dashboard, Devices, Alerts,
Settings. There is **no drawer, no FAB, no overflow menu** in the parent shell.

```
/ (SplashPage)                                    splash_page.dart
└─ /configuration (ConfigurationPage)               splash_controller.dart:71-74 (only when Supabase is not configured)
└─ /role-selection (RoleSelectionPage)              auth_session_flow.dart:84-99 (routeForDestination)
   ├─ /auth/login (LoginPage)                       login_page.dart:164 (to register); reached from role selection
   ├─ /auth/register (RegisterPage)                 register_page.dart:192 (offNamed verify-email)
   └─ /auth/verify-email (VerifyEmailPage)          auth_session_flow.dart:87; verify_email_controller.dart:165 (back to login)
   └─ /parent/family-setup (FamilySetupPage)        auth_session_flow.dart:92, role_selection_controller.dart:157
└─ /parent (ParentShellPage)  ── bottom nav, 4 tabs ──────────────────────────────
   ├─ [0] Dashboard tab (ParentDashboardTab)        parent_dashboard_tab.dart:19
   │    AppBar: family name + refresh                parent_dashboard_tab.dart:18-27
   │    ├─ empty→/parent/family-setup                parent_dashboard_tab.dart:107
   │    ├─ empty→/parent/family  (familyId arg)      parent_dashboard_tab.dart:117-120
   │    ├─ Quick links ▸ Family → /parent/family     parent_dashboard_tab.dart:171-174
   │    ├─ Quick links ▸ Pair a device → /parent/pairing/redeem   :181-184
   │    ├─ Quick links ▸ Alerts → /parent/alerts     :191-194
   │    └─ Device card ▸ Open device → /parent/devices/detail     :297-300
   ├─ [1] Devices tab (ParentDevicesTab)             parent_devices_tab.dart:17
   │    ├─ empty→/parent/family-setup                parent_devices_tab.dart:112
   │    ├─ empty→/parent/family                      parent_devices_tab.dart:122-125
   │    └─ card ▸ Open device → /parent/devices/detail            :210-213
   ├─ [2] Alerts tab (ParentAlertsTab)               parent_alerts_tab.dart:31
   │    Inline AlertsBody(compact:true) — no AppBar, no navigation  alerts_body.dart:17-110
   └─ [3] Settings tab (ParentSettingsTab)           parent_settings_tab.dart:25
        Inline SettingsBody — no AppBar                     settings_body.dart:16-239
        ├─ ▸ Family details → /parent/family           settings_body.dart:99-102
        ├─ ▸ Manage retention and audit log → /parent/audit   :176-179
        └─ ▸ Open device details → /parent/devices/detail     :323-326

/parent/family (FamilyPage)                        family_page.dart:82
├─ Link a child → /parent/pairing/redeem            family_page.dart:35-41
├─ Pairing requests → /parent/pairing/requests      family_page.dart:43-49
├─ Audit log (read-only) → /parent/audit            family_page.dart:51-56
└─ Unlink child (confirm dialog)                    family_page.dart:58-79

/parent/pairing/redeem (PairingRedeemPage)          pairing_redeem_page.dart
└─ → /parent/family on success                      pairing_redeem_page.dart:85-88

/parent/pairing/requests (PairingRequestsPage)      pairing_requests_page.dart
└─ → /parent/pairing/redeem                         pairing_requests_page.dart:55-58

/parent/devices/detail (DeviceDetailPage)           device_detail_page.dart:11
└─ "Manage" card, 6 links                          device_detail_page.dart:416-473
   ├─ App restrictions → /parent/app-restrictions    :425-428
   ├─ Screen time     → /parent/screen-time          :433-436
   ├─ Location        → /parent/location             :441-444
   ├─ Safe zones      → /parent/safe-zones           :449-452
   ├─ Safety alerts   → /parent/alerts               :457-460
   └─ Remote assistance → /parent/assistance         :465-468
   plus Revoke device (confirm) :491-507, Start device recovery (confirm) :475-489

/parent/location (LocationPage)                     location_page.dart:13
└─ AppBar fence icon / "Manage safe zones" → /parent/safe-zones  :32-36, :194-202

/parent/safe-zones (SafeZonesPage)                  safe_zones_page.dart:9
└─ CRUD via AlertDialog editor (no route)            safe_zones_page.dart:125-148, :298-380

/parent/alerts (SafetyAlertsPage → AlertsBody non-compact)   safety_alerts_page.dart:17
└─ Acknowledge (confirm dialog)                       alerts_body.dart:113-130

/parent/assistance (RemoteAssistancePage)           remote_assistance_page.dart:31
└─ Request audio / Request video (consent dialog) then
   → /parent/assistance/session                     remote_assistance_page.dart:211-214, :220-223

/parent/assistance/session (RemoteSessionPage)      remote_session_page.dart
/parent/audit (AuditLogsPage)                       audit_logs_page.dart
/parent/settings (ParentSettingsPage)               app_pages.dart:156-160 — ORPHAN, see 2.4
```

Total parent-facing route screens: 15 (parent shell + 14 pushed routes), of which
`/parent/settings` is registered but has no navigation source.

### 2.3 Child navigation tree

`ChildShellPage` is a 4-destination `NavigationBar` over an `IndexedStack`
(`lib/features/child/child_shell_page.dart:16-55`): Home, Rules, Requests (badged with
pending count, `child_shell_page.dart:39-49`), Settings. No drawer, no route-based tabs.

```
/child (ChildShellPage)                             child_shell_page.dart:9
├─ [0] Home (ChildHomeTab)                          child_home_tab.dart:11
│    AppBar: family name or "My phone" + refresh     child_home_tab.dart:18-28
│    ├─ active session card ▸ Open session            controller.openActiveSession → /child/session
│    ├─ active session card ▸ Stop sharing            child_home_tab.dart:195-203
│    ├─ enrollment card ▸ Set up linking / Finish phone setup → /child/enrollment  :227-231
│    ├─ enrollment card ▸ Open N pending requests → /child/requests   :234-240
│    ├─ device card ▸ View rules and permissions → /child/restrictions  :331-336
│    ├─ "This phone" fallback ▸ Open phone setup → /child/enrollment   :288-292
│    ├─ Waiting-for-you card ▸ Review requests → /child/requests       :467-471
│    ├─ Location sharing switch                        :399-416
│    ├─ Background protection ▸ Retry                  :377-383
│    └─ "More" list: Rules and permissions / Requests / This phone settings (tab switch)  :483-511
├─ [1] Rules (ChildRulesTab)                        child_rules_tab.dart:10
│    └─ ▸ Open full rules and permissions → /child/restrictions  :116-121, :91-95
├─ [2] Requests (ChildRequestsTab)                  child_requests_tab.dart
│    └─ ▸ → /child/requests                          child_requests_tab.dart:76, :96, :131, :143
└─ [3] Settings (ChildSettingsTab)                  child_settings_tab.dart:10
     ├─ Android permissions tiles (usage, location, bg location, camera, mic, notifications, device admin)  :136-204
     ├─ Camera and microphone test → MediaSelfTestSheet (modal)   :210-232
     ├─ ▸ View rules and verification → /child/restrictions       :256-261
     ├─ Background protection ▸ Retry                              :296-302
     └─ Unlink (confirm) / Sign out (confirm)                      :342-369

/child/enrollment (ChildEnrollmentPage)             child_enrollment_page.dart:169,508 → /child on finish
/child/restrictions (ChildRestrictionsPage)         child_restrictions_page.dart:97 → /child/enrollment
/child/session (ChildSessionPage)                   child_session_page.dart:17; opened at child_shell_controller.dart:413-416, child_requests_controller.dart:191-195
/child/requests (ChildRequestsPage)                 child_requests_controller.dart:143,192
```

Note: `ChildRequestsTab` duplicates the pushed `ChildRequestsPage` — both render the same
request list (`child_requests_tab.dart:76-143` vs `child_requests_page.dart`), so tapping
"Requests" from the tab opens an identical page one level deeper (see 2.4).

### 2.4 Duplicate screens, dead routes, inconsistent labels

| # | Finding | Evidence | Consequence |
|---|---------|----------|-------------|
| D1 | **Dead route** `/parent/settings` → `ParentSettingsPage` is registered but no code navigates to it. It re-renders the same `SettingsBody` already shown by tab 3. | `app_routes.dart:25`; `app_pages.dart:156-160`; `parent_settings_page.dart:12-23`; no `AppRoutes.parentSettings` reference outside `app_pages.dart` (grep, 2026-10-30) | Unreachable duplicate screen; the shell tab is the only settings surface. |
| D2 | Dashboard device card and Devices-tab card are near-duplicates (avatar, status chip, last seen, battery, enforcement, policy, permission gaps, "Open device"). | `parent_dashboard_tab.dart:202-309` vs `parent_devices_tab.dart:130-222` | Two implementations of the same card; the dashboard shows the guardian-assigned display name *and* the raw device name while the Devices tab shows only one, so the same phone can look different per tab. |
| D3 | Alerts is reachable three ways: bottom-nav tab, dashboard "Quick links → Alerts", device-detail "Safety alerts". The tab has no AppBar while its sibling tabs do. | `parent_shell_page.dart:39-43`; `parent_dashboard_tab.dart:187-195`; `device_detail_page.dart:454-461`; `parent_alerts_tab.dart:25-32` (no Scaffold) vs `parent_dashboard_tab.dart:17-28` (Scaffold+AppBar) | Same content, three entry points, inconsistent chrome. |
| D4 | Settings tab has **no page heading and no AppBar**; `SettingsBody` starts directly with the action-error banner and the Account card. Alerts tab does render its own header ("Alerts"). | `settings_body.dart:18-31`; `alerts_body.dart:150-156` | Users cannot tell which tab they are on; visual hierarchy differs between tabs. |
| D5 | Child "Requests" tab duplicates the pushed `/child/requests` page; every row and the CTA navigate to the near-identical page. Both use the title "Requests". | `child_requests_tab.dart:18`, `:76`, `:96`, `:131`, `:143`; `child_requests_page.dart:18` | One extra navigation hop for the same list; two screens to maintain. |
| D6 | Child Home "More" list re-lists the sibling tabs (Rules, Requests) and switches to the Settings tab via `selectTab(3)`. | `child_home_tab.dart:477-515` | Redundant navigation model inside a 4-tab shell. |
| D7 | "Rules and permissions" reachable from four child entry points; "Background protection" card is duplicated on Home and Settings. | `child_home_tab.dart:331-336`, `:485-492`; `child_rules_tab.dart:116-121`; `child_settings_tab.dart:256-261`; `child_home_tab.dart:342-387` vs `child_settings_tab.dart:267-306` | Duplicate status surfaces that can disagree (two "Background protection" chips). |
| D8 | **Label drift — pair vs link:** "Pair a device" (dashboard), "Link a child" (page title + family action), "Pairing requests" vs "Linking requests" (same objects), child side "Set up linking". | `parent_dashboard_tab.dart:179`; `pairing_redeem_page.dart:94`; `family_page.dart:195`, `:202`; `child_requests_page.dart:92`; `child_home_tab.dart:228` | Two vocabularies for one flow. |
| D9 | **Code vs Child ID:** parent screen accepts "Child ID or linking code"; family setup instructs "redeem the 8-character code"; child screen leads with a permanent `PC-…` Child ID + QR and only mentions codes implicitly. | `pairing_redeem_page.dart:175-186`; `family_setup_page.dart:105-107`; `child_enrollment_page.dart:184-235`, `:272-296` | Stale instruction on family setup contradicts the current Child-ID flow. |
| D10 | **Phone vs device:** child UI says "phone" ("This phone settings", "Set up this phone", "Open phone setup", "Finish phone setup", "My phone"); parent UI says "device" ("Devices", "Open device", "Device identity"). | `child_settings_tab.dart:18`; `child_enrollment_page.dart:47`; `child_home_tab.dart:19`, `:228`, `:289`; `parent_shell_page.dart:37`; `device_detail_page.dart:195` | Same object, two nouns across the two roles. |
| D11 | **Audit naming:** page title "Audit & retention"; entry labels "Audit log (read-only)" and "Manage retention and audit log". | `audit_logs_page.dart:17`; `family_page.dart:209`; `settings_body.dart:171` | Three names for one destination. |
| D12 | **Status casing:** `STALE` (Location) vs `Stale` (Screen time); "Recent"/"Not reported"/"No upload". | `location_page.dart:284-288`, `:300`; `screen_time_page.dart:159-169` | Inconsistent status vocabulary in the same domain (freshness). |
| D13 | Nested `Scaffold`s: shell Scaffold wraps tab Scaffolds (Dashboard, Devices) but not the other two tabs. | `parent_shell_page.dart:15`; `parent_dashboard_tab.dart:17`; `parent_devices_tab.dart:16` | Double AppBar/body scaffold; snackbars and insets behave differently per tab. |
| D14 | Duplicated helper `_severityLabel` exists twice in the same file. | `alerts_body.dart:208-217` and `alerts_body.dart:343-352` | Code duplication; labels can drift. |
| D15 | Empty-state device-card helper is duplicated with slightly different copy ("No family set up yet" both, but different body text and actions). | `parent_dashboard_tab.dart:99-122` vs `parent_devices_tab.dart:104-127` | Two onboarding empty states for the same prerequisite. |

### 2.5 Screens whose backing feature is missing or not functional

| Screen | What the UI promises | What the code says | Status |
|---|---|---|---|
| Screen time → bedtime / daily limit | "Daily limit, bedtime and device acknowledgement"; Save screen-time policy button | Child build states: "Daily screen-time limits and bedtime are not enforced system-wide by this Android build." | `UI ONLY` for bedtime/limit enforcement; the policy is saved and acknowledged but not applied (`screen_time_page.dart:264`, `:110-129`; `child_restrictions_page.dart:295-301`) |
| App restrictions | Block / allow apps, strict mode, per-app schedules | Only executable when the phone is Device Owner; otherwise a warning is shown and nothing is suspended | `PARTIALLY IMPLEMENTED` (`app_restrictions_page.dart:126-136`, `:141-146`; `device_detail_page.dart:94-105`; `child_restrictions_page.dart:124-138`) |
| Location | "Latest fix" + history | Renders decimal coordinates and accuracy only, no map, no place names, no live tracking; no map dependency in `pubspec.yaml` | `PARTIALLY IMPLEMENTED` (`location_page.dart:204-205`, `:148-191`; `pubspec.yaml:30-46`) |
| Safe zones | Create/edit/delete zones with enter/exit alerts | Requires the owner to type latitude/longitude/radius; no map picker | `PARTIALLY IMPLEMENTED` (`safe_zones_page.dart:317-352`; alert types `telemetry.dart:203-210`) |
| Remote assistance | "Request audio"/"Request video" | Child must accept and then Join; parent camera/mic never opened; audio is listen-only; screen capture explicitly excluded | `IMPLEMENTED — PARTIALLY VERIFIED` (`remote_assistance_page.dart:20-29`, `:144-151`; `remote_session_page.dart:139`) |
| Device permissions (parent) | Shows camera/mic/location/notification/usage access | Values are heartbeat-reported booleans, can stay "Unknown" indefinitely; no way to request from the parent app | `IMPLEMENTED — PARTIALLY VERIFIED` (`device_detail_page.dart:326-366`; `settings_body.dart:287-317`) |
| Notifications | "Show local notifications", "Location sharing reminder" | Explicitly local-only preferences; no push transport in `pubspec.yaml` (no FCM/APNs) | `UI ONLY` (`settings_body.dart:108-144`; `pubspec.yaml:30-46`) |
| Settings → "Security notes"/"About" | Long static text cards | No controls; informational only | `NOT APPLICABLE` (informational) (`settings_body.dart:188-224`) |

### 2.6 AirDroid section comparison

Rows use the brief's status vocabulary: `PARTIALLY IMPLEMENTED` = a related but incomplete surface;
`MISSING` = no screen or route; `IMPLEMENTED — PARTIALLY VERIFIED` = full UI path with only static or
partial runtime evidence. All rows are source-level except where a `docs/evidence` file is named.

| AirDroid section | Ours | Status | Evidence |
|---|---|---|---|
| Dashboard / Today's Event | Dashboard tab with device cards + quick links; **no event timeline / "today" feed** | `PARTIALLY IMPLEMENTED` | `parent_dashboard_tab.dart:43-97` (list = device cards, quick links, updated stamp only) |
| Location | Location page: latest fix, accuracy, point history, range chips | `PARTIALLY IMPLEMENTED` | `location_page.dart:65-191` |
| Remote Camera | None. Camera only in a consented session initiated by the child's Join | `MISSING` | `remote_assistance_page.dart:20-29`; `settings_body.dart:195-197` |
| Screen Mirroring | None; explicitly disclaimed | `MISSING` | `settings_body.dart:195-197`; `remote_session_page.dart:139` |
| One-Way Audio | "Request audio" → child accepts → listen-only session | `IMPLEMENTED — PARTIALLY VERIFIED` | `remote_assistance_page.dart:110-151`; `docs/evidence/stage8/e2-parent-sent.png`, `e8-parent-live.png` |
| App Management | Installed-app snapshot, block/allow, strict mode, per-app schedules | `PARTIALLY IMPLEMENTED` | `app_restrictions_page.dart:321-479`, `:411-448`, `:781` |
| Downtime | Per-app schedule windows + a bedtime window in the screen-time policy | `PARTIALLY IMPLEMENTED` (bedtime not enforced) | `app_restrictions_page.dart:600-620`, `:781`; `screen_time_page.dart:320-407`; `child_restrictions_page.dart:295-301` |
| Instant Block | A strict "Block every app except allowed" switch; no one-tap pause-all from dashboard | `PARTIALLY IMPLEMENTED` | `app_restrictions_page.dart:411-448` |
| Notifications | Alerts tab + local-only toggles; no push delivery | `PARTIALLY IMPLEMENTED` | `alerts_body.dart:29-110`; `settings_body.dart:108-144` |
| Social Content Detection | None (the Instagram card only pre-selects `com.instagram.android` for blocking) | `MISSING` | `app_restrictions_page.dart:382-409` |
| Inappropriate Image Detection | None; app states it never captures images outside sessions | `MISSING` | `child_settings_tab.dart:66-70` |
| Calls & SMS | None; no call-log/SMS read path in Flutter | `MISSING` | no `call_log`/`sms` references in `lib/` (grep, 2026-10-30); `pubspec.yaml:30-46` |
| Website Restrictions | None; no WebView/URL-filter dependency | `MISSING` | `pubspec.yaml:30-46` |
| Browsing History | None | `MISSING` | `pubspec.yaml:30-46`; no route/screen |
| Route History | Point history only; no trips/routes | `MISSING` | `location_page.dart:148-191` |
| Geofence | Safe zones CRUD + enter/exit alert types; coordinates typed manually | `PARTIALLY IMPLEMENTED` | `safe_zones_page.dart:79-118`, `:298-380`; `telemetry.dart:203-210` |
| Requests / Alerts | Safety alerts with ack + severity filter; pairing requests; assistance requests | `IMPLEMENTED — PARTIALLY VERIFIED` | `alerts_body.dart:17-110`; `pairing_requests_page.dart:112-142`; `child_requests_page.dart:89-135` |
| Family & Devices | Family page (guardians/children/unlink), Devices tab, device detail with revoke/recovery | `IMPLEMENTED — PARTIALLY VERIFIED` | `family_page.dart:154-281`; `parent_devices_tab.dart:32-128`; `device_detail_page.dart:34-191` |
| Settings / Account | Account card, family, local toggles, retention, permissions, version, sign out; **no password change, no profile edit, no language, no delete account** | `PARTIALLY IMPLEMENTED` | `settings_body.dart:29-236` |

### 2.7 Missing loading / empty / error states, confirmations, permission prompts

Present and consistent (credit where due): the four main list screens implement
loading + error + retry + offline banners (`parent_dashboard_tab.dart:34-72`,
`parent_devices_tab.dart:33-72`, `alerts_body.dart:19-44`, `location_page.dart:39-63`),
and destructive server actions are confirmed (`settings_body.dart:242-254`,
`device_detail_page.dart:475-507`, `family_page.dart:58-79`, `safe_zones_page.dart:135-147`,
`audit_logs_page.dart:315-330`, `child_settings_tab.dart:342-369`,
`alerts_body.dart:113-130`, `child_requests_page.dart:152-180`). The microphone permission tile is
correctly withheld until the phone is linked and replaced by an explanatory banner
(`child_settings_tab.dart:169-185`); the pairing/consent dialogs explain consequences before acting
(`child_requests_page.dart:152-180`, `remote_assistance_page.dart:201-207`).

| Gap | Evidence | Risk |
|---|---|---|
| `SettingsBody` has no loading or error state for account/family/retention; missing values render as `Unknown`. | `settings_body.dart:151-162` | Parent cannot tell "not loaded" from "not configured". |
| Removing a blocked app is a bare icon tap with no confirmation. | `app_restrictions_page.dart:610-615` | Accidental removal of a rule that silent-deletes on save. |
| Enabling strict "block everything" is a single switch with no confirmation dialog; the only warning appears after the switch is on. | `app_restrictions_page.dart:417-434` | High-impact setting flipped by a mis-tap. |
| `Remove limit` / `Clear bedtime` are immediate text buttons. | `screen_time_page.dart:357`, `:405` | Low impact but inconsistent with other destructive flows. |
| Child "Stop sharing" ends local media with no confirmation. | `child_home_tab.dart:194-203` | Intentional per session-lifetime design, but an accidental tap stops a live session. |
| Parent `Revoke device` navigates back only on success and has no "device unreachable" state beyond an inline banner. | `device_detail_page.dart:491-507`, `:115-122` | Acceptable; noting asymmetry. |
| Permission tiles trigger the OS dialog directly with no in-app rationale dialog; the only explanation is the tile subtitle. | `child_settings_tab.dart:143-204`; `child_shell_controller.dart:757-791` | On Android 13+ notification denial loops back with an error string (`child_shell_controller.dart:871-875`) instead of a "go to settings" affordance. |
| `ParentAlertsTab` renders an `EmptyState` when no family exists, outside any scroll view. | `parent_alerts_tab.dart:18-24` | Not scrollable / no refresh affordance in that state. |
| Dashboard "Linked children" list has no action to enrol the missing device. | `parent_dashboard_tab.dart:139-155` | Dead end for the exact case the card describes. |

### 2.8 Accessibility (from code)

| Aspect | Finding | Evidence |
|---|---|---|
| Semantics | **Zero `Semantics(` widgets in `lib/`.** Status is conveyed by colour + a text chip, but icons in `ListTile.leading` and `CircleAvatar` have no explicit labels. | grep `Semantics(` → 0 matches (2026-10-30); `status_chip.dart:37-61` |
| Tooltips | All 28 `IconButton`s carry a `tooltip:` (refresh, fence, copy, password toggles, remove-block). | `parent_dashboard_tab.dart:21-24`; `login_page.dart:134-145`; `app_restrictions_page.dart:610-615`; `configuration_page.dart:168-172` |
| Touch targets | Primary buttons use theme `minimumSize: Size.fromHeight(50)`; ListTiles 56+; IconButtons default 48. Inline `TextButton` "Add" (Instagram card) and per-row icon buttons rely on Material minimums with dense padding. | `app_theme.dart:75-89`; `app_restrictions_page.dart:402-405`; `status_chip.dart:38-42` (12 px label, non-interactive) |
| Text scaling | No `textScaler` handling; fixed fractional heights for empty states (`0.62`/`0.55` of screen height) and a fixed `SizedBox(height: 240)` for the usage empty state; side-by-side button rows will overflow at 200 % scale. | `parent_dashboard_tab.dart:74-77`; `parent_devices_tab.dart:74-77`; `child_requests_tab.dart:67-68`; `child_requests_page.dart:78-79`; `screen_time_page.dart:192-193`; `remote_assistance_page.dart:110-143` |
| Localisation | **No l10n at all**: no `flutter_localizations`, no `intl` message catalogs, no ARB files; every string is a hardcoded English literal (dozens of pages). | `pubspec.yaml:30-46` (no localisation deps); `app.dart:14-22` (no `localizationsDelegates`/`supportedLocales`) |
| Contrast tokens | `AppColors.warning #B26A00` on a 12 % tint at 12 px is the weakest combination; `AppColors.muted #5F6B7A` on `#F5F7FC` is acceptable. Status chips are 12 px text. | `app_theme.dart:11-13`; `status_chip.dart:34`, `:53-57` |
| Colour-only signalling | Revoked/offline/enforced are colour + text; stale location adds both an uppercase chip and a banner (good). But `CircleAvatar` online dot uses colour only in the dashboard card. | `parent_dashboard_tab.dart:222-231`; `location_page.dart:281-306` |

### 2.9 Responsive / tablet

- **No `LayoutBuilder` anywhere** in `lib/`; no `NavigationRail`, no two-pane master/detail. The only `MediaQuery` uses are four fractional empty-state heights and one keyboard inset (grep, 2026-10-30).
- No orientation lock is declared in Dart or `AndroidManifest.xml` (grep for `setPreferredOrientations`/`screenOrientation` → 0 matches), so rotation is allowed but untested and every screen is a single-column `ListView`.
- Width caps exist only on auth/onboarding/forms: 520 (`splash_page.dart:25`), 620 (`role_selection_page.dart:76`, `pairing_redeem_page.dart:98`), 560 (`family_setup_page.dart:41`), 760 (`family_page.dart:107`, `configuration_page.dart:72`). **All main data screens have no max width** — dashboard, devices, device detail, alerts, settings, location, safe zones, screen time, app restrictions, audit, session pages — so on a tablet the cards stretch edge-to-edge.
- The parent shell always uses a bottom `NavigationBar` (`parent_shell_page.dart:25-50`); on tablets/landscape this is less ergonomic than a `NavigationRail` (assumption — layout quality not measured).

### 2.10 Design system

| Element | State | Evidence |
|---|---|---|
| Theme | Single light theme only; no `darkTheme`/`themeMode`; Material 3 on. | `app.dart:14-22`; `app_theme.dart:20-35` |
| Colour tokens | 9-colour `AppColors` palette; semantic usage is consistent (primary/success/warning/danger/muted/border). A hardcoded `Color(0xFF172033)` appears three times and bypasses the palette. | `app_theme.dart:3-15`; duplicated literal at `app_theme.dart:44`, `role_selection_page.dart:122`, `splash_page.dart:50` |
| Spacing / radius | **No spacing or radius tokens.** Padding values 6/8/10/12/14/16/20/24/28/32 and radii 12/14/16 are hardcoded at call sites (every page; e.g. `settings_body.dart:19-21`, `device_detail_page.dart:106-114`). | `app_theme.dart` defines none |
| Typography | No `textTheme` override; relies on Material defaults plus ad-hoc `fontSize: 12/16/20/30` and `fontWeight` inline. | `app_theme.dart:37-94`; `parent_dashboard_tab.dart:239-242`; `child_enrollment_page.dart:231-235`; `status_chip.dart:53-57` |
| Component library | Good shared set: `AppButton`, `AppTextField`, `SectionCard`, `StatusChip`, `InfoBanner`, `KeyValueRow`, `PermissionStatusTile`, `ConfirmDialog`, `LoadingState/ErrorState/EmptyState`. | `lib/core/widgets/*.dart`; `async_state_view.dart:45-166`; `confirm_dialog.dart` |
| Status pattern | `StatusTone` 5-value enum → `StatusChip` tint (12 % alpha) + label + optional icon. Tone mapping is re-implemented five times (ternaries and `_tone` helpers), so the same status can render differently. | `status_chip.dart:5-34`; `alerts_body.dart:321-330`; `remote_assistance_page.dart:302-321`; `parent_dashboard_tab.dart:208-211`; `parent_devices_tab.dart:136-139` |
| Parent vs child distinction | **None visually**: both shells use the same `NavigationBar`, same palette, same AppBar style, same card language. Only the labels/icons differ. | `parent_shell_page.dart:25-50` vs `child_shell_page.dart:25-55`; `app.dart:17` |
| Iconography | Material icons only; semantically reasonable (shield, fence, forum). No custom brand assets beyond the splash shield glyph. | `splash_page.dart:32-44`; no `assets/` declared in `pubspec.yaml:67-76` |
| Copy density | Many screens open with 3–6 sentence explanatory `InfoBanner`/`SectionCard` paragraphs (honesty-oriented, but heavy on mobile): e.g. Remote assistance intro, Device-detail recovery card, Settings security notes. | `remote_assistance_page.dart:82-98`; `device_detail_page.dart:163-187`; `settings_body.dart:188-200` |

Runtime visual check against the two stage-8 captures: the rendered look matches the source tokens —
`#F5F7FC` page background, white 16 px-radius cards with a 1 px border, blue primary for icons and
the primary button, neutral pills for ended sessions, and the same card language on the parent
sign-in screen. The parent "Remote assistance" capture also confirms the long explanatory paragraph
at the top of the screen before any control
(`docs/evidence/stage8/e2-parent-remote-assistance.png`, described layout; source
`remote_assistance_page.dart:82-98`). No child-screen capture was read, so the parent/child visual
sameness claim rests on source only (`app.dart:17`; both shells' `NavigationBar` definitions).

## 3. Evidence gaps / BLOCKED items

| Item | Status | Reason |
|---|---|---|
| Live navigation walk-through (tabs, back stack, deep links) | `BLOCKED — ACCESS REQUIRED` | Would require launching the app and signing in; prohibited by the audit rules. All trees in §2.2–2.3 are derived from `Get.toNamed`/`Get.offAllNamed` call sites and `AppPages.routes`. |
| Screen-reader / TalkBack output, real text-scale rendering | `BLOCKED — ACCESS REQUIRED` | Requires a device. Source shows zero `Semantics` and no textScaler handling (§2.8), but the actual accessibility-tree result is unverified. |
| Tablet / landscape layout | `BLOCKED — ACCESS REQUIRED` | No `LayoutBuilder`, no width caps on data screens (§2.9); real rendering at ≥600 dp unverified. |
| AirDroid pixel/flow parity | `BLOCKED — ACCESS REQUIRED` | AirDroid itself was not installed or observed. The comparison in §2.6 uses the 19-section list supplied in the task brief; only our side is source-cited. |
| Dark mode / dynamic colour | `MISSING` | Source supplies only `theme:` (`app.dart:17`); no `darkTheme` or `themeMode` exists. Static proof; no runtime check needed. |
| Whether `/parent/settings` is reachable by any path | Verified negative (static) | Exhaustive grep of all `Get.toNamed`/`Get.offNamed`/`Get.offAllNamed`/`Get.to` calls shows no constant or dynamic reference to `AppRoutes.parentSettings` (2026-10-30). |

Assumptions are marked `(assumption)` where used; the only one is that AirDroid's listed sections
behave as their names imply, which this audit did not test.

## 4. One-paragraph summary a reviewer can trust

The app has a coherent, deliberately honest UI: two role-specific 4-tab `NavigationBar` shells, 26
registered routes, shared `SectionCard`/`StatusChip`/`InfoBanner`/async-state widgets, and
loading/offline/error/retry states on every primary list screen. Its information architecture is
nevertheless thin compared with AirDroid: of the 19 AirDroid sections, 3 are `IMPLEMENTED — PARTIALLY VERIFIED`
(One-Way Audio, Requests/Alerts, Family & Devices), 8 are `PARTIALLY IMPLEMENTED` (Dashboard,
Location, App Management, Downtime, Instant Block, Notifications, Geofence, Settings), and 8 are
`MISSING` (Remote Camera, Screen Mirroring, Social Content Detection, Inappropriate Image Detection,
Calls & SMS, Website Restrictions, Browsing History, Route History) — see §2.6. Several controls are presented
with more confidence than the implementation supports (screen-time daily limit and bedtime are
explicitly not enforced by this Android build), the parent app exposes a dead duplicate settings
route, the child app duplicates its Requests screen at two levels, and the pairing vocabulary splits
between "pair/link" and "8-character code/Child ID". Accessibility and scalability are the weakest
engineering areas: zero `Semantics`, no localisation framework, no `LayoutBuilder`/max-width on data
screens, no dark theme, and spacing/typography tokens that live as magic numbers at call sites.

---
Output path: `D:\parentcontrol_app\audit\_work\s2-ui-ux-ia.md`
Routes/screens catalogued: 26 routes (26 `GetPage` entries), of which 2 are tab shells
(`ParentShellPage`, `ChildShellPage`) hosting 8 tab screens (4 parent + 4 child) → 34 screen classes
in total (24 pushed/parent-child routes + 2 shells + 8 tabs), plus the app-specific modal surfaces
(safe-zone editor dialog, media self-test sheet) and the shared `ConfirmDialog`. 1 orphan route
(`/parent/settings`) identified.
Five biggest IA/UX gaps vs AirDroid:
1. No Dashboard/"Today's Event" feed and no instant pause-all — the home tab is only a device list
   with quick links (`parent_dashboard_tab.dart:43-97`, `:160-199`).
2. Location is coordinate text with a point list — no map, no trip/route history
   (`location_page.dart:148-191`, `:204-205`; no map dependency in `pubspec.yaml:30-46`).
3. Screen-time daily limit and bedtime are configurable but explicitly not enforced
   (`screen_time_page.dart:260-407` vs `child_restrictions_page.dart:295-301`).
4. Eight AirDroid sections are absent: Remote Camera, Screen Mirroring, Social Content Detection,
   Inappropriate Image Detection, Calls & SMS, Website Restrictions, Browsing History, Route History
   — §2.6.
5. App blocking works only on Device-Owner-provisioned phones, with no in-app provisioning path;
   on normal installs the core promise degrades to warning banners
   (`app_restrictions_page.dart:126-136`; `device_detail_page.dart:94-105`).
Secondary IA defects (not counted above): dead `/parent/settings` route, duplicate child Requests
screen, two device cards, three Alerts entry points, and pair/link/Child-ID label drift.