import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/core/config/env.dart';
import 'package:parent_control/features/pairing/pairing_qr_payload.dart';

void main() {
  group('PairingQrPayload.tryParse', () {
    test('parses the legacy v=1 linking code', () {
      final payload =
          PairingQrPayload.tryParse('parentcontrol://pair?code=4K9M2QRT&v=1');

      expect(payload, isNotNull);
      expect(payload!.value, '4K9M2QRT');
      expect(payload.isChildId, isFalse);
    });

    test('parses the v=2 permanent Child ID', () {
      final payload =
          PairingQrPayload.tryParse('parentcontrol://pair?id=PC7K4M2QRX&v=2');

      expect(payload, isNotNull);
      expect(payload!.value, 'PC7K4M2QRX');
      expect(payload.isChildId, isTrue);
    });

    test('normalizes a lower-case dashed Child ID', () {
      final payload =
          PairingQrPayload.tryParse('parentcontrol://pair?id=pc-7k4m2qrx&v=2');

      expect(payload, isNotNull);
      expect(payload!.value, 'PC7K4M2QRX');
      expect(payload.isChildId, isTrue);
    });

    test('normalizes a lower-case dashed linking code', () {
      final payload =
          PairingQrPayload.tryParse('parentcontrol://pair?code=4k9m-2qrt&v=1');

      expect(payload, isNotNull);
      expect(payload!.value, '4K9M2QRT');
      expect(payload.isChildId, isFalse);
    });

    test('uses Env.qrScheme as the only accepted scheme', () {
      expect(Env.qrScheme, 'parentcontrol');
      final uri = Uri.parse('${Env.qrScheme}://pair?id=PC7K4M2QRX&v=2');
      expect(PairingQrPayload.tryParse(uri.toString())?.value, 'PC7K4M2QRX');
      expect(
        PairingQrPayload.tryParse('other${Env.qrScheme}://pair?id=PC7K4M2QRX&v=2'),
        isNull,
      );
    });

    const rejected = <String>[
      'https://pair?code=4K9M2QRT&v=1',
      'parentcontrol://join?code=4K9M2QRT&v=1',
      'parentcontrol://pair?code=4K9M2QRT&v=3',
      'parentcontrol://pair?code=4K9M2QRT&v=1&extra=1',
      'parentcontrol://pair?code=4K9M2QRT&code=4K9M2QRT&v=1',
      'parentcontrol://pair?code=4K9M2QRT',
      'parentcontrol://pair?id=PC12345678&v=2',
      'parentcontrol://pair?code=ABC&v=1',
      'parentcontrol://pair?code=4K9M2QRT&v=1#fragment',
      'parentcontrol://pair:8080?code=4K9M2QRT&v=1',
      'parentcontrol://user:pass@pair?code=4K9M2QRT&v=1',
    ];
    for (final raw in rejected) {
      test('rejects $raw', () {
        expect(
          PairingQrPayload.tryParse(raw),
          isNull,
          reason: '$raw must not be accepted',
        );
      });
    }
  });
}
