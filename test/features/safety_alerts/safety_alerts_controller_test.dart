import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/telemetry.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/features/safety_alerts/safety_alerts_controller.dart';

class _MockAlertRepository extends Mock implements AlertRepository {}

SafetyAlert _alert() => SafetyAlert(
      id: 'alert-1',
      familyId: 'family-1',
      deviceId: 'device-1',
      type: SafetyAlertType.geofenceExit,
      severity: AlertSeverity.warning,
      message: 'Left the school safe zone',
      createdAt: DateTime.utc(2026, 1, 1, 12),
      deviceName: 'Child phone',
    );

void main() {
  late _MockAlertRepository repository;
  late SafetyAlertsController controller;

  setUp(() {
    repository = _MockAlertRepository();
    when(() => repository.fetchAlerts(familyId: 'family-1'))
        .thenAnswer((_) async => [_alert()]);
    when(() => repository.watchAlerts('family-1'))
        .thenAnswer((_) => const Stream<List<SafetyAlert>>.empty());
    controller = SafetyAlertsController(
      alertRepository: repository,
      familyId: 'family-1',
    );
  });

  tearDown(() => controller.onClose());

  test('keeps an alert unacknowledged when the server rejects the change',
      () async {
    when(() => repository.acknowledgeAlert('alert-1')).thenThrow(
      const AppException(AppErrorCodes.forbidden, 'Not allowed'),
    );

    await controller.load();
    final succeeded = await controller.acknowledge(controller.alerts.single);

    expect(succeeded, isFalse);
    expect(controller.actionError.value, isNotNull);
    expect(controller.alerts.single.isAcknowledged, isFalse);
  });

  test('updates an alert only after the server confirms acknowledgement',
      () async {
    when(() => repository.acknowledgeAlert('alert-1'))
        .thenAnswer((_) async {});

    await controller.load();
    expect(controller.alerts.single.isAcknowledged, isFalse);

    final succeeded = await controller.acknowledge(controller.alerts.single);

    expect(succeeded, isTrue);
    expect(controller.alerts.single.isAcknowledged, isTrue);
    verify(() => repository.acknowledgeAlert('alert-1')).called(1);
  });
}
