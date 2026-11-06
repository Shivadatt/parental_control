// Parent-readable text for the enforcement reason a child device reports in
// `device_policies.last_error`.
//
// The device's reason token is the only explanation a failed or unverified
// policy carries, so it must never be dropped: an unmapped value is displayed
// as-is rather than swallowed, because hiding the device's statement would
// make the screen read as healthier than the device actually is.

/// `suspended <applied> of <desired>` — the app-targeting partial-failure form.
final RegExp _suspendedPattern = RegExp(r'^suspended (\d+) of (\d+)$');

/// `quota_suspended <applied> of <desired>` — the T-B-02 quota partial-failure form.
final RegExp _quotaSuspendedPattern = RegExp(r'^quota_suspended (\d+) of (\d+)$');

const Map<String, String> _enforcementReasonText = {
  'limits_enforcement_unverified':
      'The device accepted the policy but did not confirm the time limits, so '
      'the daily limit and bedtime are not verified on the device yet.',
  'quota_not_configured':
      'The device has no active daily screen-time limit, so the limit is not '
      'enforced there yet.',
  'quota_usage_unavailable':
      "The device could not read today's screen time, so the daily limit "
      'cannot be checked right now.',
  'quota_below_limit':
      'Screen time is below the daily limit and the device is tracking it. No '
      'apps were blocked.',
  'quota_advisory_only':
      'The daily limit is advisory on this device — apps are not blocked when '
      'it is reached.',
  'quota_confirmation_missing':
      'The device did not confirm whether it enforced the daily limit.',
  'quota_suspend_failed':
      'The device could not block apps when the daily limit was reached.',
  'no_apps_suspended':
      'The device did not suspend any apps, so none of the selected '
      'restrictions are active.',
  'command_expired':
      'The command expired before the device applied it, so this version is '
      'not on the device yet.',
  'device_owner_required':
      'App blocking requires Device Owner, which this device does not have.',
  'enforcement_counts_missing':
      'The device did not report how many apps it suspended, so enforcement '
      'cannot be confirmed.',
};

const String _unknownReasonPrefix = 'The device reported: ';

/// One count from a parameterised reason, or null when it is not a number this
/// app can read. Overflow-length digit strings parse to null rather than throw.
int? _reasonCount(String? raw) {
  final digits = raw?.trim();
  if (digits == null || digits.isEmpty || digits.length > 9) return null;
  return int.tryParse(digits);
}

/// The human sentence for a device-reported enforcement reason.
///
/// Returns null only when the device gave no reason at all, so callers keep
/// their existing "no explanation" wording instead of being handed a invented
/// one.
String? enforcementReasonText(String? rawReason) {
  final reason = rawReason?.trim() ?? '';
  if (reason.isEmpty) return null;

  final mapped = _enforcementReasonText[reason.toLowerCase()];
  if (mapped != null) return mapped;

  final quotaSuspended = _quotaSuspendedPattern.firstMatch(reason);
  if (quotaSuspended != null) {
    final applied = _reasonCount(quotaSuspended.group(1));
    final desired = _reasonCount(quotaSuspended.group(2));
    if (applied != null && desired != null) {
      return 'The daily limit was reached, and the device blocked $applied of '
          '$desired apps.';
    }
  }
  final suspended = _suspendedPattern.firstMatch(reason);
  if (suspended != null) {
    final applied = _reasonCount(suspended.group(1));
    final desired = _reasonCount(suspended.group(2));
    if (applied != null && desired != null) {
      return 'The device suspended $applied of $desired apps.';
    }
  }

  // Unmapped: show the device's own value. A reason this app does not know is
  // still a reason the parent is entitled to see.
  return '$_unknownReasonPrefix$reason.';
}
