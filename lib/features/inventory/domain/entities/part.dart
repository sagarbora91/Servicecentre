import 'package:freezed_annotation/freezed_annotation.dart';

part 'part.freezed.dart';

/// An inventory part (`parts/{id}`, BUILD_BRIEF.md §5.1).
///
/// freezed value type (equality, `hashCode`, `copyWith` generated). The
/// Firestore mapping lives in the data layer; this model is pure Dart and never
/// touches `Timestamp`. Money fields ([costPaise], [mrpPaise]) are integer
/// paise; [mfgDate]/[createdAt]/[updatedAt] are UTC.
@freezed
abstract class Part with _$Part {
  /// Creates a part.
  const factory Part({
    required String id,
    required String category,
    required String reference,
    required String binCode,
    required int onHand,
    required int reserved,
    required int minLevel,
    required int reorderPoint,
    required bool serviceOnly,
    required int costPaise,
    required int mrpPaise,
    required String branchId,
    String? size,
    DateTime? mfgDate,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
  }) = _Part;

  const Part._();

  /// Quantity available to consume right now (on-hand minus reserved), floored
  /// at zero so a transient over-reservation never reads negative.
  int get available => (onHand - reserved) < 0 ? 0 : onHand - reserved;

  /// Whether on-hand has fallen to or below the reorder point (reorder due).
  bool get isBelowReorder => onHand <= reorderPoint;
}
