import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/child/child_session_binding.dart';
import 'package:parent_control/features/remote_assistance/remote_session_binding.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';
import 'package:parent_control/features/remote_assistance/remote_session_registry.dart';

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

class _EventDeviceAdminService extends DeviceAdminService {
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  bool serviceStopped = false;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  void emit(Map<String, dynamic> event) => _events.add(event);

  Future<void> dispose() => _events.close();

  @override
  Future<bool> stopAudioAssistanceService() async {
    serviceStopped = true;
    return true;
  }

  @override
  Future<bool> isAudioAssistanceServiceRunning() async => true;
}

/// Minimal controller: no server load, watchers, timers or media I/O. Only
/// `onClose()` keeps its real behaviour so disposal can be asserted.
class _TestSessionController extends RemoteSessionController {
  _TestSessionController({required super.sessionId, required super.role})
      : super(
          remoteSessionRepository: _MockRemoteSessionRepository(),
          session: SessionService(),
          deviceAdmin: DeviceAdminService(),
        );

  int closeCount = 0;
  int reconcileCalls = 0;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> reconcileAfterResume() async {
    reconcileCalls += 1;
  }

  @override
  void onClose() {
    closeCount += 1;
    super.onClose();
  }
}

RemoteSessionRegistry _registerRegistry() => Get.put<RemoteSessionRegistry>(
      RemoteSessionRegistry(),
      permanent: true,
    );

