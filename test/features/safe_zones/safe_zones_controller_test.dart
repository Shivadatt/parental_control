import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/safe_zones/safe_zones_controller.dart';

class _MockLocationRepository extends Mock implements LocationRepository {}

class _MockFamilyRepository extends Mock implements FamilyRepository {}

void main() {
  late SafeZonesController controller;

  setUp(() {
    controller = SafeZonesController(
      locationRepository: _MockLocationRepository(),
      familyRepository: _MockFamilyRepository(),
      session: SessionService(),
      familyId: 'family-1',
    );
  });

  tearDown(() => controller.onClose());

  test('accepts a radius only between 50 and 5000 metres', () {
    expect(controller.validateRadius(null), isNotNull);
    expect(controller.validateRadius('not-a-number'), isNotNull);
    expect(controller.validateRadius('49.9'), isNotNull);
    expect(controller.validateRadius('50'), isNull);
    expect(controller.validateRadius('2500'), isNull);
    expect(controller.validateRadius('5000'), isNull);
    expect(controller.validateRadius('5001'), isNotNull);
  });
}
