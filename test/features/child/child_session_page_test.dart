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
  bool captureActive = false;
  final RxBool checkingAudio = false.obs;
  final RxBool audioNotFlowing = false.obs;
  String? failure;
  int stopCalls = 0;

  @override
  bool get isMediaLive => mediaLive;

  @override
  bool get isCaptureActive => captureActive;

  @override
  bool get isCheckingAudio => checkingAudio.value;

  @override
  bool get audioUnavailable => audioNotFlowing.value;

  @override
  String? get endError => failure;

  /// The page tests never hit the server, open watchers or start the ticker.
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<bool> withdrawConsent() async {
    stopCalls += 1;
    if (failure != null) return false;
    hasActivePeer.value = false;
    isConnected.value = false;
    mediaLive = false;
    captureActive = false;
    isMediaFlowing.value = false;
    checkingAudio.value = false;
    audioNotFlowing.value = false;
    sharingStopped.value = true;
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

/// Opens the page on a surface tall enough that the whole ListView (including
/// the End session button) is laid out, so the tests can assert on it.
Future<void> _openPage(
  WidgetTester tester, {
  Size size = const Size(600, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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

  testWidgets('back pops the route without ending a live session',
      (tester) async {
    controller = _TestSessionController(
      state: _session(status: RemoteSessionStatus.active),
    );
    controller.hasActivePeer.value = true;
    controller.isConnected.value = true;
    controller.captureActive = true;
    controller.mediaLive = true;
    controller.isMediaFlowing.value = true;
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    // Only the explicit Stop sharing button turns the microphone off.
    expect(find.text('Stop sharing'), findsOneWidget);
    expect(
      find.textContaining('microphone keeps running while you use other'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // No confirmation dialog, no stop call, and the previous route is back.
    expect(find.text('Leave and end the session?'), findsNothing);
    expect(find.byType(ChildSessionPage), findsNothing);
    expect(find.text('open session'), findsOneWidget);
    expect(controller.stopCalls, 0);
    expect(Get.isRegistered<RemoteSessionController>(), isTrue);
    expect(Get.find<RemoteSessionController>(), same(controller));
    expect(controller.session.value?.status, RemoteSessionStatus.active);
    expect(controller.hasActivePeer.value, isTrue);
    expect(controller.isEnding.value, isFalse);
  });

  testWidgets('disposing the page widget never stops an authorized session',
      (tester) async {
    controller = _TestSessionController(
      state: _session(status: RemoteSessionStatus.active),
    );
    controller.hasActivePeer.value = true;
    controller.isConnected.value = true;
    controller.captureActive = true;
    controller.mediaLive = true;
    controller.isMediaFlowing.value = true;
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);
    expect(find.byType(ChildSessionPage), findsOneWidget);

    // Activity/route recreation destroys the widget tree, not the consent.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(controller.stopCalls, 0);
    expect(controller.session.value?.status, RemoteSessionStatus.active);
    expect(controller.hasActivePeer.value, isTrue);
    expect(controller.isMediaFlowing.value, isTrue);
    expect(controller.isEnding.value, isFalse);
    expect(Get.isRegistered<RemoteSessionController>(), isTrue);
    expect(Get.find<RemoteSessionController>(), same(controller));
  });

  testWidgets('Stop sharing confirms, withdraws consent, and keeps the session '
      'open', (tester) async {
    controller = _TestSessionController(
      state: _session(status: RemoteSessionStatus.active),
    );
    controller.hasActivePeer.value = true;
    controller.isConnected.value = true;
    controller.captureActive = true;
    controller.mediaLive = true;
    controller.isMediaFlowing.value = true;
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    await tester.tap(find.text('Stop sharing'));
    await tester.pumpAndSettle();
    expect(find.text('Stop sharing?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Stop sharing'),
      ),
    );
    await _pumpFrames(tester);
    await tester.pumpAndSettle();

    expect(controller.stopCalls, 1);
    expect(find.byType(ChildSessionPage), findsOneWidget);
    expect(find.text('Sharing stopped on this phone'), findsOneWidget);
    // The consent-withdrawal control stays visible for the open session even
    // after it has been used; it must not depend on live media.
    expect(find.text('Stop sharing'), findsOneWidget);
    expect(find.text('End session'), findsNothing);
    expect(controller.session.value?.status, RemoteSessionStatus.active);
    expect(controller.session.value?.endedReason, isNull);
  });

  testWidgets('an active session with no peer keeps Stop sharing visible and '
      'offers no session end', (tester) async {
    controller = _TestSessionController(
      state: _session(status: RemoteSessionStatus.active),
    );
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    expect(find.text('Session is still live'), findsOneWidget);
    expect(find.text('Reconnect microphone'), findsOneWidget);
    expect(find.text('End session'), findsNothing);
    // Consent withdrawal must remain reachable after ICE recovery has torn the
    // media down; it is a local action and leaves the server session open.
    expect(find.text('Stop sharing'), findsOneWidget);
    expect(
      find.textContaining('Only your guardian can end this session'),
      findsOneWidget,
    );
  });

  testWidgets('repeated push and pop cycles reuse the same controller',
      (tester) async {
    controller = _TestSessionController(
      state: _session(status: RemoteSessionStatus.active),
    );
    controller.hasActivePeer.value = true;
    controller.isConnected.value = true;
    controller.captureActive = true;
    controller.mediaLive = true;
    controller.isMediaFlowing.value = true;
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    for (var cycle = 0; cycle < 3; cycle++) {
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ChildSessionPage), findsNothing);

      await tester.tap(find.text('open session'));
      await tester.pumpAndSettle();
      expect(find.byType(ChildSessionPage), findsOneWidget);
      expect(find.text('Microphone is live'), findsOneWidget);
      expect(Get.find<RemoteSessionController>(), same(controller));
    }

    expect(controller.stopCalls, 0);
    expect(controller.session.value?.status, RemoteSessionStatus.active);
    expect(controller.hasActivePeer.value, isTrue);
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
    expect(controller.stopCalls, 0);
  });

  testWidgets('the media card separates an open microphone from audio flow',
      (tester) async {
    controller = _TestSessionController(state: _session());
    controller.hasActivePeer.value = true;
    controller.isConnected.value = false;
    controller.captureActive = true;
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    // The microphone is open before ICE completes. That is not audio live,
    // but it must never be reported as the microphone being off.
    expect(find.text('Microphone is live'), findsNothing);
    expect(find.text('Microphone is on — reconnecting…'), findsOneWidget);
    expect(find.text('Microphone on · connecting…'), findsOneWidget);
    expect(find.text('Microphone off'), findsNothing);
    expect(
      find.text('Stop sharing turns off camera and microphone on this phone.'),
      findsOneWidget,
    );

    controller.isConnected.value = true;
    controller.checkingAudio.value = true;
    await tester.pump();

    expect(find.text('Microphone is on — checking audio…'), findsOneWidget);
    expect(find.text('Microphone on · checking…'), findsOneWidget);
    expect(find.text('Microphone live'), findsNothing);

    controller.checkingAudio.value = false;
    controller.audioNotFlowing.value = true;
    await tester.pump();

    expect(
      find.text('Microphone is on, but audio is not reaching your guardian'),
      findsOneWidget,
    );
    expect(find.text('Microphone on · not flowing'), findsOneWidget);
    expect(find.text('Microphone live'), findsNothing);

    controller.mediaLive = true;
    controller.isMediaFlowing.value = true;
    await tester.pump();

    expect(find.text('Microphone is live'), findsOneWidget);
    expect(find.text('Microphone live'), findsOneWidget);
    expect(find.text('Microphone off'), findsNothing);
  });

  testWidgets('a connected session with the microphone off offers Join',
      (tester) async {
    controller = _TestSessionController(state: _session());
    controller.hasActivePeer.value = true;
    controller.isConnected.value = true;
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    expect(
      find.text('Connected, but the microphone is off on this phone'),
      findsOneWidget,
    );
    expect(find.text('Microphone off'), findsOneWidget);
    expect(find.text('Microphone live'), findsNothing);
    // Capture is off while the session is open, so the visible consent action
    // must be reachable without ending or replacing the session.
    expect(controller.canJoin, isTrue);
    expect(find.text('Join with microphone'), findsOneWidget);
  });

  testWidgets('the media card fits a 320dp wide screen', (tester) async {
    controller = _TestSessionController(state: _session());
    controller.hasActivePeer.value = true;
    controller.isConnected.value = true;
    controller.captureActive = true;
    controller.mediaLive = true;
    controller.isMediaFlowing.value = true;
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
    expect(find.text('Microphone is live'), findsOneWidget);
    expect(
      find.text('Stop sharing turns off camera and microphone on this phone.'),
      findsOneWidget,
    );
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
    expect(find.text('Stop sharing'), findsNothing);
  });
}
