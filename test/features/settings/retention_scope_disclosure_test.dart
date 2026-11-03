import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/utils/formatters.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/device_admin_service.dart';
import 'package:parent_control/data/services/local_settings_service.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/settings/account_privacy_repository.dart';
import 'package:parent_control/features/settings/parent_settings_controller.dart';
import 'package:parent_control/features/settings/settings_body.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockLocalSettings extends Mock implements LocalSettingsService {}

class _MockDeviceAdmin extends Mock implements DeviceAdminService {}

class _MockPrivacyRepository extends Mock implements AccountPrivacyRepository {}

/// PRIV-01 / WORD-02: the retention card has to say whose rows its counts
/// cover, and it has to get that from the server's `scope` token. Every case
/// here renders the real [SettingsBody] and reads the sentence a parent or a
/// child would actually see, so a wording change cannot pass unnoticed.
RetentionReport _report(DataScope scope, {DateTime? lastSweepAt}) {
  return RetentionReport(
    generatedAt: DateTime.utc(2026, 11, 3, 12),
    lastSweepAt: lastSweepAt,
    scope: scope,
    families: const [
      FamilyRetentionWindow(
        familyId: 'family-1',
        familyName: 'Our family',
        locationDays: 30,
        usageDays: 60,
        locationEventsOlderThanWindow: 12,
        usageDaysOlderThanWindow: 3,
      ),
    ],
  );
}

