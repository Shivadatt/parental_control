import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
}
