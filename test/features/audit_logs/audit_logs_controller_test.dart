import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/data/models/audit.dart';
import 'package:parent_control/data/repositories/repository_contracts.dart';
import 'package:parent_control/data/services/session_service.dart';
import 'package:parent_control/features/audit_logs/audit_logs_controller.dart';

class _MockAuditRepository extends Mock implements AuditRepository {}

void main() {
  late _MockAuditRepository repository;
  late SessionService session;
  late AuditLogsController controller;

  setUp(() {
    repository = _MockAuditRepository();
    session = SessionService()
      ..setAuthenticated(
        id: 'owner-1',
        address: 'owner@example.test',
        verified: true,
      )
      ..setActiveFamily(
        const Family(
          id: 'family-1',
          name: 'Our family',
          ownerId: 'owner-1',
          settings: FamilySettings(
            locationRetentionDays: 30,
            usageRetentionDays: 90,
          ),
        ),
      );
    when(() => repository.fetchAuditLogs(familyId: 'family-1', limit: 50))
        .thenAnswer((_) async => <AuditLogEntry>[]);
    controller = AuditLogsController(
      auditRepository: repository,
      session: session,
      familyId: 'family-1',
    );
  });

  tearDown(() => controller.onClose());

  test('shows an honest empty state when the family has no audit entries',
      () async {
    await controller.load();

    expect(controller.entries, isEmpty);
    expect(controller.error.value, isNull);
    expect(controller.hasMore.value, isFalse);
    expect(controller.isLoading.value, isFalse);
    expect(controller.canManage, isTrue);
  });

  test('a purge request smaller than retention reports the server floor', () {
    // family-admin purge_data clamps each cutoff to the family's retention
    // window, so the app must not promise deletion it will not perform.
    expect(controller.effectiveLocationCutoffDays(7), 30);
    expect(controller.effectiveUsageCutoffDays(7), 90);
    expect(controller.effectiveLocationCutoffDays(365), 365);
    expect(controller.effectiveUsageCutoffDays(365), 365);
  });

  test('an unknown retention window still shows the server default floor', () {
    // The screen can be opened before the family row arrives. The server then
    // applies its own 30/90 defaults, and a floor of 0 would promise deletion
    // the purge will not perform.
    final orphan = AuditLogsController(
      auditRepository: repository,
      session: session,
      familyId: 'family-2',
    );
    addTearDown(orphan.onClose);

    expect(orphan.effectiveLocationCutoffDays(7), 30);
    expect(orphan.effectiveUsageCutoffDays(7), 90);
  });

  test('a non-positive retention setting falls back to the server default', () {
    // family-admin treats a zero or invalid window as the default; the client
    // must not read the literal 0 as "keep nothing".
    session.setActiveFamily(
      const Family(
        id: 'family-1',
        name: 'Our family',
        ownerId: 'owner-1',
        settings: FamilySettings(
          locationRetentionDays: 0,
          usageRetentionDays: 0,
        ),
      ),
    );

    expect(controller.effectiveLocationCutoffDays(7), 30);
    expect(controller.effectiveUsageCutoffDays(7), 90);
  });

  test('purge shows only the server-reported count', () async {
    when(() => repository.purgeOldData(familyId: 'family-1', olderThanDays: 45))
        .thenAnswer((_) async => 12);
    await controller.load();

    final deleted = await controller.purgeOldData(45);

    expect(deleted, 12);
    expect(controller.lastPurgeCount.value, 12);
    expect(controller.actionError.value, isNull);
    expect(controller.isPurging.value, isFalse);
  });

  test('a parent who is not the owner cannot purge', () async {
    final memberSession = SessionService()
      ..setAuthenticated(
        id: 'parent-2',
        address: 'parent2@example.test',
        verified: true,
      )
      ..setActiveFamily(session.activeFamily.value);
    final memberController = AuditLogsController(
      auditRepository: repository,
      session: memberSession,
      familyId: 'family-1',
    );
    addTearDown(memberController.onClose);

    final deleted = await memberController.purgeOldData(45);

    expect(deleted, isNull);
    expect(memberController.canManage, isFalse);
    expect(
      memberController.actionError.value?.code,
      AppErrorCodes.forbidden,
    );
    verifyNever(
      () => repository.purgeOldData(
        familyId: any(named: 'familyId'),
        olderThanDays: any(named: 'olderThanDays'),
      ),
    );
  });

  test('an owner_required refusal is surfaced and never shown as success',
      () async {
    when(
      () => repository.purgeOldData(familyId: 'family-1', olderThanDays: 45),
    ).thenThrow(
      const AppException(
        'owner_required',
        'Only the family owner can purge family history.',
        statusCode: 403,
      ),
    );
    await controller.load();

    final deleted = await controller.purgeOldData(45);

    expect(deleted, isNull);
    expect(controller.lastPurgeCount.value, isNull);
    expect(controller.actionError.value?.code, 'owner_required');
    expect(controller.isPurging.value, isFalse);
  });
}
