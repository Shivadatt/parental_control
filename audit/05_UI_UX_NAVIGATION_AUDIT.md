# 05 — UI/UX and navigation audit

Source: `audit/_work/s2-ui-ux-ia.md` (356 lines, source-level; screenshots not captured). Routes verified in `lib/app/routes/app_routes.dart` and `app_pages.dart`. This is an audit, not a redesign.

## 1. Navigation model

**Parent** — 4-tab `NavigationBar` over an `IndexedStack`: Dashboard, Devices, Alerts, Settings. No drawer, no FAB, no overflow. 15 parent-facing route screens plus 14 pushed routes; one registered route (`/parent/settings`) is unreachable.

**Child** — 4-tab shell: Home, Rules, Requests (badged), Settings; pushed `/child/enrollment`, `/child/restrictions`, `/child/session`, `/child/requests`. 8 screen classes plus modals.

```
/parent → [Dashboard] [Devices] [Alerts] [Settings]
   Dashboard → family, pair, alerts, device card
   Devices → device detail → app-restrictions | screen-time | location | safe-zones | alerts | assistance → session
   Alerts → acknowledge
   Settings → family | audit/retention | device detail

/child → [Home] [Rules] [Requests] [Settings]
   Home → session | enrollment | requests | restrictions | location switch | background retry
   Settings → permissions | media self-test | restrictions | unlink | sign out
```

Neither shell protects itself: there is no middleware, so a deep link opens a shell and every data call fails with `unauthorized` instead of redirecting to login (`s1` §2.4). It is safe (server-enforced) but not graceful.

## 2. Information architecture vs AirDroid

| AirDroid section | Ours | Status |
|---|---|---|
| Dashboard / Today's Event | Device cards + quick links; no event timeline, no "today" feed, no pause-all | `PARTIALLY IMPLEMENTED` |
| Location | Latest fix + point list, no map, no place names | `PARTIALLY IMPLEMENTED` |
| Remote Camera | No screen; camera only inside a consented session | `MISSING` |
| Screen Mirroring | None | `MISSING` |
| One-Way Audio | Request → child accepts → listen-only | `IMPLEMENTED — PARTIALLY VERIFIED` |
| App Management | Installed apps, block/allow, strict mode, per-app schedules | `PARTIALLY IMPLEMENTED` |
| Downtime | Per-app windows + bedtime field (not enforced) | `PARTIALLY IMPLEMENTED` |
| Instant Block | Strict "block all except allowed" switch; no one-tap pause-all | `PARTIALLY IMPLEMENTED` |
| Notifications | Alerts tab + local-only toggles; no push | `PARTIALLY IMPLEMENTED` |
| Social Content Detection | None (Instagram shortcut only pre-selects a package to block) | `MISSING` |
| Inappropriate Image Detection | None | `MISSING` |
| Calls & SMS | None | `MISSING` |
| Website Restrictions | None | `MISSING` |
| Browsing History | None | `MISSING` |
| Route History | Point history only | `MISSING` |
| Geofence | Safe zones CRUD + enter/exit alerts; coordinates typed by hand | `PARTIALLY IMPLEMENTED` |
| Requests / Alerts | Safety alerts + pairing + assistance requests | `IMPLEMENTED — PARTIALLY VERIFIED` |
| Family & Devices | Family page, devices tab, detail, revoke/recover | `IMPLEMENTED — PARTIALLY VERIFIED` |
| Settings / Account | Account, family, toggles, retention, permissions, version, sign out; no password change, profile edit, language, delete account | `PARTIALLY IMPLEMENTED` |

## 3. Concrete navigation defects

