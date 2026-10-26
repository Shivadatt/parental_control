import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/dashboard/dashboard_controller.dart';

class _MockDeviceRepository extends Mock implements DeviceRepository {}

class _MockFamilyRepository extends Mock implements FamilyRepository {}

class _MockPolicyRepository extends Mock implements PolicyRepository {}

void main() {
  late _MockDeviceRepository deviceRepository;
  late _MockFamilyRepository familyRepository;
  late _MockPolicyRepository policyRepository;
  late SessionService session;
  late ConnectivityService connectivity;
  late DashboardController controller;

  const family = Family(
    id: 'family-1',
    name: 'Test Family',
    ownerId: 'parent-1',
    settings: FamilySettings(),
  );
  const child = FamilyMember(
    id: 'member-1',
    familyId: 'family-1',
    userId: 'child-1',
    role: FamilyMemberRole.child,
    status: FamilyMemberStatus.active,
    displayName: 'Sam',
  );

  Device buildDevice() => Device(
        id: 'device-1',
        familyId: family.id,
        childUserId: 'child-1',
        displayName: 'Pixel 8',
        status: DeviceStatus.active,
        lastSeenAt: DateTime.now().subtract(const Duration(minutes: 1)),
        batteryLevel: 67,
        isCharging: false,
        enforcementMode: 'device_owner',
        policyVersion: 3,
        usageAccessGranted: true,
      );

  setUp(() {
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
    session.setActiveFamily(family);
  });

  tearDown(() => controller.onClose());

  test('loads family, child and device with real policy acknowledgement', () async {
    final device = buildDevice();
    final policy = DevicePolicy(
      id: 'policy-3',
      deviceId: device.id,
      version: 3,
      payload: const PolicyPayload(),
      createdAt: DateTime(2025, 1, 1),
      status: PolicyEnforcementStatus.enforced,
      acknowledgedAt: DateTime(2025, 1, 2),
    );
    when(() => familyRepository.fetchMembers(family.id))
        .thenAnswer((_) async => [child]);
    when(() => deviceRepository.fetchDevices(family.id))
        .thenAnswer((_) async => [device]);
    when(() => policyRepository.fetchLatestPolicy(device.id))
        .thenAnswer((_) async => policy);

    await controller.load();

    expect(controller.error.value, isNull);
    expect(controller.family.value?.name, 'Test Family');
    expect(controller.children, hasLength(1));
    expect(controller.devices, hasLength(1));
    expect(controller.displayNameFor(device), 'Sam');
    expect(controller.policySummaryFor(device), contains('Enforced on device'));
    expect(controller.enforcementLabelFor(device), contains('Device Owner'));
    expect(controller.isEmpty, isFalse);
    expect(controller.lastRefreshedAt.value, isNotNull);
  });

  test('shows an honest empty state when no family exists', () async {
    session.setActiveFamily(null);
    when(() => familyRepository.fetchMyFamilies())
        .thenAnswer((_) async => const <Family>[]);

    await controller.load();

    expect(controller.error.value, isNull);
    expect(controller.isEmpty, isTrue);
    expect(controller.devices, isEmpty);
    expect(controller.children, isEmpty);
    expect(controller.familyName, 'No family yet');
  });

  test('keeps loaded devices when offline and flags offline state', () async {
    final device = buildDevice();
    when(() => familyRepository.fetchMembers(family.id))
        .thenAnswer((_) async => [child]);
    when(() => deviceRepository.fetchDevices(family.id))
        .thenAnswer((_) async => [device]);
    when(() => policyRepository.fetchLatestPolicy(device.id))
        .thenAnswer((_) async => null);

    await controller.load();
    expect(controller.devices, hasLength(1));

    connectivity.isOnline.value = false;
    await controller.refresh();
    expect(controller.devices, hasLength(1));
    expect(controller.isOffline.value, isTrue);
  });
}