_TestSessionController _controller(String sessionId, String role) =>
    _TestSessionController(sessionId: sessionId, role: role);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('RemoteSessionRegistry', () {
    test('acquire returns the same instance for the same session and role', () {
      final registry = _registerRegistry();
      final controller = _controller('session-1', 'child');
      var created = 0;

      final first = registry.acquire(
        sessionId: 'session-1',
        role: 'child',
        create: () {
          created += 1;
          return controller;
        },
      );
      final second = registry.acquire(
        sessionId: 'session-1',
        role: 'child',
        create: () {
          created += 1;
          return controller;
        },
      );

      expect(second, same(first));
      expect(created, 1);
      expect(controller.closeCount, 0);
      expect(registry.active, same(first));
      expect(registry.sessionId, 'session-1');
      expect(registry.role, 'child');
      expect(Get.find<RemoteSessionController>(), same(first));
    });

    test('acquiring a different session disposes the previous controller', () {
      final registry = _registerRegistry();
      final previous = _controller('session-1', 'child');
      final next = _controller('session-2', 'child');

      final first = registry.acquire(
        sessionId: 'session-1',
        role: 'child',
        create: () => previous,
      );
      final second = registry.acquire(
        sessionId: 'session-2',
        role: 'child',
        create: () => next,
      );

      expect(first, same(previous));
      expect(second, same(next));
      expect(previous.closeCount, 1);
      expect(next.closeCount, 0);
      expect(registry.active, same(second));
      expect(registry.sessionId, 'session-2');
      expect(registry.role, 'child');
      expect(Get.find<RemoteSessionController>(), same(second));
    });

    test('acquiring a different role for the same session disposes the old '
        'controller', () {
      final registry = _registerRegistry();
      final previous = _controller('session-1', 'child');
      final next = _controller('session-1', 'parent');

      final first = registry.acquire(
        sessionId: 'session-1',
        role: 'child',
        create: () => previous,
      );
      final second = registry.acquire(
        sessionId: 'session-1',
        role: 'parent',
        create: () => next,
      );

      expect(first, same(previous));
      expect(second, same(next));
      expect(previous.closeCount, 1);
      expect(registry.active, same(second));
      expect(registry.role, 'parent');
    });

    test('an empty session id never replaces or disposes the active '
        'controller', () {
      final registry = _registerRegistry();
      final live = _controller('session-1', 'child');

      registry.acquire(
        sessionId: 'session-1',
        role: 'child',
        create: () => live,
      );
      registry.acquire(
        sessionId: '',
        role: 'parent',
        create: () => _controller('', 'parent'),
      );

      expect(live.closeCount, 0);
      expect(registry.active, same(live));
      expect(registry.sessionId, 'session-1');
      expect(registry.role, 'child');
      expect(Get.find<RemoteSessionController>(), same(live));
    });

    test('an empty session id registers a findable fail-closed controller when '
        'nothing is live', () {
      final registry = _registerRegistry();
      final failClosed = _controller('', 'parent');

      final result = registry.acquire(
        sessionId: '',
        role: 'parent',
        create: () => failClosed,
      );

      expect(result, same(failClosed));
      expect(Get.find<RemoteSessionController>(), same(failClosed));
      expect(failClosed.hasContext, isFalse);
      expect(failClosed.isChildRole, isFalse);
      expect(registry.active, isNull);
      expect(registry.sessionId, isNull);
      expect(registry.role, isNull);
    });

    test('releaseActive is idempotent and a later acquire is a fresh '
        'controller', () async {
      final registry = _registerRegistry();
      final previous = _controller('session-1', 'child');
      final next = _controller('session-1', 'child');

      final first = registry.acquire(
        sessionId: 'session-1',
        role: 'child',
        create: () => previous,
      );

      await registry.releaseActive();

      expect(previous.closeCount, 1);
      expect(registry.active, isNull);
      expect(registry.sessionId, isNull);
      expect(registry.role, isNull);
      expect(Get.isRegistered<RemoteSessionController>(), isFalse);

      // Repeated releases (direct and the logout alias) are no-ops.
      await registry.releaseActive();
      await registry.releaseAll();
      expect(previous.closeCount, 1);

      final second = registry.acquire(
        sessionId: 'session-1',
        role: 'child',
        create: () => next,
      );

      expect(first, same(previous));
      expect(second, same(next));
      expect(second, isNot(same(first)));
      expect(next.closeCount, 0);
      expect(registry.active, same(second));
      expect(Get.find<RemoteSessionController>(), same(second));
    });

    test('releaseActive is safe when nothing is registered', () async {
      final registry = _registerRegistry();

      await registry.releaseActive();
      await registry.releaseAll();

      expect(registry.active, isNull);
      expect(registry.sessionId, isNull);
      expect(registry.role, isNull);
    });
  });

  group('session bindings', () {
    late _MockRemoteSessionRepository repository;

    setUp(() {
      repository = _MockRemoteSessionRepository();
      when(() => repository.fetchById('session-1'))
          .thenAnswer((_) async => null);
      Get.put<RemoteSessionRepository>(repository);
      Get.put<SessionService>(SessionService());
      Get.put<DeviceAdminService>(DeviceAdminService());
    });

    test('remote session binding without a role stays deny-by-default '
        'view-only', () {
      Get.routing.args = <String, dynamic>{'sessionId': 'session-1'};

      RemoteSessionBinding().dependencies();

      final controller = Get.find<RemoteSessionController>();
      expect(controller.sessionId, 'session-1');
      expect(controller.role, 'view-only');
      expect(controller.isValidRole, isFalse);
      expect(controller.isViewOnly, isTrue);
      expect(controller.isChildRole, isFalse);
      expect(controller.canJoin, isFalse);
      expect(Get.find<RemoteSessionRegistry>().active, same(controller));
    });

    test('child session binding without the child role fails closed', () {
      Get.routing.args = <String, dynamic>{'sessionId': 'session-1'};

      ChildSessionBinding().dependencies();

      final controller = Get.find<RemoteSessionController>();
      expect(controller.isChildRole, isFalse);
      expect(controller.hasContext, isFalse);
      expect(Get.find<RemoteSessionRegistry>().active, isNull);
    });

    testWidgets('popping the bound session route keeps the controller alive',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/',
          getPages: [
            GetPage(
              name: '/',
              page: () => const Scaffold(body: Text('home')),
            ),
            GetPage(
              name: '/session',
              page: () => const Scaffold(body: Text('session')),
              binding: RemoteSessionBinding(),
            ),
          ],
        ),
      );

      Get.toNamed(
        '/session',
        arguments: <String, dynamic>{
          'sessionId': 'session-1',
          'role': 'child',
        },
      );
      await tester.pumpAndSettle();

      final controller = Get.find<RemoteSessionController>();
      expect(controller.isChildRole, isTrue);
      expect(controller.sessionId, 'session-1');
      expect(find.text('session'), findsOneWidget);

      Get.back();
      await tester.pumpAndSettle();

      // The route is gone but the consented session controller is not: a
      // Back press may not end a live microphone session.
      expect(find.text('session'), findsNothing);
      expect(Get.isRegistered<RemoteSessionController>(), isTrue);
      expect(Get.find<RemoteSessionController>(), same(controller));
      expect(Get.find<RemoteSessionRegistry>().active, same(controller));
      expect(controller.isEnding.value, isFalse);
    });

    test('backgrounding never tears down; resuming reconciles the same '
        'controller', () {
      final registry = _registerRegistry();
      final controller = _controller('session-1', 'child');
      final active = registry.acquire(
        sessionId: 'session-1',
        role: 'child',
        create: () => controller,
      );

      registry.didChangeAppLifecycleState(AppLifecycleState.inactive);
      registry.didChangeAppLifecycleState(AppLifecycleState.hidden);
      registry.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Home, screen lock and the background do not withdraw consent.
      expect(controller.reconcileCalls, 0);
      expect(controller.closeCount, 0);
      expect(registry.active, same(active));
      expect(Get.find<RemoteSessionController>(), same(active));

      registry.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Returning reconciles the session it already owns; it never creates a
      // second controller.
      expect(controller.reconcileCalls, 1);
      expect(registry.active, same(active));
    });
  });

  group('detached child UI', () {
    test('a detached UI never ends the session or stops the microphone '
        'service', () async {
      final repository = _MockRemoteSessionRepository();
      when(() => repository.fetchById('session-1')).thenAnswer(
        (_) async => RemoteSession(
          id: 'session-1',
          familyId: 'family-1',
          deviceId: 'device-1',
          parentUserId: 'parent-1',
          childUserId: 'child-1',
          kind: SessionKind.audio,
          status: RemoteSessionStatus.accepted,
          requestedAt: DateTime.now().subtract(const Duration(minutes: 2)),
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        ),
      );
      when(() => repository.watchSession('session-1'))
          .thenAnswer((_) => const Stream<RemoteSession>.empty());
      when(() => repository.watchSignals('session-1'))
          .thenAnswer((_) => const Stream<List<WebRtcSignal>>.empty());
      when(() => repository.fetchIceConfig('session-1')).thenAnswer(
        (_) async => const IceConfig(iceServers: []),
      );

      final deviceAdmin = _EventDeviceAdminService();
      final controller = RemoteSessionController(
        remoteSessionRepository: repository,
        session: SessionService(),
        deviceAdmin: deviceAdmin,
        sessionId: 'session-1',
        role: 'child',
      );
      addTearDown(() {
        controller.onClose();
        return deviceAdmin.dispose();
      });

      await controller.load();
      expect(controller.session.value?.status, RemoteSessionStatus.accepted);

      deviceAdmin.emit({
        'type': 'audio_assistance_detached',
        'reason': 'task_removed_active',
        'sessionId': 'session-1',
      });
      await pumpEventQueue();
      expect(controller.childUiDetached.value, isTrue);

      // An older APK still reports a Recents swipe as a stopped service.
      deviceAdmin.emit({
        'type': 'audio_assistance_stopped',
        'reason': 'task_removed',
        'sessionId': 'session-1',
      });
      await pumpEventQueue();

      expect(controller.childUiDetached.value, isTrue);
      expect(controller.session.value?.status, RemoteSessionStatus.accepted);
      expect(controller.isEnding.value, isFalse);
      expect(controller.endError, isNull);
      expect(deviceAdmin.serviceStopped, isFalse);
      verifyNever(
        () => repository.end(
          sessionId: 'session-1',
          reason: 'task_removed',
        ),
      );
    });
  });
}
