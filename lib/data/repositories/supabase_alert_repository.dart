import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/json_utils.dart';
import '../models/telemetry.dart';
import '../services/edge_api.dart';
import '../services/supabase_service.dart';
import 'repository_contracts.dart';

/// Reads safety alerts and applies parent acknowledgements through the
/// `family-admin` Edge Function. Realtime is a private, RLS-filtered channel;
/// no public broadcast channel is ever created.
class SupabaseAlertRepository implements AlertRepository {
  SupabaseAlertRepository({
    required this._supabase,
    required this._edgeApi,
  });

  final SupabaseService _supabase;
  final EdgeApi _edgeApi;

  @override
  Future<List<SafetyAlert>> fetchAlerts({
    required String familyId,
    int limit = 100,
  }) async {
    try {
      final rows = await _supabase.client
          .from('safety_alerts')
          .select('*, devices(display_name)')
          .eq('family_id', familyId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map((row) => SafetyAlert.fromJson(jsonMap(row)))
          .toList(growable: false);
    } catch (error) {
      throw _mapError(error, 'Safety alerts could not be loaded.');
    }
  }

  @override
  Future<void> acknowledgeAlert(String alertId) async {
    try {
      await _edgeApi.invoke(
        'family-admin',
        action: 'ack_alert',
        body: {'alert_id': alertId},
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'The alert could not be acknowledged.');
    }
  }

  @override
  Stream<List<SafetyAlert>> watchAlerts(String familyId) {
    late final StreamController<List<SafetyAlert>> controller;
    RealtimeChannel? channel;
    var channelStarted = false;
    var disposed = false;

    void start() {
      if (channelStarted || disposed) return;
      channelStarted = true;
      try {
        final active = _supabase.client.channel(
          'safety-alerts:$familyId:${DateTime.now().microsecondsSinceEpoch}',
          opts: const RealtimeChannelConfig(private: true),
        );
        channel = active;
        final filter = PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'family_id',
          value: familyId,
        );
        active.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'safety_alerts',
          filter: filter,
          callback: (payload) {
            if (disposed) return;
            controller.add([SafetyAlert.fromJson(payload.newRecord)]);
          },
        );
        active.onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'safety_alerts',
          filter: filter,
          callback: (payload) {
            if (disposed) return;
            controller.add([SafetyAlert.fromJson(payload.newRecord)]);
          },
        );
        active.subscribe((status, error) {
          if (disposed) return;
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            controller.addError(
              const AppException(
                AppErrorCodes.network,
                'Live alert updates disconnected. Refresh to reload alerts.',
              ),
            );
          }
        });
      } catch (error) {
        controller.addError(
          _mapError(
            error,
            'Live alert updates could not be started. Refresh to reload alerts.',
          ),
        );
      }
    }

    Future<void> stop() async {
      disposed = true;
      final active = channel;
      channel = null;
      if (active != null) {
        try {
          await active.unsubscribe();
          await _supabase.client.removeChannel(active);
        } catch (_) {
          // Realtime teardown is best effort; the stream is already finished.
        }
      }
    }

    controller = StreamController<List<SafetyAlert>>.broadcast(
      onListen: start,
      onCancel: () {
        unawaited(stop());
      },
    );
    return controller.stream;
  }

  AppException _mapError(Object error, String fallbackMessage) {
    if (error is AppException) return error;
    if (error is PostgrestException) {
      final code = switch (error.code) {
        '42501' => AppErrorCodes.forbidden,
        'PGRST116' => AppErrorCodes.notFound,
        _ => AppErrorCodes.unknown,
      };
      return AppException(
        code,
        error.message.trim().isEmpty ? fallbackMessage : error.message,
      );
    }
    return AppException.from(error);
  }
}
