/// The final result of a [Job] once work concludes (BUILD_BRIEF.md §5.1).
///
/// Stored in `jobs/{id}.outcome` as a snake_case wire string; nullable while the
/// job is still in progress.
enum JobOutcome {
  /// The watch was successfully repaired.
  repaired('repaired'),

  /// The customer declined the estimate/repair.
  declined('declined'),

  /// The watch could not be repaired.
  beyondRepair('beyond_repair'),

  /// The watch was returned without repair.
  returned('returned');

  const JobOutcome(this.wireName);

  /// The snake_case string persisted in Firestore.
  final String wireName;

  /// The Firestore wire string for this outcome.
  String get toWire => wireName;

  /// Parses a stored outcome string, returning `null` if it is missing or
  /// unrecognized.
  static JobOutcome? fromWire(String? value) {
    for (final outcome in JobOutcome.values) {
      if (outcome.wireName == value) return outcome;
    }
    return null;
  }
}
