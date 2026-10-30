import '../../core/utils/json_utils.dart';

/// One app the child device could not suspend.
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
/// This is the only evidence that makes an enforcement claim provable. A row
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

  /// Apps that could not be suspended (desired - applied).
  final int? failedCount;

  /// Null when an older device build did not report the flag.
  final bool? enforcementSupported;

  /// `device_owner`, `device_admin` or `none` as reported by the device.
  final String enforcementMode;

  final List<PolicyEnforcementFailure> failures;

  bool get hasCounts => desiredCount != null && appliedCount != null;

  bool get isUnsupported => enforcementSupported == false;

  /// True only when the counts prove every target app is suspended.
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