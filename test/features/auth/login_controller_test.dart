import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/auth/auth_session_flow.dart';
import 'package:parent_control/features/auth/controllers/login_controller.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerRepositoryFallbacks);

  late MockAuthRepository auth;
  late MockFamilyRepository families;
  late MockLocalSettingsService settings;
  late SessionService session;
  late ConnectivityService connectivity;
  late LoginController controller;

  setUp(() {
    Get.testMode = true;
    auth = MockAuthRepository();
    families = MockFamilyRepository();
    settings = MockLocalSettingsService();
    session = SessionService();
    connectivity = ConnectivityService();
    controller = LoginController(
      authRepository: auth,
      familyRepository: families,
      session: session,
      settings: settings,
      connectivity: connectivity,
    );
    when(() => settings.activeFamilyId).thenReturn(null);
    when(() => settings.setActiveFamilyId(any())).thenAnswer((_) async {});
    when(() => settings.setCachedRole(any())).thenAnswer((_) async {});
    when(
      () => auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(Get.reset);

  test('unverified accounts are routed to verification and keep no profile',
      () async {
    when(() => auth.currentUserId).thenReturn('user-1');
    when(() => auth.currentEmail).thenReturn('alex@example.com');
    when(() => auth.isEmailVerified).thenReturn(false);

    final destination = await controller.signIn(
      email: 'alex@example.com',
      password: 'secret123',
    );

    expect(destination, SignedInDestination.verifyEmail);
    expect(controller.error.value, isNull);
    expect(session.emailVerified.value, isFalse);
    expect(session.profile.value, isNull);
    verifyNever(() => auth.fetchProfile());
  });

  test('verified accounts without a server role are sent to role lock',
      () async {
    when(() => auth.currentUserId).thenReturn('user-1');
    when(() => auth.currentEmail).thenReturn('alex@example.com');
    when(() => auth.isEmailVerified).thenReturn(true);
    when(() => auth.fetchProfile()).thenAnswer(
      (_) async => testProfile(role: ProfileRole.unset),
    );

    final destination = await controller.signIn(
      email: 'alex@example.com',
      password: 'secret123',
    );

    expect(destination, SignedInDestination.chooseRole);
    expect(session.profile.value?.role, ProfileRole.unset);
    expect(session.needsRoleSelection, isTrue);
    verifyNever(() => families.fetchMyFamilies());
    verifyNever(
      () => auth.setInitialRole(
        role: any(named: 'role'),
        displayName: any(named: 'displayName'),
      ),
    );
  });

  test('verified parents land on the parent shell with the server family',
      () async {
    final family = testFamily();
    when(() => auth.currentUserId).thenReturn('user-1');
    when(() => auth.currentEmail).thenReturn('alex@example.com');
    when(() => auth.isEmailVerified).thenReturn(true);
    when(() => auth.fetchProfile()).thenAnswer((_) async => testProfile());
    when(() => families.fetchMyFamilies()).thenAnswer((_) async => [family]);

    final destination = await controller.signIn(
      email: 'alex@example.com',
      password: 'secret123',
    );

    expect(destination, SignedInDestination.parentShell);
    expect(session.isParent, isTrue);
    expect(session.activeFamily.value?.id, family.id);
    verifyNever(
      () => auth.setInitialRole(
        role: any(named: 'role'),
        displayName: any(named: 'displayName'),
      ),
    );
  });

  test('an unconfirmed email error opens verification without a form error',
      () async {
    when(
      () => auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(
      const AppException('email_not_confirmed', 'Email is not confirmed yet.'),
    );

    final destination = await controller.signIn(
      email: 'alex@example.com',
      password: 'secret123',
    );

    expect(destination, SignedInDestination.verifyEmail);
    expect(controller.error.value, isNull);
    verifyNever(() => auth.fetchProfile());
  });

  test('invalid credentials stay on the form with the server error', () async {
    when(
      () => auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(
      const AppException(AppErrorCodes.unauthorized, 'Invalid email or password.'),
    );

    final destination = await controller.signIn(
      email: 'alex@example.com',
      password: 'secret123',
    );

    expect(destination, isNull);
    expect(controller.error.value?.code, AppErrorCodes.unauthorized);
    expect(controller.isSubmitting.value, isFalse);
    verifyNever(() => auth.fetchProfile());
  });

  test('offline sign-in never calls the repository', () async {
    connectivity.isOnline.value = false;

    final destination = await controller.signIn(
      email: 'alex@example.com',
      password: 'secret123',
    );

    expect(destination, isNull);
    expect(controller.error.value?.code, AppErrorCodes.network);
    verifyNever(
      () => auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  test('invalid input is rejected before any network call', () async {
    final destination = await controller.signIn(
      email: 'not-an-email',
      password: 'short',
    );

    expect(destination, isNull);
    expect(controller.error.value?.code, AppErrorCodes.validation);
    verifyNever(
      () => auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });
}