| # | Defect | Evidence | Impact |
|---|---|---|---|
| D1 | `/parent/settings` is registered but unreachable; duplicates the Settings tab | `app_routes.dart:25`, `app_pages.dart:156-160` | dead screen |
| D2 | Dashboard and Devices cards are near-duplicate implementations, and can show different names for the same phone | `parent_dashboard_tab.dart:202-309` vs `parent_devices_tab.dart:130-222` | inconsistent device identity |
| D3 | Alerts reachable three ways; the Alerts tab has no AppBar while sibling tabs do | `parent_shell_page.dart:39-43`, `parent_dashboard_tab.dart:187-195`, `device_detail_page.dart:454-461` | inconsistent chrome |
| D4 | Settings tab has no heading/AppBar at all | `settings_body.dart:18-31` | orientation confusion |
| D5 | Child Requests tab and `/child/requests` render the same list; rows navigate to the duplicate | `child_requests_tab.dart:76-143` | extra hop, two screens to maintain |
| D6 | Child Home "More" list re-lists sibling tabs | `child_home_tab.dart:477-515` | redundant model |
| D7 | "Rules and permissions" has four entry points; "Background protection" appears on Home and Settings and can disagree | `child_home_tab.dart:331-336`, `child_rules_tab.dart:116-121`, `child_settings_tab.dart:256-261` | duplicate status surfaces |
| D8 | Vocabulary drift: "Pair" vs "Link"; "Child ID" vs "linking code"; "phone" (child) vs "device" (parent); three names for audit | `family_setup_page.dart:105-107`, `pairing_redeem_page.dart:175-186`, `parent_shell_page.dart:37` vs `child_settings_tab.dart:18` | confusing for non-technical parents |
| D9 | Family setup still instructs an "8-character code" although Child IDs are `PC-XXXXXXXX` | `family_setup_page.dart:105-107` | stale copy |
| D10 | Bedtime/daily limit screen promises enforcement the child build explicitly denies | `screen_time_page.dart:264` vs `child_restrictions_page.dart:295-301` | trust-damaging |
| D11 | Location offline copy "Showing the last data loaded" is false — the latest fix is nulled on failure and nothing is cached | `location_page.dart:50-64`, `location_controller.dart:81` | misleading state |
| D12 | Safe-zone editor requires typing latitude/longitude; no map picker | `safe_zones_page.dart:317-352` | unusable for most parents |

## 4. States, confirmations and permissions

- Destructive actions are confirmed: unlink, revoke device, sign out, acknowledge alert, stop sharing all use dialogs (`ConfirmDialog` / `AlertDialog`).
- Loading/empty states exist on the main lists, but several pages conflate "no data" with "not loaded" and show status text without a retry path (location, screen time).
- Error handling is inconsistent: banners vs inline `AppException` text vs silent empty lists; there is no global error surface.
- Permission prompts: the child Settings shows a permissions checklist with statuses, but the "background location" row routes to app details rather than requesting the permission (the app never requests `ACCESS_BACKGROUND_LOCATION`).

## 5. Accessibility and responsive design (source-level)

| Item | Finding |
|---|---|
| Semantics | zero `Semantics` widgets; icon-only buttons rely on default tooltips or nothing |
| Text scaling | fixed font sizes from the theme; no `textScaler` handling in dense tables |
| Contrast | single light theme; no dark theme; status chips use saturated colors on tinted backgrounds |
| Touch targets | mostly `IconButton` defaults (48dp), but several inline `GestureDetector` chips are smaller |
| Localization | no `flutter_localizations`, no `.tr()`, hardcoded English |
| Responsive | no `LayoutBuilder`/max-width on data screens; fixed horizontal paddings; phone layout only |
| Tablet | untested/unhandled |

## 6. Design system

- One theme file (`core/theme/app_theme.dart`) with a material 3 seed; spacing/typography values are magic numbers at call sites (13/16/18/24 appear repeatedly).
- Parent and child are visually distinguished mainly by accent color and copy, not by layout.
- Status indicators are chips with mixed casing ("STALE" vs "Stale") and different vocabulary per page (D12).
- Shared widgets exist (`core/widgets`, 10 files) but device cards and empty states are duplicated per tab.

## 7. UI that exists without a working feature

| Surface | Promise | Reality |
|---|---|---|
| Screen time limit/bedtime | "Daily limit, bedtime, acknowledgement" | saved and acked, not enforced |
| Notifications toggles | "Show local notifications" | no delivery path at all |
| Remote assistance "Request video" | video session | capture path exists but has never run on a device; no rear camera, no torch |
| App restrictions | block apps | inert without Device Owner |
| Safe zones | geofence alerts | alerts only while the child uploads location; no map; manual coordinates |
| Parent device permissions | live permission status | heartbeat booleans that can stay "Unknown" indefinitely |

## 8. Recommendations (no changes made)

1. One navigation model per role: remove the dead `/parent/settings` route and the duplicate child Requests page.
2. Rename to one vocabulary (device, link, Child ID) across both roles.
3. Replace "not enforced" claims with explicit capability states (Device Owner required / not supported).
4. Add a real map picker and a map view before calling location/geofence "implemented".
5. Add route guards so signed-out deep links land on login.
6. Introduce l10n + Semantics before any consumer release; at minimum label icon-only controls.
7. Unify loading/empty/error components and add retry actions.