import 'package:freezed_annotation/freezed_annotation.dart';

part 'customer.freezed.dart';

/// A customer of the service centre (BUILD_BRIEF §5.1, `customers/{id}`).
///
/// freezed value type: equality, `hashCode`, and `copyWith` are generated. The
/// Firestore mapping (Timestamp <-> UTC DateTime, doc id outside the data map)
/// lives in the `data` layer, so this `domain` model stays free of Firebase
/// types. Money is not relevant here; dates are stored UTC.
@freezed
abstract class Customer with _$Customer {
  /// Creates a customer record.
  const factory Customer({
    required String id,
    required String name,
    required String phone,
    required int serviceCount,
    required bool consentWhatsApp,
    required String branchId,
    String? email,
    String? address,
    DateTime? lastVisitAt,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
  }) = _Customer;

  const Customer._();
}
