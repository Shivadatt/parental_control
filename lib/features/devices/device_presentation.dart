import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/device.dart';

/// Pure presentation helpers shared by the parent device screens. They never
/// invent a state: unknown values stay explicitly unknown.
String enforcementModeLabel(String? mode) {
  switch (mode) {
    case 'device_owner':
      return 'Fully managed (Device Owner)';
    case 'device_admin':
      return 'Device admin only';
    case 'none':
      return 'Not enforced';
    default:
      return 'Not reported';
  }
}

bool appSuspensionUnsupported(Device device) =>
    device.enforcementMode != 'device_owner';

String policySummary({
  required int? devicePolicyVersion,
  required DevicePolicy? policy,
}) {
  final version = policy?.version ?? devicePolicyVersion;
  if (version == null || version <= 0) return 'No policy applied yet';
  if (policy == null) return 'Policy v$version · status not available';
  return 'Policy v$version · ${policy.status.label}';
}

StatusTone policyTone(PolicyEnforcementStatus status) {
  switch (status) {
    case PolicyEnforcementStatus.pending:
      return StatusTone.warning;
    case PolicyEnforcementStatus.enforced:
      return StatusTone.success;
    case PolicyEnforcementStatus.failed:
      return StatusTone.danger;
    case PolicyEnforcementStatus.unsupported:
      return StatusTone.neutral;
  }
}

/// Permission gaps meaningful for parental controls. Unknown values are not
/// reported as gaps, because the device may not have reported yet.
List<String> permissionGapsFor(Device device) {
  final gaps = <String>[];
  if (device.usageAccessGranted == false) gaps.add('Usage access');
  if (device.locationGranted == false) gaps.add('Location');
  if (device.backgroundLocationGranted == false) {
    gaps.add('Background location');
  }
  if (device.notificationsGranted == false) gaps.add('Notifications');
  return gaps;
}
