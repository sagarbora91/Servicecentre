import 'package:freezed_annotation/freezed_annotation.dart';

part 'watch.freezed.dart';

/// A customer's watch under service (BUILD_BRIEF §5.1, `watches/{id}`).
///
/// freezed value type: equality, `hashCode`, and `copyWith` are generated. The
/// owning customer is referenced by its String doc id ([customerId]); the
/// Firestore mapping lives in the `data` layer so this `domain` model has no
/// Firebase imports. Dates are stored UTC.
@freezed
abstract class Watch with _$Watch {
  /// Creates a watch record.
  const factory Watch({
    required String id,
    required String customerId,
    required String brand,
    required String model,
    required List<String> photos,
    required String branchId,
    String? serial,
    DateTime? warrantyUntil,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
  }) = _Watch;

  const Watch._();
}
