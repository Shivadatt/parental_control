import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/json_utils.dart';
import '../models/device.dart';
import '../models/telemetry.dart';

/// Typed wrapper around the Android platform channel.
///
/// Every method reports honestly when the bridge is unavailable or a native
/// operation is unsupported; no method fabricates a successful enforcement.
class DeviceAdminService extends GetxService {
  static const MethodChannel _channel =
      MethodChannel('com.parentcontrol/native');
  static const EventChannel _events =
      EventChannel('com.parentcontrol/native_events');

  /// One native subscription shared by every listener.
  ///
  /// `receiveBroadcastStream()` opens a platform `listen` each time it is
  /// called, while the native side keeps a single event sink. A second caller
  /// (the child shell after the session screen) replaced the sink, and the
  /// first caller's cancellation then detached the sink for both, silently
  /// dropping service state events for the live assistance session.
  Stream<Map<String, dynamic>>? _eventStream;

  bool get isAvailable => Platform.isAndroid;

  Stream<Map<String, dynamic>> get events {
    if (!isAvailable) return const Stream<Map<String, dynamic>>.empty();
    return _eventStream ??=
        _events.receiveBroadcastStream().map((event) => jsonMap(event));
  }

  Future<DeviceCapabilities> getCapabilities() async {
    final result = await _invokeMap('getCapabilities');
    if (result == null) return DeviceCapabilities.empty();
    return DeviceCapabilities.fromJson(result);
  }

  Future<DeviceIdentity> getIdentity() async {
    final result = await _invokeMap('getDeviceIdentity');
    if (result == null) {
      throw AppException(
        AppErrorCodes.unsupported,
        'This build cannot create a device identity. Run the Android app on a physical device.',
      );
    }
    final identity = DeviceIdentity(
      installationId: jsonStringOr(result['installationId']),
      secret: jsonStringOr(result['secret']),
      secretHash: jsonStringOr(result['secretHash']),
    );
    if (identity.installationId.isEmpty ||
        identity.secret.isEmpty ||
        identity.secretHash.isEmpty) {
      throw AppException(
        AppErrorCodes.nativeError,
        'The device identity is incomplete. Reinstall the app and try again.',
      );
    }
    return identity;
  }

  Future<BatteryStatus> getBatteryStatus() async {
    final result = await _invokeMap('getBatteryStatus');
    return result == null ? BatteryStatus.unknown() : BatteryStatus.fromJson(result);
  }

  Future<List<InstalledApp>> getInstalledApps() async {
    final result = await _invokeList('getInstalledApps');
    if (result == null) return const [];
    return result
        .map((value) => InstalledApp.fromJson(jsonMap(value)))
        .toList(growable: false);
  }

  Future<bool> isPackageSuspended(String packageName) async {
    final result = await _invoke<bool>('isPackageSuspended', {'packageName': packageName});
    return result ?? false;
  }

  Future<NativePolicyApplyResult> applyPolicy(PolicyPayload policy) async {
    final result = await _invoke<dynamic>('applyPolicy', {'policy': policy.toJson()});
    if (result is! Map) {
      throw AppException(
        AppErrorCodes.unsupported,
        'Policy enforcement is unavailable on this device.',
      );
    }
    return NativePolicyApplyResult.fromJson(jsonMap(result));
  }

  Future<GuardianServiceStatus> getGuardianServiceStatus() async {
    final result = await _invokeMap('getGuardianServiceStatus');
    return result == null
        ? const GuardianServiceStatus()
        : GuardianServiceStatus.fromJson(result);
  }

  Future<bool> startGuardianService() async =>
      await _invoke<bool>('startGuardianService') ?? false;

  Future<bool> stopGuardianService() async =>
      await _invoke<bool>('stopGuardianService') ?? false;

  Future<bool> startAudioAssistanceService({required String sessionId}) async =>
      await _invoke<bool>('startAudioAssistanceService', {'sessionId': sessionId}) ??
      false;

  Future<bool> stopAudioAssistanceService() async =>
      await _invoke<bool>('stopAudioAssistanceService') ?? false;

  Future<bool> isAudioAssistanceServiceRunning() async =>
      await probeAudioAssistanceServiceRunning() ?? false;

  /// Tri-state probe of the native microphone foreground service.
  ///
  /// Returns `true`/`false` only when the native bridge answered, and `null`
  /// when the platform channel is unavailable or the answer is malformed.
  /// Callers must not treat `null` as "stopped": a failed probe is not proof
  /// that capture ended.
  Future<bool?> probeAudioAssistanceServiceRunning() async {
    final map = await _invokeMap('getAudioAssistanceStatus');
    if (map == null) return null;
    final value = map['isRunning'];
    return value is bool ? value : null;
  }

