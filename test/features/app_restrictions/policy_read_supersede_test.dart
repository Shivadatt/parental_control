import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/policy_enforcement.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/app_restrictions/app_restrictions_controller.dart';

/// Phase 4 §5 — the residual Phase 3 left open in `AppRestrictionsController`:
/// a policy read could publish an older version over a newer one, and a policy
/// switch could leave the previous policy's matched report on screen while the
/// status line already named the newer version.
///
/// Everything here is deterministic: no network, no timers, `Completer`s own
/// every interleaving, and all timestamps are fixed.
class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

void main() {
  late _MockDeviceRepository deviceRepository;
  late _MockPolicyRepository policyRepository;
  late AppRestrictionsController controller;

  setUpAll(() => registerFallbackValue(const PolicyPayload()));

  Device buildDevice() => Device(
        id: 'device-1',
        familyId: 'family-1',
        childUserId: 'child-1',
        displayName: 'Pixel 8',
        status: DeviceStatus.active,
        enforcementMode: 'device_owner',
        policyVersion: 6,
      );

  DevicePolicy buildPolicy({
    required String id,
    required int version,
    PolicyEnforcementStatus status = PolicyEnforcementStatus.enforced,
  }) =>
      DevicePolicy(
        id: id,
        deviceId: 'device-1',
        version: version,
        payload: const PolicyPayload(blockedPackages: ['com.instagram.android']),
        createdAt: DateTime(2025, 1, 1),
        status: status,
        acknowledgedAt: DateTime(2025, 1, 2),
      );

  DeviceCommand ackedCommand({
    required String id,
    required String policyId,
    required int version,
    Map<String, dynamic>? result,
  }) =>
      DeviceCommand(
        id: id,
        deviceId: 'device-1',
        type: DeviceCommandType.applyPolicy,
        payload: {'policy_id': policyId, 'version': version},
        status: result == null
            ? DeviceCommandStatus.delivered
            : DeviceCommandStatus.succeeded,
        createdAt: DateTime(2025, 1, 1),
        expiresAt: DateTime(2025, 1, 2),
        ackedAt: result == null ? null : DateTime(2025, 1, 2),
        result: result,
      );

  const provenCounts = <String, dynamic>{
    'desired_count': 2,
    'applied_count': 2,
    'failed_count': 0,
    'enforcement_supported': true,
    'enforcement_mode': 'device_owner',
  };

  setUp(() {
    deviceRepository = _MockDeviceRepository();
    policyRepository = _MockPolicyRepository();
    controller = AppRestrictionsController(
      deviceId: 'device-1',
      deviceRepository: deviceRepository,
      policyRepository: policyRepository,
      connectivity: ConnectivityService(),
    );
    addTearDown(controller.onClose);
    when(() => deviceRepository.fetchDevice('device-1'))
        .thenAnswer((_) async => buildDevice());
    when(() => deviceRepository.fetchReportedApps('device-1'))
        .thenAnswer((_) async => const <InstalledApp>[]);
  });

  test('a late response carrying an older policy cannot roll the screen back',
      () async {
    final slow = Completer<DevicePolicy>();
    var policyCalls = 0;
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async {
      policyCalls += 1;
      return policyCalls == 1
          ? slow.future
          : buildPolicy(id: 'policy-7', version: 7);
    });
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => const <DeviceCommand>[]);

    final first = controller.refreshPolicy();
    await controller.refreshPolicy();
    expect(controller.currentVersion, 7);

    // The first read was superseded, and its payload is an OLDER version: it
    // must not reach the screen.
    slow.complete(buildPolicy(id: 'policy-6', version: 6));
    await first;

    expect(controller.currentVersion, 7);
    expect(controller.latestPolicy.value?.id, 'policy-7');
    expect(controller.savedPolicy.value?.id, 'policy-7');
  });

  test('a genuinely newer policy from a superseded read is still published',
      () async {
    final slow = Completer<DevicePolicy>();
    var policyCalls = 0;
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async {
      policyCalls += 1;
      return policyCalls == 1
          ? slow.future
          : buildPolicy(id: 'policy-7', version: 7);
    });
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => const <DeviceCommand>[]);

    final first = controller.refreshPolicy();
    await controller.refreshPolicy();
    expect(controller.currentVersion, 7);

    // Superseded, but it carries a NEWER version than anything displayed, so
    // dropping it would hide real server state.
    slow.complete(buildPolicy(id: 'policy-8', version: 8));
    await first;

    expect(controller.currentVersion, 8);
    expect(controller.latestPolicy.value?.id, 'policy-8');
  });

  test('a late failure from a superseded read is not shown as the current error',
      () async {
    final slow = Completer<DevicePolicy>();
    var policyCalls = 0;
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async {
      policyCalls += 1;
      return policyCalls == 1
          ? slow.future
          : buildPolicy(id: 'policy-7', version: 7);
    });
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => const <DeviceCommand>[]);

    final first = controller.refreshPolicy();
    await controller.refreshPolicy();
    expect(controller.saveError.value, isNull);

    slow.completeError(const AppException(
      AppErrorCodes.unknown,
      'The policy could not be loaded.',
    ));
    await first;

    // The read that actually failed is not the one on screen: the newer policy
    // stands, and no error is reported for it.
    expect(controller.currentVersion, 7);
    expect(controller.saveError.value, isNull);
  });

  test('a policy switch clears the previous policy\'s counts before its own '
      'read resolves, so no report can prove the wrong version', () async {
    // Step 1: v6 is displayed with a matched report, so enforcement is proven.
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => buildPolicy(id: 'policy-6', version: 6));
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => [
              ackedCommand(
                id: 'command-6',
                policyId: 'policy-6',
                version: 6,
                result: provenCounts,
              ),
            ]);
    await controller.load();
    expect(controller.enforcementCorrelation, PolicyReportCorrelation.matched);
    expect(controller.enforcementProven, isTrue);
    expect(controller.appliedCountsText, 'Applied to 2 of 2 apps');

    // Step 2: a newer policy arrives while its own report read is still open.
    final pending = Completer<List<DeviceCommand>>();
    var commandCalls = 0;
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => buildPolicy(id: 'policy-7', version: 7));
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) {
      commandCalls += 1;
      return commandCalls == 1 ? pending.future : Future.value(const []);
    });

    final refresh = controller.refreshPolicy();
    // Let the policy read resolve; its report read is the one still pending.
    await Future<void>.delayed(Duration.zero);

    // While only v7's version is known, v6's counts must already be gone: the
    // status line names v7, so any counts shown have to belong to v7.
    expect(controller.currentVersion, 7);
    expect(controller.enforcementReport, isNull);
    expect(controller.enforcementCorrelation, isNull);
    expect(controller.enforcementProven, isFalse);
    expect(controller.appliedCountsText, isNull);

    pending.complete([
      ackedCommand(
        id: 'command-6',
        policyId: 'policy-6',
        version: 6,
        result: provenCounts,
      ),
    ]);
    await refresh;

    // v7's report read found only a v6 command: it is never credited to v7.
    expect(controller.currentVersion, 7);
    expect(controller.enforcementProven, isFalse);
    expect(controller.enforcementReport, isNull);
  });

  test('evidence for the displayed policy is still published normally',
      () async {
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => buildPolicy(id: 'policy-6', version: 6));
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) async => [
              ackedCommand(
                id: 'command-6',
                policyId: 'policy-6',
                version: 6,
                result: provenCounts,
              ),
            ]);

    await controller.load();

    expect(controller.currentVersion, 6);
    expect(controller.enforcementCorrelation, PolicyReportCorrelation.matched);
    expect(controller.enforcementProven, isTrue);
    expect(
      controller.policyStateText,
      contains('Policy v6 enforced on the device — Applied to 2 of 2 apps'),
    );
  });

  test('a read that lands after disposal writes nothing', () async {
    final pending = Completer<List<DeviceCommand>>();
    var commandCalls = 0;
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => buildPolicy(id: 'policy-6', version: 6));
    when(() => policyRepository.fetchRecentCommands('device-1', limit: 10))
        .thenAnswer((_) {
      commandCalls += 1;
      return commandCalls == 1 ? pending.future : Future.value(const []);
    });

    final load = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.onClose();

    pending.complete([
      ackedCommand(
        id: 'command-6',
        policyId: 'policy-6',
        version: 6,
        result: provenCounts,
      ),
    ]);
    await load;

    expect(controller.enforcementEvidence.value, isNull);
    expect(commandCalls, 1);
  });
}
