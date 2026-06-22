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
}
