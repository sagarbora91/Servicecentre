/// Lifecycle of an [Estimate] (BUILD_BRIEF.md §5.1
/// `estimates/{id}.status`).
///
/// A quote is prepared as [draft], [sent] to the customer, then either
/// [approved] or [declined]. Stored as a wire string.
enum EstimateStatus {
  /// Being prepared; not yet shown to the customer.
  draft('draft'),

  /// Shown to the customer, awaiting their decision.
  sent('sent'),

  /// The customer approved the quote; work/billing may proceed.
  approved('approved'),

  /// The customer declined the quote.
  declined('declined');

  const EstimateStatus(this.wireName);

  /// The wire string persisted in Firestore.
  final String wireName;

  /// The Firestore wire string for this status.
  String get toWire => wireName;

  /// Parses a stored status string, returning `null` if it is missing or
  /// unrecognized.
  static EstimateStatus? fromWire(String? value) {
    for (final status in EstimateStatus.values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}
