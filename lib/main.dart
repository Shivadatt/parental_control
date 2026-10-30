import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/app.dart';
import 'app/bindings/repository_binding.dart';
import 'data/services/connectivity_service.dart';
import 'data/services/device_admin_service.dart';
import 'data/services/edge_api.dart';
import 'data/services/local_settings_service.dart';
import 'data/services/session_service.dart';
import 'data/services/supabase_service.dart';
import 'features/remote_assistance/remote_session_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Get.putAsync<LocalSettingsService>(
    () => LocalSettingsService().init(),
    permanent: true,
  );
  final supabase = await Get.putAsync<SupabaseService>(
    () => SupabaseService().init(),
    permanent: true,
  );
  Get.put<EdgeApi>(EdgeApi(supabase), permanent: true);
  Get.put<SessionService>(SessionService(), permanent: true);
  await Get.putAsync<ConnectivityService>(
    () => ConnectivityService().init(),
    permanent: true,
  );
  Get.put<DeviceAdminService>(DeviceAdminService(), permanent: true);
  RepositoryBinding().dependencies();
  // Owns the live assistance session controller for the whole app lifetime so
  // a route pop can never end a consented, running microphone session.
  Get.put<RemoteSessionRegistry>(RemoteSessionRegistry(), permanent: true);

  runApp(const ParentControlApp());
}
