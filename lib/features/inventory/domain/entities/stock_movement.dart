import 'package:freezed_annotation/freezed_annotation.dart';

part 'stock_movement.freezed.dart';

/// The kind of stock ledger entry (BUILD_BRIEF.md §5.1 `stockMovements.type`).
///
/// The enum *name* differs from the stored string for [in_], because `in` is a
/// Dart keyword: the value is named `in_` but serialized/parsed as `'in'`. Use
/// [wireName] when writing to Firestore and [fromWireName] when reading.
enum StockMovementType {
  /// Stock received into inventory (manual receipt).
  in_,

  /// Stock consumed out of inventory (e.g. used on a job).
  out,

  /// A manual correction (delta can be positive or negative).
  adjust,

  /// Goods received against a purchase order.
  grn,

  /// Stock set aside (reserved) for a job/order.
  reserve,

  /// A previously reserved quantity returned to available stock.
  release;

  /// The string stored in Firestore for this type. Equals [name] for every
  /// value except [in_], which is stored as `'in'`.
  String get wireName => this == StockMovementType.in_ ? 'in' : name;

  /// Parses a stored type string, returning `null` if missing or unrecognized.
  ///
  /// Accepts `'in'` (the wire form) as well as the raw enum name `'in_'`,
  /// defensively, so either representation round-trips.
  static StockMovementType? fromWireName(String? value) {
    if (value == null) return null;
    if (value == 'in' || value == 'in_') return StockMovementType.in_;
    for (final type in StockMovementType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

/// A single append-only entry in the stock ledger (`stockMovements/{id}`).
///
/// freezed value type (equality, `hashCode`, `copyWith` generated). The
/// Firestore mapping lives in the data layer; this model is pure Dart and never
/// touches `Timestamp`. Money is not involved here; quantities are integer
/// counts and [at] is UTC.
@freezed
abstract class StockMovement with _$StockMovement {
  /// Creates a stock movement.
  const factory StockMovement({
    required String id,
    required String partId,
    required StockMovementType type,
    required int qty,
    required DateTime at,
    required String by,
    required String branchId,
    String? jobId,
    String? orderId,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
  }) = _StockMovement;

  const StockMovement._();
}