  /// Confirms to the native foreground service that the Dart isolate still
  /// owns a live microphone track. Returns false when the confirmation was
  /// not accepted; failures are never thrown into the media path.
  Future<bool> notifyAudioCaptureHeartbeat({required String sessionId}) async {
    if (!isAvailable) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'notifyAudioCaptureHeartbeat',
            {'sessionId': sessionId},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Session id the native service reports as active, or null when the service
  /// is not running or the bridge is unavailable.
  ///
  /// This is the only authoritative source for the native session id; the
  /// `audio_assistance_started` event carries the same value.
  Future<String?> getActiveAudioSessionId() async {
    final map = await _invokeMap('getAudioAssistanceStatus');
    final value = jsonStringOr(map?['activeSessionId']);
    return value.isEmpty ? null : value;
  }

  /// Whether the OS will display notifications (always true below Android 13).
  ///
  /// The microphone foreground service must be able to show its ongoing
  /// notification, so this is checked before asking the service to start.
  Future<bool> areNotificationsGranted() async =>
      await _invoke<bool>('areNotificationsGranted') ?? false;

  /// True only when RECORD_AUDIO is currently granted on a one-time basis.
  ///
  /// Android exposes no public API for the one-time flag, so the native side
  /// reports `oneTime: false`; this method therefore returns false whenever the
  /// grant cannot be proven temporary. Treat it as a hint only: always rely on
  /// the live permission check before starting the service.
  Future<bool> isMicrophoneOneTimeGrant() async {
    final map = await _invokeMap('isMicrophoneOneTimeGrant');
    if (map == null) return false;
    return jsonBoolOr(map['granted']) && jsonBoolOr(map['oneTime']);
  }

  Future<bool> configureBackgroundSync({
    required String supabaseUrl,
    required String publishableKey,
    required String deviceId,
    required String deviceSecret,
    required String familyId,
  }) async {
    return await _invoke<bool>('configureBackgroundSync', {
          'supabaseUrl': supabaseUrl,
          'publishableKey': publishableKey,
          'deviceId': deviceId,
          'deviceSecret': deviceSecret,
          'familyId': familyId,
        }) ??
        false;
  }

  Future<void> clearBackgroundSync() async {
    await _invoke<bool>('clearBackgroundSync');
  }

  Future<bool> requestDeviceAdmin() async =>
      await _invoke<bool>('requestDeviceAdmin') ?? false;

  Future<bool> openUsageAccessSettings() async =>
      await _invoke<bool>('openUsageAccessSettings') ?? false;

  Future<bool> openBackgroundLocationSettings() async =>
      await _invoke<bool>('openBackgroundLocationSettings') ?? false;

  Future<Map<String, bool>> requestPermissions({
    bool camera = false,
    bool microphone = false,
    bool location = false,
    bool backgroundLocation = false,
    bool notifications = false,
  }) async {
    final result = await _invokeMap('requestPermissions', {
      'camera': camera,
      'microphone': microphone,
      'location': location,
      'backgroundLocation': backgroundLocation,
      'notifications': notifications,
    });
    if (result == null) return const {};
    return result.map((key, value) => MapEntry(key, jsonBoolOr(value)));
  }

  Future<LocationFix?> getLastKnownLocation() async {
    final result = await _invokeMap('getLastKnownLocation');
    if (result == null) return null;
    if (jsonBoolOr(result['available']) == false) return null;
    return LocationFix.fromJson(result);
  }

  Future<bool> startLocationTracking({int intervalSeconds = 60}) async =>
      await _invoke<bool>('startLocationTracking', {
        'intervalSeconds': intervalSeconds,
      }) ??
      false;

  Future<bool> stopLocationTracking() async =>
      await _invoke<bool>('stopLocationTracking') ?? false;

  Future<List<UsageDaily>> queryDailyUsage({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await _invokeList('getDailyUsage', {
      'startMillis': from.millisecondsSinceEpoch,
      'endMillis': to.millisecondsSinceEpoch,
    });
    if (result == null) return const [];
    return result.map((value) {
      final map = jsonMap(value);
      return UsageDaily(
        deviceId: deviceId,
        day: jsonDateOr(map['day'], DateTime.now()),
        packageName: jsonStringOr(map['packageName'] ?? map['package_name']),
        appLabel: jsonStringOr(
          map['label'] ?? map['appLabel'],
          jsonStringOr(map['packageName']),
        ),
        totalMs: jsonIntOr(map['totalMs'] ?? map['total_ms']),
        lastUsedAt: jsonDateFromMillis(map['lastUsedAtMillis']),
      );
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>?> _invokeMap(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    final result = await _invoke<dynamic>(method, arguments);
    if (result is Map) return jsonMap(result);
    return null;
  }

  Future<List<dynamic>?> _invokeList(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    final result = await _invoke<dynamic>(method, arguments);
    if (result is List) return result;
    return null;
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? arguments]) async {
    if (!isAvailable) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      throw AppException.native(
        error.message ?? 'The device could not complete this operation.',
        error,
      );
    }
  }
}
