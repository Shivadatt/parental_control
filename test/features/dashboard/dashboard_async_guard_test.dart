import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/dashboard/dashboard_controller.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockFamilyRepository extends Mock implements FamilyRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

const _family1 = Family(
  id: 'family-1',
  name: 'First Family',
  ownerId: 'parent-1',
  settings: FamilySettings(),
);
const _family2 = Family(
  id: 'family-2',
  name: 'Second Family',
  ownerId: 'parent-1',
  settings: FamilySettings(),
);

const _child1 = FamilyMember(
  id: 'member-1',
  familyId: 'family-1',
  userId: 'child-1',
  role: FamilyMemberRole.child,
  status: FamilyMemberStatus.active,
  displayName: 'Sam',
);
const _child2 = FamilyMember(
  id: 'member-2',
  familyId: 'family-2',
  userId: 'child-2',
  role: FamilyMemberRole.child,
  status: FamilyMemberStatus.active,
  displayName: 'Mia',
);

Device _device(String id, String familyId, String childUserId) => Device(
      id: id,
      familyId: familyId,
      childUserId: childUserId,
      displayName: 'Pixel $id',
      status: DeviceStatus.active,
    );

// Lets a pending fetch advance to the first await it is gated on, without
// depending on wall-clock time.
Future<void> _flush() => Future<void>(() {});

