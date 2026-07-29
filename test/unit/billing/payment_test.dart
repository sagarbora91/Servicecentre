import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/billing/domain/entities/payment_mode.dart';

void main() {
  group('PaymentMode wire round-trip', () {
    test('maps each value to/from its wire string', () {
      for (final m in PaymentMode.values) {
        expect(PaymentMode.fromWire(m.toWire), m);
      }
    });

    test('returns null for missing/unknown wire strings', () {
      expect(PaymentMode.fromWire(null), isNull);
      expect(PaymentMode.fromWire('cheque'), isNull);
    });
  });
}
