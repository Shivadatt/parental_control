import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/auth/auth_session_flow.dart';

import 'fakes.dart';

void main() {
  setUpAll(registerRepositoryFallbacks);

  late MockAuthRepository auth;
  late MockFamilyRepository families;
  late MockLocalSettingsService settings;
  late SessionService session;
  late AuthSessionFlow flow;

  setUp(() {
    auth = MockAuthRepository();
    families = MockFamilyRepository();
    settings = MockLocalSettingsService();
    session = SessionService();
    flow = AuthSessionFlow(
      authRepository: auth,
      familyRepository: families,
      session: session,
      settings: settings,
    );
    when(() => settings.activeFamilyId).thenReturn(null);
    when(() => settings.setActiveFamilyId(any())).thenAnswer((_) async {});
    when(() => settings.setCachedRole(any())).thenAnswer((_) async {});
  });

  test('signed-out accounts are cleared and sent back to the entry screen',
      () async {
    when(() => auth.currentUserId).thenReturn(null);
    session.setAuthenticated(
      id: 'stale-user',
      address: 'stale@example.com',
      verified: true,
    );

    final destination = await flow.resolve();

    expect(destination, SignedInDestination.signedOut);
    expect(session.isAuthenticated, isFalse);
    expect(session.email.value, isEmpty);
    verify(() => settings.setActiveFamilyId(null)).called(1);
    verifyNever(() => auth.fetchProfile());
  });

  test('unverified accounts are routed to verification before any profile read',
      () async {
    when(() => auth.currentUserId).thenReturn('user-1');
    when(() => auth.currentEmail).thenReturn('alex@example.com');
    when(() => auth.isEmailVerified).thenReturn(false);
    session.setProfile(testProfile());
    session.setActiveFamily(testFamily());

    final destination = await flow.resolve();

    expect(destination, SignedInDestination.verifyEmail);
    expect(session.email.value, 'alex@example.com');
    expect(session.emailVerified.value, isFalse);
    expect(session.profile.value, isNull);
    expect(session.activeFamily.value, isNull);
    verifyNever(() => auth.fetchProfile());
    verifyNever(() => settings.setCachedRole(any()));
  });

  test('a verified account without a server role is sent to the role lock',
      () async {
    when(() => auth.currentUserId).thenReturn('user-1');
    when(() => auth.currentEmail).thenReturn('alex@example.com');
    when(() => auth.isEmailVerified).thenReturn(true);
    when(() => auth.fetchProfile()).thenAnswer(
      (_) async => testProfile(role: ProfileRole.unset),
    );

    final destination = await flow.resolve();

    expect(destination, SignedInDestination.chooseRole);
    expect(session.profile.value?.role, ProfileRole.unset);
    expect(session.hasChosenRole, isFalse);
    verifyNever(() => settings.setCachedRole(any()));
    verifyNever(() => families.fetchMyFamilies());
  });

  test('a missing server profile never invents a role', () async {
    when(() => auth.currentUserId).thenReturn('user-1');
    when(() => auth.currentEmail).thenReturn('alex@example.com');
    when(() => auth.isEmailVerified).thenReturn(true);
    when(() => auth.fetchProfile()).thenAnswer((_) async => null);

    final destination = await flow.resolve();

    expect(destination, SignedInDestination.chooseRole);
    expect(session.profile.value, isNull);
    expect(session.hasChosenRole, isFalse);
    verifyNever(() => families.fetchMyFamilies());
  });

  test('a parent with no family is sent to setup without a fake family',
      () async {
    when(() => auth.currentUserId).thenReturn('user-1');
    when(() => auth.currentEmail).thenReturn('alex@example.com');
    when(() => auth.isEmailVerified).thenReturn(true);
    when(() => auth.fetchProfile()).thenAnswer((_) async => testProfile());
    when(() => families.fetchMyFamilies()).thenAnswer((_) async => []);

    final destination = await flow.resolve();

    expect(destination, SignedInDestination.familySetup);
    expect(session.activeFamily.value, isNull);
    verify(() => settings.setActiveFamilyId(null)).called(1);
  });

  test('a parent resumes the remembered family returned by the server',
      () async {
    when(() => settings.activeFamilyId).thenReturn('family-2');
    when(() => auth.currentUserId).thenReturn('user-1');
    when(() => auth.currentEmail).thenReturn('alex@example.com');
    when(() => auth.isEmailVerified).thenReturn(true);
    when(() => auth.fetchProfile()).thenAnswer((_) async => testProfile());
    when(() => families.fetchMyFamilies()).thenAnswer(
      (_) async => [
        testFamily(id: 'family-1', name: 'First'),
        testFamily(id: 'family-2', name: 'Second'),
      ],
    );

    final destination = await flow.resolve();

    expect(destination, SignedInDestination.parentShell);
    expect(session.activeFamily.value?.id, 'family-2');
    expect(session.isParent, isTrue);
    verify(() => settings.setActiveFamilyId('family-2')).called(1);
  });

  test('a child goes to the child shell without reading parent families',
      () async {
    when(() => auth.currentUserId).thenReturn('child-1');
    when(() => auth.currentEmail).thenReturn('mia@example.com');
    when(() => auth.isEmailVerified).thenReturn(true);
    when(() => auth.fetchProfile()).thenAnswer(
      (_) async => testProfile(
        id: 'child-1',
        role: ProfileRole.child,
        displayName: 'Mia',
      ),
    );

    final destination = await flow.resolve();

    expect(destination, SignedInDestination.childShell);
    expect(session.profile.value?.role, ProfileRole.child);
    verifyNever(() => families.fetchMyFamilies());
  });
}
