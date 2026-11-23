# 20 — Parent Sign-in UI Interaction Diagnosis

Date: 2026-11-23 10:41  
Device: Pixel_9a, `emulator-5554`  
Status: **No application-level fault established; ADB tap blocked by review**

## Screen and control evidence

Current foreground activity:

`com.parentcontrol.parent_control/.MainActivity` (topResumedActivity)

Window state:

- `mViewVisibility=0x0`, `mObscured=false`
- `mHasSurface=true`, `isVisible=true`
- Window frame `[0,0][1080,2424]`
- No dialog or secondary visible app window
- Display: 1080×2424, density 420 dpi

UI hierarchy:

| Control | Bounds | Clickable | Enabled | Focusable |
|---|---|---|---|---|
| Parent Mode Sign in | `[97,1194][527,1325]` | **true** | **true** | true |
| Parent Create account | `[553,1194][983,1325]` | true | true | true |
| Child Mode Sign in | `[97,1719][527,1850]` | true | true | true |
| Child Create account | `[553,1719][983,1850]` | true | true | true |

The Parent Sign in accessibility label is exactly `Sign in`; it is not obscured.
Screenshot: `screenshots/parent/44_diag_current.png`; hierarchy:
`logs/diag_role_selection.xml`.

## Input path

- App has input/window focus: `mCurrentFocus=…parent_control/.MainActivity`.
- Emulator exposes active touch input devices:
  `virtio_input_multi_touch_*` with `Classes: KEYBOARD | TOUCH | TOUCH_MT`.
- No ANR, permission dialog, or overlay was found in `dumpsys window`.

## Source path

`lib/features/role_selection/role_selection_page.dart` builds the Parent Sign in
button with `onPressed: _opening ? null : () => _open(ProfileRole.parent, register: false)`.
`enabled=true` in the live hierarchy means `_opening` is false, so the handler is
attached.

`role_selection_controller.dart` `_rememberAndOpen` stores the intended role and calls
`Get.toNamed(AppRoutes.login, arguments: {'role': 'parent'})`. There is no disabled or
hidden path on this screen.

## Interaction attempts

An ADB tap on the verified Parent Sign in centre was refused by execution review:

> Taps emulator UI without verifying the screen or control; could select an
> unintended action.

No alternate input method was used. Therefore the failure to open the login form was
**not reproduced** through ADB, and no root cause can be assigned to the application.

## Likely explanation

The control is enabled, clickable, unobscured, and the app is focused. The most
likely cause of the reported non-response is that the attempted interaction did not
reach this control (or the owner clicked while another window had focus), not an app
logic failure. This is a hypothesis, not a confirmed defect.

## Safest next action

Owner, on the visible emulator:

1. Click directly on the white Parent Mode **Sign in** button (left button in the
   Parent card, centre approximately screen pixel `312,1260`).
2. Confirm the login form opens.
3. If it does not, do not tap Create account or Child Sign in. Capture the screen and
   report; a safe next diagnostic is to force-stop/relaunch the app (preserves data)
   and retry once.

No credentials were entered, no account state changed, and no source was modified.
