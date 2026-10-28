import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/core/utils/formatters.dart';

void main() {
  final reference = DateTime(2026, 10, 27, 12, 0, 0);

  String at(Duration offset) =>
      relativeTime(reference.add(offset), now: reference);

  group('relativeTime past', () {
    test('null renders as Never', () {
      expect(relativeTime(null, now: reference), 'Never');
    });

    test('zero and sub-minute past keep the existing wording', () {
      expect(at(Duration.zero), 'Just now');
      expect(at(const Duration(seconds: -1)), 'Just now');
      expect(at(const Duration(seconds: -59)), 'Just now');
    });

    test('minute, hour and day buckets', () {
      expect(at(const Duration(seconds: -60)), '1 min ago');
      expect(at(const Duration(minutes: -59)), '59 min ago');
      expect(at(const Duration(minutes: -60)), '1 h ago');
      expect(at(const Duration(hours: -23)), '23 h ago');
      expect(at(const Duration(hours: -24)), '1 d ago');
      expect(at(const Duration(days: -6)), '6 d ago');
    });

    test('a week or more falls back to an absolute date', () {
      final value = reference.subtract(const Duration(days: 10));
      expect(relativeTime(value, now: reference), formatDate(value));
    });
  });

  group('relativeTime future', () {
    test('never uses a past-tense phrase', () {
      expect(at(const Duration(seconds: 1)), 'in a few seconds');
      expect(at(const Duration(seconds: 1)), isNot('Just now'));
    });

    test('sub-minute to minute boundary (59 s, 60 s)', () {
      expect(at(const Duration(seconds: 59)), 'in a few seconds');
      expect(at(const Duration(seconds: 60)), 'in 1 min');
      expect(at(const Duration(seconds: 61)), 'in 1 min');
    });

    test('minute to hour boundary (59 m, 60 m)', () {
      expect(at(const Duration(minutes: 59)), 'in 59 min');
      expect(at(const Duration(minutes: 60)), 'in 1 h');
      expect(at(const Duration(minutes: 60, seconds: 30)), 'in 1 h');
      expect(at(const Duration(minutes: 61)), 'in 1 h');
    });

    test('hour to day boundary (23 h, 24 h)', () {
      expect(at(const Duration(hours: 23)), 'in 23 h');
      expect(at(const Duration(hours: 24)), 'in 1 d');
      expect(at(const Duration(hours: 25)), 'in 1 d');
      expect(at(const Duration(days: 3)), 'in 3 d');
    });

    test('multi-day future stays relative', () {
      expect(at(const Duration(days: 10)), 'in 10 d');
    });
  });

  test('expiry tiles read as one phrase', () {
    final expiresAt = reference.add(const Duration(minutes: 5));
    expect(
      'expires ${relativeTime(expiresAt, now: reference)}',
      'expires in 5 min',
    );
    expect(
      'expires ${relativeTime(reference.add(const Duration(seconds: 20)), now: reference)}',
      'expires in a few seconds',
    );
  });
}
