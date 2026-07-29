import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/core/utils/currency.dart';

void main() {
  group('formatPaise', () {
    test('formats whole rupees with two decimals', () {
      expect(formatPaise(250000), '₹2500.00');
      expect(formatPaise(100), '₹1.00');
    });

    test('formats a sub-rupee paise remainder, zero-padded', () {
      expect(formatPaise(199), '₹1.99');
      expect(formatPaise(5), '₹0.05');
      expect(formatPaise(0), '₹0.00');
    });

    test('keeps the sign before the symbol for negative amounts', () {
      expect(formatPaise(-500), '-₹5.00');
      expect(formatPaise(-1), '-₹0.01');
    });
  });

  group('parseRupeesToPaise', () {
    test('parses whole rupees', () {
      expect(parseRupeesToPaise('2500'), 250000);
      expect(parseRupeesToPaise('0'), 0);
    });

    test('parses one or two decimal places exactly', () {
      expect(parseRupeesToPaise('2500.5'), 250050);
      expect(parseRupeesToPaise('2500.50'), 250050);
      expect(parseRupeesToPaise('0.05'), 5);
    });

    test('trims surrounding whitespace', () {
      expect(parseRupeesToPaise('  99.99  '), 9999);
    });

    test('rejects invalid, negative, or over-precise input', () {
      expect(parseRupeesToPaise(''), isNull);
      expect(parseRupeesToPaise('abc'), isNull);
      expect(parseRupeesToPaise('-5'), isNull);
      expect(parseRupeesToPaise('1.234'), isNull);
      expect(parseRupeesToPaise('1,000'), isNull);
    });
  });
}
