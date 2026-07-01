import '../../../../core/errors/result.dart';
import '../entities/payment.dart';
import '../entities/payment_mode.dart';

/// Contract for recording and reading invoice [Payment]s.
///
/// Lives in `domain` (no Firebase imports); the `data` implementation records
/// payments transactionally (CLAUDE.md #3) so an invoice can never be
/// over-collected and its running paid total / status stay consistent.
abstract interface class PaymentsRepository {
  /// Streams the payments for [invoiceId], newest first.
  Stream<List<Payment>> watchPaymentsForInvoice(String invoiceId);

  /// Records a payment of [amountPaise] (> 0) against [invoiceId] in a
  /// transaction: it re-reads the invoice, rejects the payment (writing
  /// nothing) with a `ValidationFailure(paymentExceedsBalance)` if it would
  /// exceed the outstanding balance, otherwise appends the payment and advances
  /// the invoice's paid total + `paymentStatus` (unpaid → partial → paid).
  Future<Result<void>> recordPayment({
    required String invoiceId,
    required String branchId,
    required int amountPaise,
    required PaymentMode mode,
    required String by,
    String? ref,
  });
}
