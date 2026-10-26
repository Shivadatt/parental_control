import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/core/config/env.dart';

String _jwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.signature';
}

void main() {
  group('Env.backendConfigurationProblem', () {
    test('rejects a missing URL or key', () {
      expect(
        Env.backendConfigurationProblem(url: '', key: 'key'),
        contains('SUPABASE_URL is not set'),
      );
      expect(
        Env.backendConfigurationProblem(
          url: 'https://project.supabase.co',
          key: ' ',
        ),
        contains('SUPABASE_ANON_KEY is not set'),
      );
    });

    test('rejects malformed and remote plain-http URLs', () {
      expect(
        Env.backendConfigurationProblem(url: 'not a url', key: 'key'),
        contains('valid absolute URL'),
      );
      expect(
        Env.backendConfigurationProblem(
          url: 'http://project.supabase.co',
          key: 'key',
        ),
        contains('must use https'),
      );
    });

    test('allows http only for local development hosts', () {
      for (final host in ['localhost', '127.0.0.1', '10.0.2.2']) {
        expect(
          Env.backendConfigurationProblem(url: 'http://$host:54321', key: 'key'),
          isNull,
          reason: host,
        );
      }
      expect(
        Env.backendConfigurationProblem(
          url: 'https://project.supabase.co',
          key: 'key',
        ),
        isNull,
      );
    });

    test('rejects privileged server keys', () {
      expect(
        Env.backendConfigurationProblem(
          url: 'https://project.supabase.co',
          key: _jwt({'role': 'service_role'}),
        ),
        contains('privileged server key'),
      );
      expect(
        Env.backendConfigurationProblem(
          url: 'https://project.supabase.co',
          key: 'sb_secret_0123456789',
        ),
        contains('privileged server key'),
      );
    });

    test('accepts publishable and legacy anon keys', () {
      expect(
        Env.backendConfigurationProblem(
          url: 'https://project.supabase.co',
          key: _jwt({'role': 'anon'}),
        ),
        isNull,
      );
      expect(
        Env.backendConfigurationProblem(
          url: 'https://project.supabase.co',
          key: 'sb_publishable_abcdef',
        ),
        isNull,
      );
    });
  });
}
