import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/billing/domain/entities/payment.dart';
import 'package:service_centre_app/features/billing/domain/entities/payment_mode.dart';
import 'package:service_centre_app/features/reports/domain/day_book.dart';

void main() {
  Payment pay(PaymentMode mode, int paise) => Payment(
        id: 'p',
        invoiceId: 'i1',
        amountPaise: paise,
        mode: mode,
        branchId: 'MAIN',
      );

  group('DayBook.fromPayments', () {
    test('is empty for no payments', () {
      final book = DayBook.fromPayments(const []);
      expect(book.totalPaise, 0);
      expect(book.count, 0);
      expect(book.amountFor(PaymentMode.cash), 0);
    });

    test('groups collections by mode and balances to the grand total', () {
      final book = DayBook.fromPayments([
        pay(PaymentMode.cash, 50000),
        pay(PaymentMode.cash, 25000),
        pay(PaymentMode.upi, 120000),
        pay(PaymentMode.card, 30000),
      ]);

      expect(book.amountFor(PaymentMode.cash), 75000);
      expect(book.amountFor(PaymentMode.upi), 120000);
      expect(book.amountFor(PaymentMode.card), 30000);
      expect(book.count, 4);
      // The grand total equals the sum of the per-mode totals (it balances).
      final summed = book.byMode.values.fold(0, (a, b) => a + b);
      expect(book.totalPaise, summed);
      expect(book.totalPaise, 225000);
    });
  });
}
