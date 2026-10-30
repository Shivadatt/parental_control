import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/data/models/policy_enforcement.dart';

void main() {
  group('PolicyEnforcementReport.fromJson', () {
    test('parses the ack counters and proves full enforcement', () {
      final report = PolicyEnforcementReport.fromJson(const {
        'desired_count': 5,
        'applied_count': 5,
        'failed_count': 0,
        'enforcement_supported': true,
        'enforcement_mode': 'device_owner',
        'failures': <Map<String, dynamic>>[],
      });

      expect(report.desiredCount, 5);
      expect(report.appliedCount, 5);
      expect(report.failedCount, 0);
      expect(report.enforcementSupported, isTrue);
      expect(report.enforcementMode, 'device_owner');
      expect(report.hasCounts, isTrue);
      expect(report.isUnsupported, isFalse);
      expect(report.provesFullEnforcement, isTrue);
      expect(report.appliedSummary, 'Applied to 5 of 5 apps');
    });

    test('a partial result is not proven and keeps its failures', () {
      final report = PolicyEnforcementReport.fromJson(const {
        'desired_count': 5,
        'applied_count': 2,
        'failed_count': 3,
        'enforcement_supported': true,
        'enforcement_mode': 'device_owner',
        'failures': [
          {'package': 'com.example.game', 'reason': 'not confirmed'},
          {'package': 'com.example.chat', 'reason': 'protected component'},
        ],
      });

      expect(report.provesFullEnforcement, isFalse);
      expect(report.appliedSummary, 'Applied to 2 of 5 apps');
      expect(report.failures, hasLength(2));
      expect(report.failures.first.packageName, 'com.example.game');
      expect(report.failures.first.reason, 'not confirmed');
    });

    test('supported=false is the explicit unsupported state', () {
      final report = PolicyEnforcementReport.fromJson(const {
        'desired_count': 3,
        'applied_count': 0,
        'failed_count': 3,
        'enforcement_supported': false,
        'enforcement_mode': 'none',
      });

      expect(report.isUnsupported, isTrue);
      expect(report.provesFullEnforcement, isFalse);
      expect(report.appliedSummary, 'Applied to 0 of 3 apps');
      expect(PolicyEnforcementReport.unsupportedMessage, contains('Device Owner'));
    });

    test('missing fields stay unknown instead of claiming a state', () {
      final report = PolicyEnforcementReport.fromJson(const {
        'success': true,
        'applied_at': '2026-01-01T00:00:00.000Z',
      });

      expect(report.hasCounts, isFalse);
      expect(report.desiredCount, isNull);
      expect(report.appliedCount, isNull);
      expect(report.enforcementSupported, isNull);
      expect(report.isUnsupported, isFalse);
      expect(report.provesFullEnforcement, isFalse);
      expect(report.appliedSummary, isNull);
    });

    test('malformed counts are discarded, never treated as zero', () {
      final report = PolicyEnforcementReport.fromJson(const {
        'desired_count': -4,
        'applied_count': '3',
        'failed_count': 1,
        'enforcement_supported': false,
      });

      expect(report.desiredCount, isNull);
      expect(report.appliedCount, 3);
      expect(report.hasCounts, isFalse);
      expect(report.appliedSummary, isNull);
    });

    test('per-app failures are capped at 20 entries', () {
      final report = PolicyEnforcementReport.fromJson({
        'desired_count': 40,
        'applied_count': 0,
        'failed_count': 40,
        'enforcement_supported': true,
        'failures': List.generate(
          40,
          (index) => {'package': 'com.example.app$index', 'reason': 'refused'},
        ),
      });

      expect(report.failures, hasLength(20));
    });
  });
}