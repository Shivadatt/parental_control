import 'dart:async';

import 'package:flutter/widgets.dart';
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
      retryDelayProvider: (_) => Duration.zero,
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

  test('retries subscription with bounded backoff on stream error', () async {
    final streamController = StreamController<List<SafetyAlert>>.broadcast();
    when(() => repository.watchAlerts('family-1'))
        .thenAnswer((_) => streamController.stream);

    final retryController = SafetyAlertsController(
      alertRepository: repository,
      familyId: 'family-1',
      retryDelayProvider: (_) => Duration.zero,
    );
    retryController.onInit();
    addTearDown(() {
      retryController.onClose();
      streamController.close();
    });

    expect(retryController.reconnectAttempts, equals(0));

    // Emit 1st error -> triggers attempt 1
    streamController.addError(
      const AppException(AppErrorCodes.network, 'Disconnected'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(retryController.reconnectAttempts, equals(1));
    expect(retryController.realtimeError.value, isNull);

    // Emit 2nd error -> triggers attempt 2
    streamController.addError(
      const AppException(AppErrorCodes.network, 'Disconnected'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(retryController.reconnectAttempts, equals(2));
    expect(retryController.realtimeError.value, isNull);

    // Emit 3rd error -> triggers attempt 3
    streamController.addError(
      const AppException(AppErrorCodes.network, 'Disconnected'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(retryController.reconnectAttempts, equals(3));
    expect(retryController.realtimeError.value, isNull);

    // Emit 4th error -> retries exhausted, surfaces error
    streamController.addError(
      const AppException(AppErrorCodes.network, 'Disconnected permanently'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(retryController.realtimeError.value, isNotNull);
    expect(retryController.realtimeError.value?.message,
        contains('Disconnected permanently'));
  });

  test('resumed lifecycle triggers reconnect when disconnected', () async {
    final streamController = StreamController<List<SafetyAlert>>.broadcast();
    when(() => repository.watchAlerts('family-1'))
        .thenAnswer((_) => streamController.stream);

    final lifecycleController = SafetyAlertsController(
      alertRepository: repository,
      familyId: 'family-1',
      retryDelayProvider: (_) => Duration.zero,
    );
    lifecycleController.onInit();
    addTearDown(() {
      lifecycleController.onClose();
      streamController.close();
    });

    // Exhaust retries so it is in error state
    for (var i = 0; i < 4; i++) {
      streamController.addError(
        const AppException(AppErrorCodes.network, 'Disconnected'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(lifecycleController.realtimeError.value, isNotNull);

    // Simulate app resume
    lifecycleController.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(lifecycleController.reconnectAttempts, equals(0));
    expect(lifecycleController.isWatching.value, isTrue);
  });

  test('manual retryRealtime resets attempts and reconnects', () async {
    final streamController = StreamController<List<SafetyAlert>>.broadcast();
    when(() => repository.watchAlerts('family-1'))
        .thenAnswer((_) => streamController.stream);

    final manualController = SafetyAlertsController(
      alertRepository: repository,
      familyId: 'family-1',
      retryDelayProvider: (_) => Duration.zero,
    );
    manualController.onInit();
    addTearDown(() {
      manualController.onClose();
      streamController.close();
    });

    // Exhaust retries
    for (var i = 0; i < 4; i++) {
      streamController.addError(
        const AppException(AppErrorCodes.network, 'Disconnected'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(manualController.realtimeError.value, isNotNull);

    await manualController.retryRealtime();
    expect(manualController.reconnectAttempts, equals(0));
    expect(manualController.realtimeError.value, isNull);
    expect(manualController.isWatching.value, isTrue);
  });
}
