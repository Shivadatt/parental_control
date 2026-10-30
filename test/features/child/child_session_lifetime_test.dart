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
import 'package:parent_control/features/child/child_session_page.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';
import 'package:parent_control/features/remote_assistance/remote_session_registry.dart';

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

RemoteSession _acceptedSession() => RemoteSession(
      id: 'session-1',
      familyId: 'family-1',
      deviceId: 'device-1',
      parentUserId: 'parent-1',
      childUserId: 'child-1',
      kind: SessionKind.audio,
      status: RemoteSessionStatus.accepted,
      requestedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets(
      'popping and re-pushing the child session route keeps one live '
      'controller and never ends the session', (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repository = _MockRemoteSessionRepository();
    when(() => repository.fetchById('session-1'))
        .thenAnswer((_) async => _acceptedSession());
    when(() => repository.watchSession('session-1'))
        .thenAnswer((_) => const Stream<RemoteSession>.empty());
    when(() => repository.watchSignals('session-1'))
        .thenAnswer((_) => const Stream<List<WebRtcSignal>>.empty());
    when(() => repository.fetchIceConfig('session-1')).thenAnswer(
      (_) async => const IceConfig(iceServers: []),
    );
    when(() => repository.end(sessionId: any(named: 'sessionId')))
        .thenAnswer((_) async {});

    Get.put<RemoteSessionRepository>(repository);
    Get.put<SessionService>(SessionService());
    Get.put<DeviceAdminService>(DeviceAdminService());
    final registry = Get.put<RemoteSessionRegistry>(
      RemoteSessionRegistry(),
      permanent: true,
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(
            name: '/',
            page: () => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Get.toNamed(
                    '/child-session',
                    arguments: <String, dynamic>{
                      'sessionId': 'session-1',
                      'role': 'child',
                    },
                  ),
                  child: const Text('home'),
                ),
              ),
            ),
          ),
          GetPage(
            name: '/child-session',
            page: () => const ChildSessionPage(),
            binding: ChildSessionBinding(),
          ),
        ],
      ),
    );

    Future<void> openSession() async {
      await tester.tap(find.text('home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> popSession() async {
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await openSession();

    final controller = Get.find<RemoteSessionController>();
    expect(find.byType(ChildSessionPage), findsOneWidget);
    expect(controller.isChildRole, isTrue);
    expect(controller.sessionId, 'session-1');
    expect(controller.session.value?.status, RemoteSessionStatus.accepted);
    expect(registry.active, same(controller));
    expect(registry.role, 'child');

    // Pretend the child joined: the peer state must survive the route pop.
    controller.hasActivePeer.value = true;
    controller.isConnected.value = true;
    await tester.pump();
    expect(find.text('Stop sharing'), findsOneWidget);

    for (var cycle = 0; cycle < 3; cycle++) {
      await popSession();

      // Back only pops: no end call, no teardown, previous route is back.
      expect(find.byType(ChildSessionPage), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(Get.isRegistered<RemoteSessionController>(), isTrue);
      expect(Get.find<RemoteSessionController>(), same(controller));
      expect(registry.active, same(controller));
      expect(registry.sessionId, 'session-1');
      expect(controller.isEnding.value, isFalse);
      expect(controller.session.value?.status, RemoteSessionStatus.accepted);
      expect(controller.hasActivePeer.value, isTrue);
      expect(controller.isConnected.value, isTrue);

      await openSession();

      // Re-opening restores the same controller with the same session state;
      // the binding did not create or load a second session.
      expect(find.byType(ChildSessionPage), findsOneWidget);
      expect(Get.find<RemoteSessionController>(), same(controller));
      expect(controller.session.value?.status, RemoteSessionStatus.accepted);
      expect(controller.hasActivePeer.value, isTrue);
      expect(find.text('Stop sharing'), findsOneWidget);
    }

    verifyNever(() => repository.end(sessionId: any(named: 'sessionId')));
    verify(() => repository.fetchById('session-1')).called(1);

    // Only an explicit release disposes the app-scoped controller.
    await popSession();
    unawaited(registry.releaseActive());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(registry.active, isNull);
    expect(Get.isRegistered<RemoteSessionController>(), isFalse);
  });
}
