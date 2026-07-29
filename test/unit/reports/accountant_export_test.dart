import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/billing/domain/entities/payment.dart';
import 'package:service_centre_app/features/billing/domain/entities/payment_mode.dart';
import 'package:service_centre_app/features/reports/domain/accountant_export.dart';

List<String> _lines(String csv) =>
    csv.split(RegExp(r'\r?\n')).where((l) => l.isNotEmpty).toList();

void main() {
  group('buildPaymentsCsv', () {
    test('writes a header and one row per payment with plain rupee amounts', () {
      final csv = buildPaymentsCsv([
        Payment(
          id: 'p1',
          invoiceId: 'INV-2607-0001',
          amountPaise: 250050,
          mode: PaymentMode.upi,
          branchId: 'MAIN',
          ref: 'UPI9',
          at: DateTime.utc(2026, 7, 1, 10, 30),
        ),
      ]);

      expect(_lines(csv).first, contains('Amount (INR)'));
      // Amount rendered as a plain two-decimal rupee string (no symbol, no
      // floating point).
      expect(csv, contains('2500.50'));
      expect(csv, contains('INV-2607-0001'));
      expect(csv, contains('upi'));
      expect(csv, contains('UPI9'));
      expect(csv, contains('2026-07-01T10:30:00.000Z'));
    });

    test('produces just the header for no payments', () {
      final lines = _lines(buildPaymentsCsv(const []));
      expect(lines, hasLength(1));
      expect(lines.first, contains('Reference'));
    });
  });
}
