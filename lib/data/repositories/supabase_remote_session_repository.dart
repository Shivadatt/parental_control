import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/json_utils.dart';
import '../models/remote_session.dart';
import '../services/edge_api.dart';
import '../services/supabase_service.dart';
import 'repository_contracts.dart';

/// Assistance sessions. Status transitions are always driven by the
/// `remote-session` Edge Function response (or a Realtime row); this
/// repository never advances a session locally.
class SupabaseRemoteSessionRepository implements RemoteSessionRepository {
  SupabaseRemoteSessionRepository({
    required this._supabase,
    required this._edgeApi,
  });

  final SupabaseService _supabase;
  final EdgeApi _edgeApi;

  static const _sessionSelect =
      '*, devices(display_name), '
      'parent_profile:profiles!parent_user_id(display_name), '
      'child_profile:profiles!child_user_id(display_name)';

  @override
  Future<RemoteSession> request({
    required String deviceId,
    required SessionKind kind,
  }) async {
    try {
      final data = await _edgeApi.invokeMap(
        'remote-session',
        action: 'request',
        body: {'device_id': deviceId, 'kind': kind.wireName},
      );
      return RemoteSession.fromJson(_normalizeSession(data));
    } on AppException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'The assistance request could not be sent.');
    }
  }

  @override
  Future<List<RemoteSession>> fetchPendingForChild() async {
    try {
      final rows = await _edgeApi.invokeList(
        'remote-session',
        action: 'pending_child',
      );
      return rows
          .map((row) => RemoteSession.fromJson(_normalizeSession(jsonMap(row))))
          .toList(growable: false);
    } on AppException {
      rethrow;
    } catch (error) {
      throw _mapError(
        error,
        'Pending assistance requests could not be loaded.',
      );
    }
  }

  @override
  Future<RemoteSession?> fetchById(String sessionId) async {
    try {
      final row = await _supabase.client
          .from('remote_sessions')
          .select(_sessionSelect)
          .eq('id', sessionId)
          .maybeSingle();
      return row == null
          ? null
          : RemoteSession.fromJson(_normalizeSession(row));
    } catch (error) {
      throw _mapError(error, 'The assistance session could not be loaded.');
    }
  }

  @override
  Future<List<RemoteSession>> fetchForFamily(
    String familyId, {
    int limit = 30,
  }) async {
    try {
      final rows = await _supabase.client
          .from('remote_sessions')
          .select(_sessionSelect)
          .eq('family_id', familyId)
          .order('requested_at', ascending: false)
          .limit(limit);
      return rows
          .map((row) => RemoteSession.fromJson(_normalizeSession(jsonMap(row))))
          .toList(growable: false);
    } catch (error) {
      throw _mapError(error, 'Recent assistance sessions could not be loaded.');
    }
  }

  @override
  Future<RemoteSession> respond({
    required String sessionId,
    required bool accept,
  }) async {
    try {
      final data = await _edgeApi.invokeMap(
        'remote-session',
        action: 'respond',
        body: {'session_id': sessionId, 'accept': accept},
      );
      return RemoteSession.fromJson(_normalizeSession(data));
    } on AppException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'The assistance response could not be sent.');
    }
  }

  @override
  Future<RemoteSession> markActive(String sessionId) async {
    try {
      final data = await _edgeApi.invokeMap(
        'remote-session',
        action: 'start',
        body: {'session_id': sessionId},
      );
      return RemoteSession.fromJson(_normalizeSession(data));
    } on AppException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'The assistance session could not be started.');
    }
  }

  @override
  Future<void> end({required String sessionId, String? reason}) async {
    try {
      await _edgeApi.invoke(
        'remote-session',
        action: 'end',
        body: withoutNulls({'session_id': sessionId, 'reason': reason}),
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'The assistance session could not be ended.');
    }
  }

  @override
  Future<IceConfig> fetchIceConfig(String sessionId) async {
    try {
      final data = await _edgeApi.invokeMap(
        'remote-session',
        action: 'ice',
        body: {'session_id': sessionId},
      );
      return IceConfig.fromJson(data);
    } on AppException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'Connection configuration could not be loaded.');
    }
  }

  @override
  Future<void> sendSignal({
    required String sessionId,
    required SignalKind kind,
    required Map<String, dynamic> payload,
  }) async {
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const AppException(
        AppErrorCodes.unauthorized,
        'Sign in again to continue the assistance session.',
      );
    }
    try {
      await _supabase.client.from('webrtc_signals').insert({
        'session_id': sessionId,
        'from_user_id': userId,
        'kind': kind.wireName,
        'payload': payload,
      });
    } catch (error) {
      throw _mapError(error, 'The WebRTC signal could not be sent.');
    }
  }

  @override
  Stream<RemoteSession> watchSession(String sessionId) {
    return _watchSessionRows(
      topic: 'remote-session:$sessionId',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: sessionId,
      ),
      mapper: (record) => RemoteSession.fromJson(_normalizeSession(record)),
    );
  }

  @override
  Stream<List<RemoteSession>> watchFamilySessions(String familyId) {
    final rows = _watchSessionRows(
      topic: 'remote-session-family:$familyId',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'family_id',
        value: familyId,
      ),
      mapper: (record) => RemoteSession.fromJson(_normalizeSession(record)),
    );
    return rows.map((session) => [session]);
  }

  @override
  Stream<List<WebRtcSignal>> watchSignals(String sessionId) {
    late final StreamController<List<WebRtcSignal>> controller;
    RealtimeChannel? channel;
    var disposed = false;

    void start() {
      try {
        final active = _supabase.client.channel(
          'webrtc-signals:$sessionId:${DateTime.now().microsecondsSinceEpoch}',
          opts: const RealtimeChannelConfig(private: true),
        );
        channel = active;
        active.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'webrtc_signals',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) {
            if (disposed) return;
            controller.add([WebRtcSignal.fromJson(payload.newRecord)]);
          },
        );
        active.subscribe((status, error) {
          if (disposed) return;
          if (status == RealtimeSubscribeStatus.subscribed) {
            // An established (or re-established) channel is the recovery
            // signal: emit an empty batch so consumers can clear a stale
            // "live updates interrupted" banner even when no new row follows.
            controller.add(const <WebRtcSignal>[]);
            return;
          }
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            controller.addError(
              const AppException(
                AppErrorCodes.network,
                'Live session signaling disconnected. End the session and retry.',
              ),
            );
          }
        });
        unawaited(_replaySignals(sessionId, controller, () => disposed));
      } catch (error) {
        controller.addError(
          _mapError(error, 'Live session signaling could not be started.'),
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
          // Realtime teardown is best effort.
        }
      }
    }

    controller = StreamController<List<WebRtcSignal>>.broadcast(
      onListen: start,
      onCancel: () {
        unawaited(stop());
      },
    );
    return controller.stream;
  }

  /// Loads signals that were stored before this subscription started. Realtime
  /// only delivers new inserts, and the child may open its session screen after
  /// the parent's offer was sent. Duplicates are harmless: the session
  /// controller deduplicates by signal id.
  Future<void> _replaySignals(
    String sessionId,
    StreamController<List<WebRtcSignal>> controller,
    bool Function() isDisposed,
  ) async {
    try {
      final rows = await _supabase.client
          .from('webrtc_signals')
          .select()
          .eq('session_id', sessionId)
          .order('sequence', ascending: true);
      if (isDisposed() || rows.isEmpty) return;
      controller.add(
        rows.map((row) => WebRtcSignal.fromJson(row)).toList(growable: false),
      );
    } catch (_) {
      // Live inserts still work; only a late join could miss earlier signals.
    }
  }

  Stream<T> _watchSessionRows<T>({
    required String topic,
    required PostgresChangeFilter filter,
    required T Function(Map<String, dynamic> record) mapper,
  }) {
    late final StreamController<T> controller;
    RealtimeChannel? channel;
    var disposed = false;

    void start() {
      try {
        final active = _supabase.client.channel(
          '$topic:${DateTime.now().microsecondsSinceEpoch}',
          opts: const RealtimeChannelConfig(private: true),
        );
        channel = active;
        void onChange(PostgresChangePayload payload) {
          if (disposed) return;
          controller.add(mapper(payload.newRecord));
        }

        active.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'remote_sessions',
          filter: filter,
          callback: onChange,
        );
        active.onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'remote_sessions',
          filter: filter,
          callback: onChange,
        );
        active.subscribe((status, error) {
          if (disposed) return;
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            controller.addError(
              const AppException(
                AppErrorCodes.network,
                'Live session updates disconnected. Refresh to check the status.',
              ),
            );
          }
        });
      } catch (error) {
        controller.addError(
          _mapError(error, 'Live session updates could not be started.'),
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
          // Realtime teardown is best effort.
        }
      }
    }

    controller = StreamController<T>.broadcast(
      onListen: start,
      onCancel: () {
        unawaited(stop());
      },
    );
    return controller.stream;
  }

  /// Edge responses may expose flat display names while Realtime/direct
  /// selects embed related rows. Normalise both shapes for [RemoteSession].
  Map<String, dynamic> _normalizeSession(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    if (data['devices'] == null && data['device_name'] != null) {
      data['devices'] = {'display_name': data['device_name']};
    }
    if (data['parent_profile'] == null && data['parent_display_name'] != null) {
      data['parent_profile'] = {'display_name': data['parent_display_name']};
    }
    if (data['child_profile'] == null && data['child_display_name'] != null) {
      data['child_profile'] = {'display_name': data['child_display_name']};
    }
    return data;
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
