import 'package:get/get.dart';

import '../../data/repositories/repository_contracts.dart';
import '../../data/repositories/supabase_alert_repository.dart';
import '../../data/repositories/supabase_audit_repository.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../data/repositories/supabase_device_repository.dart';
import '../../data/repositories/supabase_family_repository.dart';
import '../../data/repositories/supabase_location_repository.dart';
import '../../data/repositories/supabase_pairing_repository.dart';
import '../../data/repositories/supabase_policy_repository.dart';
import '../../data/repositories/supabase_remote_session_repository.dart';
import '../../data/repositories/supabase_usage_repository.dart';
import '../../data/services/edge_api.dart';
import '../../data/services/supabase_service.dart';

/// Registers the single provider implementation of every repository interface.
/// Screens resolve only the interfaces, so a missing backend can never be
/// mistaken for a working one.
class RepositoryBinding extends Bindings {
  @override
  void dependencies() {
    final supabase = Get.find<SupabaseService>();
    final edgeApi = Get.find<EdgeApi>();

    Get.put<AuthRepository>(
      SupabaseAuthRepository(supabase: supabase, edgeApi: edgeApi),
      permanent: true,
    );
    Get.put<FamilyRepository>(
      SupabaseFamilyRepository(supabase: supabase, edgeApi: edgeApi),
      permanent: true,
    );
    Get.put<PairingRepository>(
      SupabasePairingRepository(supabase: supabase, edgeApi: edgeApi),
      permanent: true,
    );
    Get.put<DeviceRepository>(
      SupabaseDeviceRepository(supabase: supabase, edgeApi: edgeApi),
      permanent: true,
    );
    Get.put<PolicyRepository>(
      SupabasePolicyRepository(supabase: supabase, edgeApi: edgeApi),
      permanent: true,
    );
    Get.put<UsageRepository>(
      SupabaseUsageRepository(supabase: supabase, edgeApi: edgeApi),
      permanent: true,
    );
    Get.put<LocationRepository>(
      SupabaseLocationRepository(supabase: supabase, edgeApi: edgeApi),
      permanent: true,
    );
    Get.put<AlertRepository>(
      SupabaseAlertRepository(supabase: supabase, edgeApi: edgeApi),
      permanent: true,
    );
    Get.put<RemoteSessionRepository>(
      SupabaseRemoteSessionRepository(supabase: supabase, edgeApi: edgeApi),
      permanent: true,
    );
    Get.put<AuditRepository>(
      SupabaseAuditRepository(supabase: supabase, edgeApi: edgeApi),
      permanent: true,
    );
  }
}
