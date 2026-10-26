import 'package:parent_control/data/models/device.dart';

/// One app from the downloaded policy together with what Android's
/// DevicePolicyManager reports on this phone.
///
/// [suspended] is null when enforcement cannot be verified (for example this
/// phone is not a Device Owner). A configured block is never presented as
/// enforced without a positive DevicePolicyManager result.
class ChildEnforcedApp {
  const ChildEnforcedApp({
    required this.packageName,
    required this.label,
    required this.isScheduleRule,
    this.rule,
    this.suspended,
  });

  final String packageName;
  final String label;
  final bool isScheduleRule;
  final AppRule? rule;
  final bool? suspended;

  bool get isConfirmed => suspended == true;

  bool get hasSchedule => (rule?.windows.isNotEmpty ?? false);

  bool isActiveNow(DateTime localTime) {
    if (rule == null) return true;
    return rule!.isBlockActiveAt(localTime);
  }

  String get statusLabel {
    final value = suspended;
    if (value == null) return 'Not verified';
    return value ? 'Suspended by Android' : 'Not currently suspended';
  }
}
