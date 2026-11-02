import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/telemetry.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/safe_zones/safe_zones_controller.dart';

class _MockLocationRepository extends Mock implements LocationRepository {}

class _MockFamilyRepository extends Mock implements FamilyRepository {}

Family _family({String ownerId = 'owner-1'}) {
  return Family(
    id: 'family-1',
    name: 'Test Family',
    ownerId: ownerId,
    settings: const FamilySettings(),
    createdAt: DateTime.utc(2026, 1, 2),
  );
}

FamilyMember _member({
  required String userId,
  FamilyMemberRole role = FamilyMemberRole.parent,
  FamilyMemberStatus status = FamilyMemberStatus.active,
}) {
  return FamilyMember(
    id: 'member-$userId',
    familyId: 'family-1',
    userId: userId,
    role: role,
    status: status,
    displayName: 'Member',
    joinedAt: DateTime.utc(2026, 1, 2),
  );
}

SafeZone _zone() => const SafeZone(
  id: 'zone-1',
  familyId: 'family-1',
  name: 'Home',
  latitude: 51.5,
  longitude: -0.12,
  radiusM: 200,
);

void main() {
  late _MockLocationRepository location;
  late _MockFamilyRepository family;
  late SessionService session;
  late SafeZonesController controller;

  setUp(() {
    location = _MockLocationRepository();
    family = _MockFamilyRepository();
    session = SessionService();
    session.setAuthenticated(
      id: 'parent-2',
      address: 'parent2@example.com',
      verified: true,
    );
    when(
      () => location.fetchSafeZones('family-1'),
    ).thenAnswer((_) async => const <SafeZone>[]);
    controller = SafeZonesController(
      locationRepository: location,
      familyRepository: family,
      session: session,
      familyId: 'family-1',
    );
  });

  tearDown(() => controller.onClose());

  Future<void> load({
    Family? familyRow,
    List<FamilyMember>? members,
    Object? membersFailure,
  }) async {
    when(() => family.fetchFamily('family-1')).thenAnswer((_) async => familyRow);
    if (membersFailure != null) {
      when(() => family.fetchMembers('family-1')).thenThrow(membersFailure);
    } else {
      when(
        () => family.fetchMembers('family-1'),
      ).thenAnswer((_) async => members ?? const <FamilyMember>[]);
    }
    await controller.load();
  }

  test('an active parent who is not the owner can manage zones', () async {
    // Mirrors the server rule: family-admin delete_zone and upsert accept any
    // active parent (assertFamilyParent + canDeleteZone), not only the owner.
    await load(
      familyRow: _family(),
      members: [_member(userId: 'owner-1'), _member(userId: 'parent-2')],
    );

    expect(controller.myMembership.value?.userId, 'parent-2');
    expect(controller.canManage, isTrue);
    expect(controller.familyError.value, isNull);
  });

  test('a child member of the family cannot manage zones', () async {
    await load(
      familyRow: _family(),
      members: [
        _member(userId: 'owner-1'),
        _member(userId: 'parent-2', role: FamilyMemberRole.child),
      ],
    );

    expect(controller.canManage, isFalse);
  });

  test('a removed parent cannot manage zones', () async {
    await load(
      familyRow: _family(),
      members: [
        _member(userId: 'owner-1'),
        _member(userId: 'parent-2', status: FamilyMemberStatus.removed),
      ],
    );

    expect(controller.canManage, isFalse);
  });

  test('saveZone refuses a caller the server would reject', () async {
    await load(
      familyRow: _family(),
      members: [
        _member(userId: 'owner-1'),
        _member(userId: 'parent-2', role: FamilyMemberRole.child),
      ],
    );

    final saved = await controller.saveZone(
      name: 'School',
      latitude: 51.5,
      longitude: -0.12,
      radiusM: 200,
      active: true,
    );

    expect(saved, isFalse);
    expect(controller.actionError.value?.code, AppErrorCodes.forbidden);
    clearInteractions(location);
    verifyZeroInteractions(location);
  });

  test('a membership read failure falls back to the owner gate', () async {
    await load(
      familyRow: _family(ownerId: 'parent-2'),
      membersFailure: const AppException(
        AppErrorCodes.network,
        'Could not read family members.',
      ),
    );

    expect(controller.myMembership.value, isNull);
    expect(controller.family.value?.id, 'family-1');
    expect(controller.canManage, isTrue);
    expect(controller.familyError.value?.code, AppErrorCodes.network);
  });

  test('a failed membership read keeps the zones that loaded', () async {
    when(
      () => location.fetchSafeZones('family-1'),
    ).thenAnswer((_) async => [_zone()]);

    await load(
      membersFailure: const AppException(
        AppErrorCodes.network,
        'Could not read family members.',
      ),
    );

    expect(controller.error.value, isNull);
    expect(controller.zones.map((zone) => zone.id), ['zone-1']);
    expect(controller.canManage, isFalse);
  });
}
