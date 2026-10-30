# Audio workstream — Phase 1 notes

Contract: `docs/implementation/_work/coordinator-contract.md`. Hardening only: no signaling
payload, consent or session-lifetime change; no new dependency; public controller API unchanged
(one new optional ctor knob, `rejoinDebounce`, default 2 s).

## Work done

- **Single peer.** `decidePeerJoin(hasPeer, hasLocalMedia, isChild, captureActive)` (pure, testable)
  replaces the old `hasActivePeer` check in `join()`: `create` / `replace` / `noOp`. A child rebuild
  tears the old peer + local tracks down first; a parent or an active capture is a no-op. The
  factory `_createExclusivePeer` closes and disposes any survivor *before* creating the new peer,
  so the old "`_peer != null` but `hasActivePeer == false` -> second live peer" leak is gone.
- **Teardown.** `_teardownMedia()` serialises into `_teardownMediaOnce()`: timers/signaling
  buffers, then peer and local stream are detached synchronously before the first `await`, peer
  closed + disposed, tracks stopped once, native service stopped at most once (only child, only
  after a confirmed start). Terminal local state set first; server session untouched. Concurrent
  calls await the same future; a later call finds nothing. `_cleanupFailedJoin(token)` now refuses
  to clear shared flags / stop the service when a newer join superseded it.
- **Rejoin debounce.** `_announceChildReady` sends at most one `{ready, sdp:'', type:'offer'}`
  per 2 s and never while one is in flight; payload unchanged; the window resets after a media
  rebuild so a fresh attempt can announce immediately.
- **Native.** `AudioAssistanceService`: monotonic `lastStartId`, `stopSelf(startId)`, and a
  session-scoped Stop intent (`EXTRA_SESSION_ID` + pure `stopTargetsOtherSession`) so a stale stop
  cannot kill the new session. `startDisposition` already deduped; unchanged.
- **State surfacing.** `statusLabel` lets a terminal server state win over "Sharing stopped"; live
  labels still require `hasActivePeer`. Status card tone is success only when RTP is flowing.

## Tests

- New `test/features/remote_assistance/remote_session_audio_lifecycle_test.dart` (9 tests) with
  local fakes counting peer close/dispose and track stop. Covers the decision table, second join,
  survivor replacement, tracks-stopped-once, double teardown, transient failed/disconnected
  keeping media, duplicate rejoin dropped, debounce expiry, status never live without a peer,
  terminal state precedence.
- New `android/app/src/test/kotlin/.../AudioAssistanceStopIdempotenceTest.kt` (3 JVM tests, pure
  guard only). **BLOCKED — cross-drive Gradle.**
- `remote_session_reliability_test.dart`: `buildController` gained a `rejoinDebounce` knob;
  `Duration.zero` is passed only by the two retry-budget tests (timing, not debounce). No assertion
  was removed or relaxed.

## Executed

- `dart analyze` on the four edited Dart files -> `No issues found!`.
- `flutter test` NOT run (contract rule 10). Kotlin tests NOT run (Gradle on C: vs project on D:).

## Known risks

- Debounce drops a *second* rejoin within 2 s by design; the server replays the last signal on
  subscribe, so a drop delays rather than loses recovery.
- `RTCPeerConnection.dispose()` returns `Future<void>` but the plugin may not surface errors;
  close is always awaited first, tracks are stopped independently of it.
- `startId` semantics assume Android's per-service monotonic ids (true by platform contract);
  untested here.
- "Live" still means RTP counters > 0; a live-but-silent track shows "Connected, no audio yet",
  which is the intended honest state.