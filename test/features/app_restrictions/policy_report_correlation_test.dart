import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/data/models/policy_enforcement.dart';

/// The exact shape `PolicyApplier.buildResult` puts in `policy_ack.result`
/// (android/.../PolicyApplier.kt:352-379): counters only, never a policy id.
const Map<String, dynamic> deviceAckResult = <String, dynamic>{
  'success': true,
  'applied_at': '2026-01-01T00:00:00.000Z',
  'suspended_packages': ['com.instagram.android'],
  'unsupported_packages': <String>[],
  'errors': <String>[],
  'service_running': true,
  'bedtime_active': false,
  'desired_count': 2,
  'applied_count': 2,
  'failed_count': 0,
  'enforcement_supported': true,
  'enforcement_mode': 'device_owner',
  'failures': <Map<String, dynamic>>[],
};

PolicyEnforcementEvidence evidenceFor({
  required String expectedPolicyId,
  Map<String, dynamic> commandPayload = const <String, dynamic>{},
  Map<String, dynamic> result = deviceAckResult,
}) =>
    PolicyEnforcementEvidence.fromCommandResult(
      result: result,
      commandPayload: commandPayload,
      expectedPolicyId: expectedPolicyId,
      commandId: 'command-1',
    );

void main() {
  group('policy correlation of a device report', () {
    test('a matching policy id correlates and can prove enforcement', () {
      final evidence = evidenceFor(
        expectedPolicyId: 'policy-4',
        commandPayload: const {
          'policy_id': 'policy-4',
          'version': 4,
        },
      );

      expect(evidence.correlation, PolicyReportCorrelation.matched);
      expect(evidence.isMatched, isTrue);
      expect(evidence.isUncorrelated, isFalse);
      expect(evidence.reportedPolicyId, 'policy-4');
      expect(evidence.reportedVersion, 4);
      expect(evidence.correlationNotice, isNull);
      expect(evidence.report.provesFullEnforcement, isTrue);
      expect(evidence.provesEnforcement, isTrue);
    });

    test('a mismatched policy id never correlates to the shown policy', () {
      final evidence = evidenceFor(
        expectedPolicyId: 'policy-6',
        commandPayload: const {
          'policy_id': 'policy-5',
          'version': 5,
        },
      );

      expect(evidence.correlation, PolicyReportCorrelation.mismatched);
      expect(evidence.provesEnforcement, isFalse);
      expect(evidence.correlationNotice, contains('policy-5'));
    });

    test('a missing policy id is explicitly uncorrelated, not inherited', () {
      final evidence = evidenceFor(expectedPolicyId: 'policy-6');

      expect(evidence.correlation, PolicyReportCorrelation.uncorrelated);
      expect(evidence.isUncorrelated, isTrue);
      expect(evidence.reportedPolicyId, isNull);
      // Historical visibility: the device numbers stay readable...
      expect(evidence.report.desiredCount, 2);
      expect(evidence.report.appliedCount, 2);
      expect(evidence.report.appliedSummary, 'Applied to 2 of 2 apps');
      // ...while the proof stays off.
      expect(evidence.report.provesFullEnforcement, isTrue);
      expect(evidence.provesEnforcement, isFalse);
      expect(evidence.correlationNotice, isNotEmpty);
    });

    test('an empty policy id is uncorrelated', () {
      final evidence = evidenceFor(
        expectedPolicyId: 'policy-6',
        commandPayload: const {'policy_id': ''},
      );

      expect(evidence.correlation, PolicyReportCorrelation.uncorrelated);
      expect(evidence.provesEnforcement, isFalse);
    });

    test('a blank-spaces policy id is uncorrelated', () {
      final evidence = evidenceFor(
        expectedPolicyId: 'policy-6',
        commandPayload: const {'policy_id': '   '},
      );

      expect(evidence.correlation, PolicyReportCorrelation.uncorrelated);
      expect(evidence.provesEnforcement, isFalse);
    });

    test('an older-device payload without the field stays uncorrelated', () {
      // What the field is really worth: the ack itself has never carried a
      // policy id, so a command row without one cannot be attributed by the
      // counters, the version hint or the timestamps inside the result.
      final evidence = evidenceFor(
        expectedPolicyId: 'policy-9',
        commandPayload: const {'version': 9},
      );

      expect(evidence.correlation, PolicyReportCorrelation.uncorrelated);
      expect(evidence.reportedVersion, 9);
      expect(evidence.report.enforcementMode, 'device_owner');
      expect(evidence.provesEnforcement, isFalse);
    });

    test('a policy row without a usable id cannot claim a report', () {
      final evidence = evidenceFor(
        expectedPolicyId: '',
        commandPayload: const {'policy_id': 'policy-4'},
      );

      expect(evidence.correlation, PolicyReportCorrelation.uncorrelated);
      expect(evidence.provesEnforcement, isFalse);
    });

    test('a non-string policy id never matches by toString accident', () {
      expect(
        PolicyEnforcementEvidence.correlate(
          reportedPolicyId: 4,
          expectedPolicyId: '4',
        ),
        PolicyReportCorrelation.matched,
      );
      expect(
        PolicyEnforcementEvidence.correlate(
          reportedPolicyId: const {'id': 'policy-4'},
          expectedPolicyId: 'policy-4',
        ),
        PolicyReportCorrelation.mismatched,
      );
      expect(
        PolicyEnforcementEvidence.correlate(
          reportedPolicyId: null,
          expectedPolicyId: 'policy-4',
        ),
        PolicyReportCorrelation.uncorrelated,
      );
    });

    test('an uncorrelated unsupported report keeps its honest meaning', () {
      final evidence = evidenceFor(
        expectedPolicyId: 'policy-7',
        result: const {
          'desired_count': 3,
          'applied_count': 0,
          'failed_count': 3,
          'enforcement_supported': false,
          'enforcement_mode': 'none',
        },
      );

      expect(evidence.correlation, PolicyReportCorrelation.uncorrelated);
      expect(evidence.report.isUnsupported, isTrue);
      expect(evidence.provesEnforcement, isFalse);
    });

    test('a failed count never proves enforcement even when matched', () {
      final evidence = evidenceFor(
        expectedPolicyId: 'policy-4',
        commandPayload: const {'policy_id': 'policy-4'},
        result: const {
          'desired_count': 3,
          'applied_count': 1,
          'failed_count': 2,
          'enforcement_supported': true,
          'enforcement_mode': 'device_owner',
          'failures': [
            {'package': 'com.b', 'reason': 'Could not confirm that com.b is suspended.'},
          ],
        },
      );

      expect(evidence.correlation, PolicyReportCorrelation.matched);
      expect(evidence.report.provesFullEnforcement, isFalse);
      expect(evidence.provesEnforcement, isFalse);
      expect(evidence.report.failures.single.reason, contains('Could not confirm'));
    });
  });
}