void main() {
  late ParentSettingsController controller;
  late SessionService session;

  setUpAll(() {
    Get.testMode = true;
  });

  setUp(() {
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

    final localSettings = _MockLocalSettings();
    when(() => localSettings.notificationsEnabled).thenReturn(true);
    when(() => localSettings.locationSharingEnabled).thenReturn(true);

    final deviceAdmin = _MockDeviceAdmin();
    when(() => deviceAdmin.isAvailable).thenReturn(false);

    controller = ParentSettingsController(
      authRepository: _MockAuthRepository(),
      session: session,
      localSettings: localSettings,
      deviceAdmin: deviceAdmin,
      privacy: _MockPrivacyRepository(),
    );
    // syncFromServices only. onInit is never called here, so the report stays
    // exactly where each test puts it instead of loading asynchronously.
    controller.syncFromServices();
  });

  /// The privacy card sits far down a lazily built list, so the test viewport
  /// is tall enough that every child of the list is actually built.
  Future<void> render(WidgetTester tester, RetentionReport? report) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    controller.retentionReport.value = report;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SettingsBody(controller: controller))),
    );
    await tester.pump();
  }

  tearDown(() {
    controller.onClose();
  });

  testWidgets('a family scope claims the whole family and shows the sweep '
      'marker', (tester) async {
    final sweepAt = DateTime.utc(2026, 11, 1, 3, 30);
    await render(tester, _report(DataScope.family, lastSweepAt: sweepAt));

    expect(find.textContaining('Counts cover the whole family'), findsOneWidget);
    expect(
      find.textContaining('older than the window (all members)'),
      findsOneWidget,
    );
    expect(find.textContaining('Not reported for this account'), findsNothing);
    expect(find.textContaining(formatDateTime(sweepAt)), findsOneWidget);
    expect(find.textContaining('one global marker row'), findsOneWidget);
  });

  testWidgets('a family scope with no marker says it was never recorded',
      (tester) async {
    await render(tester, _report(DataScope.family));

    expect(find.text('Not recorded yet'), findsOneWidget);
    expect(find.textContaining('Not reported for this account'), findsNothing);
  });

  testWidgets('a device scope limits the counts and withholds the marker',
      (tester) async {
    await render(
      tester,
      _report(DataScope.device, lastSweepAt: DateTime.utc(2026, 11, 1)),
    );

    expect(find.textContaining('Counts cover only this account'), findsOneWidget);
    expect(find.textContaining('Counts cover the whole family'), findsNothing);
    expect(
      find.textContaining('older than the window (this account only)'),
      findsOneWidget,
    );
    expect(find.textContaining('Not reported for this account'), findsOneWidget);
    expect(find.textContaining('family owner only'), findsOneWidget);
    // Even a report that leaked a marker value must not render it here.
    expect(find.textContaining('Nov 2026'), findsNothing);
  });

  testWidgets('a not_reported scope says the server reported nothing',
      (tester) async {
    await render(
      tester,
      _report(DataScope.notReported, lastSweepAt: DateTime.utc(2026, 11, 1)),
    );

    expect(
      find.textContaining('The server did not report retention counts'),
      findsOneWidget,
    );
    expect(find.textContaining('Counts cover the whole family'), findsNothing);
    expect(
      find.textContaining('older than the window (no scope reported)'),
      findsOneWidget,
    );
    expect(find.textContaining('Not reported for this account'), findsOneWidget);
  });

  testWidgets('no report yet is its own state, never a family claim',
      (tester) async {
    await render(tester, null);

    expect(
      find.textContaining('The server did not report retention counts'),
      findsOneWidget,
    );
    expect(find.textContaining('Counts cover the whole family'), findsNothing);
    // A report that has not arrived does not get to claim the sweep never ran.
    expect(find.text('Not recorded yet'), findsNothing);
    expect(find.textContaining('Not reported for this account'), findsOneWidget);
  });

  testWidgets('an account with no family linked says so instead of showing '
      'empty counts', (tester) async {
    session.setActiveFamily(null);
    await render(tester, null);

    expect(
      find.textContaining('No family is linked to this account yet.'),
      findsOneWidget,
    );
    expect(find.textContaining('Counts cover the whole family'), findsNothing);
  });

  group('DataScope.parse fails closed', () {
    test('the declared tokens map to their scopes', () {
      expect(DataScope.parse('family'), DataScope.family);
      expect(DataScope.parse('device'), DataScope.device);
      expect(DataScope.parse('not_reported'), DataScope.notReported);
    });

    test('absent, malformed and non-string tokens are not_reported', () {
      for (final value in <Object?>[
        null,
        '',
        'FAMILY',
        'Family',
        ' family',
        'family ',
        'families',
        'all',
        'owner',
        42,
        0,
        true,
        <String>['family'],
        const <String, Object>{},
      ]) {
        expect(
          DataScope.parse(value),
          DataScope.notReported,
          reason: '$value must not earn a scope claim',
        );
      }
    });

    test('a document with no scope field never reads as family scope', () {
      final export = AccountDataExport(
        payload: const {'profile': {'role': 'parent'}},
        fileName: 'export.json',
        byteCount: 10,
      );
      expect(export.scope, DataScope.notReported);

      expect(
        RetentionReport.fromJson(const {'families': <Object>[]}).scope,
        DataScope.notReported,
      );
    });

    test('the scope token survives the round trip through fromJson', () {
      final family = RetentionReport.fromJson(const {
        'scope': 'family',
        'last_sweep_at': '2026-11-01T03:30:00.000Z',
        'families': [
          {
            'family_id': 'family-1',
            'name': 'Our family',
            'location_retention_days': 30,
            'usage_retention_days': 60,
            'location_events_older_than_window': 12,
            'usage_days_older_than_window': 3,
          },
        ],
      });
      expect(family.scope, DataScope.family);
      // jsonDate stamps the instant in local time, so compare the instant.
      expect(family.lastSweepAt?.toUtc(), DateTime.utc(2026, 11, 1, 3, 30));
      expect(family.families.single.locationEventsOlderThanWindow, 12);

      // A device-scope document carries no marker, so nothing can render it.
      final device = RetentionReport.fromJson(const {
        'scope': 'device',
        'families': <Object>[],
      });
      expect(device.scope, DataScope.device);
      expect(device.lastSweepAt, isNull);
    });
  });
}
