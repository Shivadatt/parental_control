import '../../core/utils/json_utils.dart';

/// One app the device could not confirm as suspended.
///
/// The device's own wording is a confirmation failure, not proof that the
/// suspend call failed, so the label must not claim more than that.
class PolicyEnforcementFailure {
  const PolicyEnforcementFailure({
    required this.packageName,
    required this.reason,
  });

  final String packageName;
  final String reason;

  factory PolicyEnforcementFailure.fromJson(Map<String, dynamic> json) =>
      PolicyEnforcementFailure(
        packageName: jsonStringOr(json['package']),
        reason: jsonStringOr(json['reason'], 'Unknown reason'),
      );
}

/// The counter set a child device returns in `policy_ack.result`.
///
/// These counters are what makes an enforcement claim provable, but only for
/// the policy the acked command names — see [PolicyEnforcementEvidence]. A row
/// with [enforcementSupported] false, or without counts, must never be shown
/// as enforced: the server maps those acks to `unsupported`/`pending` and the
/// parent UI mirrors that here.
class PolicyEnforcementReport {
  const PolicyEnforcementReport({
    this.desiredCount,
    this.appliedCount,
    this.failedCount,
    this.enforcementSupported,
    this.enforcementMode = 'none',
    this.failures = const [],
  });

  /// Apps the policy wanted suspended. Null when the device did not report.
  final int? desiredCount;

  /// Apps DevicePolicyManager confirmed suspended.
  final int? appliedCount;

  /// Apps not confirmed as suspended (desired - applied).
  final int? failedCount;

  /// Null when an older device build did not report the flag.
  final bool? enforcementSupported;

  /// `device_owner`, `device_admin` or `none` as reported by the device.
  final String enforcementMode;

  final List<PolicyEnforcementFailure> failures;

  bool get hasCounts => desiredCount != null && appliedCount != null;

  bool get isUnsupported => enforcementSupported == false;

  /// True only when the counts prove every target app is suspended.
  ///
  /// Counts alone say nothing about **which policy** they belong to, so this is
  /// necessary but never sufficient for an enforcement claim: read
  /// [PolicyEnforcementEvidence.provesEnforcement] instead.
  bool get provesFullEnforcement =>
      enforcementSupported == true &&
      hasCounts &&
      (failedCount ?? 0) == 0 &&
      appliedCount == desiredCount;

  /// "Applied to N of M apps" — null when the device did not report counts.
  String? get appliedSummary {
    final desired = desiredCount;
    final applied = appliedCount;
    if (desired == null || applied == null) return null;
    return 'Applied to $applied of $desired apps';
  }

  /// Explicit statement for a device that cannot suspend apps at all.
  static const String unsupportedMessage =
      'App blocking requires Device Owner. This installation cannot enforce restrictions.';

  factory PolicyEnforcementReport.fromJson(Map<String, dynamic> json) {
    final failures = <PolicyEnforcementFailure>[];
    for (final value in jsonList(json['failures'])) {
      if (failures.length >= 20) break;
      final failure = PolicyEnforcementFailure.fromJson(jsonMap(value));
      if (failure.packageName.isEmpty) continue;
      failures.add(failure);
    }
    return PolicyEnforcementReport(
      desiredCount: _count(json['desired_count']),
      appliedCount: _count(json['applied_count']),
      failedCount: _count(json['failed_count']),
      enforcementSupported: jsonBool(json['enforcement_supported']),
      enforcementMode: jsonStringOr(json['enforcement_mode'], 'none'),
      failures: List.unmodifiable(failures),
    );
  }

  static int? _count(Object? raw) {
    final value = jsonInt(raw);
    if (value == null || value < 0 || value > 100000) return null;
    return value;
  }
}

