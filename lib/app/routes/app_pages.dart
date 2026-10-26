import 'package:get/get.dart';
import 'package:parent_control/features/app_restrictions/app_restrictions_binding.dart';
import 'package:parent_control/features/app_restrictions/app_restrictions_page.dart';
import 'package:parent_control/features/audit_logs/audit_logs_binding.dart';
import 'package:parent_control/features/audit_logs/audit_logs_page.dart';
import 'package:parent_control/features/auth/login_binding.dart';
import 'package:parent_control/features/auth/login_page.dart';
import 'package:parent_control/features/auth/register_binding.dart';
import 'package:parent_control/features/auth/register_page.dart';
import 'package:parent_control/features/auth/splash_binding.dart';
import 'package:parent_control/features/auth/splash_page.dart';
import 'package:parent_control/features/auth/verify_email_binding.dart';
import 'package:parent_control/features/auth/verify_email_page.dart';
import 'package:parent_control/features/child/child_enrollment_binding.dart';
import 'package:parent_control/features/child/child_enrollment_page.dart';
import 'package:parent_control/features/child/child_requests_binding.dart';
import 'package:parent_control/features/child/child_requests_page.dart';
import 'package:parent_control/features/child/child_restrictions_page.dart';
import 'package:parent_control/features/child/child_session_binding.dart';
import 'package:parent_control/features/child/child_session_page.dart';
import 'package:parent_control/features/child/child_shell_binding.dart';
import 'package:parent_control/features/child/child_shell_page.dart';
import 'package:parent_control/features/configuration/configuration_page.dart';
import 'package:parent_control/features/devices/device_detail_binding.dart';
import 'package:parent_control/features/devices/device_detail_page.dart';
import 'package:parent_control/features/family/family_binding.dart';
import 'package:parent_control/features/family/family_page.dart';
import 'package:parent_control/features/family/family_setup_binding.dart';
import 'package:parent_control/features/family/family_setup_page.dart';
import 'package:parent_control/features/location/location_binding.dart';
import 'package:parent_control/features/location/location_page.dart';
import 'package:parent_control/features/pairing/pairing_redeem_binding.dart';
import 'package:parent_control/features/pairing/pairing_redeem_page.dart';
import 'package:parent_control/features/pairing/pairing_requests_binding.dart';
import 'package:parent_control/features/pairing/pairing_requests_page.dart';
import 'package:parent_control/features/parent_shell/parent_shell_binding.dart';
import 'package:parent_control/features/parent_shell/parent_shell_page.dart';
import 'package:parent_control/features/remote_assistance/remote_assistance_binding.dart';
import 'package:parent_control/features/remote_assistance/remote_assistance_page.dart';
import 'package:parent_control/features/remote_assistance/remote_session_binding.dart';
import 'package:parent_control/features/remote_assistance/remote_session_page.dart';
import 'package:parent_control/features/role_selection/role_selection_binding.dart';
import 'package:parent_control/features/role_selection/role_selection_page.dart';
import 'package:parent_control/features/safe_zones/safe_zones_binding.dart';
import 'package:parent_control/features/safe_zones/safe_zones_page.dart';
import 'package:parent_control/features/safety_alerts/safety_alerts_binding.dart';
import 'package:parent_control/features/safety_alerts/safety_alerts_page.dart';
import 'package:parent_control/features/screen_time/screen_time_binding.dart';
import 'package:parent_control/features/screen_time/screen_time_page.dart';
import 'package:parent_control/features/settings/parent_settings_binding.dart';
import 'package:parent_control/features/settings/parent_settings_page.dart';

import 'app_routes.dart';

abstract final class AppPages {
  static final List<GetPage<dynamic>> routes = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: AppRoutes.splash,
      page: () => const SplashPage(),
      binding: SplashBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.configuration,
      page: () => const ConfigurationPage(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.roleSelection,
      page: () => const RoleSelectionPage(),
      binding: RoleSelectionBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.login,
      page: () => const LoginPage(),
      binding: LoginBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.register,
      page: () => const RegisterPage(),
      binding: RegisterBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.verifyEmail,
      page: () => const VerifyEmailPage(),
      binding: VerifyEmailBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.parentShell,
      page: () => const ParentShellPage(),
      binding: ParentShellBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.familySetup,
      page: () => const FamilySetupPage(),
      binding: FamilySetupBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.family,
      page: () => const FamilyPage(),
      binding: FamilyBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.pairingRedeem,
      page: () => const PairingRedeemPage(),
      binding: PairingRedeemBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.pairingRequests,
      page: () => const PairingRequestsPage(),
      binding: PairingRequestsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.deviceDetail,
      page: () => const DeviceDetailPage(),
      binding: DeviceDetailBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.appRestrictions,
      page: () => const AppRestrictionsPage(),
      binding: AppRestrictionsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.screenTime,
      page: () => const ScreenTimePage(),
      binding: ScreenTimeBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.location,
      page: () => const LocationPage(),
      binding: LocationBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.safeZones,
      page: () => const SafeZonesPage(),
      binding: SafeZonesBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.alerts,
      page: () => const SafetyAlertsPage(),
      binding: SafetyAlertsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.remoteAssistance,
      page: () => const RemoteAssistancePage(),
      binding: RemoteAssistanceBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.remoteSession,
      page: () => const RemoteSessionPage(),
      binding: RemoteSessionBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.auditLogs,
      page: () => const AuditLogsPage(),
      binding: AuditLogsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.parentSettings,
      page: () => const ParentSettingsPage(),
      binding: ParentSettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.childShell,
      page: () => const ChildShellPage(),
      binding: ChildShellBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.childEnrollment,
      page: () => const ChildEnrollmentPage(),
      binding: ChildEnrollmentBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.childRestrictions,
      page: () => const ChildRestrictionsPage(),
      binding: ChildShellBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.childSession,
      page: () => const ChildSessionPage(),
      binding: ChildSessionBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.childRequests,
      page: () => const ChildRequestsPage(),
      binding: ChildRequestsBinding(),
    ),
  ];
}
