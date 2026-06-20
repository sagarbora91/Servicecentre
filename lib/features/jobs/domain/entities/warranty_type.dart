/// How a [Job]'s repair is covered for billing (BUILD_BRIEF.md §5.1).
///
/// Stored in `jobs/{id}.warrantyType` as a snake_case wire string; nullable
/// until the job is billed.
enum WarrantyType {
  /// Covered under the manufacturer/service warranty (no charge).
  inWarranty('in_warranty'),

  /// Chargeable repair.
  paid('paid'),

  /// Free of charge as a goodwill gesture.
  goodwill('goodwill');

  const WarrantyType(this.wireName);

  /// The snake_case string persisted in Firestore.
  final String wireName;

  /// The Firestore wire string for this warranty type.
  String get toWire => wireName;

  /// Parses a stored warranty-type string, returning `null` if it is missing or
  /// unrecognized.
  static WarrantyType? fromWire(String? value) {
    for (final type in WarrantyType.values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}
