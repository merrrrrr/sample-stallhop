import 'package:flutter_test/flutter_test.dart';
import 'package:stallhop/core/utils/formatters.dart';

void main() {
  group('centsToRM', () {
    test('formats zero', () => expect(centsToRM(0), 'RM 0.00'));

    test('formats typical amounts', () {
      expect(centsToRM(750), 'RM 7.50');
      expect(centsToRM(50), 'RM 0.50');
      expect(centsToRM(5), 'RM 0.05');
    });

    test('formats negative amounts with a leading sign', () {
      expect(centsToRM(-750), '-RM 7.50');
    });

    test('formats large amounts', () {
      expect(centsToRM(123456789), 'RM 1234567.89');
    });
  });

  group('rmToCents', () {
    test('parses plain and decimal values', () {
      expect(rmToCents('7.50'), 750);
      expect(rmToCents('7'), 700);
      expect(rmToCents(' 0.05 '), 5);
    });

    test('rounds sub-cent input', () {
      expect(rmToCents('7.505'), 751);
    });

    test('returns null for garbage', () {
      expect(rmToCents('abc'), isNull);
      expect(rmToCents(''), isNull);
      expect(rmToCents('7,50'), isNull);
    });
  });

  group('timeAgo', () {
    test('recent moments', () {
      expect(timeAgo(DateTime.now()), 'just now');
      expect(
        timeAgo(DateTime.now().subtract(const Duration(minutes: 5))),
        '5 min ago',
      );
      expect(
        timeAgo(DateTime.now().subtract(const Duration(hours: 3))),
        '3 h ago',
      );
    });
  });
}
