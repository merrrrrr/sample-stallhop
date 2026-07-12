import 'package:flutter_test/flutter_test.dart';
import 'package:stallhop/core/utils/validators.dart';

void main() {
  group('email', () {
    test('accepts valid addresses', () {
      expect(Validators.email('alice@test.com'), isNull);
      expect(Validators.email('a.b+tag@sub.domain.co'), isNull);
      expect(Validators.email('  spaced@test.com  '), isNull);
    });

    test('rejects invalid addresses', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('missing@tld'), isNotNull);
      expect(Validators.email('@no-user.com'), isNotNull);
    });
  });

  group('password', () {
    test('accepts 6+ characters', () {
      expect(Validators.password('secret'), isNull);
      expect(Validators.password('longer password'), isNull);
    });

    test('rejects empty and short', () {
      expect(Validators.password(null), isNotNull);
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('12345'), isNotNull);
    });
  });

  group('confirmPassword', () {
    test('accepts matching', () {
      expect(Validators.confirmPassword('secret', 'secret'), isNull);
    });

    test('rejects empty or mismatched', () {
      expect(Validators.confirmPassword(null, 'secret'), isNotNull);
      expect(Validators.confirmPassword('', 'secret'), isNotNull);
      expect(Validators.confirmPassword('other', 'secret'), isNotNull);
    });
  });

  group('phone (Malaysian mobile)', () {
    test('accepts local and country-code formats', () {
      expect(Validators.phone('0123456789'), isNull);
      expect(Validators.phone('+60123456789'), isNull);
      expect(Validators.phone('60123456789'), isNull);
      expect(Validators.phone('012-345 6789'), isNull); // separators stripped
    });

    test('rejects empty, short, and non-numeric', () {
      expect(Validators.phone(null), isNotNull);
      expect(Validators.phone(''), isNotNull);
      expect(Validators.phone('012345'), isNotNull);
      expect(Validators.phone('abcdefghij'), isNotNull);
    });
  });

  group('required', () {
    test('accepts non-blank values', () {
      expect(Validators.required('x'), isNull);
    });

    test('rejects null/blank and names the field', () {
      expect(Validators.required(null), isNotNull);
      expect(Validators.required('   '), isNotNull);
      expect(Validators.required('', 'Name'), contains('Name'));
    });
  });

  group('price', () {
    test('accepts positive amounts', () {
      expect(Validators.price('7.50'), isNull);
      expect(Validators.price('1'), isNull);
    });

    test('rejects empty, non-numeric, zero, and negative', () {
      expect(Validators.price(null), isNotNull);
      expect(Validators.price(''), isNotNull);
      expect(Validators.price('abc'), isNotNull);
      expect(Validators.price('0'), isNotNull);
      expect(Validators.price('-5'), isNotNull);
    });
  });
}
