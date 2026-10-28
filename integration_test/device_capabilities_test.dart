// Device test: Usage Access and location reporting after explicit grants.
//
// Setup on the target phone (special access cannot be granted from the app):
//   adb shell appops set com.parentcontrol.parent_control GET_USAGE_STATS allow
//   adb shell pm grant com.parentcontrol.parent_control android.permission.ACCESS_FINE_LOCATION
//   adb shell pm grant com.parentcontrol.parent_control android.permission.ACCESS_COARSE_LOCATION
//   adb shell pm grant com.parentcontrol.parent_control android.permission.ACCESS_BACKGROUND_LOCATION
//
// Run:
//   .fvm/flutter_sdk/bin/flutter test integration_test/device_capabilities_test.dart \
//     -d <serial> --dart-define-from-file=.tools/ui_journey.json
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parent_control/data/services/device_admin_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Usage Access and location report on this phone', (tester) async {
    final admin = DeviceAdminService();

    final capabilities = await admin.getCapabilities();
    expect(
      capabilities.available,
      isTrue,
      reason: 'The native device bridge is unavailable.',
    );
    expect(
      capabilities.usageAccessGranted,
      isTrue,
      reason:
          'Usage Access is not granted. Run: adb shell appops set '
          'com.parentcontrol.parent_control GET_USAGE_STATS allow',
    );
    expect(
      capabilities.fineLocationGranted,
      isTrue,
      reason:
          'Fine location is not granted. Run: adb shell pm grant '
          'com.parentcontrol.parent_control android.permission.ACCESS_FINE_LOCATION',
    );
    // ignore: avoid_print
    print(
      'CAPABILITIES: usageAccess=${capabilities.usageAccessGranted} '
      'fineLocation=${capabilities.fineLocationGranted} '
      'backgroundLocation=${capabilities.backgroundLocationGranted} '
      'deviceOwner=${capabilities.isDeviceOwner}',
    );

    final now = DateTime.now();
    final usage = await admin.queryDailyUsage(
      deviceId: 'device-test',
      from: now.subtract(const Duration(hours: 24)),
      to: now,
    );
    // ignore: avoid_print
    print('USAGE ROWS (24h): ${usage.length}');
    expect(
      usage,
      isNotEmpty,
      reason:
          'Usage Access is granted but no UsageStats rows were returned for the '
          'last 24 hours.',
    );
    expect(
      usage.every((row) => row.packageName.isNotEmpty),
      isTrue,
      reason: 'A usage row has no package name.',
    );

    final permissions = await admin.requestPermissions(
      location: true,
      backgroundLocation: true,
    );
    expect(permissions['location'], isTrue);

    final started = await admin.startLocationTracking(intervalSeconds: 30);
    expect(started, isTrue, reason: 'Location tracking did not start.');

    final fix = await admin.getLastKnownLocation();
    final stopped = await admin.stopLocationTracking();
    expect(stopped, isTrue);

    expect(fix, isNotNull, reason: 'No location fix was available.');
    expect(fix!.latitude.abs() <= 90, isTrue);
    expect(fix.longitude.abs() <= 180, isTrue);
    expect(fix.latitude == 0 && fix.longitude == 0, isFalse);
    // ignore: avoid_print
    print(
      'LOCATION FIX: source=${fix.source} mock=${fix.isMock} '
      'accuracyM=${fix.accuracyM.toStringAsFixed(1)} '
      'age=${DateTime.now().difference(fix.recordedAt).inSeconds}s',
    );
  });
}
