import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/devices/devices_controller.dart';

import '../auth/fakes.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

Device _device() => Device(
  id: 'device-1',
  familyId: 'family-1',
  childUserId: 'child-1',
  displayName: 'realme RMX2161',
  status: DeviceStatus.active,
);

void main() {
  setUpAll(registerRepositoryFallbacks);

  test(
    'a newly approved child device appears without a manual refresh',
    () async {
      final devices = _MockDeviceRepository();
      final families = MockFamilyRepository();
      final session = SessionService()..setActiveFamily(testFamily());
      final connectivity = ConnectivityService();
      var fetches = 0;
      when(() => devices.fetchDevices('family-1')).thenAnswer((_) async {
        fetches += 1;
        return fetches == 1 ? const <Device>[] : [_device()];
      });
      final controller = DevicesController(
        deviceRepository: devices,
        familyRepository: families,
        session: session,
        connectivity: connectivity,
        refreshInterval: const Duration(milliseconds: 20),
      );
      addTearDown(controller.onClose);

      controller.onInit();
      await pumpEventQueue();
      expect(controller.devices, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.devices, hasLength(1));
      expect(controller.devices.single.displayName, 'realme RMX2161');
      expect(fetches, greaterThan(1));
    },
  );

  test('the poll stops when the controller is disposed', () async {
    final devices = _MockDeviceRepository();
    final families = MockFamilyRepository();
    final session = SessionService()..setActiveFamily(testFamily());
    final connectivity = ConnectivityService();
    var fetches = 0;
    when(() => devices.fetchDevices('family-1')).thenAnswer((_) async {
      fetches += 1;
      return [_device()];
    });
    final controller = DevicesController(
      deviceRepository: devices,
      familyRepository: families,
      session: session,
      connectivity: connectivity,
      refreshInterval: const Duration(milliseconds: 20),
    );

    controller.onInit();
    await pumpEventQueue();
    controller.onClose();
    final callsAtClose = fetches;

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(fetches, callsAtClose);
  });
}
