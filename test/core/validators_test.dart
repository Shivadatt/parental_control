import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/core/utils/validators.dart';

void main() {
  group('Validators.isChildId', () {
    test('accepts the canonical Child ID', () {
      expect(Validators.isChildId('PC7K4M2QRX'), isTrue);
    });

    test('accepts the dashed display form', () {
      expect(Validators.isChildId('PC-7K4M2QRX'), isTrue);
    });

    test('rejects a legacy 8-character linking code', () {
      expect(Validators.isChildId('4K9M2QRT'), isFalse);
      expect(Validators.isChildId('ABCD1234'), isFalse);
    });

    test('rejects the empty string and the bare prefix', () {
      expect(Validators.isChildId(''), isFalse);
      expect(Validators.isChildId('PC'), isFalse);
    });

    test('rejects ambiguous characters excluded from the alphabet', () {
      // The alphabet is 23456789ABCDEFGHJKMNPQRSTVWXYZ: no I, L, O, U, 0, 1.
      for (final ambiguous in <String>[
        'PC7K4M2QRI',
        'PC7K4M2QRL',
        'PC7K4M2QRO',
        'PC7K4M2QRU',
        'PC7K4M2QR0',
        'PC7K4M2QR1',
      ]) {
        expect(
          Validators.isChildId(ambiguous),
          isFalse,
          reason: '$ambiguous must be rejected',
        );
      }
    });

    test('rejects a wrong prefix', () {
      expect(Validators.isChildId('XX7K4M2QRX'), isFalse);
      expect(Validators.isChildId('AB7K4M2QRX'), isFalse);
    });

    test('rejects a wrong length', () {
      expect(Validators.isChildId('PC7K4M2QR'), isFalse);
      expect(Validators.isChildId('PC7K4M2QRXX'), isFalse);
    });

    test('normalizes lowercase and separators before matching', () {
      // Identifiers are normalized (upper case, separators stripped), so the
      // lower-case display form is the same identifier as the canonical form.
      expect(Validators.isChildId('pc-7k4m2qrx'), isTrue);
      expect(Validators.isChildId(' pc 7k4m2qrx '), isTrue);
      // Lower-case ambiguous letters are still excluded after normalization.
      expect(Validators.isChildId('pc-7k4m2qri'), isFalse);
    });
  });

  group('Validators.isLinkingCode', () {
    test('accepts an 8-character code from the alphabet', () {
      expect(Validators.isLinkingCode('ABCD1234'), isTrue);
      expect(Validators.isLinkingCode('4K9M2QRT'), isTrue);
    });

    test('rejects codes with the wrong length', () {
      expect(Validators.isLinkingCode('ABC'), isFalse);
      expect(Validators.isLinkingCode('ABCD12345'), isFalse);
      expect(Validators.isLinkingCode(''), isFalse);
    });

    test('rejects a Child ID', () {
      expect(Validators.isLinkingCode('PC7K4M2QRX'), isFalse);
      expect(Validators.isLinkingCode('PC-7K4M2QRX'), isFalse);
    });
  });

  group('Validators.pairingCode', () {
    test('requires a Child ID or linking code', () {
      expect(
        Validators.pairingCode(''),
        'A Child ID or linking code is required',
      );
      expect(
        Validators.pairingCode(null),
        'A Child ID or linking code is required',
      );
    });

    test('explains both accepted formats for a malformed value', () {
      final message = Validators.pairingCode('ABC');
      expect(message, isNotNull);
      expect(message, contains('Child ID'));
      expect(message, contains('8-character'));
    });

    test('rejects a Child ID with ambiguous characters', () {
      final message = Validators.pairingCode('PC12345678');
      expect(message, isNotNull);
      expect(message, contains('Child ID'));
    });

    test('accepts a Child ID, its display form and a legacy code', () {
      expect(Validators.pairingCode('PC7K4M2QRX'), isNull);
      expect(Validators.pairingCode('pc-7k4m2qrx'), isNull);
      expect(Validators.pairingCode('ABCD1234'), isNull);
    });
  });

  test('normalizePairingCode upper-cases and strips separators', () {
    expect(Validators.normalizePairingCode(' pc-7k4 m2qr x '), 'PC7K4M2QRX');
    expect(Validators.normalizePairingCode('abcd-1234'), 'ABCD1234');
  });
}
