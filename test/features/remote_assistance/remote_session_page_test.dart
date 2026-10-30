import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/remote_assistance/remote_session_controller.dart';
import 'package:parent_control/features/remote_assistance/remote_session_page.dart';

class _MockRemoteSessionRepository extends Mock
    implements RemoteSessionRepository {}

/// Parent-side page state is driven explicitly so the test covers the leave
/// state machine without the media stack.
class _TestSessionController extends RemoteSessionController {
  _TestSessionController({required RemoteSession state})
      : super(
          remoteSessionRepository: _MockRemoteSessionRepository(),
          session: SessionService(),
          deviceAdmin: DeviceAdminService(),
          sessionId: state.id,
          role: 'parent',
        ) {
    session.value = state;
    isLoading.value = false;
  }

  bool mediaLive = false;
  final RxBool checkingAudio = false.obs;
  String? failure;
  int endCalls = 0;

  @override
  bool get isMediaLive => mediaLive;

  @override
  bool get isCheckingAudio => checkingAudio.value;

  @override
  String? get endError => failure;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<bool> endSession() async {
    endCalls += 1;
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
        endedReason: 'ended_by_parent',
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
  String? endedReason,
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
      endedReason: endedReason,
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
                  builder: (_) => const RemoteSessionPage(),
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

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  late _TestSessionController controller;

  tearDown(Get.reset);

  testWidgets('leaving ends a session that has no active peer yet',
      (tester) async {
    controller = _TestSessionController(state: _session());
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('End the session and leave?'), findsOneWidget);

    await tester.tap(find.text('End and leave'));
    await _pumpFrames(tester);
    await tester.pumpAndSettle();

    expect(controller.endCalls, 1);
    expect(controller.session.value?.endedReason, 'ended_by_parent');
    expect(find.byType(RemoteSessionPage), findsNothing);
  });

  testWidgets('a failed end keeps the parent on the page and warns',
      (tester) async {
    controller = _TestSessionController(state: _session())
      ..failure = 'The server could not be reached.';
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End and leave'));
    await _pumpFrames(tester);

    expect(controller.endCalls, 1);
    expect(find.byType(RemoteSessionPage), findsOneWidget);
    expect(find.text('The session may still be live'), findsOneWidget);
    expect(find.text('The server could not be reached.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Leave without ending'), findsOneWidget);

    // Leaving anyway needs a second, explicit confirmation.
    await tester.tap(find.text('Leave without ending'));
    await tester.pumpAndSettle();
    expect(find.text('Leave without ending the session?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byType(RemoteSessionPage), findsOneWidget);

    await tester.tap(find.text('Leave without ending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave anyway'));
    await tester.pumpAndSettle();
    expect(find.byType(RemoteSessionPage), findsNothing);
  });

  testWidgets('media banners are hidden once the session has ended',
      (tester) async {
    controller = _TestSessionController(
      state: _session(status: RemoteSessionStatus.ended, endedReason: 'ended'),
    );
    controller.iceConfig.value = const IceConfig(iceServers: []);
    controller.permissionDenied.value = true;
    controller.connectionWarning.value = 'The media connection failed.';
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    expect(find.text('Relay not configured'), findsNothing);
    expect(find.text('Permission denied'), findsNothing);
    expect(find.text('Media connection'), findsNothing);
    expect(
      find.widgetWithText(InfoBanner, 'Session ended'),
      findsOneWidget,
    );

    // The same banners come back only while the session is genuinely open.
    controller.session.value = _session();
    await tester.pump();

    expect(find.text('Relay not configured'), findsOneWidget);
    expect(find.text('Permission denied'), findsOneWidget);

    // A lapsed pending request is just as stale: no live-media advice is shown.
    controller.session.value = _session(
      status: RemoteSessionStatus.requested,
      expiresIn: const Duration(minutes: -1),
    );
    await tester.pump();

    expect(find.text('Relay not configured'), findsNothing);
    expect(
      find.widgetWithText(InfoBanner, 'Request expired'),
      findsWidgets,
    );
  });

  testWidgets('the audio card only claims live audio when it is live',
      (tester) async {
    controller = _TestSessionController(state: _session());
    controller.hasActivePeer.value = true;
    controller.isConnected.value = false;
    Get.put<RemoteSessionController>(controller);
    await _openPage(tester);

    expect(find.text('One-way audio live'), findsNothing);
    expect(find.text('Connecting to the child device…'), findsOneWidget);
    expect(find.text('Audio not live'), findsOneWidget);

    controller.isConnected.value = true;
    controller.checkingAudio.value = true;
    await tester.pump();

    expect(find.text('One-way audio live'), findsNothing);
    expect(find.text('Checking audio…'), findsOneWidget);
    expect(find.text('Audio checking…'), findsOneWidget);
    expect(find.text('Connecting media…'), findsOneWidget);
    expect(find.text('Media connected'), findsNothing);

    controller.checkingAudio.value = false;
    await tester.pump();

    expect(find.text('One-way audio live'), findsNothing);
    expect(find.text('Audio unavailable'), findsOneWidget);
    expect(find.text('Audio not live'), findsOneWidget);

    controller.mediaLive = true;
    controller.isMediaFlowing.value = true;
    await tester.pump();

    expect(find.text('Media connected'), findsOneWidget);
    expect(find.text('One-way audio live'), findsOneWidget);
    expect(find.text('Audio live'), findsOneWidget);
  });
}
