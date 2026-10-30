# Two-device live QA — 2026-10-28

Parent: `emulator-5554` (sdk_gphone64_x86_64, Android 17/API 37, QA Parent A,
qa.parent.a2.20261026@example.com).
Child: `5HXWRGQ4IFU8WS4T` (realme RMX2161, Android 12/API 31, QA Child A,
qa.child.a2.20261026@example.com), QA Family A.
Both: app 1.0.0 (4002). No source, migration, hosted config or app data changed.

## Timeline (IST)

- 08:21 preflight: 5 device rows on parent (4 Revoked, 1 Offline realme); realme
  not Device Owner (`dpm list-owners` → no owners); child last seen 7:41,
  background service foreground, "No rules downloaded".
- 08:32 parent unlinks QA Child A: confirmation dialog, server-confirmed
  removal, family page shows Removed.
- 08:33 child refresh: still shows family/linked/registered + "App list upload
  failed: Device credentials are not valid." (credential revocation enforced).
- 08:34 force-stop + relaunch child → unlinked setup state; "Set up linking"
  shows Child ID `PC-94EAJ78H` (unchanged).
- 08:34 parent enters the ID → pending, expires 2026-10-29 08:34.
- 08:35 child sees request ("expires Just now" — BUG-036), approves through
  confirmation; 08:36 "Register this phone" succeeds, local status Online.
- 08:36–08:41 parent `last_seen` frozen at 08:33 while child service foreground
  (BUG-039); cold restart 08:41 → heartbeat, Online, last seen 08:41.
- 08:42 camera/mic self-test: main camera live 1280x720, front camera live,
  mic live; camera CONNECT/DISCONNECT and `Recording active: false` after stop.
- 08:45 parent video assistance request → 08:46 child views, accepts (consent
  recorded), joins; both screens Connected, child camera device 1 connected,
  recording active; parent preview blank, no parent-side audio playback.
  Android mic prompt appeared despite permission already granted; answered in
  dialog.
- 08:47 parent taps End session → ANR dialog (`am_anr`, Input dispatching timed
  out 5003 ms); child camera disconnected at 08:47:25.
- 08:49–08:52 heartbeat cadence 08:41/08:46/08:51; detail Offline at 08:50:5x
  with 4-min-old heartbeat, Online at 08:51:55 with new heartbeat (BUG-038).

## Files

- parent_*.xml / child_*.xml: uiautomator text dumps per step.
- parent_*.png / child_*.png: screenshots.
- parent_anr.png, parent_anr.txt: ANR evidence.
- child_logcat_after_relink.txt, child_crash.txt, child_camera_state.txt,
  parent_audio_playback.txt.
- Full uiautomator XML retained for each dump alongside its extracted text.

## Not done

Policy apply to the new row; remote media delivery verification; Device Owner /
app suspension; TURN; QR scan; physical parent device.
