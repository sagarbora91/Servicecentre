/// The kind of supplier (`suppliers/{id}.type`, BUILD_BRIEF.md §5.1).
enum SupplierType {
  /// Titan (watch brand) spares.
  titan('titan'),

  /// Strap supplier.
  strap('strap'),

  /// Any other supplier.
  other('other');

  const SupplierType(this.wireName);

  /// The wire string persisted in Firestore.
  final String wireName;

  /// The Firestore wire string for this type.
  String get toWire => wireName;

  /// Parses a stored type string, defaulting to [SupplierType.other] when
  /// missing or unrecognized.
  static SupplierType fromWire(String? value) {
    for (final type in SupplierType.values) {
      if (type.wireName == value) return type;
    }
    return SupplierType.other;
  }
}
