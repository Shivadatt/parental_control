import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/local_settings_service.dart';

/// Mocktail doubles for the three repository interfaces owned by this agent.
class MockAuthRepository extends Mock implements AuthRepository {}

class MockFamilyRepository extends Mock implements FamilyRepository {}

class MockPairingRepository extends Mock implements PairingRepository {}

/// Local preferences are mocked so tests never touch SharedPreferences.
class MockLocalSettingsService extends Mock implements LocalSettingsService {}

void registerRepositoryFallbacks() {
  registerFallbackValue(ProfileRole.unset);
  registerFallbackValue(const FamilySettings());
}

Profile testProfile({
  String id = 'user-1',
  ProfileRole role = ProfileRole.parent,
  String displayName = 'Alex',
}) {
  return Profile(id: id, role: role, displayName: displayName);
}

Family testFamily({
  String id = 'family-1',
  String name = 'Test Family',
  String ownerId = 'user-1',
  FamilySettings settings = const FamilySettings(),
}) {
  return Family(
    id: id,
    name: name,
    ownerId: ownerId,
    settings: settings,
    createdAt: DateTime.utc(2026, 1, 2),
  );
}

FamilyMember testMember({
  String id = 'member-1',
  String familyId = 'family-1',
  String userId = 'user-1',
  FamilyMemberRole role = FamilyMemberRole.parent,
  FamilyMemberStatus status = FamilyMemberStatus.active,
  String displayName = 'Alex',
}) {
  return FamilyMember(
    id: id,
    familyId: familyId,
    userId: userId,
    role: role,
    status: status,
    displayName: displayName,
    joinedAt: DateTime.utc(2026, 1, 2),
  );
}

PairingRequest testPairingRequest({
  String id = 'request-1',
  String familyId = 'family-1',
  String familyName = 'Test Family',
  String parentUserId = 'user-1',
  String childUserId = 'child-1',
  PairingRequestStatus status = PairingRequestStatus.pendingChild,
  DateTime? expiresAt,
}) {
  return PairingRequest(
    id: id,
    tokenId: 'token-1',
    familyId: familyId,
    familyName: familyName,
    parentUserId: parentUserId,
    parentDisplayName: 'Alex',
    childUserId: childUserId,
    childDisplayName: 'Mia',
    status: status,
    createdAt: DateTime.utc(2026, 1, 2),
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 10)),
  );
}