void main() {
  late _MockDeviceRepository deviceRepository;
  late _MockFamilyRepository familyRepository;
  late _MockPolicyRepository policyRepository;
  late SessionService session;
  late ConnectivityService connectivity;
  late DashboardController controller;
  var closedInTest = false;

  setUp(() {
    closedInTest = false;
    deviceRepository = _MockDeviceRepository();
    familyRepository = _MockFamilyRepository();
    policyRepository = _MockPolicyRepository();
    session = SessionService();
    connectivity = ConnectivityService();
    controller = DashboardController(
      deviceRepository: deviceRepository,
      familyRepository: familyRepository,
      policyRepository: policyRepository,
      session: session,
      connectivity: connectivity,
      refreshInterval: null,
    );
  });

  tearDown(() {
    if (!closedInTest) controller.onClose();
  });

  test('a superseded request succeeding does not clobber the newer family',
      () async {
    session.setActiveFamily(_family1);
    final oldGate = Completer<List<Device>>();
    final newGate = Completer<List<Device>>();
    final kept = _device('device-2', 'family-2', 'child-2');
    when(() => familyRepository.fetchMembers('family-1'))
        .thenAnswer((_) async => [_child1]);
    when(() => familyRepository.fetchMembers('family-2'))
        .thenAnswer((_) async => [_child2]);
    when(() => deviceRepository.fetchDevices('family-1'))
        .thenAnswer((_) => oldGate.future);
    when(() => deviceRepository.fetchDevices('family-2'))
        .thenAnswer((_) => newGate.future);
    when(() => policyRepository.fetchLatestPolicy('device-2'))
        .thenAnswer((_) async => null);

    final old = controller.load();
    await _flush();
    session.setActiveFamily(_family2);
    final fresh = controller.load();
    await _flush();

    newGate.complete([kept]);
    await fresh;
    expect(controller.devices.map((d) => d.id), ['device-2']);

    oldGate.complete([_device('device-1', 'family-1', 'child-1')]);
    await old;
    await _flush();

    expect(controller.family.value?.id, 'family-2');
    expect(controller.devices.map((d) => d.id), ['device-2']);
    expect(controller.error.value, isNull);
    expect(controller.isLoading.value, isFalse);
  });

  test('a superseded request failing does not paint the newer family as error',
      () async {
    session.setActiveFamily(_family1);
    final oldGate = Completer<List<Device>>();
    final newGate = Completer<List<Device>>();
    final kept = _device('device-2', 'family-2', 'child-2');
    when(() => familyRepository.fetchMembers('family-1'))
        .thenAnswer((_) async => [_child1]);
    when(() => familyRepository.fetchMembers('family-2'))
        .thenAnswer((_) async => [_child2]);
    when(() => deviceRepository.fetchDevices('family-1'))
        .thenAnswer((_) => oldGate.future);
    when(() => deviceRepository.fetchDevices('family-2'))
        .thenAnswer((_) => newGate.future);
    when(() => policyRepository.fetchLatestPolicy('device-2'))
        .thenAnswer((_) async => null);

    final old = controller.load();
    await _flush();
    session.setActiveFamily(_family2);
    final fresh = controller.load();
    await _flush();

    newGate.complete([kept]);
    await fresh;
    expect(controller.error.value, isNull);

    oldGate.completeError(AppException.network());
    await old;
    await _flush();

    // The UI-02 core: the stale request's failure must not surface over the
    // newer family's loaded state.
    expect(controller.error.value, isNull);
    expect(controller.devices.map((d) => d.id), ['device-2']);
    expect(controller.isLoading.value, isFalse);
  });

  test('a response for a family the user left is dropped and loading cleared',
      () async {
    session.setActiveFamily(_family1);
    final gate = Completer<List<Device>>();
    when(() => familyRepository.fetchMembers('family-1'))
        .thenAnswer((_) async => [_child1]);
    when(() => deviceRepository.fetchDevices('family-1'))
        .thenAnswer((_) => gate.future);
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => null);

    final inFlight = controller.load();
    await _flush();
    session.setActiveFamily(_family2);
    gate.complete([_device('device-1', 'family-1', 'child-1')]);
    await inFlight;
    await _flush();

    expect(controller.devices, isEmpty);
    expect(controller.error.value, isNull);
    expect(controller.isLoading.value, isFalse);
  });

  test('a disposed controller writes no UI state after an in-flight fetch fails',
      () async {
    session.setActiveFamily(_family1);
    final gate = Completer<List<Device>>();
    when(() => familyRepository.fetchMembers('family-1'))
        .thenAnswer((_) async => [_child1]);
    when(() => deviceRepository.fetchDevices('family-1'))
        .thenAnswer((_) => gate.future);
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => null);

    final inFlight = controller.load();
    await _flush();
    await controller.refresh(); // folds a reload onto the in-flight fetch

    var loadingWrites = 0;
    final worker = ever<bool>(controller.isLoading, (_) => loadingWrites++);
    controller.onClose();
    closedInTest = true;

    gate.completeError(AppException.network());
    await inFlight;
    await _flush();

    // Neither the catch nor the finally may touch state after disposal, and
    // the folded reload must not resurrect.
    expect(controller.error.value, isNull);
    expect(controller.devices, isEmpty);
    expect(loadingWrites, 0);

    // A refresh after close is a no-op on UI state.
    await controller.refresh();
    expect(controller.error.value, isNull);

    worker.dispose();
  });

  test('several refresh requests during one fetch coalesce into one reload',
      () async {
    session.setActiveFamily(_family1);
    final gate = Completer<List<Device>>();
    final device = _device('device-1', 'family-1', 'child-1');
    var deviceCalls = 0;
    when(() => familyRepository.fetchMembers('family-1'))
        .thenAnswer((_) async => [_child1]);
    when(() => deviceRepository.fetchDevices('family-1')).thenAnswer((_) {
      deviceCalls++;
      return deviceCalls == 1 ? gate.future : Future.value([device]);
    });
    when(() => policyRepository.fetchLatestPolicy('device-1'))
        .thenAnswer((_) async => null);

    final inFlight = controller.load();
    await _flush();
    await controller.refresh();
    await controller.refresh();
    expect(deviceCalls, 1);

    gate.complete([device]);
    await inFlight;
    await _flush();

    expect(deviceCalls, 2); // exactly one reload despite two refreshes
    expect(controller.devices, hasLength(1));
    expect(controller.error.value, isNull);
  });
}
