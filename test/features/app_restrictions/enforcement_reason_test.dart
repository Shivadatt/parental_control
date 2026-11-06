import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/features/app_restrictions/enforcement_reason.dart';

void main() {
  group('enforcementReasonText maps every device-reported reason token', () {
    const table = <String, String>{
      'limits_enforcement_unverified':
          'The device accepted the policy but did not confirm the time '
          'limits, so the daily limit and bedtime are not verified on the '
          'device yet.',
      'quota_not_configured':
          'The device has no active daily screen-time limit, so the limit is '
          'not enforced there yet.',
      'quota_usage_unavailable':
          "The device could not read today's screen time, so the daily limit "
          'cannot be checked right now.',
      'quota_below_limit':
          'Screen time is below the daily limit and the device is tracking it. '
          'No apps were blocked.',
      'quota_advisory_only':
          'The daily limit is advisory on this device — apps are not blocked '
          'when it is reached.',
      'quota_confirmation_missing':
          'The device did not confirm whether it enforced the daily limit.',
      'quota_suspend_failed':
          'The device could not block apps when the daily limit was reached.',
      'no_apps_suspended':
          'The device did not suspend any apps, so none of the selected '
          'restrictions are active.',
      'command_expired':
          'The command expired before the device applied it, so this version '
          'is not on the device yet.',
      'device_owner_required':
          'App blocking requires Device Owner, which this device does not have.',
      'enforcement_counts_missing':
          'The device did not report how many apps it suspended, so '
          'enforcement cannot be confirmed.',
    };

    table.forEach((token, sentence) {
      test(token, () {
        expect(enforcementReasonText(token), sentence);
      });
    });

    test('no mapped sentence is an empty string', () {
      for (final sentence in table.values) {
        expect(sentence.trim(), isNotEmpty);
      }
    });

    test('lookup is case-insensitive and tolerant of surrounding space', () {
      expect(
        enforcementReasonText('  QUOTA_BELOW_LIMIT '),
        table['quota_below_limit'],
      );
    });

    test('advisory-only never reads as apps being blocked', () {
      final text = enforcementReasonText('quota_advisory_only')!;
      expect(text, contains('advisory'));
      expect(text, contains('apps are not blocked'));
    });

    test('unverified reasons never claim enforcement', () {
      for (final token in [
        'limits_enforcement_unverified',
        'quota_confirmation_missing',
        'enforcement_counts_missing',
      ]) {
        final text = enforcementReasonText(token)!;
        expect(
          text.toLowerCase().contains('is enforced'),
          isFalse,
          reason: '$token must not read as enforced',
        );
      }
    });
  });

  group('parameterised count reasons', () {
    test('suspended <n> of <m> renders the device numbers', () {
      expect(enforcementReasonText('suspended 1 of 3'), isNotNull);
      expect(
        enforcementReasonText('suspended 1 of 3'),
        contains('suspended 1 of 3 apps'),
      );
      expect(
        enforcementReasonText('suspended 0 of 5'),
        contains('suspended 0 of 5 apps'),
      );
    });

    test('quota_suspended <n> of <m> is read before the plain form', () {
      final text = enforcementReasonText('quota_suspended 2 of 5')!;
      expect(text, contains('2 of 5'));
      expect(text, contains('daily limit'));
      // Not the app-targeting sentence: the quota form means something else.
      expect(text, isNot(contains('The device suspended')));
    });

    test('the two count forms do not collapse into the same sentence', () {
      expect(
        enforcementReasonText('suspended 2 of 5'),
        isNot(enforcementReasonText('quota_suspended 2 of 5')),
      );
    });

    test('a malformed count form still shows the device value', () {
      expect(
        enforcementReasonText('suspended two of three'),
        contains('suspended two of three'),
      );
      expect(
        enforcementReasonText('suspended 1 of'),
        contains('suspended 1 of'),
      );
    });

    test('an oversized count does not throw and shows the raw value', () {
      const huge = 'suspended 99999999999999 of 4';
      expect(enforcementReasonText(huge), contains(huge));
    });
  });

  group('unknown reasons are displayed, never swallowed', () {
    test('an unmapped token is shown as reported', () {
      expect(
        enforcementReasonText('some_future_device_token'),
        contains('some_future_device_token'),
      );
    });

    test('a legacy free-text reason is shown as reported', () {
      expect(
        enforcementReasonText('2 of 3 packages could not be suspended'),
        contains('2 of 3 packages could not be suspended'),
      );
    });

    test('the unmapped value is never replaced by a success sentence', () {
      final text = enforcementReasonText('brand_new_reason')!;
      expect(text, isNot(contains('enforced')));
      expect(text, isNot(contains('no problem')));
    });

    test('null and blank give no sentence at all so the caller stays honest', () {
      expect(enforcementReasonText(null), isNull);
      expect(enforcementReasonText(''), isNull);
      expect(enforcementReasonText('   '), isNull);
    });
  });
}
