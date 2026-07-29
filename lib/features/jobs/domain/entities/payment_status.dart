/// The billing/payment state of a [Job] (BUILD_BRIEF.md §5.1).
///
/// Stored in `jobs/{id}.paymentStatus` as a wire string; defaults to
/// [PaymentStatus.unbilled] for a freshly created job.
enum PaymentStatus {
  /// No invoice has been raised yet.
  unbilled('unbilled'),

  /// Invoiced but unpaid.
  unpaid('unpaid'),

  /// Part of the amount has been collected.
  partial('partial'),

  /// Fully paid.
  paid('paid');

  const PaymentStatus(this.wireName);

  /// The wire string persisted in Firestore.
  final String wireName;

  /// The Firestore wire string for this payment status.
  String get toWire => wireName;

  /// Parses a stored payment-status string, returning `null` if it is missing
  /// or unrecognized.
  static PaymentStatus? fromWire(String? value) {
    for (final status in PaymentStatus.values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}
