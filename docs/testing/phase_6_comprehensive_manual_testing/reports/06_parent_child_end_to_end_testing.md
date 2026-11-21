# 06 — Parent–Child End-to-End Testing

Both devices were operated together. Parent actions were not treated as successful
unless the child-side state or server-backed parent state reflected them.

## Tested workflows

| ID | Workflow | Parent observation | Child observation | Status |
|---|---|---|---|---|
| E01 | Existing sessions on both devices | Parent dashboard loaded | Child home loaded | PASS |
| E02 | Child/device visibility | Two RMX2161 rows | Linked account/device present | PASS |
| E03 | Heartbeat / online sync | Offline, last seen 190 h | Offline; credentials invalid | FAIL |
| E04 | Last-seen update | Stuck at Nov 13, 2026 5:23 PM | Same stale timestamp | FAIL |
| E05 | Policy version consistency | Detail/dashboard v4; list v2 | Rules v4 received Nov 17 | FAIL |
| E09 | Usage visibility | "No usage reported yet" | Upload failed, credentials invalid | FAIL |
| E10 | Location visibility | One stale Nov 13 fix; no 7-day history | Location service not running initially | FAIL |
| E14 | Parent restart then resync | Session restored; data reloaded | Not involved | PASS |
| E15 | Parent network loss | Offline banner + cached dashboard | Not involved | PASS |
| E16 | Parent network restore | Banner cleared, refresh succeeded | Not involved | PASS |

## Detailed observations

### E2E-001 — online/offline synchronization

1. Child background service was running with a visible notification.
2. Child settings reported: `Usage upload failed: Device credentials are not valid.`
3. Child home showed Offline; parent dashboard and device list showed Offline.
4. Child home refresh and parent dashboard refresh were performed.
5. Parent last-seen remained Nov 13, 2026 5:23 PM (~190 hours old).

Result: **FAIL**. The expected authenticated heartbeat did not occur. Fresh client
installation did not resolve it because the server-side device credential remains
mismatched.

### E2E-002 — revoked device visibility

Parent dashboard and device list show two rows for the same child/device:

- Revoked row: last seen Nov 13, 2026 10:18 AM, “No policy applied yet”.
- Offline row: last seen Nov 13, 2026 5:23 PM, “Policy v4 · Waiting for device”.

Result: **FAIL**. A revoked device is still presented beside the active device with
the same name, creating ambiguous device identity and stale duplicate data.

### E2E-003 — policy version mismatch

| Surface | Version shown |
|---|---|
| Parent dashboard | v4 |
| Parent device detail | v4 |
| Parent Devices tab | **v2** |
| Child Rules | v4 (received Nov 17) |

Result: **FAIL**. The list summary is stale/inconsistent with detail and child state.

### E2E-004 — permission mismatch

| Surface | Claim |
|---|---|
| Parent device detail | Notifications Granted |
| Child settings | Notifications Granted |
| Android `dumpsys package` | `POST_NOTIFICATIONS` not in granted runtime permissions |

Result: **FAIL (notification permission)**. The earlier location-permission warning
was not reproduced after install; fine/background location are granted. The
notification false-positive remains.

## Workflows not executed

| ID | Workflow | Reason | Status |
|---|---|---|---|
| E06 | Save policy and verify child application | Would mutate live screen-time/app restrictions on a real child device | NOT TESTED |
| E07 | App restriction propagation | Credential invalid; phone not Device Owner | BLOCKED |
| E08 | Bedtime/schedule propagation | No policy mutation performed | BLOCKED |
| E11 | New alert synchronization | No safe new alert generated | NOT TESTED |
| E12 | Parent logout/re-login | No password supplied; would strand session | NOT TESTED |
| E13 | Child restart then resync | Physical device lost USB authorization | BLOCKED |
| E17 | Duplicate-event check | No successful upload path | NOT TESTED |

## End-to-end verdict

The core supported synchronization path is **not functional** on the tested
environment. Parent UI, navigation, cached data, filters and detail screens work,
but the child cannot authenticate its heartbeat or uploads, so online status,
last-seen, usage, location and policy acknowledgement cannot complete.

Evidence: `screenshots/end_to_end/`, `logs/e2e_parent_after_child_refresh.xml`,
`logs/child_home_loaded.xml`, `logs/child_settings_bottom.xml`.
