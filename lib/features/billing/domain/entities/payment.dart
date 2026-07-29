import 'package:freezed_annotation/freezed_annotation.dart';

import 'payment_mode.dart';

part 'payment.freezed.dart';

/// A payment recorded against an invoice (`payments/{id}`, BUILD_BRIEF.md §5.1).
///
/// [amountPaise] is integer paise (BUILD_BRIEF §4); [ref] is an optional
/// reference (e.g. a UPI transaction id). freezed value type; Firestore mapping
/// lives in `data`.
@freezed
abstract class Payment with _$Payment {
  /// Creates a payment.
  const factory Payment({
    required String id,
    required String invoiceId,
    required int amountPaise,
    required PaymentMode mode,
    required String branchId,
    String? ref,
    DateTime? at,
    String? by,
  }) = _Payment;

  const Payment._();
}
