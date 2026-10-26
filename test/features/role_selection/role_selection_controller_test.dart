import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/role_selection/controllers/role_selection_controller.dart';

import '../auth/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerRepositoryFallbacks);

  late MockAuthRepository auth;
  late MockFamilyRepository families;
  late MockLocalSettingsService settings;
  late SessionService session;
  late ConnectivityService connectivity;
  late RoleSelectionController controller;

  setUp(() {
    Get.testMode = true;
    auth = MockAuthRepository();
    families = MockFamilyRepository();
    settings = MockLocalSettingsService();
    session = SessionService();
    session.setAuthenticated(
      id: 'user-1',
      address: 'alex@example.com',
      verified: true,
    );
    connectivity = ConnectivityService();
    controller = RoleSelectionController(
      authRepository: auth,
      familyRepository: families,
      session: session,
      settings: settings,
      connectivity: connectivity,
    );
    when(() => settings.cachedRole).thenReturn('');
    when(() => settings.setCachedRole(any())).thenAnswer((_) async {});
  });

  tearDown(Get.reset);

  test('locking the initial role calls the server exactly once', () async {
    when(
      () => auth.setInitialRole(
        role: ProfileRole.parent,
        displayName: 'Alex',
      ),
    ).thenAnswer(
      (_) async => testProfile(role: ProfileRole.parent, displayName: 'Alex'),
    );

    controller.prepare(lockRequested: true);
    expect(controller.isLockMode.value, isTrue);

    final first = controller.setInitialRole(
      role: ProfileRole.parent,
      displayName: 'Alex',
    );
    final duplicate = controller.setInitialRole(
      role: ProfileRole.parent,
      displayName: 'Alex',
    );

    expect(await duplicate, isFalse);
    expect(await first, isTrue);
    verify(
      () => auth.setInitialRole(
        role: ProfileRole.parent,
        displayName: 'Alex',
      ),
    ).called(1);
    expect(session.profile.value?.role, ProfileRole.parent);
    expect(controller.isSubmitting.value, isFalse);
  });

  test('a prefilled display name comes from the signed-in profile', () {
    session.setProfile(
      testProfile(role: ProfileRole.unset, displayName: 'Alex'),
    );

    controller.prepare(lockRequested: true);

    expect(controller.isLockMode.value, isTrue);
    expect(controller.displayNamePrefill.value, 'Alex');
  });

  test('choosing a role before sign-in only stores a local hint', () async {
    session.clear();
    controller.prepare();

    expect(controller.isLockMode.value, isFalse);
    final saved = await controller.continueToLogin(ProfileRole.child);

    expect(saved, isTrue);
    verify(() => settings.setCachedRole('child')).called(1);
    expect(session.hasChosenRole, isFalse);
    verifyNever(
      () => auth.setInitialRole(
        role: any(named: 'role'),
        displayName: any(named: 'displayName'),
      ),
    );
  });

  test('role assignment is refused outside the lock flow', () async {
    session.clear();
    controller.prepare();

    final result = await controller.setInitialRole(
      role: ProfileRole.parent,
      displayName: 'Alex',
    );

    expect(result, isFalse);
    expect(controller.error.value?.code, AppErrorCodes.forbidden);
    verifyNever(
      () => auth.setInitialRole(
        role: any(named: 'role'),
        displayName: any(named: 'displayName'),
      ),
    );
  });

  test('a blank display name never reaches the server', () async {
    controller.prepare(lockRequested: true);

    final result = await controller.setInitialRole(
      role: ProfileRole.child,
      displayName: '   ',
    );

    expect(result, isFalse);
    expect(controller.error.value?.code, AppErrorCodes.validation);
    verifyNever(
      () => auth.setInitialRole(
        role: any(named: 'role'),
        displayName: any(named: 'displayName'),
      ),
    );
  });

  test('offline locking never calls the server', () async {
    connectivity.isOnline.value = false;
    controller.prepare(lockRequested: true);

    final result = await controller.setInitialRole(
      role: ProfileRole.child,
      displayName: 'Mia',
    );

    expect(result, isFalse);
    expect(controller.error.value?.code, AppErrorCodes.network);
    verifyNever(
      () => auth.setInitialRole(
        role: any(named: 'role'),
        displayName: any(named: 'displayName'),
      ),
    );
  });

  test('a server role error is surfaced unchanged', () async {
    when(
      () => auth.setInitialRole(
        role: ProfileRole.child,
        displayName: 'Mia',
      ),
    ).thenThrow(
      const AppException(AppErrorCodes.forbidden, 'Role is already assigned.'),
    );

    controller.prepare(lockRequested: true);
    final result = await controller.setInitialRole(
      role: ProfileRole.child,
      displayName: 'Mia',
    );

    expect(result, isFalse);
    expect(controller.error.value?.code, AppErrorCodes.forbidden);
    expect(session.hasChosenRole, isFalse);
    verify(
      () => auth.setInitialRole(
        role: ProfileRole.child,
        displayName: 'Mia',
      ),
    ).called(1);
  });
}
