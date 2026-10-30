import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/data/models/device.dart';

Device _device({DateTime? lastSeenAt}) => Device(
      id: 'device-1',
      familyId: 'family-1',
      childUserId: 'child-1',
      displayName: 'Mia phone',
      status: DeviceStatus.active,
      lastSeenAt: lastSeenAt,
    );

void main() {
  group('Device.isOnline', () {
    test('a device that never reported a heartbeat is offline', () {
      expect(_device().isOnline, isFalse);
      expect(_device().statusLabel, 'Offline');
    });

    test('a heartbeat inside the guardian interval keeps the device online', () {
      final now = DateTime.now();
      expect(_device(lastSeenAt: now.subtract(const Duration(minutes: 2))).isOnline,
          isTrue);
      // GuardianService beats every five minutes; the window must cover two
      // full intervals plus grace, or a healthy device flips to "Offline"
      // between beats (BUG-038).
      expect(
        _device(lastSeenAt: now.subtract(const Duration(minutes: 5, seconds: 59)))
            .isOnline,
        isTrue,
      );
    });

    test('a heartbeat 11 minutes old is still healthy', () {
      final device =
          _device(lastSeenAt: DateTime.now().subtract(const Duration(minutes: 11)));
      expect(device.isOnline, isTrue);
      expect(device.syncHealth, DeviceSyncHealth.healthy);
      expect(device.statusLabel, 'Online');
    });

    test('a missed heartbeat past the online window is stalled, not online',
        () {
      final device =
          _device(lastSeenAt: DateTime.now().subtract(const Duration(minutes: 13)));
      expect(device.isOnline, isFalse);
      expect(device.syncHealth, DeviceSyncHealth.stalled);
      expect(device.statusLabel, 'Online (sync stalled)');
      expect(device.statusLabel, isNot('Online'));
    });

    test('a device unheard of for 31 minutes is offline', () {
      final device =
          _device(lastSeenAt: DateTime.now().subtract(const Duration(minutes: 31)));
      expect(device.isOnline, isFalse);
      expect(device.syncHealth, DeviceSyncHealth.offline);
      expect(device.statusLabel, 'Offline');
    });

    test('a future heartbeat from clock skew is still treated as online', () {
      final device =
          _device(lastSeenAt: DateTime.now().add(const Duration(minutes: 1)));
      expect(device.isOnline, isTrue);
      expect(device.syncHealth, DeviceSyncHealth.healthy);
    });
  });

  group('Device.syncHealth', () {
    test('never-synced devices report offline health without an age', () {
      final device = _device();
      expect(device.syncHealth, DeviceSyncHealth.offline);
      expect(device.lastSeenAge, isNull);
      expect(device.lastSeenAgeLabel, 'never synced');
      expect(device.isSyncStalled, isFalse);
    });

    test('health thresholds follow the 12/30 minute contract', () {
      final now = DateTime.now();
      expect(
        _device(lastSeenAt: now.subtract(const Duration(minutes: 11))).syncHealth,
        DeviceSyncHealth.healthy,
      );
      expect(
        _device(lastSeenAt: now.subtract(const Duration(minutes: 13))).syncHealth,
        DeviceSyncHealth.stalled,
      );
      expect(
        _device(lastSeenAt: now.subtract(const Duration(minutes: 31))).syncHealth,
        DeviceSyncHealth.offline,
      );
    });

    test('lastSeenAge exposes the heartbeat age in minutes', () {
      final device =
          _device(lastSeenAt: DateTime.now().subtract(const Duration(minutes: 11)));
      expect(device.lastSeenAge, isNotNull);
      expect(device.lastSeenAge!.inMinutes, 11);
    });
  });

  group('Device.lastSeenAgeLabel', () {
    test('a fresh beat reads "synced just now"', () {
      final device =
          _device(lastSeenAt: DateTime.now().subtract(const Duration(seconds: 20)));
      expect(device.lastSeenAgeLabel, 'synced just now');
    });

    test('a healthy beat names the age', () {
      final device =
          _device(lastSeenAt: DateTime.now().subtract(const Duration(minutes: 3)));
      expect(device.lastSeenAgeLabel, 'synced 3 min ago');
    });

    test('a device without a recent beat reads "last seen", never "synced"',
        () {
      final device =
          _device(lastSeenAt: DateTime.now().subtract(const Duration(minutes: 42)));
      expect(device.lastSeenAgeLabel, 'last seen 42 min ago');
      expect(device.syncHealth, DeviceSyncHealth.offline);
    });
  });
}
