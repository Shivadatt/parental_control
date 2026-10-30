# 02 — AirDroid feature comparison

Reference: AirDroid Parental Control official overview (`https://help.airdroid.com/hc/en-us/articles/4677178239131-AirDroid-Parental-Control-Overview`), as supplied in the master prompt. Capabilities are compared functionally; no AirDroid source, branding or visual design was copied.

Status values are counts from the merged inventory (`01_COMPLETE_FEATURE_INVENTORY.md`, 242 subfeatures). "FV" = FULLY IMPLEMENTED — VERIFIED, "PV" = IMPLEMENTED — PARTIALLY VERIFIED, "PI" = PARTIALLY IMPLEMENTED, "CUT" = CODE EXISTS — NOT TESTED, "BO" = BACKEND ONLY, "NA" = NOT APPLICABLE.

## 1. Category scorecard

| # | AirDroid category | Subfeatures audited | FV | PV | PI | CUT | Broken | Missing | Other | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Family & Device Management | 17 | 9 | 5 | 2 | — | 1 | — | — | Strongest area; presence is broken (F2/F3 class) |
| 2 | Today's Event / Dashboard | 13 | 1 | 3 | 3 | — | — | 6 | — | Device list, not an event timeline |
| 3 | Remote Camera | 14 | 1 | 5 | 2 | 3 | — | 3 | — | Code path only; never run on a device |
| 4 | Screen Mirroring | 13 | — | — | — | — | — | 12 | 1 NA | **Absent** |
| 5 | One-Way Audio | 20 | 15 | 3 | — | — | 1 | 1 | — | Only proven media feature; lifetime broken hosted |
| 6 | Instant Block | 13 | — | 5 | 5 | 3 | — | — | — | Real only under Device Owner; never executed |
| 7 | Downtime | 13 | — | — | 4 | 1 | — | 7 | 1 BO | Bedtime stored, not enforced |
| 8 | App Management | 13 | — | 7 | 2 | 2 | — | 2 | — | Inventory works; enforcement DO-only |
| 9 | Notifications Monitoring | 10 | — | — | — | — | — | 10 | — | **Absent** |
| 10 | Social Content Detection | 13 | — | — | — | — | — | 13 | — | **Absent** |
| 11 | Inappropriate Image Detection | 10 | — | — | — | — | — | 10 | — | **Absent** |
| 12 | Calls & SMS Monitoring | 10 | — | — | — | — | — | 9 | 1 NA | **Absent** (platform-restricted) |
| 13 | Website Restrictions | 14 | — | — | — | — | — | 14 | — | **Absent** |
| 14 | Web Time Limits | 2 | — | — | — | — | — | 1 | 1 NA | iOS-only reference; Android equivalent absent |
| 15 | Browsing History | 10 | — | — | — | — | — | 10 | — | **Absent** |
| 16 | Location | 12 | — | 7 | 1 | 1 | — | 2 | 1 BO | Works, no map, no route |
| 17 | Route History | 9 | — | 3 | 2 | — | — | 4 | — | Point history only |
| 18 | Geofence | 11 | — | 8 | 2 | 1 | — | — | — | Server-side evaluation works; parent UX is manual |
| 19 | Alerts & Requests | 14 | 2 | 2 | 1 | 2 | — | 7 | — | Safety alerts + pairing; no push |

Additional product functionality already present beyond AirDroid's list (11 rows, all PI/PV): audit log + retention, device health/battery/connectivity, remote commands, family management, settings, notifications preferences. Product features that are **absent**: chat, SOS, rewards, subscription/billing, admin tools, data export, account deletion, privacy controls beyond retention.

## 2. Where parity actually exists

**Family & device management (9 fully verified).** Parent/child registration and login, role lock, pairing (Child ID, QR, invite), request/approve, unlink, device registration, revoke, recovery, multi-device, multiple children, session persistence. Runtime evidence: historical verification reports and the Stage 8 two-device run. The one broken row is **online/offline presence**, whose logic was corrected (6-minute window + row refresh) and proven at runtime, but a separate guardian scheduler stall (F2) can still freeze `last_seen_at` while the FGS claims to run.

