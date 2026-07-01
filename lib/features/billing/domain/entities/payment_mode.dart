/// How a payment was collected (`payments/{id}.mode`, BUILD_BRIEF.md §5.1).
enum PaymentMode {
  /// Cash.
  cash('cash'),

  /// UPI transfer.
  upi('upi'),

  /// Card (credit/debit).
  card('card');

  const PaymentMode(this.wireName);

  /// The wire string persisted in Firestore.
  final String wireName;

  /// The Firestore wire string for this mode.
  String get toWire => wireName;

  /// Parses a stored mode string, returning `null` if missing/unrecognized.
  static PaymentMode? fromWire(String? value) {
    for (final mode in PaymentMode.values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }
}
