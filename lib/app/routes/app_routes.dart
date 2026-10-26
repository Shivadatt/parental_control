class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const configuration = '/configuration';
  static const roleSelection = '/role-selection';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const verifyEmail = '/auth/verify-email';

  static const parentShell = '/parent';
  static const familySetup = '/parent/family-setup';
  static const family = '/parent/family';
  static const pairingRedeem = '/parent/pairing/redeem';
  static const pairingRequests = '/parent/pairing/requests';
  static const deviceDetail = '/parent/devices/detail';
  static const appRestrictions = '/parent/app-restrictions';
  static const screenTime = '/parent/screen-time';
  static const location = '/parent/location';
  static const safeZones = '/parent/safe-zones';
  static const alerts = '/parent/alerts';
  static const remoteAssistance = '/parent/assistance';
  static const remoteSession = '/parent/assistance/session';
  static const auditLogs = '/parent/audit';
  static const parentSettings = '/parent/settings';

  static const childShell = '/child';
  static const childEnrollment = '/child/enrollment';
  static const childRestrictions = '/child/restrictions';
  static const childSession = '/child/session';
  static const childRequests = '/child/requests';
}
