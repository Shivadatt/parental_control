import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/child/child_session_page.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

/// Drives the child page from explicit state so the widget test exercises the
/// page's own leave state machine, not the real media pipeline.
class _TestSessionController extends RemoteSessionController {
  _TestSessionController({required RemoteSession state, super.role = 'child'})
      : super(
          remoteSessionRepository: _MockRemoteSessionRepository(),
          session: SessionService(),
          deviceAdmin: DeviceAdminService(),
          sessionId: state.id,
        ) {
    session.value = state;
    isLoading.value = false;
  }

  bool mediaLive = false;
  String? failure;
  int endCalls = 0;
  final List<String?> endReasons = <String?>[];

  @override
  bool get isMediaLive => mediaLive;

  @override
  String? get endError => failure;

  /// The page tests never hit the server, open watchers or start the ticker.
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<bool> endSession({String? reason}) async {
    endCalls += 1;
    endReasons.add(reason);
    if (failure != null) return false;
    final current = session.value;
    if (current != null && current.status.isOpen) {
      session.value = RemoteSession(
        id: current.id,
        familyId: current.familyId,
        deviceId: current.deviceId,
        parentUserId: current.parentUserId,
        childUserId: current.childUserId,
        kind: current.kind,
        status: RemoteSessionStatus.ended,
        requestedAt: current.requestedAt,
        expiresAt: current.expiresAt,
        acceptedAt: current.acceptedAt,
        endedAt: DateTime.now(),
        endedReason: reason,
        consentRecorded: current.consentRecorded,
      );
    }
    return true;
  }
}

RemoteSession _session({
  RemoteSessionStatus status = RemoteSessionStatus.accepted,
  SessionKind kind = SessionKind.audio,
  Duration expiresIn = const Duration(minutes: 10),
}) =>
    RemoteSession(
      id: 'session-1',
      familyId: 'family-1',
      deviceId: 'device-1',
      parentUserId: 'parent-1',
      childUserId: 'child-1',
      kind: kind,
      status: status,
      requestedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      expiresAt: DateTime.now().add(expiresIn),
    );

Future<void> _openPage(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChildSessionPage(),
                ),
              ),
              child: const Text('open session'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open session'));
  await tester.pumpAndSettle();
}

/// The busy overlay animates, so settle with explicit frames instead of
/// pumpAndSettle while an end attempt is in flight.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  late _TestSessionController controller;

  tearDown(Get.reset);

  testWidgets('back ends the session before the route pops', (tester) async {
    controller = _TestSessionController(state: _session());
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Leave and end the session?'), findsOneWidget);
    expect(find.textContaining('microphone'), findsWidgets);

    await tester.tap(find.text('End and leave'));
    await _pumpFrames(tester);
    await tester.pumpAndSettle();

    expect(controller.endCalls, 1);
    expect(controller.endReasons.single, 'left_screen');
    expect(find.byType(ChildSessionPage), findsNothing);
  });

  testWidgets('a failed end keeps the child on the page with a retry',
      (tester) async {
    controller = _TestSessionController(state: _session())
      ..failure = 'The network is offline.';
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End and leave'));
    await _pumpFrames(tester);

    expect(controller.endCalls, 1);
    expect(find.byType(ChildSessionPage), findsOneWidget);
    expect(find.text('The session is still open'), findsOneWidget);
    expect(find.text('The network is offline.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Stay in session'), findsOneWidget);

    // Retry runs another end attempt instead of leaving silently.
    await tester.tap(find.text('Retry'));
    await _pumpFrames(tester);
    expect(controller.endCalls, 2);
    expect(find.byType(ChildSessionPage), findsOneWidget);
  });

  testWidgets('a terminal session leaves without a confirmation dialog',
      (tester) async {
    controller = _TestSessionController(
      state: _session(status: RemoteSessionStatus.ended),
    );
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Leave and end the session?'), findsNothing);
    expect(find.byType(ChildSessionPage), findsNothing);
    expect(controller.endCalls, 0);
  });

  testWidgets('the media card only claims the microphone is on when it is live',
      (tester) async {
    controller = _TestSessionController(state: _session());
    controller.hasActivePeer.value = true;
    controller.isConnected.value = false;
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    expect(find.text('Microphone is on'), findsNothing);
    expect(
      find.text('Microphone is stopped — not sharing audio'),
      findsOneWidget,
    );
    expect(find.text('Microphone off'), findsOneWidget);
    expect(find.text('Ending stops camera and microphone.'), findsOneWidget);

    controller.mediaLive = true;
    controller.isConnected.value = true;
    await tester.pump();

    expect(find.text('Microphone is on'), findsOneWidget);
    expect(find.text('Microphone live'), findsOneWidget);
    expect(find.text('Microphone off'), findsNothing);
  });

  testWidgets('the media card fits a 320dp wide screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    controller = _TestSessionController(state: _session());
    controller.hasActivePeer.value = true;
    controller.isConnected.value = true;
    controller.mediaLive = true;
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Microphone is on'), findsOneWidget);
    expect(find.text('Ending stops camera and microphone.'), findsOneWidget);
  });

  testWidgets('the child page refuses a controller that is not the child role',
      (tester) async {
    controller = _TestSessionController(
      state: _session(),
      role: 'parent',
    );
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    expect(find.text('Not available for this account'), findsOneWidget);
    expect(find.text('End session'), findsNothing);
  });
}
