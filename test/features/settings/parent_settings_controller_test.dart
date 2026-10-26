import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/settings/parent_settings_controller.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockLocalSettings extends Mock implements LocalSettingsService {}

class _MockDeviceAdmin extends Mock implements DeviceAdminService {}

void main() {
  late _MockLocalSettings localSettings;
  late SessionService session;
  late ParentSettingsController controller;

  setUp(() {
    localSettings = _MockLocalSettings();
    when(() => localSettings.notificationsEnabled).thenReturn(false);
    when(() => localSettings.locationSharingEnabled).thenReturn(true);

    session = SessionService()
      ..setAuthenticated(
        id: 'parent-1',
        address: 'parent@example.test',
        verified: true,
      )
      ..setProfile(
        const Profile(
          id: 'parent-1',
          role: ProfileRole.parent,
          displayName: 'Parent',
        ),
      )
      ..setActiveFamily(
        const Family(
          id: 'family-1',
          name: 'Our family',
          ownerId: 'parent-1',
          settings: FamilySettings(
            locationRetentionDays: 30,
            usageRetentionDays: 60,
          ),
        ),
      );

    final deviceAdmin = _MockDeviceAdmin();
    when(() => deviceAdmin.isAvailable).thenReturn(false);

    controller = ParentSettingsController(
      authRepository: _MockAuthRepository(),
      session: session,
      localSettings: localSettings,
      deviceAdmin: deviceAdmin,
    );
    controller.syncFromServices();
  });

  tearDown(() => controller.onClose());

  test('shows the signed-in parent, family and local-only preferences', () {
    expect(controller.email.value, 'parent@example.test');
    expect(controller.roleLabel.value, 'Parent');
    expect(controller.emailVerified.value, isTrue);
    expect(controller.familyName.value, 'Our family');
    expect(controller.familyRole.value, 'Owner');
    expect(controller.isFamilyOwner, isTrue);
    expect(controller.retention.value?.locationRetentionDays, 30);
    expect(controller.retention.value?.usageRetentionDays, 60);
    expect(controller.notificationsEnabled.value, isFalse);
    expect(controller.locationReminderEnabled.value, isTrue);
  });

  test('updates a local toggle only after the local save succeeds', () async {
    when(() => localSettings.setNotificationsEnabled(true))
        .thenAnswer((_) async {});

    await controller.setNotificationsEnabled(true);

    expect(controller.actionError.value, isNull);
    expect(controller.notificationsEnabled.value, isTrue);
    verify(() => localSettings.setNotificationsEnabled(true)).called(1);
  });

  test('keeps the previous toggle value when the local save fails', () async {
    when(() => localSettings.setLocationSharingEnabled(false)).thenThrow(
      const AppException(AppErrorCodes.unknown, 'Local storage unavailable'),
    );

    await controller.setLocationReminderEnabled(false);

    expect(controller.actionError.value, isNotNull);
    expect(controller.locationReminderEnabled.value, isTrue);
  });
}
