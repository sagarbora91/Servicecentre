/// Lifecycle of a purchase [Order] (`orders/{id}.status`, BUILD_BRIEF.md §5.1).
enum OrderStatus {
  /// Being prepared; not yet placed with the supplier.
  draft('draft'),

  /// Placed with the supplier, nothing received yet.
  placed('placed'),

  /// Some — but not all — ordered quantities have been received (partial GRN).
  partial('partial'),

  /// Everything ordered has been received.
  received('received'),

  /// The order was cancelled.
  cancelled('cancelled');

  const OrderStatus(this.wireName);

  /// The wire string persisted in Firestore.
  final String wireName;

  /// The Firestore wire string for this status.
  String get toWire => wireName;

  /// Parses a stored status string, defaulting to [OrderStatus.draft] when
  /// missing or unrecognized.
  static OrderStatus fromWire(String? value) {
    for (final status in OrderStatus.values) {
      if (status.wireName == value) return status;
    }
    return OrderStatus.draft;
  }
}
