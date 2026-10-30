import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'remote_session_controller.dart';

/// App-scoped owner of the single live assistance session controller.
///
/// Route bindings used to register [RemoteSessionController] with
/// `Get.lazyPut`, so popping the session route disposed the controller and
/// `onClose()` tore down an active, consented microphone session. The registry
/// keeps that controller alive across route pushes and pops: only acquiring a
/// different session, an explicit release (logout/unlink) or an explicit
/// termination disposes it.
///
/// It is registered once in `main()` as a permanent service and resolved by
/// `RemoteSessionBinding` and `ChildSessionBinding`.
///
/// It also observes app lifecycle: returning to the foreground reconciles the
/// session that it already owns. Nothing on the pause/hide path tears media
/// down, because backgrounding is not a consent withdrawal.
class RemoteSessionRegistry extends GetxService with WidgetsBindingObserver {
  RemoteSessionController? _active;
  String? _sessionId;
  String? _role;

  /// The live controller, or null when no session is held.
  RemoteSessionController? get active => _active;

  /// Session id of [active], or null when no session is held.
  String? get sessionId => _sessionId;

  /// Role of [active] (`parent`, `child` or `view-only`), or null.
  String? get role => _role;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Reconciles the owned session with the server and native state when the app
  /// returns. It only re-reads existing state: it never creates a session and
  /// never re-opens the microphone without a fresh child action.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final controller = _active;
    if (controller == null) return;
    unawaited(controller.reconcileAfterResume());
  }

  /// Returns the live controller for the same (sessionId, role); otherwise
  /// disposes any previous controller and creates + registers the new one.
  ///
  /// A non-empty session is held permanently in GetX, so route disposal no
  /// longer ends it. An empty session id is the fail-closed binding path: it
  /// never touches, replaces or disposes the live controller and is never
  /// marked active. When nothing is registered it registers a transient
  /// (route-scoped) controller so the page can still find it; when a
  /// controller is already registered, that controller is kept and the page
  /// keeps using it. The transient is not created in that case so a
  /// fail-closed controller can never exist unowned while a live session
  /// holds the microphone.
  RemoteSessionController acquire({
    required String sessionId,
    required String role,
    required RemoteSessionController Function() create,
  }) {
    final normalizedId = sessionId.trim();
    final normalizedRole = role.trim().toLowerCase();

    if (normalizedId.isEmpty) {
      return _acquireFailClosed(create);
    }

    final current = _active;
    if (current != null &&
        _sessionId == normalizedId &&
        _role == normalizedRole) {
      // Same session reachable again (route re-pushed, deep link). Keep the
      // exact instance and make sure it is still resolvable by the page.
      _ensureRegistered(current);
      return current;
    }

    // A different session or role must never overlap with the previous one:
    // dispose it first so exactly one capture engine can be live at a time.
    _disposeActive();
    _disposeStaleRegistration();

    final controller = create();
    _active = controller;
    _sessionId = normalizedId;
    _role = normalizedRole;
    Get.put<RemoteSessionController>(controller, permanent: true);
    return controller;
  }

  /// Explicitly releases the active controller and its native resources
  /// (capture, microphone service, peer). Never ends the server session.
  ///
  /// Idempotent, safe when nothing is registered, and must not be called from
  /// route disposal. Fields are cleared before teardown so a re-entrant call
  /// (for example from `onClose()` of the controller) sees an empty registry.
  Future<void> releaseActive() async {
    final controller = _active ?? _registered();
    _active = null;
    _sessionId = null;
    _role = null;

    if (controller != null) {
      try {
        await controller.releaseNativeResources();
      } catch (_) {
        // Local release is best effort; the server session is unaffected.
      }
    }
    if (Get.isRegistered<RemoteSessionController>()) {
      Get.delete<RemoteSessionController>(force: true);
    }
    await Future<void>.delayed(Duration.zero);
  }

  /// Alias used by logout/unlink paths.
  Future<void> releaseAll() => releaseActive();

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(releaseActive());
    super.onClose();
  }

  RemoteSessionController _acquireFailClosed(
    RemoteSessionController Function() create,
  ) {
    final registered = _registered();
    if (registered != null) return registered;
    final controller = create();
    // Route-scoped on purpose: the page finds it by type and it follows the
    // usual GetX disposal rules. It is never marked active.
    Get.put<RemoteSessionController>(controller);
    return controller;
  }

  void _ensureRegistered(RemoteSessionController controller) {
    final registered = _registered();
    if (identical(registered, controller)) return;
    if (registered != null) {
      // A stale registration of the same type would block Get.put.
      Get.delete<RemoteSessionController>(force: true);
    }
    Get.put<RemoteSessionController>(controller, permanent: true);
  }

  void _disposeActive() {
    final controller = _active;
    _active = null;
    _sessionId = null;
    _role = null;
    if (controller == null) return;
    // The replaced controller must not keep a capture engine alive. Teardown is
    // asynchronous; its service stop is scoped to that controller's session so
    // it cannot stop a newer foreground service.
    unawaited(controller.releaseNativeResources());
    if (identical(_registered(), controller)) {
      Get.delete<RemoteSessionController>(force: true);
    } else {
      controller.onClose();
    }
  }

  void _disposeStaleRegistration() {
    if (Get.isRegistered<RemoteSessionController>()) {
      Get.delete<RemoteSessionController>(force: true);
    }
  }

  RemoteSessionController? _registered() {
    if (!Get.isRegistered<RemoteSessionController>()) return null;
    return Get.find<RemoteSessionController>();
  }
}
