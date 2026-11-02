import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/repositories/supabase_location_repository.dart';
import 'package:parent_control/data/services/edge_api.dart';
import 'package:parent_control/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseService extends Mock implements SupabaseService {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

/// Records what the repository actually put on the wire.
class _Call {
  _Call(this.function, this.body);

  final String function;
  final Object? body;
}

void main() {
  late _MockSupabaseService supabase;
  late _MockSupabaseClient client;
  late _MockFunctionsClient functions;
  late List<_Call> calls;
  late SupabaseLocationRepository repository;

  setUp(() {
    supabase = _MockSupabaseService();
    client = _MockSupabaseClient();
    functions = _MockFunctionsClient();
    calls = <_Call>[];
    when(() => supabase.isConfigured).thenReturn(true);
    when(() => supabase.isReady).thenReturn(true);
    when(() => supabase.client).thenReturn(client);
    when(() => client.functions).thenReturn(functions);
    when(
      () => functions.invoke(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((invocation) async {
      calls.add(
        _Call(
          invocation.positionalArguments.single as String,
          invocation.namedArguments[#body],
        ),
      );
      return const FunctionResponse(
        status: 200,
        data: {'ok': true, 'data': {'deleted': true}},
      );
    });
    // Any direct table write from the delete path is a contract violation.
    when(() => client.from(any())).thenThrow(
      StateError('safe_zones must not be deleted through the client'),
    );
    repository = SupabaseLocationRepository(
      supabase: supabase,
      edgeApi: EdgeApi(supabase),
    );
  });

  test('deleteSafeZone calls family-admin with action delete_zone', () async {
    await repository.deleteSafeZone('zone-1');

    expect(calls, hasLength(1));
    expect(calls.single.function, 'family-admin');
    expect(
      calls.single.body,
      {'action': 'delete_zone', 'zone_id': 'zone-1'},
    );
  });

  test('deleteSafeZone never touches the safe_zones table directly', () async {
    await repository.deleteSafeZone('zone-1');

    verifyNever(() => client.from(any()));
  });

  test('a 403 from family-admin surfaces as forbidden', () async {
    when(
      () => functions.invoke(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenThrow(
      const FunctionException(
        status: 403,
        details: {
          'error': {
            'code': 'forbidden',
            'message': 'A parent in this family is required.',
          },
        },
      ),
    );

    Object? thrown;
    try {
      await repository.deleteSafeZone('zone-1');
    } catch (error) {
      thrown = error;
    }

    expect(thrown, isA<AppException>());
    expect((thrown as AppException).code, AppErrorCodes.forbidden);
    expect(thrown.statusCode, 403);
    expect(thrown.message, 'A parent in this family is required.');
  });

  test('a 404 from family-admin surfaces as zone_not_found', () async {
    when(
      () => functions.invoke(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenThrow(
      const FunctionException(
        status: 404,
        details: {
          'error': {'code': 'zone_not_found', 'message': 'The safe zone was not found.'},
        },
      ),
    );

    Object? thrown;
    try {
      await repository.deleteSafeZone('gone');
    } catch (error) {
      thrown = error;
    }

    expect(thrown, isA<AppException>());
    expect((thrown as AppException).code, 'zone_not_found');
    expect(thrown.statusCode, 404);
  });
}
