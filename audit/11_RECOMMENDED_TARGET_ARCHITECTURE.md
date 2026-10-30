# 11 — Recommended target architecture (recommendation only)

Nothing in this document is implemented. It proposes how to close the gaps in `10_GAP_ANALYSIS_AND_PRIORITIES.md` without discarding what already works. Labels: **[keep]**, **[refactor]**, **[new]**, **[remove]**.

## 1. Principles

1. **Keep the three-tier split** (Flutter UI/state, Kotlin capture/background/enforcement, Supabase truth). It is sound and already runtime-proven for audio.
2. **One writer per fact.** Today two halves can disagree: Flutter authors policies, Kotlin applies them, and the server believes the ack. Enforcement state must be owned by the device and proven, not asserted.
3. **Capability honesty over feature count.** A feature either has an enforcement/transport mechanism or the UI states the limitation. No surface may claim what the platform cannot do.
4. **Deployment is part of the architecture.** The F1 defect exists because one artifact deployed independently. Edge Functions need versioned deploys tied to migrations.

## 2. Proposed module layout (delta to `lib/`)

```
lib/
├── core/
│   ├── logging/            [new] structured log sink + redaction (no secrets/PII)
│   ├── telemetry/          [new] crash + metric hooks (opt-in)
│   ├── flags/              [new] remote/local feature flags
│   ├── l10n/               [new] ARB files + delegates
│   └── errors/             [keep] AppException + codes
├── data/
│   ├── repositories/       [keep] contracts; add capability interfaces
│   ├── services/
│   │   ├── realtime/       [refactor] one subscription manager, reconnection
│   │   ├── sync/           [new] durable outbox + retry/backoff
│   │   └── push/           [new] notification transport interface (FCM later)
│   └── models/             [keep]
├── features/
│   ├── dashboard/          [refactor] Today's Event feed over usage_daily + alerts
│   ├── enforcement/        [new] parent policy editor + child capability/status view
│   ├── web_control/        [new] rules + history (requires VpnService)
│   ├── notifications/      [new] parent timeline (requires listener)
│   ├── location/           [refactor] map view, route/trip model, offline queue
│   └── …                   [keep] existing feature folders
└── app/routes/             [refactor] add auth middleware + remove dead route
```

## 3. Android target

| Area | Change | Reason |
|---|---|---|
| Enforcement | Introduce an `EnforcementStrategy` interface with `DeviceOwnerStrategy` (existing `setPackagesSuspended`), `AccessibilityStrategy` (optional, policy-reviewed) and `UnsupportedStrategy` that the UI reflects honestly | Removes false "enforced" state; enables non-DO devices |
| Policy ack | Send the **actual applied set** and a capability report; server sets `enforced` only on a full match | P0-2 |
| Scheduling | Add WorkManager (periodic sync/heartbeat) and AlarmManager for exact downtime boundaries; keep FGS for media | Survives FGS caps and OEM cleaners |
| Guardian | Split the single scheduler tick into independent supervised jobs with a watchdog that restarts a dead tick | F2 |
| Location | Add background-location request path, offline queue, and `GeofencingClient` for local evaluation (server evaluation stays authoritative) | Data loss + latency |
| Boot | Reconcile on `BOOT_COMPLETED` via WorkManager (allowed) instead of refusing on API ≥ 35 | Recovery after reboot |
| Media | Add camera FGS type + rear/torch support if video parity is pursued; add MediaProjection service for mirroring behind explicit consent | Parity |
| Notifications | NotificationListenerService behind explicit special-access grant | Parity |
| Web | `VpnService` with per-family rules and a visible persistent notification | Parity; only feasible enforcement |
| Security | Release keystore, network security config (pin Supabase/TURN), verified app links instead of a custom scheme | Ship-readiness |

## 4. Backend target

| Area | Change | Reason |
|---|---|---|
| Deployment | Version Edge Functions with a deploy manifest; CI gate that fails if `remote-session` source hash differs from deployed | Prevent F1 recurrence |
| Scheduling | Enable `pg_cron` (or an authenticated external scheduler) for `expire_stale_sessions`, `detect_offline_devices`, retention | Currently unreachable |
| Audit | Add `session_expired`, `enforcement_changed`, `permission_revoked` event types; audit every terminal transition | F1 invisibility |
| Authorization | Owner-only `purge_data`; drop `safe_zones` client DELETE; re-check membership in the four service RPCs; use session role for immutability | P0-4 |
| Signaling | Unique `(session_id, sequence)`; verify `session_nonce` on accept/ICE | Replay resistance |
| Notifications | Optional `push_tokens` table + FCM dispatch from `safety_alerts`/commands | Real-time parity |
| Storage | Define buckets + policies only if attachments/recordings are introduced | Currently none |
| Retention | Enforce family settings in a scheduled job, not only on purge | Compliance |

## 5. Reuse vs refactor

**Reuse unchanged:** auth/role lock, pairing (Child ID/QR/invite), device registration and secret transport, session state machine and consent gating, RTP-based liveness, `remote_session_transition_guard`, RLS model (authenticated-only, no anon), partial unique indexes, encrypted local store, append-only audit log.

**Refactor:** policy ack + enforcement status; guardian scheduling; location pipeline (queue + map); notification settings that currently do nothing; navigation (dead route, duplicates); error/loading states; logging/observability.

**New:** web control (VPN), notification listener, push, MediaProjection mirroring (if approved), camera completion, route/trip model, image detection (privacy review first).

**Remove:** unreachable `/parent/settings`, duplicate child Requests page, dead Dart write paths (`DeviceAdminService.applyPolicy`, `PolicyRepository.acknowledgeCommand`, `UsageRepository.uploadUsage`, `LocationRepository.uploadLocation`) or wire them into the real path.

## 6. Sequencing constraint

Deploying the `remote-session` fix is independent of every structural change and should happen first. Enforcement truthfulness (P0-2/P0-3) should precede any new parity feature, because adding more restriction surfaces on a non-enforcing device multiplies the false-state risk. Web filtering and notification monitoring are the two parity features with the best effort-to-value ratio once enforcement is honest; social/image detection and calls/SMS should be treated as separate privacy-reviewed projects, not incremental additions.