/// How strongly a device report is tied to the policy it seems to prove.
///
/// The device's `policy_ack.result` never names a policy: `PolicyApplier.kt`
/// builds counters only and `GuardianService.sendAck` posts exactly
/// `{action, command_id, status, result}`. Attribution therefore comes from the
/// stored command's `payload.policy_id`, which `apply_policy_version` writes in
/// the same transaction as the policy row — nothing else in a real payload can
/// identify a policy.
enum PolicyReportCorrelation {
  /// The command names exactly the policy on screen.
  matched,

  /// The command names no policy: shown for reference, never proof.
  uncorrelated,

  /// The command names another policy; it belongs to that one only.
  mismatched,
}

/// A device report plus the proof of which policy it belongs to.
///
/// Old command rows (and any hand-made row) may carry no `policy_id`. Those
/// stay visible with [correlationNotice] so a parent can still read the
/// device's own counts, but they can never satisfy an enforcement claim: the
/// alternative — silently attributing them to the newest policy — was ENF-01.
class PolicyEnforcementEvidence {
  const PolicyEnforcementEvidence({
    required this.report,
    required this.correlation,
    required this.expectedPolicyId,
    this.reportedPolicyId,
    this.reportedVersion,
    this.commandId,
    this.ackedAt,
  });

  /// Builds evidence from one command row's stored payload and ack result.
  factory PolicyEnforcementEvidence.fromCommandResult({
    required Map<String, dynamic> result,
    required String expectedPolicyId,
    Map<String, dynamic> commandPayload = const <String, dynamic>{},
    String? commandId,
    DateTime? ackedAt,
  }) {
    final reported = jsonString(commandPayload['policy_id'])?.trim() ?? '';
    return PolicyEnforcementEvidence(
      report: PolicyEnforcementReport.fromJson(result),
      correlation: correlate(
        reportedPolicyId: reported,
        expectedPolicyId: expectedPolicyId,
      ),
      expectedPolicyId: expectedPolicyId,
      reportedPolicyId: reported.isEmpty ? null : reported,
      reportedVersion: jsonInt(commandPayload['version']),
      commandId: commandId,
      ackedAt: ackedAt,
    );
  }

  /// The one correlation rule: an exact, non-blank `policy_id` match.
  ///
  /// Timestamps, `version` and `installation_id` are deliberately not accepted
  /// as substitutes. A late ack is genuine evidence for its own version and
  /// must not age into proof for a newer one, and `installation_id` is a
  /// service-only column the parent client never receives.
  static PolicyReportCorrelation correlate({
    required Object? reportedPolicyId,
    required String expectedPolicyId,
  }) {
    final reported = jsonString(reportedPolicyId)?.trim() ?? '';
    final expected = expectedPolicyId.trim();
    if (reported.isEmpty || expected.isEmpty) {
      return PolicyReportCorrelation.uncorrelated;
    }
    return reported == expected
        ? PolicyReportCorrelation.matched
        : PolicyReportCorrelation.mismatched;
  }

  final PolicyEnforcementReport report;
  final PolicyReportCorrelation correlation;

  /// The policy the UI is currently showing.
  final String expectedPolicyId;

  /// The id the command named, or null when it named none.
  final String? reportedPolicyId;

  /// The version the command carried, informational only.
  final int? reportedVersion;
  final String? commandId;
  final DateTime? ackedAt;

  bool get isMatched => correlation == PolicyReportCorrelation.matched;

  bool get isUncorrelated =>
      correlation == PolicyReportCorrelation.uncorrelated;

  /// The only path to an "enforced" claim: matched id and proving counts.
  bool get provesEnforcement => isMatched && report.provesFullEnforcement;

  /// Parent-visible statement of what this report can and cannot prove.
  String? get correlationNotice {
    switch (correlation) {
      case PolicyReportCorrelation.matched:
        return null;
      case PolicyReportCorrelation.uncorrelated:
        return 'This device report does not say which policy version it '
            'applied to. It is shown for reference only and is not proof that '
            'the version above is enforced.';
      case PolicyReportCorrelation.mismatched:
        return 'This device report belongs to policy ${reportedPolicyId ?? 'another version'}, '
            'not the policy shown here.';
    }
  }
}