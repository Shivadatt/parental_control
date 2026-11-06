import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/data/models/device.dart';
import 'package:parent_control/data/models/policy_enforcement.dart';

void main() {
  Map<String, dynamic> resultWith(Object? quota) => <String, dynamic>{
        'desired_count': 2,
        'applied_count': 2,
        'failed_count': 0,
        'enforcement_supported': true,
        'enforcement_mode': 'device_owner',
        'quota': quota,
      };

  group('QuotaReport deserializes the ack shape', () {
    test('a full quota object is read field by field', () {
      final report = PolicyEnforcementReport.fromJson(resultWith({
        'configured': true,
        'usage_available': true,
        'usage_minutes': 45,
        'limit_minutes': 90,
        'day_bucket': '2026-11-06',
        'limit_reached': false,
        'action': 'none',
        'desired_count': 3,
        'applied_count': 3,
        'failed_count': 0,
        'enforcement_supported': true,
        'enforcement_mode': 'device_owner',
        'reason': 'quota_below_limit',
      }));

      final quota = report.quota!;
      expect(quota.configured, isTrue);
      expect(quota.usageAvailable, isTrue);
      expect(quota.usageMinutes, 45);
      expect(quota.limitMinutes, 90);
      expect(quota.dayBucket, '2026-11-06');
      expect(quota.limitReached, isFalse);
      expect(quota.action, 'none');
      expect(quota.desiredCount, 3);
      expect(quota.appliedCount, 3);
      expect(quota.failedCount, 0);
      expect(quota.enforcementSupported, isTrue);
      expect(quota.enforcementMode, 'device_owner');
      expect(quota.reason, 'quota_below_limit');
      expect(quota.remainingMinutes, 45);
      expect(quota.isLimitReached, isFalse);
      expect(report.hasQuotaReport, isTrue);
    });

    test('app counters keep their app-only meaning next to quota counters', () {
      final report = PolicyEnforcementReport.fromJson(resultWith({
        'configured': true,
        'usage_available': true,
        'usage_minutes': 10,
        'limit_minutes': 30,
        'limit_reached': false,
        'action': 'none',
        'desired_count': 5,
        'applied_count': 4,
        'failed_count': 1,
      }));

      // Top level stays "Applied to N of M apps"; quota counts are separate.
      expect(report.appliedSummary, 'Applied to 2 of 2 apps');
      expect(report.quota!.appliedCount, 4);
      expect(report.quota!.desiredCount, 5);
    });

    test('numeric strings from jsonb are accepted', () {
      final quota = PolicyEnforcementReport.fromJson(resultWith({
        'limit_minutes': '60',
        'usage_minutes': '20',
      })).quota!;
      expect(quota.limitMinutes, 60);
      expect(quota.usageMinutes, 20);
      expect(quota.remainingMinutes, 40);
    });
  });

  group('backward compatibility with an ack that has no quota', () {
    test('absent quota key leaves every quota reading unset', () {
      final report = PolicyEnforcementReport.fromJson(const {
        'desired_count': 3,
        'applied_count': 3,
        'failed_count': 0,
        'enforcement_supported': true,
        'enforcement_mode': 'device_owner',
      });

      expect(report.quota, isNull);
      expect(report.hasQuotaReport, isFalse);
      // The pre-T-B-02 behaviour is untouched.
      expect(report.hasCounts, isTrue);
      expect(report.provesFullEnforcement, isTrue);
      expect(report.appliedSummary, 'Applied to 3 of 3 apps');
    });

    test('a null quota object is not a quota either', () {
      final report = PolicyEnforcementReport.fromJson(resultWith(null));
      expect(report.quota, isNull);
      expect(report.provesFullEnforcement, isTrue);
    });

    test('a malformed quota shape fails closed instead of claiming a state', () {
      expect(PolicyEnforcementReport.fromJson(resultWith('quota')).quota, isNull);
      expect(PolicyEnforcementReport.fromJson(resultWith(<Object>[])).quota, isNull);
      expect(PolicyEnforcementReport.fromJson(resultWith(7)).quota, isNull);
    });

    test('an empty quota object proves nothing and stays unknown', () {
      final quota = PolicyEnforcementReport.fromJson(resultWith({})).quota!;
      expect(quota.hasLimit, isFalse);
      expect(quota.usageKnown, isFalse);
      expect(quota.remainingMinutes, isNull);
      expect(quota.isLimitReached, isNull);
      expect(quota.reason, isNull);
    });

    test('the quota survives a command row round trip', () {
      final command = DeviceCommand(
        id: 'command-1',
        deviceId: 'device-1',
        type: DeviceCommandType.applyPolicy,
        payload: const {'policy_id': 'policy-9'},
        status: DeviceCommandStatus.succeeded,
        createdAt: DateTime(2025, 1, 1),
        expiresAt: DateTime(2025, 1, 2),
        result: resultWith({
          'configured': true,
          'usage_available': true,
          'usage_minutes': 12,
          'limit_minutes': 60,
          'limit_reached': false,
          'action': 'none',
          'reason': 'quota_below_limit',
        }),
      );

      final restored = DeviceCommand.fromJson(command.toJson());
      final evidence = PolicyEnforcementEvidence.fromCommandResult(
        result: restored.result!,
        expectedPolicyId: 'policy-9',
        commandPayload: restored.payload,
      );
      expect(evidence.isMatched, isTrue);
      expect(evidence.report.quota!.limitMinutes, 60);
      expect(evidence.report.quota!.usageMinutes, 12);
      expect(evidence.report.quota!.remainingMinutes, 48);
    });
  });

  group('null versus zero limit', () {
    test('a limit of 0 is not configured, never a total ban', () {
      final quota =
          PolicyEnforcementReport.fromJson(resultWith({'limit_minutes': 0}))
              .quota!;
      expect(quota.limitMinutes, isNull);
      expect(quota.hasLimit, isFalse);
      expect(quota.remainingMinutes, isNull);
    });

    test('a negative or above-day limit is not configured', () {
      for (final raw in [-1, -1440, 1441, 2000, 99999999]) {
        final quota =
            PolicyEnforcementReport.fromJson(resultWith({'limit_minutes': raw}))
                .quota!;
        expect(quota.limitMinutes, isNull, reason: '$raw must not configure a limit');
        expect(quota.hasLimit, isFalse);
      }
    });

    test('1 and 1440 are both real limits', () {
      expect(
        PolicyEnforcementReport.fromJson(
          resultWith({'limit_minutes': 1}),
        ).quota!.limitMinutes,
        1,
      );
      expect(
        PolicyEnforcementReport.fromJson(
          resultWith({'limit_minutes': 1440}),
        ).quota!.limitMinutes,
        1440,
      );
    });

    test('configured=false outranks a present limit number', () {
      final quota = PolicyEnforcementReport.fromJson(resultWith({
        'configured': false,
        'limit_minutes': 60,
        'usage_minutes': 5,
      })).quota!;
      expect(quota.hasLimit, isFalse);
      expect(quota.remainingMinutes, isNull);
    });
  });

  group('remaining time is max(0, limit - usage) and integer-safe', () {
    QuotaReport quota(int limit, Object? usage, {bool? available}) =>
        PolicyEnforcementReport.fromJson(resultWith({
          'configured': true,
          'limit_minutes': limit,
          'usage_minutes': usage,
          'usage_available': available,
        })).quota!;

    test('below the limit leaves the difference', () {
      expect(quota(90, 30).remainingMinutes, 60);
    });

    test('exactly at the limit leaves zero, not negative', () {
      expect(quota(90, 90).remainingMinutes, 0);
    });

    test('over the limit clamps to zero', () {
      expect(quota(90, 600).remainingMinutes, 0);
    });

    test('zero usage against a real limit shows the whole allowance', () {
      expect(quota(120, 0).remainingMinutes, 120);
    });

    test('missing usage is unknown, not full and not zero', () {
      final missing = quota(120, null);
      expect(missing.remainingMinutes, isNull);
      expect(missing.usageKnown, isFalse);
    });

    test('usage_available false makes the number unknown', () {
      final unavailable = quota(120, 40, available: false);
      expect(unavailable.usageKnown, isFalse);
      expect(unavailable.remainingMinutes, isNull);
      expect(unavailable.isLimitReached, isNull);
    });

    test('a nonsensical usage reading is discarded, not clamped', () {
      expect(quota(120, 5000).remainingMinutes, isNull);
      expect(quota(120, -5).remainingMinutes, isNull);
      expect(quota(120, 'lots').remainingMinutes, isNull);
    });

    test('no limit configured means no remaining figure', () {
      expect(quota(0, 20).remainingMinutes, isNull);
    });
  });

  group('limit reached follows the device first', () {
    test('the device flag wins over the arithmetic', () {
      final deviceSays = PolicyEnforcementReport.fromJson(resultWith({
        'configured': true,
        'limit_minutes': 90,
        'usage_minutes': 10,
        'usage_available': true,
        'limit_reached': true,
      })).quota!;
      expect(deviceSays.isLimitReached, isTrue);
    });

    test('derived from the numbers when the device sent no flag', () {
      final reached = PolicyEnforcementReport.fromJson(resultWith({
        'configured': true,
        'limit_minutes': 90,
        'usage_minutes': 95,
        'usage_available': true,
      })).quota!;
      expect(reached.isLimitReached, isTrue);
    });

    test('unknown when neither side is reported', () {
      final unknown =
          PolicyEnforcementReport.fromJson(resultWith({'limit_minutes': 90}))
              .quota!;
      expect(unknown.isLimitReached, isNull);
    });
  });

  group('stored policy limit follows the same 1..1440 rule', () {
    test('a zero daily limit in the payload reads as no limit', () {
      const payload = PolicyPayload(dailyScreenTimeLimitMinutes: 0);
      final restored = PolicyPayload.fromJson(payload.toJson());
      expect(restored.dailyScreenTimeLimitMinutes, isNull);
    });

    test('an out-of-range daily limit reads as no limit', () {
      for (final raw in [-30, 1441, 99999]) {
        final restored = PolicyPayload.fromJson({
          'daily_screen_time_limit_minutes': raw,
        });
        expect(
          restored.dailyScreenTimeLimitMinutes,
          isNull,
          reason: '$raw is not a configured limit',
        );
      }
    });

    test('a real limit survives the round trip', () {
      const payload = PolicyPayload(dailyScreenTimeLimitMinutes: 90);
      expect(
        PolicyPayload.fromJson(payload.toJson()).dailyScreenTimeLimitMinutes,
        90,
      );
    });
  });
}
