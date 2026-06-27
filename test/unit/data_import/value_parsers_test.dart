import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/data_import/domain/value_parsers.dart';

void main() {
  group('parseFlag', () {
    test('true-ish values parse to true', () {
      for (final v in ['true', 'TRUE', 'Yes', 'y', '1']) {
        expect(parseFlag(v), isTrue, reason: v);
      }
    });

    test('false-ish and null values parse to false', () {
      for (final v in [null, '', 'no', '0', 'maybe']) {
        expect(parseFlag(v), isFalse, reason: '$v');
      }
    });
  });

  group('parseCount', () {
    test('absent is 0; valid integers pass through', () {
      expect(parseCount(null), 0);
      expect(parseCount('0'), 0);
      expect(parseCount('5'), 5);
    });

    test('negative or non-integer is invalid (null)', () {
      expect(parseCount('-1'), isNull);
      expect(parseCount('1.5'), isNull);
      expect(parseCount('x'), isNull);
    });
  });

  group('parseMoneyToPaise', () {
    test('absent is 0', () {
      expect(parseMoneyToPaise(null), 0);
    });

    test('rupees convert to paise, tolerating ₹ and commas', () {
      expect(parseMoneyToPaise('250'), 25000);
      expect(parseMoneyToPaise('250.50'), 25050);
      expect(parseMoneyToPaise('₹1,250.00'), 125000);
    });

    test('negative or non-numeric is invalid (null)', () {
      expect(parseMoneyToPaise('-5'), isNull);
      expect(parseMoneyToPaise('abc'), isNull);
    });
  });
}
