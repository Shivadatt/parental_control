import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/settings/account_privacy_repository.dart';
import 'package:parent_control/features/settings/parent_settings_controller.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockLocalSettings extends Mock implements LocalSettingsService {}

class _MockDeviceAdmin extends Mock implements DeviceAdminService {}

class _MockPrivacyRepository extends Mock
    implements AccountPrivacyRepository {}

void main() {
  late _MockPrivacyRepository privacy;
  late _MockLocalSettings localSettings;
  late SessionService session;
  late ParentSettingsController controller;

  setUpAll(() {
    Get.testMode = true;
  });

  setUp(() {
    privacy = _MockPrivacyRepository();
    localSettings = _MockLocalSettings();
    when(() => localSettings.notificationsEnabled).thenReturn(true);
    when(() => localSettings.locationSharingEnabled).thenReturn(true);
    when(() => localSettings.clearOnSignOut()).thenAnswer((_) async {});

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
      privacy: privacy,
    );
    controller.syncFromServices();
  });

  tearDown(() => controller.onClose());

  test('export success exposes the real server document', () async {
    final export = AccountDataExport(
      payload: {
        'generated_at': '2026-10-30T00:00:00.000Z',
        'tables': {
          'location_events': {'row_count': 12, 'truncated': false},
          'usage_daily': {'row_count': 4, 'truncated': true},
        },
      },
      fileName: 'parent-control-export-2026-10-30.json',
      byteCount: 2048,
      savedPath: '/tmp/parent-control-export-2026-10-30.json',
    );
    when(() => privacy.exportMyData()).thenAnswer((_) async => export);

    final result = await controller.exportMyData();

    expect(result, same(export));
    expect(controller.lastExport.value, same(export));
    expect(controller.isExporting.value, isFalse);
    expect(controller.actionError.value, isNull);
    expect(export.rowCounts, {'location_events': 12, 'usage_daily': 4});
    expect(export.truncatedTables, ['usage_daily']);
    verify(() => privacy.exportMyData()).called(1);
  });

  test('export failure is surfaced and never reports success', () async {
    when(() => privacy.exportMyData()).thenThrow(
      const AppException(AppErrorCodes.network, 'Network unavailable'),
    );

    final result = await controller.exportMyData();

    expect(result, isNull);
    expect(controller.lastExport.value, isNull);
    expect(controller.isExporting.value, isFalse);
    expect(controller.actionError.value?.code, AppErrorCodes.network);
  });

  test('delete confirmation rejects a wrong word or wrong email', () async {
    expect(
      controller.validateAccountDeletionInput(
        confirm: 'delete',
        email: 'parent@example.test',
      ),
      isNotNull,
    );
    expect(
      controller.validateAccountDeletionInput(
        confirm: 'DELETE',
        email: 'other@example.test',
      ),
      isNotNull,
    );
    expect(
      controller.validateAccountDeletionInput(
        confirm: 'DELETE',
        email: 'parent@example.test',
      ),
      isNull,
    );

    final deleted = await controller.deleteAccount(
      confirm: 'DELETE',
      email: 'other@example.test',
    );

    expect(deleted, isFalse);
    expect(controller.actionError.value?.code, AppErrorCodes.validation);
    verifyNever(
      () => privacy.deleteAccount(
        confirm: any(named: 'confirm'),
        email: any(named: 'email'),
      ),
    );
  });

  test('a blocked owner keeps the session and explains the reason', () async {
    when(
      () => privacy.deleteAccount(
        confirm: 'DELETE',
        email: 'parent@example.test',
      ),
    ).thenAnswer(
      (_) async => const AccountDeletionOutcome(
        deleted: false,
        blockedReason:
            'Remove or transfer the other members of your family before '
            'deleting your account.',
      ),
    );

    final deleted = await controller.deleteAccount(
      confirm: 'DELETE',
      email: 'parent@example.test',
    );

    expect(deleted, isFalse);
    expect(controller.isDeletingAccount.value, isFalse);
    expect(controller.accountDeletionBlockedReason.value, contains('Remove'));
    expect(controller.actionError.value?.code, AppErrorCodes.forbidden);
    expect(session.isAuthenticated, isTrue);
  });

  test('a confirmed deletion clears the local session', () async {
    when(
      () => privacy.deleteAccount(
        confirm: 'DELETE',
        email: 'parent@example.test',
      ),
    ).thenAnswer((_) async => const AccountDeletionOutcome(deleted: true));

    final deleted = await controller.deleteAccount(
      confirm: 'DELETE',
      email: 'parent@example.test',
    );

    expect(deleted, isTrue);
    expect(session.isAuthenticated, isFalse);
    expect(controller.accountDeletionBlockedReason.value, isEmpty);
    verify(() => localSettings.clearOnSignOut()).called(1);
  });

  test('retention report supplies windows, counts and the last sweep',
      () async {
    final sweepAt = DateTime.utc(2026, 10, 30, 6);
    when(() => privacy.loadRetentionReport()).thenAnswer(
      (_) async => RetentionReport(
        generatedAt: DateTime.utc(2026, 10, 30, 7),
        lastSweepAt: sweepAt,
        families: const [
          FamilyRetentionWindow(
            familyId: 'family-1',
            familyName: 'Our family',
            locationDays: 14,
            usageDays: 60,
            locationEventsOlderThanWindow: 120,
            usageDaysOlderThanWindow: 9,
          ),
          FamilyRetentionWindow(
            familyId: 'family-2',
            familyName: 'Grandparents',
            locationDays: 30,
            usageDays: 90,
          ),
        ],
      ),
    );

    await controller.loadRetentionReport();

    expect(controller.isLoadingRetention.value, isFalse);
    expect(controller.retentionError.value, isNull);
    expect(controller.retentionWindows, hasLength(2));
    expect(controller.retentionWindows.first.locationDays, 14);
    expect(controller.retentionWindows.first.locationEventsOlderThanWindow, 120);
    expect(controller.retentionReport.value?.lastSweepAt, sweepAt);
  });

  test('retention failure falls back to the family settings already known',
      () async {
    when(() => privacy.loadRetentionReport()).thenThrow(
      const AppException(AppErrorCodes.unknown, 'Report unavailable'),
    );

    await controller.loadRetentionReport();

    expect(controller.retentionError.value, isNotNull);
    expect(controller.retentionReport.value, isNull);
    expect(controller.retentionWindows, hasLength(1));
    expect(controller.retentionWindows.single.locationDays, 30);
    expect(controller.retentionWindows.single.usageDays, 60);
  });
}