**One-way audio (15 fully verified).** Consent request → accept → second "Join now" gate → mic FGS → WebRTC → parent playback. Packet-level proof exists (`in 5463 pkts / out 0`, started `VOICE_COMMUNICATION` AudioTrack). Runtime matrix covers background 5 min, lock 2 min, Recents swipe, force stop, permission revoke/restore, network loss + manual rejoin, parent End online/offline. Gaps: session lifetime (`BROKEN` on hosted — F1), no TURN relay, human audibility unconfirmed, 30-min endurance and airplane mode not tested.

**Geofence (8 partially verified).** Safe zones CRUD and server-side haversine evaluation with enter/exit alerts on state flip (`device-telemetry/index.ts:274-352`). But the parent types lat/lng by hand, there is no map, no dwell/accuracy buffer, no push, and alerts stop if the child disables sharing.

**Location (7 partially verified).** A real fix streams from the child and is persisted; the parent sees coordinates, accuracy and a point list. No map SDK, no place names, background location never requested, and offline uploads discard all but the newest fix.

## 3. Where the product claims more than it does

| Surface | Claim | Reality | Severity |
|---|---|---|---|
| Screen time | daily limit + bedtime | not enforced; the child screen says so | High (trust) |
| App restrictions | block/allow apps | only under Device Owner; normal installs suspend nothing | P0 |
| Enforcement status | "enforced" | can be acknowledged as succeeded when zero apps were suspended | P0 (false state) |
| Remote assistance | "Request video" | video path never executed on hardware; front camera only; no torch/switch/background camera | P1 |
| Notifications | notification preferences | no delivery transport at all | P2 |
| Location offline copy | "showing last data loaded" | latest fix is nulled on failure; nothing cached | P3 |
| Live updates banner | "End the session and retry" | shown while media is live (F6) | P3 |

## 4. Categories that are structurally impossible without new platform capability

| Category | What is required | Feasible for a normal app? |
|---|---|---|
| Screen mirroring | MediaProjection + per-session consent + `FOREGROUND_SERVICE_MEDIA_PROJECTION` | Yes, with user consent per session |
| Notifications | NotificationListenerService + `BIND_NOTIFICATION_LISTENER_SERVICE` grant | Yes, with a special-access grant |
| Website restrictions | VpnService (user-consented) or Accessibility URL inspection | VpnService yes; Accessibility is policy-risky |
| Calls & SMS | default SMS/dialer role and/or READ_SMS/READ_CALL_LOG (Play-restricted) | Only as default handler; not for silent interception |
| Social content detection | Accessibility + screen capture or notification text; no public message-content API | Not reliably; privacy/Play risk |
| Inappropriate image detection | MediaStore/ContentObserver + on-device ML | Partially (gallery-scoped), heavy privacy constraints |
| Instant block (without Device Owner) | Accessibility or overlay-based enforcement | Possible but fragile and Play-sensitive; DO is the reliable path |

## 5. AirDroid-vs-ours functional differences that matter most

1. **No "Today's Event" timeline.** AirDroid's home is an activity feed; ours is a device list with quick links. Weekly/daily usage exists as data (`usage_daily`) but is not presented as a trend/feed.
2. **No enforceable restrictions.** AirDroid's core value (block, downtime, limits) depends on enforcement; ours depends on Device Owner provisioning that has never been performed, and bedtime/limits are stored but unused.
3. **No notification/social/call monitoring.** Four AirDroid categories have zero implementation, which is the largest parity gap by count (42 of 111 missing rows).
4. **No web layer at all.** Website restrictions and browsing history are entirely absent (24 missing rows), including the enforcement primitive.
5. **Media is audio-only and one-way**, while AirDroid offers camera and screen mirroring; our video path is unverified code.
6. **No push channel.** AirDroid delivers alerts in real time; ours depends on the app being open or a polling FGS being alive.

## 6. Conclusion

The app reaches AirDroid parity in **account/family/device management** and in **consented one-way audio** (modulo the hosted lifetime defect and TURN). It is materially behind in **enforcement** (blocking/downtime/limits), **monitoring** (notifications, social, images, calls/SMS) and **web control** (restrictions, history), and it lacks the **activity-feed dashboard** that organizes AirDroid's experience. Of 242 audited subfeatures, 28 are fully verified, 53 partially verified, 30 partially implemented, 2 backend-only, 13 code-exists-untested, 2 broken, 111 missing and 3 not applicable.