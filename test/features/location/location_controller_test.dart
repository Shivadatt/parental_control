import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/telemetry.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/features/location/location_controller.dart';

class _MockLocationRepository extends Mock implements LocationRepository {}

LocationEvent _locationEvent({required DateTime recordedAt}) => LocationEvent(
      id: 'location-1',
      deviceId: 'device-1',
      latitude: 51.5074,
      longitude: -0.1278,
      accuracyM: 12,
      recordedAt: recordedAt,
      receivedAt: recordedAt,
    );

void main() {
  late _MockLocationRepository repository;
  late LocationController controller;

  setUp(() {
    repository = _MockLocationRepository();
    when(() => repository.fetchLatestLocation(any()))
        .thenAnswer((_) async => null);
    when(() => repository.fetchHistory(
          deviceId: any(named: 'deviceId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => <LocationEvent>[]);
    controller = LocationController(
      locationRepository: repository,
      deviceId: 'device-1',
      familyId: 'family-1',
    );
  });

  tearDown(() => controller.onClose());

  test('labels a fix older than ten minutes as stale', () async {
    when(() => repository.fetchLatestLocation('device-1')).thenAnswer(
      (_) async => _locationEvent(
        recordedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
    );

    await controller.load();

    expect(controller.latest.value, isNotNull);
    expect(controller.latestIsStale, isTrue);
  });

  test('does not label a recent fix as stale', () async {
    when(() => repository.fetchLatestLocation('device-1')).thenAnswer(
      (_) async => _locationEvent(
        recordedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    );

    await controller.load();

    expect(controller.latest.value, isNotNull);
    expect(controller.latestIsStale, isFalse);
  });

  test('reports no fix honestly when the device has never uploaded', () async {
    await controller.load();

    expect(controller.latest.value, isNull);
    expect(controller.hasNeverReported, isTrue);
    expect(controller.latestIsStale, isFalse);
  });
}
