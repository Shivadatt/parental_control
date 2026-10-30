import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/telemetry.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/safe_zones/safe_zones_controller.dart';

class _MockLocationRepository extends Mock implements LocationRepository {}

class _MockFamilyRepository extends Mock implements FamilyRepository {}

SafeZone _zone(String id) => SafeZone(
      id: id,
      familyId: 'family-1',
      name: 'Home',
      latitude: 51.5,
      longitude: -0.12,
      radiusM: 200,
    );

void main() {
  late _MockLocationRepository location;
  late SafeZonesController controller;

  setUp(() {
    location = _MockLocationRepository();
    controller = SafeZonesController(
      locationRepository: location,
      familyRepository: _MockFamilyRepository(),
      session: SessionService(),
      familyId: 'family-1',
    );
  });

  tearDown(() => controller.onClose());

  test('deleteZone removes the zone once the server confirms deletion',
      () async {
    // The repository now calls family-admin delete_zone; the controller keeps
    // the same success contract: drop the row locally and clear the busy state.
    when(() => location.deleteSafeZone('zone-1')).thenAnswer((_) async {});
    controller.zones.addAll([_zone('zone-1'), _zone('zone-2')]);

    final removed = await controller.deleteZone(_zone('zone-1'));

    expect(removed, isTrue);
    expect(controller.zones.map((zone) => zone.id), ['zone-2']);
    expect(controller.actionError.value, isNull);
    expect(controller.savingZoneId.value, isNull);
    verify(() => location.deleteSafeZone('zone-1')).called(1);
  });

  test('deleteZone keeps the zone and surfaces the server error', () async {
    // A revoked/forbidden server response must not remove the row silently.
    when(() => location.deleteSafeZone('zone-1')).thenThrow(
          const AppException(
            AppErrorCodes.forbidden,
            'A parent in this family is required.',
            statusCode: 403,
          ),
        );
    controller.zones.addAll([_zone('zone-1')]);

    final removed = await controller.deleteZone(_zone('zone-1'));

    expect(removed, isFalse);
    expect(controller.zones, hasLength(1));
    expect(controller.actionError.value?.code, AppErrorCodes.forbidden);
    expect(controller.savingZoneId.value, isNull);
  });

  test('deleteZone ignores a second tap while a delete is in flight', () async {
    when(() => location.deleteSafeZone('zone-1')).thenAnswer((_) async {});
    controller.zones.addAll([_zone('zone-1')]);
    controller.savingZoneId.value = 'zone-1';

    final removed = await controller.deleteZone(_zone('zone-1'));

    expect(removed, isFalse);
    verifyNever(() => location.deleteSafeZone('zone-1'));
  });
}