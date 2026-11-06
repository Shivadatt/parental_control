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
    this.quota,
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

  /// The device's daily screen-time quota verdict, or null when the ack carried
  /// no `quota` object. Null means "no quota proof" — never "quota satisfied".
  final QuotaReport? quota;

  bool get hasQuotaReport => quota != null;

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
      quota: QuotaReport.fromResult(json),
    );
  }

  static int? _count(Object? raw) {
    final value = jsonInt(raw);
    if (value == null || value < 0 || value > 100000) return null;
    return value;
  }
}

/// The device's own daily screen-time quota verdict, carried in
/// `policy_ack.result.quota`.
///
/// T-B-02 added this as an optional key inside a free-form `jsonb` result, so
/// an ack from an older device simply has no `quota`. [fromResult] returns null
/// in that case and every parent-facing reading stays at its pre-T-B-02
/// behaviour: nothing is claimed, and nothing defaults to success.
class QuotaReport {
  const QuotaReport({
    this.configured,
    this.usageAvailable,
    this.usageMinutes,
    this.limitMinutes,
    this.dayBucket,
    this.limitReached,
    this.action,
    this.desiredCount,
    this.appliedCount,
    this.failedCount,
    this.enforcementSupported,
    this.enforcementMode = 'none',
    this.reason,
  });

  /// The server's `readInteger(..., 1, 1440)` bounds the stored limit, and a
  /// device-local day has at most 1440 minutes of usage.
  static const int _maxDayMinutes = 1440;

  final bool? configured;
  final bool? usageAvailable;

  /// Minutes used in the device's own calendar day. Null when not reported.
  final int? usageMinutes;

  /// The configured daily limit as the device read it. Null means not configured.
  final int? limitMinutes;

  /// The device-local day the numbers belong to, informational only.
  final String? dayBucket;

  final bool? limitReached;

  /// `none`, `advisory`, `suspended` or `suspend_failed` as reported.
  final String? action;

  final int? desiredCount;
  final int? appliedCount;
  final int? failedCount;
  final bool? enforcementSupported;
  final String enforcementMode;

  /// The device's reason token; read through `enforcementReasonText` for display.
  final String? reason;

  /// True only when a usable limit exists. A limit of `0` or of `2000` is not a
  /// total ban: the server rejects it, so a device reporting one has reported
  /// no limit at all.
  bool get hasLimit => limitMinutes != null && configured != false;

  /// Usage counts as known only when the device both says it measured it and
  /// gives the number; otherwise remaining time must render as unknown.
  bool get usageKnown => usageMinutes != null && usageAvailable != false;

  /// `max(0, limit - usage)` in minutes, or null when either side is unknown.
  int? get remainingMinutes {
    if (!hasLimit || !usageKnown) return null;
    final remaining = limitMinutes! - usageMinutes!;
    return remaining < 0 ? 0 : remaining;
  }

  /// The device's own verdict when it gave one; only otherwise derived from the
  /// numbers, and never invented when either is missing.
  bool? get isLimitReached {
    final reported = limitReached;
    if (reported != null) return reported;
    if (!hasLimit || !usageKnown) return null;
    return usageMinutes! >= limitMinutes!;
  }

  /// Reads `result.quota`. Absent, null or a non-object all mean "no quota
  /// proof" rather than an empty quota, so malformed shapes fail closed.
  static QuotaReport? fromResult(Map<String, dynamic> result) {
    final raw = result['quota'];
    if (raw == null) return null;
    if (raw is! Map) return null;
    final json = jsonMap(raw);
    final bucket = jsonString(json['day_bucket'])?.trim();
    final action = jsonString(json['action'])?.trim().toLowerCase();
    final reason = jsonString(json['reason'])?.trim();
    return QuotaReport(
      configured: jsonBool(json['configured']),
      usageAvailable: jsonBool(json['usage_available']),
      usageMinutes: _usageMinutes(json['usage_minutes']),
      limitMinutes: _limitMinutes(json['limit_minutes']),
      dayBucket: (bucket == null || bucket.isEmpty) ? null : bucket,
      limitReached: jsonBool(json['limit_reached']),
      action: (action == null || action.isEmpty) ? null : action,
      desiredCount: PolicyEnforcementReport._count(json['desired_count']),
      appliedCount: PolicyEnforcementReport._count(json['applied_count']),
      failedCount: PolicyEnforcementReport._count(json['failed_count']),
      enforcementSupported: jsonBool(json['enforcement_supported']),
      enforcementMode: jsonStringOr(json['enforcement_mode'], 'none'),
      reason: (reason == null || reason.isEmpty) ? null : reason,
    );
  }

  static int? _limitMinutes(Object? raw) {
    final value = jsonInt(raw);
    if (value == null) return null;
    if (value < 1 || value > _maxDayMinutes) return null;
    return value;
  }

  static int? _usageMinutes(Object? raw) {
    final value = jsonInt(raw);
    if (value == null || value < 0 || value > _maxDayMinutes) return null;
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